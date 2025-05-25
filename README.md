# pdf2pdfocr
A tool to OCR a PDF (or supported images) and add a text "layer" (a "pdf sandwich") in the original file making it a searchable PDF.
The script uses only open source tools.

# donations
This software is free, but if you like it, please donate to support new features.

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=PZZU5APJGSWVA&lc=GB&item_name=pdf2pdfocr%20development&currency_code=USD)

Bitcoin (BTC) address: [bc1qqd4pj0pymptwg523ems8pxgjwdslh7ujv5egqg](https://blockchair.com/bitcoin/address/bc1qqd4pj0pymptwg523ems8pxgjwdslh7ujv5egqg)

# tips
Tips are also welcome!

Dogecoin (DOGE) address: [D94hD2qPnkxmZk8qa1b6F1d7NfUrPkmcrG](https://blockchair.com/dogecoin/address/D94hD2qPnkxmZk8qa1b6F1d7NfUrPkmcrG)

PIX (Brazilian Instant Payments): 54fdb88f-dae3-433b-9e4d-e0c0408daf74

[![chave PIX](https://raw.githubusercontent.com/LeoFCardoso/pdf2pdfocr/master/pix_qrcode.png)]()

Please contact for donations and tips in other cryptocurrencies.

# installation
In Linux, please try these instructions (thanks to @nicoursi).

    # 1. Create the virtual environment
    python3 -m venv ~/pdf2pdfocr-venv
    # 2. Activate the virtual environment
    source ~/pdf2pdfocr-venv/bin/activate
    # 3. Install dependencies
    pip install -r requirements.txt
    # 4. Copy Python files to the virtual environment bin directory
    cp *.py ~/pdf2pdfocr-venv/bin/
    # 5. Copy executables to /usr/local/bin
    cp pdf2pdfocr pdf2pdfocr_gui /usr/local/bin

In macOS, you will need macports.
    
    # First install Xcode from Mac App Store, then:
    xcode-select --install
    sudo xcodebuild -license
    # Install Macports from https://www.macports.org/install.php
    sudo port selfupdate
    # Install tesseract as main ocr engine (Portuguese included below - please add your preferred languages)
    sudo port install git libtool automake autoconf tesseract tesseract-por tesseract-osd tesseract-eng
    # Install cuneiform (the optional ocr engine - see flag "-c")
    sudo port install cuneiform
    # Install qpdf (optional for better performance)
    sudo port install qpdf
    # Install python 3 and other dependencies
    sudo port install python312 py312-pip poppler poppler-data ImageMagick ghostscript
    # Configure default python3 installer
    sudo port select --set python python312
    sudo port select --set python3 python312
    sudo port select --set pip pip312
    sudo port select --set pip3 pip312
    # Configure venv and python deps in fixed home directory
    python3 -m venv ~/pdf2pdfocr-venv
    ~/pdf2pdfocr-venv/bin/python3 -m pip install --upgrade pip
    ~/pdf2pdfocr-venv/bin/pip3 install --upgrade setuptools
    ~/pdf2pdfocr-venv/bin/pip3 install -r requirements.txt
    ~/pdf2pdfocr-venv/bin/pip3 install -r requirements_gui.txt
    # Copy main scripts to venv
    cp pdf2pdfocr.py pdf2pdfocr_gui.py pdf2pdfocr_multibackground.py ~/pdf2pdfocr-venv/bin
    sudo ./install_command

Cuneiform and qpdf are optional.

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

# fun
Caseiro com orgulho! ;-)
