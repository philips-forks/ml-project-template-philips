$pwd_string = Read-Host "Enter a Password for Jupyter"
Write-Output $pwd_string | Out-File ".jupyter_password" -Encoding ASCII

docker build -t template-ml-project .