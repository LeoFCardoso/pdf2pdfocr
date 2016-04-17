# pdf2pdfocr
A tool to OCR a PDF (or supported images) and add a text "layer" in the original file making it a searchable PDF. The script uses only open source tools.
# installation
In Linux and OSX (macports), installation is straightforward. Just install required packages and be happy. You can use "install_command" script to copy required files to "/usr/local/bin".  
In Windows, you will need Cygwin. Please read the document "Installing Windows tools for pdf2pdfocr" for a simple tutorial. It's also possible to use "Send To" menu using the "pdf2pdfocr.cmd" script.
# docker
The Dockerfile can be used to build a docker image to run pdf2pdfocr inside a container. To build the image, please download all sourcers and run.

    docker build -t leofcardoso/pdf2pdfocr:latest .
It's also possible to pull the docker imagem from docker hub.

    docker pull leofcardoso/pdf2pdfocr
You can run the application with docker run.

    docker run --rm -v "$(pwd):/home/docker" leofcardoso/pdf2pdfocr ./sample_file.pdf
# basic usage
This will create a searchable (OCR) PDF file in the same dir of "input_file".  

    pdf2pdfocr.sh <input_file>  
In some cases, you will want to deal with option flags. Please use:  

    pdf2pdfocr.sh -?  
to view all the options.
