#!/bin/bash

# Default values
default_OP_IP="54.81.85.209"
#default_user="defaultUser"
#default_password="defaultPassword"
default_s3_path="s3://statfungen/ftp_fgc_xqtl/"
default_VM_path="/data/"

# Prompt for user and password
read -p "Enter user: " user
read -sp "Enter password: " password
echo ""


# Prompt for OP_IP, allowing default
read -p "Enter OP_IP [$default_OP_IP]: " OP_IP
OP_IP=${OP_IP:-$default_OP_IP}

# # Prompt for user, allowing default
# read -p "Enter user [$default_user]: " user
# user=${user:-$default_user}
# # Prompt for password, allowing default. Use -s to hide input.
# echo -n "Enter password [default hidden]: "
# read -s password
# echo ""
# password=${password:-$default_password}


# Other parameters
image="sos2:latest"
core=4
mem=16
publish="8888:8888"
securityGroup="sg-038d1e15159af04a1"

# Ask if the user wants to include dataVolume
echo "Include dataVolume? (yes/no) [default: yes]:"
read include_dataVolume
include_dataVolume=${include_dataVolume:-yes}

dataVolumeOption=""
if [[ $include_dataVolume == "yes" ]]; then
    # Use defaults or prompt for new s3_path and VM_path
    read -p "Enter s3_path [$default_s3_path]: " s3_path
    s3_path=${s3_path:-$default_s3_path}

    read -p "Enter VM_path [$default_VM_path]: " VM_path
    VM_path=${VM_path:-$default_VM_path}

    dataVolumeOption="--dataVolume ${s3_path}:${VM_path}"
fi

# Log in
echo "Logging in..."
float login -a "$OP_IP" -u "$user" -p "$password"

# Submit job and extract job ID
echo "Submitting job..."
jobid=$(echo "yes" | float submit -i "$image" -c "$core" -m "$mem" --publish "$publish" --securityGroup "$securityGroup" $dataVolumeOption | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}')
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
        echo "Original URL: $url"
        break # break it when got IP
    else
        echo "Still waiting for the job to execute..."
        sleep 60 # check it every 60 secs
    fi
done

# Modify and output URL
new_url=$(echo "$url" | sed -E "s/.*http:\/\/[^:]+(:8888\/lab\?token=[a-zA-Z0-9]+)/http:\/\/$IP\1/")
echo "To access the server, copy this URL in a browser: $new_url"

suspend_command="float suspend -j $jobid"
echo "Suspend your Jupyter Notebook when you do not need it by running:"
echo "$suspend_command"

