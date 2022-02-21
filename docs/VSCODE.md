# VSCode hints

## Attaching to Docker
1. Install VSCode [Docker extension](https://code.visualstudio.com/docs/containers/overview).
2. `Shift-Command-P` -> `Preferences: Open Settings (JSON)`
3. Add `"docker.host": "tcp://localhost:23750"`
4. Forward the port using `ssh -N -L localhost:23750:/var/run/docker.sock <user>@<server>`
- alternatively you can set port forwarding setting in the `~/.ssh/config`:
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

6. SSH to the server, go to local VSCode client instance and look into Docker extenstion
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
