Write-Output "Hi, let's set up your project."

$curdir = Split-Path -Path $PSScriptRoot -Leaf
$docker_image_name = Read-Host "Set up docker image name[:tag] [$($curdir)]"
$docker_image_name = ($curdir, $docker_image_name)[[bool]$docker_image_name]

$pwd_string = Read-Host "Set up password for Jupyter"

Write-Output $docker_image_name | Out-File ".docker_image_name" -Encoding ASCII
Write-Output $pwd_string | Out-File ".jupyter_password" -Encoding ASCII

docker build -t $docker_image_name .
