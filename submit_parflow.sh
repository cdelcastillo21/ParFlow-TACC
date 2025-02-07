#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $(basename $0) INPUT_DIR [OPTIONS]"
    echo "Submit ParFlow simulation jobs"
    echo ""
    echo "Required arguments:"
    echo "  INPUT_DIR                      Directory containing ParFlow simulation input files"
    echo ""
    echo "Optional arguments:"
    echo "  -p, --parflow-dir DIR         ParFlow installation directory (default: \$HOME/parflow)"
    echo "  -r, --root-dir DIR            Root directory for job execution (default: \$SCRATCH)"
    echo "  -s, --stage-only              Only stage the job, don't submit to SLURM"
    echo ""
    echo "SLURM job options:"
    echo "  -j, --job-name NAME           Job name (default: derived from INPUT_DIR)"
    echo "  -N, --nodes N                 Number of nodes (default: 1)"
    echo "  -n, --tasks N                 Number of MPI tasks (default: 4)"
    echo "  -t, --time HH:MM:SS           Wall time limit (default: 00:30:00)"
    echo "  -q, --queue QUEUE             SLURM partition/queue (default: skx-dev)"
    echo "  -A, --account ACCOUNT         SLURM account/allocation"
    echo "  -m, --mail-address EMAIL      Email address for job notifications"
    echo ""
    echo "  -h, --help                    Show this help message"
}

# Function to validate directory exists
validate_dir() {
    if [ ! -d "$1" ]; then
        echo "Error: Directory $1 does not exist"
        exit 1
    fi
}

# Function to get base directory name
get_base_dirname() {
    # Remove trailing slash if present and get base name
    dirname "$(echo "$1" | sed 's:/*$::')" | xargs basename
}

# Parse command line arguments
INPUT_DIR=""
PARFLOW_DIR="$HOME/parflow"
ROOT_DIR="$SCRATCH"
STAGE_ONLY=false

# SLURM defaults
NODES=1
TASKS=4
TIME="00:30:00"
QUEUE="skx-dev"
ACCOUNT=""
MAIL_ADDRESS=""
JOB_NAME=""

# Check if no arguments provided
if [ $# -eq 0 ]; then
    print_usage
    exit 1
fi

# Parse positional and optional arguments
INPUT_DIR="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--parflow-dir)
            PARFLOW_DIR="$2"
            shift 2
            ;;
        -r|--root-dir)
            ROOT_DIR="$2"
            shift 2
            ;;
        -s|--stage-only)
            STAGE_ONLY=true
            shift
            ;;
        -j|--job-name)
            JOB_NAME="$2"
            shift 2
            ;;
        -N|--nodes)
            NODES="$2"
            shift 2
            ;;
        -n|--tasks)
            TASKS="$2"
            shift 2
            ;;
        -t|--time)
            TIME="$2"
            shift 2
            ;;
        -q|--queue)
            QUEUE="$2"
            shift 2
            ;;
        -A|--account)
            ACCOUNT="$2"
            shift 2
            ;;
        -m|--mail-address)
            MAIL_ADDRESS="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Function to validate directory exists
validate_dir() {
    if [ ! -d "$1" ]; then
        echo "Error: Directory $1 does not exist"
        exit 1
    fi
}

# Function to get base directory name
get_base_dirname() {
    # Remove trailing slash if present and get base name
    dirname "$(echo "$1" | sed 's:/*$::')" | xargs basename
}

# Function to generate timestamp
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Validate input directory
validate_dir "$INPUT_DIR"
validate_dir "$PARFLOW_DIR"
validate_dir "$ROOT_DIR"

# Set job name if not provided
if [ -z "$JOB_NAME" ]; then
    JOB_NAME="ParFlow_$(get_base_dirname "$INPUT_DIR")"
fi

