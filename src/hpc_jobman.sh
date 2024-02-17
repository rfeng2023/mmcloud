#!/bin/bash
# CUMC StatFunGen Lab members

# Help function
show_help() {
    echo "Usage: $0 [options] <script>"
    echo "Options:"
    echo "  -c <value>                                Specify the exact number of CPUs to use. Required."
    echo "  -m <value>                                Specify the exact amount of memory to use in GB. Required."
    echo "  --walltime <value>                        Specify the walltime for the job in the format hh:mm:ss. Required."
    echo "  --queue <value>                           Specify the queue to submit the job to. Required."
    echo "  --cwd <value>                             Define the working directory for the job (default: current directory)."
    echo "  --entrypoint '<command>'                  Set the initial command to run in the job script (required)."
    echo "  --job-size <value>                        Set the number of commands per job (required)."
    echo "  --job-name <value>                        Set the name prefix of jobs (required)."
    echo "  --no-fail-fast                            Continue executing subsequent commands even if one fails."
    echo "  --parallel-commands <value>               Set the number of commands to run in parallel (default: 1)."
    echo "  --dryrun                                  Execute a dry run, printing commands without running them."
    echo "  --help                                    Show this help message."
}

# Initialize variables with default values
c_value=""
m_value=""
entrypoint=""
cwd=$(pwd)
job_size=""
job_name=""
parallel_commands=""
dryrun=false
no_fail="|| { command_failed=1; break; }"
walltime=""
queue=""
no_fail="|| { command_failed=1; break; }"
no_fail_parallel="--halt now,fail=1 || { command_failed=1; }"
declare -a extra_parameters=()

# Parse command-line arguments
while (( "$#" )); do
  case "$1" in
    -c)
      c_value="$2"
      parallel_commands=$c_value  # Default parallel commands to CPU if not specified
      shift 2
      ;;
    -m)
      m_value="$2"
      shift 2
      ;;
    --entrypoint)
      entrypoint="$2"
      shift 2
      ;;
    --job-size)
      job_size="$2"
      shift 2
      ;;
    --job-name)
      job_name="$2"
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
    --no-fail-fast)
      no_fail="|| true"
      no_fail_parallel="--halt never || true"
      shift
      ;;
    --dryrun)
      dryrun=true
      shift
      ;;
    --walltime)
      walltime="$2"
      shift 2
      ;;
    --queue)
      queue="$2"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    -*|--*=)  # Unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *)
      SCRIPT_NAME="$1"  # Assume the first non-option argument is the script name
      shift
      ;;
  esac
done

# Function to check for required parameters
check_required_params() {
    if [ -z "$c_value" ] || [ -z "$m_value" ] || [ -z "$walltime" ] || [ -z "$queue" ] || [ -z "$job_size" ] || [ -z "$job_name" ]; then
        echo "Error: Missing required parameters." >&2
        show_help
        exit 1
    fi
}

submit_jobs_with_qsub() {
    local script_file="$1"

    # Check if the script file exists
    if [ ! -f "$script_file" ]; then
        echo "Script file does not exist: $script_file"
        return 1
    fi

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
        job_script=$(cat << EOF
#!/bin/sh
#$ -l h_rt=${walltime}
#$ -l h_vmem=${m_value}G
#$ -pe openmp ${c_value}
#$ -q ${queue}
#$ -N ${job_name}
#$ -o ${cwd}/${job_name}-\$JOB_ID.out
#$ -e ${cwd}/${job_name}-\$JOB_ID.err  
#$ -j y
#$ -S /bin/bash

set -o errexit -o pipefail

# Create directories if they don't exist for cwd
mkdir -p ${cwd}

# Activate environment with entrypoint in job script
${entrypoint}

# Change to the specified working directory
cd ${cwd}

# Initialize a flag to track command success, which can be changed in no_fail
command_failed=0

# Conditional execution based on parallel_commands and also length of commands
commands_to_run=(${commands[@]})
if [[ $parallel_commands -gt 1 && ${#commands[*]} -gt 1 ]]; then
    printf "%%s\\\\n" "\${commands_to_run[@]}"  | parallel -j $parallel_commands ${no_fail_parallel}
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
        printf "$job_script" > $job_filename 
        full_cmd+="qsub $job_filename "

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
    submit_jobs_with_qsub "$SCRIPT_NAME"
}

main
