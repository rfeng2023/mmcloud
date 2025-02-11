#!/bin/bash
username=$(whoami)
cd /home/$username

link_paths() {
  efs_path=$1
  local_path=$2
  paths=$3

  # Do not symlink if paths is none (only for oem_packages)
  if [[ ${paths} != "none" ]]; then
    ln -s ${efs_path}/.pixi ${local_path}/.pixi
    ln -s ${efs_path}/micromamba ${local_path}/micromamba

    # To link .bashrc and .profile, need to remove the original (not for oem_packages)
    rm ${local_path}/.bashrc ${local_path}/.profile
    ln -s ${efs_path}/.bashrc ${local_path}/.bashrc
    ln -s ${efs_path}/.profile ${local_path}/.profile
  fi

  # If we are mountng "full" paths, link all of the directories with config files
  # This is for mount_packages and oem_mount_packages
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
      ln -s ${efs_path}/ghq ${local_path}/ghq
  fi

  # After installing pixi, it adds the local dir to the PATH through the .bashrc
  # Because we do not want multiple $HOME to front of PATH
  # We need to make a new .bashrc every time.
  echo -e "Making new .bashrc...\n"
  tee ${efs_path}/.bashrc << EOF
source \$HOME/.set_paths
unset PYTHONPATH
export PYDEVD_DISABLE_FILE_VALIDATION=1
EOF
}

set_paths() {
  efs_path=$1
  mode=$2

  # Create a PATH script - does not need to be saved in EFS
  # (new every time for easy editing)
  if [[ ${mode} == "mount_packages" ]]; then
    # mount_packages will not use shared packages, so no need to add /mnt/efs/shared/.pixi/bin to PATH
    tee ${HOME}/.set_paths << EOF
export PATH="\${HOME}/.pixi/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
  else
    # For all other modes, to avoid potential conflicts between user installed packages in their home folder (whether it's saved to EFS or not)
    # We set the HOME path before the shared path
    tee ${HOME}/.set_paths << EOF 
export PATH="\${HOME}/.pixi/bin:/mnt/efs/shared/.pixi/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
  fi
  # --- This section is mainly for updating the .bashrc ---
  # --- When previous versions used /opt/shared instead of /mnt/efs/shared ---
  # Update bashrc to remove /opt/shared and replace with /mnt/efs/shared
  if grep -Fxq 'export PATH="/opt/shared/.pixi/bin:${PATH}"' ~/.bashrc; then
      echo "/opt/shared exists in .bashrc. Updating the path..."
      sed -i 's|/opt/shared|/mnt/efs/shared|g' ~/.bashrc
      echo "Path updated to use /mnt/efs/shared."
  fi
  # ---------------------------------------------------------------------------

  source $efs_path/.bashrc
  echo "PATH: $PATH"
}

# Link necessary dirs and files
# The efs_path, or first parameter in link_paths and set_paths, is the location of their .bashrc
if [[ ${MODE} == "shared_admin" ]]; then
  # For updating shared packages
  link_paths /mnt/efs/shared /home/${username} full
  set_paths /mnt/efs/shared shared_admin
elif [[ ${MODE} == "oem_packages" ]]; then
  # Can access shared packages but NOT user packages. Can install packages locally
  link_paths /mnt/efs/shared /home/${username} none
  set_paths /mnt/efs/shared oem_packages
elif [[ ${MODE} == "mount_packages" ]]; then
  # Can NOT access shared packages, but can see user packages. Can install user packages on EFS
  link_paths /mnt/efs/${FLOAT_USER} /home/${username} full
  set_paths /mnt/efs/${FLOAT_USER} mount_packages
elif [[ ${MODE} == "oem_mount_packages" ]]; then
  # Can access shared and user packages in the EFS. Can install user packages on EFS
  link_paths /mnt/efs/${FLOAT_USER} /home/${username} full
  set_paths /mnt/efs/${FLOAT_USER} oem_mount_packages
else
  echo -e "ERROR: invalid mode specified - must be one of oem_admin, shared_admin or user"
  exit 1
fi

# Update channel config file if it does not exist already
if [ ! -d "${HOME}/.pixi" ] && [ ! -f "${HOME}/.pixi/config.toml" ]; then
  mkdir -p ${HOME}/.pixi && echo 'default_channels = ["dnachun", "conda-forge", "bioconda"]' > ${HOME}/.pixi/config.toml
fi

# init.sh run after it is updated
curl -O https://raw.githubusercontent.com/gaow/misc/refs/heads/master/bash/pixi/init.sh
chmod +x init.sh
./init.sh

# Run entrypoint if given
if [[ ! -z "$ENTRYPOINT" ]]; then
    curl -fsSL ${ENTRYPOINT} | bash
else
# Else run original VMUI check
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

fi