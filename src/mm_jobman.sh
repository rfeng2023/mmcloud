#!/bin/bash
# Gao Wang and MemVerge Inc.

RED='\033[0;31m'
NC='\033[0m' # No Color

# Required values (given by CLI)
opcenter=""
gateway=""
securityGroup=""
efs_ip=""

# Modes
batch_mode=""
interactive_mode=""
shared_admin="" # For updating shared packages in interactive jobs
mount_packages="" # For accessing one's own packages in interactive and batch jobs
oem_packages="" # For accessing shared packages in interactive and batch jobs. Default.

# Global optional values (given by CLI) - some default values given
declare -a dataVolumeOption=()
declare -a ebs_mount=()
declare -a ebs_mount_size=()
declare -a mount_local=()
declare -a mount_remote=()
declare -a mountOpt=()
declare -a extra_parameters=()
core=2
mem=16
dryrun=false
entrypoint=""
float_executable="float"
image="quay.io/danielnachun/tmate-minimal"
image_vol_size=3
root_vol_size=""
job_name=""
user=""
password=""
vm_policy=""

# Batch-specific optional values
job_script=""
job_size=""
cwd="~"
parallel_commands=""
min_cores_per_command=0
min_mem_per_command=0
no_fail="|| { command_failed=1; break; }"
no_fail_parallel="--halt now,fail=1"
declare -a download_local=()
declare -a download_remote=()
declare -a download_include=()
declare -a upload_local=()
declare -a upload_remote=()

# Interactive-specific optional values
ide=""
idle_time=7200
publish="8888:8888"
publish_set=false
suspend_off=""

# Function to display usage information
usage() {
    echo ""
    echo "Usage: $0 [options]"
    echo "Required Options:"
    echo "  -o, --opcenter <ip>                   Set the OP IP address"
    echo "  -sg, --securityGroup <group>          Set the security group"
    echo "  -g, --gateway <id>                    Set gateway"
    echo "  -efs <ip>                             Set EFS IP"
    echo ""

    echo "Required Batch Options:"
    echo "  --job-script <file>                   Main job script to be run on MMC."                          
    echo "  --job-size <value>                    Set the number of commands per job for creating virtual machines."
    echo ""

    echo "Batch-specific Options:"
    echo "  --cwd <value>                         Define the working directory for the job (default: ~)."
    echo "  --download <remote>:<local>           Download files/folders from S3. Format: <S3 path>:<local path> (space-separated)."
    echo "  --upload <local>:<remote>             Upload folders to S3. Format: <local path>:<S3 path>."
    echo "  --download-include '<value>'          Include certain files for download (space-separated), encapsulate in quotations."
    echo "  --no-fail-fast                        Continue executing subsequent commands even if one fails."
    echo "  --parallel-commands <value>           Set the number of commands to run in parallel (default: CPU value)."
    echo "  --min-cores-per-command <value>       Specify the minimum number of CPU cores required per command."
    echo "  --min-mem-per-command <value>         Specify the minimum amount of memory in GB required per command."
    echo ""

    echo "Required Interactive Options:"
    echo "  -ide, --interactive-develop-env <env> Set the IDE"
    echo ""

    echo "Interactive-specific Options:"
    echo "  --idle <seconds>                      Amount of idle time before suspension. Only works for jupyter instances (default: 7200 seconds)"
    echo "  --suspend-off                         For Jupyter jobs, turn off the auto-suspension feature"
    echo "  -pub, --publish <ports>               Set the port publishing in the form of port:port"
    echo "  --entrypoint <dir>                    Set entrypoint of interactive job - please give Github link"
    echo "  --shared-admin                        Run in admin mode to make changes to shared packages in interactive mode"
    echo ""

    echo "Global Options:"
    echo "  -u, --user <username>                 Set the username"
    echo "  -p, --password <password>             Set the password"
    echo "  -i, --image <image>                   Set the Docker image"
    echo "  -c <min>:<optional max>               Specify the exact number or a range of CPUs to use."
    echo "  -m <min>:<optional max>               Specify the exact amount or a range of memory to use (in GB)."
    echo "  --mount-packages                      Grant the ability to use user packages in interactive mode"
    echo "  --oem-packages                        Grant the ability to use shared packages in interactive mode"
    echo "  -vp, --vmPolicy <policy>              Set the VM policy"
    echo "  -ivs, --imageVolSize <size>           Set the image volume size"
    echo "  -rvs, --rootVolSize <size>            Set the root volume size"
    echo "  --ebs-mount <folder>=<size>           Mount an EBS volume to a local directory. Format: <local path>=<size>. Size in GB (space-separated)."
    echo "  --mount <s3_path:vm_path>             Add S3:VM mounts, separated by spaces"
    echo "  --mountOpt <value>                    Specify mount options for the bucket (required if --mount is used) (space-separated)."
    echo "  --env <variable>=<value>              Specify additional environmental variables (space-separated)."
    echo "  -jn, --job-name <name>                Set the job name (batch jobs will have a number suffix)"
    echo "  --float-executable <path>             Set the path to the float executable (default: float)"
    echo "  --dryrun                              Execute a dry run, printing commands without running them."
    echo "  -h, --help                            Display this help message"
}

