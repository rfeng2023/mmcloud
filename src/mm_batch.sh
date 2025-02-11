#!/bin/bash

## BATCH DEFAULTS -- PLEASE CHANGE DEFAULTS HERE IF NECESSARY ##
opcenter=3.82.198.55
gateway=g-sidlpgb7oi9p48kxycpmn
efs_ip=fs-0e43817652b4ed69f.fsx.us-east-1.amazonaws.com@tcp:/csbjpb4v
security_group=sg-02867677e76635b25
################################################################

# Find parent directory of mm_jobman.sh
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

script_dir=$(find_script_dir)
$script_dir/mm_jobman.sh -o $opcenter -g $gateway -efs $efs_ip -sg $security_group --vmPolicy spotOnly "$@"
