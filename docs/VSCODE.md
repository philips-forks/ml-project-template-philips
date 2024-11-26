# VSCode Remote devevelpment in Docker containers

## Attaching to a container that is running on a local machine

1. Install [Docker extension](https://code.visualstudio.com/docs/containers/overview).
1. Open Docker Extension tab and find your container or press Shift+P and type `> Dev Containers: Attach to Running Container...
1. Open `/code` folder.
1. Voilà!

## Attaching to a container that is running on a remote server

1. Install [Remote Development](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack) extension pack
1. Connect to machine where the docker container is running with SSH:
    - Check >< icon in the bottom left corner of the app or press Shift+P and type `> Remote-SSH: Connect to Host...`
    - Select the host with the running container (to avoid typing password on every login, google for _ssh host alias_ and _ssh pubkey authentication_ )
1. Install [Docker extension](https://code.visualstudio.com/docs/containers/overview) on remote VScode instance (got to Extensions and type Docker)
1. Open Docker Extension tab and find your container or press Shift+P and type `> Dev Containers: Attach to Running Container...
1. Open `/code` folder.
1. Voilà!

## OLD INSTRUCTIONS

## Attaching to Docker run locally

1. Install VSCode [Docker extension](https://code.visualstudio.com/docs/containers/overview).
1. `Shift-Command-P` -> `Preferences: Open Settings (JSON)`
    - In Windows check "Settings -> General -> Expose daemon on tcp://localhost:2375 without TLS" and add `"docker.host": "tcp://localhost:2375"` into VSCode preferences
    - In Linux:
        - `"docker.host": "/var/run/docker.sock"`

## Attaching to Docker run remotely

1. Install VSCode [Docker extension](https://code.visualstudio.com/docs/containers/overview).
2. `Shift-Command-P` -> `Preferences: Open Settings (JSON)`
3. Add `"docker.host": "tcp://localhost:23750"`
4. Forward the port using `ssh -N -L localhost:23750:/var/run/docker.sock <user>@<server>`

-   alternatively you can set port forwarding setting in the `~/.ssh/config`:

```bash
Host server-alias
    Hostname server.ip.add.ress
    User user_on_server
    # create .key file with ssh-keygen
    IdentityFile ~/.ssh/server.key
    # Forward Jupyter, Tenorboard and SSH ports if needed.
    # Local port localhost:9999 is forwarded to server's localhost:8888.
    LocalForward 9999 127.0.0.1:8888  # you define remote ports (here 8888) on the docker_start.sh
    LocalForward 9009 127.0.0.1:6006
    LocalForward 2222 127.0.0.1:22
    # Forward Docker host port to srever's docker host port.
    LocalForward 23750 /var/run/docker.sock
```

When created, you will be able to connect to the sever with `ssh server-alias` command.

6. Forward the port, go to local VSCode client instance and look into Docker extension
   ![image](https://user-images.githubusercontent.com/22550252/154921162-e0d026be-dea8-4739-ae23-6b723c1cfbfa.png)

7. If port 23750 is used, you should change it in VSCode settings and port forwarding setting to any other arbitrary unused port.

## Default VSCode remote instance extensions

If you have VSCode extesions to install in every container follow:
https://code.visualstudio.com/docs/remote/containers#_always-installed-extensions  
My choice is:

    "remote.containers.defaultExtensions": [
        "eamodio.gitlens",
        "mhutchie.git-graph",
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-toolsai.jupyter",
        "ms-toolsai.jupyter-keymap",
        "ms-toolsai.jupyter-renderers",
        "njpwerner.autodocstring",
    ],
