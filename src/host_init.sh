#!/bin/bash

cd /root

# Install aws
alias aws="/usr/local/aws-cli/v2/current/bin/aws"
export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${PATH}"

# Install Juicefs, redis, and fuse
yum install fuse gcc python3 bash --quiet -y

JFS_LATEST_TAG=$(curl -s https://api.github.com/repos/juicedata/juicefs/releases/latest | grep 'tag_name' | cut -d '"' -f 4 | tr -d 'v')
wget -q "https://github.com/juicedata/juicefs/releases/download/v${JFS_LATEST_TAG}/juicefs-${JFS_LATEST_TAG}-linux-amd64.tar.gz"
tar zxf "juicefs-${JFS_LATEST_TAG}-linux-amd64.tar.gz"
sudo install juicefs /usr/local/bin

# Format Juicefs
echo "Formatting Juicefs"
/usr/local/bin/juicefs format --storage s3 \
--bucket https://wanggroup.s3.us-east-1.amazonaws.com \
--trash-days=0 \
"mysql://wanggroup:wanggroup@(gao-package-installation-test.cluster-cr2aikmwy2vn.us-east-1.rds.amazonaws.com:3306)/juicefs" \
wanggroup-package-installation 2>&1 >/dev/null

# Mount Juicefs
echo "Mounting juicefs"
sudo mkdir -p /mnt/jfs
sudo chmod 777 /mnt/jfs
nohup /usr/local/bin/juicefs mount \
"mysql://wanggroup:wanggroup@(gao-package-installation-test.cluster-cr2aikmwy2vn.us-east-1.rds.amazonaws.com:3306)/juicefs" \
--buffer-size 600 \
--writeback \
--cache-dir /mnt/jfs_cache \
/mnt/jfs 1> /dev/null  2>&1 &

# Make sure it is mounted before end script
sleep 10s

# Make the directories if it does not exist already
sudo mkdir -p /mnt/jfs/$FLOAT_USER
sudo mkdir -p /mnt/jfs/$FLOAT_USER/.pixi
sudo mkdir -p /mnt/jfs/$FLOAT_USER/micromamba
