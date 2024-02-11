#!/bin/bash
# Gao Wang and MemVerge Inc.

# Help function
#!/bin/bash

# Help function with updated documentation
show_help() {
    echo "Usage: $0 [options] <script>"
    echo "Options:"
    echo "  -c <min>:<optional max>                   Specify the exact number of CPUs to use, or, with ':', the min and max of CPUs to use. Required."
    echo "  -m <min>:<optional max>                   Specify the exact amount of memory to use, or, with ':', the min and max of memory in GB. Required."
    echo "  --cwd <value>                             Define the working directory for the job (default: ~)."
    echo "  --download <remote>:<local>               Download files/folders from S3. Format: <S3 path>:<local path> (optional)."
    echo "  --upload <local>:<remote>                 Upload folders to S3. Format: <local path>:<S3 path> (optional)."
    echo "  --download-include '<value>'              Use the include flag to include certain files for download (space-separated) (optional)."
    # echo "  --downloadOpt '<value>'      Options for download, separated by ',' (optional)."
    # echo "  --uploadOpt '<value>'        Options for upload, separated by ',' (optional)."
    echo "  --dryrun                                  Execute a dry run, printing commands without running them."
    echo "  --entrypoint '<command>'                  Set the initial command to run in the job script (required)."
    echo "  --image <value>                           Specify the Docker image to use for the job (required)."
    echo "  --job-size <value>                        Set the number of commands per job for creating virtual machines (required)."
    echo "  --mount <bucket>:<local>                  Mount an S3 bucket to a local directory. Format: <bucket>:<local path> (optional)."
    echo "  --mountOpt <value>                        Specify mount options for the bucket (required if --mount is used)."
    echo "  --ebs-mount <folder>=<size>               Mount an EBS volume to a local directory. Format: <local path>=<size>. Size in GB (optional)."
    echo "  --no-fail-fast                            Continue executing subsequent commands even if one fails."
    echo "  --opcenter <value>                        Provide the Opcenter address for the job (required)."
    echo "  --parallel-commands <value>               Set the number of commands to run in parallel (default: number of CPUs)."
    echo "  --help                                    Show this help message."
}

# Check if at least one argument is provided
if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

# Initialize variables for options with default values
c_min=""
c_max=""
m_min=""
m_max=""
declare -a mountOpt=()
image=""
entrypoint=""
cwd="~"
job_size=""
opcenter=""
parallel_commands=""
declare -a mount_local=()
declare -a mount_remote=()
declare -a download_local=()
declare -a download_remote=()
declare -a download_include=()
#declare -a downloadOpt=()
#declare -a uploadOpt=()
declare -a upload_local=()
declare -a upload_remote=()
declare -a ebs_mount=()
declare -a ebs_mount_size=()
dryrun=false
no_fail="|| { command_failed=1; break; }"
declare -a extra_parameters=()

