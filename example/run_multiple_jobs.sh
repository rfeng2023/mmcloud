mmfloat submit -i ghcr.io/cumc/stephenslab_docker -j run_job.sh -c 2 -m 8 --dataVolume [size=5]:/home/jovyan/AWS/data
mmfloat submit -i ghcr.io/cumc/stephenslab_docker -j run_job1.sh -c 2 -m 8 --dataVolume [size=5]:/home/jovyan/AWS/data
mmfloat submit -i ghcr.io/cumc/stephenslab_docker -j run_job2.sh -c 2 -m 8 --dataVolume [size=5]:/home/jovyan/AWS/data
