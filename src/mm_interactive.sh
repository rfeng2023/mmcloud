#!/bin/bash

# Set strict mode
set -euo pipefail

# Default values for parameters
OP_IP="44.222.241.133"
s3_path="s3://statfungen/ftp_fgc_xqtl"
vm_path="/data/"
image="quay.io/danielnachun/tmate-minimal"
core=4
mem=16
publish="8888:8888"
vm_policy="onDemand"
ide="tmate"
mount_packages="false"
float_executable="float"

# Initialize other variables
user=""
password=""
job_name=""
no_mount=false
additional_mounts=()
publish_set=false
gateway="" # Default will be set later, as it depends on OP_IP
image_vol_size=""
root_vol_size=""

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -o, --OP_IP <ip>                 Set the OP IP address"
    echo "  -u, --user <username>            Set the username"
    echo "  -p, --password <password>        Set the password"
    echo "  -s3, --s3_path <path>            Set the S3 path"
    echo "  --vm_path <path>                 Set the VM path"
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
    echo "  --mount-packages                 Mount dedicated volumes on AWS to accommodate conda package installation and usage"
    echo "  --float-executable <path>        Set the path to the float executable (default: float)"
    echo "  -g, --gateway <id>               Set gatewayID (default: default gateway on corresponding OpCenter)"
    echo "  --oem-admin                      Run in admin mode to make changes to OEM packages"
    echo "  --shared-admin                   Run in admin mode to make changes to shared packages"
    echo "  -h, --help                       Display this help message"
}

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o|--OP_IP) OP_IP="$2"; shift ;;
        -u|--user) user="$2"; shift ;;
        -p|--password) password="$2"; shift ;;
        -s3|--s3_path) s3_path="$2"; shift ;;
        -vm|--vm_path) vm_path="$2"; shift ;;
        -i|--image) image="$2"; shift ;;
        -c|--core) core="$2"; shift ;;
        -m|--mem) mem="$2"; shift ;;
        -pub|--publish) publish="$2"; publish_set=true; shift ;;
        -sg|--securityGroup) securityGroup="$2"; shift ;;
        -vp|--vmPolicy) vm_policy="$2"; shift ;;
        -ivs|--imageVolSize) image_vol_size="$2"; shift ;;
        -rvs|--rootVolSize) root_vol_size="$2"; shift ;;
        -ide|--interactive_develop_env) ide="$2"; shift ;;
        -am|--additional_mounts) additional_mounts+=("$2"); shift ;;
        --no-mount) no_mount=true ;;
        -jn|--job_name) job_name="$2"; shift ;;
        --mount-packages) mount_packages="true" ;;
        --float-executable) float_executable="$2"; shift ;;
        -g|--gateway) gateway="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        --oem-admin) oem_admin=true ;;
        --shared-admin) shared_admin=true ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

# Now that all variables are initialized, we can set -u
set -u

RED='\033[0;31m'
NC='\033[0m' # No Color

valid_ides=("tmate" "jupyter" "jupyter-lab" "rstudio" "vscode")
if [[ ! " ${valid_ides[*]} " =~ " ${ide} " ]]; then
    echo "Error: Invalid IDE specified. Please choose one of: ${valid_ides[*]}"
    exit 1
fi

# If ide is tmate, warn user about initial package setup
if [ $ide == "tmate" ]; then
    while true; do
    echo -e "${RED}NOTICE:${NC} tmate sessions are primarily designed for initial package configuration.\nFor regular development work, we recommend utilizing a more advanced Integrated Development Environment (IDE)\nvia the -ide option, if you have previously set up an alternative IDE.\n\nDo you wish to proceed with the tmate session? (y/N): \c"
    read input
    input=${input:-n}  # Default to "n" if no input is given
    case $input in
        [yY]) 
            break
            ;;
        [nN]) 
            echo "Exiting the script."
            exit 0
            ;;
        *) 
            echo "Invalid input. Please enter 'y' or 'n'."
            ;;
    esac
done
fi

# Update hard-coded security group and gateway if no specific gateway given
if [[ "$OP_IP" == "3.82.198.55" ]]; then
    securityGroup="sg-00c7a6c97b097ec7b"
    if [[ -z "$gateway" ]]; then
        gateway="g-4nntvdipikat0673xagju"
    fi