# Parse command line options
while (( "$#" )); do
  case "$1" in
        -o|--opcenter) opcenter="$2"; shift 2;;
        -u|--user) user="$2"; shift 2;;
        -p|--password) password="$2"; shift 2;;
        -i|--image) image="$2"; shift 2;;
        -sg|--securityGroup) securityGroup="$2"; shift 2;;
        -g|--gateway) gateway="$2"; shift 2;;
        -c|--core) core="$2"; parallel_commands="$2"; shift 2;;
        -m|--mem) mem="$2"; shift 2;;
        -pub|--publish) publish="$2"; publish="$2"; publish_set=true; shift 2;;
        -efs) efs_ip="$2"; shift 2;;
        -vp|--vmPolicy) vm_policy="$2"; shift 2;;
        -ivs|--imageVolSize) image_vol_size="$2"; shift 2;;
        -rvs|--rootVolSize) root_vol_size="$2"; shift 2;;
        -ide|--interactive-develop-env) ide="$2"; interactive_mode="true"; shift 2;;
        -jn|--job-name) job_name="$2"; shift 2;;
        --float-executable) float_executable="$2"; shift 2;;
        --entrypoint) entrypoint="$2"; shift 2;;
        --idle) idle_time="$2"; shift 2;;
        --suspend-off) suspend_off=true; shift ;;
        --shared-admin) shared_admin=true; shift ;;
        --mount-packages) mount_packages=true; shift ;;
        --oem-packages) oem_packages=true; shift ;;
        --dryrun) dryrun=true; shift ;;
        --parallel-commands) parallel_commands="$2"; parallel_commands_given=true; shift 2;;
        --min-cores-per-command) min_cores_per_command="$2"; shift 2;;
        --min-mem-per-command) min_mem_per_command="$2"; shift 2;;
        --job-script) job_script="$2"; batch_mode="true"; shift 2;;
        --job-size) job_size="$2"; shift 2;;
        --cwd) cwd="$2"; shift 2;;
        --no-fail-fast) no_fail="|| true"; no_fail_parallel="--halt never || true" ; shift ;;
        --ebs-mount)
            shift
            while [ $# -gt 0 ] && [[ $1 != -* ]]; do
                IFS='=' read -ra PARTS <<< "$1"
                ebs_mount+=("${PARTS[0]}") 
                ebs_mount_size+=("${PARTS[1]}")
                shift
            done
            ;;
        --download-include)
            shift
                while [ $# -gt 0 ] && [[ $1 != -* ]]; do
                IFS='' read -ra INCLUDE <<< "$1"
                download_include+=("${INCLUDE[0]}")
                shift
            done
            ;;
        --mount|--download|--upload)
            current_flag="$1"
            shift
            while [ $# -gt 0 ] && [[ $1 != -* ]]; do
                IFS=':' read -ra PARTS <<< "$1"
                if [ "$current_flag" == "--mount" ]; then
                mount_local+=("${PARTS[1]}")
                mount_remote+=("${PARTS[0]}")
                elif [ "$current_flag" == "--download" ]; then
                download_remote+=("${PARTS[0]}")
                download_local+=("${PARTS[1]}")
                elif [ "$current_flag" == "--upload" ]; then
                upload_local+=("${PARTS[0]}")
                upload_remote+=("${PARTS[1]}")
                fi
                shift
            done
            ;;
        --mountOpt)
            shift
            while [ $# -gt 0 ] && [[ $1 != -* ]]; do
                IFS='' read -ra MOUNT <<< "$1"
                mountOpt+=("${MOUNT[0]}")
                shift
            done
            ;;
        -*|--*=)  # Unsupported flags
            extra_parameters+=("$1")  # Add the unsupported flag to extra_parameters
            shift  # Move past the flag
            # We expect the user to understand float cli commands if using this option
            # Therefore, all unsupported flags will be added to the end of the float command as they are
            # Add all subsequent arguments until the next flag to extra_parameters
            while [ $# -gt 0 ] && ! [[ "$1" =~ ^- ]]; do
                extra_parameters+=("$1")
                shift
            done
            ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
done

# Check required parameters are given
check_required_params() {
    # Check for missing params
    local missing_params=""
    local is_missing=false

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

    # Both `-ide` or `--job-script` cannot be specified
    if [ -n "$ide" ] && [ -n "$job_script" ]; then
        echo ""
        echo "Error: Please specify either an IDE for interactive jobs, or a job script for a batch job."
        exit 1
    # However, if neither are specified, we will be in the default tmate interactive job in oem-packages mode
    elif [ -z "$ide" ] && [ -z "$job_script" ]; then
        # It's possible for users to do `--shared-admin` when ide and job script are not defined.
        # Make sure share-admin is not defined
        if [ -z "$shared_admin" ]; then
            echo ""
            echo "Warning: Neither an IDE nor a job script was specified. Starting interactive tmate job in oem-packages mode."
            interactive_mode="true"
            ide="tmate"
            oem_packages=true
        # if shared-admin is defined, set the right parameters
        else
            echo ""
            echo "Warning: Shared-admin mode was specified without ide or job script. Starting interactive tmate job in shared-admin mode"
            interactive_mode="true"
            ide="tmate"
            shared_admin="true"
        fi
    fi

    # Batch and Interactive jobs use the same format to mount buckets
    if [[ ${#mount_local[@]} -ne ${#mountOpt[@]} ]]; then
        missing_params+="--mountOpt (required to match with --mount), "
        is_missing=true
    fi

    # Check for overlapping directories between ebs_mount and mount_local
    if (( ${#ebs_mount[@]} )) && (( ${#mount_local[@]} )); then
        for mount_dir in "${ebs_mount[@]}"; do
            for local_dir in "${mount_local[@]}"; do
                if [ "$mount_dir" == "$local_dir" ]; then
                    echo ""
                    echo "Error: Overlapping directories found in ebs_mount and mount_local: $mount_dir"
                    exit 1
                fi
            done
        done
    fi

    missing_params=${missing_params%, }
    if [ "$is_missing" = true ]; then
        echo "Error: Missing required parameters: $missing_params" >&2
        usage
        exit 1
    fi
}

# If it is an interactive job, prompt for user and password if not provided
# If it is a batch job, will check if   
login() {
    echo ""

    # For batch job
    if [[ "$batch_mode" == "true" ]]; then
        local output=$($float_executable login --info)
        local address=$(echo "$output" | grep -o 'address: [0-9.]*' | awk '{print $2}')
        if [ "$address" == "" ];then
            echo -e "\n[ERROR] No opcenter logged in to. Did you log in?"
            exit 1
        fi
        if [ "$opcenter" != "$address" ]; then
            echo -e "\n[ERROR] The provided opcenter address $opcenter does not match the logged in opcenter $address. Please log in to $opcenter."
            exit 1
        fi
        # If login was successful, save the float username
        user=$(echo "$output" | grep 'username' | awk '{print $2}')
    fi

    # For interactive job
    if [[ "$interactive_mode" == "true" ]]; then
        if [[ -z "$user" ]]; then
            read -p "Enter user for $opcenter: " user
        fi
        if [[ -z "$password" ]]; then
            read -sp "Enter password for $opcenter: " password
            echo ""
        fi
        "$float_executable" login -a "$opcenter" -u "$user" -p "$password"
    fi

    # If error returned by login, exit the script
    if [[ "$?" != 0 ]]; then
        echo ""
        echo "Error: Login failed. Please check username and password"
        exit 1
    fi
}

# Check if user is using the wrong parameters for the wrong mode
check_conflicting_parameters() {
    # Already checked if either (but not both or neither) modes are set
    local conflicting_params=""
    local is_conflicting=false

    # Check if using interactive-specific parameters for batch mode
    if [[ "$batch_mode" == "true" ]]; then
        # If the interactive mode variables are populated, return error
        if [[ ! -z "$shared_admin" ]]; then
            conflicting_params+="--shared-admin "
            is_conflicting=true
        fi
        if [[ "$idle_time" != 7200 ]]; then
            conflicting_params+="--idle "
            is_conflicting=true
        fi
        if [[ "$suspend_off" != "" ]]; then
            conflicting_params+="--suspend-off "
            is_conflicting=true
        fi
        if [[ "$publish_set" != false ]]; then
            conflicting_params+="-pub,--publish "
            is_conflicting=true
        fi
        if [[ "$entrypoint" != "" ]]; then
            conflicting_params+="--entrypoint "
            is_conflicting=true
        fi
        conflicting_params=${conflicting_params%, }
        if [ "$is_conflicting" = true ]; then
            echo ""
            echo "Error: Conflicting parameters for batch mode: $conflicting_params" >&2
            usage
            exit 1
        fi
    fi

    # Check if using batch-specific parameters for interactive mode
    if [[ "$interactive_mode" == "true" ]]; then
        if [[ ! -z "$job_size" ]]; then
            conflicting_params+="--job-size "
            is_conflicting=true
        fi
        if [[ "$cwd" != "~" ]]; then
            conflicting_params+="--cwd "
            is_conflicting=true
        fi
        if [[ ${#download_local[@]} -ne 0 ]]; then
            conflicting_params+="--download "
            is_conflicting=true
        fi
        if [[ ${#upload_local[@]} -ne 0 ]]; then
            conflicting_params+="--upload "
            is_conflicting=true
        fi
        if [[ ${#download_include[@]} -gt 0 ]]; then
            conflicting_params+="--download-include "
            is_conflicting=true
        fi
        if [[ "$no_fail" != "|| { command_failed=1; break; }" ]]; then
            conflicting_params+="--no-fail-fast "
            is_conflicting=true
        fi
        if [[ ! -z "$parallel_commands_given" ]]; then
            conflicting_params+="--parallel-commands "
            is_conflicting=true
        fi
        if [[ "$min_cores_per_command" -gt 0 ]]; then
            conflicting_params+="--min-cores-per-command "
            is_conflicting=true
        fi
        if [[ "$min_mem_per_command" -gt 0 ]]; then
            conflicting_params+="--min-mem-per-command "
            is_conflicting=true
        fi
        conflicting_params=${conflicting_params%, }
        if [ "$is_conflicting" = true ]; then
            echo ""
            echo "Error: Conflicting parameters for interactive mode: $conflicting_params" >&2
            usage
            exit 1
        fi

    fi
}

# # # Helper functions for batch jobs # # #
# If in batch mode, check params
check_required_batch_params() {
    local missing_params=""
    local is_missing=false

    if [ -z "$job_script" ]; then
        missing_params+="--job-script, "
        is_missing=true
    fi
    if [ -z "$job_size" ]; then
        missing_params+="--job-size, "
        is_missing=true
    fi

    if [[ ${#download_include[@]} -gt ${#download_local[@]} ]]; then
        missing_params+="--download-include (cannot surpass number of --download values), "
        is_missing=true
    fi

    # Batch mode can also specify either mount-packages, oem-packages, or both
    # However, if neither are given, default to oem-packages
    if [[ -z "$mount_packages" && -z "$oem_packages" ]]; then
        echo ""
        echo "Warning: No mode specified for batch job. Defaulting to oem-packages mode."
        oem_packages=true
    fi

    # Remove trailing comma and space
    missing_params=${missing_params%, }

    if [ "$is_missing" = true ]; then
        echo ""
        echo "Error: Missing required batch parameters: $missing_params" >&2
        usage
        exit 1
    fi

    # Additional check for --parallel-commands when --min-cores-per-command or --min-mem-per-command is specified
    if [[ "$min_cores_per_command" -gt 0 || "$min_mem_per_command" -gt 0 ]] && [[ "$parallel_commands" -gt 0 ]]; then
        echo ""
        echo "Error: --parallel-commands must be set to 0 for automatic determination when --min-cores-per-command or --min-mem-per-command is specified."
        exit 1
    fi

    # Check for overlapping directories between download_local and mount_local
    if (( ${#download_local[@]} )) && (( ${#mount_local[@]} )); then
        for download_dir in "${download_local[@]}"; do
            for mount_dir in "${mount_local[@]}"; do
                if [ "$download_dir" == "$mount_dir" ]; then
                    echo ""
                    echo "Error: Overlapping directories found in download_local and mount_local: $download_dir"
                    exit 1
                fi
            done
        done  
    fi
}

create_download_commands() {
  local download_cmd=""

    for i in "${!download_local[@]}"; do
      # If local folder has a trailing slash, we are copying into a folder, therefore we make the folder
      if [[ ${download_local[$i]} =~ /$ ]]; then
        download_cmd+="mkdir -p ${download_local[$i]%\/}\n"
      fi
      download_cmd+="aws s3 cp s3://${download_remote[$i]} ${download_local[$i]} --recursive"

      # Separate include commands with space
      if [ ${#download_include[@]} -gt 0 ]; then
        # Split by space
        IFS=' ' read -ra INCLUDES <<< "${download_include[$i]}"
        if [ ${#INCLUDES[@]} -gt 0 ]; then
          # If an include command is used, we want to make sure we don't include the entire folder
          download_cmd+=" --exclude '*'"
        fi
        for j in "${!INCLUDES[@]}"; do
          download_cmd+=" --include '${INCLUDES[$j]}'"
        done
      fi
      download_cmd+="\n"
    done

  download_cmd=${download_cmd%\\n}
  echo -e $download_cmd
}

create_upload_commands() {
  local upload_cmd=""

  # If no uploadOpt option, just create upload commands
  if [ ${#uploadOpt[@]} -eq 0 ]; then
    for i in "${!upload_local[@]}"; do
        upload_cmd+="mkdir -p ${upload_local[$i]%\/}\n"
        local upload_folder=${upload_remote[$i]%\/}
        if [[ ${upload_local[$i]} =~ /$ ]]; then
          upload_cmd+="aws s3 sync ${upload_local[$i]} s3://${upload_folder}\n"
        else  
          local last_folder=$(basename "${upload_local[$i]}")
          upload_cmd+="aws s3 sync ${upload_local[$i]} s3://${upload_folder}/$last_folder\n"
        fi
    done
  fi

  upload_cmd=${upload_cmd%\\n}
  echo -e $upload_cmd
}

mount_batch_buckets() {
    local dataVolume_cmd=""
    # If more than one mount option, we expect there to be the same number of mounted buckets
    if [ ${#mountOpt[@]} -eq  ${#mount_local[@]} ]; then
        for i in "${!mountOpt[@]}"; do
            dataVolume_cmd+="--dataVolume '[${mountOpt[$i]},endpoint=s3.us-east-1.amazonaws.com]s3://${mount_remote[$i]}:${mount_local[$i]}' "
        done
    else
        # Number of mountOptions > 1 and dne number of buckets
        echo ""
        echo -e "\n[ERROR] If there are multiple mount options, please provide the same number of mount options and same number of buckets\n"
        exit 1
    fi

  echo -e $dataVolume_cmd
}

mount_batch_volumes() {
  local volumeMount_cmd=""

  for i in "${!ebs_mount[@]}"; do
    local folder="${ebs_mount[i]}"
    local size="${ebs_mount_size[i]}"

    volumeMount_cmd+="--dataVolume '[size=$size]:$folder' "
  done

  echo -e $volumeMount_cmd
}

calculate_max_parallel_jobs() {
    # Required minimum resources per job
    min_cores_per_cmd=$1  # Minimum CPU cores required per job
    min_mem_per_cmd=$2    # Minimum memory required per job in GB

    # Available system resources
    available_cores=$(lscpu | grep "CPU(s):" | head -n 1 | awk '{print $2}')  # Total available CPU cores
    # available_memory_gb=$(free -m | grep Mem: | awk '{print $2}' | awk '{print int($1/1024)}')
    available_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    available_memory_gb=$((available_memory_kb / 1024 / 1024))

    # Initialize max_parallel_jobs to default parallen_commands
    max_parallel_jobs=$3
    max_jobs_by_cpu=0
    max_jobs_by_mem=0

    # Calculate the maximum number of jobs based on CPU constraints, if applicable
    if [ -n "$min_cores_per_cmd" ] && [ "$min_cores_per_cmd" -gt 0 ]; then
        max_jobs_by_cpu=$((available_cores / min_cores_per_cmd))
        if [ "$max_jobs_by_cpu" -eq 0 ]; then
            max_jobs_by_cpu=1  # Ensure at least 1 job can run if the division results in 0
        fi
    fi

    # Calculate the maximum number of jobs based on memory constraints, if applicable
    if [ -n "$min_mem_per_cmd" ] && [ "$min_mem_per_cmd" -gt 0 ]; then
        max_jobs_by_mem=$((available_memory_gb / min_mem_per_cmd))
        if [ "$max_jobs_by_mem" -eq 0 ]; then
            max_jobs_by_mem=1  # Ensure at least 1 job can run if the division results in 0
        fi
    fi

    # Determine the maximum number of parallel jobs based on the more restrictive resource (CPU or memory)
    if [ "$max_jobs_by_cpu" -gt 0 ] && [ "$max_jobs_by_mem" -gt 0 ]; then
        max_parallel_jobs=$(( max_jobs_by_cpu < max_jobs_by_mem ? max_jobs_by_cpu : max_jobs_by_mem ))
    elif [ "$max_jobs_by_cpu" -gt 0 ]; then
        max_parallel_jobs=$max_jobs_by_cpu
    elif [ "$max_jobs_by_mem" -gt 0 ]; then
        max_parallel_jobs=$max_jobs_by_mem
    fi

    if [ "$max_parallel_jobs" -eq 0 ]; then
        max_parallel_jobs=1
    fi

    echo -e $available_cores $available_memory_gb $max_parallel_jobs
}

submit_each_line_with_float() {
    local script_file="$1"
    local download_cmd=""
    local upload_cmd=""
    local download_mkdir=""
    local upload_mkdir=""
    local dataVolume_params=""

    # Check if the script file exists
    if [ ! -f "$script_file" ]; then
        echo ""
        echo "Script file does not exist: $script_file"
        return 1
    fi

    # Check if the script file is empty
    if [ ! -s "$script_file" ]; then
        echo ""
        echo "Script file is empty: $script_file"
        return 0
    fi

    # Only create download and upload commands if there are corresponding parameters
    if [ ${#download_local[@]} -ne 0 ]; then
        download_cmd=$(create_download_commands)
    fi
    if [ ${#upload_local[@]} -ne 0 ]; then
        upload_cmd=$(create_upload_commands)
    fi

    # Separate out the mkdir commands
    download_mkdir=$(echo -e "$download_cmd" | grep 'mkdir')
    upload_mkdir=$(echo -e "$upload_cmd" | grep 'mkdir')
    # Remove mkdir commands from the original command
    download_cmd=$(echo -e "$download_cmd" | grep -v 'mkdir')
    upload_cmd=$(echo -e "$upload_cmd" | grep -v 'mkdir')

    # Mount bucket(s) with provided mount options
    dataVolume_params=$(mount_batch_buckets)

    # Mount volume(s)
    volume_params=$(mount_batch_volumes)

    # Read all lines from the script file into an array
    all_commands=()
    total_commands=0
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue  # Skip empty lines
        fi
        all_commands+=("$line")
        total_commands=$(( total_commands + 1))  
    done < <(sed -e '$a\' $script_file) # always add a newline to the end of file before sending it in

    # Divide the commands into jobs based on job-size
    num_jobs=$(( ($total_commands + $job_size - 1) / $job_size )) # Ceiling division

    # Determine VM Policy
    # In batch mode, vmPolicy is spotOnly by default - variable is empty initially
    if [[ -z $vm_policy ]]; then
        vm_policy_command="[spotOnly=true,retryInterval=900s]"
    else
        local lowercase_vm_policy=$(echo "$vm_policy" | tr '[:upper:]' '[:lower:]')
        if [ $lowercase_vm_policy == "spotonly" ]; then
            vm_policy_command="[spotOnly=true,retryInterval=900s]"
        elif [ $lowercase_vm_policy == "ondemand" ]; then
            vm_policy_command="[onDemand=true]"
        elif [ $lowercase_vm_policy == "spotfirst" ]; then
            vm_policy_command="[spotFirst=true]"
        else
            echo ""
            echo "Invalid VM Policy setting '$vm_policy'. Please use 'spotOnly', 'onDemand', or 'spotFirst'"
            return 1
        fi
    fi

    # Ability to use --mount-packages and --oem-packages as batch user
    local directory_setup="vm_username=\$(whoami)\n"
    if [[ $oem_packages == true && $mount_packages == true ]]; then
        # Can access user and shared packages
        directory_setup+="ln -sf /mnt/efs/$user/.pixi /home/\${vm_username}/.pixi\n"
        directory_setup+="export PATH=\"\${HOME}/.pixi/bin:/mnt/efs/shared/.pixi/bin:\${PATH}\"\n"
        directory_setup+="mkdir -p \${HOME}/.local/lib/python3.12/site-packages\n"
        directory_setup+="mkdir -p \${HOME}/.pixi/envs/python/lib/R/etc\n"
        directory_setup+="export PYTHONPATH=\"\${HOME}/.pixi/envs/python/lib/python3.12/site-packages:/mnt/efs/shared/.pixi/envs/python/lib/python3.12/site-packages\"\n"
        directory_setup+="echo \".libPaths(c('\${HOME}/.pixi/envs/r-base/lib/R/library', '/mnt/efs/shared/.pixi/envs/r-base/lib/R/library'))\" > \${HOME}/.Rprofile\n"
    elif [[ $mount_packages == true ]]; then
        # Only user packages
        directory_setup+="ln -sf /mnt/efs/$user/.pixi /home/\${vm_username}/.pixi\n"
        directory_setup+="export PATH=\"\${HOME}/.pixi/bin:\${PATH}\"\n"
        directory_setup+="mkdir -p \${HOME}/.local/lib/python3.12/site-packages\n"
        directory_setup+="mkdir -p \${HOME}/.pixi/envs/python/lib/R/etc\n"
        directory_setup+="export PYTHONPATH=\"\${HOME}/.pixi/envs/python/lib/python3.12/site-packages\"\n"
        directory_setup+="echo \".libPaths(c('\${HOME}/.pixi/envs/r-base/lib/R/library'))\" > \${HOME}/.Rprofile\n"
    elif [[ $oem_packages == true ]]; then
        # Only shared packages
        directory_setup+="export PATH=\"/mnt/efs/shared/.pixi/bin:\${PATH}\"\n"
        directory_setup+="export PYTHONPATH=\"/mnt/efs/shared/.pixi/envs/python/lib/python3.12/site-packages\"\n"
        directory_setup+="echo \".libPaths(c('/mnt/efs/shared/.pixi/envs/r-base/lib/R/library'))\" > \${HOME}/.Rprofile\n"
    fi

    # Loop to create job submission commands
    for (( j = 0; j < $num_jobs; j++ )); do
        full_cmd=""
        # Using a sliding-window effect, take the next job_size number of jobs
        start=$(($j * $job_size))
        end=$(($start + $job_size - 1))

        commands=()
        i=$start
        while [[ $i -le $end && $i -lt ${#all_commands[*]} ]]; do
          commands+=("\"${all_commands[$i]}\"")
          i=$(( i + 1 ))
        done

        if [ "$dryrun" = true ]; then
            full_cmd+="#-------------\n"
        fi

        # Create the job script using heredoc
        calculate_max_parallel_jobs_def=$(declare -f calculate_max_parallel_jobs)
        submission_script=$(cat << EOF
#!/bin/bash

set -o errexit -o pipefail

# Symlink /mnt/efs/shared folders to \${HOME} to make software available
${directory_setup}

# Function definition for calculate_max_parallel_jobs
${calculate_max_parallel_jobs_def}

# Create directories if they don't exist for download
${download_mkdir}
# Create directories if they don't exist for upload
${upload_mkdir}
# Create directories if they don't exist for cwd
mkdir -p ${cwd}

# Execute the download commands to fetch data from S3
${download_cmd}

# Change to the specified working directory
cd ${cwd}

# Compute parallel command numbers based on runtime values
read available_cores available_memory_gb num_parallel_commands < <(calculate_max_parallel_jobs ${min_cores_per_command} ${min_mem_per_command} ${parallel_commands})
echo "Available CPU cores: \$available_cores"
echo "Available Memory: \$available_memory_gb GB"
echo "Maximum parallel jobs: \$num_parallel_commands"

# Initialize a flag to track command success, which can be changed in no_fail
command_failed=0

# Conditional execution based on num_parallel_commands and also length of commands
commands_to_run=(${commands[@]})
if [[ \$num_parallel_commands -gt 1 && ${#commands[*]} -gt 1 ]]; then
    printf "%%s\\\\n" "\${commands_to_run[@]}"  | parallel -j \$num_parallel_commands ${no_fail_parallel}
else
    printf "%%s\\\\n" "\${commands_to_run[@]}" | while IFS= read -r cmd; do
        eval \$cmd ${no_fail}
    done
fi

# Always execute the upload commands to upload data to S3
${upload_cmd}

# Check if any command failed
if [ \$command_failed -eq 1 ]; then
    exit 1
fi
EOF
)
        if [ "$dryrun" = true ]; then
            job_filename=${script_file%.*}_"$j".mmjob.sh 
        else
            mkdir -p ${TMPDIR:-/tmp}/${script_file%.*}
            job_filename=${TMPDIR:-/tmp}/${script_file%.*}/$j.mmjob.sh
        fi
        printf "$submission_script" > $job_filename 

        # Generating float command
        full_cmd+="$float_executable submit -a $opcenter \n\
        --securityGroup $securityGroup \n\
        -i '$image' \n\
        -j $job_filename \n\
        -c $core \n\
        -m $mem \n\
        --hostInit $host_script \n\
        --dirMap /mnt/efs:/mnt/efs \n\
        --withRoot \n\
        --vmPolicy $vm_policy_command \n\
        --env EFS=$efs_ip \n"

        # Add dataVolume and additional volume params if they are not empty
        if [[ ! -z  $dataVolume_params ]]; then
            full_cmd+=" $dataVolume_params"
        fi
        if [[ ! -z  $volume_params ]]; then
            full_cmd+=" $volume_params"
        fi
        
        # Add job_name with number suffix if given
        if [[ ! -z "$job_name" ]]; then
            full_cmd+=" -n ${job_name}_${j}"
        fi

        # If image vol size and root vol size not empty, populate float args
        if [[ ! -z "$image_vol_size" ]]; then
            full_cmd+=" --imageVolSize $image_vol_size"
        fi
        if [[ ! -z "$root_vol_size" ]]; then
            full_cmd+=" --rootVolSize $root_vol_size"
        fi

        # Set MODE env variable
        if [[ -n "$mount_packages" && -n "$oem_packages" ]]; then
            full_cmd+=" --env MODE=oem_mount_packages"
        elif [[ -n "$mount_packages" ]]; then
            full_cmd+=" --env MODE=mount_packages"
        elif [[ -n "$oem_packages" ]]; then
            full_cmd+=" --env MODE=oem_packages"
        fi

        # Added extra parameters if given
        for param in "${extra_parameters[@]}"; do
          full_cmd+=" $param"
        done

        full_cmd=${full_cmd%\ }

        # Execute or echo the full command
        if [ "$dryrun" = true ]; then
            echo -e "${full_cmd}"
        else
            jobid=$(eval "$full_cmd" | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}')
            echo "Job ID: $jobid"
            rm -rf ${TMPDIR:-/tmp}/${script_file%.*}
        fi
    done 
}

###########################################

# # # Helper functions for interactive jobs # # #
# If in interactive mode, check params
check_required_interactive_params(){
    # Check for interactive mode params
    # If none of the modes are given, default to oem-packages mode
    if [[ -z "$shared_admin" && -z "$mount_packages" && -z "$oem_packages" ]]; then
        echo ""
        echo "Warning: No mode specified for interactive job. Defaulting to oem-packages mode."
        oem_packages=true
    elif [[ -n "$shared_admin" && (-n "$mount_packages" || -n "$oem_packages") ]]; then
        echo ""
        echo "Error: --shared-admin cannot be used with the other package modes."
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
determine_interactive_mounts() {
    # Mounting buckets
    # If more than one mount option, we expect there to be the same number of mounted buckets
    # As we did a check in check_required_params
    if [ ${#mountOpt[@]} -eq  ${#mount_local[@]} ]; then
        for i in "${!mountOpt[@]}"; do
            float_submit_interactive_args+=("--dataVolume" "[${mountOpt[$i]},endpoint=s3.us-east-1.amazonaws.com]s3://${mount_remote[$i]}:${mount_local[$i]}")
        done
    fi

    # Mounting EBS volumes
    for i in "${!ebs_mount[@]}"; do
        local folder="${ebs_mount[i]}"
        local size="${ebs_mount_size[i]}"
        float_submit_interactive_args+=("--dataVolume" "[size=$size]:$folder")
    done
}

# Determine VM Policy for instance
determine_vm_policy() {
    # If vm_policy is empty, set to onDemand
    if [[ -z $vm_policy ]]; then
        vm_policy_command="[onDemand=true]"
    else
        case "$(echo "$vm_policy" | tr '[:upper:]' '[:lower:]')" in
            spotonly) vm_policy_command="[spotOnly=true]" ;;
            ondemand) vm_policy_command="[onDemand=true]" ;;
            spotfirst) vm_policy_command="[spotFirst=true]" ;;
            *)
                echo "Invalid VM Policy setting '$vm_policy'. Please use 'spotOnly', 'onDemand', or 'spotFirst'"
                exit 1
                ;;
        esac
    fi
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
    float_submit_interactive_args+=(
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
        "--hostInit" "${host_script}"
        "--dirMap" "/mnt/efs:/mnt/efs"
        "-n" "$job_name"
        "--env" "GRANT_SUDO=yes"
        "--env" "VMUI=$ide"
        "--env" "EFS=$efs_ip"
    )

    # Specific parameters for jupyter job
    if [ $ide == "jupyter" ] || [ $ide == "jupyter-lab" ]; then
        float_submit_interactive_args+=(
        "--env" "JUPYTER_RUNTIME_DIR=/tmp/jupyter_runtime"
        "--env" "JUPYTER_ENABLE_LAB=TRUE"
        "--env" "ALLOWABLE_IDLE_TIME_SECONDS=$idle_time"
        )
    fi

    # If dataVolume is nonempty, add in mount and ebs mounts
    if (( ${#dataVolumeOption[@]} )); then
        float_submit_interactive_args+=(
            "${dataVolumeOption[@]}"
        )
    fi

    # If image vol size and root vol size not empty, populate float args
    if [[ ! -z "$image_vol_size" ]]; then
        float_submit_interactive_args+=(
            "--imageVolSize" "$image_vol_size"
        )
    fi
    if [[ ! -z "$root_vol_size" ]]; then
        float_submit_interactive_args+=(
            "--rootVolSize" "$root_vol_size"
        )
    fi
    # If entrypoint provided, add it
    if [[ ! -z "$entrypoint" ]]; then
        float_submit_interactive_args+=(
            "--env" "ENTRYPOINT=$entrypoint"
        )
    fi
    # If suspend_on is empty, suspension feature is on
    # If it is populated, turn off suspension with an env variable
    if [[ "$suspend_off" == "true" ]]; then
        float_submit_interactive_args+=(
            "--env" "SUSPEND_FEATURE=false"
        )
    fi

    # Added extra parameters if given
    for param in "${extra_parameters[@]}"; do
        float_submit_interactive_args+=(
            "$param"
        )
    done
}

# Validate mode combinations
validate_modes() {
    # Allowable combinations: oem-packages and mount-packages
    if [[ -n "$mount_packages" && -n "$oem_packages" ]]; then
        float_submit_interactive_args+=(
            "--env" "MODE=oem_mount_packages"
        )
    elif [[ -n "$mount_packages" ]]; then
        float_submit_interactive_args+=(
            "--env" "MODE=mount_packages"
        )
    elif [[ -n "$oem_packages" ]]; then
        float_submit_interactive_args+=(
            "--env" "MODE=oem_packages"
        )
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
        float_submit_interactive_args+=(
            "--env" "MODE=shared_admin"
            "--env" "PIXI_HOME=/mnt/efs/shared/.pixi"
        )
    fi
}

# For interactive jobs - get gateway IP of job
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

# For interactive jobs - get tmate url
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

# For interactive jobs - get jupyter link and token
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

# Submit job
submit_interactive_job() {
    # Display the float submit command
    echo ""
    echo "#-------------"
    echo -e "${float_submit_interactive_args[*]}"
    echo "#-------------"

    # Submit the job and retrieve job ID
    # Execute or echo the full command
    if [ "$dryrun" = true ]; then
        exit 0
    else
        float_submit_output=$(echo "yes" | "${float_submit_interactive_args[@]}")
        jobid=$(echo "$float_submit_output" | grep 'id:' | awk -F'id: ' '{print $2}' | awk '{print $1}' || true)
    fi
    if [[ -z "$jobid" ]]; then
        echo "Error returned from float submission command! Exiting..."
        exit 1
    fi
    echo ""
    echo "JOB ID: $jobid"

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

}
#################################################

# --- MAIN SECTION ---

# Check required parameters (regardless of batch or interactive)
check_required_params
check_conflicting_parameters
script_dir=$(find_script_dir)
host_script="${script_dir}/host_init.sh"
# Start batch mode if batch_mode is true
if [[ "$batch_mode" == "true" ]]; then
    echo "Starting batch mode..."

    # Check parameters
    check_required_batch_params

    login

    # Submit job
    submit_each_line_with_float $job_script

# Start interactive mode if interactive_mode is true
elif [[ "$interactive_mode" == "true" ]]; then
    echo "Starting interactive mode..."

    # Initialize variables
    float_submit_interactive_args=(
        "$float_executable" "submit"
    )
    
    # Check parameters
    check_required_interactive_params

    # Additional helper functions
    give_tmate_warning
    login
    determine_ports
    determine_interactive_mounts
    determine_vm_policy

    # Existing job checks
    determine_running_jobs

    # Build float command
    float_parameter_checks
    validate_modes

    # Submit interactive job
    submit_interactive_job
fi
