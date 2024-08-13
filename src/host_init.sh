#!/bin/bash

cd /root

# Install aws
alias aws="/usr/local/aws-cli/v2/current/bin/aws"
export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:${PATH}"

# Install Juicefs, redis, and fuse
yum install fuse gcc python3 bash --quiet -y
wget -q http://download.redis.io/redis-stable.tar.gz
tar xzf redis-stable.tar.gz
cd redis-stable && make 1> /dev/null 2>&1
cd ..

echo -n "bind 0.0.0.0 -::1
port 6868
daemonize yes
#requirepass mmcloud
maxmemory-policy noeviction
save ""
appendonly no
protected-mode no
" > /etc/redis.conf
/root/redis-stable/src/redis-server /etc/redis.conf

JFS_LATEST_TAG=$(curl -s https://api.github.com/repos/juicedata/juicefs/releases/latest | grep 'tag_name' | cut -d '"' -f 4 | tr -d 'v')
wget -q "https://github.com/juicedata/juicefs/releases/download/v${JFS_LATEST_TAG}/juicefs-${JFS_LATEST_TAG}-linux-amd64.tar.gz"
tar zxf "juicefs-${JFS_LATEST_TAG}-linux-amd64.tar.gz"
sudo install juicefs /usr/local/bin

# Set variables
# Juicefs will not take "_" in the name, so any usernames with "_" will have it removed
JFS_NAME="${FLOAT_USER//_/}"
METADATA_ID="${FLOAT_USER//_/}_JFS"
FOUND_METADATA=$(aws s3 ls s3://wanggroup | grep "$METADATA_ID.meta.json.gz" | awk '{print $4}')

# Format Juicefs
if [[ ! -z $FOUND_METADATA ]]; then
    # If metadata is found, copy it over and load
    echo "Metadata id $METADATA_ID found in bucket"
    aws s3 cp s3://wanggroup/$METADATA_ID.meta.json.gz .
    /usr/local/bin/juicefs load redis://127.0.0.1:6868/1 $METADATA_ID.meta.json.gz

    echo "Formatting Juicefs"
    /usr/local/bin/juicefs config --yes --storage s3 \
    --bucket https://wanggroup.s3.us-east-1.amazonaws.com \
    --trash-days=0 \
    redis://127.0.0.1:6868/1 \
    $JFS_NAME 2>&1 >/dev/null
else
    # No previous metadata found, new mount expected
    echo "Formatting Juicefs - no previous metadata $METADATA_ID found"
    /usr/local/bin/juicefs format --storage s3 \
    --bucket https://wanggroup.s3.us-east-1.amazonaws.com \
    --trash-days=0 \
    redis://127.0.0.1:6868/1 \
    $JFS_NAME 2>&1 >/dev/null
fi

# Mount Juicefs
echo "Mounting juicefs"
sudo mkdir -p /home/jovyan
sudo chmod 777 /home/jovyan
nohup /usr/local/bin/juicefs mount \
redis://127.0.0.1:6868/1 \
--buffer-size 600 \
--writeback \
--cache-dir /mnt/jfs_cache \
--root-squash $FLOAT_USER_ID \
/home/jovyan 1> /dev/null  2>&1 &

# Make sure it is mounted before end script
sleep 10s

# vvv For files to be run in the container vvv
# Create the entrypoint file that was overwritten
echo -n "#!/bin/bash
set -e
cd /home/jovyan/

### From Docker file
apt-get update && apt-get -y install ca-certificates tzdata libgl1 libgomp1 less curl tmate jupyter-lab rstudio nvim micromamba

### From Entrypoint file
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
" > /home/jovyan/entrypoint.sh
chmod 755 /home/jovyan/entrypoint.sh