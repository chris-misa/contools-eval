#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <date_stamp>"
fi

for i in $1/$1_*; do
  rscript genReport.r $i
done
