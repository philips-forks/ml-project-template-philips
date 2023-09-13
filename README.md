# Machine learning project template
This template was prepared to facilitate the routine of Docker image preparation for a typical deep learning project. Core idea of this template is usability. You need to do just a few steps, and you are ready for running your experiments!

## Requirements:
**Linux:**
* [Docker with GPU support on Linux](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
* Optionally: [Rootless Docker](https://docs.docker.com/engine/security/rootless/)

**Windows:**
* [Docker with GPU support on Windows 10/11](./docs/WINDOWS_DOCKER_GPU.md)

## Quick start
1. **Clone this repo:** `git clone --recursive git@github.com:philips-internal/*.git`
1. **Add proxy settings** into the `~/.docker/config.json`:

        {
            "proxies": {
                "default": {
                    "httpProxy": "http://address.proxy.com:8888/",
                    "httpsProxy": "http://address.proxy.com:8888/",
                    "noProxy": "localhost,127.0.0.1"
                }
            }
        }
1. **Define dependencies** in the `environment.yaml` and `requirements.txt`
1. **Add planned packages**  into the `./src` dir. After the build you can import this module in python. You can add as many modules in `./src` as you want **before the build**. Do not forget, that each module should include `__init__.py` to be taken into account.
1. **Add pip-installable packages** into the `./libs`. They will be installed during the build with `pip install -e <lib>` and can be imported in python directly.
1. **Build image:** `bash docker_build.sh`.
    * To avoid an interactive session you can provide the following arguments in the command: 
    
        ```bash
        bash docker_build.sh \
            --docker_image_name ml-project-template:tagged \
            --jupyter_password JUPYTER_PASSWORD \
            --ssh_password SSH_PASSWORD
        ```
7. **Start a container:** `bash docker_start_interactive.sh`
    * You will be asked to define IMAGE_NAME, CONTAINER_NAME, WORKSPACE_DIR, JUPYTER_PORT, TENSORBOARD_PORT, SSH_PORT. 
    * The ports you are asked to set up are the **host** ports, advice available ports to your system admin if you work on remote server, or specify free ports if you work on local machine. 
    * Workspace dir is a directory on the host machine, provide a full path. 
    * If you want to define additional docker run parameters, just provide them after the command. For example: `bash docker_start_interactive.sh -p 9898:9898`

8. After image has been started: 
    - Jupyter Lab is available at: `http://localhost:<JUPYTER_PORT>/lab  `
    - Jupyter Notebook is available at: `http://localhost:<JUPYTER_PORT>/tree`
    - Tensorboard is available at: `http://localhost:<TENSORBOARD_PORT>`, monitoring experiments in $tb.
    - Connect to container via SSH: `ssh -p <SSH_PORT> root@localhost` (if you are under proxy, no connection to outer world => no package installation possible)
    - Inspect the container: `docker exec -it <CONTAINER_NAME> bash` (if you are under proxy, install packages inside in this mode)
    - Stop the container: `docker stop <CONTAINER_HASH>`
    - Inside the container WORKSPACE_DIR will be available at /ws

9. **Connect an IDE** to the running container:
    * VSCode: [Docker with GPU support on Windows 10/11](./docs/VSCODE.md)
    * PyCharm: TBD

10. **Update the image**
     * You can access container by the command: `docker exec -it <CONTAINER_NAME> bash`  
     * Then install as many pip packages as you want (do not forget to add them into `requirements.txt`)  
     * At the end you can update the image with the command: `docker commit --change=CMD ~/init.sh <CONTAINER_NAME> <IMAGE_NAME>`

11. **Share the image**
     * Share the repo and then either build the image on new machine, or compress and decompress the image on a new machine :
     * `docker save <IMAGE_NAME>:latest > my-image.tar`
     * `docker load < my-image.tar`
