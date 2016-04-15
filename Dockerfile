# pdf2pdfocr
#
# VERSION               1.0
FROM      ubuntu:15.10
MAINTAINER Leonardo F. Cardoso <leonardo.f.cardoso@gmail.com>

RUN useradd docker \
  && mkdir /home/docker \
  && chown docker:docker /home/docker

# Update system and install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  locales \
  python3 \
  python3-pil \
  python3-pip \
  python3-reportlab \
  python3-venv

RUN apt-get install -y --no-install-recommends \
  file \
  imagemagick \
  parallel \
  pdftk
  
# Virtualenv for python
RUN pyvenv /appenv \
  && pyvenv --system-site-packages /appenv

# Complete python install
RUN . /appenv/bin/activate; \
  pip3 install --upgrade pip \
  && pip3 install --upgrade pypdf2

# Final dependencies
RUN apt-get install -y --no-install-recommends \
  poppler-utils \
  tesseract-ocr \
# tesseract-ocr-osd tesseract-ocr-por tesseract-ocr-eng
  tesseract-ocr-all

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