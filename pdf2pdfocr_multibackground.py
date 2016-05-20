#!/usr/bin/env python3
##############################################################################
# Copyright (c) 2016: Leonardo Cardoso
# https://github.com/LeoFCardoso/pdf2pdfocr
##############################################################################
# Emulate pdftk multibackground operator
# $1 - first file (preserves metadata)
# $2 - second file (background)
# $3 - output file
# User should pass correct parameters. There is no parameter check.
####
# Depends on PyPDF2
#
import sys
from PyPDF2 import PdfFileWriter, PdfFileReader
from PyPDF2.generic import NameObject, createStringObject
#
__author__ = 'Leonardo F. Cardoso'
#
output = PdfFileWriter()
# First file (image)
imagepdf = PdfFileReader(open(sys.argv[1], 'rb'), strict=False)
# Second file (text)
textpdf = PdfFileReader(open(sys.argv[2], 'rb'), strict=False)
# Copy pages to output with text
for i in range(imagepdf.getNumPages()):
    imagepage = imagepdf.getPage(i)
    textpage = textpdf.getPage(i)
    # print("Img:", imagepage.mediaBox.upperRight)
    # print("Text:", textpage.mediaBox.upperRight)
    factor_x = textpage.mediaBox.upperRight[0] / imagepage.mediaBox.upperRight[0]
    factor_y = textpage.mediaBox.upperRight[1] / imagepage.mediaBox.upperRight[1]
    # print(factor_x, factor_y)
    imagepage.scale(float(factor_x), float(factor_y))
    textpage.mergePage(imagepage)  # imagepage stay on top
    textpage.compressContentStreams()
    output.addPage(textpage)
#
info_dict_output = output._info.getObject()
ipdf_info = imagepdf.documentInfo
# Our signature as a producer
our_name = "PDF2PDFOCR(github.com/LeoFCardoso/pdf2pdfocr)"
read_producer = False
PRODUCER_KEY = "/Producer"
for key in ipdf_info:
    value = ipdf_info[key]
    if key == PRODUCER_KEY:
        value = value + "; " + our_name
        read_producer = True
    #
    try:
        info_dict_output.update({NameObject(key): createStringObject(value)})
    except TypeError:
        # This can happen with some array properties. Just mask the exception by now.
        # TODO - fix
        print("Warning: property " + key + " not copied to final PDF")
    #
#
if not read_producer:
    info_dict_output.update({NameObject(PRODUCER_KEY): createStringObject(our_name)})
#
with open(sys.argv[3], 'wb') as f:
    output.write(f)
#