while (( "$#" )); do
  case "$1" in
    -c)
      if [[ "$2" =~ ":" ]]; then
        c_min=$(echo "$2" | cut -d':' -f1)
        c_max=:$(echo "$2" | cut -d':' -f2)
      else
        c_min="$2"
        c_max=":$2"
      fi
      parallel_commands=$c_min  # Default parallel commands to min CPU if not specified
      shift 2
      ;;
    -m)
      if [[ "$2" =~ ":" ]]; then
        m_min=$(echo "$2" | cut -d':' -f1)
        m_max=:$(echo "$2" | cut -d':' -f2)
      else
        m_min="$2"
        m_max=":$2"
      fi
      shift 2
      ;;
    --image)
      image="$2"
      shift 2
      ;;
    --entrypoint)
      entrypoint="$2"
      shift 2
      ;;
    --opcenter)
      opcenter="$2"
      shift 2
      ;;
    --job-size)
      job_size="$2"
      shift 2
      ;;
    --cwd)
      cwd="$2"
      shift 2
      ;;
    --parallel-commands)
      parallel_commands="$2"
      shift 2
      ;;
    --mount)
      while [[ "$2" =~ ":" ]]; do
        mount_local+=("$(echo "$2" | cut -d':' -f2)")
        mount_remote+=("$(echo "$2" | cut -d':' -f1)")
        shift
      done
      shift
      ;;
    --mountOpt)
      while [ $# -gt 0 ] && [[ $1 != -* ]]; do
        mountOpt+=("$1")
        shift
      done
      ;;
    --download)
      while [[ "$2" =~ ":" ]]; do
        download_remote+=("$(echo "$2" | cut -d':' -f1)")
        download_local+=("$(echo "$2" | cut -d':' -f2)")
        shift
      done
      shift
      ;;
    --upload)
      while [[ "$2" =~ ":" ]]; do
        upload_local+=("$(echo "$2" | cut -d':' -f1)")
        upload_remote+=("$(echo "$2" | cut -d':' -f2)")
        shift
      done
      shift
      ;;
    --download-include)
      IFS=' ' read -ra download_include <<< "$2"
      shift 2
      ;;
    --ebs-mount)
      while [[ "$2" =~ "=" ]]; do
        ebs_mount+=("$(echo "$2" | cut -d'=' -f1)")
        ebs_mount_size+=("$(echo "$2" | cut -d'=' -f2)")
        shift
      done
      shift
      ;;
    --dryrun)
      dryrun=true
      shift
      ;;
    --no-fail-fast)
      no_fail="|| true"
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    # We expect the user to understand float cli commands
    # Therefore, all unsupported flags will be added to the end of the float command as they are
    -*|--*=)  # Unsupported flags
      extra_parameters+=("$1")  # Add the unsupported flag to extra_parameters
      shift  # Move past the flag
      # Add all subsequent arguments until the next flag to extra_parameters
      while [ $# -gt 0 ] && ! [[ "$1" =~ ^- ]]; do
        extra_parameters+=("$1")
        shift
      done
      ;;
    *)
      SCRIPT_NAME="$1"  # Assume the first non-option argument is the script name
      shift
      ;;
  esac
done

