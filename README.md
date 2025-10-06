# ComfyUI Installation with ROCm on WSL (Ubuntu 24.04)

This guide provides detailed instructions for setting up ComfyUI with ROCm on Windows Subsystem for Linux (WSL) using Ubuntu 24.04. It covers installing WSL, setting up Ubuntu 24.04, installing prerequisites, running the provided `install_rocm_comfyui.sh` script, activating the virtual environment (venv), and starting ComfyUI. This setup is designed for AMD Radeon GPUs (e.g., RX 7900 XTX) and uses ROCm 6.4.2 with PyTorch 2.6.0.

**Date**: October 3, 2025

## Prerequisites

Before starting, ensure the following are in place:

- **Operating System**: Windows 11 (build 22000 or higher).
- **Hardware**: AMD Radeon GPU supported by ROCm (e.g., RX 7000/9000 series). Check compatibility at [AMD ROCm GPU Support](https://rocm.docs.amd.com/projects/radeon/en/latest/reference-ryzen/gpu_os_support.html).
- **Memory**: At least 8GB RAM and sufficient GPU VRAM (8GB+ for models like Stable Diffusion).
- **Administrative Access**: Required for Windows PowerShell commands and WSL sudo privileges.
- **Internet Connection**: Needed for downloading packages, PyTorch wheels, and ComfyUI.

## Step-by-Step Installation

### Step 1: Install Windows Subsystem for Linux (WSL)

WSL allows running Linux on Windows, with WSL2 required for GPU support.

1. **Open PowerShell as Administrator**:
   - Search for "PowerShell" in the Start menu, right-click, and select "Run as administrator".

2. **Enable WSL**:
   ```powershell
   wsl --install
   ```
   - This installs WSL and the default Ubuntu distribution. Restart your computer if prompted.

3. **Update WSL**:
   ```powershell
   wsl --update
   ```

4. **Verify WSL Installation**:
   ```powershell
   wsl --status
   ```
   - Ensure the default version is WSL 2. If not, set it:
     ```powershell
     wsl --set-default-version 2
     ```

### Step 2: Install Ubuntu 24.04 Distro

Ubuntu 24.04 (Noble Numbat) is recommended for ROCm 6.4.2 compatibility.

1. **Install Ubuntu 24.04**:
   - Open the Microsoft Store, search for "Ubuntu 24.04 LTS", and install it.
   - Alternatively, in PowerShell as Administrator:
     ```powershell
     wsl --install -d Ubuntu-24.04
     ```

2. **Launch Ubuntu**:
   - Search for "Ubuntu 24.04" in the Start menu and open it.
   - Set up a username and password (e.g., username: `test`, password: your choice) when prompted.

3. **Update Ubuntu Packages**:
   In the Ubuntu terminal:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

### Step 3: Install Prerequisites

These packages and drivers are required for ROCm, PyTorch, and ComfyUI.

1. **Update AMD Adrenalin Drivers in Windows**:
   - Download the latest AMD Adrenalin drivers (version 24.20.11.01 or later) from [AMD's website](https://www.amd.com/en/support).
   - Install via AMD Software or Device Manager.
   - Reboot your computer.

2. **Install Required Ubuntu Packages**:
   In the Ubuntu terminal:
   ```bash
   sudo apt install -y git wget nano python3.12-venv python3-pip
   ```

3. **Verify GPU Access**:
   Check if ROCm detects your GPU:
   ```bash
   rocminfo
   ```
   - Expected output should list your GPU (e.g., `Radeon RX 7900 XTX`).
   - If `rocminfo` is not found or no GPU is detected, the script will install ROCm in the next step.

### Step 4: Save and Run the Installation Script

The `install_rocm_comfyui.sh` script automates the installation of ROCm 6.4.2, creates a user-specified virtual environment, installs PyTorch with ROCm-specific wheels, and sets up ComfyUI.

1. **Save the Script**:
   In the Ubuntu terminal:
   ```bash
   nano ~/install_rocm_comfyui.sh
   ```
   Copy and paste the script content (provided below or from a previous source), then save (Ctrl+O, Enter, Ctrl+X).

   ```bash
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
   ```

2. **Set Executable Permissions**:
   In the Ubuntu terminal:
   ```bash
   chmod +x ~/install_rocm_comfyui.sh
   ```

3. **Run the Script**:
   ```bash
   ./install_rocm_comfyui.sh
   ```
   - **Prompts**:
     - **Prerequisites**: Enter `y` to confirm you’ve set up Windows 11, AMD drivers, and Ubuntu 24.04.
     - **Virtual Environment Name**: Enter a name (e.g., `comfyui_venv`).
     - **Existing ComfyUI Directory**: If `~/ComfyUI` exists, choose `remove`, `rename`, or `exit`.
   - The script installs ROCm 6.4.2, verifies the GPU, creates the venv, installs PyTorch wheels, clones ComfyUI, and provides instructions for next steps.

### Step 5: Switch to the Virtual Environment and Start ComfyUI

After the script completes, activate the venv and start ComfyUI.

1. **Activate the Virtual Environment**:
   ```bash
   source ~/comfyui_venv/bin/activate
   ```
   - Replace `comfyui_venv` with the name you provided (e.g., `comfyui_venv`).
   - Your terminal prompt will change to indicate the venv is active (e.g., `(comfyui_venv) test@NV-Test:~$`).

2. **Comment Out Packages in `requirements.txt`**:
   To avoid conflicts with the installed PyTorch wheels:
   ```bash
   cd ~/ComfyUI
   nano requirements.txt
   ```
   - Find the lines for `torch`, `torchaudio`, and `torchvision`.
   - Add a `#` at the start of each line (e.g., `#torch`, `#torchaudio`, `#torchvision`).
   - Save (Ctrl+O, Enter) and exit (Ctrl+X).

3. **Install ComfyUI Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Start ComfyUI**:
   ```bash
   python3 main.py
   ```
   - ComfyUI will start and display a URL (e.g., `http://127.0.0.1:8188`).
   - Open this URL in a Windows web browser to access the ComfyUI interface.

5. **Deactivate the Virtual Environment (When Done)**:
   ```bash
   deactivate
   ```

### Step 6: Add Models (Optional)

To use ComfyUI with models like Stable Diffusion:

1. **Download Models**:
   - Obtain models (e.g., `sd3_medium_incl_clips.safetensors`) from Hugging Face.
   - For gated models, authenticate within the venv:
     ```bash
     source ~/comfyui_venv/bin/activate
     pip install huggingface_hub
     huggingface-cli login
     cd ~/ComfyUI/models/checkpoints
     # Download model (e.g., wget or manual download)
     ```

2. **Place Models**:
   - Copy models to `~/ComfyUI/models/checkpoints`.
   - From Windows, access this directory at `\\wsl$\Ubuntu\home\test\ComfyUI\models\checkpoints`.

## Troubleshooting

If you encounter issues during setup, try these solutions:

- **Script Execution Fails**:
  - Ensure permissions:
    ```bash
    chmod +x ~/install_rocm_comfyui.sh
    ```
  - Check for Windows line endings:
    ```bash
    sudo apt install -y dos2unix
    dos2unix ~/install_rocm_comfyui.sh
    ```
  - Verify the shebang line:
    ```bash
    head -n 1 ~/install_rocm_comfyui.sh
    ```
    Expected: `#!/bin/bash`

- **ROCm Library Not Found**:
  - Verify:
    ```bash
    ls -l /opt/rocm-6.4.2/lib/libhsa-runtime64.so.1
    ```
  - Reinstall ROCm if missing:
    ```bash
    sudo apt update
    wget https://repo.radeon.com/amdgpu-install/6.4.2.1/ubuntu/noble/amdgpu-install_6.4.60402-1_all.deb
    sudo apt install -y ./amdgpu-install_6.4.60402-1_all.deb
    amdgpu-install -y --usecase=wsl,rocm --no-dkms
    ```

- **GPU Not Detected**:
  - Check:
    ```bash
    rocminfo
    ls /dev/dxg
    ```
  - Update AMD drivers (24.20.11.01 or newer) and WSL:
    ```powershell
    wsl --update
    ```

- **Port Conflict (8188)**:
  - If `python3 main.py` fails due to port 8188:
    ```bash
    sudo ss -tulnp | grep 8188
    sudo kill -9 <pid>
    ```
  - Alternatively, modify ComfyUI to use a different port (e.g., 8189) by editing `main.py` or configuration.

- **ComfyUI Dependency Errors**:
  - Retry after ensuring `requirements.txt` is modified:
    ```bash
    source ~/comfyui_venv/bin/activate
    cd ~/ComfyUI
    pip install -r requirements.txt
    ```

- **Virtual Environment Issues**:
  - If `source ~/comfyui_venv/bin/activate` fails, recreate:
    ```bash
    rm -rf ~/comfyui_venv
    python3 -m venv ~/comfyui_venv --system-site-packages
    ```

## Cleanup (Optional)

To remove old or unused files:
```bash
rm -rf ~/comfyui_venv  # Remove venv
rm -rf ~/ComfyUI  # Remove ComfyUI
rm -rf ~/comfyui_data ~/comfyui_data_backup_*  # Remove Docker-related directories from previous attempts
```

## Notes

- **Driver Update**: If `rocminfo` shows `Warning: Windows driver is old`, update AMD Adrenalin drivers from [AMD’s website](https://www.amd.com/en/support).
- **ROCm 6.4.4 Preview**: To use ROCm 6.4.4, edit the script:
  ```bash
  ROCM_VERSION="6.4.4.1"
  ROCM_DEB="amdgpu-install_6.4.60404-1_all.deb"
  ROCM_URL="https://repo.radeon.com/amdgpu-install/$ROCM_VERSION/ubuntu/noble/$ROCM_DEB"
  ROCM_LIB_PATH="/opt/rocm-6.4.4/lib/libhsa-runtime64.so.1"
  ```
  Update PyTorch wheel URLs in the script (check [AMD ROCm docs](https://rocm.docs.amd.com)).

For additional help, consult the [AMD ROCm WSL Guide](https://rocm.docs.amd.com/projects/radeon/en/latest/docs/install/installrad/wsl/install-wsl.html) or share error outputs with your support contact.
