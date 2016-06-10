#!/bin/bash

# OCR a PDF and add a text "layer" in the original file (a so called "pdf sandwich")
# Use only open source tools.
# Unless requested, does not re-encode the images inside an unprotected PDF file.
# Leonardo Cardoso - inspired in ocrmypdf (https://github.com/jbarlow83/OCRmyPDF)
# and this post: https://github.com/jbarlow83/OCRmyPDF/issues/8

# Dependencies:
# ------------
# Tesseract-OCR and Tesseract-OCR-por
# Python3 (ReportLab / pypdf2)
# OCRMYPDF (for the great hocrtransform.py script) - https://github.com/jbarlow83/OCRmyPDF/blob/master/ocrmypdf/hocrtransform.py
# Poppler (and xpdf)
# Gnu Parallel
# ImageMagick
# Dos2unix (only in windows - cygwin)
#
# Optional dependencies:
# ---------------------
# pdftk - only if user want to force pdftk to do the final multibackground (overlay) -p flag
#

usage_and_exit() {
	cat 1>&2 <<EOF
Usage: $0 [-s] [-t] [-a] [-f] [-g <convert_parameters>] [-d <threshold_percent>] [-j <parallel_percent>] [-w] [-o <output file>] [-p] [-l <langs>] [-m <pagesegmode>] [-u] [-k] [-v] <input file>
-s -> safe mode. Does not overwrite output [PDF | TXT] OCR file.
-t -> check text mode. Does not process if source PDF already has text.
-a -> check encryption mode. Does not process if source PDF is protected.
-f -> force PDF rebuild from extracted images.
-g -> with images or '-f', use presets or force parameters when calling 'convert' to build the final PDF file.
      Examples:
      -g fast -> a fast bitonal file ("-threshold 60% -compress Group4")
      -g best -> best quality, but bigger bitonal file ("-colors 2 -colorspace gray -normalize -threshold 60% -compress Group4")
      -g grayscale -> good bitonal file from grayscale documents ("-threshold 85% -morphology Dilate Diamond -compress Group4")
      -g jpeg -> keep original color image as JPEG ("-strip -interlace Plane -gaussian-blur 0.05 -quality 50% -compress JPEG")
      -g "-threshold 60% -compress Group4" -> direct apply these parameters (DON'T FORGET TO USE QUOTATION MARKS)
      Note, without -g, preset 'best' is used.
-d -> use imagemagick deskew *before* OCR. <threshold_percent> should be a percent, e.g. '40%'. No effect with unprotected pdf's without '-f' flag.
-j -> Run this many jobs in parallel for OCR and DESKEW. Multiply with the number of CPU cores. (default = 100% [all cores])
-w -> Create also a text file at same location of PDF OCR file.
-o -> Force output file to the specified location.
-p -> Force the use of pdftk tool to do the final overlay of files.
-l -> Force tesseract to use specific languages (default: por+eng).
-m -> Force tesseract to use HOCR with specific "pagesegmode" (default: tesseract HOCR default = 1). Use with caution.
-u -> Enable bash debug mode.
-k -> Keep temporary files for debug.
-v -> Enable verbose mode.
EOF
	exit 1
}

# Debug messages
DEBUG() {
	if [[ $VERBOSE_MODE == true ]]; then
		local msg="$1"
		local tstamp=`date`
		echo -e "[$tstamp] [DEBUG]\t$msg"
	fi
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
	ocrutil2_page=$1
	ocrutil2_tmpdir=$2
	ocr_util2_dir=$3
	ocr_util2_tesseract_lang=$4
	ocr_util2_tesseract_psm=$5
	#
	file_name=$(basename $ocrutil2_page)
	file_name_witout_ext=${file_name%.*}
	# OCR to HOCR format
	# TODO - learn to uniform font sizes (bounding box) in hocr
	# TODO - expert mode - let user pass tesseract custom parameters
	tesseract -l $ocr_util2_tesseract_lang -c tessedit_create_hocr=1 -c tessedit_create_txt=1 -c tessedit_pageseg_mode=$ocr_util2_tesseract_psm $ocrutil2_page $ocrutil2_tmpdir/$file_name_witout_ext >/dev/null 2>"$ocrutil2_tmpdir/tess_err_$file_name_witout_ext.log"
	# Downloaded hocrTransform.py from ocrmypdf software
	python3.4 "$ocr_util2_dir"/hocrtransform.py -r 300 $ocrutil2_tmpdir/$file_name_witout_ext.hocr $ocrutil2_tmpdir/$file_name_witout_ext.pdf
}
# https://www.gnu.org/software/parallel/man.html#EXAMPLE:-Composed-commands
export -f ocrutil2

# Function to remove temps
cleanup() {
	if [[ $DELETE_TEMPS == true ]]; then
		rm -f $TMP_DIR/$PREFIX*.hocr $TMP_DIR/$PREFIX*.$EXT_IMG $TMP_DIR/$PREFIX*.txt $TMP_DIR/$PREFIX*.ps $TMP_DIR/$PREFIX*.pdf $TMP_DIR/tess_err*.log $TMP_DIR/err_multiback*.log $TMP_DIR/err_pdf2ps*.log $TMP_DIR/err_ps2pdf*.log $TMP_DIR/err_pdfunite*.log $TMP_DIR/err_pdftk*.log $TMP_DIR/$PREFIX-ocr.pdf
	else
		echo "Temporary files kept in $TMP_DIR" 1>&2
	fi
}

## Parameters
#############
# Reset variables
OPTIND=1
SAFE_MODE=false
CHECK_TEXT_MODE=false
CHECK_PROTECTION_MODE=false
FORCE_REBUILD_MODE=false
USE_DESKEW_MODE=false
PARALLEL_THRESHOLD="100%"
FORCE_OUT_MODE=false
USER_CONVERT_PARAMS=""
DEBUG_MODE=false
CREATE_TEXT_MODE=false
DELETE_TEMPS=true
USE_PDFTK=false
TESS_LANGS="por+eng"
TESS_PSM="1"
VERBOSE_MODE=false
while getopts ":stafg:d:j:wo:pl:m:ukv" opt; do
	case $opt in
		s)
			SAFE_MODE=true
		;;
		t)
			CHECK_TEXT_MODE=true
		;;
		a)
			CHECK_PROTECTION_MODE=true
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
		j)
			PARALLEL_THRESHOLD="${OPTARG}"
		;;
		w)
			CREATE_TEXT_MODE=true
		;;
		o)
			FORCE_OUT_MODE=true
			FORCE_OUT_FILE="${OPTARG}"
		;;
		p)
			USE_PDFTK=true
		;;
		l)
			TESS_LANGS="${OPTARG}"
		;;
		m)
			TESS_PSM="${OPTARG}"
		;;
		u)
			DEBUG_MODE=true
		;;
		k)
			DELETE_TEMPS=false
		;;
		v)
			VERBOSE_MODE=true
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

