#!/bin/bash

cd /home/docker
exec /opt/pdf2pdfocr/venv/bin/python3 /opt/pdf2pdfocr/pdf2pdfocr.py "$@"
