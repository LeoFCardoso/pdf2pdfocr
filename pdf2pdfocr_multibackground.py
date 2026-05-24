#!/usr/bin/env python3
##############################################################################
# Copyright (c) 2016: Leonardo Cardoso
# https://github.com/LeoFCardoso/pdf2pdfocr
##############################################################################
# Emulate pdftk multibackground operator
# $1 - first file (foreground)
# $2 - second file (background)
# $3 - output file
# User should pass correct parameters. There is no parameter check.
####
# Depends on PyPDF
#
import datetime
import sys

from pypdf import PdfWriter, PdfReader, Transformation

__author__ = 'Leonardo F. Cardoso'
#

verbose_mode = False  # Used for debug


def debug(param):
    try:
        if verbose_mode:
            tstamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
            print("[{0}] [DEBUG]\t{1}".format(tstamp, param))
    except:
        pass


output = PdfWriter()
# First file (image)
imagepdf = PdfReader(open(sys.argv[1], 'rb'), strict=False)
# Second file (text)
textpdf = PdfReader(open(sys.argv[2], 'rb'), strict=False)
# Copy pages to output with text
scale_tolerance = 0.001
for i in range(len(imagepdf.pages)):
    debug("Page: {0}".format(i + 1))
    imagepage = imagepdf.pages[i]
    textpage = textpdf.pages[i]
    debug("Img (original): {0}".format(imagepage.mediabox.upper_right))
    debug("Text: {0}".format(textpage.mediabox.upper_right))
    # Handle rotation
    rotate_angle = imagepage.get('/Rotate')
    debug("Image page rotate angle is {0}".format(rotate_angle))
    debug("Text page rotate angle is {0}".format(textpage.get('/Rotate')))
    if rotate_angle is None:
        rotate_angle = 0
    #
    image_page_x = imagepage.mediabox.upper_right[0]
    image_page_y = imagepage.mediabox.upper_right[1]
    # With rotated pages (90 or 270 degress), we have to switch x and y, to avoid wrong scale operation
    if rotate_angle == 90 or rotate_angle == 270:
        image_page_x = imagepage.mediabox.upper_right[1]
        image_page_y = imagepage.mediabox.upper_right[0]
    #
    debug("Img (dimensions after rotation): {0}, {1}".format(image_page_x, image_page_y))
    factor_x = textpage.mediabox.upper_right[0] / image_page_x
    factor_y = textpage.mediabox.upper_right[1] / image_page_y
    debug("Factors: {0}, {1}".format(factor_x, factor_y))
    debug("Corrected Factors: {0}, {1}".format(factor_x - 1, factor_y - 1))
    # Try to avoid unnecessary scale operation
    if abs(factor_x - 1) > scale_tolerance or abs(factor_y - 1) > scale_tolerance:
        debug("Scaling...")
        imagepage.scale(float(factor_x), float(factor_y))
    # imagepage stay on top
    if rotate_angle == 0 or rotate_angle == 360:
        debug("Merge simple")
        # TODO very slow in some PDFs
        textpage.merge_page(imagepage)
    else:
        debug("Merge rotated")
        # Tested values for translation with 90 degrees
        if rotate_angle == 90:
            transform = Transformation().rotate(-rotate_angle).translate(image_page_y / 2, image_page_y / 2)
            textpage.merge_transformed_page(imagepage, transform, expand=False)
        # Tested values for translation with 180 degrees
        if rotate_angle == 180:
            transform = Transformation().rotate(-rotate_angle).translate(image_page_x / 2, image_page_y / 2)
            textpage.merge_transformed_page(imagepage, transform, expand=False)
        # Tested values for translation with 270 degrees
        if rotate_angle == 270:
            transform = Transformation().rotate(-rotate_angle).translate(image_page_x / 2, image_page_x / 2)
            textpage.merge_transformed_page(imagepage, transform, expand=False)
    #
    output.add_page(textpage)
    output.pages[-1].compress_content_streams()
#
with open(sys.argv[3], 'wb') as f:
    output.write(f)
#