if [[ $DEBUG_MODE == true ]]; then
	set -x
fi

# Handle pdftk stuff
if [[ $USE_PDFTK == true ]]; then
	PDFTK_PATH=$(which pdftk)
	if [[ "$PDFTK_PATH" == "" ]]; then
		echo "pdftk tool not installed. Try to run without '-p' flag. Exiting..." 1>&2
		cleanup
		exit 1
	fi
	# When using cygwin, maybe we are using native pdftk (in 64Bit, for instance). 
	# So, we have to translate path names.
	# Prepare pdftk vars for "translate_path_one_file"
	OS=$(uname -s)   # Global var to check operating system
	PDFTK_WINDOWS_NATIVE=false
	if [[ "$OS" == *"CYGWIN"* ]]; then
		CYGPATH_PDFTK=`cygpath "$(which pdftk)"`
		if [[ $CYGPATH_PDFTK == "/cygdrive/"* ]]; then
			PDFTK_WINDOWS_NATIVE=true  #pdftk is Windows native
		fi
	fi
	# Function to translate file paths for windows / posix
	translate_path_one_file() {
		if [[ $OS == *"CYGWIN"* && $PDFTK_WINDOWS_NATIVE == true ]]; then
			echo `cygpath -alw "$1"`
		else
			echo "$1"	
		fi
	}
	#
fi

# This is the file to be transformed
# Must be supported image or PDF
INPUT_FILE=$1
if [[ ! -e  "$INPUT_FILE" ]]; then
	echo "$INPUT_FILE not found. Exiting." 1>&2
	cleanup
	exit 1
fi

FILE_TYPE=`file -b "$INPUT_FILE"`
DEBUG "Input file $INPUT_FILE: type is $FILE_TYPE" 

