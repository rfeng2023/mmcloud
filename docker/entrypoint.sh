#!/bin/bash

# Function to check if a command is available
is_available() {
  command -v "$1" &> /dev/null
}

# Function to start the terminal server
start_terminal_server() {
  echo "Starting terminal server ..."
  tmate -F
}

# Check if VMUI variable is set
if [[ -z "${VMUI}" ]]; then
  echo "No UI specified."
  start_terminal_server
  exit 0
fi

# Check the value of VMUI and start the corresponding UI
case "${VMUI}" in
  jupyter)
    if is_available jupyter-lab; then
      echo "JupyterLab is available. Starting JupyterLab ..."
      jupyter-lab
    else
      echo "JupyterLab is not available."
      start_terminal_server
    fi
    ;;
  rstudio)
    if is_available rserver; then
      echo "RStudio is available. Starting RStudio ..."
      rserver --config-file=${HOME}/.pixi/envs/rstudio/etc/rstudio/rserver.conf
    else
      echo "RStudio is not available."
      start_terminal_server
    fi
    ;;
  nvim)
    if is_available nvim; then
      echo "Nvim is available. Starting Nvim ..."
      nvim
    else
      echo "Nvim is not available."
      start_terminal_server
    fi
    ;;
  *)
    echo "Unknown UI specified: ${VMUI}."
    start_terminal_server
    ;;
esac
