#!/bin/bash

# exit on error
set -e

BASELINE_VERSION=${1:-3.7.2}
MASTER_VERSION=${2:-master}
TEST_DIR=${3:-tests}
TEST_RESULT_DIR=${4:-tests-results}
COMPARISON_REPORT_DIR=${5:-comparison-report}
REPORT_CSV=${6:-report.csv}
REPORT_HTML=${7:-perf-regression-report.html}
THRESHOLD=${8:-2}
TEST_DURATION=5m
DATE=$(date '+%Y_%m_%d-%H_%M_%S')
REPORT_HTML_DIR=${TEST_RESULT_DIR}/${DATE}
REPORT_HTML_LOC=${REPORT_HTML_DIR}/${REPORT_HTML}

html()
{

    echo "$1" >> ${REPORT_HTML_LOC}
}

run_benchmarks()
{
    CLIENTS=$1
    MEMBERS=$2

    for TEST_NAME in ${TEST_DIR}/*.*
    do
        echo Processing $TEST_NAME

        TEST_NAME=$(echo "${TEST_NAME}" | cut -d'.' -f1  | cut -d'/' -f2)

        BASELINE_TESTS_RESULT_DIR=${TEST_RESULT_DIR}/${DATE}/${CLIENTS}C-${MEMBERS}M/${TEST_NAME}/${BASELINE_VERSION}
        MASTER_TESTS_RESULT_DIR=${TEST_RESULT_DIR}/${DATE}/${CLIENTS}C-${MEMBERS}M/${TEST_NAME}/${MASTER_VERSION}
        PERF_COMPARISON_REPORT_DIR=${TEST_RESULT_DIR}/${DATE}/${CLIENTS}C-${MEMBERS}M/${TEST_NAME}/${COMPARISON_REPORT_DIR}

        echo "**********RUNNING TEST : "$TEST_NAME "***************"

        # Deleting baseline specific simulator properties
        cp template_simulator.properties simulator.properties

        #Runing baseline test
        echo "VERSION_SPEC=git=v"${BASELINE_VERSION} >> simulator.properties
        cat simulator.properties
        ./run $MEMBERS $CLIENTS $TEST_DURATION ${TEST_DIR}/${TEST_NAME} ${BASELINE_TESTS_RESULT_DIR}

        #Deleting master specific simulator properties
        rm simulator.properties
        cp template_simulator.properties simulator.properties

        #Runing Master version test
        echo "VERSION_SPEC=git="${MASTER_VERSION} >> simulator.properties
        cat simulator.properties
        ./run $MEMBERS $CLIENTS $TEST_DURATION ${TEST_DIR}/${TEST_NAME} ${MASTER_TESTS_RESULT_DIR}

        #Running benchmark/comparison report genertion report tool
        #    ${SIMULATOR_ROOT}/bin/benchmark-report ${PERF_COMPARISON_REPORT_DIR} ${BASELINE_TESTS_RESULT_DIR} ${MASTER_TESTS_RESULT_DIR}
        benchmark-report ${PERF_COMPARISON_REPORT_DIR} ${BASELINE_TESTS_RESULT_DIR} ${MASTER_TESTS_RESULT_DIR}

        #Parse benchmark/comparison report and get performance change
        ./parse-benchmark-report.sh ${TEST_NAME} ${PERF_COMPARISON_REPORT_DIR}/report.html ${THRESHOLD} \
            >> ${TEST_RESULT_DIR}/${DATE}/${CLIENTS}C-${MEMBERS}M/${REPORT_CSV}
    done
}

add_report(){
    TITLE=$1
    CLIENTS=$2
    MEMBERS=$3

    html "<h2>$TITLE</h2>"

    html "<h3>TESTS CONFIGURATION </h3>"
    html "<table border=\"1\">"
    html "<tr bgcolor=/"#0B97F3/"><td>NAME</td><td>VALUE</td></tr>"
    html "<tr><td>Baseline Hazelcast Version</td><td>"${BASELINE_VERSION}"</td></tr>"
    html "<tr><td>Master Hazelcast Version</td><td>"${MASTER_VERSION}"</td></tr>"
    html "<tr><td>Hazelcast Member Count</td><td>${MEMBERS}</td></tr>"
    html "<tr><td>Hazelcast Client Count</td><td>${CLIENTS}</td></tr>"
    html "<tr><td>Test Duration</td><td>${TEST_DURATION}</td></tr>"
    html "</table></br></br>"

    html "<h3>PERFORMANCE RESULTS</h3>"
    html "<table border=\"1\">"
    html "<tr bgcolor=/"#0B97F3/"><td>Benchmark</td>"
    html "<td>Throughput - "${BASELINE_VERSION}" (op/s)</td>"
    html "<td>Throughput - "${MASTER_VERSION}" (op/s)</td>"
    html "<td>Throughput Improvement %</td>"
    html "<td>Result</td>"
    html "</tr>"

    while read INPUT ; do
        test_name=$(echo $INPUT | cut -d',' -f1)
        baseline_number=$(echo $INPUT | cut -d',' -f2)
        master_number=$(echo $INPUT | cut -d',' -f3)
        regression=$(echo $INPUT | cut -d',' -f4)
        result=$(echo $INPUT | cut -d',' -f5)

        if [ "${result}" == "FAILED" ]
        then
            color_code="#FF0000/"
        else
            color_code="#00FF00"
        fi

        #get_color_code $result

        html "<tr bgcolor=/"${color_code}"/>"
        html "<td><a href=\"${CLIENTS}C-${MEMBERS}M/${test_name}/comparison-report/report.html\">${test_name}</a></td>"
        html "<td>${baseline_number}</td><td>${master_number}</td>"
        html "<td>${regression}</td><td>${result}</td>"
        html "</tr>"
    done < ${TEST_RESULT_DIR}/${DATE}/${CLIENTS}C-${MEMBERS}M/${REPORT_CSV}
    html "</table>"
}

init(){
    echo TEST_DIR=$TEST_DIR

    echo "Date : " $DATE

    # make sure that simulator is installed on the machines.
    cp template_simulator.properties simulator.properties
    provisioner --install

    # make sure the directory exists
    mkdir -p REPORT_HTML_DIR
}

init

html "<html><body>"

run_benchmarks 3 3
add_report "Clients"  3 3

run_benchmarks 0 3
add_report "Members only" 0 3

run_benchmarks 0 1
add_report "Single node" 0 1

html "</body></html>"