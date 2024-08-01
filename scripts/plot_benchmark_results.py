import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import ScalarFormatter
import argparse

def plot_benchmark_results(csv_file, output_file):
    # Read the CSV file
    df = pd.read_csv(csv_file)

    # Set up the plot style
    plt.style.use('ggplot')
    plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Arial', 'Helvetica', 'sans-serif']
    plt.rcParams['font.size'] = 12
    plt.rcParams['axes.titlesize'] = 16
    plt.rcParams['axes.labelsize'] = 14

    # Create the figure and axis objects
    fig, ax = plt.subplots(figsize=(12, 8))

    # Define a color cycle
    colors = plt.cm.tab10(np.linspace(0, 1, len(df['env_name'].unique())))

    # Plot lines for each environment and installation type
    for (env, install_type), group in df.groupby(['env_name', 'install_type']):
        ax.plot(group['matrix_size'], group['time'], 
                marker='o', linestyle='-', linewidth=2, markersize=8,
                label=f"{env} ({install_type})")

    # Set the scales to logarithmic
    ax.set_xscale('log')
    ax.set_yscale('log')

    # Customize the plot
    ax.set_xlabel('Matrix Size', fontweight='bold')
    ax.set_ylabel('Execution Time (seconds)', fontweight='bold')
    ax.set_title('NumPy Matrix Multiplication Benchmark', fontweight='bold', pad=20)

    # Customize tick labels
    ax.tick_params(axis='both', which='major', labelsize=12)
    
    # Use ScalarFormatter to display non-scientific tick labels
    ax.xaxis.set_major_formatter(ScalarFormatter())
    ax.yaxis.set_major_formatter(ScalarFormatter())

    # Add legend
    ax.legend(title='Environment (Install Type)', title_fontsize=12, fontsize=10, 
              loc='upper left', bbox_to_anchor=(1, 1))

    # Add grid
    ax.grid(True, which="both", ls="-", alpha=0.2)

    # Adjust layout and save
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Plot saved as {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plot NumPy benchmark results.")
    parser.add_argument("csv_file", help="Input CSV file with benchmark results")
    parser.add_argument("--output", default="benchmark_plot.png", help="Output plot file name")
    args = parser.parse_args()

    plot_benchmark_results(args.csv_file, args.output)
