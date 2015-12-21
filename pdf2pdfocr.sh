#!/bin/bash

# OCR a PDF and add a text "layer" in the original file.
# Use only open source tools.
# Does not re-encode any image or content in original PDF (if unprotected).
# Leonardo Cardoso - inspired in ocrmypdf (https://github.com/jbarlow83/OCRmyPDF)
# and this post: https://github.com/jbarlow83/OCRmyPDF/issues/8

# Dependencies:
# Tesseract-OCR and Tesseract-OCR-por (Portuguese is hardcoded by now)
# Python3 (and ReportLab)
# OCRMYPDF (for the great hocrtransform.py script) - https://github.com/jbarlow83/OCRmyPDF/blob/master/ocrmypdf/hocrtransform.py
# Poppler
# Gnu Parallel
# PDFtk Server (Cygwin only in 32 bits)
# ImageMagick

# This is the file to be transformed
# Must be supported image or PDF
INPUT_FILE=$1

# Global var to check operating system
OS=`uname -s`

# Return complete path of argument, except last level (filename or dirname)
complete_path() {
	pushd `dirname "$1"` > /dev/null
	local DIR_OUT=`pwd`
	popd > /dev/null
	echo "$DIR_OUT"
}

# OCRUtil Function - will be called from gnu parallel, so must use it's own variables
ocrutil2() {
	#echo "Param 1 is file: $1"
	ocrutil2_page=$1
	#echo "Param 2 is tmp dir: $2"
	ocrutil2_tmpdir=$2
	#echo "Param 3 is script dir: $3"
	ocr_util2_dir=$3
	#
	file_name=$(basename $ocrutil2_page)
	file_name_witout_ext=${file_name%.*}
	# OCR to HOCR format
	tesseract -l por $ocrutil2_page $ocrutil2_tmpdir/$file_name_witout_ext hocr >/dev/null 2>"$ocrutil2_tmpdir/tess_err_$file_name_witout_ext.log"
	# Downloaded hocrTransform.py from ocrmypdf software
	python3.4 "$ocr_util2_dir"/hocrtransform.py -r 300 $ocrutil2_tmpdir/$file_name_witout_ext.hocr $ocrutil2_tmpdir/$file_name_witout_ext.pdf
	# echo "Completed character recognition on $ocrutil2_page"
}
# https://www.gnu.org/software/parallel/man.html#EXAMPLE:-Composed-commands
export -f ocrutil2

# When using cygwin, maybe we are using native PDFTK (in 64Bit, for instance). So, we have to translate path names
# Prepare PDFTK detection and vars for "translate_path_one_file"
PDFTK_NATIVE=false
if [[ $OS == *"CYGWIN"* ]]; then
	CYGPATH_PDFTK=`cygpath "$(which pdftk)"`
	if [[ $CYGPATH_PDFTK == "/cygdrive/"* ]]; then
		PDFTK_NATIVE=true  #PDFTK is Windows native
	fi
fi
#
translate_path_one_file() {
	# TODO - check if pdftk is native or cygwin based on Windows
	if [[ $OS == *"CYGWIN"* && $PDFTK_NATIVE == true ]]; then
		echo `cygpath -alw "$1"`
	else
		echo "$1"	
	fi
}

# Temp files
tmpfile=$(mktemp)
TMP_DIR=$(dirname $tmpfile)
rm $tmpfile
# echo "Temp dir is $TMP_DIR"

# Where am I?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# echo "Script dir is $DIR"

# A random prefix to support multiple execution in parallel
PREFIX=`cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 5`
# echo $PREFIX

FILE_TYPE=`file "$INPUT_FILE"`
#echo $FILE_TYPE 

if [[ $FILE_TYPE == *"PDF"* ]]; then
	# Create images from PFDF
	pdftoppm -r 300 "$INPUT_FILE" $TMP_DIR/$PREFIX
	# File extension generated
	EXT_IMG=ppm
else
	if [[ $FILE_TYPE == *"TIFF"* || $FILE_TYPE == *"JPEG"* ]]; then
		convert "$INPUT_FILE" -scene 1 $TMP_DIR/$PREFIX-%d.pbm
		# File extension generated
		EXT_IMG=pbm
		# Deskew test - TODO add command line option to user choose to deskew
		# echo "Applying deskew"
		mogrify -deskew 40% $TMP_DIR/$PREFIX-*.pbm
	else
		echo "$FILE_TYPE is not supported in this script. Exiting"
		exit 1
	fi
fi

# Gnu Parallel (trust me, it speed up things here)
ls "$TMP_DIR"/"$PREFIX"*."$EXT_IMG" | awk -v tmp_dir="$TMP_DIR" -v script_dir="$DIR" '{ print $1"*"tmp_dir"*"script_dir }' | sort | parallel --colsep '\*' 'ocrutil2 {1} {2} {3}'

# Join PDF files into one file that contains all OCR "backgrounds"
PARAM_1_JOIN=`translate_path_one_file $TMP_DIR`
PARAM_2_JOIN=`translate_path_one_file $TMP_DIR/$PREFIX-ocr.pdf`
pdftk "$PARAM_1_JOIN"/"$PREFIX"*.pdf output "$PARAM_2_JOIN"

# Check if original PDF has some kind of protection
PDF_PROTECTED=0
PARAM_IN_PROTECT=`translate_path_one_file "$INPUT_FILE"`
pdftk "$PARAM_IN_PROTECT" dump_data output /dev/null dont_ask 2>/dev/null || PDF_PROTECTED=1

OUTPUT_NAME=$(basename "$INPUT_FILE")
OUTPUT_NAME_NO_EXT=${OUTPUT_NAME%.*}
OUTPUT_DIR=$(complete_path "$INPUT_FILE")

if [ "$PDF_PROTECTED" = "0" ]; then
	# Merge OCR background PDF into the main PDF document
	PARAM_1_MERGE=`translate_path_one_file "$INPUT_FILE"`
	PARAM_2_MERGE=`translate_path_one_file $TMP_DIR/$PREFIX-ocr.pdf`
	PARAM_3_MERGE=`translate_path_one_file "$OUTPUT_DIR/$OUTPUT_NAME_NO_EXT"-OCR.pdf`
	pdftk "$PARAM_1_MERGE" multibackground "$PARAM_2_MERGE" output "$PARAM_3_MERGE"
else
	echo "Original file is not an unprotected PDF. I will rebuild it (in black and white) from images  (maybe a bigger file will be generated)..."
	convert $TMP_DIR/$PREFIX*.$EXT_IMG -compress Group4 $TMP_DIR/$PREFIX-input_unprotected.pdf
	PARAM_1_REBUILD=`translate_path_one_file $TMP_DIR/$PREFIX-input_unprotected.pdf`
	PARAM_2_REBUILD=`translate_path_one_file $TMP_DIR/$PREFIX-ocr.pdf`
	PARAM_3_REBUILD=`translate_path_one_file "$OUTPUT_DIR/$OUTPUT_NAME_NO_EXT"-OCR.pdf`
	pdftk "$PARAM_1_REBUILD" multibackground "$PARAM_2_REBUILD" output "$PARAM_3_REBUILD"
fi

# Cleanup (comment to preserve temp files and debug)
rm -f $TMP_DIR/$PREFIX*.hocr $TMP_DIR/$PREFIX*.$EXT_IMG $TMP_DIR/$PREFIX*.txt $TMP_DIR/$PREFIX*.pdf $TMP_DIR/tess_err*.log $TMP_DIR/$PREFIX-ocr.pdf
#
echo "Success!"
exit 0
#