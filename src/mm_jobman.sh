#!/bin/bash
# Gao Wang and MemVerge Inc.

# Help function
show_help() {
    echo "Usage: $0 [options] <script>"
    echo "Options:"
    echo "  -c <value>                   Specify the number of CPUs to use (default and recommended for AWS Spot Instances: 2)."
    echo "  -m <value>                   Set the amount of memory in GB (default: 16)."
    echo "  --cwd <value>                Define the working directory for the job (default: ~)."
    echo "  --download <remote>:<local>  Download files/folders from S3. Format: <S3 path>:<local path> (optional)."
    echo "  --upload <local>:<remote>    Upload folders to S3. Format: <local path>:<S3 path> (optional)."
    # echo "  --downloadOpt '<value>'      Options for download, separated by ',' (optional)."
    # echo "  --uploadOpt '<value>'        Options for upload, separated by ',' (optional)."
    echo "  --dryrun                     Execute a dry run, printing commands without running them."
    echo "  --entrypoint '<command>'     Set the initial command to run in the job script (required)."
    echo "  --env <key>=<val>            Set environmental variables for the job in the format KEY=VALUE (optional)."
    echo "  --image <value>              Specify the Docker image to use for the job (required)."
    echo "  --imageVolSize <value>       Define the size of the image volume in GB (depends on the size of input image)."
    echo "  --job-size <value>           Set the number of commands per job for creating virtual machines (default: 2)."
    echo "  --mount <bucket>:<local>     Mount an S3 bucket to a local directory. Format: <bucket>:<local path> (optional)."
    echo "  --mountOpt <value>           Specify mount options for the bucket (required)."
    echo "  --volMount <size>:<folder>   Mount a volume under a directory. Size in GB (optional)."
    echo "  --no-fail-fast               Continue executing subsequent commands even if one fails."
    echo "  --opcenter <value>           Provide the Opcenter address for the job (required)."
    echo "  --parallel-commands <value>  Set the number of commands to run in parallel (default: number of CPUs)."
    echo "  --help                       Show this help message."
}

# Check if at least one argument is provided
if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

# Initialize variables for options with default values
# CPU = 2 is a good default for AWS Spot instances
c_value=2
m_value=16
declare -a mountOpt=()
image=""
dryrun=false
declare -a mount_local=()
declare -a mount_remote=()
declare -a download_local=()
declare -a download_remote=()
declare -a downloadOpt=()
declare -a uploadOpt=()
declare -a upload_local=()
declare -a upload_remote=()
opcenter=""
entrypoint="date"
cwd="~"
env=""
job_size=2
parallel_commands=$c_value
imageVolSize=""
no_fail="|| { command_failed=1; break; }"
declare -a volMount=()

while (( "$#" )); do
  case "$1" in
    -c)
      c_value="$2"
      parallel_commands=$c_value
      shift 2
      ;;
    -m)
      m_value="$2"
      shift 2
      ;;
    --mountOpt)
      shift
      while [ $# -gt 0 ] && [[ $1 != -* ]]; do
        IFS='' read -ra MOUNT <<< "$1"
        mountOpt+=("${MOUNT[0]}")
        shift
      done
      ;;
    --volMount)
      shift
      while [ $# -gt 0 ] && [[ $1 != -* ]]; do
        IFS='' read -ra VOLUME <<< "$1"
        volMount+=("${VOLUME[0]}")
        shift
      done
      ;;
    --image)
      image="$2"
      shift 2
      ;;
    # --downloadOpt)
    #   shift
    #   while [ $# -gt 0 ] && [[ $1 != -* ]]; do
    #     IFS=',' read -ra DOWNLOAD <<< "$1"
    #     echo "${DOWNLOAD[0]}"
    #     downloadOpt+=("${DOWNLOAD[0]}")
    #     shift
    #   done
    #   ;;
    # --uploadOpt)
    #   shift
    #   while [ $# -gt 0 ] && [[ $1 != -* ]]; do
    #     IFS=',' read -ra UPLOAD <<< "$1"
    #     uploadOpt+=("${UPLOAD[0]}")
    #     shift
    #   done
    #   ;;
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
    --opcenter)
      opcenter="$2"
      shift 2
      ;;
   --entrypoint)
      entrypoint="$2"
      shift 2
      ;;
   --cwd)
      cwd="$2"
      shift 2
      ;;
   --env)
      env="$2"
      shift 2
      ;;
   --job-size)
      job_size="$2"
      shift 2
      ;;
   --parallel-commands)
      parallel_commands="$2"
      shift 2
      ;;
   --imageVolSize)
      imageVolSize="$2"
      shift 2
      ;;
   --no-fail-fast)
      no_fail="|| true"
      shift 
      ;;
   --dryrun)
      dryrun=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *)
      SCRIPT_NAME="$1"  # Assume the first non-option argument is the script name
      shift
      ;;
  esac
