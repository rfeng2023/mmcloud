# How to set up package installation project
This tutorial will go through the setup for the package installation project. For information on how to **use* the setup, [please follow the instructions here](https://wanggroup.org/productivity_tips/mmcloud-interactive).

## Brief Introduction
Using an S3 bucket, we use [`JuiceFS`](https://`JuiceFS`.com/docs/community/introduction/), a high-performance file system, as a layer on top of it in order to have faster storage executions. `JuiceFS` requires a metadata database, which we will use [MemoryDB](https://aws.amazon.com/memorydb/) for. `JuiceFS` will be mounted on the job, and its contents will exist in a bucket `wanggroup`.

The `JuiceFS` mount is subdivided into directories for each user. Further subdirs within each user will include package directories such as `.pixi`, `micromamba`, `.conda`, etc.

The job is submitted with the `docker.io/rfeng2023/pixi-jovyan:latest` image, which is a bare image intended to have additional packages installed. Within the job, each installation dir is symlinked to an equivalent directory on `/home/jovyan`, so that when a user logs in and installs packages, the installation directories such as `/home/jovyan/.pixi` actually link to a location on the `JuiceFS` mount.

## Set up MemoryDB Database

Go to the [MemoryDB](https://us-east-1.console.aws.amazon.com/memorydb) page on the AWS console. Click the orange `Get started` button and choose `Create Cluster`.

Follow the following steps (if not mentioned, leave as default):
* Click `Easy Create`
* Choose `Dev/Test` Configuration
* Give a name
* If this is your first time creating a MemoryDb database, select `Create a new subnet group`. Else, click `Choose existing subnet group` and pick your default subnet group
    * If creating a new subnet group, pick a name and the VPC you use (should just be the main one).
    * For the selected subnets, add as many subnets as you would like. AWS may throw an error when you click `Create` at the end. That is because not all subnets have MemoryDB available to them. If that happens, just remove those subnets from your list and resume

The MemoryDB database will take about 20 minutes to create. You will see an endpoint in the form of
```bash
clustercfg.NAME.*****.memorydb.REGION.amazonaws.com:6379
```

This will be the endpoint you will use in the Host Init script

## Host Init Script

The Host Init script is intended to run on the host machine **before** the container is up. It allows for us to set up `JuiceFS`, which needs to be mounted outside a container.

The items needed in the host init script are as follows:
* Setting PATH and necessary env variables
* Installing `JuiceFS` and necessary packages
* Format `JuiceFS`, using an S3 bucket in the same region as your MemoryDB database and instances
* Mount `JuiceFS`
* Creating directories and setting permissions if dir did not exist

## Bind Mount Script

The bind mount script is essentially the job script for the instance and it runs in the container. `JuiceFS` at this point is mounted to the host AND container. 

The items needed in the bind mount script are as follows:
* Symlinking all package installation directories of the current user to the corresponding on under `/home/jovyan`
* Remaking `.bashrc` and `.profile` and synlinking
* Determining which IDE to run

## Submission Command

The steps in the the [`mm_interactive How-To``](https://wanggroup.org/productivity_tips/mmcloud-interactive) will show how to submit the package installation job. It requires a different set of paramters than other interactive jobs, which is already accounted for if submitting with `mm_interactive.sh`. The special parameters are below (there is no need to submit these - **this is for reference only**):
```bash
--env VMUI=$ide \
--dirMap /mnt/jfs:/mnt/jfs \
--hostInit $script_dir/host_init.sh \
-j $script_dir/bind_mount.sh \
--dataVolume [size=100]:/mnt/jfs_cache"
```

## Current Results

With this setup, it takes 88 minutes to fully run the below command as of 9/6/2024
```bash
curl -fsSL https://raw.githubusercontent.com/gaow/misc/master/bash/pixi/pixi-mamba.sh | bash
```


