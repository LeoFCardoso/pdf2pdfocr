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
# Must be a TIFF or PDF
INPUT_FILE=$1

# Global var to check operating system
OS=`uname -s`

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
    echo "Character recognition on $ocrutil2_page"
    tesseract -l por $ocrutil2_page $ocrutil2_tmpdir/$file_name_witout_ext hocr >/dev/null 2>"$ocrutil2_tmpdir/tess_err_$file_name_witout_ext.log"
    # Downloaded hocrTransform.py from ocrmypdf software
    python3.4 "$ocr_util2_dir"/hocrtransform.py -r 300 $ocrutil2_tmpdir/$file_name_witout_ext.hocr $ocrutil2_tmpdir/$file_name_witout_ext.pdf
}
# https://www.gnu.org/software/parallel/man.html#EXAMPLE:-Composed-commands
export -f ocrutil2

# When using cygwin, maybe we are using some native tools. So, we have to translate path names
translate_path() {
    # TODO - check if pdftk is native or cygwin based on Windows
	if [[ $OS == *"CYGWIN"* ]]; then
		echo `cygpath -w $1`
	else
		echo $1	
	fi
}

# Temp files
tmpfile=$(mktemp)
TMP_DIR=$(dirname $tmpfile)
rm $tmpfile
echo "Temp dir is $TMP_DIR"

# Where am I?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Script dir is $DIR"

# A random prefix to support multiple execution in parallel
PREFIX=`cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 5`
# echo $PREFIX

FILE_TYPE=`file "$INPUT_FILE"`
#echo $FILE_TYPE 

if [[ $FILE_TYPE == *"TIFF"* ]]; then
	convert "$INPUT_FILE" -scene 1 $TMP_DIR/$PREFIX-%d.pbm
	# File extension generated
	EXT_IMG=pbm
	# Trying to use unpaper - can't use it in windows. So, commenting lines
	# echo "Applying unpaper in images..."
	# unpaper $TMP_DIR/$PREFIX-%1d.pbm $TMP_DIR/"$PREFIX"_unp-%1d.pbm --verbose > /dev/null
	# rm $TMP_DIR/$PREFIX-*.pbm
fi

if [[ $FILE_TYPE == *"PDF"* ]]; then
	# Create images from PFDF
	pdftoppm -r 300 "$INPUT_FILE" $TMP_DIR/$PREFIX
	# File extension generated
	EXT_IMG=ppm
fi

# Gnu Parallel (trust me, it speed up things here)
ls $TMP_DIR/$PREFIX*.$EXT_IMG | awk -v tmp_dir="$TMP_DIR" -v script_dir="$DIR" '{ print $1"*"tmp_dir"*"script_dir }' | sort | parallel --colsep '\*' -j 20 'ocrutil2 {1} {2} {3}'

# Join PDF files into one file that contains all OCR "backgrounds"
pdftk `translate_path $TMP_DIR/$PREFIX*.pdf` output `translate_path $TMP_DIR/$PREFIX-ocr.pdf`

# Check if original PDF has some kind of protection
PDF_PROTECTED=0
pdftk `translate_path "$INPUT_FILE"` dump_data output /dev/null dont_ask 2>/dev/null || PDF_PROTECTED=1

OUTPUT_NAME=$(basename "$INPUT_FILE")
OUTPUT_NAME_NO_EXT=${OUTPUT_NAME%.*}

if [ "$PDF_PROTECTED" = "0" ]; then
	# Merge OCR background PDF into the main PDF document
	pdftk `translate_path "$INPUT_FILE"` multibackground `translate_path $TMP_DIR/$PREFIX-ocr.pdf` output `translate_path "$OUTPUT_NAME_NO_EXT"-OCR.pdf`
else
    echo "Original file is TIFF or PDF protected by password. I will recompose it in black and white from images  (maybe a bigger file will be generated)..."
    convert $TMP_DIR/$PREFIX*.$EXT_IMG -compress Group4 $TMP_DIR/$PREFIX-input_unprotected.pdf
    pdftk `translate_path $TMP_DIR/$PREFIX-input_unprotected.pdf` multibackground `translate_path $TMP_DIR/$PREFIX-ocr.pdf` output `translate_path "$OUTPUT_NAME_NO_EXT"-OCR.pdf`
fi

# Cleanup (comment to preserve temp files and debug)
rm -f $TMP_DIR/$PREFIX*.hocr $TMP_DIR/$PREFIX*.$EXT_IMG $TMP_DIR/$PREFIX*.txt $TMP_DIR/$PREFIX*.pdf $TMP_DIR/tess_err*.log $TMP_DIR/$PREFIX-ocr.pdf
#