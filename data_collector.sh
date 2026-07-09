#!/bin/bash
LOG_FILE="./collector.log"
while true; do
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    level=$(echo "scale=2; 10 + ($RANDOM % 1000) / 100" | bc)
    echo "$timestamp water_level=$level"
    sleep 5
done >> "$LOG_FILE" 2>&1
