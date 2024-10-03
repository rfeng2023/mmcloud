#!/bin/bash

# Set strict mode
set -euo pipefail

# Default values for parameters
declare -A defaults=(
    [OP_IP]="44.222.241.133"
    [s3_path]="s3://statfungen/ftp_fgc_xqtl"
    [VM_path]="/data/"
    [image]="quay.io/danielnachun/tmate-minimal"
    [core]=4
    [mem]=16
    [publish]="8888:8888"
    [securityGroup]="sg-02867677e76635b25"
    [gateway]="g-9xahbrb5rkbs0ic8yzylk"
    [vm_policy]="onDemand"
    [image_vol_size]=60
    [root_vol_size]=70
    [ide]="tmate"
    [package_installation]="false"
)

# Initialize variables
user=""
password=""
job_name=""
no_mount=false
declare -A params
for key in "${!defaults[@]}"; do
    params[$key]="${defaults[$key]}"
done
additional_mounts=()
publish_set=false

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -o, --OP_IP <ip>                 Set the OP IP address"
    echo "  -u, --user <username>            Set the username"
    echo "  -p, --password <password>        Set the password"
    echo "  -s3, --s3_path <path>            Set the S3 path"
    echo "  --VM_path <path>                 Set the VM path"
    echo "  -i, --image <image>              Set the Docker image"
    echo "  -c, --core <cores>               Set the number of cores"
    echo "  -m, --mem <memory>               Set the memory size"
    echo "  -pub, --publish <ports>          Set the port publishing"
    echo "  -sg, --securityGroup <group>     Set the security group"
    echo "  -vp, --vmPolicy <policy>         Set the VM policy"
    echo "  -ivs, --imageVolSize <size>      Set the image volume size"
    echo "  -rvs, --rootVolSize <size>       Set the root volume size"
    echo "  -ide, --interactive_develop_env <env> Set the IDE"
    echo "  -am, --additional_mounts <mount> Add additional mounts"
    echo "  --no-mount                       Disable all mounting"
    echo "  -jn, --job_name <name>           Set the job name"
    echo "  --package-installation           Set to package installation setup"
    echo "  -h, --help                       Display this help message"
}

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o|--OP_IP) params[OP_IP]="$2"; shift ;;
        -u|--user) user="$2"; shift ;;
        -p|--password) password="$2"; shift ;;
        -s3|--s3_path) params[s3_path]="$2"; shift ;;
        --VM_path) params[VM_path]="$2"; shift ;;
        -i|--image) params[image]="$2"; shift ;;
        -c|--core) params[core]="$2"; shift ;;
        -m|--mem) params[mem]="$2"; shift ;;
        -pub|--publish) params[publish]="$2"; publish_set=true; shift ;;
        -sg|--securityGroup) params[securityGroup]="$2"; shift ;;
        -vp|--vmPolicy) params[vm_policy]="$2"; shift ;;
        -ivs|--imageVolSize) params[image_vol_size]="$2"; shift ;;
        -rvs|--rootVolSize) params[root_vol_size]="$2"; shift ;;
        -ide|--interactive_develop_env) params[ide]="$2"; shift ;;
        -am|--additional_mounts) additional_mounts+=("$2"); shift ;;
        --no-mount) no_mount=true ;;
        -jn|--job_name) job_name="$2"; shift ;;
        --package-installation) params[package_installation]="true"; ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

# Update hard-coded security group and gateway if OpCenter is 3.82.198.55
if [[ "${params[OP_IP]}" == "3.82.198.55" ]]; then
    params[gateway]="g-4nntvdipikat0673xagju"
    params[securityGroup]="sg-00c7a6c97b097ec7b"
fi

# Adjust publish port if not set by user and ide is rstudio
if [[ "$publish_set" == false && "${params[ide]}" == "rstudio" ]]; then
    params[publish]="8787:8787"
fi

# Prompt for user and password if not provided
if [[ -z "$user" ]]; then
    read -p "Enter user for ${params[OP_IP]}: " user
fi
if [[ -z "$password" ]]; then
    read -sp "Enter password for ${params[OP_IP]}: " password
    echo ""
fi

# Data volume handling
if [[ $no_mount == false ]]; then
    dataVolumeOption=("--dataVolume" "[mode=rw,endpoint=s3.us-east-1.amazonaws.com]${params[s3_path]}:${params[VM_path]}")
    if [[ ${#additional_mounts[@]} -gt 0 ]]; then  # Check if additional_mounts has any elements
        for mount in "${additional_mounts[@]}"; do
            dataVolumeOption+=("--dataVolume" "[mode=rw,endpoint=s3.us-east-1.amazonaws.com]${mount}")
        done
    fi
else
    dataVolumeOption=()
fi
# Determine VM Policy
case "$(echo "${params[vm_policy]}" | tr '[:upper:]' '[:lower:]')" in
    spotonly) vm_policy_command="[spotOnly=true]" ;;
    ondemand) vm_policy_command="[onDemand=true]" ;;
    spotfirst) vm_policy_command="[spotFirst=true]" ;;
    *)
        echo "Invalid VM Policy setting '${params[vm_policy]}'. Please use 'spotOnly', 'onDemand', or 'spotFirst'"
        exit 1
        ;;
esac

# Check if specified scripts exist
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
echo "Logging in to ${params[OP_IP]}"
float login -a "${params[OP_IP]}" -u "$user" -p "$password"

