# pdf2pdfocr
A tool to OCR a PDF (or supported images) and add a text "layer" (a "pdf sandwich") in the original file making it a searchable PDF.
The script uses only open source tools.

# donations
This software is free, but if you like it, please donate to support new features.

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=PZZU5APJGSWVA&lc=GB&item_name=pdf2pdfocr%20development&currency_code=USD)

[![flattr](https://button.flattr.com/flattr-badge-large.png)](https://flattr.com/submit/auto?fid=pojqg0&url=https%3A%2F%2Fgithub.com%2FLeoFCardoso%2Fpdf2pdfocr)

Bitcoin (BTC) address: 173D1zQQyzvCCCek9b1SpDvh7JikBEdtRJ

Niobio Cash (NBR - https://niobiocash.org) address: N918uWiGba4ZcCBsc8nZrqhRaucjAZvhnMQ6WA7ubKoNhgNmWS1xn1pThP9HJG6rWqVEEWSPRkJff6dQjCEtbgtMP2Eudcr

Please contact for donations in other cryptocurrencies.

# installation
In Linux, installation is straightforward. Just install required packages and be happy.
You can use "install_command" script to copy required files to "/usr/local/bin".

In macOS, you will need macports.
    
    # First install Xcode from Mac App Store, then:
    xcode-select --install
    sudo xcodebuild -license
    # Install Macports from https://www.macports.org/install.php
    sudo port selfupdate
    # Install tesseract (Portuguese included below - please add your preferred languages)
    sudo port install git libtool automake autoconf tesseract tesseract-por tesseract-osd tesseract-eng
    # Install python 3 and other dependencies
    sudo port install python37 py37-pip poppler poppler-data ImageMagick wget ghostscript
    # Configure default python3 installer
    sudo port select --set python3 python37
    sudo port select --set pip pip37
    # Install libs (please ignore warning messages)
    sudo pip install reportlab Gooey
    sudo pip install https://github.com/mstamy2/PyPDF2/archive/master.zip
    # Install pdftk (may fail eventually with macports)
    sudo port install pdftk
    # if fail, please install pdftk manually
    # for versions <  macOS 10.11
      wget https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.6-setup.pkg
    # for versions >= macOS 10.11 (http://stackoverflow.com/questions/32505951/pdftk-server-on-os-x-10-11)
      wget https://www.pdflabs.com/tools/pdftk-the-pdf-toolkit/pdftk_server-2.02-mac_osx-10.11-setup.pkg

Note, wget and pdftk are optional. If macports version of pdftk fail to install, you have to install it manually with above command (or never use "-p" flag).

In Windows, you will need to manually install required software. Please read "install_windows.txt" file and try the tutorial with scoop tool. It's easy! :-)

# docker (without GUI)
The Dockerfile can be used to build a docker image to run pdf2pdfocr inside a container. To build the image, please download all sources and run.

    docker build -t leofcardoso/pdf2pdfocr:latest .
It's also possible to pull the docker image from docker hub.

    docker pull leofcardoso/pdf2pdfocr
You can run the application with docker run.

    docker run --rm -v "$(pwd):/home/docker" leofcardoso/pdf2pdfocr -v -i ./sample_file.pdf
# basic usage
This will create a searchable (OCR) PDF file in the same dir of "input_file".  

    pdf2pdfocr.py -i <input_file>  
In some cases, you will want to deal with option flags. Please use:  

    pdf2pdfocr.py --help 
to view all the options.

It's also possible to use GUI.
    
    pdf2pdfocr_gui.py <<optional input file>>
