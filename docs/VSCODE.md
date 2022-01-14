# VSCode hints

## Attaching to Docker
1. Install VSCode Docker extension.
2. `Shift-Command-P` -> `Preferences: Open Settings (JSON)`
3. Add `"docker.host": "tcp://localhost:23750"`
4. Forward the port using `ssh -N -L localhost:23750:/var/run/docker.sock <user>@<server>`
5. Go to local VSCode client instance and look into Docker extenstion

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
