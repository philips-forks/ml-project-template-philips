#!/bin/bash
echo -n Enter a Password for Jupyter:
read -s password
echo $password > .jupyter_password

docker build -t template-ml-project --build-arg username=$(whoami) --build-arg uid=$(id -u) .
