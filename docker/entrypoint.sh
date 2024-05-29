#!/bin/bash

# Check if JupyterLab is available
if command -v jupyter-lab &> /dev/null
then
    echo "JupyterLab is available. Starting JupyterLab on port 8080..."
    jupyter-lab --port 8080
else
    echo "JupyterLab is not available. Starting ttyd on port 8080..."
    ttyd --port 8080 bash
fi