elif [[ "$OP_IP" == "44.222.241.133" ]]; then
    securityGroup="sg-02867677e76635b25"
    if [[ -z "$gateway" ]]; then
        gateway="g-9xahbrb5rkbs0ic8yzylk"
    fi
fi

# Adjust publish port if not set by user and ide is rstudio
if [[ "$publish_set" == false && "$ide" == "rstudio" ]]; then
    publish="8787:8787"
fi
if [[ "$publish_set" == false && "$ide" == "vscode" ]]; then
    publish="8989:8989"
fi

# Prompt for user and password if not provided
if [[ -z "$user" ]]; then
    read -p "Enter user for $OP_IP: " user
fi
if [[ -z "$password" ]]; then
    read -sp "Enter password for $OP_IP: " password
    echo ""
fi

# Set default job_name if not provided by user
published_port=$(echo "$publish" | cut -d':' -f1)
if [[ -z "$job_name" ]]; then
    # Extract the published port from the publish variable
    job_name="${user}_${ide}_${published_port}"
# If there is a custom job name, we add identifiers to the end
else
    job_name+=".${user}_${ide}_${published_port}"
fi

# Data volume handling
if [[ $no_mount == false ]]; then
    dataVolumeOption=("--dataVolume" "[mode=rw,endpoint=s3.us-east-1.amazonaws.com]$s3_path:$vm_path")
    if [[ ${#additional_mounts[@]} -gt 0 ]]; then  # Check if additional_mounts has any elements
        for mount in "${additional_mounts[@]}"; do
            dataVolumeOption+=("--dataVolume" "[mode=rw,endpoint=s3.us-east-1.amazonaws.com]${mount}")
        done
    fi
else
    dataVolumeOption=()
fi

# Determine VM Policy
case "$(echo "$vm_policy" | tr '[:upper:]' '[:lower:]')" in
    spotonly) vm_policy_command="[spotOnly=true]" ;;
    ondemand) vm_policy_command="[onDemand=true]" ;;
    spotfirst) vm_policy_command="[spotFirst=true]" ;;
    *)
        echo "Invalid VM Policy setting '$vm_policy'. Please use 'spotOnly', 'onDemand', or 'spotFirst'"
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
echo "Logging in to $OP_IP"
"$float_executable" login -a "$OP_IP" -u "$user" -p "$password"

# Build the float submit command as an array
float_submit_args=(
    "$float_executable" "submit" "-a" "$OP_IP"
    "-i" "$image" "-c" "$core" "-m" "$mem"
    "--vmPolicy" "$vm_policy_command"
    "--gateway" "$gateway"
    "--migratePolicy" "[disable=true,evadeOOM=false]"
    "--publish" "$publish"
    "--securityGroup" "$securityGroup"
    "--withRoot"
    "--allowList" "[r5*,r6*,r7*,m*]"
    "-e" "GRANT_SUDO=yes"
    "--env" "JUPYTER_RUNTIME_DIR=/tmp/jupyter_runtime"
    "--env" "JUPYTER_ENABLE_LAB=TRUE"
    "--env" "VMUI=$ide"
    "${dataVolumeOption[@]}"
)

# If image vol size and root vol size not empty, populate float args
if [[ ! -z "$image_vol_size" ]]; then
    float_submit_args+=(
        "--imageVolSize" "$image_vol_size"
    )
fi
if [[ ! -z "$root_vol_size" ]]; then
    float_submit_args+=(
        "--rootVolSize" "$root_vol_size"
    )
fi

# Add host-init and mount-init if specified
if [[ "$mount_packages" == "true" ]]; then
    float_submit_args+=(
        "-j" "$script_dir/bind_mount.sh"
        "--hostInit" "$script_dir/host_init_interactive.sh"
        "--dirMap" "/mnt/efs:/mnt/efs"
        "-n" "$job_name"
    )
fi

if [[ "${oem_admin}" == "true" && ${shared_admin} == "true" ]]; then
    echo -e "${RED}ERROR: only one of --oem-admin and --shared-admin can be specificied"; exit 1
fi

if [[ "${oem_admin}" == "true" || ${shared_admin} == "true" ]] && [[ ${mount_packages} == "false" ]]; then
    echo -e "${RED}ERROR: --mount-packages must be specified when --oem-admin or --shared-admin are specified"; exit 1
fi

