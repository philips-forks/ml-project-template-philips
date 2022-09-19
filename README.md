# Machine learning project template


## Requirements:
* [Docker with GPU support on Windows 10/11](https://github.com/lobantseff/template-ml-project/blob/master/docs/WINDOWS_DOCKER_GPU.md)
* [Docker with GPU support on Linux](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

## Quick start

1. **Edit project requirements** in `environment.yaml`
1. **If you are under proxy**, do not forget to set up environment proxy variable: `$http_proxy` & `$https_proxy` in Linux and `$env:http_proxy` & `$env:https_proxy` in Windows.
2. **Build:**
* In Linux shell: `bash docker_build.sh`
* In Windows PowerShell: `.\docker_build.ps1` or right-click -> "Run with Powershell"

3. **Start container:**
* In Linux shell: `bash docker_start.sh`
* In Windows PowerShell: `.\docker_start.ps1` or right-click -> "Run with Powershell"

  
**Notes:**
- On Windows machine. If PowerShell says "execution of scripts is disabled on this system", you can  run in powershell with admin rights: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine` to allow scripts execution. But do it with caution, since some scripts can be vulnerable. For the details follow the [link](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.2).
- You can attach VSCode to a running container: [quick tutorial](https://github.com/lobantseff/template-ml-project/blob/master/docs/VSCODE.md), [documentation](https://code.visualstudio.com/docs/remote/containers)
- To commit updates from a running container to the built image use:  
    `docker commit --change='CMD ~/init.sh' updated_container_name_or_hash docker_image_name`  
    (_not recommended as a daily practice, good practice is to update the environment.yaml, requirements.txt or Dockerfile_)

## Project structure and philosophy behind

The idea behind this template is to be able to store lightweight code and heavy model artifacts and data in different places.

```
  # Code folder. Available under `/code` inside the container
  template-ml-project/
  ├── libs/
  |   ├── external_lib_as_submodule1/
  |   └── external_lib_as_submodule1/
  ├── src/
  │   ├── template_ml_project/
  │   │   └── __init__.py
  |   └── template_lib2/
  |       └── __init__.py
  ├── notebooks
  │   └── notebook_example.ipynb
  ├── .gitignore
  ├── Dockerfile
  ├── README.md
  ├── docker_build.ps1
  ├── docker_build.sh
  ├── docker_run.ps1
  ├── docker_run.sh
  ├── environment.yaml
  ├── set_jupyter_password.py
  └── setup.py
  
  # Workspace folder. Available under `/ws` inside the container.
  template-ml-project-workspace/
  ├── data_raw
      └── file.dcm
  ├── data_processed
      └── file.npz
  ├── artifacts
      ├── segmentation_masks
      |   └── mask.jpg
      └── checkpoints
  ├── configs/
  └── etc/
 ```
