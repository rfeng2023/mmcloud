# MM cloud instructions

Written by Ru Feng, Oct 2023

## **Questions Oct 12th 2023**


1. Could you please review each step in the tutorial provided and correct any inaccuracies? I've made several adjustments based on my own research and recollections from our Zoom meetings, but there might be some missing or incomplete steps, especially in sections marked with "FIXME".

2. I managed to follow the tutorial up to step 5. However, I'm uncertain about what happens with the `run_job.sh` scripts once they're uploaded to S3. Specifically, how are the `susieR` scripts we provided executed?

3. Based on the final information given, does it indicate that only the scripts have been successfully uploaded? So what is the output you supposed on step 6 and step7?

4. Should I also transfer the protocol data to S3? I noticed that I haven't uploaded any data to `s3://test-rf-oct-cu/test`. 

5. Given our use of the SoS workflow system, Step 5 in the instructions may not be entirely relevant, correct? SoS should inherently handle parallel job submissions. How is this achieved in our setup?
   
6. Regarding the term `$AWS_REGION`, is it meant to denote geographical regions on AWS (us-east-1)?


## **1. Download AWS CLI tools**
    (Linux/Windows/Mac) https://docs.aws.amazon.com/cli/latest/userguide/gteting-started-install.html
   If you are Mac user, you can use to install AWS CLI tools.
   ```
   curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
   sudo installer -pkg AWSCLIV2.pkg -target /
   ```
   After you see `installer: The install was successful.`, check if it was installed successfully with 
   ```
   which aws
   aws --version
   ```






## **2. Create S3 Storage Resource and Upload Data to AWS**
### **FIXME:2.1 is a GUI instructions for now, should be completed by CLI**
### **2.1 Setting Up Your IAW User and Account**

