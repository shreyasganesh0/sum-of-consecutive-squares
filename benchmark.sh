#!/bin/bash

N=1000000
K=20
OUTPUT_DIR="outputs"

echo "Starting benchmark runs..."
echo "This may take a while."

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "=========================="

for workers in 2 4 8
do
  output_file="$OUTPUT_DIR/run_${workers}_workers.txt"
  echo "--- Running with $workers workers..."
  gleam run -- $N $K $workers > "$output_file"
done

for ((workers=10; workers<=200; workers+=10))
do
  output_file="$OUTPUT_DIR/run_${workers}_workers.txt"
  echo "--- Running with $workers workers..."
  gleam run -- $N $K $workers > "$output_file"
done

for ((workers=200; workers<=1500; workers+=100))
do
    output_file="$OUTPUT_DIR/run_${workers}_workers.txt"
    echo "--- Running with $workers workers..."
    gleam run -- $N $K $workers > "$output_file"
done

echo ""
echo "=========================="
echo "All benchmark runs are complete."
echo ""

echo "Analyzing results..."

best_time_workers=0
best_time=999999999.0
best_ratio_workers=0
best_ratio=0.0

for file in "$OUTPUT_DIR"/*.txt; do
  workers=$(echo "$file" | sed -n 's/.*run_\([0-9]*\)_workers\.txt/\1/p')

  current_time=$(grep "REAL TIME:" "$file" | awk '{print $3}' | sed 's/s//')
  current_ratio=$(grep "Ratio:" "$file" | awk '{print $7}')

  if [[ -n "$current_time" && -n "$current_ratio" ]]; then
    
    if (( $(awk -v a="$current_time" -v b="$best_time" 'BEGIN {print (a < b)}') )); then
      best_time="$current_time"
      best_time_workers="$workers"
    fi

    if (( $(awk -v a="$current_ratio" -v b="$best_ratio" 'BEGIN {print (a > b)}') )); then
      best_ratio="$current_ratio"
      best_ratio_workers="$workers"
    fi
  fi
done

echo ""
echo "=========================="
echo "Analysis Complete"
echo "=========================="
echo ""
echo " Fastest Run:"
echo "   - Workers: $best_time_workers"
echo "   - Real Time: ${best_time}s"
echo ""
echo " Best Parallelism (Highest Ratio):"
echo "   - Workers: $best_ratio_workers"
echo "   - CPU/Real Time Ratio: $best_ratio"
echo ""
