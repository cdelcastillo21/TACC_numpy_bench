#!/bin/bash

# Set default values
verbose=false
log_file="numpy_benchmark.log"
pre_cleanup=false
post_cleanup=false

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run NumPy benchmarks in different conda environments."
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message and exit"
    echo "  -v, --verbose        Enable verbose output"
    echo "  -l, --log FILE       Specify a log file (default: numpy_benchmark.log)"
    echo "  --pre-cleanup        Remove existing environments before creating new ones"
    echo "  --post-cleanup       Remove environments after benchmarks are completed"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -l|--log)
            log_file="$2"
            shift 2
            ;;
        --pre-cleanup)
            pre_cleanup=true
            shift
            ;;
        --post-cleanup)
            post_cleanup=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function for logging
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$log_file"
    if $verbose || [ "$level" == "ERROR" ]; then
        echo "[$timestamp] [$level] $message"
    fi
}

# Function to remove environment
remove_env() {
    env_name=$1
    if conda env list | grep -q "$env_name"; then
        log "Removing existing environment: $env_name" "INFO"
        conda env remove -n $env_name -y
        if [ $? -ne 0 ]; then
            log "Failed to remove environment $env_name" "ERROR"
            return 1
        fi
    else
        log "Environment $env_name does not exist, skipping removal" "INFO"
    fi
}

# Function to create conda environment and install NumPy
create_env() {
    env_name=$1
    install_method=$2
    channel=$3

    log "Creating environment: $env_name" "INFO"
    conda create -n $env_name python=3.9 -y --override-channels -c anaconda
    if [ $? -ne 0 ]; then
        log "Failed to create environment $env_name" "ERROR"
        return 1
    fi

    source activate $env_name
    if [ $? -ne 0 ]; then
        log "Failed to activate environment $env_name" "ERROR"
        return 1
    fi

    log "Installing NumPy in $env_name using $install_method" "INFO"
    if [ "$install_method" == "pip" ]; then
        pip install numpy
    elif [ "$install_method" == "conda" ]; then
        if [ -n "$channel" ]; then
            conda install --override-channels -c $channel numpy -y
        else
            conda install --override-channels -c anaconda numpy -y
        fi
    fi

    if [ $? -ne 0 ]; then
        log "Failed to install NumPy in $env_name" "ERROR"
        return 1
    fi

    log "Installing psutil in $env_name" "INFO"
    pip install psutil
    if [ $? -ne 0 ]; then
        log "Failed to install psutil in $env_name" "ERROR"
        return 1
    fi

    # TODO: Fix
#     log "Getting disk space for $env_name" "INFO"
#     env_path=$(conda info --json | python -c "import sys, json; print(json.load(sys.stdin)['envs'][0])")
#     disk_space=$(du -sh "$env_path" | cut -f1)
#     log "Disk space used by $env_name: $disk_space" "INFO"
}

# Function to run benchmark
run_benchmark() {
    env_name=$1
    log "Running benchmark in $env_name" "INFO"
    source activate $env_name
    if [ $? -ne 0 ]; then
        log "Failed to activate environment $env_name for benchmark" "ERROR"
        return 1
    fi

    python - <<EOF > "${env_name}_benchmark.log"
import numpy as np
import time
import psutil

size = 2000
a = np.random.rand(size, size)
b = np.random.rand(size, size)

start_time = time.time()
c = np.dot(a, b)
end_time = time.time()

elapsed_time = end_time - start_time
memory_usage = psutil.Process().memory_info().rss / (1024 * 1024)  # in MB

print(f"Time taken: {elapsed_time:.4f} seconds")
print(f"Memory usage: {memory_usage:.2f} MB")
print(f"NumPy version: {np.__version__}")
print(f"NumPy config: {np.show_config()}")
EOF

    log "Benchmark for $env_name completed" "INFO"
}

# Main execution
log "Starting NumPy benchmark script" "INFO"

environments=(
    "numpy_pip pip"
    "numpy_conda_anaconda conda"
    "numpy_conda_forge conda conda-forge"
)

# Pre-cleanup if option is set
if $pre_cleanup; then
    log "Performing pre-cleanup" "INFO"
    for env in "${environments[@]}"; do
        IFS=' ' read -r -a env_info <<< "$env"
        env_name="${env_info[0]}"
        remove_env $env_name
    done
fi

# Create environments, run benchmarks
for env in "${environments[@]}"; do
    IFS=' ' read -r -a env_info <<< "$env"
    env_name="${env_info[0]}"
    install_method="${env_info[1]}"
    channel="${env_info[2]:-}"

    log "Processing environment: $env_name" "INFO"
    create_env $env_name $install_method $channel
    if [ $? -eq 0 ]; then
        run_benchmark $env_name
        conda deactivate
    else
        log "Skipping benchmark for $env_name due to setup failure" "WARNING"
    fi
done

# Post-cleanup if option is set
if $post_cleanup; then
    log "Performing post-cleanup" "INFO"
    for env in "${environments[@]}"; do
        IFS=' ' read -r -a env_info <<< "$env"
        env_name="${env_info[0]}"
        remove_env $env_name
    done
fi

log "NumPy benchmark script completed" "INFO"
echo "Benchmarks completed. Results are saved in *_benchmark.log files."
