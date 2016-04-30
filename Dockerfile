# pdf2pdfocr
#
# VERSION               1.0
FROM      ubuntu:15.10
MAINTAINER Leonardo F. Cardoso <leonardo.f.cardoso@gmail.com>

RUN useradd docker \
  && mkdir /home/docker \
  && chown docker:docker /home/docker

# Update system and install dependencies
# Please uncomment tesseract-ocr-all if you want all languages to be installed
RUN apt-get update && apt-get install -y --no-install-recommends \
  file \
  imagemagick \
  locales \
  parallel \
  pdftk \
  poppler-utils \
  python3 \
  python3-pil \
  python3-pip \
  python3-reportlab \
  python3-venv \
  tesseract-ocr \
#  tesseract-ocr-all
  tesseract-ocr-osd tesseract-ocr-por tesseract-ocr-eng
  
# Virtualenv for python
RUN pyvenv /appenv \
  && pyvenv --system-site-packages /appenv

# Complete python install
RUN . /appenv/bin/activate; \
  pip3 install --upgrade pip \
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