if [[ "${oem_admin}" == "true" ]]; then
    float_submit_args+=(
        "--env" "MODE=oem_admin"
    )
elif [[ "${shared_admin}" == "true" ]]; then
    float_submit_args+=(
        "--env" "MODE=shared_admin"
    )
else 
    float_submit_args+=(
        "--env" "MODE=user"
    )
fi

# Determine if there are exisitng interactive jobs for this user
running_jobs=$($float_executable list -f user=${user} -f "status=Executing or status=Suspended or status=Suspending or status=Starting or status=Initializing"| awk '{print $4}' | grep -v -e '^$' -e 'NAME' | grep "${user}_${ide}_${published_port}" || true)

# If there exists executing or suspended jobs that match the ID, warn user
if [[ -n "$running_jobs" ]]; then
    job_count=$(echo "$running_jobs" | wc -l)    	
    echo -e "${RED}WARNING: ${NC}User ${RED}$user${NC} already has ${job_count} existing interactive jobs under the same ide ${RED}$ide${NC} and port ${RED}$published_port${NC}."
    while true; do
        echo -e "Do you wish to proceed (y/N)? \c"
        read input
        input=${input:-n}  # Default to "n" if no input is given
        case $input in
            [yY]) 
                break
                ;;
            [nN]) 
                echo "Exiting the script."
                exit 0
                ;;
            *) 
                echo "Invalid input. Please enter 'y' or 'n'."
                ;;
        esac
    done
fi

# Display the float submit command
echo -e "[Float submit command]: ${float_submit_args[*]}"

# Submit the job and retrieve job ID
float_submit_output=$(echo "yes" | "${float_submit_args[@]}")
jobid=$(echo "$float_submit_output" | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}' || true)
if [[ -z "$jobid" ]]; then
    echo "Error returned from float submission command! Exiting..."
    exit 1
fi
echo ""
echo "JOB ID: $jobid"

# Helper functions
# No other echo needed as just getting IP_ADDRESS
get_public_ip() {
    local jobid="$1"
    local IP_ADDRESS=""
    while [[ -z "$IP_ADDRESS" ]]; do
        IP_ADDRESS=$("$float_executable" show -j "$jobid" | grep -A 1 portMappings | tail -n 1 | awk '{print $4}' || true)
        if [[ -n "$IP_ADDRESS" ]]; then
            echo "$IP_ADDRESS"
        else
            sleep 1s
        fi
    done
}

get_tmate_session() {
    local jobid="$1"
    echo "[$(date)]: Waiting for the job to execute and retrieve tmate web session (~5min)..."
    while true; do
        url=$("$float_executable" log -j "$jobid" cat stdout.autosave | grep "web session:" | head -n 1 || true)  
        if [[ -n "$url" ]]; then
            local tmate_session=$(echo "$url" | awk '{print $3}')
            echo "To access the server, copy this URL in a browser: $tmate_session"
            echo "To access the server, copy this URL in a browser: $tmate_session" > "${jobid}_tmate_session.log"

            local ssh=$("$float_executable" log -j "$jobid" cat stdout.autosave | grep "ssh session:" | head -n 1 || true)
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
        url=$("$float_executable" log -j "$jobid" cat stderr.autosave | grep token= | head -n 1 || true)
        no_jupyter=$("$float_executable" log -j "$jobid" cat stdout.autosave | grep "JupyterLab is not available." | head -n 1 || true)

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
case "$ide" in
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
        echo "To access RStudio Server, navigate to http://$IP_ADDRESS in your web browser."
        echo "Please give the instance about 10 minutes to start RStudio"
        echo "RStudio Server URL: http://$IP_ADDRESS" > "${jobid}_rstudio.log"
        ;;
    vscode)
        IP_ADDRESS=$(get_public_ip "$jobid")
        echo "To access code-server, navigate to http://$IP_ADDRESS in your web browser."
        echo "Please give the instance about 10 minutes to start code-server"
        echo "code-server URL: http://$IP_ADDRESS" > "${jobid}_code-server.log"
        ;;
    *)
        echo "Unrecognized IDE specified: $ide"
        ;;
esac

# Output suspend command
suspend_command="$float_executable suspend -j $jobid"
echo "Suspend your environment when you do not need it by running:"
echo "$suspend_command"
echo "$suspend_command" >> "${jobid}_${ide}.log"
