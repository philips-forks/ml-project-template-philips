$ErrorActionPreference = "Stop"
Set-Variable HOME "C:\Users\$env:UserName"  -Force

# -------------- Read default image name from build output or manual input --------------
$docker_image_name = Get-Content ".docker_image_name"
$docker_image_name_input = Read-Host "Image [$docker_image_name]"
$docker_image_name = ($docker_image_name, $docker_image_name_input)[[bool]$docker_image_name_input]

# -------------------------- Prompt for custom container name ---------------------------
$container_name=$docker_image_name.replace(':', '_')
$container_name_input = Read-Host "Container name [$docker_image_name]"
$container_name = ($container_name, $container_name_input)[[bool]$container_name_input]

# ----------------------------- Prompt for workspace folder -----------------------------
$ws_dump = Get-Content ".ws_dir"
$ws = Read-Host "Absolute path to project workspace folder [$ws_dump]"
$ws = ($ws_dump, $ws)[[bool]$ws]
if ($ws) 
{
    Write-Output $ws | Out-File ".ws_dir" -Encoding ASCII
}

# ---------------------------- Prompt for tensorboard folder ----------------------------
$tb_dump = Get-Content ".tb_dir"
$tb_dump = ("/ws/experiments", $tb_dump)[[bool]$tb_dump]
$tb = Read-Host "Relative path to the tensorboard logdir [$tb_dump]"
$tb = ($tb_dump, $tb)[[bool]$tb]
if ($tb) 
{
    Write-Output $tb | Out-File ".tb_dir" -Encoding ASCII
}

# ------------------------- Prompt for GPUS visible in container ------------------------
$gpus_prompt = Read-Host "GPUs [all]"
$gpus_prompt = ("all", $gpus_prompt)[[bool]$gpus_prompt]
$gpus = '"device=str"'.replace('str',$gpus_prompt)

# ---------------------------- Prompt for host Jupyter port -----------------------------
$jupyter_port = Read-Host "Jupyter port [8888]"
$jupyter_port = (8888, $jupyter_port)[[bool]$jupyter_port]

# -------------------------- Prompt for host TensorBoard port ---------------------------
$tb_port = Read-Host "Tensorboard port [6006]"
$tb_port = (6006, $tb_port)[[bool]$tb_port]

# ------------------------------ Prompt for host SSH port -------------------------------
$ssh_port = Read-Host "SSH port [22]"
$ssh_port = (22, $ssh_port)[[bool]$ssh_port]

while ($true)
{
    $rc = Read-Host "Restart container on reboot? [Y/n]"
    if ($rc -eq "Y" -or $rc -eq "")
    {
        docker run `
            --restart unless-stopped `
            --gpus $gpus `
            -d `
            -v ${HOME}/.ssh:/home/$env:UserName/.ssh `
            -v ${PWD}:/code `
            -v ${ws}:/ws `
            --shm-size 32G `
            -p 127.0.0.1:${jupyter_port}:8888 `
            -p 127.0.0.1:${tb_port}:6006 `
            -p 127.0.0.1:${ssh_port}:22 `
            -e TB_DIR=${tb} `
            --name $container_name `
            $docker_image_name
        docker exec --user=root $container_name service ssh start
        break
    }

    elseif ( $rc -eq "n" )
    {
        docker run `
            --rm `
            --gpus $gpus `
            -d `
            -v ${HOME}/.ssh:/home/$env:UserName/.ssh `
            -v ${PWD}:/code `
            -v ${ws}:/ws `
            --shm-size 32G `
            -p 127.0.0.1:${jupyter_port}:8888 `
            -p 127.0.0.1:${tb_port}:6006 `
            -p 127.0.0.1:${ssh_port}:22 `
            -e TB_DIR=${tb} `
            --name $container_name `
            $docker_image_name
        docker exec --user=root $container_name service ssh start
        break
    }

    else
    {
        "Provide Y or n"
    }
}


echo "------------------------ CONTAINER IS SUCCESSFULLY STARTED -----------------------"
echo "- Jupyter Lab is now available at: localhost:$jupyter_port/lab" 
echo "- Jupyter Notebook is available at: localhost:$jupyter_port/tree"
echo ""
echo "- Connect to container via SSH: ssh -p $ssh_port $env:UserName@localhost"
echo "- Inspect the container: docker exec -it $container_name bash"
echo "- Update the image: docker commit --change='CMD ~/init.sh' updated_container_name_or_hash $docker_image_name"
echo ""
echo "- Stop the container: docker stop $container_name"
echo ""
if ($ws) 
{
    echo "- Inside the container $ws will be available at /ws"
    echo "- Tensorboard is available at: localhost:$tb_port, monitoring experiments in $tb."
}
Write-Output ""
Read-Host -Prompt "Press Enter to exit"
