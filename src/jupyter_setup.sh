#!/bin/bash

# Default values for other parameters
default_OP_IP="23.22.157.8"
default_s3_path="s3://statfungen/ftp_fgc_xqtl/"
default_VM_path="/data/"
default_image="sos2:latest"
default_core=4
default_mem=16
default_publish="8888:8888"
default_securityGroup="sg-038d1e15159af04a1"
default_include_dataVolume="yes"

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
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Prompt for user and password if not provided via command line
if [[ -z "$user" ]]; then
    read -p "Enter user: " user
fi
if [[ -z "$password" ]]; then
    read -sp "Enter password: " password
    echo ""
fi


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
    dataVolumeOption="--dataVolume [mode='rw']${s3_path}:${VM_path}"
fi
if [[ $include_dataVolume == "no" ]]; then
    dataVolumeOption=""
    s3_path=""
    VM_path=""
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
echo

# Log in
echo "Logging in..."
float login -a "$OP_IP" -u "$user" -p "$password"

# Submit job and extract job ID
echo "Submitting job..."
float_submit="float submit -a $OP_IP -i $image -c $core -m $mem --migratePolicy [disable=true] --publish $publish --securityGroup $securityGroup $dataVolumeOption --withRoot"
echo "[Float submit command]: $float_submit"
jobid=$(echo "yes" | $float_submit | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}')
echo "Job ID: $jobid"

# Waiting the job initialization and extracting IP
echo "Waiting for the job to initialize and retrieve the public IP (~3min)..."
while true; do
    IP=$(float show -j "$jobid" | grep public | cut -d ':' -f2 | sed 's/ //g')

    if [[ -n "$IP" ]]; then
        echo "Public IP: $IP"
        break # break it when got IP
    else
        echo "Still waiting for the job to initialize..."
        sleep 60 # check it every 60 secs
    fi
done

# Waiting the executing and get autosave log 
echo "Waiting for the job to execute and retrieve token(~7min)..."
while true; do
    url=$(float log -j "$jobid" cat stderr.autosave | grep token | head -n1)

    if [[ -n "$url" ]]; then
        #echo "Original URL: $url"
        break # break it when got IP
    else
        echo "Still waiting for the job to execute..."
        sleep 60 # check it every 60 secs
    fi
done

# Modify and output URL
new_url=$(echo "$url" | sed -E "s/.*http:\/\/[^:]+(:8888\/lab\?token=[a-zA-Z0-9]+)/http:\/\/$IP\1/")
echo "To access the server, copy this URL in a browser: $new_url"
echo "To access the server, copy this URL in a browser: $new_url" > "${jobid}.log"

suspend_command="float suspend -j $jobid"
echo "Suspend your Jupyter Notebook when you do not need it by running:"
echo "$suspend_command"

