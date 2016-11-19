# pdf2pdfocr
A tool to OCR a PDF (or supported images) and add a text "layer" (a "pdf sandwich") in the original file making it a searchable PDF.
The script uses only open source tools.

# donations
This software is free, but if you like it, please donate to support new features.

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=PZZU5APJGSWVA&lc=GB&item_name=pdf2pdfocr%20development&currency_code=USD)

[![flattr](https://button.flattr.com/flattr-badge-large.png)](https://flattr.com/submit/auto?fid=pojqg0&url=https%3A%2F%2Fgithub.com%2FLeoFCardoso%2Fpdf2pdfocr)

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
