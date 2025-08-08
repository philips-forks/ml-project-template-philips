"""
Main training script for ML Project.

This script serves as the entry point for training the model.
"""

import json
import logging
import os
import sys
from pathlib import Path

# Get experiment information from environment variables
EXPERIMENT_NAME = os.getenv("EXPERIMENT_NAME", "default_experiment")
EXPERIMENT_DIR = os.getenv("EXPERIMENT_DIR", "/ws/experiments/default_experiment")

# Configure logging to write to experiment-specific log file
log_file = Path(EXPERIMENT_DIR) / "training.log"
log_file.parent.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler(str(log_file))],
)

logger = logging.getLogger(__name__)


def setup_training_environment() -> dict:
    """
    Set up the training environment and validate paths.

    Returns:
        dict: Configuration dictionary with paths and settings.
    """
    experiment_dir = Path(EXPERIMENT_DIR)

    config = {
        "data_dir": Path("/data"),
        "workspace_dir": Path("/ws"),
        "experiment_dir": experiment_dir,
        "model_checkpoints": experiment_dir / "checkpoints",
        "training_logs": experiment_dir / "training.log",
        "tensorboard_logs": experiment_dir / "tb_logs",
        "plots_dir": experiment_dir / "plots",
    }

    # Load experiment configuration or create default one
    config_file = experiment_dir / "config.json"
    if config_file.exists():
        with open(config_file, "r", encoding="utf-8") as f:
            experiment_config = json.load(f)
            config["experiment_config"] = experiment_config
            logger.info("Loaded experiment configuration from %s", config_file)
    else:
        # Create default configuration
        logger.info("Creating default experiment configuration at %s", config_file)
        default_config = {
            "experiment_name": EXPERIMENT_NAME,
            "model": {"type": "example_model", "parameters": {"learning_rate": 0.001, "batch_size": 32, "epochs": 100}},
            "data": {"dataset_path": "/data", "validation_split": 0.2},
            "training": {"optimizer": "adam", "loss_function": "categorical_crossentropy", "metrics": ["accuracy"]},
            "paths": {
                "experiment_dir": f"/ws/experiments/{EXPERIMENT_NAME}",
                "checkpoints": f"/ws/experiments/{EXPERIMENT_NAME}/checkpoints",
                "logs": f"/ws/experiments/{EXPERIMENT_NAME}/training.log",
                "tensorboard": f"/ws/experiments/{EXPERIMENT_NAME}/tb_logs",
                "plots": f"/ws/experiments/{EXPERIMENT_NAME}/plots",
            },
        }

        with open(config_file, "w", encoding="utf-8") as f:
            json.dump(default_config, f, indent=4)

        config["experiment_config"] = default_config
        logger.info("Created default experiment configuration")

    # Validate data directory exists
    if not config["data_dir"].exists():
        logger.error("Data directory not found: %s", config["data_dir"])
        raise FileNotFoundError(f"Data directory not found: {config['data_dir']}")

    # Log configuration
    logger.info("=== Training Environment Setup ===")
    logger.info("Experiment: %s", EXPERIMENT_NAME)
    logger.info("Data directory: %s", config["data_dir"])
    logger.info("Workspace directory: %s", config["workspace_dir"])
    logger.info("Experiment directory: %s", config["experiment_dir"])
    logger.info("Model checkpoints: %s", config["model_checkpoints"])
    logger.info("TensorBoard logs: %s", config["tensorboard_logs"])
    logger.info("Plots directory: %s", config["plots_dir"])

    logger.info("Training environment setup completed successfully")
    return config


def main() -> None:
    """
    Main training function for ML Project.

    This function initializes the training environment, loads data,
    configures the model, and starts the training process.
    """
    logger.info("Starting ML Project training...")

    try:
        # Setup training environment
        config = setup_training_environment()

        # Log system information
        logger.info("Data directory: %s", config["data_dir"])
        logger.info("Workspace directory: %s", config["workspace_dir"])
        logger.info("Model checkpoints: %s", config["model_checkpoints"])
        logger.info("Training logs: %s", config["training_logs"])

        # Example: Save a dummy checkpoint
        checkpoint_path = config["model_checkpoints"] / "model_epoch_5.pt"
        checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
        # In real training, you would save your model here
        # torch.save(model.state_dict(), checkpoint_path)
        logger.info("Checkpoint saved to %s", checkpoint_path)

        # Example: Save a dummy plot
        plots_dir = config["plots_dir"]
        plots_dir.mkdir(parents=True, exist_ok=True)
        plot_path = plots_dir / "training_loss.png"
        # In real training, you would save your plots here
        # plt.savefig(plot_path)
        logger.info("Training plot saved to %s", plot_path)

        # Actual training code would go here
        logger.info("Training logic placeholder - implement your model training here")

        # Example training loop placeholder
        logger.info("Initializing model...")
        logger.info("Loading dataset...")
        logger.info("Starting training epochs...")

        # Simulate training progress
        for epoch in range(1, 6):  # Example: 5 epochs
            logger.info("Epoch %d/5 - Training in progress...", epoch)

        logger.info("Training completed successfully!")
        logger.info("All artifacts saved to experiment directory: %s", config["experiment_dir"])

    except Exception as e:
        logger.error("Training failed with error: %s", str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()
