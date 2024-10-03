#!/bin/bash

cd /root

# Install aws
alias aws="/usr/local/aws-cli/v2/current/bin/aws"
export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${PATH}"

# Install Juicefs, redis, and fuse
yum install fuse gcc python3 bash --quiet -y
curl -sSL https://d.juicefs.com/install | sh -

# Format Juicefs
echo "Formatting Juicefs"
/usr/local/bin/juicefs format --storage s3 \
--bucket https://wanggroup.s3.us-east-1.amazonaws.com \
--trash-days=0 \
"rediss://clustercfg.gao-package-installation.tw2oou.memorydb.us-east-1.amazonaws.com:6379/1" \
wanggroup-package-installation-memory 2>&1 >/dev/null

# Mount Juicefs
echo "Mounting juicefs"
sudo mkdir -p /mnt/jfs
sudo chmod 777 /mnt/jfs
nohup /usr/local/bin/juicefs mount \
"rediss://clustercfg.gao-package-installation.tw2oou.memorydb.us-east-1.amazonaws.com:6379/1" \
--buffer-size 600 \
--writeback \
--cache-dir /mnt/jfs_cache \
--cache-size 102400 \
--backup-skip-trash \
--max-uploads=200 \
--prefetch 10 \
/mnt/jfs 1> /dev/null  2>&1 &

# Make sure it is mounted before end script
sleep 10s

# Make the directories if it does not exist already
# Reason why for so many if statements is to allow for new directories
# to be made without relying on if the user exists
if [ ! -d "/mnt/jfs/$FLOAT_USER/" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER
fi
if [ ! -d "/mnt/jfs/$FLOAT_USER/.pixi" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.pixi
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.pixi
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.pixi
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.pixi
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/micromamba" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/micromamba
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/micromamba
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/micromamba
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/micromamba
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.config" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.config
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.config
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.config
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.config
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.cache" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.cache
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.cache
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.cache
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.cache
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.conda" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.conda
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.conda
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.conda
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.conda
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.condarc" ]; then
    # A file, not a directory
    sudo touch /mnt/jfs/$FLOAT_USER/.condarc
    sudo chown mmc /mnt/jfs/$FLOAT_USER/.condarc
    sudo chmod 777 /mnt/jfs/$FLOAT_USER/.condarc
    sudo chgrp users /mnt/jfs/$FLOAT_USER/.condarc
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.ipython" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.ipython
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.ipython
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.ipython
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.ipython
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.jupyter" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.jupyter
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.jupyter
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.jupyter
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.jupyter
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.local" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.local
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.local
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.local
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.local
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.mamba/pkgs" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.mamba/pkgs
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.mamba
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.mamba
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.mamba
fi

if [ ! -d "/mnt/jfs/$FLOAT_USER/.local" ]; then
    sudo mkdir -p /mnt/jfs/$FLOAT_USER/.local
    sudo chown -R mmc /mnt/jfs/$FLOAT_USER/.local
    sudo chmod -R 777 /mnt/jfs/$FLOAT_USER/.local
    sudo chgrp -R users /mnt/jfs/$FLOAT_USER/.local
fi

# For bashrc and profile, if they do exist, make sure they have the right permissions
# for this setup
if [ -d "/mnt/jfs/$FLOAT_USER/.bashrc" ]; then
    sudo chown mmc /mnt/jfs/$FLOAT_USER/.bashrc
    sudo chmod 777 /mnt/jfs/$FLOAT_USER/.bashrc
    sudo chgrp users /mnt/jfs/$FLOAT_USER/.bashrc
fi
if [ -d "/mnt/jfs/$FLOAT_USER/.profile" ]; then
    sudo chown mmc /mnt/jfs/$FLOAT_USER/.profile
    sudo chmod 777 /mnt/jfs/$FLOAT_USER/.profile
    sudo chgrp users /mnt/jfs/$FLOAT_USER/.profile
fi