if [[ $FILE_TYPE == *"PDF"* && $CHECK_TEXT_MODE == true ]]; then
	PDF_FONTS=$(pdffonts "$INPUT_FILE" 2>/dev/null | tail -n +3 | cut -d' ' -f1 | sort | uniq)
	if ! ( [ "$PDF_FONTS" = '' ] || [ "$PDF_FONTS" = '[none]' ] ) ; then
		echo "$INPUT_FILE already has text and check text mode is enabled. Exiting." 1>&2
		cleanup
		exit 1
	fi
fi

ENCRYPTION_INFO="empty"   # init value
if [[ $FILE_TYPE == *"PDF"* ]]; then 
	ENCRYPTION_INFO=`pdfinfo "$INPUT_FILE" 2>/dev/null | grep "Encrypted" | xargs | cut -d ' ' -f 2`
fi

# Check protection mode
if [[ $CHECK_PROTECTION_MODE == true && "$ENCRYPTION_INFO" == "yes" ]]; then
	echo "$INPUT_FILE is encrypted PDF and check encryption mode is enabled. Exiting." 1>&2
	cleanup
	exit 1
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

# Text output file name (-w option)
OUTPUT_FILE_TEXT="$OUTPUT_FILE".txt

if [[ ( $SAFE_MODE == true && -e "$OUTPUT_FILE" ) || ( $SAFE_MODE == true && $CREATE_TEXT_MODE == true && -e "$OUTPUT_FILE_TEXT" ) ]]; then
	if [[ -e "$OUTPUT_FILE" ]]; then
		echo "$OUTPUT_FILE already exists and safe mode is enabled. Exiting." 1>&2
	fi
	if [[ $CREATE_TEXT_MODE == true && -e "$OUTPUT_FILE_TEXT" ]]; then
		echo "$OUTPUT_FILE_TEXT already exists and safe mode is enabled. Exiting." 1>&2
	fi
	cleanup
	exit 1
fi

# Initial cleanup
rm "$OUTPUT_FILE" >/dev/null 2>&1
if [[ $CREATE_TEXT_MODE == true ]]; then
	rm "$OUTPUT_FILE_TEXT" >/dev/null 2>&1
fi

# Temp files
tmpfile=$(mktemp)
TMP_DIR=$(dirname $tmpfile)
rm $tmpfile
DEBUG "Temp dir is $TMP_DIR"

# Where am I?
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEBUG "Script dir is $DIR"

# A random prefix to support multiple execution in parallel
PREFIX=`cat /dev/urandom 2>/dev/null | env LC_CTYPE=C tr -dc a-zA-Z0-9 2>/dev/null | head -c 5 2>/dev/null`
DEBUG "Prefix is $PREFIX"

if [[ $FILE_TYPE == *"PDF"* ]]; then
	# Using jpg to avoid big temp files in pdf with a lot of pages
	# TODO - maybe create a flag to force PPM use (without -jpeg), because it's fast
	# Create images from PDF
	pdftoppm -r 300 -jpeg "$INPUT_FILE" $TMP_DIR/$PREFIX
	# File extension generated
	EXT_IMG=jpg
else
	if [[ $FILE_TYPE == *"TIFF"* || $FILE_TYPE == *"JPEG"* || $FILE_TYPE == *"PNG"* ]]; then
		# File extension generated
		EXT_IMG=jpg
		convert "$INPUT_FILE" -quality 100 -scene 1 $TMP_DIR/$PREFIX-%d.$EXT_IMG
	else
		echo "$FILE_TYPE is not supported in this script. Exiting." 1>&2
		cleanup
		exit 1
	fi
fi

if [[ $USE_DESKEW_MODE == true ]]; then
	DEBUG "Applying deskew"
	ls "$TMP_DIR"/"$PREFIX"*."$EXT_IMG" | awk '{ print $1 }' | sort | parallel -j "$PARALLEL_THRESHOLD" --colsep '\*' mogrify -deskew "$DESKEW_THRESHOLD" :::
fi

# Gnu Parallel (trust me, it speed up things here)
PROGRESS_IN_PARALLEL=""
if [[ $VERBOSE_MODE == true ]]; then
	PROGRESS_IN_PARALLEL="--progress"
