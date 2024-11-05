#!/bin/bash

# Help message
usage() {
    echo "Usage: $0 [-i INTERVAL] [-- PARFLOW_STATUS_ARGS]"
    echo "  -i INTERVAL : Update interval in seconds (default: 10)"
    echo "  -h         : Show this help message"
    echo ""
    echo "Additional arguments after -- are passed to parflow_status.sh"
    echo "Example:"
    echo "  $0 -i 5 -- -j 1234,5678 -n 10"
    echo "  $0 -- --job_ids 1234 --num_lines 3"
    exit 1
}

# Default interval
INTERVAL=10
STATUS_ARGS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i)
            INTERVAL="$2"
            shift 2
            ;;
        -h)
            usage
            ;;
        --)
            shift
            STATUS_ARGS="$@"
            break
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Call watch on the status script
if [ -z "$STATUS_ARGS" ]; then
    watch -n $INTERVAL $SCRIPT_DIR/parflow_status.sh
else
    watch -n $INTERVAL "$SCRIPT_DIR/parflow_status.sh $STATUS_ARGS"
fi