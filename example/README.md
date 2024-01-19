## Example `mm_jobman.sh` command

Here we assume that 

1. the data to be analyzed are already uploaded to S3 bucket by [the Data Admin](https://wanggroup.org/productivity_tips/memverge-aws#notes-for-data-admin).
2. the analysis script is also available on S3 --- in this example the [xqtl-pipeline repo](https://github.com/cumc/xqtl-pipeline) is cloned to the bucket.
3. the container image used for the analysis is the latest

We use the command below to submit commands in `commands_to_submit.txt`

```bash
username=aw3600
./src/mm_jobman.sh \
 ./example/commands_to_submit.txt \
 -c 2 -m 16 \
 --job-size 100 \
 --mount statfungen/ftp_fgc_xqtl:/home/$username/data \
	 statfungen/ftp_fgc_xqtl/sos_cache/$username:/home/$username/.sos \
 --mountOpt "mode=r" "mode=rw"  \
 --cwd "/home/$username/data" \
 --image ghcr.io/cumc/pecotmr_docker:latest \
 --entrypoint "source /usr/local/bin/_activate_current_env.sh" \
 --env ENV_NAME=pecotmr \
 --imageVolSize 10 \
 --opcenter 54.81.85.209 \
 --download "statfungen/ftp_fgc_xqtl/ROSMAP/genotype/analysis_ready/:/home/$username/data" \
 --upload /home/$username/output:statfungen/ftp_fgc_xqtl/ \
 --no-fail-fast \
 --volMount 60:/home/$username/data
```

Here, 

- `-c 2` and `-m 16` specifies that the VM should have 2 CPU threads and 16GB of memory.
- `--job-size 100` will split commands per line within `commands_to_submit.txt` into batches, each batch has at most 100 commands.
- `--mount` includes two folders: the AWS folder `s3://statfungen/ftp_fgc_xql` is mounted to the VM as `~/data`; the AWS folder `s3://statfungen/ftp_fgc_xqtl/sos_cache/aw3600` is mounted to the VM as `~/.sos`.
- `--mountOpts` specifies "mode=r" for the first folder that mounts it as read-only to the analysis command. That means the analysis command cannot directly change or add anything to `~/data` folder in the VM. The second folder is mounted with "mode=rw", that is, the analysis command can write into the `~/.sos` folder in the VM.
- `--env`, `--entrypoint`, `--image` and  `--imageVolSize` options are specific to how our docker image `ghcr.io/cumc/pecotmr_docker` is configured to work with the VM.  
- `--download` specifies the folder or files inside of the S3 bucket that we would like to download to the VM, at the begin of the analysis. If any data has been downloaded using this command, you should update the file paths in the 'commands_to_submit.txt' file accordingly. For instance, if we downloaded genotype data from `statfungen/ftp_fgc_xqtl/ROSMAP/genotype/analysis_ready/` to the VM at `/home/$username/data`, which is also the current working directory (cwd), then the genotype data path in your 'commands_to_submit.txt' should be specified as `./`.
- `--upload` specifies the folder inside of the VM that we would like to upload to the S3 bucket, at the end of the analysis. In this case, we always write the results to a folder called `~/output` inside of the VM, and we upload it to S3 at the end. Alternatively, it is also possible to mount a folder from S3 to the VM with "mode=rw" so we can directly write the outputs to that folder as they are generated. **The `--upload` approach would work the best if the job is I/O intensive; otherwise, it would be more robust to directly mount from S3 and write the output there**.

- `--no-fail-fast` when this switch is turned on, all commands in a batch will be executed regardless if the previous ones failed or succeeded. 
- `--volMount` when downloading data from an S3 bucket instead of using direct mounts, ensure you allocate sufficient storage space to the destination path using the following command format: <size>:<folder> where 'size' represents the storage size in GB, and 'folder' is the destination path. For example: `60:/home/$username/data`."

To test this for yourself without submitting the job, please add `--dryrun` to the end of the command (eg right after `--no-fail-fast`) and run on your computer. You should find a file called `commands_to_submit_1.mmjob.sh` you can take a look at it to see the actual script that will be executed on the VM.
