#!/bin/bash

# Set default values
verbose=false
log_file="numpy_benchmark.log"
csv_file="numpy_benchmark_results.csv"
environments=()

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS] ENV1 ENV2 ..."
    echo "Run NumPy benchmarks in specified conda environments."
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message and exit"
    echo "  -v, --verbose        Enable verbose output"
    echo "  -l, --log FILE       Specify a log file (default: numpy_benchmark.log)"
    echo "  -c, --csv FILE       Specify a CSV output file (default: numpy_benchmark_results.csv)"
    echo
    echo "ENV1, ENV2, ... are the names of existing conda environments to benchmark"
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
        -c|--csv)
            csv_file="$2"
            shift 2
            ;;
        *)
            environments+=("$1")
            shift
            ;;
    esac
done

# Check if environments were specified
if [ ${#environments[@]} -eq 0 ]; then
    echo "Error: No environments specified."
    show_help
    exit 1
fi

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

# Function to get environment path
get_env_path() {
    local env_name=$1
    conda env list | grep "$env_name" | awk '{print $2}'
}

# Function to determine installation type
get_install_type() {
    local env_name=$1
    source activate $env_name
    if pip list | grep -q numpy; then
        echo "pip"
    elif conda list | grep -q numpy; then
        echo "conda"
    else
        echo "unknown"
    fi
    conda deactivate
}

# Function to run benchmark
run_benchmark() {
    env_name=$1
    log "Running benchmark in $env_name" "INFO"
    
    # Activate the environment
    source activate $env_name
    if [ $? -ne 0 ]; then
        log "Failed to activate environment $env_name" "ERROR"
        return 1
    fi

    # Get disk space
    env_path=$(get_env_path $env_name)
    if [ -z "$env_path" ]; then
        log "Failed to get path for environment $env_name" "ERROR"
        return 1
    fi
    disk_space=$(du -sh "$env_path" | cut -f1)
    log "Disk space used by $env_name: $disk_space" "INFO"

    # Determine installation type
    install_type=$(get_install_type $env_name)
    log "NumPy installation type for $env_name: $install_type" "INFO"

    # Run benchmark
    python - <<EOF
import numpy as np
import time
import psutil
import csv

sizes = [100, 200, 500, 1000, 2000, 5000, 10000]

results = []

for size in sizes:
    a = np.random.rand(size, size)
    b = np.random.rand(size, size)

    start_time = time.time()
    c = np.dot(a, b)
    end_time = time.time()

    elapsed_time = end_time - start_time
    memory_usage = psutil.Process().memory_info().rss / (1024 * 1024)  # in MB

    results.append({
        'env_name': '$env_name',
        'install_type': '$install_type',
        'matrix_size': size,
        'time': elapsed_time,
        'memory': memory_usage
    })

    print(f"Size: {size}x{size}, Time: {elapsed_time:.4f} seconds, Memory: {memory_usage:.2f} MB")

# Append results to CSV file
with open('$csv_file', 'a', newline='') as csvfile:
    fieldnames = ['env_name', 'install_type', 'matrix_size', 'time', 'memory']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    
    # Write header if file is empty
    if csvfile.tell() == 0:
        writer.writeheader()
    
    for row in results:
        writer.writerow(row)

print(f"NumPy version: {np.__version__}")
print(f"NumPy config: {np.show_config()}")
EOF

    log "Benchmark for $env_name completed" "INFO"
    conda deactivate
}

# Main execution
log "Starting NumPy benchmark script" "INFO"

# Clear existing CSV file
> "$csv_file"

for env_name in "${environments[@]}"; do
    log "Processing environment: $env_name" "INFO"
    
    # Check if environment exists
    if conda env list | grep -q "$env_name"; then
        run_benchmark $env_name
    else
        log "Environment $env_name does not exist, skipping" "WARNING"
    fi
done

log "NumPy benchmark script completed" "INFO"
echo "Benchmarks completed. Results are saved in $csv_file"
