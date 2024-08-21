#!/bin/bash
cd /home/jovyan

# Link necessary dirs and files
ln -s /mnt/jfs/$FLOAT_USER/.pixi /home/jovyan/.pixi
echo 'default_channels = ["dnachun", "conda-forge", "bioconda"]' > /home/jovyan/.pixi/config.toml
ln -s /mnt/jfs/$FLOAT_USER/.config /home/jovyan/.config
ln -s /mnt/jfs/$FLOAT_USER/micromamba /home/jovyan/micromamba

# Remove already existing .bashrc and .profile
rm /home/jovyan/.bashrc /home/jovyan/.profile

# Set a basic .bashrc and .profile if jfs does not have them
if [ ! -f /mnt/jfs/$FLOAT_USER/.bashrc ]; then
  cat << EOF > /mnt/jfs/$FLOAT_USER/.bashrc
export PATH="\${HOME}/.pixi/bin:\${PATH}"
unset PYTHONPATH
export PYDEVD_DISABLE_FILE_VALIDATION=1
EOF
fi
if [ ! -f /mnt/jfs/$FLOAT_USER/.profile ]; then
  cat << EOF > /mnt/jfs/$FLOAT_USER/.profile
# if running bash
if [ -n "\$BASH_VERSION" ]; then
  # include .bashrc if it exists
  if [ -f "\$HOME/.bashrc" ]; then
      . "\$HOME/.bashrc"
  fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "\$HOME/bin" ] ; then
  PATH="\$HOME/bin:\$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "\$HOME/.local/bin" ] ; then
  PATH="\$HOME/.local/bin:\$PATH"
fi
EOF
fi

ln -s /mnt/jfs/$FLOAT_USER/.bashrc /home/jovyan/.bashrc
ln -s /mnt/jfs/$FLOAT_USER/.profile /home/jovyan/.profile

# Run the original entrypoint script
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
    if is_available rstudio; then
      echo "RStudio is available. Starting RStudio ..."
      rstudio
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