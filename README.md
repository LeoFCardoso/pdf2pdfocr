# pdf2pdfocr
A tool to OCR a PDF (or supported images) and add a text "layer" (a "pdf sandwich") in the original file making it a searchable PDF.
The script uses only open source tools.

# donations
This software is free, but if you like it, please donate to support new features.

<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_top">
<input type="hidden" name="cmd" value="_s-xclick">
<input type="hidden" name="encrypted" value="-----BEGIN PKCS7-----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-----END PKCS7-----
">
<input type="image" src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!">
<img alt="" border="0" src="https://www.paypalobjects.com/pt_BR/i/scr/pixel.gif" width="1" height="1">
</form>

<a href="https://flattr.com/submit/auto?fid=pojqg0&url=https%3A%2F%2Fgithub.com%2FLeoFCardoso%2Fpdf2pdfocr" target="_blank"><img src="https://button.flattr.com/flattr-badge-large.png" alt="Flattr this" title="Flattr this" border="0"></a>

# installation
In Linux, installation is straightforward. Just install required packages and be happy.
You can use "install_command" script to copy required files to "/usr/local/bin".

In OSX, you will need macports. Install macports, and run:
    
    xcode-select --install
    sudo port selfupdate
    sudo port install git tesseract tesseract-por tesseract-osd tesseract-eng python34 py34-reportlab py34-pip poppler poppler-data parallel ImageMagick wget pdftk
    sudo pip-3.4 install pypdf2
    # for versions < OSX 10.11
    wget https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.6-setup.pkg
    # for OSX 10.11 (http://stackoverflow.com/questions/32505951/pdftk-server-on-os-x-10-11)
    wget https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg
    # Install pdftk pkg manually

Note, wget and pdftk are optional. Macports version of pdftk won't build in OSX 10.11. So you have to install it manually with above commands.

In Windows, you will need to manually install required software.
Please read the document "Installing Windows tools for pdf2pdfocr" for a simple tutorial. It's also possible to use "Send To" menu using the "pdf2pdfocr.vbs" script.
# docker
The Dockerfile can be used to build a docker image to run pdf2pdfocr inside a container. To build the image, please download all sourcers and run.

    docker build -t leofcardoso/pdf2pdfocr:latest .
It's also possible to pull the docker image from docker hub.

    docker pull leofcardoso/pdf2pdfocr
You can run the application with docker run.

    docker run --rm -v "$(pwd):/home/docker" leofcardoso/pdf2pdfocr ./sample_file.pdf
# basic usage
This will create a searchable (OCR) PDF file in the same dir of "input_file".  

    pdf2pdfocr.py -i <input_file>  
In some cases, you will want to deal with option flags. Please use:  

    pdf2pdfocr.py --help 
to view all the options.
