#!/bin/bash

. /appenv/bin/activate
cd /home/docker
exec pdf2pdfocr.sh "$@"
