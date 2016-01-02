#!/bin/bash

# OCR a PDF and add a text "layer" in the original file.
# Use only open source tools.
# Unless requested, does not re-encode the images inside an unprotected PDF file.
# Leonardo Cardoso - inspired in ocrmypdf (https://github.com/jbarlow83/OCRmyPDF)
# and this post: https://github.com/jbarlow83/OCRmyPDF/issues/8

# Dependencies:
# Tesseract-OCR and Tesseract-OCR-por (Portuguese+English are hardcoded by now)
# Python3 (and ReportLab)
# OCRMYPDF (for the great hocrtransform.py script) - https://github.com/jbarlow83/OCRmyPDF/blob/master/ocrmypdf/hocrtransform.py
# Poppler (and xpdf)
# Gnu Parallel
# PDFtk Server (in Cygwin only available in '32 bits'. In Cygwin64, you must use native pdftk)
# ImageMagick

usage_and_exit() {
	echo "Usage: $0 [-s] [-t] [-f] [-d <threshold_percent>] [-o <output file>] <input file>" 1>&2
	echo " -s -> safe mode. Does not overwrite output OCR file."  1>&2
	echo " -t -> check text mode. Does not process if source PDF already has text."  1>&2
	echo " -f -> force PDF rebuild in B&W from images."  1>&2
	echo " -d -> only for images - use image magick deskew before OCR. <threshold_percent> should be a percent, e.g. '40%'."  1>&2
	echo " -o -> Force output file to the specified location."  1>&2
	exit 1
}

# Return complete path of argument, except last level (filename or dirname)
complete_path() {
	local DIR_NAME_1=`dirname "$1"`
	pushd "$DIR_NAME_1" > /dev/null
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
	tesseract -l por+eng $ocrutil2_page $ocrutil2_tmpdir/$file_name_witout_ext hocr >/dev/null 2>"$ocrutil2_tmpdir/tess_err_$file_name_witout_ext.log"
	# Downloaded hocrTransform.py from ocrmypdf software
	python3.4 "$ocr_util2_dir"/hocrtransform.py -r 300 $ocrutil2_tmpdir/$file_name_witout_ext.hocr $ocrutil2_tmpdir/$file_name_witout_ext.pdf
	# echo "Completed character recognition on $ocrutil2_page"
}
# https://www.gnu.org/software/parallel/man.html#EXAMPLE:-Composed-commands
export -f ocrutil2

# When using cygwin, maybe we are using native PDFTK (in 64Bit, for instance). So, we have to translate path names
# Prepare PDFTK detection and vars for "translate_path_one_file"
OS=`uname -s`   # Global var to check operating system
PDFTK_NATIVE=false
if [[ $OS == *"CYGWIN"* ]]; then
	CYGPATH_PDFTK=`cygpath "$(which pdftk)"`
	if [[ $CYGPATH_PDFTK == "/cygdrive/"* ]]; then
		PDFTK_NATIVE=true  #PDFTK is Windows native
	fi
fi
#
translate_path_one_file() {
	if [[ $OS == *"CYGWIN"* && $PDFTK_NATIVE == true ]]; then
		echo `cygpath -alw "$1"`
	else
		echo "$1"	
	fi
}

## Parameters
#############
OPTIND=1   # Reset just in case
while getopts ":stfd:o:" opt; do
	case $opt in
		s)
			SAFE_MODE=true
		;;
		t)
			CHECK_TEXT_MODE=true
		;;
		f)
			FORCE_REBUILD_MODE=true
		;;
		d)
			USE_DESKEW_MODE=true
			DESKEW_THRESHOLD="${OPTARG}"
		;;
		o)
			FORCE_OUT_MODE=true
			FORCE_OUT_FILE="${OPTARG}"
		;;
		\?)
			usage_and_exit
		;;
	esac
done
# Adjust mass arguments
shift $((OPTIND - 1))

## Main
#######

# This is the file to be transformed
# Must be supported image or PDF
INPUT_FILE=$1

if [[ $CHECK_TEXT_MODE == true ]]; then
	PDF_FONTS=$(pdffonts "$INPUT_FILE" 2>/dev/null | tail -n +3 | cut -d' ' -f1 | sort | uniq)
	if ! ( [ "$PDF_FONTS" = '' ] || [ "$PDF_FONTS" = '[none]' ] ) ; then
		echo "$INPUT_FILE already has text and check text mode is enabled. Exiting." 1>&2
		exit 1
	fi
fi

# This is the output file
if [[ $FORCE_OUT_MODE == true ]]; then
	OUTPUT_FILE="$FORCE_OUT_FILE"
else
	OUTPUT_NAME=$(basename "$INPUT_FILE")
	OUTPUT_NAME_NO_EXT=${OUTPUT_NAME%.*}
	OUTPUT_DIR=$(complete_path "$INPUT_FILE")
	OUTPUT_FILE="$OUTPUT_DIR/$OUTPUT_NAME_NO_EXT"-OCR.pdf
fi

if [[ $SAFE_MODE == true && -e "$OUTPUT_FILE" ]]; then
	echo "$OUTPUT_FILE already exists and safe mode is enabled. Exiting." 1>&2
	exit 1
fi

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

FILE_TYPE=`file -b "$INPUT_FILE"`
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
		if [[ $USE_DESKEW_MODE == true ]]; then
			# echo "Applying deskew"
			mogrify -deskew "$DESKEW_THRESHOLD" $TMP_DIR/$PREFIX-*.pbm
		fi
	else
		echo "$FILE_TYPE is not supported in this script. Exiting." 1>&2
		exit 1
	fi
fi

