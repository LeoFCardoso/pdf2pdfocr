#!/usr/bin/env python3
##############################################################################
# Copyright (c) 2016: Leonardo Cardoso
# https://github.com/LeoFCardoso/pdf2pdfocr
##############################################################################
# OCR a PDF and add a text "layer" in the original file (a so called "pdf sandwich")
# Use only open source tools.
# Unless requested, does not re-encode the images inside an unprotected PDF file.
# Leonardo Cardoso - inspired in ocrmypdf (https://github.com/jbarlow83/OCRmyPDF)
# and this post: https://github.com/jbarlow83/OCRmyPDF/issues/8
#
# pip libraries dependencies: PyPDF2, reportlab
# external tools dependencies: file, poppler, imagemagick, tesseract, ghostscript, pdftk (optional)
###############################################################################
import argparse
import datetime
import errno
import fnmatch
import glob
import itertools
import math
import multiprocessing
import os
import random
import shlex
import shutil
import string
import subprocess
import sys
import tempfile
import time

import PyPDF2

####
__author__ = 'Leonardo F. Cardoso'


def debug(param):
    try:
        if verbose_mode:
            tstamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
            print("[{0}] [DEBUG]\t{1}".format(tstamp, param))
    except:
        pass


def log(param):
    try:
        tstamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
        print("[{0}] [LOG]\t{1}".format(tstamp, param))
    except:
        pass


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def best_effort_remove(filename):
    try:
        os.remove(filename)
    except OSError as e:
        if e.errno != errno.ENOENT:  # errno.ENOENT = no such file or directory
            raise  # re-raise exception if a different error occured


# find files in filesystem
def find(pattern, path):
    result = []
    for root, dirs, files in os.walk(path):
        for name in files:
            if fnmatch.fnmatch(name, pattern):
                result.append(os.path.join(root, name))
    return result


def cleanup(param_delete, param_tmp_dir, param_prefix):
    if param_delete:
        # All with PREFIX on temp files
        for f in glob.glob(param_tmp_dir + "*" + param_prefix + "*.*"):
            os.remove(f)
    else:
        eprint("Temporary files kept in {0}".format(param_tmp_dir))


def do_pdftoimage(param_path_pdftoppm, param_page_range, param_input_file, param_tmp_dir, param_prefix,
                  param_shell_mode):
    """
    Convert PDF to image file.
    Will be called from multiprocessing, so no global variables are allowed.
    """
    command_line_list = [param_path_pdftoppm]
    first_page = 0
    last_page = 0
    if param_page_range is not None:
        first_page = param_page_range[0]
        last_page = param_page_range[1]
        command_line_list += ['-f', str(first_page), '-l', str(last_page)]
    #
    command_line_list += ['-r', '300', '-jpeg', param_input_file, param_tmp_dir + param_prefix]
    pimage = subprocess.Popen(command_line_list, stdout=subprocess.DEVNULL,
                              stderr=open(
                                  param_tmp_dir + "pdftoppm_err_{0}-{1}-{2}.log".format(param_prefix, first_page,
                                                                                        last_page),
                                  "wb"),
                              shell=param_shell_mode)
    pimage.wait()


def do_deskew(param_image_file, param_threshold, param_shell_mode, param_path_mogrify):
    """
    Do a deskew of image.
    Will be called from multiprocessing, so no global variables are allowed.
    """
    pd = subprocess.Popen([param_path_mogrify, '-deskew', param_threshold, param_image_file], shell=param_shell_mode)
    pd.wait()


