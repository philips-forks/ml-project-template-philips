#!/bin/bash
docker run --gpus all -d -v ${PWD}:/code -v $1:/ws -p 8888:8888 --user $(id -u):$(id -u) --name template_ml_project template-ml-project

# OPTIONS DESCRIPTION
# --gpus all: allows access of docker container to your GPU
# -d: runs container in detached mode
# -v ${PWD}:/code: attaches current repository folder to /code in container. 
#                  All changes in the /code folder are changes in the repo folder.
# -v $1:/ws: attaches dir, which is specified in the first arg of docker_run.sh call
#            as /ws folder. All changes in the /ws folder are changes in the attached folder.
# -p 8888:8888: maps host port 8888 to 8888 port in teh container. The former is host port, 
#               the latter is the container port (8888 is default port for jupyter)
# --user $(id -u):$(id -u): run container under current user.
#                           By default container is run by root user, hence all files in 
#                           /code and /ws are created under the root user. Usually this is
#                           undesirable behaviour.
# --name template_ml_project: give a name to the created container