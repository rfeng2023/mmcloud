# Cloud computing setup: MemVerge + AWS

## Download and use MemVerge toolkit from container images

We recommend using `singularity` to run MemVerge and AWS tools. On conventional Linux-based HPC, `singularity` should be available. If you want to manage your computing from a local computer, [here is a setup guide for Mac users](https://wanggroup.org/productivity_tips/macos-setup#singularity-on-mac).

First, download the singularity image that contains MemVerge and AWS related tools:

```
singularity pull mmc_utils.sif docker://frankkoumv/mmc:mmc-utils
```

When an update for this image is available, you can simply delete it and pull again:

```
rm -f mmc_utils.sif
singularity pull mmc_utils.sif docker://frankkoumv/mmc:mmc-utils
```

Here are some command line alias you may want to set in your bash configuration, as shortcut to use tools from `mmc_utils.sif`

*FIXME: test and improve this. for example Mac users may have different alias depending on [how they installed singularity](https://wanggroup.org/productivity_tips/singularity-apple-silicon)*

```
alias aws="singularity exec /path/to/mmc_utils.sif aws"
alias mmfloat="singularity exec /path/to/mmc_utils.sif float"
alias mm_jobman.sh="singularity exec /path/to/mmc_utils.sif mm_jobman.sh"
```

where `/path/to/mmc_utils.sif` is where you save the `mmc_utils.sif` file.

## Data transfer with AWS bucket

### First time user: configure your pre-existing account on project AWS bucket

This assumes that your admin has already an user account on their bucket, with Access Key ID and Secret Access Key for your access to the project AWS bucket. To configure your account from command terminal,

```bash
aws configure
```

You will be prompted to provide these information:

```
AWS Access Key ID [None]:
AWS Secret Access Key [None]: 
Default region name [None]: us-east-1
Default output format [None]: yaml
```

The first two pieces of info should be available from your admin.

### Upload data to pre-existing AWS bucket

This assumes that your admin has already created a storage bucket on AWS, and that you can access it. In this documentation the pre-existing bucket is called `cumc-gao`. You should have your username from your admin.

To copy file eg `$DATA_FILE` to the bucket, 

```
aws s3 cp $DATA_FILE s3://$S3_BUCKET/ 
```

Example:

```
touch test_wiki.txt
aws s3 cp test_wiki.txt s3://cumc-gao/
```

To copy folder `$DATA_DIR` to the bucket,

```
aws s3 cp $DATA_DIR s3://$S3_BUCKET/ 
```

Example:

```
mkdir test_wiki
mv test_wiki.txt test_wiki
aws s3 cp test_wiki s3://cumc-gao/ --recursive
```

Once you completed uploading files to AWS bucket, you are ready to run your analysis through MemVerge.

### Download data from pre-existing AWS bucket

After your analysis is done, it is possible to retrieve the results stored on S3 to your local machine, simply by reversing the command for Upload discussed in the previous section. For example,


```bash
aws s3 cp s3://$S3_BUCKET/$DATA_DIR/output output --recursive
```

### Remove data from AWS buckets

*Warning: think twice before you run it!*

*FIXME: on our end we should set it up such that a user can only remove files they created, not from other people*

```bash
aws s3 rm s3://$S3_BUCKET/$DATA_DIR/cache --recursive
```

### Suggested organization of files in AWS buckets

We recommend that you create a personal folder on the bucket to save data specific to your own tasks (that are not shared with others). For example for user `gaow` on `cumc-gao` bucket, the personal folder should be `s3://cumc-gao/gaow`

*FIXME: provide a command to show users how to create a personal folder*

## Submit computing jobs through MemVerge CLI toolkit

### First time user: configure your pre-existing MemVerge account 

This assumes that your admin has already created a MemVerge account for you, with a username and password provided. To login, 

```bash
mmfloat login -u <username> -a <op_center_ip_address>
```

Example:

```bash
mmfloat login -u gaow -a 54.81.85.209
```

### Execute a simple command through pre-configured docker containers

Here is an example running a simple bash script `susie_example.sh` using `stephenslab_docker` image file available from online docker image repositories. The `susie_example.sh` has these contents (copied from running `?susieR::susie` in R terminal):

```bash
#!/bin/bash
# run_r_code.sh

Rscript - << 'EOF'
# susie example
set.seed(1)
n = 1000
p = 1000
beta = rep(0,p)
beta[1:4] = 1
X = matrix(rnorm(n*p),nrow = n,ncol = p)
X = scale(X,center = TRUE,scale = TRUE)
y = drop(X %*% beta + rnorm(n))
res = susie(X,y,L = 10)
saveRDS(res, "susie_example_result.rds")
EOF
```

The command below will submit this bash script to AWS accessing 2 CPUs, 8GB of Memory, and 10GB of EBS storage already mounted on `/home/jovyan/aws/data` -- this is the work dir of your job environment in your MemVerge OpCenter. *FIXME: this last sentence is not clear. how do i know that this folder /home/jovyan/aws/data is mounted? Do i need to customize it? if so, to what? Please clarify the last sentence*

```bash
mmfloat submit -i ghcr.io/cumc/stephenslab_docker -j susie_example.sh -c 2 -m 8 --dataVolume "[size=10]:/home/jovyan/AWS/data"
```

*FIXME: I get an error message "Error: Resource not found (code: 1002)"*

### Submit multiple jobs for "embarrassing parallel" processing

For the multiple jobs to submit all at once, we assume that:

1. Each job is one line of bash command
2. Multiple jobs can be executed in parallel
3. All these jobs uses the same CPU and memory resource 


Suppose you have 3 jobs to run in parallel, possibly using different docker images, like this:

```bash
docker run ghcr.io/cumc/stephenslab_docker micromamba run -n stephenslab R --slave -e "print('analysis_1')" > analysis_1.result.txt
docker run ghcr.io/cumc/bioinfo_docker micromamba run -n bioinfo R --slave -e "print('analysis_2')" > analysis_2.result.txt
docker run ghcr.io/cumc/pcatools_docker micromamba run -n pcatools R --slave -e "print('analysis_3')" > analysis_3.result.txt
```

You save these lines to `run_my_job.sh` and use `mm_jobman.sh` to submit them --- `mm_jobman.sh` is a utility script included in the default PATH for executables in the `mm_utils.sif` image. 

```bash
mm_jobman.sh run_my_job.sh \
  -c 2 -m 8 --dataVolume "[size=10]:/home/jovyan/AWS/data" \
  --mount /home/jovyan/AWS/data/:cumc-gaow/gaow/large_folder_that_you_mount_not_copy/ \
  --sync /home/jovyan/TEMP/:cumc-gaow/gaow/small_frequently_used_file_folder_that_you_copy_to_local_VM/ \
  --opcenter 54.81.85.209
```

*FIXME: this does not yet work. I have this in mind for months but what is implemented so far in `jobmanager.sh` is not quite there yet. The procedure now is still complicated. Please consider the above contents as my proposed interface for you new `mm_jobman.sh` program.*


*FIXME: it is also not clear to me how `/home/jovyan/AWS/data` connects to the AWS bucket. Therefore I proposed the volume mounting interface `path1:path2` where the left side of `:` is opcenter data volume, the right side is S3 bucket. Notice also the difference between proposed `--mount` and `--sync`. In the end, we should find the results `analysis_{1,2,3}.result.txt` written into our S3 bucket `cumc-gaow/gaow/large_folder_that_you_mount_not_copy`*

After the job is submitted and being managed, you can check the status using:

```
mmfloat squeue
```

which should show the job ID. The check log files generate for a job, 
  
```
mmfloat log -j <jobID> ls #check log file name 
mmfloat log -j <jobID> cat <logfile> #check log file contents
```

### Download your results to local computer

*You only do this when necessary*

A general discussion of this was covered in section "Data transfer with AWS bucket". Here is an example how you can download the results generated from the test jobs we just discussed:

```
aws s3 cp s3://cumc-gao/gaow ./ --recursive
```

## Notes for Admin

*This section is only relevant to admins. If you are a user you can skip this*

### Setting Up Your IAW User and Account 

This is a one-time job for the system admin, done through GUI)

*FIXME: the approach below will gave every one in the group the full access to the whole bucket, so everyone can read and edit others' file, that would be convenient but also dangerous. Need to manage it better next step*

- Log into AWS Console:
  - Navigate to [AWS Console](https://aws.amazon.com/).
  - Sign up for a root AWS account if you're new, else log in.

- Search for IAW:
  - After logging in, search for "IAW" using the top search bar.

- Creat Group
  - Click "User groups" on the left.
  - Attach "AmazonS3FullAccess" for this group
  - Add Users to this group.

- Add user and set up access key
  - GUI/or maybe for root user (first time to set up the access key) 
    - Add User:
      - Click "Users" on the left and then click "Create user" on the right.
      - Click "Next" following instructions.
    - Manage Access Keys:
      - Find "Security recommendations" on the IAW dashboard.
      - Click "Manage access keys".
    - Create an Access Key:
      - Go to the "Access keys" section.
      - Select "Create access key".
    - Retrieve Your Access Key and Secret Access Key:
      - A dialogue will show your Access Key ID and Secret Access Key.
      - Check the box, then click "Next".
      - Download a copy of these keys for safekeeping.
  - CLI (change to root access)
    ```
     aws iam create-user --user-name YourUserName
     aws iam add-user-to-group --user-name YourUserName --group-name Gao-lab
     aws iam create-access-key --user-name YourUserName
    ```
    copy these keys for safekeeping.
- Configure AWS CLI:
  - Run the following in your terminal:
    ```bash
    aws configure
    ```
  - Provide:
    - Your Access Key ID and Secret Access Key.
    - Region: `us-east-1`.
    - Output format (e.g., `yaml`).

###  Create project S3 Bucket

To create an S3 bucket, ensure your `$S3_BUCKET` name is globally unique and in lowercase. For example:

```bash
aws s3api create-bucket --bucket $S3_BUCKET --region $AWS_REGION
```

Example:

```bash
aws s3api create-bucket --bucket cumc-gao --region us-east-1
```

### MemVerge account management

First, login as admin, 

```bash
mmfloat login -u <admin username> -p <admin passwd> -a /<op_center_ip_address>
```

Then create a new user for example `tom`,

```bash
mmfloat user add tom
```

### Setup MemVerge OpCenter for project

*FIXME: add how to set up an op_center here, the step 1 in this [GUI tutorial](https://hackmd.io/@speri/rkmPkmP52#1-Launch-EC2-Instance) is nice but it would be better if you have a CLI instructions*

*FIXME: [Gao] I don't understand the concept and relevance of OpCenter -- so when you describe how to set it up here, please also give a bit of background and motivation so I (and other future admin) understand it*

## Appendix: AWS and MemVerge Software Installation and Set Up

*You can safely skip this section if you use the docker/singularity image provided by MemVerge, as detailed in the first section of this document. Here we keep these contents as Appendix for book-keeping purpose.*

### AWS CLI tools

(Linux/Windows/Mac) https://docs.aws.amazon.com/cli/latest/userguide/gteting-started-install.html

   - If you are *Mac* user, you can use below commands to install AWS CLI tools.
   ```
   curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
   sudo installer -pkg AWSCLIV2.pkg -target /
   ```
   - If you are *HPC/Linux* user, you can use to install AWS CLI tools (Also add `export PATH=$PATH:/home/<UNI>/.local/bin` in your `~/.bashrc` and don't forget to source it).
   ```
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   ./aws/install -i /home/<UNI>/.local/bin/aws-cli -b /home/<UNI>/.local/bin
   ```
   - If you are *Windows* user, you can open cmd as administrator and use below commands to install AWS CLI tools.
   ```
   msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
   ```

   Check if it was installed successfully with 
   ```
   which aws
   aws --version
   ```

### MemVerge `float` for job submission

#### Download Float from the Operation Center

  - For linux and Mac user
   ```bash
   wget https://<op_center_ip_address>/float --no-check-certificate
   # Example using an IP address:
   wget https://54.81.85.209/float --no-check-certificate
   ```
  - For Windows user, the float file above is not compatible, so you need to access https://54.81.85.209 and manually downloaded the version of the tool specifically for Windows.

Or you can choose to open MMCloud OpCenter and download it with GUI.

#### Move and Make It Executable 
  - For MAC user
   ```bash
   sudo mv float /usr/local/bin/
   sudo chmod +x /usr/local/bin/float
   alias float = /path/to/float_binary/float
   ```
  - For Linux user (Also add `export PATH=$PATH:<PATH>` in your `~/.bashrc` and don't forget to source it), there is a firewall issue on our HPC, so we can not login to float on HPC, the resolution for now is that we can submit data on through HPC, and submit commands/scripts locally (on your laptop or desktop)
  ```
  chmod +x <PATH>/float 
  ```
  - For Windows user:
Files located in C:\Windows\System32 are automatically included in the system's PATH environment variable on Windows. This means that any executable file in this directory can be run from any location in the Command Prompt without specifying the full path to the executable. The System32 directory is a crucial part of the Windows operating system, containing many of its core files and utilities. So, if float.exe is in this directory, you can run it from anywhere in the Command Prompt by just typing `float`.

#### Addressing Mac Security Settings 

*Optional: For Mac Users*

If you are using a Mac, float might be blocked due to your security settings. Follow these steps to address it:

   - Open 'System Preferences'.
   - Navigate to 'Privacy & Security '.
   - Under the 'Security' tab, you'll see a message about Float being blocked. Click on 'Allow Anyway'.

#### Rename Float to Avoid Name Conflicts 

*Optional For Mac Users, but would change your float name in downstream instruction and the future work*

If there's an existing application or command named `float`, rename the downloaded `float` to avoid conflicts:

   ```bash
   mv /usr/local/bin/float /usr/local/bin/mmfloat
   alias mmfloat = /usr/local/bin/mmfloat
   ```