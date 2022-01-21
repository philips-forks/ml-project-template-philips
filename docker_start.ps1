# Read default image name from build output or manual input
$docker_image_name = Get-Content ".docker_image_name"
$docker_image_name_input = Read-Host "Image [$docker_image_name]"
$docker_image_name = ($docker_image_name, $docker_image_name_input)[[bool]$docker_image_name_input]

# Prompt for workspace folder
$ws_dump = Get-Content ".ws_path"
$ws = Read-Host "Absolute path to project workspace folder [$ws_dump]"
$ws = ($ws_dump, $ws)[[bool]$ws]
if ($ws) 
{
    Write-Output $ws | Out-File ".ws_path" -Encoding ASCII
}

# Prompt for custom container name
$container_name=$docker_image_name.replace(':', '_')
$container_name_input = Read-Host "Container name [$docker_image_name]"
$container_name = ($container_name, $container_name_input)[[bool]$container_name_input]

# Prompt for GPUS visible in container
$gpus_prompt = Read-Host "GPUs [all]"
$gpus_prompt = ("all", $gpus_prompt)[[bool]$gpus_prompt]
$gpus = '"device=str"'.replace('str',$gpus_prompt)

# Prompt for host Jupyter port
$jupyter_port = Read-Host "Jupyter port [8888]"
$jupyter_port = (8888, $jupyter_port)[[bool]$jupyter_port]

docker run --rm --gpus ${gpus} -d -v ${PWD}:/code -v ${ws}:/ws -p ${jupyter_port}:8888 --name $container_name $docker_image_name

echo ""
echo "- Jupyter Lab is now available at: localhost:$jupyter_port/lab" 
echo "- Jupyter Notebook is available at: localhost:$jupyter_port/tree"
echo ""
echo "- Inspect the container: docker exec -it $container_name bash"
echo "- Inspect the container and install packages: docker exec -it --user=root $container_name bash"
echo ""
echo "- Stop the container: docker stop $container_name"
echo ""
if ($ws) 
{
    echo "- Inside the container $ws will be available at /ws" 
}
Write-Output ""
Read-Host -Prompt "Press Enter to exit"
