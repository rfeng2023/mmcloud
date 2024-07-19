#!/bin/bash

# Default values for other parameters
default_OP_IP="44.222.241.133"
default_s3_path="s3://statfungen/ftp_fgc_xqtl/"
default_VM_path="/data/"
default_image="pixi-ru:latest"
default_core=4
default_mem=16
default_publish="8888:8888"
default_securityGroup="sg-02867677e76635b25"
default_gateway="g-9xahbrb5rkbs0ic8yzylk"
default_include_dataVolume="yes"
default_vm_policy="onDemand"
default_image_vol_size=60
default_interactive_s3_path_base="s3://statfungen/ftp_fgc_xqtl/interactive_sessions/"
default_interactive_VM_path="/home/jovyan/"
default_ide="nvim"

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
interactive_s3_path=""
interactive_VM_path="$default_interactive_VM_path"
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
        -ide|--interactive_develop_env) ide="$2"; shift ;;
        -is3|--interactive_s3_path) interactive_s3_path="$2"; shift ;;
        -ivm|--interactive_VM_path) interactive_VM_path="$2"; shift ;;
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

# Set interactive_s3_path based on user if not provided and if interactive mount is enabled
if [[ "$no_interactive_mount" = false ]]; then
    if [[ -z "$interactive_s3_path" ]]; then
        if [[ "$user" == "admin" ]]; then
            interactive_s3_path="${default_interactive_s3_path_base}rf2872/"
        else
            interactive_s3_path="${default_interactive_s3_path_base}${user}/"
        fi
    fi

    # Check and create S3 path if it doesn't exist
    aws s3api head-object --bucket statfungen --key "${interactive_s3_path#s3://statfungen/}" || aws s3api put-object --bucket statfungen --key "${interactive_s3_path#s3://statfungen/}"
fi

# Data volume handling modified to account for no-mount
dataVolumeOption=""
if [[ $no_mount == false ]]; then
    if [[ $include_dataVolume == "yes" ]]; then
        dataVolumeOption="--dataVolume [mode=rw]${s3_path}:${VM_path}"
        if [[ "$no_interactive_mount" = false ]]; then
            dataVolumeOption+=" --dataVolume [mode=rw]${interactive_s3_path}:${interactive_VM_path}"
        fi
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

# Log in
echo "Logging in to $OP_IP"
float login -a "$OP_IP" -u "$user" -p "$password"

# Adjust float submit command to include job name if provided
float_submit="float submit -a $OP_IP \
-i $image -c $core -m $mem \
--vmPolicy $vm_policy_command \
--imageVolSize $image_vol_size \
--gateway $gateway \
--migratePolicy [cpu.disable=true,mem.disable=true,stepAuto=true,evadeOOM=true] \
--publish $publish \
--securityGroup $securityGroup \
$dataVolumeOption \
--vmPolicy [onDemand=true] \
--withRoot \
--allowList [m*] \
--env JUPYTER_RUNTIME_DIR=/tmp/jupyter_runtime"

if [[ -n "$job_name" ]]; then 
    float_submit+=" -n $job_name"
fi

# If user is admin, grant them sudo access
admin_role=$(float login --info | grep "role: admin")
if [ ! -z "$admin_role" ]; then
    float_submit+=" -e GRANT_SUDO=yes"
fi

echo "[Float submit command]: $float_submit"
jobid=$(echo "yes" | $float_submit | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}')
echo "Job ID: $jobid"

if [[ "$ide" == "jupyter" ]]; then
    # Waiting for the job initialization and extracting IP
    echo "Waiting for the job to initialize and retrieve the public IP (~3min)..."
    while true; do
        IP_ADDRESS=$(float show -j "$jobid" | grep -A 1 portMappings | tail -n 1 | awk '{print $4}')
        if [[ $IP_ADDRESS == *.* ]]; then
            echo "Public IP: $IP_ADDRESS"
            break # break it when got IP
        else
            echo "Still waiting for the job to initialize..."
            sleep 60 # check it every 60 secs
        fi
    done

    # Waiting for the job to execute and get autosave log 
    echo "Waiting for the job to execute and retrieve token (~7min)..."
    while true; do
        url=$(float log -j "$jobid" cat stderr.autosave | grep token= | head -n 1)
        if [[ $url == *token* ]]; then
            break # break it when got token
        else
            echo "Still waiting for the job to execute..."
            sleep 60 # check it every 60 secs
        fi
    done

    # Modify and output URL
    token=$(echo "$url" | sed -E 's|.*http://[^/]+/(lab\?token=[a-zA-Z0-9]+).*|\1|')
    new_url="http://$IP_ADDRESS/$token"
    echo "To access the server, copy this URL in a browser: $new_url"
    echo "To access the server, copy this URL in a browser: $new_url" > "${jobid}_jupyter.log"
else
    # Waiting for the job initialization and extracting SSH session
    echo "Waiting for the job to initialize and retrieve SSH session (~3min)..."
    while true; do
        ssh_session=$(float show -j "$jobid" | grep 'ssh session' | awk -F'ssh session: ' '{print $2}')
        if [[ -n "$ssh_session" ]]; then
            echo "SSH session: $ssh_session"
            break # break it when got SSH session
        else
            echo "Still waiting for the job to initialize..."
            sleep 60 # check it every 60 secs
        fi
    done

    echo "SSH session: $ssh_session" > "${jobid}_${ide}.log"
fi

# Output suspend command for all IDEs
suspend_command="float suspend -j $jobid"
echo "Suspend your environment when you do not need it by running:"
echo "$suspend_command"
echo "$suspend_command" >> "${jobid}_${ide}.log"

