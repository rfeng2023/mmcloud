#!/bin/bash
username=$(whoami)
cd /home/$username

link_paths() {
    efs_path=$1
    local_path=$2
    paths=$3

    # Always link .pixi and micromamba folders from EFS mount to destination path
    ln -s ${efs_path}/.pixi ${local_path}/.pixi
    ln -s ${efs_path}/micromamba ${local_path}/micromamba

    # If we are mounting "minimal" paths and shared mode is "user", then we are linking a read-only,
    # shared software path so we make the mount path read only
    if [[ ${paths} == "minimal" && ${MODE} == "user" ]]; then
        chmod -w ${efs_path}/.pixi
        chmod -w ${efs_path}/micromamba
    fi

    # If we are mountng "full" paths, link all of the directories with config files
    if [[ ${paths} == "full" ]]; then
        # We probably don't need this first line any more - need to check
        echo 'default_channels = ["dnachun", "conda-forge", "bioconda"]' > ${local_path}/.pixi/config.toml

        ln -s ${efs_path}/.config ${local_path}/.config
        ln -s ${efs_path}/.cache ${local_path}/.cache
        ln -s ${efs_path}/.conda ${local_path}/.conda
        ln -s ${efs_path}/.condarc ${local_path}/.condarc
        ln -s ${efs_path}/.ipython ${local_path}/.ipython
        ln -s ${efs_path}/.jupyter ${local_path}/.jupyter
        ln -s ${efs_path}/.mamba ${local_path}/.mamba
        ln -s ${efs_path}/.local ${local_path}/.local
        ln -s ${efs_path}/.mambarc ${local_path}/.mambarc
    fi

    # If we are linking full paths, create a basic .bashrc and .profile if they don't exist on the EFS mount
    # and link those files to the local path
    # We also need to do this if we are in admin mode for the shared or OEM folders, as these folders (for now) won't have a bashrc
    if [[ ${paths} == "full" || ${MODE} == "oem_admin" || ${MODE} == "shared_admin" ]]; then
        # Remove existing .bashrc and .profile
        rm ${local_path}/.bashrc ${local_path}/.profile

        # Set a basic .bashrc and .profile if efs does not have them
        if [ ! -f ${efs_path}/.bashrc ]; then
            tee ${efs_path}/.bashrc << EOF
export PATH="/mnt/efs/shared/.pixi/bin:\${PATH}"
export PATH="\${HOME}/.pixi/bin:\${PATH}"
unset PYTHONPATH
export PYDEVD_DISABLE_FILE_VALIDATION=1
EOF
        fi
        if [ ! -f ${efs_path}/.profile ]; then
            cat ${efs_path}/.profile << EOF
# if running bash
if [ -n "\$BASH_VERSION" ]; then
  # include .bashrc if it exists
  if [ -f "\$HOME/.bashrc" ]; then
      . "\$HOME/.bashrc"
  fi
fi
EOF
        fi

        ln -s ${efs_path}/.bashrc ${local_path}/.bashrc
        ln -s ${efs_path}/.profile ${local_path}/.profile
    fi
}

# Link necessary dirs and files
if [[ ${MODE} == "oem_admin" ]]; then
    link_paths /mnt/efs/oem /home/${username} minimal
elif [[ ${MODE} == "shared_admin" ]]; then
    link_paths /mnt/efs/shared /home/${username} minimal
elif [[ ${MODE} == "user" ]]; then
    link_paths /mnt/efs/${FLOAT_USER} /home/${username} full
else
    echo -e "ERROR: invalid mode specified - must be one of oem_admin, shared_admin or user"
fi

# Run the original entrypoint script
# Function to check if a command is available
export PATH="/home/$username/.pixi/bin":${PATH}
source /home/$username/.bashrc
echo "PATH: $PATH"

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
          sleep 15s
      done
    else
      echo "JupyterLab is not available."
      start_terminal_server
    fi
    ;;
  rstudio)
    if is_available rserver; then
      echo "RStudio is available. Starting RStudio ..."
      rserver --config-file=${HOME}/.config/rstudio/rserver.conf
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