fi
DEBUG "Starting OCR"
ls "$TMP_DIR"/"$PREFIX"*."$EXT_IMG" | awk -v tmp_dir="$TMP_DIR" -v script_dir="$DIR" -v tesseract_lang="$TESS_LANGS" -v tesseract_psm="$TESS_PSM" '{ print $1"*"tmp_dir"*"script_dir"*"tesseract_lang"*"tesseract_psm }' | sort | parallel -j "$PARALLEL_THRESHOLD" $PROGRESS_IN_PARALLEL --colsep '\*' 'ocrutil2 {1} {2} {3} {4} {5}'
DEBUG "OCR completed"

# Join PDF files into one file that contains all OCR "backgrounds"
# Workaround for bug 72720 in older poppler releases
# https://bugs.freedesktop.org/show_bug.cgi?id=72720
OCRED_PAGES=$(ls -1 "$TMP_DIR"/"$PREFIX"*.pdf | wc -l | xargs)
DEBUG "We have $OCRED_PAGES ocr'ed files"
if [[ "$OCRED_PAGES" -gt "1" ]]; then
	pdfunite "$TMP_DIR"/"$PREFIX"*.pdf "$TMP_DIR/$PREFIX-ocr.pdf" 2>"$TMP_DIR/err_pdfunite-$PREFIX-join.log"
else
	cp "$TMP_DIR"/"$PREFIX"*.pdf "$TMP_DIR/$PREFIX-ocr.pdf" 2>"$TMP_DIR/err_pdfunite-$PREFIX-join.log"
fi
DEBUG "Joined ocr'ed PDF files"

# Create final text output
if [[ $CREATE_TEXT_MODE == true ]]; then
	cat "$TMP_DIR"/"$PREFIX"*.txt 1>"$OUTPUT_FILE_TEXT"
	OS=$(uname -s)
	if [[ "$OS" == *"CYGWIN"* ]]; then
		unix2dos --quiet "$OUTPUT_FILE_TEXT"
	fi
	DEBUG "Created final text file"
fi

# Check if original PDF has some kind of protection (with pdfinfo from poppler)
REBUILD_PDF_FROM_IMAGES=1
if [[ "$ENCRYPTION_INFO" == "no" ]]; then
	REBUILD_PDF_FROM_IMAGES=0
fi

if [[ "$REBUILD_PDF_FROM_IMAGES" == "0" && $FORCE_REBUILD_MODE == false ]]; then
	# Merge OCR background PDF into the main PDF document making a PDF sandwich
	if [[ $USE_PDFTK == true ]]; then
		PARAM_1_MERGE=`translate_path_one_file "$INPUT_FILE"`
		PARAM_2_MERGE=`translate_path_one_file $TMP_DIR/$PREFIX-ocr.pdf`
		PDF_PRE_OUTPUT_TMP=`translate_path_one_file $TMP_DIR/$PREFIX-PRE-OUTPUT.pdf`
		PARAM_4_MERGE=`translate_path_one_file $TMP_DIR/err_multiback-$PREFIX-merge.log`
		ORIGINAL_PRODUCER=`pdftk "$PARAM_1_MERGE" dump_data | grep -A 1 "Producer" | grep -v "Producer" | cut -d ' ' -f '2-'`
		pdftk "$PARAM_1_MERGE" multibackground "$PARAM_2_MERGE" output "$PDF_PRE_OUTPUT_TMP" 2>"$PARAM_4_MERGE"
		# Adjust final pdf producer (and sometimes title) information.
		OUR_NAME="PDF2PDFOCR(github.com/LeoFCardoso/pdf2pdfocr)"
		if [ -z "$ORIGINAL_PRODUCER" ]; then
			# Set title and producer
			NEW_TITLE=$(basename "$OUTPUT_FILE")
			echo -e "InfoBegin\nInfoKey: Title\nInfoValue: $NEW_TITLE\nInfoBegin\nInfoKey: Producer\nInfoValue: $OUR_NAME" > $TMP_DIR/$PREFIX-pdfdata.txt
		else
			echo -e "InfoBegin\nInfoKey: Producer\nInfoValue: $ORIGINAL_PRODUCER; $OUR_NAME" > $TMP_DIR/$PREFIX-pdfdata.txt
		fi
		PARAM_1_PRODUCER=`translate_path_one_file $TMP_DIR/$PREFIX-pdfdata.txt`
		PARAM_2_PRODUCER=`translate_path_one_file $TMP_DIR/$PREFIX-OUTPUT.pdf` # Final file
		PARAM_3_PRODUCER=`translate_path_one_file $TMP_DIR/err_pdftk-$PREFIX-producer.log`
		pdftk "$PDF_PRE_OUTPUT_TMP" update_info "$PARAM_1_PRODUCER" output "$PARAM_2_PRODUCER" 2>"$PARAM_3_PRODUCER"
	else
		# python simple overlay implementation - also adjust producer
		python3.4 "$DIR"/pdf2pdfocr_multibackground.py "$INPUT_FILE" "$TMP_DIR/$PREFIX-ocr.pdf" "$TMP_DIR/$PREFIX-OUTPUT.pdf" 2>"$TMP_DIR/err_multiback-$PREFIX-merge.log"
		# Sometimes, the above script fail with some malformed PDF files. The code below
		# try to rewrite source PDF and run it again.
		if [[ ! -e  "$TMP_DIR/$PREFIX-OUTPUT.pdf" ]]; then
			DEBUG "Fail to merge source PDF with extracted OCR text. Trying to fix source PDF to build final file..."
			echo "Warning: metadata wiped from final PDF file (due to possibly malformed source PDF)" 1>&2
			pdf2ps "$INPUT_FILE" "$TMP_DIR/$PREFIX-fixPDF.ps" 2>"$TMP_DIR/err_pdf2ps-$PREFIX.log"
			ps2pdf "$TMP_DIR/$PREFIX-fixPDF.ps" "$TMP_DIR/$PREFIX-fixPDF.pdf" 2>"$TMP_DIR/err_ps2pdf-$PREFIX.log"
			# TODO try to preserve input file metadata
			python3.4 "$DIR"/pdf2pdfocr_multibackground.py "$TMP_DIR/$PREFIX-fixPDF.pdf" "$TMP_DIR/$PREFIX-ocr.pdf" "$TMP_DIR/$PREFIX-OUTPUT.pdf" 2>"$TMP_DIR/err_multiback-$PREFIX-merge-fixed.log"
		fi
	fi
