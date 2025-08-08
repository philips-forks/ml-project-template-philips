> ⚠️ IMPORTANT:
>
> This repository is a template. Do not clone it directly!
> Instead, create a new repository based on this template and clone that.
> All instructions provided below apply to your new repository.

# ML Project Template

This template was prepared to facilitate the routine of Docker image preparation for a typical deep learning project. Core idea of this template is usability.

_You need to do just a few steps, and you are ready for running your experiments!_

## 🚀 Quick Initialization

**New to this template?** Run the initialization script first:

```bash
./init.sh
```

This interactive script will:

-   **Rename** the source directory from `mlproject` to your project name
-   **Update** `pyproject.toml` with your project details
-   **Create** a `.env` file with Docker configuration
-   **Configure** default paths for workspace and data directories

The script will prompt you for:

-   **Project name** (must be a valid Python package name)
-   **Description** and **author information**
-   **Docker configuration** (image name, container name, GPUs)
-   **Directory paths** (workspace, data directories)

Example session:

```
Project name (Python package name) [ml-project-template]: my_awesome_project
Project description [A machine learning project]: Computer vision model for device detection
Author name [Your Name]: John Doe
Author email [your.name@example.com]: john.doe@company.com
Docker image name [my-awesome-project:latest]:
Default container name [my-awesome-project.latest.dev]:
...
```

