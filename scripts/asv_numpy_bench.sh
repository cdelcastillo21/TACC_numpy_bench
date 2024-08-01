#!/bin/bash

# Exit on error
set -e

# Check if asv is installed
if ! command -v asv &> /dev/null
then
    echo "asv is not installed. Please install it using: pip install asv"
    exit 1
fi

# Clone NumPy repository if it doesn't exist
if [ ! -d "numpy" ]; then
    git clone https://github.com/numpy/numpy.git
fi

# Change to NumPy directory
cd numpy

# Update the repository
git pull

# Change to benchmarks directory
cd benchmarks

# Run all benchmarks (this may take a while)
# echo "Running all NumPy benchmarks..."
# asv run --python=same

# Run a specific benchmark module (e.g., bench_core)
echo "Running bench_core benchmarks..."
asv run --python=same -b bench_core

# Run benchmarks with quick mode (for testing)
# echo "Running quick benchmarks for Ufunc..."
# export REGEXP="bench.*Ufunc"
# asv run --dry-run --show-stderr --python=same --quick -b $REGEXP

# Generate HTML output
echo "Generating HTML output..."
asv publish

# Preview the results
echo "Preview available. Run 'asv preview' to view in your browser."

echo "Benchmark run complete."
