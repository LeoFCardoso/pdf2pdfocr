# pdf2pdfocr
A tool to OCR a PDF (or supported images) and add a text "layer" (a "pdf sandwich") in the original file making it a searchable PDF.
The script uses only open source tools.

# donations
This software is free, but if you like it, please donate to support new features.

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=PZZU5APJGSWVA&lc=GB&item_name=pdf2pdfocr%20development&currency_code=USD)

[![flattr](https://button.flattr.com/flattr-badge-large.png)](https://flattr.com/submit/auto?fid=pojqg0&url=https%3A%2F%2Fgithub.com%2FLeoFCardoso%2Fpdf2pdfocr)

Bitcoin (BTC) address: [173D1zQQyzvCCCek9b1SpDvh7JikBEdtRJ](https://blockchair.com/bitcoin/address/173D1zQQyzvCCCek9b1SpDvh7JikBEdtRJ)

# tips
Tips are also welcome!

[![tippin.me](https://badgen.net/badge/%E2%9A%A1%EF%B8%8Ftippin.me/@LeoFCardoso/F0918E)](https://tippin.me/@LeoFCardoso)

Dogecoin (DOGE) address: [D94hD2qPnkxmZk8qa1b6F1d7NfUrPkmcrG](https://blockchair.com/dogecoin/address/D94hD2qPnkxmZk8qa1b6F1d7NfUrPkmcrG)

PIX (Brazilian Instant Payments): 0726e8f2-7e59-488a-8abb-bda8f0d7d9ce

[![chave PIX](https://raw.githubusercontent.com/LeoFCardoso/pdf2pdfocr/master/pix_qrcode.png)](https://nubank.com.br/pagar/414xb/ndt4lfy9GT)

Please contact for donations and tips in other cryptocurrencies.

# installation
In Linux, installation is straightforward. Just install required packages and be happy.
You can use "install_command" script to copy required files to "/usr/local/bin".

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
    sudo port install python37 py37-pip poppler poppler-data ImageMagick ghostscript
    # Configure default python3 installer
    sudo port select --set python3 python37
    sudo port select --set pip pip37
    # Install libs (please ignore warning messages)
    sudo pip3 install packaging psutil reportlab Gooey
    sudo pip3 install PyPDF2
    # Install optional libs (for cuneiform)
    sudo pip3 install lxml beautifulsoup4

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
