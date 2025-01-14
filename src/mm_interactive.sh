#!/bin/bash
# Gao Wang and MemVerge Inc.

# Set strict mode
set -euo pipefail
RED='\033[0;31m'
NC='\033[0m' # No Color

# Required values (given by CLI)
opcenter=""
gateway=""
securityGroup=""
efs_ip=""

# Modes
oem_admin="" # For batch jobs only
shared_admin="" # For updating shared packages in interactive jobs
mount_packages="" # For accessing one's own packages in interactive jobs
oem_packages="" # For accessing shared packages in interactive jobs

# Optional values (given by CLI) - some default values given
declare -a mounts=()
declare -a dataVolumeOption=()
core=4
mem=16
dryrun=false
entrypoint=""
float_executable="float"
ide="tmate"
idle_time=7200
image="quay.io/danielnachun/tmate-minimal"
image_vol_size=""
root_vol_size=""
job_name=""
no_mount=false
publish="8888:8888"
publish_set=false
suspend_off=""
user=""
password=""
vm_policy="onDemand"

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Required Options:"
    echo "  -o, --opcenter <ip>                   Set the OP IP address"
    echo "  -sg, --securityGroup <group>          Set the security group"
    echo "  -g, --gateway <id>                    Set gateway"
    echo "  -c, --core <cores>                    Set the number of cores for initial instance"
    echo "  -m, --mem <memory>                    Set the memory size for initial instance"

    echo "Required Batch Options:"
    # TODO BATCH MODE PARAMETER
    echo "  --job-size <value>                    Set the number of commands per job for creating virtual machines." # TODO

    echo "Batch-specific Options:"
    echo "  --cwd <value>                         Define the working directory for the job (default: ~)." # TODO
    echo "  --download <remote>:<local>           Download files/folders from S3. Format: <S3 path>:<local path>." # TODO
    echo "  --upload <local>:<remote>             Upload folders to S3. Format: <local path>:<S3 path>." # TODO
    echo "  --download-include '<value>'          Use the include flag to include certain files for download (space-separated)." # TODO
    echo "  --no-fail-fast                        Continue executing subsequent commands even if one fails." #TODO
    echo "  --parallel-commands <value>           Set the number of commands to run in parallel (default: CPU value)." # TODO
    echo "  --min-cores-per-command <value>       Specify the minimum number of CPU cores required per command." # TODO
    echo "  --min-mem-per-command <value>         Specify the minimum amount of memory in GB required per command." # TODO

    echo "Required Interactive Options:"
    # TODO INTERACTIVE MODE PARAMETER
    echo "  -efs <ip>                             Set EFS IP"

    echo "Interactive-specific Options:"
    echo "  --idle                                Amount of idle time before suspension. Only works for jupyter instances (default: 7200 seconds)"
    echo "  --suspend-off                         For Jupyter jobs, turn off the auto-suspension feature"
    echo "  -ide, --interactive_develop_env <env> Set the IDE"
    echo "  -pub, --publish <ports>               Set the port publishing in the form of port:port"
    echo "  --shared-admin                        Run in admin mode to make changes to shared packages"
    echo "  --mount-packages                      Grant the ability to use user packages"
    echo "  --oem-packages                        Grant the ability to use shared packages"


    echo "Global Options:"
    echo "  -u, --user <username>                 Set the username" # Login once so do not have to login before every job submission
    echo "  -p, --password <password>             Set the password"
    echo "  -i, --image <image>                   Set the Docker image"
    echo "  -vp, --vmPolicy <policy>              Set the VM policy"
    echo "  -ivs, --imageVolSize <size>           Set the image volume size"
    echo "  -rvs, --rootVolSize <size>            Set the root volume size"
    echo "  --ebs-mount <folder>=<size>           Mount an EBS volume to a local directory. Format: <local path>=<size>. Size in GB." #TODO
    echo "  --mount <s3_path:vm_path>             Add S3:VM mounts separated by commas"
    echo "  --mountOpt <value>                    Specify mount options for the bucket (required if --mount is used)." #TODO
    echo "  --no-mount                            Disable all mounting"
    echo "  -jn, --job_name <name>                Set the job name"
    echo "  --float-executable <path>             Set the path to the float executable (default: float)"
    echo "  --entrypoint <dir>                    Set entrypoint of interactive job - please give Github link"
    #echo "  --oem-admin                           Run in admin mode to make changes to batch packages (for batch job updates only)"
    echo "  --dryrun                              Execute a dry run, printing commands without running them."
    echo "  -h, --help                            Display this help message"
}

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -o|--opcenter) opcenter="$2"; shift ;;
        -u|--user) user="$2"; shift ;;
        -p|--password) password="$2"; shift ;;
        -i|--image) image="$2"; shift ;;
        -c|--core) core="$2"; shift ;;
        -m|--mem) mem="$2"; shift ;;
        -pub|--publish) publish="$2"; publish="$2"; publish_set=true; shift ;;
        -sg|--securityGroup) securityGroup="$2"; shift ;;
        -g|--gateway) gateway="$2"; shift ;;
        -efs) efs_ip="$2"; shift ;;
        -vp|--vmPolicy) vm_policy="$2"; shift ;;
        -ivs|--imageVolSize) image_vol_size="$2"; shift ;;
        -rvs|--rootVolSize) root_vol_size="$2"; shift ;;
        -ide|--interactive_develop_env) ide="$2"; shift ;;
        --no-mount) no_mount=true ;;
        -jn|--job_name) job_name="$2"; shift ;;
        --float-executable) float_executable="$2"; shift ;;
        --entrypoint) entrypoint="$2"; shift ;;
        --idle) idle_time="$2"; shift ;;
        --suspend-off) suspend_off=true ;;
        --oem-admin) oem_admin=true ;;
        --shared-admin) shared_admin=true ;;
        --mount-packages) mount_packages=true ;;
        --oem-packages) oem_packages=true ;;
        --dryrun) dryrun=true ;;
        --mount)
            IFS=',' read -r -a mounts <<< "$2";
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

