$ErrorActionPreference = "Stop"

Write-Output "------------------------ Hi, let's set up your project! ------------------------"


# ---------------------------- Prompts to define variables  -----------------------------
$curdir = Split-Path -Path $PSScriptRoot -Leaf
$docker_image_name = Read-Host "Set up docker image name[:tag] [$($curdir)]"
$docker_image_name = ($curdir, $docker_image_name)[[bool]$docker_image_name]

$pwd_string = Read-Host "Set up password for Jupyter"
$ssh_string = Read-Host "Set up password for SSH access"

Write-Output $pwd_string | Out-File ".jupyter_password" -Encoding ASCII
Write-Output $ssh_string | Out-File ".ssh_password" -Encoding ASCII
Write-Output $docker_image_name | Out-File ".docker_image_name" -Encoding ASCII
Write-Output "" | Out-File ".ws_dir" -Encoding ASCII
Write-Output "" | Out-File ".tb_dir" -Encoding ASCII


# ------------------------------------ Build docker -------------------------------------
docker build -t $docker_image_name `
    --build-arg username=$env:UserName `
    --build-arg userpwd=$ssh_string `
    .


# ----- Install user packages from ./src to the container and submodules from ./libs ----
docker run -dt -v ${PWD}:/code --name tmp_container $docker_image_name

foreach ($lib in Get-ChildItem -Directory .\libs\) 
{
    if (Test-Path -Path .\libs\$lib\setup.py)
    {
        Write-Output "Installing $lib"
        docker exec -u root tmp_container pip install  -e /code/libs/$lib/.
    } 
    else 
    {
        Write-Output ".\libs\$lib does not have setup.py file to install."
    }
}
docker exec -u root tmp_container pip install  -e /code/.
docker stop tmp_container
docker commit --change='CMD ~/init.sh' tmp_container $docker_image_name
docker rm tmp_container > $null


Write-Output "------------------ Build successfully finished! --------------------------------"
Write-Output "---- Start the container: .\docker_start.ps1 in Powershell, or right-click on script file -> Run with Powershell ----"
Write-Output ""
Read-Host -Prompt "Press Enter to exit"