# Create timestamped job directory
TIMESTAMP=$(get_timestamp)
RUN_NAME="${JOB_NAME/ParFlow_/}"  # Remove ParFlow_ prefix if present
JOB_DIR="${ROOT_DIR}/${RUN_NAME}_${TIMESTAMP}"
mkdir -p "$JOB_DIR"

# Create SLURM submit script with conditional sections
{
    cat << EOL
#!/bin/bash
#SBATCH -J ${JOB_NAME}      # Job name
#SBATCH -o ${JOB_NAME}.o%j  # Name of stdout output file
#SBATCH -e ${JOB_NAME}.e%j  # Name of stderr error file
EOL

    # Add conditional SLURM directives
    if [ -n "$ACCOUNT" ]; then
        echo "#SBATCH -A $ACCOUNT             # Allocation"
    fi
    
    cat << EOL
#SBATCH -p $QUEUE           # Queue (partition) name
#SBATCH -N $NODES          # Total # of nodes 
#SBATCH -n $TASKS          # Total # of mpi tasks
#SBATCH -t $TIME          # Run time (hh:mm:ss)
EOL

    # Add mail options if specified
    if [ -n "$MAIL_ADDRESS" ]; then
        echo "#SBATCH --mail-user=$MAIL_ADDRESS"
        echo "#SBATCH --mail-type=all    # Send email at begin and end of job"
    fi

    cat << EOL

# Load required modules
module purge
module load intel/24.0
module load impi/21.11
module load cmake/3.28.1
module load hypre/2.30.0
module load silo/git2024
module load hdf5/1.14.4
module load netcdf/4.9.2
module load pnetcdf/1.12.3

# Set ParFlow directory
export PARFLOW_DIR=${PARFLOW_DIR}
# Add ParFlow binary directory to path
export PATH=\$PARFLOW_DIR/bin:\$PATH

# Set working directory (already created by submit script)
WORK_DIR=${JOB_DIR}
cd \$WORK_DIR

# Copy input files from source directory
cp -r ${INPUT_DIR}/* .

# Run ParFlow using TCL script
tclsh LW_NetCDF_Test.tcl

# Copy results back to submission directory
cp -r * \$SLURM_SUBMIT_DIR/
EOL
} > "${JOB_DIR}/submit.sh"

# Make submit script executable
chmod +x "${JOB_DIR}/submit.sh"

# If not stage-only, submit the job
if [ "$STAGE_ONLY" = false ]; then
    cd "$JOB_DIR"
    # Capture the entire sbatch output and get the last line, then extract the last word
    SUBMITTED_JOB=$(sbatch submit.sh | tail -n1 | awk '{print $NF}')
    
    # Verify we got a numeric job ID
    if [[ ! "$SUBMITTED_JOB" =~ ^[0-9]+$ ]]; then
        echo "Error: Failed to get valid job ID from submission"
        exit 1
    fi
    
    echo "Job submitted in directory: $JOB_DIR"
    echo "Job name: $JOB_NAME"
    echo "Job ID: $SUBMITTED_JOB"
    echo ""
    echo "To monitor this job:"
    echo "  Single status check:"
    echo "    ./parflow_status.sh -j $SUBMITTED_JOB"
    echo ""
    echo "  Continuous monitoring (updates every 10 seconds):"
    echo "    ./monitor_parlfow.sh -- -j $SUBMITTED_JOB"
    echo ""
    echo "  Continuous monitoring with custom interval (e.g., 5 seconds):"
    echo "    ./monitor_parflow.sh -i 5 -- -j $SUBMITTED_JOB"
    echo ""
    echo "  Monitor with detailed output (10 lines of log files):"
    echo "    ./monitor_parflow.sh -- -j $SUBMITTED_JOB -n 10"
else
    echo "Job staged in directory: $JOB_DIR"
    echo "Job name: $JOB_NAME"
    echo ""
    echo "To submit this job:"
    echo "  cd $JOB_DIR"
    echo "  sbatch submit.sh"
fi