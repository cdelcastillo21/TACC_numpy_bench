#!/bin/bash

# Default values
conda_version="24.5.0"
python_version="3.10"
conda_channels="conda-forge"
conda_packages=""
pip_packages=""
verbose=0
trash_dir="$SCRATCH/trash"

# Function to format the install directory name
format_install_dir() {
    local version=$1
    if [ "$version" = "latest" ]; then
        echo "${SCRATCH}/conda-latest"
    else
        # Replace . with _ in the version number
        local formatted_version=$(echo $version | sed 's/\./_/g')
        echo "${SCRATCH}/conda-${formatted_version}"
    fi
}

# Set install_dir based on conda_version
install_dir=$(format_install_dir $conda_version)
build_dir="$install_dir-build"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Set up a Conda environment with specified options and Mamba resolver."
    echo
    echo "Options:"
    echo "  -h, --help                Show this help message and exit"
    echo "  -i, --install-dir DIR     Set the installation directory (default: $install_dir)"
    echo "  -b, --build-dir DIR       Set the build directory (default: $build_dir)"
    echo "  -p, --python-version VER  Set the Python version (default: $python_version)"
    echo "  -c, --conda-channels CH   Set Conda channels, comma-separated (default: $conda_channels)"
    echo "  -k, --conda-packages PKG  Set Conda packages to install, comma-separated (default: none)"
    echo "  -m, --pip-packages PKG    Set pip packages to install, comma-separated (default: none)"
    echo "  -v, --conda-version VER   Set Conda version to install (default: latest)"
    echo "  -V, --verbose             Increase verbosity (can be used multiple times)"
    echo
    echo "Example:"
    echo "  $0 --conda-version 23.11.0 --python-version 3.10 --conda-channels conda-forge \\"
    echo "  	--conda-packages numpy,pandas --pip-packages pandas -V"
}

# Logging function
log() {
    local level=$1
    shift
    if [[ $verbose -ge $level ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
    fi
}

# Error handling function
handle_error() {
    local exit_code=$1
    local error_message=$2
    if [ $exit_code -ne 0 ]; then
        log 0 "ERROR: $error_message"
        exit $exit_code
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
        show_help
        exit 0
        ;;
        -i|--install-dir)
        install_dir="$2"
        shift 2
        ;;
        -b|--build-dir)
        build_dir="$2"
        shift 2
        ;;
        -p|--python-version)
        python_version="$2"
        shift 2
        ;;
        -c|--conda-channels)
        conda_channels="$2"
        shift 2
        ;;
        -k|--conda-packages)
        conda_packages="$2"
        shift 2
        ;;
        -m|--pip-packages)
        pip_packages="$2"
        shift 2
        ;;
        -v|--conda-version)
        conda_version="$2"
        install_dir=$(format_install_dir $conda_version)
        build_dir="$install_dir-build"
        shift 2
        ;;
        -V|--verbose)
        ((verbose++))
        shift
        ;;
        *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
done

# Detect architecture
arch=$(uname -m)
case $arch in
    x86_64)
        arch_name="x86_64"
        ;;
    aarch64|arm64)
        arch_name="aarch64"
        ;;
    *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
esac

log 1 "Detected architecture: $arch_name"
log 1 "Installation directory: $install_dir"
log 1 "Build directory: $build_dir"

# Function to move directory to trash
move_to_trash() {
    local dir="$1"
    local dir_name=$(basename "$dir")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local trash_path="${trash_dir}/${dir_name}_${timestamp}"
    
    mkdir -p "$trash_dir"
    handle_error $? "Failed to create trash directory: $trash_dir"
    
    mv "$dir" "$trash_path"
    handle_error $? "Failed to move directory to trash: $dir"
    
    log 1 "Moved directory to trash: $dir -> $trash_path"
}

# Check if directories exist and prompt for moving to trash
for dir in "$install_dir" "$build_dir"; do
    if [ -d "$dir" ]; then
        read -p "Directory $dir already exists. Do you want to move it to trash? [y/N] " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            move_to_trash "$dir"
        else
            log 0 "Installation cancelled. Please choose a different directory or move existing ones manually."
            exit 1
        fi
    fi
done

# Create directories
mkdir -p "$build_dir"
handle_error $? "Failed to create build directory: $build_dir"
log 1 "Created build directory: $build_dir"

# Determine Miniconda installer URL based on conda_version and architecture
if [ "$conda_version" = "latest" ]; then
    miniconda_installer="Miniconda3-latest-Linux-${arch_name}.sh"
else
    # Add checks, because sometime will be 1, or even 2 for patches I think?
    miniconda_installer="Miniconda3-py39_${conda_version}-0-Linux-${arch_name}.sh"
fi

log 1 "Using Miniconda installer: $miniconda_installer"

# Download and install Miniconda
log 1 "Downloading Miniconda installer..."
wget "https://repo.anaconda.com/miniconda/${miniconda_installer}" -O "${build_dir}/${miniconda_installer}"
handle_error $? "Failed to download Miniconda installer"

log 1 "Installing Miniconda..."
bash "${build_dir}/${miniconda_installer}" -b -p "$install_dir"
handle_error $? "Failed to install Miniconda"

# Set conda channels
log 1 "Setting conda channels..."
IFS=',' read -ra CHANNELS <<< "$conda_channels"
for channel in "${CHANNELS[@]}"; do
    "$install_dir/bin/conda" config --add channels "$channel"
    handle_error $? "Failed to add channel: $channel"
    log 2 "Added channel: $channel"
done

# Disable auto-activation of base environment
log 1 "Disabling auto-activation of base environment..."
"$install_dir/bin/conda" config --set auto_activate_base false
handle_error $? "Failed to disable auto-activation of base environment"

# TODO: Configure so ~/.condarc, user conda configs, inside of conda install directory?

# TODO: Change this to detect if in appropriate conda version range to use this
# Set libmamba as default solver
# log 1 "Installing mamba..."
# "$install_dir/bin/conda" install -y -n base conda-libmamba-solver
# handle_error $? "Failed to install conda-libmamba-solver"
# "$install_dir/bin/conda" config --set solver libmamba
# handle_error $? "Failed to set libmamba as default solver"

# Create a new environment with specified Python version using mamba
log 1 "Creating new environment 'myenv' with Python $python_version..."
"$install_dir/bin/conda" create -y -n myenv python="$python_version"
handle_error $? "Failed to create new environment 'myenv'"

# Install conda packages if specified using conda 
if [ -n "$conda_packages" ]; then
    log 1 "Installing conda packages: $conda_packages"
    "$install_dir/bin/conda" install -y -n myenv $conda_packages
    handle_error $? "Failed to install conda packages"
fi

# Install pip packages if specified
if [ -n "$pip_packages" ]; then
    log 1 "Installing pip packages: $pip_packages"
    source "$install_dir/bin/activate" myenv
    pip install $pip_packages
    handle_error $? "Failed to install pip packages"
    conda deactivate
fi

# TODO: Set up Python user environment - Add to init script?
# log 1 "Setting up Python user environment..."
# echo "export PYTHONUSERBASE=$WORK/.local" >> "$install_dir/etc/conda/activate.d/env_vars.sh"
# echo 'export PATH="$WORK/.local/bin:$PATH"' >> "$install_dir/etc/conda/activate.d/env_vars.sh"
# handle_error $? "Failed to set up Python user environment"

# Output command to source environment
echo "To activate the Conda environment, run the following command:"
echo "source activate $install_dir/envs/myenv"

log 1 "Setup complete!"
