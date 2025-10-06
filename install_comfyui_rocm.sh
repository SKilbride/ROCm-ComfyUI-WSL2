#!/bin/bash

# Installer script for ROCm on WSL, creating a venv, installing PyTorch, and setting up ComfyUI
# Assumes WSL Ubuntu 24.04 and AMD Radeon GPU with compatible drivers
# To run: chmod +x install_rocm_comfyui.sh; ./install_rocm_comfyui.sh
# Sets permissions for ROCm library, venv, and ComfyUI directory
# Installs python3-venv to ensure venv creation
# Tested for ROCm 6.4.2, PyTorch 2.6.0, Ubuntu 24.04, Python 3.12
# Date: October 3, 2025

# Exit on error
set -e

# Variables
ROCM_VERSION="6.4.2.1"
ROCM_DEB="amdgpu-install_6.4.60402-1_all.deb"
ROCM_URL="https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/noble/${ROCM_DEB}"
ROCM_LIB_PATH="/opt/rocm-6.4.2/lib/libhsa-runtime64.so.1"

echo "Starting ROCm and ComfyUI installation on WSL..."

# Step 1: Verify prerequisites (manual check instructions)
echo "Checking prerequisites..."
echo "Ensure the following are set up before running this script:"
echo "1. Windows 11 (build 22000 or higher) with WSL2 enabled ('wsl --install' in PowerShell)."
echo "2. Latest AMD Adrenalin drivers (24.20.11.01 or later) installed in Windows."
echo "3. WSL Ubuntu 24.04 installed ('wsl --install -d Ubuntu-24.04' in PowerShell)."
echo "4. At least 8GB RAM and sufficient GPU VRAM (8GB+ for Stable Diffusion)."
echo "If not set up, exit and configure these first. Continue? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Exiting. Please set up prerequisites and rerun."
    exit 1
fi

# Step 2: Install ROCm
echo "Installing ROCm $ROCM_VERSION..."
sudo apt update
sudo apt autoremove -y  # Clean up unused packages like libllvm19
if [ ! -f "$ROCM_DEB" ]; then
    wget "$ROCM_URL"
fi
sudo apt install -y "./$ROCM_DEB"
amdgpu-install -y --usecase=wsl,rocm --no-dkms
rm -f "$ROCM_DEB"
echo "ROCm installation complete."

# Step 3: Verify ROCm installation
echo "Verifying ROCm installation..."
if ! command -v rocminfo &> /dev/null; then
    echo "Error: rocminfo not found. ROCm installation failed."
    echo "Check https://rocm.docs.amd.com/projects/radeon/en/latest/docs/install/installrad/wsl/install-wsl.html"
    exit 1
fi
if ! rocminfo | grep -q "Name:.*Radeon"; then
    echo "Error: No AMD GPU detected by rocminfo. Ensure GPU drivers are installed in Windows."
    exit 1
fi
echo "ROCm verified. GPU detected."

# Step 4: Verify ROCm library
echo "Verifying ROCm library at $ROCM_LIB_PATH..."
if [ ! -f "$ROCM_LIB_PATH" ]; then
    echo "Error: $ROCM_LIB_PATH not found."
    echo "Attempting to find alternative path..."
    ROCM_LIB_PATH=$(find /opt -name "libhsa-runtime64.so.1" -type f 2>/dev/null | head -n 1)
    if [ -z "$ROCM_LIB_PATH" ] || [ ! -f "$ROCM_LIB_PATH" ]; then
        echo "Error: libhsa-runtime64.so.1 not found in /opt."
        echo "Found paths:"
        find /opt -name "*hsa-runtime64.so*" 2>/dev/null || echo "No matching files found."
        echo "Please check ROCm installation or manually specify the path."
        exit 1
    fi
fi
echo "Found ROCm library: $ROCM_LIB_PATH"
sudo chmod 644 "$ROCM_LIB_PATH" 2>/dev/null || echo "Warning: Could not set permissions on $ROCM_LIB_PATH"

# Step 5: Install python3-venv
echo "Installing python3-venv for virtual environment support..."
sudo apt install -y python3.12-venv

# Step 6: Ask for venv name
echo "Enter the name for the virtual environment (e.g., comfyui_venv):"
read VENV_NAME
if [ -z "$VENV_NAME" ]; then
    echo "Error: Virtual environment name cannot be empty."
    exit 1
fi

# Step 7: Create and activate venv
echo "Creating and activating virtual environment: $VENV_NAME..."
if [ -d "$VENV_NAME" ]; then
    echo "Warning: Virtual environment $VENV_NAME already exists."
    echo "Remove and recreate it? (y/N)"
    read -r venv_response
    if [[ "$venv_response" =~ ^[Yy]$ ]]; then
        rm -rf "$VENV_NAME"
    else
        echo "Exiting. Please choose a different venv name or remove the existing one."
        exit 1
    fi
