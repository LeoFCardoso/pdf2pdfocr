# pdf2pdfocr
#
# version 1.0
FROM ubuntu:16.04
MAINTAINER Leonardo F. Cardoso <leonardo.f.cardoso@gmail.com>

RUN useradd docker \
  && mkdir /home/docker \
  && chown docker:docker /home/docker

# Please uncomment tesseract-ocr-all if you want all languages to be installed
RUN apt-get update && apt-get install -y --no-install-recommends \
  file \
  ghostscript \
  imagemagick \
  locales \
  pdftk \
  poppler-utils \
  python3 \
  python3-pil \
  python3-pip \
  python3-reportlab \
  python3-setuptools\
  tesseract-ocr \
#  tesseract-ocr-all
  tesseract-ocr-osd tesseract-ocr-por tesseract-ocr-eng
  
# Complete python install
RUN pip3 install --upgrade pip \
  && pip3 install --upgrade pypdf2

# Clean
RUN apt-get autoremove -y && apt-get clean -y
RUN rm -rf /tmp/* /var/tmp/*

# Install application
COPY . /opt/install
WORKDIR /opt/install
RUN /opt/install/install_command

USER docker
WORKDIR /home/docker

ENTRYPOINT ["/opt/install/docker-wrapper.sh"]
#