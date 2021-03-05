#!/usr/bin/env python3
##############################################################################
# Copyright (c) 2018: Leonardo Cardoso
# https://github.com/LeoFCardoso/pdf2pdfocr
##############################################################################
# Gui for PDF2PDFOCR
##############################################################################
import os

import sys
from gooey import Gooey, GooeyParser

from pdf2pdfocr import VERSION

__author__ = 'Leonardo F. Cardoso'


@Gooey(
    program_name="PDF2PDFOCR {0}".format(VERSION),
    target='"{0}" "{1}"'.format(sys.executable, os.path.dirname(os.path.abspath(__file__)) + os.path.sep + 'pdf2pdfocr.py'),
    default_size=(1024, 768),
    show_success_modal=False,
    tabbed_groups=True,
    header_bg_color="#FF4800",
    body_bg_color="#FF9100",
    footer_bg_color="#FF9100",
    sidebar_bg_color="#FF9100",
    terminal_panel_color="#FF9100",
)
def show_gui(p_input_file_argument):
    parser = GooeyParser(description="https://github.com/LeoFCardoso/pdf2pdfocr")
    #
    files_group = parser.add_argument_group("Files", gooey_options={'columns': 1})
    files_group.add_argument("-i", dest="input_file", metavar="Input file", action="store", required=True, widget="FileChooser",
                             default=p_input_file_argument, help="path for input file")
    files_group.add_argument("-o", dest="output_file", metavar="Output file", action="store", required=False, widget="FileChooser",
                             help="force output file to the specified location (optional)")
    #
    basic_options = parser.add_argument_group("Basic options")
    basic_options.add_argument("-s", dest="safe_mode", metavar='Safe (-s)', action="store_true", default=False,
                               help="Does not overwrite output [PDF | TXT] OCR file ")
    basic_options.add_argument("-t", dest="check_text_mode", metavar='Check text (-t)', action="store_true", default=False,
                               help="Does not process if source PDF already has text ")
    basic_options.add_argument("-a", dest="check_protection_mode", metavar='Check encryption (-a)', action="store_true", default=False,
                               help="Does not process if source PDF is protected ")
    basic_options.add_argument("-b", dest="max_pages", metavar='Max pages (-b)', action="store", default=None, type=int,
                               help="Does not process if number of pages is greater than this value ")
    basic_options.add_argument("-d", dest="deskew_percent", metavar='Deskew (-d)', action="store",
                               help="Use imagemagick deskew before OCR. Should be a percent, e.g. '40%' ")
    basic_options.add_argument("-w", dest="create_text_mode", metavar='Text file (-w)', action="store_true", default=False,
                               help="Create a text file at same location of PDF OCR file [tesseract only] ")
    basic_options.add_argument("-u", dest="autorotate", metavar='Autorotate (-u)', action="store_true", default=False,
                               help="Try to autorotate pages using 'psm 0' feature [tesseract only] ")
    basic_options.add_argument("-v", dest="verbose_mode", metavar='Verbose (-v)', action="store_true", default=True,
                               help="enable verbose mode ")
    #
    rebuild_options = parser.add_argument_group("Rebuild options", gooey_options={'columns': 1})
    rebuild_options.add_argument("-f", dest="force_rebuild_mode", metavar='Force rebuild (-f)', action="store_true", default=False,
                                 help="Force PDF rebuild from extracted images ")
    option_g_help = """With image input or '-f', use presets or force parameters when calling 'convert' to build the final PDF file:
        fast -> a fast bitonal file ("-threshold 60% -compress Group4")
        best -> best quality, but bigger bitonal file ("-colors 2 -colorspace gray -normalize -threshold 60% -compress Group4")
        grayscale -> good bitonal file from grayscale documents ("-threshold 85% -morphology Dilate Diamond -compress Group4")
        jpeg -> keep original color image as JPEG ("-strip -interlace Plane -gaussian-blur 0.05 -quality 50% -compress JPEG")
        jpeg2000 -> keep original color image as JPEG2000 ("-quality 32% -compress JPEG2000")
        or use custom parameters directly (USE SPACE CHAR FIRST)
        Note, without -g, preset 'best' is used
    """
    rebuild_options.add_argument("-g", dest="convert_params", metavar='Force params (-g)', action="store", default="",
                                 help=option_g_help, widget="Dropdown",
                                 choices=["", "fast", "best", "grayscale", "jpeg", "jpeg2000",
                                          " -custom_params (to use custom params, please keep the first space char)"])
    #
    advanced_options = parser.add_argument_group("Advanced options")
    advanced_options.add_argument("-c", dest="ocr_engine", metavar='OCR engine (-c)', action="store", type=str, default="tesseract",
                                  help="select the OCR engine to use ", widget="Dropdown", choices=["tesseract", "cuneiform", "no_ocr"])
    advanced_options.add_argument("-j", dest="parallel_percent", metavar='Parallel (-j)', action="store", type=float, default=1.0,
                                  help="run this percentual jobs in parallel (0 - 1.0]\nmultiply with the number of CPU cores, default = 1 [all "
                                       "cores] ")
    advanced_options.add_argument("-r", dest="image_resolution", metavar='Resolution (-r)', action="store", default=300, type=int,
                                  help="specify image resolution in DPI before OCR operation\nlower is faster, higher improves OCR quality, default "
                                       "is for quality = 300")
    advanced_options.add_argument("-e", dest="text_generation_strategy", metavar='Text generation (-e)', action="store", default="tesseract",
                                  type=str, help="specify how text is generated in final pdf file [tesseract only] ",
                                  widget="Dropdown", choices=["tesseract", "native"])
    advanced_options.add_argument("-l", dest="tess_langs", metavar='Languages (-l)', action="store", required=False, default="por",
                                  help="force tesseract or cuneiform to use specific language ")
    advanced_options.add_argument("-m", dest="tess_psm", metavar='Tesseract PSM (-m)', action="store", required=False,
                                  help="force tesseract to use HOCR with specific \"pagesegmode\"\n(default: tesseract "
                                       "HOCR default = 1) [tesseract only]. Use with caution ")
    advanced_options.add_argument("-x", dest="extra_ocr_flag", metavar='Extra OCR parameters (-x)', action="store", required=False, default="",
                                  help="add extra command line flags in select OCR engine for all pages.\nUse with caution ")
    advanced_options.add_argument("-k", dest="keep_temps", metavar='Keep temps (-k)', action="store_true", default=False,
                                  help="keep temporary files for debug ")
    #
    return parser.parse_args()


# -------------
# MAIN
# -------------
if __name__ == '__main__':
    # Check if there is a filename argument
    input_file_argument = ""
    if len(sys.argv) > 1:
        input_file_argument = sys.argv[1]
    #
    show_gui(input_file_argument)
    exit(0)
    #
# This is the end