# Now that all variables are initialized, we can set -u
set -u

# Check required parameters are given
check_required_params() {
    missing_params=""
    is_missing=false
    if [ -z "$opcenter" ]; then
        missing_params+="-o, "
        is_missing=true
    fi
    if [ -z "$gateway" ]; then
        missing_params+="-g, "
        is_missing=true
    fi
    if [ -z "$securityGroup" ]; then
        missing_params+="-sg, "
        is_missing=true
    fi
    if [ -z "$efs_ip" ]; then
        missing_params+="-efs, "
        is_missing=true
    fi
    missing_params=${missing_params%, }
    if [ "$is_missing" = true ]; then
        echo "Error: Missing required parameters: $missing_params" >&2
        usage
        exit 1
    fi
}

# Set tmate warning and check valid IDEs
give_tmate_warning () {
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
        echo ""
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
}

# Prompt for user and password if not provided
login() {
    # TODO: do not login if given already
    echo ""
    if [[ -z "$user" ]]; then
        read -p "Enter user for $opcenter: " user
    fi
    if [[ -z "$password" ]]; then
        read -sp "Enter password for $opcenter: " password
        echo ""
    fi
    "$float_executable" login -a "$opcenter" -u "$user" -p "$password"
}

# Adjust publish port if not set by user and by ide
determine_ports() {
    if [[ "$publish_set" == false && "$ide" == "rstudio" ]]; then
        publish="8787:8787"
    fi
    if [[ "$publish_set" == false && "$ide" == "vscode" ]]; then
        publish="8989:8989"
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
}

# Data volume handling
determine_mounts() {
    if [[ $no_mount == false ]]; then
        if [[ ${#mounts[@]} -gt 0 ]]; then  # Check if mounts has any elements
            for mount in "${mounts[@]}"; do
                dataVolumeOption+=("--dataVolume" "[mode=rw,endpoint=s3.us-east-1.amazonaws.com]${mount}")
            done
        fi
    else
        dataVolumeOption=()
    fi
}

# Determine VM Policy for instance
determine_vm_policy() {
    case "$(echo "$vm_policy" | tr '[:upper:]' '[:lower:]')" in
        spotonly) vm_policy_command="[spotOnly=true]" ;;
        ondemand) vm_policy_command="[onDemand=true]" ;;
        spotfirst) vm_policy_command="[spotFirst=true]" ;;
        *)
            echo "Invalid VM Policy setting '$vm_policy'. Please use 'spotOnly', 'onDemand', or 'spotFirst'"
            exit 1
            ;;
    esac
}

