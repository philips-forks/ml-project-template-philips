# Machine learning project template

This template was prepared to facilitate the routine of Docker image preparation for a typical deep learning project. Core idea of this template is usability. You need to do just a few steps, and you are ready for running your experiments!

## Requirements:

**Linux:**

-   [Docker with GPU support on Linux](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
-   Optionally: [Rootless Docker](https://docs.docker.com/engine/security/rootless/)

**Windows:**

-   [Docker with GPU support on Windows 10/11](./docs/WINDOWS_DOCKER_GPU.md)

## Quick start

> This repo is a template. Do not clone this repo! Instead, create a repo from this template and clone one. All the following instructions given for the inherited repo and not for this template.

1. **Default base image** is `nvcr.io/nvidia/pytorch:XX.XX-py3`. if you would like to use tensorflow, change base image (`nvcr.io/nvidia/tensorflow:XX.XX-tf2-py3` recommended)
1. Rename `./src/mlproject` dir to the name you would like to import with python: `import mlproject`
1. **Python dependencies** are defined in `./pyproject.toml`. In the `project.scripts` section you can also define entrypoint scripts. Check out the file for an example.
1. **You can add submodules** into `./libs` dir. Ones which are python package (can be installed with pip) will be installed into the image.

```bash
$ git submodule add https://example.com/submodule.git ./libs/submodule
```

6.  **A container will serve Jupyter and Tensorflow.** Put your project-related notebooks into `./notebooks`.
1.  **Add proxy settings into the `~/.docker/config.json` if needed:**

        {
            "proxies": {
                "default": {
                    "httpProxy": "http://address.proxy.com:8888/",
                    "httpsProxy": "http://address.proxy.com:8888/",
                    "noProxy": "localhost,127.0.0.1"
                }
            }
        }

1.  **Build the image and follwo the instructions on prompt. Building can take up to 20m:**

```bash
$ ./docker_build.sh
# You can also use non-interactive way:
$ ./docker_build.sh my-project:v1.0 --jupyter-pwd <jupyter_password>
```

9. **Start a conatiner and follow the instructions on prompt:**

```bash
$ ./docker_start.sh
```

10. **Step by step will be asked to provide:**
- IMAGE_NAME:TAG — image to start *(impl. for cases when you might want to start previously built image)*
- CONTAINER_NAME — custom name for the container.
- WORKSPACE_DIR — directory on the host machine where you want to store pre-processed data, training logs, model weights, etc. Inside container will be available in `/ws`.  **Provide an absolute path.**
- DATA_DIR is a directory on the host machine where you keep read-only raw data. Inside container will be available in `/data`. **Provide an absolute path.**
- JUPYTER_PORT and TENSORBOARD_PORT — the **host** ports to bind, check the busy ports with `netstat -tulp | grep LISTEN`.

11. After image has been started:

```
-   Current repo folder is available at /code
-   <WORKSPACE_DIR> is available at /ws
-   <DATA_DIR> is available at /data

-   Jupyter Lab is available at: http://localhost:<JUPYTER_PORT>/lab
-   Tensorboard is available at: http://localhost:<TENSORBOARD_PORT>, monitoring experiments in <WORKSPACE_DIR>/experiments by default.

-   To inspect the container: docker exec -it <CONTAINER_NAME> bash
-   To stop the container: docker stop <CONTAINER_HASH>
```

12. **Connect an IDE** to the running container:

-   VSCode: [Docker with GPU support on Windows 10/11](./docs/VSCODE.md)
-   PyCharm: TBD

13. **Update the image**

-   You can access container by the command: `docker exec -it <CONTAINER_NAME> bash`
-   Then install as many pip packages as you want (do not forget to add them into `pyproject.toml`)
-   At the end you can update the image with the command: `docker commit --change=CMD ~/init.sh <CONTAINER_NAME> <IMAGE_NAME:v2.0>`

14. **Options to share the image**:
- Push to a docker registry:
```bash 
$ docker login <REGISTRY_URL>
$ docker tag <IMAGE_NAME:TAG> <REGISTRY_URL>/<IMAGE_NAME:TAG>
$ docker push <REGISTRY_URL>/<IMAGE_NAME:TAG>
```
- Share the repo and then either build the image on new machine, or compress and decompress the image on a new machine:
```bash 
$ docker save image_name:tag | gzip > output_file.tar.gz
$ docker load < output_file.tar.gz
```
