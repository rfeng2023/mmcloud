#!/bin/bash

# Check if JupyterLab is available
if command -v jupyter-lab &> /dev/null
then
    echo "JupyterLab is available. Starting JupyterLab ..."
    jupyter-lab 
else
    echo "JupyterLab is not available. Starting tmate ..."
    tmate -F
fi