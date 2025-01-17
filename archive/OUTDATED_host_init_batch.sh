#!/bin/bash

cd /root
MODE=${MODE:-""}
EFS=${EFS:-""}

# Install aws
alias aws="/usr/local/aws-cli/v2/current/bin/aws"
export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${PATH}"

# EFS
yum install fuse gcc python3 bash nfs-utils --quiet -y
sudo mkdir -p /mnt/efs
sudo chmod 777 /mnt/efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $EFS:/ /mnt/efs

# Make sure it is mounted before end script
sleep 10s

# Make the directories if it does not exist already
# Reason why for so many if statements is to allow for new directories
# to be made without relying on if the user exists
if [ ! -d "/mnt/efs/shared/" ]; then
    sudo mkdir -p /mnt/efs/shared
    sudo chown -R mmc /mnt/efs/shared
    sudo chmod -R 777 /mnt/efs/shared
    sudo chgrp -R users /mnt/efs/shared
fi
if [ ! -d "/mnt/efs/shared/.pixi" ]; then
    sudo mkdir -p /mnt/efs/shared/.pixi
    sudo chown -R mmc /mnt/efs/shared/.pixi
    sudo chmod -R 777 /mnt/efs/shared/.pixi
    sudo chgrp -R users /mnt/efs/shared/.pixi
fi

if [ ! -d "/mnt/efs/shared/micromamba" ]; then
    sudo mkdir -p /mnt/efs/shared/micromamba
    sudo chown -R mmc /mnt/efs/shared/micromamba
    sudo chmod -R 777 /mnt/efs/shared/micromamba
    sudo chgrp -R users /mnt/efs/shared/micromamba
fi

if [ ! -d "/mnt/efs/shared/.config" ]; then
    sudo mkdir -p /mnt/efs/shared/.config
    sudo chown -R mmc /mnt/efs/shared/.config
    sudo chmod -R 777 /mnt/efs/shared/.config
    sudo chgrp -R users /mnt/efs/shared/.config
fi

if [ ! -d "/mnt/efs/shared/.cache" ]; then
    sudo mkdir -p /mnt/efs/shared/.cache
    sudo chown -R mmc /mnt/efs/shared/.cache
    sudo chmod -R 777 /mnt/efs/shared/.cache
    sudo chgrp -R users /mnt/efs/shared/.cache
fi

if [ ! -d "/mnt/efs/shared/.conda" ]; then
    sudo mkdir -p /mnt/efs/shared/.conda
    sudo chown -R mmc /mnt/efs/shared/.conda
    sudo chmod -R 777 /mnt/efs/shared/.conda
    sudo chgrp -R users /mnt/efs/shared/.conda
fi

if [ ! -f "/mnt/efs/shared/.condarc" ]; then
    # A file, not a directory
    sudo touch /mnt/efs/shared/.condarc
    sudo chown mmc /mnt/efs/shared/.condarc
    sudo chmod 777 /mnt/efs/shared/.condarc
    sudo chgrp users /mnt/efs/shared/.condarc
fi

if [ ! -d "/mnt/efs/shared/.ipython" ]; then
    sudo mkdir -p /mnt/efs/shared/.ipython
    sudo chown -R mmc /mnt/efs/shared/.ipython
    sudo chmod -R 777 /mnt/efs/shared/.ipython
    sudo chgrp -R users /mnt/efs/shared/.ipython
fi

if [ ! -d "/mnt/efs/shared/.jupyter" ]; then
    sudo mkdir -p /mnt/efs/shared/.jupyter
    sudo chown -R mmc /mnt/efs/shared/.jupyter
    sudo chmod -R 777 /mnt/efs/shared/.jupyter
    sudo chgrp -R users /mnt/efs/shared/.jupyter
fi

if [ ! -d "/mnt/efs/shared/.local" ]; then
    sudo mkdir -p /mnt/efs/shared/.local
    sudo chown -R mmc /mnt/efs/shared/.local
    sudo chmod -R 777 /mnt/efs/shared/.local
    sudo chgrp -R users /mnt/efs/shared/.local
fi

if [ ! -d "/mnt/efs/shared/.mamba/pkgs" ]; then
    sudo mkdir -p /mnt/efs/shared/.mamba/pkgs
    sudo chown -R mmc /mnt/efs/shared/.mamba
    sudo chmod -R 777 /mnt/efs/shared/.mamba
    sudo chgrp -R users /mnt/efs/shared/.mamba
fi

if [ ! -f "/mnt/efs/shared/.mambarc" ]; then
    # A file, not a directory
    sudo touch /mnt/efs/shared/.mambarc
    sudo chown mmc /mnt/efs/shared/.mambarc
    sudo chmod 777 /mnt/efs/shared/.mambarc
    sudo chgrp users /mnt/efs/shared/.mambarc
fi

# One-time case if .bashrc and .profile do not exist
# For bashrc and profile, if they do exist, make sure they have the right permissions
# for this setup
if [ ! -f "/mnt/efs/shared/.bashrc" ]; then
    sudo touch /mnt/efs/shared/.bashrc
fi
if [ ! -f "/mnt/efs/shared/.profile" ]; then
    sudo touch /mnt/efs/shared/.profile
fi

# For bashrc and profile, if they do exist, make sure they have the right permissions
# for this setup
if [ -f "/mnt/efs/shared/.bashrc" ]; then
    sudo chown mmc /mnt/efs/shared/.bashrc
    sudo chmod 777 /mnt/efs/shared/.bashrc
    sudo chgrp users /mnt/efs/shared/.bashrc
fi
if [ -f "/mnt/efs/shared/.profile" ]; then
    sudo chown mmc /mnt/efs/shared/.profile
    sudo chmod 777 /mnt/efs/shared/.profile
    sudo chgrp users /mnt/efs/shared/.profile
fi