done


check_required_params() {
    local missing_params=""
    local is_missing=false

    if [ -z "$image" ]; then
        missing_params+="--image, "
        is_missing=true
    fi
    if [ -z "$mountOpt" ]; then
        missing_params+="--mountOpt, "
        is_missing=true
    fi
    if [ -z "$opcenter" ]; then
        missing_params+="--opcenter, "
        is_missing=true
    fi
    if [ -z "$entrypoint" ]; then
        missing_params+="--entrypoint, "
        is_missing=true
    fi
    if [ ${#mount_local[@]} -eq 0 ]; then
        missing_params+="--mount, "
        is_missing=true
    fi

    # Remove trailing comma and space
    missing_params=${missing_params%, }

    if [ "$is_missing" = true ]; then
        echo "Error: Missing required parameters: $missing_params"
        show_help
        exit 1
    fi
}

create_download_commands() {
  local download_cmd=""

  # If no downloadOpt option, just create download commands
  if [ ${#downloadOpt[@]} -eq 0 ]; then
    for i in "${!download_local[@]}"; do
      # If local folder has a trailing slash, we are copying into a folder, therefore we make the folder
      if [[ ${download_remote[$i]} =~ /$ ]]; then
        download_cmd+="mkdir -p ${download_local[$i]}\n"
      fi
        download_cmd+="aws s3 cp s3://${download_remote[$i]} ${download_local[$i]} --recursive\n"
    done
  fi

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
        upload_cmd+="mkdir -p ${upload_local[$i]}\n"
        if [[ ${upload_local[$i]} =~ /$ ]]; then
          upload_cmd+="aws s3 sync ${upload_local[$i]} s3://${upload_remote[$i]}\n"
        else  
          local last_folder=$(basename "${upload_local[$i]}")
          upload_cmd+="aws s3 sync ${upload_local[$i]} s3://${upload_remote[$i]}/$last_folder\n"
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

  while [ $start -lt ${#array[@]} ]; do
      local end=$((start + parallel_commands))
      # If parallel_commands is 1, or if only one remainder command,
      # No need for `parallel`
      end_val=${#array[@]}
      if [ $parallel_commands -ne 1 ] && [ $((end_val - start)) -ne 1 ]; then
        substring+='parallel :::'
      fi
      for ((i = start; i < end && i < ${#array[@]}; i++)); do
	      substring+=" "
          # No quotation marks if it is a singular command
          if [ $parallel_commands -ne 1 ] && [ $((end_val - start)) -ne 1 ]; then
            substring+="${array[i]}"
          else
            # Marker for single commands, as should not have quotes later
            substring+="<${array[i]}>"
          fi
      done
      start=$end
      substring+='\n'
  done
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

  for i in "${!volMount[@]}"; do
    IFS=':' read -ra PARTS <<< "${volMount[i]}"
    local size="${PARTS[0]}"
    local folder="${PARTS[1]}"

    volumeMount_cmd+="--dataVolume '[size=$size]:$folder'"
  done

  echo -e $volumeMount_cmd
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
    done < "$script_file"
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
        full_cmd+="float submit -i '$image' -j $job_filename -c $c_value -m $m_value $dataVolume_params $volume_params"

        # Additional float cli parameters
        if [[ ! -z '$env' ]]; then
          full_cmd+=" --env $env"
        fi
        if [[ ! -z '$imageVolSize' ]]; then
          full_cmd+=" --imageVolSize $imageVolSize"
        fi

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
        echo "#c value: $c_value"
        echo "#m value: $m_value"
        echo "#mountOpt value: $mountOpt"
        echo "#image value: $image"
        echo "#opcenter value: $opcenter"
        echo "#entrypoint value: $entrypoint"
        echo "#cwd value: $cwd"
        echo "#env values: $env"
        echo "#job-size: $job_size"
        echo "#parallel-commands: $parallel_commands"
        echo "#commands to run:"
    fi
    submit_each_line_with_mmfloat "$SCRIPT_NAME"
}

main
