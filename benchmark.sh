#!/bin/bash

# --- Configuration ---
N=100000000
K=20
OUTPUT_DIR="outputs"

# --- Script Start ---
echo "Starting benchmark runs..."

# Create the output directory if it doesn't already exist
mkdir -p "$OUTPUT_DIR"

echo "=========================="

# 1. Run with specific worker counts: 2, 4, and 8
for workers in 2 4 8
do
  output_file="$OUTPUT_DIR/run_${workers}_workers.txt"
  echo ""
  echo "--- Running with $workers workers (saving to $output_file) ---"
  # Redirect the command's output to the file
  gleam run $N $K $workers > "$output_file"
done

# 2. Run with worker counts from 10 to 500, incrementing by 10
for ((workers=10; workers<=500; workers+=10))
do
  output_file="$OUTPUT_DIR/run_${workers}_workers.txt"
  echo ""
  echo "--- Running with $workers workers (saving to $output_file) ---"
  # Redirect the command's output to the file
  gleam run $N $K $workers > "$output_file"
done

echo ""
echo "=========================="
echo "All benchmark runs are complete. Results are in the '$OUTPUT_DIR' directory."
