# Build docker image for basic environments


> **Note:** The instructions below works in MacOS and Linux.

*Host Environment MacOS*
```
$ sw_vers
ProductName:		macOS
ProductVersion:		14.4
BuildVersion:		23E214
```

*Host Environment Linux*

```
$ uname -a
Linux cordata 6.5.0-26-generic #26~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Tue Mar 12 10:22:43 UTC 2 x86_64 x86_64 x86_64 GNU/Linux
```

*Docker Versions*
```
$ docker --version
Docker version 24.0.7, build afdd53b
```

Version 26.0.0 also works.


## Build the image

```
$ cd docker
$ tree
.
├── Dockerfile
├── global_packages
├── init.sh
├── python_libs.yml
├── README.md
└── r_libs.yml

1 directory, 6 files
```

Using `docker build` command to build the container. For MacOS, make sure to specify the `--platform` option so that it is built in linux AMD64 architecture. You could tag the container name as you preferred.

```bash
docker build --platform linux/amd64 -t pixi-jovyan -f Dockerfile .
```

Example output:
```
[+] Building 49.4s (11/11) FINISHED                                                                                                            docker:default
 => [internal] load build definition from Dockerfile                                                                                                     0.0s
 => => transferring dockerfile: 613B                                                                                                                     0.0s
 => [internal] load metadata for ghcr.io/prefix-dev/pixi:latest                                                                                          0.3s
 => [internal] load .dockerignore                                                                                                                        0.0s
 => => transferring context: 2B                                                                                                                          0.0s
 => CACHED [1/6] FROM ghcr.io/prefix-dev/pixi:latest@sha256:6527d29c3c8c241021bd9ea787069e899d45ab495ce89cdbeabf1b0ab31a0f04                             0.0s
 => [internal] load build context                                                                                                                        0.0s
 => => transferring context: 337B                                                                                                                        0.0s
 => [2/6] RUN apt-get update && apt-get -y install ca-certificates tzdata libgl1 libgomp1 less tmate                                                    44.9s
 => [3/6] RUN ln -sf /bin/bash /bin/sh                                                                                                                   0.3s 
 => [4/6] RUN useradd --no-log-init --create-home --shell /bin/bash --uid 1000 --no-user-group jovyan                                                    0.5s 
 => [5/6] COPY --chown=jovyan --chmod=755 entrypoint.sh /home/jovyan/entrypoint.sh                                                                       0.0s 
 => [6/6] WORKDIR /home/jovyan                                                                                                                           0.1s 
 => exporting to image                                                                                                                                   3.2s 
 => => exporting layers                                                                                                                                  3.2s 
 => => writing image sha256:6a91f1eda2c964286dfbdc1f430504a63480bd10a4b49e1b1a1be42ca61b608b                                                             0.0s
 => => naming to docker.io/library/pixi-jovyan 
```

Check the image has been built successfully.
```bash
$ docker images | head -2
REPOSITORY                    TAG       IMAGE ID       CREATED              SIZE
pixi-jovyan                   latest    f30c3fd0e1b4   57 seconds ago       384MB
```

## Verify the docker images locally (optional)
You could use `docker run` to validate the image locally.
```
docker run -it --platform linux/amd64 pixi-jovyan
```

Then you will see these in your terminal,

```
To connect to the session locally, run: tmate -S /tmp/tmate-1000/m2tJUM attach
Connecting to ssh.tmate.io...
web session read only: https://tmate.io/t/ro-JZ6aj6ddRu3n7sGYkwfPvZWs8
ssh session read only: ssh ro-JZ6aj6ddRu3n7sGYkwfPvZWs8@nyc1.tmate.io
web session: https://tmate.io/t/FqrdyjWdJv8ScPGeLYhJacYwt
ssh session: ssh FqrdyjWdJv8ScPGeLYhJacYwt@nyc1.tmate.io
```

You can use the `ssh session` to connect to it, by typing the last line of the text above in your terminal. That will take you to an interactive session through your local terminal emulator.

## Push to the dockerhub

For enabling the container image to be pulled by others later, you could push the container image to a public dockerhub.

```
docker tag pixi-jovyan gaow/pixi-jovyan:latest
docker push gaow/pixi-jovyan:latest
```