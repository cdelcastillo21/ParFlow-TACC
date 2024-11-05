#!/bin/bash
#==============================================================================
# ParFlow Job Status Monitor
#==============================================================================
# 
# Author: Carlos del-Castillo-Negrete
# Email: carlosd@tacc.utexas.edu
# Date: October 30, 2024
#
# Purpose:
#   Monitors the status of ParFlow jobs on HPC SLURM systems, providing 
#   information about job progress, solver status, and output logs. Can monitor 
#   multiple jobs simultaneously and provides detailed status information.
#
# Usage:
#   ./parflow_status.sh [OPTIONS]
#
# Options:
#   -h, --help              Show this help message
#   -j, --job_ids IDS      Comma-separated list of job IDs to monitor
#   -n, --num_lines LINES   Number of lines to show from log files (default: 5)
#
# Example:
#   ./parflow_status.sh -j 1234,5678 -n 10
#   ./parflow_status.sh --job_ids 1234 --num_lines 3
#
# Output Includes:
#   - Job ID and runtime
#   - Number of completed timesteps
#   - Latest solver iterations
#   - Recent errors (if any)
#   - Storage usage
#   - Job status
#   - Detailed log output
#
#==============================================================================

# Default values
NUM_LINES=5
JOB_IDS=""

# Help function
show_help() {
    head -n 32 "$0" | tail -n 28
    exit 0
}

get_solver_info() {
    local WORK_DIR=$1
    local OUTPUT_TXT="$WORK_DIR/*.out.txt"
    local TIMING_CSV="$WORK_DIR/*.out.timing.csv"
    local SOLVER_STATUS=""
    
    # Check if solver has completed
    if [ -f $OUTPUT_TXT ] && grep -q "Problem solved" $OUTPUT_TXT; then
        SOLVER_STATUS="Complete"
    # Check if solver is running by looking at timing file
    elif [ -f $TIMING_CSV ]; then
        local SOLVER_TIME=$(tail -n1 $TIMING_CSV | cut -d',' -f2)
        if [ ! -z "$SOLVER_TIME" ] && [ "$SOLVER_TIME" != "0.000000" ]; then
            SOLVER_STATUS="Running (${SOLVER_TIME}s)"
        else
            SOLVER_STATUS="Starting"
        fi
    else
        SOLVER_STATUS="Unknown"
    fi
    
    echo "$SOLVER_STATUS"
}


# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -j|--job_ids)
            JOB_IDS="${2//,/ }"  # Convert comma-separated list to space-separated
            shift 2
            ;;
        -n|--num_lines)
            NUM_LINES="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Get running ParFlow jobs
if [ -z "$JOB_IDS" ]; then
    # If no job IDs specified, get all running ParFlow jobs
    JOBS=$(squeue -u $USER -o "%.8i %.9P %.8j %.8u %.2t %.10M %.6D %R" | grep ParFlow | awk '{print $1}')
else
    # Filter for specified job IDs
    JOBS="$JOB_IDS"
fi

if [ -z "$JOBS" ]; then
    echo "No running ParFlow jobs found"
    exit 0
fi

# Print header
echo "--------------------------------------------------------------------------------"
printf "%-12s | %-10s | %-15s | %-12s | %-15s | %-15s | %-10s\n" \
    "Job ID" "Runtime" "Timesteps" "Solver Its" "Last Error" "Storage" "Status"
echo "--------------------------------------------------------------------------------"

# Process each job
for JOBID in $JOBS; do
    # Check if job exists
    if ! squeue -j $JOBID &>/dev/null; then
        echo "Job $JOBID not found"
        continue
    fi
    
    WORK_DIR=$SCRATCH/parflow_run_${JOBID}
    
    # Get runtime
    RUNTIME=$(squeue -j $JOBID -o "%M" | tail -n1)
    
    # Find pressure files (using wildcard to match any prefix)
    TIMESTEPS=$(ls -1 $WORK_DIR/*.out.press.*.pfb 2>/dev/null | wc -l)
    
    # Find solver log (*.out.kinsol.log)
    SOLVER_LOG=$(find $WORK_DIR -name "*.out.kinsol.log" 2>/dev/null | head -n1)
    if [ -f "$SOLVER_LOG" ]; then
        SOLVER_ITS=$(tail -n 20 "$SOLVER_LOG" | grep "number of nonlinear iterations" | tail -n1 | awk '{print $NF}')
    else
        SOLVER_ITS="N/A"
    fi
    
    # Find main output log (*.out.log)
    OUTPUT_LOG=$(find $WORK_DIR -name "*.out.log" 2>/dev/null | head -n1)
    if [ -f "$OUTPUT_LOG" ]; then
        LAST_ERROR=$(tail -n 20 "$OUTPUT_LOG" | grep -i "error" | tail -n1 | cut -c1-15)
        if [ -z "$LAST_ERROR" ]; then
            LAST_ERROR="None"
        fi
    else
        LAST_ERROR="None"
    fi
    
    # Get storage usage
    if [ -d "$WORK_DIR" ]; then
        STORAGE=$(du -sh $WORK_DIR 2>/dev/null | cut -f1)
    else
        STORAGE="N/A"
    fi
    
    # Get job status
    STATUS=$(squeue -j $JOBID -o "%.2t" | tail -n1)
    
    # Print job info row
    printf "%-12s | %-10s | %-15s | %-12s | %-15s | %-15s | %-10s\n" \
        "$JOBID" "$RUNTIME" "$TIMESTEPS" "$SOLVER_ITS" "$LAST_ERROR" "$STORAGE" "$STATUS"
done

echo "--------------------------------------------------------------------------------"

# Print summary section
echo -e "\nDetailed Status for Running Jobs:"
echo "--------------------------------------------------------------------------------"
for JOBID in $JOBS; do
    if ! squeue -j $JOBID &>/dev/null; then
        continue
    fi
    
    WORK_DIR=$SCRATCH/parflow_run_${JOBID}
    
    # Find the appropriate log files
    SOLVER_LOG=$(find $WORK_DIR -name "*.out.kinsol.log" 2>/dev/null | head -n1)
    OUTPUT_LOG=$(find $WORK_DIR -name "*.out.log" 2>/dev/null | head -n1)
    
    echo "Job $JOBID:"
    echo "  Latest Solver Output ($SOLVER_LOG):"
    if [ -f "$SOLVER_LOG" ]; then
        tail -n $NUM_LINES "$SOLVER_LOG" | sed "s/^/    /"
    else
        echo "    No solver log found"
    fi
    
    echo "  Latest Output ($OUTPUT_LOG):"
    if [ -f "$OUTPUT_LOG" ]; then
        tail -n $NUM_LINES "$OUTPUT_LOG" | sed "s/^/    /"
    else
        echo "    No output log found"
    fi

    SOLVER_STATUS=$(get_solver_info "$WORK_DIR")
    echo "  Solver Status: $SOLVER_STATUS"
    
    if [ -f "$WORK_DIR"/*.out.timing.csv ]; then
        echo "  Performance Metrics:"
        echo "    Total Runtime: $(tail -n1 "$WORK_DIR"/*.out.timing.csv | cut -d',' -f2)s"
        echo "    CLM Time: $(grep "CLM" "$WORK_DIR"/*.out.timing.csv | cut -d',' -f2)s"
        echo "    I/O Time: $(grep "PFB I/O" "$WORK_DIR"/*.out.timing.csv | cut -d',' -f2)s"
    fi

    echo "--------------------------------------------------------------------------------"
done