# pdf2pdfocr
#
# Dockerfile version 5.1
#
FROM ubuntu:20.04
MAINTAINER Leonardo F. Cardoso <leonardo.f.cardoso@gmail.com>

RUN useradd docker \
  && mkdir /home/docker \
  && chown docker:docker /home/docker

# Software dependencies [Start]
RUN apt-get update && apt-get install -y --no-install-recommends \
  cuneiform \
  qpdf \
  file \
  ghostscript \
  imagemagick \
  locales \
  poppler-utils \
  python3 \
  python3-pip \
  python3-setuptools\
  tesseract-ocr \
  tesseract-ocr-osd tesseract-ocr-por tesseract-ocr-eng
#  tesseract-ocr-all

# Allow IM to process PDF
RUN rm /etc/ImageMagick-6/policy.xml

# Software dependencies [End]

# Python 3 and deps [Start]
RUN pip3 install --upgrade packaging psutil Pillow reportlab \
 && pip3 install --upgrade lxml beautifulsoup4 \
 && pip3 install --upgrade wheel

RUN pip3 install --upgrade PyPDF2
# RUN pip3 install --upgrade https://github.com/mstamy2/PyPDF2/archive/master.zip
# Python 3 and deps [End]

RUN tesseract --list-langs    # just a test

# Clean
RUN rm -rf /tmp/* /var/tmp/*

# Install application
COPY . /opt/install
WORKDIR /opt/install
RUN /opt/install/install_command

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV OMP_THREAD_LIMIT 1

USER docker
WORKDIR /home/docker

ENTRYPOINT ["/opt/install/docker-wrapper.sh"]
#