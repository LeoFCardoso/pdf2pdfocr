# pdf2pdfocr
#
# Dockerfile version 5.2
#
FROM ubuntu:20.04
MAINTAINER Leonardo F. Cardoso <leonardo.f.cardoso@gmail.com>

RUN useradd docker \
  && mkdir /home/docker \
  && chown docker:docker /home/docker

# OS Software dependencies [Start]
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
    tesseract-ocr-osd tesseract-ocr-por tesseract-ocr-eng \
  && rm -rf /var/lib/apt/lists/*

# Allow IM to process PDF
RUN rm /etc/ImageMagick-6/policy.xml

# OS Software dependencies [End]

RUN tesseract --list-langs    # just a test

# Clean
RUN rm -rf /tmp/* /var/tmp/*

# Install application
COPY . /opt/install
WORKDIR /opt/install
RUN /opt/install/install_command

# Python 3 and deps [Start]
RUN pip3 install -r requirements.txt
# Python 3 and deps [End]

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV OMP_THREAD_LIMIT 1

USER docker
WORKDIR /home/docker

ENTRYPOINT ["/opt/install/docker-wrapper.sh"]
#