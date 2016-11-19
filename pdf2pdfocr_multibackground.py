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
# Depends on PyPDF2
#
import sys
from PyPDF2 import PdfFileWriter, PdfFileReader
#
__author__ = 'Leonardo F. Cardoso'
#
output = PdfFileWriter()
# First file (image)
imagepdf = PdfFileReader(open(sys.argv[1], 'rb'), strict=False)
# Second file (text)
textpdf = PdfFileReader(open(sys.argv[2], 'rb'), strict=False)
# Copy pages to output with text
scale_tolerance = 0.001
for i in range(imagepdf.getNumPages()):
    # print ("Page: ", i+1)
    imagepage = imagepdf.getPage(i)
    textpage = textpdf.getPage(i)
    # print("Img:", imagepage.mediaBox.upperRight)
    # print("Text:", textpage.mediaBox.upperRight)
    factor_x = textpage.mediaBox.upperRight[0] / imagepage.mediaBox.upperRight[0]
    factor_y = textpage.mediaBox.upperRight[1] / imagepage.mediaBox.upperRight[1]
    # print(factor_x, factor_y)
    # print(factor_x - 1, factor_y - 1)
    # Try to avoid unnecessary scale operation
    if abs(factor_x - 1) > scale_tolerance or abs(factor_y - 1) > scale_tolerance:
        # print("Scaling...")
        imagepage.scale(float(factor_x), float(factor_y))
    # Handle rotation
    rotate_angle = imagepage.get('/Rotate')
    # print("Page rotate angle is", rotate_angle)
    if rotate_angle is None:
        rotate_angle = 0
    #
    # imagepage stay on top
    if rotate_angle == 0:
        textpage.mergePage(imagepage)
    else:
        textpage.mergeRotatedTranslatedPage(imagepage, (-1*rotate_angle), imagepage.mediaBox.getWidth() / 2,
                                            imagepage.mediaBox.getHeight() / 2)
    #
    textpage.compressContentStreams()
    output.addPage(textpage)
#
with open(sys.argv[3], 'wb') as f:
    output.write(f)
#
