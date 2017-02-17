# pdf2pdfocr
#
# Dockerfile version 2.0 - Alpine linux
#
FROM alpine:3.5
MAINTAINER Leonardo F. Cardoso <leonardo.f.cardoso@gmail.com>

RUN addgroup docker \
 && adduser -G docker -D docker \
 && chown docker:docker /home/docker

# Python 3 and deps [Start]
RUN apk add --no-cache python3 \
 && python3 -m ensurepip \
 && pip3 install --upgrade pip setuptools \
 && pip3 install --upgrade pypdf2

RUN apk add --no-cache build-base linux-headers python3-dev zlib-dev jpeg-dev

RUN pip3 install --upgrade Pillow reportlab

RUN rm -r /usr/lib/python*/ensurepip \
 && rm -r /root/.cache
# Python 3 and deps [End]

# Software dependencies [Start]
RUN apk add --no-cache ghostscript
RUN apk add --no-cache imagemagick
RUN apk add --no-cache pdftk
RUN apk add --no-cache poppler-utils
RUN apk add --no-cache tesseract-ocr
RUN apk add --no-cache wget ca-certificates
RUN \
    # english
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.cube.bigrams && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.cube.bigrams && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.cube.fold && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.cube.lm && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.cube.nn && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.cube.params && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.cube.size && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.cube.word-freq && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.tesseract_cube.nn && \
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/eng.traineddata && \
    # portuguese
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/por.traineddata && \
    # osd - hocr option
    wget -q -P /usr/share/tessdata/ https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/osd.traineddata
    # please download more languages if you need.
RUN tesseract --list-langs    # just a test
RUN apk add --no-cache file
RUN apk add --no-cache bash
# Software dependencies [End]

# Clean
RUN rm -rf /tmp/* /var/tmp/*

# Install application
COPY . /opt/install
WORKDIR /opt/install
RUN /opt/install/install_command

USER docker
WORKDIR /home/docker

ENTRYPOINT ["/opt/install/docker-wrapper.sh"]
#