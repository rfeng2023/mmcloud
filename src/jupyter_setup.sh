
## submit jupyter notebook automatically 
#!/bin/bash

# Default values
default_OP_IP="54.81.85.209"
#default_user="defaultUser"
#default_password="defaultPassword"
default_s3_path="s3://statfungen/ftp_fgc_xqtl/"
default_VM_path="/data/"

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


# Prompt for user and password
read -p "Enter user: " user
read -sp "Enter password: " password
echo ""

# Other parameters
image="sos2:latest"
core=4
mem=16
publish="8888:8888"

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
jobid=$(echo "yes" | float submit -i "$image" -c "$core" -m "$mem" --publish "$publish" $dataVolumeOption | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}')
echo "Job ID: $jobid"

# Waiting the job initialization and extracting IP
echo "Waiting for the job to initialize and retrieve the public IP..."
while true; do
    IP=$(float show -j "$jobid" | grep public | cut -d ':' -f2 | sed 's/ //g')

    if [[ -n "$IP" ]]; then
        echo "Public IP: $IP"
        break # break the loop when got IP 
    else
        echo "Still waiting for the job to initialize..."
        sleep 60 # check the status every 60s
    fi
done

# Get IP
IP=$(float show -j "$jobid" | grep public | cut -d ':' -f2 | sed 's/ //g')
echo "IP: $IP"

# Get URL
url=$(float log -j "$jobid" cat stderr.autosave | grep token | head -n1)
echo "Original URL: $url"

# Modify and output URL
new_url=$(echo "$url" | sed -E "s/.*http:\/\/[^:]+(:8888\/lab\?token=[a-zA-Z0-9]+)/http:\/\/$IP\1/")
echo "Modified URL: $new_url"

