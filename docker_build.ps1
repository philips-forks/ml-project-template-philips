Write-Output "Hi, let's set up your project."

$curdir = Split-Path -Path $PSScriptRoot -Leaf
$project_name = Read-Host "Set up docker image name[:tag] [$($curdir)]"
$project_name = ($curdir, $project_name)[[bool]$project_name]

$pwd_string = Read-Host "Set up password for Jupyter"

Write-Output $project_name | Out-File ".docker_image_name" -Encoding ASCII
Write-Output $pwd_string | Out-File ".jupyter_password" -Encoding ASCII

docker build -t $project_name .