- Log into AWS Console:
  - Navigate to [AWS Console](https://aws.amazon.com/).
  - Sign up for a root AWS account if you're new, else log in.

- Search for IAW:
  - After logging in, search for "IAW" using the top search bar.

- Manage Access Keys:
  - Find "Security recommendations" on the IAW dashboard.
  - Click "Manage access keys".

- Create an Access Key:
  - Go to the "Access keys" section.
  - Select "Create access key".

- Retrieve Your Access Key and Secret Access Key:
  - A dialogue will show your Access Key ID and Secret Access Key.
  - Check the box, then click "Next".
  - Download a copy of these keys for safekeeping (optional).

- Configure AWS CLI:
  - Run the following in your terminal:
    ```bash
    aws configure
    ```
  - Provide:
    - Your Access Key ID and Secret Access Key.
    - Region: `us-east-1`.
    - Output format (e.g., `yaml`).

### **2.2 Create an S3 Bucket**

To create an S3 bucket, ensure your `$S3_BUCKET` name is globally unique and in lowercase. Also, set `$AWS_REGION` to `us-east-1`. For example:
```bash
aws s3api create-bucket --bucket $S3_BUCKET --region $AWS_REGION
 # Example:
aws s3api create-bucket --bucket test-rf-oct-cu --region us-east-1
```


### **2.3 Copy Files from Local Directory to S3**

Replace `$DATA_DIR`, `$S3_BUCKET`, and `$AWS_REGION` as needed. 
```bash
aws s3 cp $DATA_DIR s3://$S3_BUCKET/$AWS_REGION --recursive
 # Example:
aws s3 cp /Users/carol/Desktop/CUIMC/AWS/aws-test s3://test-rf-oct-cu/us-east-1 --recursive
```








## **3. Create Job Submission Script for each R Files**

The content of example script `run_job.sh` here:

 - **Prepare Data**: 
   This step is about copying data files from your S3 bucket to the worker node.
   
 - **Run the Test**:
    Execute your R script using the Micromamba command.
   
 - **Upload the Results**:
    After the job completion, copy results from the worker node back to your S3 bucket.

**Important**: 
- Within your `run_job.sh` script, make sure you update the `S3_BUCKET` variable to match the name of your S3 bucket:
  ```bash
  S3_BUCKET="s3://test-rf-oct-cu/test"
  ```







## **4. Set Up and Use Float Submit Commands**

Before submitting jobs, you'll need to set up and configure float for your environment. Here's how you can do that:
### **FIXME: add how to set up an op_center here, the step 1 in this [GUI tutorial](https://hackmd.io/@speri/rkmPkmP52#1-Launch-EC2-Instance) is nice but it would be better if you have a CLI instructions**
### **4.1 Download Float from the Operation Center:**

   ```bash
   wget https://<op_center_ip_address>/float --no-check-certificate
   # Example using an IP address:
   wget https://54.81.85.209/float --no-check-certificate
   ```

### **4.2 Move and Grant Execution Rights to Float:**

   ```bash
   sudo mv float /usr/local/bin/
   sudo chmod +x /usr/local/bin/float
   ```

### **4.3 Addressing Mac Security Settings (Optional: For Mac Users):**

If you are using a Mac, float might be blocked due to your security settings. Follow these steps to address it:

   - Open 'System Preferences'.
   - Navigate to 'Security & Privacy'.
   - Under the 'General' tab, you'll see a message about Float being blocked. Click on 'Allow' or any similar option that grants permission.

### **4.4 Rename Float to Avoid Name Conflicts (Optional, but would change your float name in downstream instruction and the future work):**

If there's an existing application or command named `float`, rename the downloaded `float` to avoid conflicts:

   ```bash
   mv /usr/local/bin/float /usr/local/bin/mmfloat
   ```

### **4.5 Log in to Float:**

Use the username `admin` and password `memverge`:

   ```bash
   mmfloat login -a /<op_center_ip_address>
   # Example using an IP address:
   mmfloat login -a 54.81.85.209
   ```

### **4.6 Create and Execute Float Submit Commands:**

This example command submits the `stephenslab_docker` container image with the `run_job.sh` job script. The job will have access to 2 CPUs, 8GB of Memory, and 10GB of EBS storage mounted on `/home/jovyan/aws/data`. Ensure you run this command in the directory where your data resides:

   ```bash
   mmfloat submit -i ghcr.io/cumc/stephenslab_docker -j run_job.sh -c 2 -m 8 --dataVolume "[size=10]:/home/jovyan/AWS/data"
   ```
`/home/jovyan/AWS/data` is the work dir of your job environment in your op_center



## **5. Submit Multiple Jobs Using Job Queue**

To efficiently manage and execute a high number of tasks, it's often useful to submit multiple jobs at once. Here's how you can set this up:

### **5.1 Create Multiple Job Scripts:**

Based on your requirements, you may have different scripts to run. For this example, let's assume you need multiple `run_job.sh` files with varying R script names.

- Repeat steps from sections 3 and 4 to create multiple `run_job.sh` files.

- Generate a master script named run_multiple_jobs.sh that compiles all the mmfloat submit commands. The various run_job.sh scripts differ only in the specific R script they execute, which carries out the actual analysis :

    ```bash
    echo 'mmfloat submit -i ghcr.io/cumc/stephenslab_docker -j run_job.sh -c 2 -m 8 --dataVolume "[size=10]:/home/jovyan/AWS/data"' > run_multiple_jobs.sh
    echo 'mmfloat submit -i ghcr.io/cumc/stephenslab_docker -j run_job1.sh -c 2 -m 8 --dataVolume "[size=10]:/home/jovyan/AWS/data"' >> run_multiple_jobs.sh
    echo 'mmfloat submit -i ghcr.io/cumc/stephenslab_docker -j run_job2.sh -c 2 -m 8 --dataVolume "[size=10]:/home/jovyan/AWS/data"' >> run_multiple_jobs.sh
    ```

### **5.2 Use Job Manager to Submit Jobs in Bulk:**

Once you have your job scripts ready, you can use `jobmanager.sh` to submit them all.

- Ensure that you've edited the `jobmanager.sh` script to set `FLOAT="mmfloat"` and `OPCENTER=<op_center_ip_address>` (example:`OPCENTER="54.81.85.209"`).

- Give execution permissions to the scripts and then use `jobmanager-2.sh` to manage and submit the jobs:

    ```bash
    chmod +x run_multiple_jobs.sh ./jobmanager-2.sh
    ./jobmanager-2.sh -f run_multiple_jobs.sh -q 30 
    ```

### **FIXME: After executing the above commands, you might see the message: `2023-10-12 23:05:39 INFO: Job queue is full, check again in 5 seconds`. What does that indicate?**
The final output of this step is `2023-10-12 23:20:38 INFO: All jobs submitted`

## **6. Download Job Results**

After submitting your jobs and once they are complete, you'll likely want to retrieve the results stored on S3 to your local machine. Here's how you can do that:
### **FIXME: please help to confirm this line is corrector not. The $DATA_DIR is showing in S3?and it always complainning `Unknown options: –-recursive`**


Ensure you've set or replaced the values for `$S3_BUCKET` and `$DATA_DIR` with their appropriate values. The basic structure of the command is:

```bash
aws s3 cp s3://$S3_BUCKET/$DATA_DIR/output $DATA_DIR/output --recursive
Example: 
aws s3 cp s3://test-rf-oct-cu/aws-test/output /Users/carol/Desktop/CUIMC/AWS/aws-test/output --recursive
```

## **7. Clean up S3 buckets Example (have not tried yet)**
```
aws s3 rm s3://$S3_BUCKET --recursive aws s3 rb s3://$S3_BUCKET
```