def do_ocr(param_image_file, param_tess_lang, param_tess_psm, param_temp_dir, param_script_dir, param_shell_mode,
           param_path_tesseract, param_path_this_python):
    """
    Do OCR of image.
    Will be called from multiprocessing, so no global variables are allowed.
    """
    # OCR to HOCR format
    # TODO - learn to uniform font sizes (bounding box) in hocr
    # TODO - expert mode - let user pass tesseract custom parameters
    param_image_no_ext = os.path.splitext(os.path.basename(param_image_file))[0]
    pocr = subprocess.Popen([param_path_tesseract, '-l', param_tess_lang,
                             '-c', 'tessedit_create_hocr=1',
                             '-c', 'tessedit_create_txt=1',
                             '-c', 'tessedit_pageseg_mode=' + param_tess_psm,
                             param_image_file,
                             param_temp_dir + param_image_no_ext],
                            stdout=subprocess.DEVNULL,
                            stderr=open(param_temp_dir + "tess_err_{0}.log".format(param_image_no_ext), "wb"),
                            shell=param_shell_mode)
    pocr.wait()
    # Run downloaded "hocrTransform.py" from ocrmypdf software to create a transparent text PDF from HOCR
    ptransfor = subprocess.Popen([param_path_this_python, param_script_dir + 'hocrtransform.py', '-r', '300',
                                  "{0}{1}.hocr".format(param_temp_dir, param_image_no_ext),
                                  "{0}{1}.pdf".format(param_temp_dir, param_image_no_ext)],
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL,
                                 shell=param_shell_mode)
    ptransfor.wait()


def test_convert(param_path_convert, param_tmp_dir, param_prefix, param_shell_mode):
    """
    test convert command to check if it's ImageMagick
    :param param_path_convert: path to call program
    :param param_tmp_dir: tmp path
    :param param_prefix: the prefix
    :param param_shell_mode: shell mode to use
    :return: True if it's ImageMagicks convert, false with any other case
    """
    result = False
    test_image = param_tmp_dir + "converttest-" + param_prefix + ".jpg"
    ptest = subprocess.Popen([param_path_convert, 'rose:', test_image], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, shell=param_shell_mode)
    streamdata = ptest.communicate()[0]
    ptest.wait()
    return_code = ptest.returncode
    if return_code == 0:
        best_effort_remove(test_image)
        result = True
    return result


def percentual_float(x):
    x = float(x)
    if x <= 0.0 or x > 1.0:
        raise argparse.ArgumentTypeError("%r not in range (0.0, 1.0]" % (x,))
    return x


def edit_producer(param_source_file, param_input_file_metadata, param_output_file):
    file_source = open(param_source_file, 'rb')
    pre_output_pdf = PyPDF2.PdfFileReader(file_source, strict=False)
    final_output_pdf = PyPDF2.PdfFileWriter()
    for i in range(pre_output_pdf.getNumPages()):
        page = pre_output_pdf.getPage(i)
        final_output_pdf.addPage(page)
    info_dict_output = dict()
    # Our signature as a producer
    our_name = "PDF2PDFOCR(github.com/LeoFCardoso/pdf2pdfocr)"
    read_producer = False
    producer_key = "/Producer"
    if param_input_file_metadata is not None:
        for key in param_input_file_metadata:
            value = param_input_file_metadata[key]
            if key == producer_key:
                value = value + "; " + our_name
                read_producer = True
            #
            try:
                # Check if value can be accepted by pypdf API
                test_conversion = PyPDF2.generic.createStringObject(value)
                info_dict_output[key] = value
            except TypeError:
                # This can happen with some array properties.
                eprint("Warning: property " + key + " not copied to final PDF")
    #
    if not read_producer:
        info_dict_output[producer_key] = our_name
    #
    final_output_pdf.addMetadata(info_dict_output)
    #
    with open(param_output_file, 'wb') as f:
        final_output_pdf.write(f)
        f.close()
    #
    file_source.close()
#