Skip to [Complete Workflow](#complete-workflow) after initialization.

## 📚 Script Help and Options

All scripts support detailed help information:

```bash
./init.sh --help                 # Setup and initialization options
./docker_build.sh --help         # Build configuration options
./docker_dev.sh --help           # Development container options
./docker_train.sh --help         # Training and experiment options
./docker_update.sh --help        # Image update options
./setup_philips_proxy.sh --help  # Helper script to setup Philips Cisco Proxy within the running container
```

Each script supports both **interactive** and **non-interactive** modes, with the latter using command-line arguments or defaults from the `.env` file.

## Requirements:

**Linux:**

-   [Docker with GPU support on Linux](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
-   Optionally: [Rootless Docker](https://docs.docker.com/engine/security/rootless/)

**Windows:**

-   [Docker with GPU support on Windows 10/11](./docs/WINDOWS_DOCKER_GPU.md)

## Project Setup

1. **Initialize your project** (recommended for new projects):

```bash
$ ./init.sh
```

This interactive script will:

-   Prompt for your project name and rename the source directory accordingly
-   Update `pyproject.toml` with your project details (name, description, author)
-   Configure default Docker image name in `.env`
-   Set up workspace and data directory paths
-   Update all references to use your project name

2. **Manual setup** (if you prefer to configure manually):
    - **Default base image** is `nvcr.io/nvidia/pytorch:XX.XX-py3`. if you would like to use tensorflow, change base image (`nvcr.io/nvidia/tensorflow:XX.XX-tf2-py3`)
    - **Rename** `./src/mlproject` dir to `./src/your_project_name` – the name you would like to import with python: `import your_project_name`
    - **Update** `pyproject.toml` with your project name, description, and author information
    - **Create** a `.env` file (`docker_*.sh` scripts will generate it if not provided) to store Docker configuration defaults
    - **Python dependencies** are defined in `./pyproject.toml`. In the `project.scripts` section you can also define entrypoint scripts. Check out the file for an example.
3. **You can add submodules** into `./libs` dir. Ones which are python package (can be installed with pip) will be installed into the image.

```bash
$ git submodule add https://example.com/submodule.git ./libs/submodule
```

4.  **The container provides a Python environment for ML development.** Put your project-related scripts into `./src/your_project_name`. Use `./src/your_project_name/main.py` as the entry script that will be executed during training (`python src/your_project_name/main.py`). You can also define custom entry points in the `project.scripts` section of `pyproject.toml`.
5.  **Add proxy settings into the `~/.docker/config.json` if needed:**

```json
{
    "proxies": {
        "default": {
            "httpProxy": "http://address.proxy.com:8080/",
            "httpsProxy": "http://address.proxy.com:8080/",
            "noProxy": "localhost,127.0.0.1"
        }
    }
}
```

6.  **Build the image and follow the instructions on prompt. Building can take up to 20m:**

```bash
$ ./docker_build.sh
# You can also use non-interactive way:
$ ./docker_build.sh my-project:v1.0
# For deployment (code embedded in image):
$ ./docker_build.sh my-project:v1.0 --deploy
```

7. **Start a development container for interactive work:**

To know more: [Development vs Training](#development-vs-training)

```bash
$ ./docker_dev.sh
# You can also use non-interactive way:
$ ./docker_dev.sh my-project:v1.0 --non-interactive
```

> **Connect VS Code** to the running development container ([instructions](./docs/VSCODE.md))

8. **Or start training directly:**

```bash
$ ./docker_train.sh
# For detached training (runs in background):
$ ./docker_train.sh my-project:v1.0 --detached
# Non-interactive mode (reads values from .env file generated by init.sh):
$ ./docker_train.sh my-project:v1.0 --non-interactive
# With custom experiment name:
$ ./docker_train.sh my-project:v1.0 --experiment "feature_engineering_v2"
```

9. **Container Details:**

    **Development Containers (`docker_dev.sh`)**:

    - Naming Convention: `<image_name>.dev` (e.g., `my-project.latest.dev`)
    - Current repo folder is available at `/code` (mounted, live updates)
    - `<WORKSPACE_DIR>` is available at `/ws`
    - `<DATA_DIR>` is available at `/data` (read-only)

    **Training Containers (`docker_train.sh`):**

    - Naming convention: `<image_name>.train.<experiment_name>` (e.g., `my-project.latest.train.250808_1430-baseline_model`)
    - Code is **frozen** in a Docker image for reproducibility (no mounting)
    - `<WORKSPACE_DIR>` is available at `/ws`
    - `<DATA_DIR>` is available at `/data` (read-only)
    - Experiment artifacts saved to `/ws/experiments/<experiment_name>/`
    - Creates a frozen experiment image: `<base_image>:exp-<experiment_name>`

    **Managing containers:**

    - To inspect containers: `docker exec -it <CONTAINER_NAME> bash`
    - To monitor training logs: `docker logs -f <CONTAINER_NAME>`
    - To stop containers: `docker stop <CONTAINER_NAME>`

10. **Monitoring Training and Experiments:**

```bash
# Monitor real-time training logs
$ docker logs -f <training_container_name>

# Access experiment-specific training log
$ tail -f ./ws/experiments/<experiment_name>/training.log

# View experiment metadata
$ cat ./ws/experiments/<experiment_name>/system_info.txt
$ cat ./ws/experiments/<experiment_name>/config.json

# List all experiments
$ ls -la ./ws/experiments/

# Compare different experiment configurations
$ diff ./ws/experiments/exp1/config.json ./ws/experiments/exp2/config.json
```

11. **Update the image**

After making changes to your development container (installing pip packages, etc.), you can update your Docker image to preserve those changes:

**Using the update script (recommended):**

```bash
# Interactive mode - prompts for container and image details
./docker_update.sh

# Non-interactive mode - uses defaults from .env
./docker_update.sh --non-interactive

# Specify container and image explicitly
./docker_update.sh --container my_container --image my-project:v2.0

# With commit message and author
./docker_update.sh -c my_container -i my-project:v2.0 \
  -m "Added new dependencies" --author "Your Name <email@example.com>"
```

**Manual approach:**

-   `docker commit --change='CMD ~/start.sh' <CONTAINER_NAME> <IMAGE_NAME:v2.0>`

The `docker_update.sh` script provides a safer, more user-friendly way to update images with validation, helpful prompts, and better error handling.

12. **Options to share the image**:

    a) **Share the repo** after checking taht `pyproject.toml` contain the right versions of package dependencies. Your peer will be able to rebuild the image following the [standard workflow](#complete-workflow).

    b) **For standalone deployment** (includes code in image), use frozen image from trainng, or rebuild an image with `--deploy` flag

    ```bash
    # Build image with code embedded for deployment
    $ ./docker_build.sh my-project:v1.0 --deploy
    ```

    The `--deploy` flag copies your source code directly into the Docker image, creating a standalone image that doesn't require mounting the code directory.

    c) **For development sharing** (code mounted at runtime), just use an `IMAGE_NAME` from `docker image list`

**Push to a docker registry:**

```bash
$ docker login <REGISTRY_URL>
$ docker tag <IMAGE_NAME:TAG> <REGISTRY_URL>/<IMAGE_NAME:TAG>
$ docker push <REGISTRY_URL>/<IMAGE_NAME:TAG>
```

**Compress and decompress the image** on a new machine:

```bash
$ docker save <IMAGE_NAME:TAG> | gzip > output_file.tar.gz
$ docker load < output_file.tar.gz
```

## 🧪 Training Experiment Management

The `docker_train.sh` script provides comprehensive **experiment management** with automatic organization, code freezing, and artifact tracking. Each training run is treated as a separate experiment with full reproducibility.

### Features

#### 🔒 Code Reproducibility:

-   **Frozen Docker Image**: Creates a frozen Docker image (`<base_image>:exp-<experiment_name>`) containing your exact code and environment state
-   **Source Code Snapshot**: Saves a code snapshot in the experiment directory (`code_snapshot/src/`)
-   **Python Requirements**: Captures exact package versions in `requirements.txt`
-   **Version Control**: Git commit hash captured in `system_info.txt`

**Experiment Workflow Examples**

```bash
# Basic experiment with auto-generated name
./docker_train.sh my-project:v1.0 --detached
# Creates: ws/experiments/250808_1430-experiment/

# Custom experiment name
./docker_train.sh my-project:v1.0 --experiment "baseline_model" --detached
# Creates: ws/experiments/250808_1430-baseline_model/

# Non-interactive training
./docker_train.sh --non-interactive --experiment "automated_run"
```

#### 📁 Experiment Artifacts

Each experiment creates an organized directory structure:

```
.../<ws>/experiments/<YYMMDD_HHMM-experiment_name>/
├── checkpoints/          # Model checkpoints
├── plots/                # Training plots and visualizations
├── tb_logs/              # TensorBoard logs
├── code_snapshot/        # Frozen source code
│   └── src/              # Your project source code at experiment time
├── config.json           # Experiment configuration (auto-generated)
├── requirements.txt      # Frozen package versions
├── system_info.txt       # System metadata and GPU info
└── training.log          # Complete training logs
```

**🏷️ Automatic Experiment Naming:**

-   Format: `YYMMDD_HHMM-<custom_name>` (e.g., `250808_1430-feature_engineering_v2`)
-   Timestamp automatically added if not present in custom name
-   Default: `YYMMDD_HHMM-experiment` if no custom name provided

> ⚠️ **Important**: The training container uses the **frozen code** from the experiment image, not mounted code. This ensures complete reproducibility - the exact same code will run even if you modify your working directory later.

## Development vs Training

**Development Container (`docker_dev.sh`):**

-   Provides an interactive container environment for development
-   Ideal for debugging, code development, and interactive testing
-   Code is **mounted** from your working directory (live updates)
-   Access the container via VS Code `ms-vscode-remote.vscode-remote-extensionpack` extension and run your code interactively ([instructions](./docs/VSCODE.md))

**Training Container (`docker_train.sh`):**

-   Runs the training script directly (`src/your_project_name/main.py`)
-   Code is **frozen** in a Docker image for reproducibility
-   Creates structured experiment directories with full artifact tracking
-   Can run in interactive mode (default) or detached mode (`--detached`)
-   Each run is a separate experiment with timestamp-based naming

## Complete Workflow

The typical development and training workflow follows these steps:

> **Note**: If you haven't run `./init.sh` yet, do that first to set up your project properly.

### 1. Initial Setup

```bash
# Build the Docker image with your environment
./docker_build.sh my-project:v1.0
```

### 2. Development Phase

```bash
# Start development container with interactive shell
./docker_dev.sh my-project:v1.0

# Access the container and develop/test your code interactively
# Run your scripts, debug, and iterate on your code
```

### 3. Training Phase

```bash
# When ready to train, start training container with experiment management
./docker_train.sh my-project:v1.0 --experiment "baseline_model"

# Or run in background (detached mode)
./docker_train.sh my-project:v1.0 --experiment "feature_engineering_v2" --detached

# Monitor training progress
docker logs -f <training_container_name>

# Each run creates a complete experiment with frozen code and full artifact tracking
```

### 4. Experiment Artifacts and Results

Each training run (with `./docker_train.sh`) automatically creates:

-   **Experiment directory**: `./ws/experiments/<YYMMDD_HHMM-experiment_name>/`
    -   **Training logs**: `./ws/experiments/<experiment_name>/training.log`
    -   **Model checkpoints**: `./ws/experiments/<experiment_name>/checkpoints/`
    -   **Plots and visualizations**: `./ws/experiments/<experiment_name>/plots/`
    -   **TensorBoard logs**: `./ws/experiments/<experiment_name>/tb_logs/`
    -   **Code snapshot**: `./ws/experiments/<experiment_name>/code_snapshot/src/`
    -   **Frozen requirements**: `./ws/experiments/<experiment_name>/requirements.txt`
    -   **System metadata**: `./ws/experiments/<experiment_name>/system_info.txt`
    -   **Configuration**: `./ws/experiments/<experiment_name>/config.json`

**Reproducibility Features:**

-   **Frozen Docker Image**: Each training run creates a frozen experiment image `<base_image>:exp-<experiment_name>` with the exact code state
-   **Code Snapshot**: Clean copy of source code (`src/`) at experiment time saved to `code_snapshot/`
-   **Environment Freeze**: Exact package versions captured in `requirements.txt`
-   **System Metadata**: Complete system and GPU information in `system_info.txt`
-   **Git Integration**: Captures current Git commit hash for version control

> ⚠️ **Important**: The training container uses the **frozen code** from the experiment image, not mounted code. This ensures complete reproducibility - the exact same code will run even if you modify your working directory later.

### 5. Experiment Management

```bash
# List all experiments
ls -la ./ws/experiments/

# Compare experiment results
cat ./ws/experiments/250808_1430-baseline_model/config.json
cat ./ws/experiments/250808_1445-feature_eng_v2/config.json

# View recent training details (if training was run in detached mode)
cat .train_hint

# Reproduce exact experiment (using frozen image)
docker run -it <base_image>:exp-250808_1430-baseline_model python src/your_project_name/main.py

# Access experiment artifacts
tail -f ./ws/experiments/<experiment_name>/training.log
ls ./ws/experiments/<experiment_name>/checkpoints/
```
