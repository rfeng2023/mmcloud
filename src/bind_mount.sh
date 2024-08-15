#!/bin/bash
cd /home/jovyan

ln -s /mnt/jfs/$FLOAT_USER/.pixi /home/jovyan/.pixi
ln -s /mnt/jfs/$FLOAT_USER/micromamba /home/jovyan/micromamba

# Run tmate
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