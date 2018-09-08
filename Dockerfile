# pdf2pdfocr
#
# Dockerfile version 3.0 - Alpine linux
#
FROM alpine:3.8
MAINTAINER Leonardo F. Cardoso <leonardo.f.cardoso@gmail.com>

RUN addgroup docker \
 && adduser -G docker -D docker \
 && chown docker:docker /home/docker

# Python 3 and deps [Start]
RUN apk add --no-cache python3 \
 && python3 -m ensurepip \
 && pip3 install --upgrade pip setuptools \
 && pip3 install --upgrade https://github.com/mstamy2/PyPDF2/archive/master.zip

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
    # portuguese (please download more languages if you need) - tesseract branch 3.04 and 3.05
    wget -q -P /usr/share/tessdata/ "https://raw.githubusercontent.com/tesseract-ocr/tessdata/3.04.00/por.traineddata"

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