# Function to check for required parameters
check_required_params() {
    local missing_params=""
    local is_missing=false

    if [ -z "$c_min" ]; then
        missing_params+="-c, "
        is_missing=true
    fi
    if [ -z "$m_min" ]; then
        missing_params+="-m, "
        is_missing=true
    fi
    if [ -z "$image" ]; then
        missing_params+="--image, "
        is_missing=true
    fi
    if [ -z "$job_size" ]; then
        missing_params+="--job-size, "
        is_missing=true
    fi
    if [ -z "$opcenter" ]; then
        missing_params+="--opcenter, "
        is_missing=true
    fi
    if [[ ${#mount_local[@]} -gt 0 && ${#mountOpt[@]} -eq 0 ]]; then
        missing_params+="--mountOpt (required with --mount), "
        is_missing=true
    fi

    # Remove trailing comma and space
    missing_params=${missing_params%, }

    if [ "$is_missing" = true ]; then
        echo "Error: Missing required parameters: $missing_params" >&2
        show_help
        exit 1
    fi

    # Check for overlapping directories between ebs_mount and mount_local
    for mount_dir in "${ebs_mount[@]}"; do
        for local_dir in "${mount_local[@]}"; do
            if [ "$mount_dir" == "$local_dir" ]; then
                echo "Error: Overlapping directories found in ebs_mount and mount_local: $mount_dir"
                exit 1
            fi
        done
    done

    # Check for overlapping directories between download_local and mount_local
    for download_dir in "${download_local[@]}"; do
        for mount_dir in "${mount_local[@]}"; do
            if [ "$download_dir" == "$mount_dir" ]; then
                echo "Error: Overlapping directories found in download_local and mount_local: $download_dir"
                exit 1
            fi
        done
    done
}

create_download_commands() {
  local download_cmd=""

  # if [ ${#downloadOpt[@]} -eq 0 ]; then
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
  # fi

  # # If just one downloadOpt option, use the same one for all download commands
  # elif [ ${#downloadOpt[@]} -eq 1 ]; then
  #   for i in "${!download_local[@]}"; do
  #     # If local folder has a trailing slash, we are copying into a folder, therefore we make the folder
  #     if [[ ${download_remote[$i]} =~ /$ ]]; then
  #       download_cmd+="mkdir -p ${download_local[$i]}\n"
  #     fi
  #       download_cmd+="aws s3 cp s3://${download_remote[$i]} ${download_local[$i]} $downloadOpt\n"
  #   done

  # # If more than one downloadOpt option, we expect there to be the same number of download commands
  # elif [ ${#downloadOpt[@]} -eq  ${#download_local[@]} ]; then
  #   for i in "${!downloadOpt[@]}"; do
  #     # If local folder has a trailing slash, we are copying into a folder, therefore we make the folder
  #     if [[ ${download_remote[$i]} =~ /$ ]]; then
  #       download_cmd+="mkdir -p ${download_local[$i]}\n"
  #     fi
  #     download_cmd+="aws s3 cp s3://${download_remote[$i]} ${download_local[$i]} ${downloadOpt[$i]}\n"
  #   done

  # # Number of downloadOpts > 1 and dne number of downloads
  # else
  #   echo -e "\n[ERROR] If there are multiple download options, please provide the same number of download options and same number of downloads\n"
  #   exit 1
  # fi

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

  # # If just one uploadOpt option, use the same one for all upload commands
  # elif [ ${#uploadOpt[@]} -eq 1 ]; then
  #   for i in "${!upload_local[@]}"; do
  #     upload_cmd+="mkdir -p ${upload_local[$i]}\n"
  #     if [[ ${upload_local[$i]} =~ /$ ]]; then
  #       upload_cmd+="aws s3 sync ${upload_local[$i]} s3://${upload_remote[$i]} $uploadOpt\n"
  #     else  
  #       local last_folder=$(basename "${upload_local[$i]}")
  #       upload_cmd+="aws s3 sync ${upload_local[$i]} s3://${upload_remote[$i]}/$last_folder $uploadOpt\n"
  #     fi
  #   done

  # # If more than one uploadOpt option, we expect there to be the same number of upload commands
  # elif [ ${#uploadOpt[@]} -eq  ${#upload_local[@]} ]; then
  #   for i in "${!uploadOpt[@]}"; do
  #     upload_cmd+="mkdir -p ${upload_local[$i]}\n"
  #     if [[ ${upload_local[$i]} =~ /$ ]]; then
  #         upload_cmd+="aws s3 sync ${upload_local[$i]} s3://${upload_remote[$i]} ${uploadOpt[$i]}\n"
  #     else
  #       local last_folder=$(basename "${upload_local[$i]}")
  #       upload_cmd+="aws s3 sync ${upload_local[$i]} s3://${upload_remote[$i]}/$last_folder ${uploadOpt[$i]}\n"
  #     fi
  #   done

  # # Number of uploadOpts > 1 and dne number of uploads
  # else
  #   echo -e "\n[ERROR] If there are multiple upload options, please provide the same number of upload options and same number of uploads\n"
  #   exit 1
  # fi

  upload_cmd=${upload_cmd%\\n}
  echo -e $upload_cmd
}

generate_parallel_commands() {
  local job_commands=$1
  
  IFS=$'\n' read -d '' -ra array <<< "$(echo "$job_commands" | grep -o -E "'([^']+)'")"
  local start=0
  substring=''

  # If parallel_commands is 1, or if only one remainder command,
  # No need for `parallel`
  end_val=${#array[@]}
  if [ $parallel_commands -ne 1 ] && [ $((end_val - start)) -ne 1 ]; then
    substring+="parallel -j $parallel_commands :::"
  fi
  for ((i = start; i < end_val; i++)); do
    substring+=" "
    substring+="${array[i]}"
  done

  substring+='\n'
  echo -e $substring
}

mount_buckets() {
  local dataVolume_cmd=""

  # If just one mount option, use the same one for all bucket mounting
  if [ ${#mountOpt[@]} -eq 1 ]; then
    for i in "${!mount_local[@]}"; do
        dataVolume_cmd+="--dataVolume '[$mountOpt]s3://${mount_remote[$i]}:${mount_local[$i]}' "
    done

  # If more than one mount option, we expect there to be the same number of mounted buckets
  else
    if [ ${#mountOpt[@]} -eq  ${#mount_local[@]} ]; then
      for i in "${!mountOpt[@]}"; do
            dataVolume_cmd+="--dataVolume '[${mountOpt[$i]}]s3://${mount_remote[$i]}:${mount_local[$i]}' "
      done
    else
      # Number of mountOptions > 1 and dne number of buckets
      echo -e "\n[ERROR] If there are multiple mount options, please provide the same number of mount options and same number of buckets\n"
      exit 1
    fi
  fi

  echo -e $dataVolume_cmd
}

mount_volumes() {
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
    available_cores=$(nproc)  # Total available CPU cores
    echo "Available CPU cores: $avaliable_cores"
    available_memory_gb=$(free -m | grep Mem: | awk '{print $2}' | awk '{printf "%.0f", $1/1024}')  # Total available memory in GB
    echo "Available Memory: $available_memory_gb GB"

    # Calculate the maximum number of jobs based on CPU and memory constraints
    max_jobs_by_cpu=$((available_cores / min_cores_per_cmd))
    max_jobs_by_mem=$((available_memory_gb / min_mem_per_cmd))

    # Determine the limiting factor and set the maximum number of parallel jobs
    if [ $max_jobs_by_cpu -le $max_jobs_by_mem ]; then
        max_parallel_jobs=$max_jobs_by_cpu
    else
        max_parallel_jobs=$max_jobs_by_mem
    fi

    echo "Maximum parallel jobs: $max_parallel_jobs"
}

submit_each_line_with_mmfloat() {
    local script_file="$1"
    local download_cmd=""
    local upload_cmd=""
    local download_mkdir=""
    local upload_mkdir=""
    local dataVolume_params=""

    # Check if the script file exists
    if [ ! -f "$script_file" ]; then
        echo "Script file does not exist: $script_file"
        return 1
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
    dataVolume_params=$(mount_buckets)

    # Mount volume(s)
    volume_params=$(mount_volumes)

    # Read all lines from the script file into an array
    all_commands=""
    total_commands=0
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue  # Skip empty lines
        fi
        all_commands+="'$line'\n"
        total_commands=$(( total_commands + 1))  
    done < <(sed -e '$a\' $script_file) # always add a newline to the end of file before sending it in
    all_commands=${all_commands%\\n}
    # Divide the commands into jobs based on job-size
    num_jobs=$(( ($total_commands + $job_size - 1) / $job_size )) # Ceiling division
    # Loop to create job submission commands
    for (( j = 1; j < $num_jobs + 1; j++ )); do
        full_cmd=""
        # Using a sliding-window effect, take the next job_size number of jobs
        start=$((($j - 1) * $job_size + 1))
        end=$(($start + $job_size - 1))
        job_commands=$(echo -e "$all_commands" | sed -n "$start,${end}p")

        # Extract commands to use with `parallel`
        paralleled=$(generate_parallel_commands "$job_commands")
        paralleled=${paralleled%&&}

        # Add the mmfloat submit command for each line
        if [ "$dryrun" = true ]; then
            full_cmd+="#-------------\n"
        fi

        # Replacing single quotes with double quotes
        # Because job script submitted removes single quotes
        subline=$(echo -e "$paralleled")
        subline=${subline//\'/\"}
        # If no `parallel` in the line, no need for any quotation marks
        # as it a singular command
        # Use < > markers to remove quotation marks
        subline=${subline//\<\"/}
        subline=${subline//\">/}

        # Create the job script using heredoc
        job_script=$(cat << EOF
#!/bin/bash

set -o errexit -o pipefail
# Activate environment with entrypoint in job script
${entrypoint}

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

# Initialize a flag to track command success
# which can be changed in $no_fail
command_failed=0
{
    while IFS= read -r command; do
        eval \$command $no_fail
    done <<< '''${subline}'''
}

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
        printf "$job_script" > $job_filename 
        full_cmd+="float submit -i '$image' -j $job_filename -c $c_min$c_max -m $m_min$m_max $dataVolume_params $volume_params "

        # Added extra parameters if given
        for param in "${extra_parameters[@]}"; do
          full_cmd+="$param "
        done
        full_cmd=${full_cmd%\ }

        # Execute or echo the full command
        if [ "$dryrun" = true ]; then
            echo -e "${full_cmd}"
        else
            eval "$full_cmd"
            rm -rf ${TMPDIR:-/tmp}/${script_file%.*}
        fi
    done 
}

main() {
    check_required_params
    if [ "$dryrun" = true ]; then
        echo "#Processing script: $SCRIPT_NAME"
        echo "#c values: $c_min$c_max"
        echo "#m values: $m_min$m_max"
        echo "#mountOpt value: $mountOpt"
        echo "#image value: $image"
        echo "#opcenter value: $opcenter"
        echo "#entrypoint value: $entrypoint"
        echo "#cwd value: $cwd"
        echo "#job-size: $job_size"
        echo "#parallel-commands: $parallel_commands"
        echo "#extra float parameters: $extra_parameters"
        echo "#commands to run:"
    fi
    submit_each_line_with_mmfloat "$SCRIPT_NAME"
}

main