def calculate_ranges(input_file_number_of_pages, cpu_to_use):
    """
    calculate ranges to run pdptoppm in parallel. Each CPU available will run well defined page range
    :param input_file_number_of_pages:
    :param cpu_to_use:
    :return:
    """
    if input_file_number_of_pages is None:
        return None
    #
    range_size = math.ceil(input_file_number_of_pages / cpu_to_use)
    number_of_ranges = math.ceil(input_file_number_of_pages / range_size)
    result = []
    for i in range(0, number_of_ranges):
        range_start = (range_size * i) + 1
        range_end = (range_size * i) + range_size
        # Handle last range
        if range_end > input_file_number_of_pages:
            range_end = input_file_number_of_pages
        result.append((range_start, range_end))
    # Check result
    check_pages = 0
    for created_range in result:
        check_pages += (created_range[1] - created_range[0]) + 1
    if check_pages != input_file_number_of_pages:
        raise ArithmeticError("Please check 'calculate_ranges' function, something is wrong...")
    #
    return result


# -------------
# MAIN
# -------------

# -------------
# External tools command. If you can't edit your path, adjust here to match your system
cmd_tesseract = "tesseract"
cmd_convert = "convert"
cmd_magick = "magick"  # used on Windows with ImageMagick 7+ (to avoid conversion path problems)
cmd_mogrify = "mogrify"
cmd_file = "file"
cmd_pdftoppm = "pdftoppm"
cmd_ps2pdf = "ps2pdf"
cmd_pdf2ps = "pdf2ps"
# -------------

