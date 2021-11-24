# Use GPU with docker on Windows

Since November 2021 Windows 10 supports CUDA under WSL 2 by default, without joining Windows Insiders program. For Windows 11 you can skip the step 1.

1. On Windows 10 check the latest updates. You need Build 19044.1263 or higher. You can check your build version number by running `winver` via the Run command (Windows logo key + R)
2. Install CUDA-enabled driver for WSL: https://developer.nvidia.com/cuda/wsl
3. Install WSL 2: https://docs.microsoft.com/en-us/windows/wsl/install
4. Install Docker Desktop: https://docs.docker.com/desktop/windows/install/

Source: https://docs.microsoft.com/en-us/windows/ai/directml/gpu-cuda-in-wsl
