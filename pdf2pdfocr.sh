#!/bin/bash

# OCR a PDF and add a text "layer" in the original file.
# Use only open source tools.
# Unless requested, does not re-encode the images inside an unprotected PDF file.
# Leonardo Cardoso - inspired in ocrmypdf (https://github.com/jbarlow83/OCRmyPDF)
# and this post: https://github.com/jbarlow83/OCRmyPDF/issues/8

# Dependencies:
# Tesseract-OCR and Tesseract-OCR-por (Portuguese+English are hardcoded by now)
# Python3 (ReportLab / pypdf2)
# OCRMYPDF (for the great hocrtransform.py script) - https://github.com/jbarlow83/OCRmyPDF/blob/master/ocrmypdf/hocrtransform.py
# Poppler (and xpdf)
# Gnu Parallel
# ImageMagick

usage_and_exit() {
	cat 1>&2 <<EOF
Usage: $0 [-s] [-t] [-f] [-g <convert_parameters>] [-d <threshold_percent>] [-o <output file>] <input file>
-s -> safe mode. Does not overwrite output OCR file.
-t -> check text mode. Does not process if source PDF already has text. 
-f -> force PDF rebuild from extracted images.
-g -> with images or '-f', use presets or force parameters when calling 'convert' to build the final PDF file.
      Examples:
      -g p1 -> a fast bitonal file ("-threshold 60% -compress Group4")
      -g p2 -> best quality, but bigger bitonal file ("-colors 2 -colorspace gray -normalize -threshold 60% -compress Group4")
      -g p3 -> good bitonal file from grayscale documents ("-threshold 85% -morphology Dilate Diamond -compress Group4")
      -g "-threshold 60% -compress Group4" -> direct apply these parameters (DON'T FORGET TO USE QUOTATION MARKS)
      Note, without -g, preset p1 is used.
-d -> only for images - use image magick deskew *before* OCR. <threshold_percent> should be a percent, e.g. '40%'.
-o -> Force output file to the specified location.
EOF
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

## Parameters
#############
# Reset variables
OPTIND=1
SAFE_MODE=false
CHECK_TEXT_MODE=false
FORCE_REBUILD_MODE=false
USE_DESKEW_MODE=false
FORCE_OUT_MODE=false
USER_CONVERT_PARAMS=""
while getopts ":stfg:d:o:" opt; do
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
		g)
			USER_CONVERT_PARAMS="${OPTARG}"
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
if [[ ! -e  "$INPUT_FILE" ]]; then
	echo "$INPUT_FILE not found. Exiting."
	exit 1
fi

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
# Initial cleanup
rm "$OUTPUT_FILE" >/dev/null 2>&1

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
		# File extension generated
		EXT_IMG=jpg
		convert "$INPUT_FILE" -scene 1 $TMP_DIR/$PREFIX-%d.$EXT_IMG
		if [[ $USE_DESKEW_MODE == true ]]; then
			# echo "Applying deskew"
			mogrify -deskew "$DESKEW_THRESHOLD" $TMP_DIR/$PREFIX-*.$EXT_IMG
		fi
	else
		echo "$FILE_TYPE is not supported in this script. Exiting." 1>&2
		exit 1
	fi
fi

# Gnu Parallel (trust me, it speed up things here)
ls "$TMP_DIR"/"$PREFIX"*."$EXT_IMG" | awk -v tmp_dir="$TMP_DIR" -v script_dir="$DIR" '{ print $1"*"tmp_dir"*"script_dir }' | sort | parallel -j -1 --colsep '\*' 'ocrutil2 {1} {2} {3}'

# Join PDF files into one file that contains all OCR "backgrounds"
# -> pdfunite from poppler
pdfunite "$TMP_DIR"/"$PREFIX"*.pdf "$TMP_DIR/$PREFIX-ocr.pdf" 2>"$TMP_DIR/err_pdfunite-$PREFIX-join.log"

# Check if original PDF has some kind of protection (with pdfinfo from poppler)
PDF_PROTECTED=1
ENCRYPTION_INFO=`pdfinfo "$INPUT_FILE" 2>/dev/null | grep "Encrypted" | xargs | cut -d ' ' -f 2`
if [[ "$ENCRYPTION_INFO" == "no" ]]; then
	PDF_PROTECTED=0
fi

if [[ "$PDF_PROTECTED" == "0" && $FORCE_REBUILD_MODE == false ]]; then
	# Merge OCR background PDF into the main PDF document
	python3.4 "$DIR"/pdf2pdfocr_multibackground.py "$INPUT_FILE" "$TMP_DIR/$PREFIX-ocr.pdf" "$TMP_DIR/$PREFIX-OUTPUT.pdf" 2>"$TMP_DIR/err_multiback-$PREFIX-merge.log"
else
	echo "Original file is not an unprotected PDF (or forcing rebuild). I will rebuild it (in black and white) from extracted images..."
	# Convert presets
	# Please read http://www.imagemagick.org/Usage/quantize/#colors_two
	PRESET_P1="-threshold 60% -compress Group4"
	PRESET_P2="-colors 2 -colorspace gray -normalize -threshold 60% -compress Group4"
	PRESET_P3="-threshold 85% -morphology Dilate Diamond -compress Group4"
	#
	case "$USER_CONVERT_PARAMS" in
		p1) CONVERT_PARAMS="$PRESET_P1" ;;
		p2) CONVERT_PARAMS="$PRESET_P2" ;;
		p3) CONVERT_PARAMS="$PRESET_P3" ;;
		*) CONVERT_PARAMS="$USER_CONVERT_PARAMS" ;;
	esac
	if [[ $CONVERT_PARAMS == "" ]]; then
		CONVERT_PARAMS="$PRESET_P1"
	fi
	#
	convert $TMP_DIR/$PREFIX*.$EXT_IMG $CONVERT_PARAMS $TMP_DIR/$PREFIX-input_unprotected.pdf
	python3.4 "$DIR"/pdf2pdfocr_multibackground.py "$TMP_DIR/$PREFIX-input_unprotected.pdf" "$TMP_DIR/$PREFIX-ocr.pdf" "$TMP_DIR/$PREFIX-OUTPUT.pdf" 2>"$TMP_DIR/err_multiback-$PREFIX-rebuild.log"
fi

# Copy the output file
cp "$TMP_DIR/$PREFIX-OUTPUT.pdf" "$OUTPUT_FILE"

# Adjust the new file timestamp
touch -r "$INPUT_FILE" "$OUTPUT_FILE"

# Cleanup (comment to preserve temp files and debug)
rm -f $TMP_DIR/$PREFIX*.hocr $TMP_DIR/$PREFIX*.$EXT_IMG $TMP_DIR/$PREFIX*.txt $TMP_DIR/$PREFIX*.pdf $TMP_DIR/tess_err*.log $TMP_DIR/err_multiback*.log $TMP_DIR/err_pdfunite*.log $TMP_DIR/$PREFIX-ocr.pdf
#
echo "Success!"
exit 0
#