# Machine learning project template
![11978-91-1536580089-2](https://user-images.githubusercontent.com/22550252/138448732-e867678f-c845-4428-a482-170412d08486.png)



## Requirements
* Docker version 20.10.8

## Installation

0. Edit your requirements in `environment.yaml`

2. Rename: 
* `template-ml-project -> your-project-name`
* `template_ml_project -> your_project_name`

in the folowing files:
```
- docker_build.sh
- docker_build.ps1
- docker_run.sh
- docker_run.ps1
- setup.py
```
2. Build
* In Linux shell: `./docker_build.sh`
* In Windows PowerShell: `docker_build.ps1`

3. Run
* In Linux shell: `./docker_run.sh /path/to/data/folder`
* In Windows PowerShell: `.\docker_run.ps1 "D:\Path\To\Data Folder"`

Inside the container data folder will be available at `/ws`

## Project structure and philosophy behind

The idea behind this template is to be able to store lightweight code and heavy model artifacts and data in different places.

```
  # Code folder
  template-ml-project/
  ├── template_ml_project
      └── __init__.py
  ├── notebooks
  │   └── notebook_example.ipynb
  ├── Dockerfile
  ├── README.md
  ├── docker_build.ps1
  ├── docker_build.sh
  ├── docker_run.ps1
  ├── docker_run.sh
  ├── environment.yaml
  ├── set_jupyter_password.py
  └── setup.py
  
  # Workspace folder
  template-ml-project-workspace/
  ├── data_raw
      └── file.dcm
  ├── data_processed
      └── file.npz
  ├── artifacts
      ├── segmentation_masks
      |   └── mask.jpg
      └── checkpoints
  ├── set_jupyter_password.py
  └── setup.py
 ```