# Find parent directory of scripts to use the right one
find_script_dir() {
    SOURCE=${BASH_SOURCE[0]}
    while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
        SOURCE=$(readlink "$SOURCE")
        [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
    echo $DIR
}

# Determine if there are exisitng interactive jobs for this user
determine_running_jobs() {
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
}

# Additional float parameter checks
float_parameter_checks() {
    # Build the float submit command as an array
    float_submit_args+=(
        "-a" "$opcenter"
        "-i" "$image" "-c" "$core" "-m" "$mem"
        "--vmPolicy" "$vm_policy_command"
        "--gateway" "$gateway"
        "--securityGroup" "$securityGroup"
        "--migratePolicy" "[disable=true,evadeOOM=false]"
        "--publish" "$publish"
        "--withRoot"
        "--allowList" "[r5*,r6*,r7*,m*]"
        "-j" "$script_dir/bind_mount.sh"
        "--hostInit" "$script_dir/${host_script}"
        "--dirMap" "/mnt/efs:/mnt/efs"
        "-n" "$job_name"
        "--env" "GRANT_SUDO=yes"
        "--env" "VMUI=$ide"
        "--env" "EFS=$efs_ip"
    )

    # Specific parameters for jupyter job
    if [ $ide == "jupyter" ] || [ $ide == "jupyter-lab" ]; then
        float_submit_args+=(
        "--env" "JUPYTER_RUNTIME_DIR=/tmp/jupyter_runtime"
        "--env" "JUPYTER_ENABLE_LAB=TRUE"
        "--env" "ALLOWABLE_IDLE_TIME_SECONDS=$idle_time"
        )
    fi

    # If dataVolume is nonempty, add it in
    if (( ${#dataVolumeOption[@]} )); then
        float_submit_args+=(
            "${dataVolumeOption[@]}"
        )
    fi
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
    # If entrypoint provided, add it
    if [[ ! -z "$entrypoint" ]]; then
        float_submit_args+=(
            "--env" "ENTRYPOINT=$entrypoint"
        )
    fi
    # If suspend_on is empty, suspension feature is on
    # If it is populated, turn off suspension with an env variable
    if [[ "$suspend_off" == "true" ]]; then
        float_submit_args+=(
            "--env" "SUSPEND_FEATURE=false"
        )
    fi
}

# Validate mode combinations
validate_modes() {
    if [[ -z "$oem_admin" && -z "$shared_admin" && -z "$mount_packages" && -z "$oem_packages" ]]; then
        echo "Error: At least one of --oem-admin, --shared-admin, --mount-packages, or --oem-packages must be provided."
        exit 1
    elif [[ -n "$oem_admin" && (-n "$shared_admin" || -n "$mount_packages" || -n "$oem_packages") ]]; then
        echo "Error: --oem-admin cannot be used the other modes."
        exit 1
    elif [[ -n "$shared_admin" && (-n "$oem_admin" || -n "$mount_packages" || -n "$oem_packages") ]]; then
        echo "Error: --shared-admin cannot be used the other modes."
        exit 1
    fi

    # Allowable combinations: oem-packages and mount-packages
    if [[ -n "$mount_packages" && -n "$oem_packages" ]]; then
        float_submit_args+=(
            "--env" "MODE=oem_mount_packages"
        )
    elif [[ -n "$mount_packages" ]]; then
        float_submit_args+=(
            "--env" "MODE=mount_packages"
        )
    elif [[ -n "$oem_packages" ]]; then
        float_submit_args+=(
            "--env" "MODE=oem_packages"
        )
    elif [[ -n "$oem_admin" ]]; then
        echo ""
        echo -e "${RED}WARNING: ${NC}Make sure the specified EFS IP corresponds to the batch EFS, as ${RED}--oem-admin${NC} mode requires the ${RED}batch EFS${NC}."
        while true; do
                echo -e "Is your EFS IP correct (y/N)? \c"
                read input
                input=${input:-n}  # Default to "n" if no input is given
                case $input in
                    [yY])
                        break
                        ;;
                    [nN]) 
                        # If warning is not accepted, exit the script
                        echo "Exiting the script."
                        exit 0
                        ;;
                    *) 
                        echo "Invalid input. Please enter 'y' or 'n'."
                        ;;
                esac
            done

        running_batch_jobs=$($float_executable list -a $batch_opcenter -u $user -p $password -f "status=Executing or status=Floating or status=Suspended or status=Suspending or status=Starting or status=Initializing" | awk '{print $4}' | grep -v -e '^$' -e 'NAME' || true) 
        if [[ ! -z $running_batch_jobs ]]; then
            batch_job_count=$(echo "$running_batch_jobs" | wc -l)
        else
            batch_job_count=0
        fi
        if [[ $batch_job_count -gt 0 ]]; then
            echo ""
            echo -e "${RED}WARNING: ${NC}There are ${batch_job_count} batch jobs running. Updating packages in the batch setup could lead to checkpoint failures."
            while true; do
                echo -e "Do you wish to proceed (y/N)? \c"
                read input
                input=${input:-n}  # Default to "n" if no input is given
                case $input in
                    [yY])
                        break
                        ;;
                    [nN]) 
                        # If warning is not accepted, exit the script
                        echo "Exiting the script."
                        exit 0
                        ;;
                    *) 
                        echo "Invalid input. Please enter 'y' or 'n'."
                        ;;
                esac
            done
        fi
        float_submit_args+=(
            "--env" "MODE=oem_admin"
            "--env" "PIXI_HOME=/mnt/efs/shared/.pixi"
        )
        host_script="host_init_batch.sh"

    elif [[ -n "$shared_admin" ]]; then
        running_int_jobs=$($float_executable list -a $opcenter -f "status=Executing or status=Floating or status=Suspended or status=Suspending or status=Starting or status=Initializing" | awk '{print $4}' | grep -v -e '^$' -e 'NAME' || true)
        if [[ ! -z $running_int_jobs ]]; then
            int_job_count=$(echo "$running_int_jobs" | wc -l)
        else
            int_job_count=0
        fi
        if [[ $int_job_count -gt 0 ]]; then
            echo ""
            echo -e "${RED}WARNING: ${NC}There are ${int_job_count} interactive jobs running. Updating packages in the interactive setup could lead to checkpoint failures."
            while true; do
                echo -e "Do you wish to proceed (y/N)? \c"
                read input
                input=${input:-n}  # Default to "n" if no input is given
                case $input in
                    [yY])
                        break
                        ;;
                    [nN]) 
                        # If warning is not accepted, exit the script
                        echo "Exiting the script."
                        exit 0
                        ;;
                    *) 
                        echo "Invalid input. Please enter 'y' or 'n'."
                        ;;
                esac
            done
        fi
        float_submit_args+=(
            "--env" "MODE=shared_admin"
            "--env" "PIXI_HOME=/mnt/efs/shared/.pixi"
        )
    fi
}

