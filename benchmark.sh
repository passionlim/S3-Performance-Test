#!/bin/bash
cd `dirname $0`

echo "" > perf_result.log
for file_size in 128k 256k 512k 5m
do
  for thread_cnt in 1 2 4 8 16 32 128 256 512 1024
  do
    total_file_cnt=`echo "$thread_cnt * 2" | bc `
    total_file_cnt=$(( $total_file_cnt > 128 ? $total_file_cnt : 128 ))
    echo "thread_count=$thread_cnt, total_file_cnt=$total_file_cnt, file_size=$file_size " >&2
    ./perftest.sh -t $thread_cnt -n $total_file_cnt -s $file_size clean >> perf_result.log
    ./perftest.sh -t $thread_cnt -n $total_file_cnt -s $file_size write >> perf_result.log
    ./perftest.sh -t $thread_cnt -n $total_file_cnt -s $file_size read >> perf_result.log
  done
done




