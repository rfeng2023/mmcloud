#!/bin/bash

set -x
export PATH=/opt/aws/dist:$PATH

# Variables to update
S3_BUCKET="s3://cumc-gao/test"
workdir="/home/jovyan/AWS/data"
resultdir="/home/jovyan/AWS/data/susie_original2/susie"
RUNIMAGE="stephenslab"
RUNSCRIPT="susie_1_3_a9bfc671.R"

# Log file
LOG_FILE=$FLOAT_LOG_PATH/output.txt
touch $LOG_FILE

prepare_data() {
	# Prepare working directory and result directory
        mkdir -p $workdir/protocal_data
        mkdir -p $resultdir

	# Copy data from S3 to instance
	echo "[`date +%m-%d_%H:%M:%S`]:Ready to download job script from $S3_BUCKET to $workdir"
        aws s3 cp $S3_BUCKET/$RUNSCRIPT $workdir/
	echo "[`date +%m-%d_%H:%M:%S`]:Ready to download data from $S3_BUCKET to $workdir"
        aws s3 cp --recursive $S3_BUCKET/protocal_data/ $workdir/protocal_data/
        ls -lts $workdir/protocal_data/
}

run_test() {
	echo "[`date +%m-%d_%H:%M:%S`]:Running $RUNSCRIPT script"
        micromamba run -n $RUNIMAGE Rscript $workdir/$RUNSCRIPT
}

upload_result() {
	echo "[`date +%m-%d_%H:%M:%S`]:Uploading results to $S3_BUCKET"
	aws s3 sync $resultdir $S3_BUCKET/results 
}

main() {
	echo "[`date +%m-%d_%H:%M:%S`]:Ready to prepare source data"
	prepare_data
	echo "[`date +%m-%d_%H:%M:%S`]:Ready to run test"
	run_test
	echo "[`date +%m-%d_%H:%M:%S`]:Ready to save test result"
	upload_result
}

main >> $LOG_FILE 2>&1
