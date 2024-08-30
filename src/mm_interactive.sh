#!/bin/bash

# Default values for other parameters
default_OP_IP="44.222.241.133"
default_s3_path="s3://statfungen/ftp_fgc_xqtl/"
default_VM_path="/data/"
default_image="docker.io/rfeng2023/pixi-jovyan:latest"
default_core=4
default_mem=16
default_publish="8888:8888"
default_securityGroup="sg-02867677e76635b25"
default_gateway="g-9xahbrb5rkbs0ic8yzylk"
default_include_dataVolume="yes"
default_vm_policy="onDemand"
default_image_vol_size=60
default_root_vol_size=40
default_ide="tmate"

# Initialize variables to empty for user and password
user=""
password=""

# New variables initialization for job_name and no_mount
job_name="" # <- Added
no_mount=false # <- Added

# Initialize variables with default values for other parameters
OP_IP="$default_OP_IP"
s3_path="$default_s3_path"
VM_path="$default_VM_path"
image="$default_image"
core="$default_core"
mem="$default_mem"
publish="$default_publish"
securityGroup="$default_securityGroup"
gateway="$default_gateway"
include_dataVolume="$default_include_dataVolume"
vm_policy="$default_vm_policy"
image_vol_size="$default_image_vol_size"
root_vol_size="$default_root_vol_size"
ide="$default_ide"
additional_mounts=()
no_interactive_mount=false

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o|--OP_IP) OP_IP="$2"; shift ;;
        -u|--user) user="$2"; shift ;;
        -p|--password) password="$2"; shift ;;
        -s3|--s3_path) s3_path="$2"; shift ;;
        -vm|--VM_path) VM_path="$2"; shift ;;
        -i|--image) image="$2"; shift ;;
        -c|--core) core="$2"; shift ;;
        -m|--mem) mem="$2"; shift ;;
        -pub|--publish) publish="$2"; shift ;;
        -sg|--securityGroup) securityGroup="$2"; shift ;;
        -dv|--dataVolume) include_dataVolume="$2"; shift ;;
        -vm|--vmPolicy) vm_policy="$2"; shift ;;
        -ivs|--imageVolSize) image_vol_size="$2"; shift ;;
        -rvs|--rootVolSize) root_vol_size="$2"; shift ;;
        -ide|--interactive_develop_env) ide="$2"; shift ;;
        -am|--additional_mounts) additional_mounts+=("$2"); shift ;;
        --no-interactive-mount) no_interactive_mount=true; ;;
        --no-mount) no_mount=true; ;; # <- Added
        -jn|--job_name) job_name="$2"; shift ;; # <- Added
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Existing prompts for user and password if not provided via command line
if [[ -z "$user" ]]; then
    read -p "Enter user for $OP_IP: " user
fi
if [[ -z "$password" ]]; then
    read -sp "Enter password for $OP_IP: " password
    echo ""
fi

# Data volume handling modified to account for no-mount
dataVolumeOption=""
if [[ $no_mount == false ]]; then
    if [[ $include_dataVolume == "yes" ]]; then
        dataVolumeOption="--dataVolume [mode=rw]${s3_path}:${VM_path}"
        for mount in "${additional_mounts[@]}"; do
            dataVolumeOption+=" --dataVolume [mode=rw]${mount}"
        done
    fi
fi

# Determine VM Policy
lowercase_vm_policy=$(echo "$vm_policy" | tr '[:upper:]' '[:lower:]')
vm_policy_command=""
if [ "$lowercase_vm_policy" == "spotonly" ]; then
    vm_policy_command="[spotOnly=true]"
elif [ "$lowercase_vm_policy" == "ondemand" ]; then
    vm_policy_command="[onDemand=true]"
elif [ "$lowercase_vm_policy" == "spotfirst" ]; then
    vm_policy_command="[spotFirst=true]"
else
    echo "Invalid VM Policy setting '$vm_policy'. Please use 'spotOnly', 'onDemand', or 'spotFirst'"
    exit 1
fi

# Update security group and gateway if IP is 3.82.198.55
if [[ "$OP_IP" = "3.82.198.55" ]]; then
    gateway="g-4nntvdipikat0673xagju"
    securityGroup="sg-00c7a6c97b097ec7b"
fi

