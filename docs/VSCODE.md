# VSCode hints

## Attaching to Docker
1. Install VSCode Docker extension.
2. `Shift-Command-P` -> `Preferences: Open Settings (JSON)`
3. Add `"docker.host": "tcp://localhost:23750"`
4. Forward the port using `ssh -N -L localhost:23750:/var/run/docker.sock <user>@<server>`
    - also you can set port forwarding setting in the `~/.ssh/config`:
```bash
Host server-alias
    Hostname server.ip.add.ress
    User user_on_server
    # create .key file with ssh-keygen
    IdentityFile ~/.ssh/server.key
    # Forward Jupyter port if needed. Local port localhost:9999 is forwarded to server's localhost:8888.
    LocalForward 9999 127.0.0.1:8888
    # Forward Docker host port to srever's docker host port.
    LocalForward 23750 /var/run/docker.sock
 ```
When created, you will be able to connect to the sever with `ssh server-alias` command.

6. Go to local VSCode client instance and look into Docker extenstion

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
