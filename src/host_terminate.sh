#!/bin/bash

# Cd into correct directory
export HOME=/root
cd /home/jovyan

# The following section contains functions and commands that should not be modified by the user.
function dump_metadata() {
  echo $(date): "Attempting to dump JuiceFS data"
  juicefs dump redis://$(echo $WORKER_ADDR):6868/1 $METADATA_ID.meta.json.gz --keep-secret-key
  echo $(date): "JuiceFS metadata $METADATA_ID.meta.json.gz created."
}

function cp_metadata() {
  # We will only copy the metadata to the bucket if it was created later than the current metadata (if it exists)
  FOUND_METADATA=$(aws s3 ls s3://wanggroup | grep "$METADATA_ID.meta.json.gz" | awk '{print $4}')

  if [[ ! -z $FOUND_METADATA ]]; then
    # If previous metadata is found, compare the date of creation
    FOUND_METADATA_DATE=$(date -d "$(aws s3 ls s3://rnaseq-full-1 | grep $METADATA_ID.meta.json.gz | awk '{print $1,$2}')" "+%Y-%m-%d %H:%M:%S")
    
    if [[ $CURRENT_TIME < $FOUND_METADATA_DATE ]] ; then
      # If the METADATA date is AFTER the CURRENT_TIME, leave the metadata alone
      echo $(date): "Latest metadata date in bucket is AFTER the current time"
      echo $(date): "Leaving metadata alone..."
    else
      # If the METADATA date is BEFORE the CURRENT_TIME, overwrite the metadata with our latest one
      echo $(date): "Latest metadata date in bucket is AFTER the current time"
      echo $(date): "Copying latest metadata to bucket"
      aws s3 cp "$(echo $METADATA_ID).meta.json.gz" s3://wanggroup
      echo $(date): "Copying to bucket complete!"
    fi  
else
    # No previous metadata found, copy metadata to bucket
    echo $(date): "No previous metadata found - copying latest metadata to bucket"
    aws s3 cp "$(echo $METADATA_ID).meta.json.gz" s3://wanggroup
    echo $(date): "Copying to bucket complete!"
fi
}

# Functions pre-Nextflow run
# AWS S3 Access and Secret Keys: For accessing S3 buckets. 
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
METADATA_ID="${FLOAT_USER//_/}_JFS"
dump_metadata
cp_metadata
