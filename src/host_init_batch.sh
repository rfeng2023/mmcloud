#!/bin/bash

cd /root
MODE=${MODE:-""}

# Install aws
alias aws="/usr/local/aws-cli/v2/current/bin/aws"
export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${PATH}"

# EFS
yum install fuse gcc python3 bash nfs-utils --quiet -y
sudo mkdir -p /mnt/efs
sudo chmod 777 /mnt/efs
# If mode is NOT oem_admin, set EFS to read only
if [[ ! -n ${MODE} ]]; then
    echo "MODE is NOT oem_admin. Set EFS to read-only"
    sudo mount -t nfs4 -o ro -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.1.10.231:/ /mnt/efs
else
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.1.10.231:/ /mnt/efs
fi


# Make sure it is mounted before end script
sleep 10s

# Make the directories if it does not exist already
# Reason why for so many if statements is to allow for new directories
# to be made without relying on if the user exists
if [ ! -d "/mnt/efs/oem/" ]; then
    sudo mkdir -p /mnt/efs/oem
    sudo chown -R mmc /mnt/efs/oem
    sudo chmod -R 777 /mnt/efs/oem
    sudo chgrp -R users /mnt/efs/oem
fi
if [ ! -d "/mnt/efs/oem/.pixi" ]; then
    sudo mkdir -p /mnt/efs/oem/.pixi
    sudo chown -R mmc /mnt/efs/oem/.pixi
    sudo chmod -R 777 /mnt/efs/oem/.pixi
    sudo chgrp -R users /mnt/efs/oem/.pixi
fi

if [ ! -d "/mnt/efs/oem/micromamba" ]; then
    sudo mkdir -p /mnt/efs/oem/micromamba
    sudo chown -R mmc /mnt/efs/oem/micromamba
    sudo chmod -R 777 /mnt/efs/oem/micromamba
    sudo chgrp -R users /mnt/efs/oem/micromamba
fi

if [ ! -d "/mnt/efs/oem/.config" ]; then
    sudo mkdir -p /mnt/efs/oem/.config
    sudo chown -R mmc /mnt/efs/oem/.config
    sudo chmod -R 777 /mnt/efs/oem/.config
    sudo chgrp -R users /mnt/efs/oem/.config
fi

if [ ! -d "/mnt/efs/oem/.cache" ]; then
    sudo mkdir -p /mnt/efs/oem/.cache
    sudo chown -R mmc /mnt/efs/oem/.cache
    sudo chmod -R 777 /mnt/efs/oem/.cache
    sudo chgrp -R users /mnt/efs/oem/.cache
fi

if [ ! -d "/mnt/efs/oem/.conda" ]; then
    sudo mkdir -p /mnt/efs/oem/.conda
    sudo chown -R mmc /mnt/efs/oem/.conda
    sudo chmod -R 777 /mnt/efs/oem/.conda
    sudo chgrp -R users /mnt/efs/oem/.conda
fi

if [ ! -d "/mnt/efs/oem/.condarc" ]; then
    # A file, not a directory
    sudo touch /mnt/efs/oem/.condarc
    sudo chown mmc /mnt/efs/oem/.condarc
    sudo chmod 777 /mnt/efs/oem/.condarc
    sudo chgrp users /mnt/efs/oem/.condarc
fi

if [ ! -d "/mnt/efs/oem/.ipython" ]; then
    sudo mkdir -p /mnt/efs/oem/.ipython
    sudo chown -R mmc /mnt/efs/oem/.ipython
    sudo chmod -R 777 /mnt/efs/oem/.ipython
    sudo chgrp -R users /mnt/efs/oem/.ipython
fi

if [ ! -d "/mnt/efs/oem/.jupyter" ]; then
    sudo mkdir -p /mnt/efs/oem/.jupyter
    sudo chown -R mmc /mnt/efs/oem/.jupyter
    sudo chmod -R 777 /mnt/efs/oem/.jupyter
    sudo chgrp -R users /mnt/efs/oem/.jupyter
fi

if [ ! -d "/mnt/efs/oem/.local" ]; then
    sudo mkdir -p /mnt/efs/oem/.local
    sudo chown -R mmc /mnt/efs/oem/.local
    sudo chmod -R 777 /mnt/efs/oem/.local
    sudo chgrp -R users /mnt/efs/oem/.local
fi

if [ ! -d "/mnt/efs/oem/.mamba/pkgs" ]; then
    sudo mkdir -p /mnt/efs/oem/.mamba/pkgs
    sudo chown -R mmc /mnt/efs/oem/.mamba
    sudo chmod -R 777 /mnt/efs/oem/.mamba
    sudo chgrp -R users /mnt/efs/oem/.mamba
fi

if [ ! -d "/mnt/efs/oem/.mambarc" ]; then
    # A file, not a directory
    sudo touch /mnt/efs/oem/.mambarc
    sudo chown mmc /mnt/efs/oem/.mambarc
    sudo chmod 777 /mnt/efs/oem/.mambarc
    sudo chgrp users /mnt/efs/oem/.mambarc
fi

# For bashrc and profile, if they do exist, make sure they have the right permissions
# for this setup
if [ -d "/mnt/efs/oem/.bashrc" ]; then
    sudo chown mmc /mnt/efs/oem/.bashrc
    sudo chmod 777 /mnt/efs/oem/.bashrc
    sudo chgrp users /mnt/efs/oem/.bashrc
fi
if [ -d "/mnt/efs/oem/.profile" ]; then
    sudo chown mmc /mnt/efs/oem/.profile
    sudo chmod 777 /mnt/efs/oem/.profile
    sudo chgrp users /mnt/efs/oem/.profile
fi
