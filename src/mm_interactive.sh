#!/bin/bash

# Default values for other parameters
default_OP_IP="23.22.157.8"
default_s3_path="s3://statfungen/ftp_fgc_xqtl/"
default_VM_path="/data/"
default_image="pixi-ru:latest"
default_core=4
default_mem=16
default_publish="8888:8888"
default_securityGroup="sg-038d1e15159af04a1"
default_include_dataVolume="yes"
default_vm_policy="onDemand"
default_image_vol_size=17
default_interactive_s3_path_base="s3://statfungen/ftp_fgc_xqtl/interactive_sessions/"
default_interactive_VM_path="/home/jovyan/"
default_ide="nvim"

# Initialize variables to empty for user and password
user=""
password=""

# Initialize variables with default values for other parameters
OP_IP="$default_OP_IP"
s3_path="$default_s3_path"
VM_path="$default_VM_path"
image="$default_image"
core="$default_core"
mem="$default_mem"
publish="$default_publish"
securityGroup="$default_securityGroup"
include_dataVolume="$default_include_dataVolume"
vm_policy="$default_vm_policy"
image_vol_size="$default_image_vol_size"
interactive_s3_path=""
interactive_VM_path="$default_interactive_VM_path"
ide="$default_ide"

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
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Prompt for user and password if not provided via command line
if [[ -z "$user" ]]; then
    read -p "Enter user for $OP_IP: " user
fi
if [[ -z "$password" ]]; then
    read -sp "Enter password for $OP_IP: " password
    echo ""
fi

# Set interactive_s3_path based on user
if [[ "$user" == "admin" ]]; then
    interactive_s3_path="${default_interactive_s3_path_base}rf2872/"
else
    interactive_s3_path="${default_interactive_s3_path_base}${user}/"
fi

# Check and create S3 path if it doesn't exist
aws s3api head-object --bucket statfungen --key "ftp_fgc_xqtl/interactive_sessions/${user}/" || aws s3api put-object --bucket statfungen --key "ftp_fgc_xqtl/interactive_sessions/${user}/"

dataVolumeOption=""
if [[ $include_dataVolume == "yes" ]]; then
    # If no s3_path is provided via the command-line, notify the user that the default will be used
    if [[ -z "$s3_path" ]]; then
        echo "s3_path is not provided. The default will be used: $default_s3_path"
        s3_path=$default_s3_path
    fi

    # If no VM_path is provided via the command-line, notify the user that the default will be used
    if [[ -z "$VM_path" ]]; then
        echo "VM_path is not provided. The default will be used: $default_VM_path"
        VM_path=$default_VM_path
    fi

    # Construct the dataVolumeOption with either the specified or default values
    dataVolumeOption="--dataVolume [mode=rw]${s3_path}:${VM_path} --dataVolume [mode=rw]${interactive_s3_path}:${interactive_VM_path}"
fi
if [[ $include_dataVolume == "no" ]]; then
    dataVolumeOption=""
    s3_path=""
    VM_path=""
    interactive_s3_path=""
    interactive_VM_path=""
fi

# Determine VM Policy
lowercase_vm_policy=$(echo "$vm_policy" | tr '[:upper:]' '[:lower:]')
if [ $lowercase_vm_policy == "spotonly" ]; then
    vm_policy_command="[spotOnly=true]"
elif [ $lowercase_vm_policy == "ondemand" ]; then
    vm_policy_command="[onDemand=true]"
elif [ $lowercase_vm_policy == "spotfirst" ]; then
    vm_policy_command="[spotFirst=true]"
else
    echo "Invalid VM Policy setting '$vm_policy'. Please use 'spotOnly', 'onDemand', or 'spotFirst'"
    return 1
fi

# Confirm variables (optional, for debugging or confirmation)
echo "Using the following configurations:"
echo "OP_IP: $OP_IP"
echo "User: $user"
# Echoing password is not recommended for security reasons
echo "S3 Path: $s3_path"
echo "VM Path: $VM_path"
echo "Image: $image"
echo "Core: $core"
echo "Memory: $mem GB"
echo "Publish: $publish"
echo "Security Group: $securityGroup"
echo "Include Data Volume: $include_dataVolume"
echo "VM Policy: $vm_policy"
echo "Interactive S3 Path: $interactive_s3_path"
echo "Interactive VM Path: $interactive_VM_path"
echo "IDE: $ide"
echo

# Log in
echo "Logging in to $OP_IP"
float login -a "$OP_IP" -u "$user" -p "$password"

# Submit job and extract job ID
echo "Submitting job..."
# Will use default gateway g-1xpuesgrea6xclgj46sbf (should be the only gateway)
float_submit="float submit -a $OP_IP -i $image -c $core -m $mem --vmPolicy $vm_policy_command --imageVolSize $image_vol_size --gateway g-1xpuesgrea6xclgj46sbf --migratePolicy [disable=true] --publish $publish --securityGroup $securityGroup $dataVolumeOption --vmPolicy [onDemand=true] --withRoot"
# If user is admin, grant them sudo access
admin_role=$(float login --info | grep "role: admin")
if [ ! -z "$admin_role" ];then
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
        url=$(float log -j "$jobid" cat stderr.autosave | grep token | head -n 1)
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