# https://docs.python.org/3/library/multiprocessing.html#multiprocessing-programming
# See "Safe importing of main module"
if __name__ == '__main__':
    multiprocessing.freeze_support()  # Should make effect only on non-fork systems (Windows)

    # How to run external process? In Windows use Shell=True
    # http://stackoverflow.com/questions/5658622/python-subprocess-popen-environment-path
    # "Also, on Windows with shell=False, it pays no attention to PATH at all,
    # and will only look in relative to the current working directory."
    shell_mode = False
    if os.name == 'nt':
        shell_mode = True
    # Temp dir
    tmp_dir = tempfile.gettempdir() + os.path.sep
    #
    # A random prefix to support multiple execution in parallel
    prefix = ''.join(random.SystemRandom().choice(string.ascii_uppercase + string.digits) for _ in range(5))
    #
    # Check if external tools are available, aborting in case of any error.
    path_tesseract = shutil.which(cmd_tesseract)
    if path_tesseract is None:
        eprint("tesseract not found. Aborting...")
        exit(1)
    #
    # Try to avoid errors on Windows with native OS "convert" command
    # http://savage.net.au/ImageMagick/html/install-convert.html
    # https://www.imagemagick.org/script/magick.php
    path_convert = shutil.which(cmd_convert)
    if not test_convert(path_convert, tmp_dir, prefix, shell_mode):
        path_convert = shutil.which(cmd_magick)
    if path_convert is None:
        eprint("convert/magick from ImageMagick not found. Aborting...")
        exit(1)
    #
    path_mogrify = shutil.which(cmd_mogrify)
    if path_mogrify is None:
        eprint("mogrify from ImageMagick not found. Aborting...")
        exit(1)
    #
    path_file = shutil.which(cmd_file)
    if path_file is None:
        eprint("file not found. Aborting...")
        exit(1)
    #
    path_pdftoppm = shutil.which(cmd_pdftoppm)
    if path_pdftoppm is None:
        eprint("pdftoppm (poppler) not found. Aborting...")
        exit(1)
    #
    path_ps2pdf = shutil.which(cmd_ps2pdf)
    path_pdf2ps = shutil.which(cmd_pdf2ps)
    if path_ps2pdf is None or path_pdf2ps is None:
        eprint("ps2pdf or pdf2ps (ghostscript) not found. File repair will not work...")
    #

    path_this_python = sys.executable

    # Arguments
    parser = argparse.ArgumentParser(description='pdf2pdfocr.py version 1.0',
                                     formatter_class=argparse.RawTextHelpFormatter)
    requiredNamed = parser.add_argument_group('required arguments')
    requiredNamed.add_argument("-i", dest="input_file", action="store", required=True,
                               help="path for input file")
    #
    parser.add_argument("-s", dest="safe_mode", action="store_true", default=False,
                        help="safe mode. Does not overwrite output [PDF | TXT] OCR file")
    parser.add_argument("-t", dest="check_text_mode", action="store_true", default=False,
                        help="check text mode. Does not process if source PDF already has text")
    parser.add_argument("-a", dest="check_protection_mode", action="store_true", default=False,
                        help="check encryption mode. Does not process if source PDF is protected")
    parser.add_argument("-f", dest="force_rebuild_mode", action="store_true", default=False,
                        help="force PDF rebuild from extracted images")
    # Escape % wiht %%
    option_g_help = """with images or '-f', use presets or force parameters when calling 'convert' to build the final PDF file
Examples:
    -g fast -> a fast bitonal file ("-threshold 60%% -compress Group4")
    -g best -> best quality, but bigger bitonal file ("-colors 2 -colorspace gray -normalize -threshold 60%% -compress Group4")
    -g grayscale -> good bitonal file from grayscale documents ("-threshold 85%% -morphology Dilate Diamond -compress Group4")
    -g jpeg -> keep original color image as JPEG ("-strip -interlace Plane -gaussian-blur 0.05 -quality 50%% -compress JPEG")
    -g jpeg2000 -> keep original color image as JPEG2000 ("-quality 32%% -compress JPEG2000")
    -g "-threshold 60%% -compress Group4" -> direct apply these parameters (DON'T FORGET TO USE QUOTATION MARKS)
    Note, without -g, preset 'best' is used"""
    parser.add_argument("-g", dest="convert_params", action="store", default="",
                        help=option_g_help)
    parser.add_argument("-d", dest="deskew_percent", action="store",
                        help="use imagemagick deskew *before* OCR. <DESKEW_PERCENT> should be a percent, e.g. '40%%'")
    parser.add_argument("-j", dest="parallel_percent", action="store", type=percentual_float,
                        help="run this percentual jobs in parallel (0 - 1.0] - multiply with the number of CPU cores"
                             " (default = 1 [all cores])")
    parser.add_argument("-w", dest="create_text_mode", action="store_true", default=False,
                        help="also create a text file at same location of PDF OCR file")
    parser.add_argument("-o", dest="output_file", action="store", required=False,
                        help="force output file to the specified location")
    parser.add_argument("-p", dest="use_pdftk", action="store_true", default=False,
                        help="force the use of pdftk tool to do the final overlay of files "
                             "(if not rebuild from images)")
    parser.add_argument("-l", dest="tess_langs", action="store", required=False,
                        help="force tesseract to use specific languages (default: por+eng)")
    parser.add_argument("-m", dest="tess_psm", action="store", required=False,
                        help="force tesseract to use HOCR with specific \"pagesegmode\" (default: tesseract "
                             "HOCR default = 1). Use with caution")
    parser.add_argument("-k", dest="keep_temps", action="store_true", default=False,
                        help="keep temporary files for debug")
    parser.add_argument("-v", dest="verbose_mode", action="store_true", default=False,
                        help="enable verbose mode")
    #
    args = parser.parse_args()

    safe_mode = args.safe_mode
    check_text_mode = args.check_text_mode
    check_protection_mode = args.check_protection_mode
    force_rebuild_mode = args.force_rebuild_mode
    user_convert_params = args.convert_params
    if user_convert_params is None:
        user_convert_params = ""  # Default
    deskew_threshold = args.deskew_percent
    use_deskew_mode = args.deskew_percent is not None
    parallel_threshold = args.parallel_percent
    if parallel_threshold is None:
        parallel_threshold = 1  # Default
    create_text_mode = args.create_text_mode
    force_out_mode = args.output_file is not None
    if force_out_mode:
        force_out_file = args.output_file
    else:
        force_out_file = ""
    use_pdftk = args.use_pdftk
    tess_langs = args.tess_langs
    if tess_langs is None:
        tess_langs = "por+eng"  # Default
    tess_psm = args.tess_psm
    if tess_psm is None:
        tess_psm = "1"  # Default
    delete_temps = not args.keep_temps
    verbose_mode = args.verbose_mode
    #
    debug("Temp dir is {0}".format(tmp_dir))
    debug("Prefix is {0}".format(prefix))
    #
    if use_pdftk:
        path_pdftk = shutil.which("pdftk")
        if path_pdftk is None:
            eprint("pdftk not found. Aborting...")
            cleanup(delete_temps, tmp_dir, prefix)
            exit(1)
    #
    input_file = args.input_file
    if not os.path.isfile(input_file):
        eprint("{0} not found. Exiting.".format(input_file))
        cleanup(delete_temps, tmp_dir, prefix)
        exit(1)
    # Use absolute path
    input_file = os.path.abspath(input_file)

    input_file_type = ""
    # Using file call to get better compatibility with Windows (file is 32bit only)
    pfile = subprocess.Popen([path_file, '-b', '--mime-type', input_file], stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, shell=shell_mode)
    pfile_output, pfile_errors = pfile.communicate()
    pfile.wait()
    input_file_type = pfile_output.decode("utf-8").strip()
    log("Input file {0}: type is {1}".format(input_file, input_file_type))
    #
    input_file_has_text = False
    input_file_is_encrypted = False
    input_file_metadata = dict()
    input_file_number_of_pages = None
    if input_file_type == "application/pdf":
        pdfFileObj = open(input_file, 'rb')  # read binary
        pdfReader = PyPDF2.PdfFileReader(pdfFileObj, strict=False)
        try:
            input_file_number_of_pages = pdfReader.getNumPages()
        except Exception:
            eprint("Warning: could not read input file number of pages.")
            input_file_number_of_pages = None
        #
        input_file_is_encrypted = pdfReader.isEncrypted
        if not input_file_is_encrypted:
            input_file_metadata = pdfReader.documentInfo
        text_check_failed = False
        try:
            for pageObj in pdfReader.pages:
                try:
                    if pageObj.extractText() != "":
                        input_file_has_text = True
                except TypeError:
                    text_check_failed = True
        except PyPDF2.utils.PdfReadError:
            text_check_failed = True
        #
        if check_text_mode and text_check_failed and not input_file_has_text:
            eprint("Warning: fail to check for text in input file. Assuming no text, but this can be wrong")
    #
    if input_file_type == "application/pdf" and check_text_mode and input_file_has_text:
        eprint("{0} already has text and check text mode is enabled. Exiting.".format(input_file))
        cleanup(delete_temps, tmp_dir, prefix)
        exit(1)
    #
    if input_file_type == "application/pdf" and check_protection_mode and input_file_is_encrypted:
        eprint("{0} is encrypted PDF and check encryption mode is enabled. Exiting.".format(input_file))
        cleanup(delete_temps, tmp_dir, prefix)
        exit(1)
    #
    # This is the output file
    output_file = ""
    if force_out_mode:
        output_file = force_out_file
    else:
        output_name_no_ext = os.path.splitext(os.path.basename(input_file))[0]
        output_dir = os.path.dirname(input_file)
        output_file = output_dir + os.path.sep + output_name_no_ext + "-OCR.pdf"
    #
    output_file_text = output_file + ".txt"
    debug("Output file: {0} for PDF and {1} for TXT".format(output_file, output_file_text))
    #
    if (safe_mode and os.path.isfile(output_file)) or \
            (safe_mode and create_text_mode and os.path.isfile(output_file_text)):
        if os.path.isfile(output_file):
            eprint("{0} already exists and safe mode is enabled. Exiting.".format(output_file))
        if create_text_mode and os.path.isfile(output_file_text):
            eprint("{0} already exists and safe mode is enabled. Exiting.".format(output_file_text))
        cleanup(delete_temps, tmp_dir, prefix)
        exit(1)
    #
    # Initial cleanup
    best_effort_remove(output_file)
    if create_text_mode:
        best_effort_remove(output_file_text)
    #
    # Where am I?
    script_dir = os.path.dirname(os.path.abspath(__file__)) + os.path.sep
    debug("Script dir is {0}".format(script_dir))
    #
    cpu_count = multiprocessing.cpu_count()
    cpu_to_use = int(cpu_count * parallel_threshold)
    if cpu_to_use == 0:
        cpu_to_use = 1
    debug("Parallel operations will use {0} CPUs".format(cpu_to_use))
    #
    extension_images = "jpg"  # Using jpg to avoid big temp files in pdf with a lot of pages
    log("Converting PDF to images...")
    if input_file_type == "application/pdf":
        parallel_page_ranges = calculate_ranges(input_file_number_of_pages, cpu_to_use)
        if parallel_page_ranges is not None:
            pdfimage_pool = multiprocessing.Pool(cpu_to_use)
            pdfimage_pool.starmap(do_pdftoimage, zip(itertools.repeat(path_pdftoppm),
                                                     parallel_page_ranges,
                                                     itertools.repeat(input_file),
                                                     itertools.repeat(tmp_dir),
                                                     itertools.repeat(prefix),
                                                     itertools.repeat(shell_mode)))
        else:
            # Without page info, only alternative is going sequentialy (without range)
            do_pdftoimage(path_pdftoppm, None, input_file, tmp_dir, prefix, shell_mode)
    else:
        if input_file_type in ["image/tiff", "image/jpeg", "image/png"]:
            # %09d to format files for correct sort
            p = subprocess.Popen([path_convert, input_file, '-quality', '100', '-scene', '1',
                                  tmp_dir + prefix + '-%09d.' + extension_images], shell=shell_mode)
            p.wait()
        else:
            eprint("{0} is not supported in this script. Exiting.".format(input_file_type))
            cleanup(delete_temps, tmp_dir, prefix)
            exit(1)
    # Images to be processed
    image_file_list = find("{0}*.{1}".format(prefix, extension_images), tmp_dir)
    #
    if use_deskew_mode:
        debug("Applying deskew (will rebuild final PDF file)")
        deskew_pool = multiprocessing.Pool(cpu_to_use)
        # Call function in parallel
        deskew_pool.starmap(do_deskew, zip(image_file_list, itertools.repeat(deskew_threshold),
                                           itertools.repeat(shell_mode), itertools.repeat(path_mogrify)))
        # Sequential code below
        # for image_file in deskew_file_list:
        #     do_deskew(...)
        #
    #
    log("Starting OCR...")
    ocr_pool = multiprocessing.Pool(cpu_to_use)
    ocr_pool_map = ocr_pool.starmap_async(do_ocr,
                                          zip(image_file_list, itertools.repeat(tess_langs), itertools.repeat(tess_psm),
                                              itertools.repeat(tmp_dir), itertools.repeat(script_dir),
                                              itertools.repeat(shell_mode),
                                              itertools.repeat(path_tesseract), itertools.repeat(path_this_python)))
    while not ocr_pool_map.ready():
        # TODO - how many *pages* remaining?
        log("Waiting for OCR to complete. {0} tasks remaining...".format(ocr_pool_map._number_left))
        time.sleep(5)
    #
    log("OCR completed")
    # Join PDF files into one file that contains all OCR "backgrounds"
    # Workaround for bug 72720 in older poppler releases
    # https://bugs.freedesktop.org/show_bug.cgi?id=72720
    text_pdf_file_list = find("{0}*.{1}".format(prefix, "pdf"), tmp_dir)
    debug("We have {0} ocr'ed files".format(len(text_pdf_file_list)))
    if len(text_pdf_file_list) > 1:
        pdf_merger = PyPDF2.PdfFileMerger()
        for text_pdf_file in sorted(glob.glob(tmp_dir + prefix + "*.pdf")):
            pdf_merger.append(PyPDF2.PdfFileReader(text_pdf_file, strict=False))
        pdf_merger.write(tmp_dir + prefix + "-ocr.pdf")
        pdf_merger.close()
    else:
        if len(text_pdf_file_list) == 1:
            shutil.copyfile(text_pdf_file_list[0], tmp_dir + prefix + "-ocr.pdf")
        else:
            eprint("No PDF files generated after OCR. This is not expected. Aborting.")
            cleanup(delete_temps, tmp_dir, prefix)
            exit(1)
    #
    debug("Joined ocr'ed PDF files")
    #
    # Create final text output
    if create_text_mode:
        text_files = sorted(glob.glob(tmp_dir + prefix + "*.txt"))
        text_io_wrapper = open(output_file_text, 'w')
        with text_io_wrapper as outfile:
            for fname in text_files:
                with open(fname) as infile:
                    for line in infile:
                        outfile.write(line)
        #
        text_io_wrapper.close()
        #
        debug("Created final text file")
    #
    # Start building final PDF.
    # First, should we rebuild source file?
    rebuild_pdf_from_images = False
    if input_file_is_encrypted or input_file_type != "application/pdf" or use_deskew_mode:
        rebuild_pdf_from_images = True
    #
    if (not rebuild_pdf_from_images) and (not force_rebuild_mode):
        # Merge OCR background PDF into the main PDF document making a PDF sandwich
        if use_pdftk:
            debug("Merging with OCR with pdftk")
            ppdftk = subprocess.Popen([path_pdftk, input_file, 'multibackground', tmp_dir + prefix + "-ocr.pdf",
                                       'output', tmp_dir + prefix + "-OUTPUT.pdf"],
                                      stdout=subprocess.DEVNULL,
                                      stderr=open(tmp_dir + "err_multiback-{0}-merge-pdftk.log".format(prefix), "wb"),
                                      shell=shell_mode)
            ppdftk.wait()
        else:
            debug("Merging with OCR")
            pmulti = subprocess.Popen([path_this_python, script_dir + 'pdf2pdfocr_multibackground.py', input_file,
                                       tmp_dir + prefix + "-ocr.pdf", tmp_dir + prefix + "-OUTPUT.pdf"],
                                      stdout=subprocess.DEVNULL,
                                      stderr=open(tmp_dir + "err_multiback-{0}-merge.log".format(prefix), "wb"),
                                      shell=shell_mode)
            pmulti.wait()
            # Sometimes, the above script fail with some malformed input PDF files.
            # The code below try to rewrite source PDF and run it again.
            if not os.path.isfile(tmp_dir + prefix + "-OUTPUT.pdf"):
                debug("Fail to merge source PDF with extracted OCR text. "
                      "Trying to fix source PDF to build final file...")
                prepair1 = subprocess.Popen([path_pdf2ps, input_file, tmp_dir + prefix + "-fixPDF.ps"],
                                            stdout=subprocess.DEVNULL,
                                            stderr=open(tmp_dir + "err_pdf2ps-{0}.log".format(prefix), "wb"),
                                            shell=shell_mode)
                prepair1.wait()
                prepair2 = subprocess.Popen([path_ps2pdf, tmp_dir + prefix + "-fixPDF.ps",
                                             tmp_dir + prefix + "-fixPDF.pdf"],
                                            stdout=subprocess.DEVNULL,
                                            stderr=open(tmp_dir + "err_ps2pdf-{0}.log".format(prefix), "wb"),
                                            shell=shell_mode)
                prepair2.wait()
                pmulti2 = subprocess.Popen([path_this_python, script_dir + 'pdf2pdfocr_multibackground.py',
                                            tmp_dir + prefix + "-fixPDF.pdf",
                                            tmp_dir + prefix + "-ocr.pdf", tmp_dir + prefix + "-OUTPUT.pdf"],
                                           stdout=subprocess.DEVNULL,
                                           stderr=open(tmp_dir + "err_multiback-{0}-merge-fixed.log".format(prefix),
                                                       "wb"),
                                           shell=shell_mode)
                pmulti2.wait()
            #
    else:
        eprint("Warning: metadata wiped from final PDF file (original file is not an unprotected PDF / "
               "forcing rebuild from extracted images / using deskew)")
        # Convert presets
        # Please read http://www.imagemagick.org/Usage/quantize/#colors_two
        preset_fast = "-threshold 60% -compress Group4"
        preset_best = "-colors 2 -colorspace gray -normalize -threshold 60% -compress Group4"
        preset_grayscale = "-threshold 85% -morphology Dilate Diamond -compress Group4"
        preset_jpeg = "-strip -interlace Plane -gaussian-blur 0.05 -quality 50% -compress JPEG"
        preset_jpeg2000 = "-quality 32% -compress JPEG2000"
        #
        convert_params = ""
        if user_convert_params == "fast":
            convert_params = preset_fast
        elif user_convert_params == "best":
            convert_params = preset_best
        elif user_convert_params == "grasyscale":
            convert_params = preset_grayscale
        elif user_convert_params == "jpeg":
            convert_params = preset_jpeg
        elif user_convert_params == "jpeg2000":
            convert_params = preset_jpeg2000
        else:
            convert_params = user_convert_params
        # Handle default case
        if convert_params == "":
            convert_params = preset_best
        #
        # http://stackoverflow.com/questions/79968/split-a-string-by-spaces-preserving-quoted-substrings-in-python
        log("Rebuilding PDF from images")
        convert_params_list = shlex.split(convert_params)
        prebuild = subprocess.Popen(
            [path_convert] + sorted(glob.glob(tmp_dir + prefix + "*." + extension_images)) + convert_params_list + [
                tmp_dir + prefix + "-input_unprotected.pdf"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            shell=shell_mode)
        prebuild.wait()
        #
        debug("Merging with OCR")
        pmulti = subprocess.Popen([path_this_python, script_dir + 'pdf2pdfocr_multibackground.py',
                                   tmp_dir + prefix + "-input_unprotected.pdf",
                                   tmp_dir + prefix + "-ocr.pdf", tmp_dir + prefix + "-OUTPUT.pdf"],
                                  stdout=subprocess.DEVNULL,
                                  stderr=open(tmp_dir + "err_multiback-{0}-rebuild.log".format(prefix), "wb"),
                                  shell=shell_mode)
        pmulti.wait()
    #
    if not os.path.isfile(tmp_dir + prefix + "-OUTPUT.pdf"):
        eprint("Output file could not be created :( Exiting with error code.")
        cleanup(delete_temps, tmp_dir, prefix)
        exit(1)
    #
    # TODO - create option for PDF/A files
    # gs -dPDFA=3 -dBATCH -dNOPAUSE -sProcessColorModel=DeviceCMYK -sDEVICE=pdfwrite
    # -sPDFACompatibilityPolicy=2 -sOutputFile=output_filename.pdf ./Test.pdf
    # As in
    # http://git.ghostscript.com/?p=ghostpdl.git;a=blob_plain;f=doc/VectorDevices.htm;hb=HEAD#PDFA
    #
    # Edit producer and build final PDF
    # Without edit producer is easy as "shutil.copyfile(tmp_dir + prefix + "-OUTPUT.pdf", output_file)"
    debug("Editing producer")
    edit_producer(tmp_dir + prefix + "-OUTPUT.pdf", input_file_metadata, output_file)
    debug("Output file created")
    #
    # Adjust the new file timestamp
    # TODO touch -r "$INPUT_FILE" "$OUTPUT_FILE"
    #
    cleanup(delete_temps, tmp_dir, prefix)
    #
    paypal_donate_link = "https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=leonardo%2ef%2ecardoso%40gmail%2ecom&lc=US&item_name=pdf2pdfocr%20development&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHosted"
    flattr_donate_link = "https://flattr.com/profile/pdf2pdfocr.devel"
    success_message = """Success!
This software is free, but if you like it, please donate to support new features.
---> Paypal
{0}
---> Flattr
{1}""".format(paypal_donate_link, flattr_donate_link)
    log(success_message)
    exit(0)
    #
# This is the end