fi
python3 -m venv "$VENV_NAME" --system-site-packages
chmod -R 755 "$VENV_NAME"
source "$VENV_NAME/bin/activate"

# Step 8: Install and update pip
echo "Installing and updating pip..."
sudo apt install -y python3-pip
pip3 install --upgrade pip wheel

# Step 9: Install PyTorch wheels
echo "Installing PyTorch wheels..."
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.2/torch-2.6.0%2Brocm6.4.2.git76481f7c-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.2/torchvision-0.21.0%2Brocm6.4.2.git4040d51f-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.2/pytorch_triton_rocm-3.2.0%2Brocm6.4.2.git7e948ebf-cp312-cp312-linux_x86_64.whl
wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.2/torchaudio-2.6.0%2Brocm6.4.2.gitd8831425-cp312-cp312-linux_x86_64.whl
pip3 uninstall -y torch torchvision pytorch-triton-rocm torchaudio || true
pip3 install torch-2.6.0+rocm6.4.2.git76481f7c-cp312-cp312-linux_x86_64.whl \
    torchvision-0.21.0+rocm6.4.2.git4040d51f-cp312-cp312-linux_x86_64.whl \
    torchaudio-2.6.0+rocm6.4.2.gitd8831425-cp312-cp312-linux_x86_64.whl \
    pytorch_triton_rocm-3.2.0+rocm6.4.2.git7e948ebf-cp312-cp312-linux_x86_64.whl
rm *.whl
echo "PyTorch installation complete."

# Step 10: Update runtime library
echo "Updating runtime library..."
location=$(pip show torch | grep Location | awk -F ": " '{print $2}')
if [ -z "$location" ]; then
    echo "Error: Could not locate PyTorch installation."
    exit 1
fi
cd "${location}/torch/lib/"
rm -f libhsa-runtime64.so* 2>/dev/null || echo "No libhsa-runtime64.so files found to remove."
cd ~

# Step 11: Verify home directory
echo "Verifying current directory is home..."
if [ "$PWD" != "$HOME" ]; then
    echo "Relocating to home directory..."
    cd ~
fi
echo "Current directory: $PWD"

# Step 12: Verify if ComfyUI is already present
echo "Checking for existing ComfyUI installation..."
if [ -d "ComfyUI" ]; then
    echo "ComfyUI directory already exists."
    echo "Do you want to remove, rename, or exit? (remove/rename/exit)"
    read -r ACTION
    case "${ACTION}" in
        remove)
            rm -rf ComfyUI
            ;;
        rename)
            mv ComfyUI "ComfyUI_backup_$(date +%F_%H%M%S)"
            ;;
        *)
            echo "Exiting."
            exit 0
            ;;
    esac
fi

# Step 13: Clone ComfyUI
echo "Cloning ComfyUI..."
git clone https://github.com/comfyanonymous/ComfyUI.git
chmod -R 755 ComfyUI
echo "ComfyUI cloned successfully."

# Step 14: Inform user about requirements.txt
echo "Before running ComfyUI, please comment out the following lines in ComfyUI/requirements.txt:"
echo "  - torch"
echo "  - torchaudio"
echo "  - torchvision"
echo "To edit, run: nano ComfyUI/requirements.txt (add '#' before each line, save with Ctrl+O, Enter, Ctrl+X)"
echo "To install dependencies, run: source $VENV_NAME/bin/activate; cd ComfyUI; pip install -r requirements.txt"
echo "To run ComfyUI, use: source $VENV_NAME/bin/activate; cd ComfyUI; python3 main.py"
echo "Then open the provided URL (e.g., http://127.0.0.1:8188) in a Windows browser."

# Step 15: Verify PyTorch and GPU access
echo "Verifying PyTorch and GPU access..."
TORCH_CHECK=$(python3 -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null)
if [ "$TORCH_CHECK" = "True" ]; then
    echo "PyTorch GPU access verified: $TORCH_CHECK"
    GPU_NAME=$(python3 -c "import torch; print(torch.cuda.get_device_name(0))" 2>/dev/null)
    echo "GPU detected: $GPU_NAME"
else
    echo "Error: PyTorch GPU access failed. Check ROCm/GPU setup."
    exit 1
fi

echo "Installation complete! ComfyUI is set up in ~/ComfyUI, and venv is in ~/$VENV_NAME."
echo "Note: For ROCm 6.4.4 preview, edit this script to use version 6.4.4.1 and update PyTorch wheel URLs."