# Build the float submit command as an array
float_submit_args=(
    "float" "submit" "-a" "${params[OP_IP]}"
    "-i" "${params[image]}" "-c" "${params[core]}" "-m" "${params[mem]}"
    "--vmPolicy" "$vm_policy_command"
    "--imageVolSize" "${params[image_vol_size]}"
    "--rootVolSize" "${params[root_vol_size]}"
    "--gateway" "${params[gateway]}"
    "--migratePolicy" "[disable=true,evadeOOM=false]"
    "--publish" "${params[publish]}"
    "--securityGroup" "${params[securityGroup]}"
    "--withRoot"
    "--allowList" "[m*]"
    "-e" "GRANT_SUDO=yes"
    "--env" "JUPYTER_RUNTIME_DIR=/tmp/jupyter_runtime"
    "--env" "JUPYTER_ENABLE_LAB=TRUE"
    "--env" "VMUI=${params[ide]}"
    "${dataVolumeOption[@]}"
)

# Add host-init and mount-init if specified
if [[ "${params[package_installation]}" == "true" ]]; then
    float_submit_args+=(
        "-j" "$script_dir/bind_mount.sh"
        "--hostInit" "$script_dir/host_init.sh"
        "--dirMap" "/mnt/jfs:/mnt/jfs"
        "--dataVolume" "[size=100]:/mnt/jfs_cache"
    )
fi

# Include job name if provided
[[ -n "$job_name" ]] && float_submit_args+=("-n" "$job_name")

# Display the float submit command
echo -e "[Float submit command]: ${float_submit_args[*]}"

# Submit the job and retrieve job ID
float_submit_output=$(echo "yes" | "${float_submit_args[@]}")
jobid=$(echo "$float_submit_output" | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}' || true)
if [[ -z "$jobid" ]]; then
    echo "Error returned from float submission command! Exiting..."
    exit 1
fi
echo "JOB ID: $jobid"

# Helper functions
get_public_ip() {
    local jobid="$1"
    echo "[$(date)]: Waiting to retrieve the public IP (~1min)..."
    local IP_ADDRESS=""
    while [[ -z "$IP_ADDRESS" ]]; do
        IP_ADDRESS=$(float show -j "$jobid" | grep -A 1 portMappings | tail -n 1 | awk '{print $4}' || true)
        if [[ -n "$IP_ADDRESS" ]]; then
            echo "PUBLIC IP: $IP_ADDRESS"
        else
            sleep 60
            echo "[$(date)]: Still waiting to retrieve public IP..."
        fi
    done
    echo "$IP_ADDRESS"
}

get_tmate_session() {
    local jobid="$1"
    echo "[$(date)]: Waiting for the job to execute and retrieve tmate web session (~5min)..."
    while true; do
        url=$(float log -j "$jobid" cat stdout.autosave | grep "web session:" | head -n 1 || true)  
        if [[ -n "$url" ]]; then
            local tmate_session=$(echo "$url" | awk '{print $3}')
            echo "To access the server, copy this URL in a browser: $tmate_session"
            echo "To access the server, copy this URL in a browser: $tmate_session" > "${jobid}_tmate_session.log"

            local ssh=$(float log -j "$jobid" cat stdout.autosave | grep "ssh session:" | head -n 1 || true)
            local ssh_tmate=$(echo "$ssh" | awk '{print $3,$4}')
            echo "SSH session: $ssh_tmate"
            echo "SSH session: $ssh_tmate" >> "${jobid}_tmate_session.log"
            break
        else
            sleep 60
            echo "[$(date)]: Still waiting for the job to execute..."
        fi
    done
}

get_jupyter_token() {
    local jobid="$1"
    local ip_address="$2"
    echo "[$(date)]: Waiting for the job to execute and retrieve Jupyter token (~10min)..."
    while true; do
        url=$(float log -j "$jobid" cat stderr.autosave | grep token= | head -n 1 || true)
        no_jupyter=$(float log -j "$jobid" cat stdout.autosave | grep "JupyterLab is not available." | head -n 1 || true)

        if [[ $url == *token=* ]]; then
            local token=$(echo "$url" | sed -E 's|.*http://[^/]+/(lab\?token=[a-zA-Z0-9]+).*|\1|')
            local new_url="http://$ip_address/$token"
            echo "To access the server, copy this URL in a browser: $new_url"
            echo "To access the server, copy this URL in a browser: $new_url" > "${jobid}_jupyter.log"
            break
        elif [[ -n $no_jupyter ]]; then
            echo "[$(date)]: WARNING: No JupyterLab installed. Falling back to tmate session."
            get_tmate_session "$jobid"
            break
        else
            sleep 60
            echo "[$(date)]: Still waiting for the job to generate token..."
        fi
    done
}

# Wait for the job to execute and retrieve connection info
case "${params[ide]}" in
    tmate)
        IP_ADDRESS=$(get_public_ip "$jobid")
        get_tmate_session "$jobid"
        ;;
    jupyter|jupyter-lab)
        IP_ADDRESS=$(get_public_ip "$jobid")
        get_jupyter_token "$jobid" "$IP_ADDRESS"
        ;;
    rstudio)
        IP_ADDRESS=$(get_public_ip "$jobid")
        echo "To access RStudio Server, navigate to http://$IP_ADDRESS:8787 in your web browser."
        echo "RStudio Server URL: http://$IP_ADDRESS:8787" > "${jobid}_rstudio.log"
        ;;
    *)
        echo "Unrecognized IDE specified: ${params[ide]}"
        ;;
esac

# Output suspend command
suspend_command="float suspend -j $jobid"
echo "Suspend your environment when you do not need it by running:"
echo "$suspend_command"
echo "$suspend_command" >> "${jobid}_${params[ide]}.log"
