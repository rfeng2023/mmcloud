#!/bin/bash
username=$(whoami)
cd /home/$username

# Link necessary dirs and files
ln -s /mnt/efs/$FLOAT_USER/.pixi /home/$username/.pixi
echo 'default_channels = ["dnachun", "conda-forge", "bioconda"]' > /home/$username/.pixi/config.toml
ln -s /mnt/efs/$FLOAT_USER/micromamba /home/$username/micromamba
ln -s /mnt/efs/$FLOAT_USER/.config /home/$username/.config
ln -s /mnt/efs/$FLOAT_USER/.cache /home/$username/.cache
ln -s /mnt/efs/$FLOAT_USER/.conda /home/$username/.conda
ln -s /mnt/efs/$FLOAT_USER/.condarc /home/$username/.condarc
ln -s /mnt/efs/$FLOAT_USER/.ipython /home/$username/.ipython
ln -s /mnt/efs/$FLOAT_USER/.jupyter /home/$username/.jupyter
ln -s /mnt/efs/$FLOAT_USER/.mamba /home/$username/.mamba
ln -s /mnt/efs/$FLOAT_USER/.local /home/$username/.local
ln -s /mnt/efs/$FLOAT_USER/.mambarc /home/$username/.mambarc

# Remove already existing .bashrc and .profile
rm /home/$username/.bashrc /home/$username/.profile

# Set a basic .bashrc and .profile if efs does not have them
if [ ! -f /mnt/efs/$FLOAT_USER/.bashrc ]; then
  cat << EOF > /mnt/efs/$FLOAT_USER/.bashrc
export PATH="\${HOME}/.pixi/bin:\${PATH}"
unset PYTHONPATH
export PYDEVD_DISABLE_FILE_VALIDATION=1
EOF
fi
if [ ! -f /mnt/efs/$FLOAT_USER/.profile ]; then
  cat << EOF > /mnt/efs/$FLOAT_USER/.profile
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

ln -s /mnt/efs/$FLOAT_USER/.bashrc /home/$username/.bashrc
ln -s /mnt/efs/$FLOAT_USER/.profile /home/$username/.profile

# Run the original entrypoint script
# Function to check if a command is available
export PATH="/home/$username/.pixi/bin":${PATH}
is_available() {
  location=$(which "$1" 2> /dev/null)
  if [ ! -z $location ]; then
    return 0
  else
    return 1
  fi
}

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
  jupyter|jupyter-lab)
    if is_available jupyter-lab; then
      echo "[$(date)]: JupyterLab is available. Starting JupyterLab ..."
      while true; do
          jupyter-lab
          # Check if jupyter-lab exited with a non-zero exit code
          if [ $? -ne 0 ]; then
              echo "[$(date)]: Jupyter Lab crashed, restarting..."
          else
              echo "[$(date)]: Jupyter Lab exited normally."
              break
          fi
          # Optionally, add a short sleep to avoid immediate retries
          sleep 30s
      done
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
  vscode)
    if is_available code-server; then
      echo "VS Code is available via code-server. Starting ..."
      code-server
    else
      echo "VS Code is not available."
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