# Local variables not affected by CLI
host_script="host_init_interactive.sh"
float_submit_args=(
    "$float_executable" "submit"
)
batch_opcenter=3.82.198.55 # Hard-coded for now - only used when running oem-admin mode

# Call commands
check_required_params
script_dir=$(find_script_dir)
give_tmate_warning
login
determine_ports
determine_mounts
determine_vm_policy

# Existing job checks
determine_running_jobs

# Build float command
float_parameter_checks
validate_modes

# Display the float submit command
echo ""
echo "#-------------"
echo -e "${float_submit_args[*]}"
echo "#-------------"

# Submit the job and retrieve job ID
# Execute or echo the full command
if [ "$dryrun" = true ]; then
    exit 0
else
    float_submit_output=$(echo "yes" | "${float_submit_args[@]}")
    jobid=$(echo "$float_submit_output" | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}' || true)
fi
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
        echo "Please give the instance about 5 minutes to start RStudio"
        echo "RStudio Server URL: http://$IP_ADDRESS" > "${jobid}_rstudio.log"
        ;;
    vscode)
        IP_ADDRESS=$(get_public_ip "$jobid")
        echo "To access code-server, navigate to http://$IP_ADDRESS in your web browser."
        echo "Please give the instance about 5 minutes to start vscode"
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
