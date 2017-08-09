#!/bin/bash
set -e

folder="${1:-.}"

for i in ${folder}/*.json; do
    filename=$(basename "$i")
    pipeline_name="${filename%.*}"
    statistics=$(python pipeline-statistics.py "$i")
    echo "$pipeline_name,$statistics"
done