# Gnu Parallel (trust me, it speed up things here)
ls "$TMP_DIR"/"$PREFIX"*."$EXT_IMG" | awk -v tmp_dir="$TMP_DIR" -v script_dir="$DIR" '{ print $1"*"tmp_dir"*"script_dir }' | sort | parallel --colsep '\*' 'ocrutil2 {1} {2} {3}'

# Join PDF files into one file that contains all OCR "backgrounds"
PARAM_1_JOIN=`translate_path_one_file $TMP_DIR`
PARAM_2_JOIN=`translate_path_one_file $TMP_DIR/$PREFIX-ocr.pdf`
PARAM_3_JOIN=`translate_path_one_file $TMP_DIR/err_pdftk-$PREFIX-join.log`
pdftk "$PARAM_1_JOIN"/"$PREFIX"*.pdf output "$PARAM_2_JOIN" 2>"$PARAM_3_JOIN"

# Check if original PDF has some kind of protection
PDF_PROTECTED=0
PARAM_IN_PROTECT=`translate_path_one_file "$INPUT_FILE"`
pdftk "$PARAM_IN_PROTECT" dump_data output /dev/null dont_ask 2>/dev/null || PDF_PROTECTED=1

if [[ "$PDF_PROTECTED" == "0" && $FORCE_REBUILD_MODE == false ]]; then
	# Merge OCR background PDF into the main PDF document
	PARAM_1_MERGE=`translate_path_one_file "$INPUT_FILE"`
	PARAM_2_MERGE=`translate_path_one_file $TMP_DIR/$PREFIX-ocr.pdf`
	PDF_OUTPUT_TMP=`translate_path_one_file $TMP_DIR/$PREFIX-OUTPUT.pdf`
	PARAM_4_MERGE=`translate_path_one_file $TMP_DIR/err_pdftk-$PREFIX-merge.log`
	ORIGINAL_PRODUCER=`pdftk "$PARAM_1_MERGE" dump_data | grep -A 1 "Producer" | grep -v "Producer" | cut -d ' ' -f '2-'`
	pdftk "$PARAM_1_MERGE" multibackground "$PARAM_2_MERGE" output "$PDF_OUTPUT_TMP" 2>"$PARAM_4_MERGE"
else
	echo "Original file is not an unprotected PDF (or forcing rebuild). I will rebuild it (in black and white) from extracted images..."
	# TODO - maybe let user override these convert settings
	# Please read http://www.imagemagick.org/Usage/quantize/#colors_two
	# Better and bigger files:
	## convert $TMP_DIR/$PREFIX*.$EXT_IMG -colors 2 -colorspace gray -normalize -threshold 60% -compress Group4 $TMP_DIR/$PREFIX-input_unprotected.pdf
	# Faster conversion, smaller files, less details:
	convert $TMP_DIR/$PREFIX*.$EXT_IMG -threshold 60% -compress Group4 $TMP_DIR/$PREFIX-input_unprotected.pdf
	PARAM_1_REBUILD=`translate_path_one_file $TMP_DIR/$PREFIX-input_unprotected.pdf`
	PARAM_2_REBUILD=`translate_path_one_file $TMP_DIR/$PREFIX-ocr.pdf`
	PDF_OUTPUT_TMP=`translate_path_one_file $TMP_DIR/$PREFIX-OUTPUT.pdf`
	PARAM_4_REBUILD=`translate_path_one_file $TMP_DIR/err_pdftk-$PREFIX-rebuild.log`
	unset ORIGINAL_PRODUCER     # Here, there is no original producer
	pdftk "$PARAM_1_REBUILD" multibackground "$PARAM_2_REBUILD" output "$PDF_OUTPUT_TMP" 2>"$PARAM_4_REBUILD"
fi

# Adjust PDF producer (and title) information.
OUR_NAME="PDF2PDFOCR(github.com/LeoFCardoso/pdf2pdfocr)"
if [ -z "$ORIGINAL_PRODUCER" ]; then
	# Set title and producer
	NEW_TITLE=$(basename "$OUTPUT_FILE")
	echo -e "InfoBegin\nInfoKey: Title\nInfoValue: $NEW_TITLE\nInfoBegin\nInfoKey: Producer\nInfoValue: $OUR_NAME" > $TMP_DIR/$PREFIX-pdfdata.txt
else
	echo -e "InfoBegin\nInfoKey: Producer\nInfoValue: $ORIGINAL_PRODUCER; $OUR_NAME" > $TMP_DIR/$PREFIX-pdfdata.txt
fi
PARAM_1_PRODUCER=`translate_path_one_file $TMP_DIR/$PREFIX-pdfdata.txt`
PARAM_2_PRODUCER=`translate_path_one_file "$OUTPUT_FILE"`
PARAM_3_PRODUCER=`translate_path_one_file $TMP_DIR/err_pdftk-$PREFIX-producer.log`
pdftk "$PDF_OUTPUT_TMP" update_info "$PARAM_1_PRODUCER" output "$PARAM_2_PRODUCER" 2>"$PARAM_3_PRODUCER"

# Adjust the new file timestamp
touch -r "$INPUT_FILE" "$OUTPUT_FILE"

# Cleanup (comment to preserve temp files and debug)
rm -f $TMP_DIR/$PREFIX*.hocr $TMP_DIR/$PREFIX*.$EXT_IMG $TMP_DIR/$PREFIX*.txt $TMP_DIR/$PREFIX*.pdf $TMP_DIR/tess_err*.log $TMP_DIR/err_pdftk*.log $TMP_DIR/$PREFIX-ocr.pdf
#
echo "Success!"
exit 0
#