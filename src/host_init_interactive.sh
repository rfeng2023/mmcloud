#!/bin/bash

cd /root

# Install aws
alias aws="/usr/local/aws-cli/v2/current/bin/aws"
export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${PATH}"

# EFS
yum install fuse gcc python3 bash nfs-utils --quiet -y
sudo mkdir -p /mnt/efs
sudo chmod 777 /mnt/efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.1.10.236:/ /mnt/efs

# Make sure it is mounted before end script
sleep 10s

# Make the directories if it does not exist already
# Reason why for so many if statements is to allow for new directories
# to be made without relying on if the user exists
if [ ! -d "/opt/shared" ]; then
    sudo mkdir -p /opt/shared
    sudo chown -R mmc /opt/shared
    sudo chmod -R 777 /opt/shared
    sudo chgrp -R users /opt/shared
fi
if [ ! -d "/mnt/efs/$FLOAT_USER/" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER
    sudo chown -R mmc /mnt/efs/$FLOAT_USER
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER
    sudo chgrp -R users /mnt/efs/$FLOAT_USER
fi
if [ ! -d "/mnt/efs/$FLOAT_USER/.pixi" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.pixi
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.pixi
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.pixi
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.pixi
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/micromamba" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/micromamba
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/micromamba
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/micromamba
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/micromamba
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.config" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.config
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.config
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.config
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.config
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.cache" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.cache
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.cache
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.cache
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.cache
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.conda" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.conda
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.conda
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.conda
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.conda
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.condarc" ]; then
    # A file, not a directory
    sudo touch /mnt/efs/$FLOAT_USER/.condarc
    sudo chown mmc /mnt/efs/$FLOAT_USER/.condarc
    sudo chmod 777 /mnt/efs/$FLOAT_USER/.condarc
    sudo chgrp users /mnt/efs/$FLOAT_USER/.condarc
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.ipython" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.ipython
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.ipython
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.ipython
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.ipython
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.jupyter" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.jupyter
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.jupyter
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.jupyter
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.jupyter
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.local" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.local
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.local
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.local
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.local
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.mamba/pkgs" ]; then
    sudo mkdir -p /mnt/efs/$FLOAT_USER/.mamba/pkgs
    sudo chown -R mmc /mnt/efs/$FLOAT_USER/.mamba
    sudo chmod -R 777 /mnt/efs/$FLOAT_USER/.mamba
    sudo chgrp -R users /mnt/efs/$FLOAT_USER/.mamba
fi

if [ ! -d "/mnt/efs/$FLOAT_USER/.mambarc" ]; then
    # A file, not a directory
    sudo touch /mnt/efs/$FLOAT_USER/.mambarc
    sudo chown mmc /mnt/efs/$FLOAT_USER/.mambarc
    sudo chmod 777 /mnt/efs/$FLOAT_USER/.mambarc
    sudo chgrp users /mnt/efs/$FLOAT_USER/.mambarc
fi

# For bashrc and profile, if they do exist, make sure they have the right permissions
# for this setup
if [ -d "/mnt/efs/$FLOAT_USER/.bashrc" ]; then
    sudo chown mmc /mnt/efs/$FLOAT_USER/.bashrc
    sudo chmod 777 /mnt/efs/$FLOAT_USER/.bashrc
    sudo chgrp users /mnt/efs/$FLOAT_USER/.bashrc
fi
if [ -d "/mnt/efs/$FLOAT_USER/.profile" ]; then
    sudo chown mmc /mnt/efs/$FLOAT_USER/.profile
    sudo chmod 777 /mnt/efs/$FLOAT_USER/.profile
    sudo chgrp users /mnt/efs/$FLOAT_USER/.profile
fi

# This section will rename the files under /opt/share/.pixi/bin/trampoline_configuration to point to the right location
# This is so non-admin users will be able to use shared packages
for file in /mnt/efs/shared/.pixi/bin/trampoline_configuration/*.json; do
    sed -i 's|/home/ubuntu/.pixi|/opt/shared/.pixi|g' "$file"
done