# Helper function to find script dir - needed to find location of hostinit and job script
function find_script_dir() {
    SOURCE=${BASH_SOURCE[0]}
    while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
        SOURCE=$(readlink "$SOURCE")
        [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
    echo $DIR
}
script_dir=$(find_script_dir)

# Log in
echo "Logging in to $OP_IP"
float login -a "$OP_IP" -u "$user" -p "$password"

# Adjust float submit command to include job name if provided
float_submit="float submit -a $OP_IP \
-i $image -c $core -m $mem \
--vmPolicy $vm_policy_command \
--imageVolSize $image_vol_size \
--rootVolSize $root_vol_size \
--gateway $gateway \
--migratePolicy [disable=true, evadeOOM=true] \
--publish $publish \
--securityGroup $securityGroup \
$dataVolumeOption \
--withRoot \
--allowList [m*] \
-a $OP_IP -u $user -p $password \
-e GRANT_SUDO=yes \
--env JUPYTER_RUNTIME_DIR=/tmp/jupyter_runtime \
--env VMUI=$ide \
--env JUPYTER_ENABLE_LAB=TRUE \
"
# for package installation setup
if [[ $image == "docker.io/rfeng2023/pixi-jovyan:latest" ]]; then
    float_submit+=" --dirMap /mnt/jfs:/mnt/jfs --hostInit $script_dir/host_init.sh -j $script_dir/bind_mount.sh --dataVolume [size=100]:/mnt/jfs_cache"
fi

if [[ -n "$job_name" ]]; then 
    float_submit+=" -n $job_name"
fi

echo -e "[Float submit command]: $float_submit"
jobid=$(echo "yes" | $float_submit | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}')
if [ ! -n "$jobid" ]; then
    echo "Error returned from float submission command! Exiting..."
    exit
fi
echo "JOB ID: $jobid"

# Grab session information based on ide
if [ "$ide" == "tmate" ]; then
    # Waiting for the job initialization and extracting IP
    echo "[$(date)]: Waiting to retrieve the public IP (~1min)..."
    while true; do
        IP_ADDRESS=$(float show -j "$jobid" | grep -A 1 portMappings | tail -n 1 | awk '{print $4}')
        if [[ -n "IP_ADDRESS" ]]; then
            echo "PUBLIC IP: $IP_ADDRESS"
            break # break it when got IP
        else
            sleep 60 # check it every 60 secs
            echo "[$(date)]: Still waiting to retrieve public ip..."
        fi
    done

    # Waiting for the job to execute and get autosave log 
    echo "[$(date)]: Waiting for the job to execute and retrieve tmate web session (~5min)..."
    while true; do
        url=$(float log -j "$jobid" cat stdout.autosave | grep "web session:" | head -n 1)
        if [[ -n "$url" ]]; then
            # Modify and output URL
            tmate_session=$(echo "$url" | awk '{print $3}')
            echo "To access the server, copy this URL in a browser: $tmate_session"
            echo "To access the server, copy this URL in a browser: $tmate_session" > "${jobid}_tmate_session.log"

            # tmate session line will always come with ssh session line
            ssh=$(float log -j "$jobid" cat stdout.autosave | grep "ssh session:" | head -n 1)
            ssh_tmate=$(echo "$ssh" | awk '{print $3,$4}')
            echo "SSH session: $ssh_tmate"
            echo "SSH session: $ssh_tmate" > "${jobid}_${ide}.log"
            break
        else
            sleep 60 # check it every 60 secs
            echo "[$(date)]: Still waiting for the job to execute..."
        fi
    done
fi

if [ "$ide" == "jupyter" ] || [ "$ide" == "jupyter-lab" ]; then
    # Waiting for the job to execute and get autosave log 
    echo "[$(date)]: Waiting for the job to execute and retrieve jupyter token (~10min)..."
    while true; do
        url=$(float log -j "$jobid" cat stderr.autosave | grep token= | head -n 1)
        no_jupyter=$(float log -j "$jobid" cat stdout.autosave | grep "JupyterLab is not available." | head -n 1)

        # If jupyter token and URL found
        if [[ $url == *token* ]]; then
            # Modify and output URL
            IP_ADDRESS=$(float show -j "$jobid" | grep -A 1 portMappings | tail -n 1 | awk '{print $4}')
            token=$(echo "$url" | sed -E 's|.*http://[^/]+/(lab\?token=[a-zA-Z0-9]+).*|\1|')
            new_url="http://$IP_ADDRESS/$token"
            echo "To access the server, copy this URL in a browser: $new_url"
            echo "To access the server, copy this URL in a browser: $new_url" > "${jobid}_jupyter.log"
            break # break it when got token
        # If jupyter lab is not installed, do tmate section
        elif [[ -n $no_jupyter ]]; then
            echo "[$(date)]: WARNING: No JupyterLab installed under this user. Sharing tmate information:"
            url=$(float log -j "$jobid" cat stdout.autosave | grep "web session:" | head -n 1)
            tmate_session=$(echo "$url" | awk '{print $3}')
            echo "To access the server, copy this URL in a browser: $tmate_session"
            echo "To access the server, copy this URL in a browser: $tmate_session" > "${jobid}_tmate_session.log"

            # tmate session line will always come with ssh session line
            ssh=$(float log -j "$jobid" cat stdout.autosave | grep "ssh session:" | head -n 1)
            ssh_tmate=$(echo "$ssh" | awk '{print $3,$4}')
            echo "SSH session: $ssh_tmate"
            echo "SSH session: $ssh_tmate" > "${jobid}_${ide}.log"
            break
        else
            sleep 60 # check it every 60 secs
            echo "[$(date)]: Still waiting for the job to generate token..."
        fi
    done
fi

# Output suspend command for all IDEs
suspend_command="float suspend -j $jobid"
echo "Suspend your environment when you do not need it by running:"
echo "$suspend_command"
echo "$suspend_command" >> "${jobid}_${ide}.log"

