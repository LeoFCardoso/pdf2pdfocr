# pdf2pdfocr
#
# Dockerfile version 8.0 (Ubuntu 26.04 LTS)
#
FROM ubuntu:26.04
LABEL maintainer="Leonardo F. Cardoso <leonardo.f.cardoso@gmail.com>"

RUN useradd docker \
  && mkdir /home/docker \
  && chown docker:docker /home/docker

# OS Software dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    qpdf \
    file \
    ghostscript \
    imagemagick \
    locales \
    poppler-utils \
    python3 \
    python3-pip \
    python3-setuptools\
    python3-venv \
    tesseract-ocr \
    tesseract-ocr-osd tesseract-ocr-por tesseract-ocr-eng \
  && apt-get clean \
  && rm -rf /usr/share/doc/* /usr/share/man/* \
  && rm -rf /var/lib/apt/lists/*

# Allow IM to process PDF
RUN rm /etc/ImageMagick-7/policy.xml

# Uncomment for test
# RUN tesseract --list-langs

# Install venv and application
WORKDIR /opt/pdf2pdfocr
COPY requirements.txt .

RUN python3 -m venv /opt/pdf2pdfocr/venv \
  && /opt/pdf2pdfocr/venv/bin/pip3 install --upgrade pip wheel \
  && /opt/pdf2pdfocr/venv/bin/pip3 install --only-binary=:all: --no-cache-dir -r requirements.txt

COPY pdf2pdfocr* docker-wrapper.sh /opt/pdf2pdfocr/

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 OMP_THREAD_LIMIT=1 MAGICK_THREAD_LIMIT=1

# Clean
RUN rm -rf /tmp/* /var/tmp/*

USER docker
WORKDIR /home/docker

ENTRYPOINT ["/opt/pdf2pdfocr/docker-wrapper.sh"]
#