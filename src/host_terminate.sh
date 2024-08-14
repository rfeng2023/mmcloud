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

# Returns 0 if current timestamps are NOT more recent - therefore no need to update metadata
# Returns 1 if current timestamps ARE more recent - therefore need to udpate metadata
function compare_timestamps() {
  # Copy over older timestamp files
  aws s3 cp s3://wanggroup/"$(echo $METADATA_ID)_pixi.txt" "$(echo $METADATA_ID)_pixi_BUCKET.txt"
  aws s3 cp s3://wanggroup/"$(echo $METADATA_ID)_micromamba.txt" "$(echo $METADATA_ID)_micromamba_BUCKET.txt"
  # Check md5sum of current directories
  cp /home/jovyan/.pixi/timestamp.txt "$(echo $METADATA_ID)_pixi.txt"
  cp /home/jovyan/micromamba/timestamp.txt "$(echo $METADATA_ID)_micromamba.txt"

  if [ "$(echo $METADATA_ID)_pixi_BUCKET.txt" < "$(echo $METADATA_ID)_pixi.txt" ]  && \
  [ "$(echo $METADATA_ID)_micromamba_BUCKET.txt" < "$(echo $METADATA_ID)_micromamba.txt" ] ; then
    # If either bucket (OLD) timestamps are older the current timestamps, metadata needs to be updated
    rm -rf "$(echo $METADATA_ID)_pixi_BUCKET.txt" "$(echo $METADATA_ID)_micromamba_BUCKET.txt"
    return 1
  else
    # Else, metadata does not need to be changed
    rm -rf "$(echo $METADATA_ID)_pixi_BUCKET.txt" "$(echo $METADATA_ID)_pixi.txt" "$(echo $METADATA_ID)_micromamba_BUCKET.txt" "$(echo $METADATA_ID)_micromamba.txt"
    return 0
  fi
}

function cp_metadata_timestamps() {
  # Dumping metadata
  echo $(date): "Copying latest metadata to bucket"
  dump_metadata
  aws s3 cp "$(echo $METADATA_ID).meta.json.gz" s3://wanggroup
  echo $(date): "Copying metadata to bucket complete!"

  # Dumping timestamp
  # If we are in this case, we assume the timestamp exists
  echo $(date): "Copying latest timestamp to bucket"
  aws s3 cp "$(echo $METADATA_ID)_pixi.txt" s3://wanggroup
  aws s3 cp "$(echo $METADATA_ID)_micromamba.txt" s3://wanggroup
  echo $(date): "Copying timestamps to bucket complete!"

  rm -rf "$(echo $METADATA_ID)_pixi.txt" "$(echo $METADATA_ID)_micromamba.txt"
}

function main() {
  # We will only copy the metadata to the bucket if the timestamps in .pixi and micromamba directories
  # are more recent than the ones in the bucket
  echo $(date): "Checking if '$METADATA_ID.meta.json.gz' exists in bucket"
  FOUND_METADATA=$(aws s3 ls s3://wanggroup | grep "$METADATA_ID.meta.json.gz" | awk '{print $4}')

  if [[ ! -z $FOUND_METADATA ]]; then
    # If previous metadata is found, we check the md5sums with it
    echo $(date): "Previous '$METADATA_ID.meta.json.gz' found - Checking timestamps"

    compare_timestamps
    if [ $? -eq 0 ]; then
      # If output of compare_timestamps is 0, no need to dump metadata
      echo $(date): "Timestamp files of pixi and micromamba folders are NOT newer than ones in bucket. No need to update metadata!!"
    else
      # If output of compare_timestamps is 1, metadata AND timestamp files need to be updated
      echo $(date): "Timestamp files of pixi and micromamba folders ARE newer than ones in bucket."
      cp_metadata_timestamps
    fi
else
    # No previous metadata found, copy metadata to bucket
    echo $(date): "No previous metadata found - This means we need to save the metadata and timestamp files"
    # In this case, no previous metadata found, which means no previous timestamp files found - needs to be generated
    cp /home/jovyan/.pixi/timestamp.txt "$(echo $METADATA_ID)_pixi.txt"
    cp /home/jovyan/micromamba/timestamp.txt "$(echo $METADATA_ID)_micromamba.txt"
    cp_metadata_timestamps
fi
}

# Functions pre-Nextflow run
# AWS S3 Access and Secret Keys: For accessing S3 buckets. 
CURRENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
METADATA_ID="${FLOAT_USER//_/}_JFS"
main
