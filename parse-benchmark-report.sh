#!/bin/bash

#cat report.html | grep -6 Throughput | tail -2 | awk -F "<|>" '{print "Benchmark-Name : " $5  " Throughput-Mean : "$9 }'

TEST_NAME=${1:-TEST}
HTML_REPORT_FILE=${2:-report.html}
THRESHOLD=${3:-5}

INDEX=0

#benchmark_name=$(cat $HTML_REPORT_FILE | grep -5 Throughput | tail -1 | awk -F "<|>" '{print $5}')"_Vs_"$(cat $HTML_REPORT_FILE | grep -6 Throughput | tail -1 | awk -F "<|>" '{print $5}')
benchmark_name=${TEST_NAME}

TPS_LHS=$(cat $HTML_REPORT_FILE | grep -5 Throughput | tail -1 | awk -F "<|>" '{print $9 }')
TPS_RHS=$(cat $HTML_REPORT_FILE | grep -6 Throughput | tail -1 | awk -F "<|>" '{print $9 }')

perf_change=$(echo $TPS_RHS/$TPS_LHS | bc -l)
perf_change=$(echo $perf_change-1 | bc -l)
perf_change=$(echo $perf_change*100 | bc -l)

grace_perf_change=$(echo $perf_change + ${THRESHOLD} | bc -l)

if [ 1 -eq "$(echo "${grace_perf_change} < 0" | bc)" ]
  then
    RESULT[${INDEX}]="FAILED"
  else
    RESULT[${INDEX}]="PASSED"
  fi

echo $benchmark_name,$TPS_LHS,$TPS_RHS,$perf_change,${RESULT[${INDEX}]}