else
	echo "Warning: metadata wiped from final PDF file (original file is not an unprotected PDF or forcing rebuild from extracted images)" 1>&2
	# Convert presets
	# Please read http://www.imagemagick.org/Usage/quantize/#colors_two
	PRESET_FAST="-threshold 60% -compress Group4"
	PRESET_BEST="-colors 2 -colorspace gray -normalize -threshold 60% -compress Group4"
	PRESET_GRAYSCALE="-threshold 85% -morphology Dilate Diamond -compress Group4"
	PRESET_JPEG="-strip -interlace Plane -gaussian-blur 0.05 -quality 50% -compress JPEG"
	#
	case "$USER_CONVERT_PARAMS" in
		fast) CONVERT_PARAMS="$PRESET_FAST" ;;
		best) CONVERT_PARAMS="$PRESET_BEST" ;;
		grayscale) CONVERT_PARAMS="$PRESET_GRAYSCALE" ;;
		jpeg) CONVERT_PARAMS="$PRESET_JPEG" ;;
		*) CONVERT_PARAMS="$USER_CONVERT_PARAMS" ;;
	esac
	if [[ $CONVERT_PARAMS == "" ]]; then
		CONVERT_PARAMS="$PRESET_BEST"
	fi
	#
	convert $TMP_DIR/$PREFIX*.$EXT_IMG $CONVERT_PARAMS $TMP_DIR/$PREFIX-input_unprotected.pdf
	python3.4 "$DIR"/pdf2pdfocr_multibackground.py "$TMP_DIR/$PREFIX-input_unprotected.pdf" "$TMP_DIR/$PREFIX-ocr.pdf" "$TMP_DIR/$PREFIX-OUTPUT.pdf" 2>"$TMP_DIR/err_multiback-$PREFIX-rebuild.log"
fi

# Test for output file error
if [[ ! -e  "$TMP_DIR/$PREFIX-OUTPUT.pdf" ]]; then
	echo "Output file could not be created :( Exiting with error code." 1>&2
	cleanup
	exit 1
fi

DEBUG "Output file created"

# Copy the output file
cp "$TMP_DIR/$PREFIX-OUTPUT.pdf" "$OUTPUT_FILE"

# Adjust the new file timestamp
touch -r "$INPUT_FILE" "$OUTPUT_FILE"

# Final cleanup
cleanup

echo "Success!"
exit 0
#