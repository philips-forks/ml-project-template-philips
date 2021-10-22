param([String]$ws="")
docker run --gpus all -d -v ${PWD}:/code -v ${ws}:/ws -p 8888:8888 --name template_ml_project template-ml-project
