#!/usr/bin/env bash
#
# Copyright (C) 2023 MemVerge Inc.
#

JOBFILE="run_multiple_jobs.sh"
FLOAT="mmfloat"
FLOAT_CRED="-u admin -p memverge"
#OPCENTER="-a my.opcenter.aws"
OPCENTER="54.81.85.209"
JOB_ARGS="-j helloworld.sh  -i cactus  -m 8 -c 2"
QUEUE_DEPTH=4
NUM_JOBS=10
LOG="jobmanager.log"

RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m' # No color

usage() {
    echo "This script is to submit a set number of jobs while queuing up the rest"
    echo "Usage:"
    echo "$0 [ -f|--jobfile ]       # Job file contains a list of float submit commands"
    echo "                [ -e|--float_cli ]     # Location for MM Cloud CLI float command"
    echo "                [ -a|--address ]       # Hostname or IP address of the MM Cloud OpCenter"
    echo "                [ -q|--queue_depth ]   # Depth of the job queue or number of parallel running jobs"
    echo "                [ -h|--help ]          # Display this help message"
}

# Log a message to a file
log() {
    echo -e `date +"%Y-%m-%d %H:%M:%S "` "$@" | tee -a $LOG
}

# Print out a informational message started with "INFO: "
info() {
    log "INFO: $1"
}

# Print out a warning message started with "WARNING: "
warn() {
    log "${ORANGE}WARNING${NC}: $1"
}

# Print out an error message started with "ERROR: "
error() {
    log "${RED}ERROR${NC}: $1"
}

# Print out a bar
bar() {
    echo "--------------------------------------------------------------"
}

# Ask if user wants to proceed
confirm() {
    local response
    # call with a prompt string or use a default
    if [[ $YES -eq 1 ]] ; then
        info "$1 [y/N]: yes"
        true
    else
        read -r -p "$1 [y/N]: " response
        case "$response" in
            [yY][eE][sS]|[yY])
                true
                ;;
            *)
                false
                ;;
        esac
    fi
}



# Get number of running jobs
running_jobs() {
    echo $($FLOAT $FLOAT_CRED squeue list | egrep 'Executing|Starting|Initializing|Floating' | wc -l)
}

# Run a job
run_job() {
    log "$@"
    $@ | tee -a $LOG
    sed -i .orig '1d' $JOBFILE.pending
    echo "$@" >> $JOBFILE.processed
}

# Wait for number of running jobs lower than the threadsold
hold_jobs() {
    while [ $(running_jobs) -ge $QUEUE_DEPTH ] ; do
        info "Job queue is full, check again in 5 seconds"
        sleep 6
    done
}

# Start of the MAIN function
args=$(getopt -l "jobfile,float_cli,address,queue_depth,help" -o "f:e:a:q:h" -- "$@")
if [[ $? -ne 0 ]] ; then
    usage
    exit 254
fi
eval set -- "$args"

while [[ $# -ge 1 ]]; do
    case "$1" in
        --)
            # No more options left.
            shift
            break ;;
        -f|--jobfile)
            JOBFILE=$2
	    echo "Processing job file $JOBFILE..."
            shift 2 ;;
        -e|--float_cli)
            FLOAT=$2
	    echo "float CLI executable is $FLOAT."
            shift 2 ;;
        -a|--address)
            OPCENTER="$2"
	    echo "OpCenter is $OPCENTER."
            shift 2 ;;
        -q|--queue_depth)
            QUEUE_DEPTH=$2
            echo "The Maximum number of parallel jobs is $QUEUE_DEPTH"
            shift 2 ;;
        -h|--help)
            usage
            exit 0 ;;
    esac
done

$FLOAT status >/dev/null 2>&1

if [[ $? -ne 0 ]] ; then
    bar
    error "float CLI $FLOAT is not found"
    warn "Please make sure command $FLOAT is included in the search path"
    exit 2
fi

if [[ $JOBFILE == "samplejobfile" ]] ; then
    info "No job script provided, generate an sample job script"
    sample_jobs
fi

if [[ -s $OPCENTER ]] ; then
    OPCENTER=$(grep address $HOME/.float/session.yaml | sed 's/:/ /g' | sed 's|/||g' | awk '{print $NF}')
fi

if [[ $($FLOAT login $FLOAT_CRED -a $OPCENTER) != "Login Succeeded!" ]] ; then
    error "Failed to login MMC OpCenter $OPCENTER"
    exit 255
fi

if confirm "Submit all jobs in job file $JOBFILE to OpCenter $OPCENTER" ; then
    rm -f $JOBFILE.pending* $JOBFILE.processed* $JOBFILE.tmp
else
    exit 3
fi

info "Generate pending job file $JOBFILE.pending"
info "Generate processed job file $JOBFILE.processed"
egrep 'submit|sbatch' $JOBFILE | sed 's/^[ \t]*//' | sed '/^#/d' > $JOBFILE.tmp
cp $JOBFILE.tmp $JOBFILE.pending

hold_jobs
while read line ; do
    run_job "$line"
    sleep 6
    diff=$(expr $QUEUE_DEPTH - $(running_jobs))
    if [[ $diff -ge 1 ]] ; then
        for i in $(seq $diff) ; do 
            read line
            echo inner "$line"
            if [[ ! -s "$line" ]] ; then
                echo run $line
                run_job "$line"
            fi
        done
    fi 
    [[ -s $JOBFILE.pending ]] && hold_jobs
done < $JOBFILE.tmp

rm -f $JOBFILE.tmp
info "All jobs submitted"

