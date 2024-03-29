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
-  statfungen/ftp_fgc_xqtl/sos_cache/$username:/home/$username/.sos \
-  statfungen/ftp_fgc_xqtl/analysis_result/finemapping_twas:/home/$username/output \
 --mountOpt "mode=r" "mode=rw" "mode=rw" \
 --cwd "/home/$username/data" \
 --image ghcr.io/cumc/pecotmr_docker:latest \
 --entrypoint "source /usr/local/bin/_activate_current_env.sh" \
 --env ENV_NAME=pecotmr \
 --imageVolSize 10 \
 --opcenter 23.22.157.8 \
 --download "statfungen/ftp_fgc_xqtl/ROSMAP/genotype/analysis_ready/geno_by_chrom/:/home/$username/input/" \
 --download-include "ROSMAP_NIA_WGS.leftnorm.bcftools_qc.plink_qc.1.*" \
 --ebs-mount "/home/$username/input=60" \
 --no-fail-fast  
```

Here, 

- `-c 2` and `-m 16` specifies that the VM should have 2 CPU threads and 16GB of memory.
- `--job-size 100` will split commands per line within `commands_to_submit.txt` into batches, each batch has at most 100 commands.
- `--mount` includes three folders: the AWS folder `s3://statfungen/ftp_fgc_xql` is mounted to the VM as `~/data`; the AWS folder `s3://statfungen/ftp_fgc_xqtl/sos_cache/aw3600` is mounted to the VM as `~/.sos`; the AWS folder `statfungen/ftp_fgc_xqtl/analysis_result/finemapping_twas` is mounted to the VM as `~/output`.
- `--mountOpts` specifies "mode=r" for the first folder that mounts it as read-only to the analysis command. That means the analysis command cannot directly change or add anything to `~/data` folder in the VM. The second folder is mounted with "mode=rw", that is, the analysis command can write into the `~/.sos` folder in the VM.The third folder is mounted with "mode=rw", so we can directly write the outputs to that folder as they are generated.
- `--env`, `--entrypoint`, `--image` and  `--imageVolSize` options are specific to how our docker image `ghcr.io/cumc/pecotmr_docker` is configured to work with the VM.  
- `--download` specifies the folder inside of the S3 bucket that we would like to download to the VM, at the begin of the analysis. If any data has been downloaded using this command, you should update the file paths in the 'commands_to_submit.txt' file accordingly. And **add `/` after the local folder in download** (because we want to download into a folder). For instance, if we downloaded genotype data from `statfungen/ftp_fgc_xqtl/ROSMAP/genotype/analysis_ready/geno_by_chrom/` to the VM at `/home/$username/input/`, then the genotype data path in your 'commands_to_submit.txt' should be specified as `../input`.
- `--download-include` should be used to specify the prefix or suffix of files you want to download from S3 bucket. 
- `--ebs-mount` Mount a dedicated local EBS volume to the VM instance. When downloading data from an S3 bucket instead of using direct mounts, ensure you allocate sufficient storage space to the destination path by mounting a dedicated EBS volume. It must be different from the path in `--mount` which mounts a folder on the S3 bucket. 
- `--no-fail-fast` when this switch is turned on, all commands in a batch will be executed regardless if the previous ones failed or succeeded. 
To test this for yourself without submitting the job, please add `--dryrun` to the end of the command (eg right after `--no-fail-fast`) and run on your computer. You should find a file called `commands_to_submit_1.mmjob.sh` you can take a look at it to see the actual script that will be executed on the VM.


## Example `jupyter_setup.sh` command
```bash
 bash jupyter_setup.sh -u <float_user> -p <password> 
```

The parameters including:
- `-u|--user` user name for your float account
- `-p|--password` password for your float account
- `-o|--OP_IP` the IP address for your opcenter, default is `54.81.85.209`
- `-dv|--dataVolume` to choose mount to S3 or not, the option is `yes|no`, default is `yes`
- `-s3|--s3_path` data path on S3 bucket would be mountted to VM, default is `s3://statfungen/ftp_fgc_xqtl/`
- `-vm|--VM_path` the VM path would be mountted to S3 bucket, default is `/data/`
- `-i|--image` image for jupyter notebook, default is `sos2:latest`
- `-c|--core` default is `4`
- `-m|--mem` default is `16`
- `-pub|--publish` default is `8888:8888`
- `-sg|--securityGroup` default

## Example `hpc_jobman.sh` command

This is designed for submitting jobs to our HPC.

```
bash src/hpc_jobman.sh commands_to_submit.txt \
   -c 3 -m 32 --cwd ~/output \
   --walltime 40:00:00 --queue csg.q \
   --entrypoint "source ~/mamba_activate.sh" \
   --job-size 3 --job-name susie_rss_gwas \
   --no-fail-fast --dryrun 
```

run the example command exactly as is, on your Mac is fine, or HPC. You should see screen output like this:

```
#-------------
qsub /home/gw/Downloads/commands_to_submit_0.mmjob.sh
```

check the contents of `commands_to_submit_0.mmjob.sh` to understand what it is. Then you can use this for analysis on the cluster to submit eg 1300 jobs. To do so, you can put `--job-size 20`  so you will submit 1300 / 20 = 65 jobs. Each of these jobs will use 3 CPU and 32 G of memory, which you can change. If you use multiple CPU, the jobs will be running in parallel by batches of size specified by `--parallel-commands`, default value set to `-c`. 

Once you are comfortable with the outcome of the `--dryrun`, you can remove `--dryrun` and run on the HPC, which will submit all the jobs.
