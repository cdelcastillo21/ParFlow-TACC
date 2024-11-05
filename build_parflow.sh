#!/bin/bash
#===============================================================================
# ParFlow Installation Script for TACC Stampede3
#===============================================================================
# 
# Author: Carlos del-Castillo-Negrete
# Email: carlosd@tacc.utexas.edu
# Date: October 30, 2024
# Last Modified: October 30, 2024
#
# Purpose:
#   Automates the installation of ParFlow on TACC Stampede3 using Intel compilers
#   and existing module system. This script follows the installation procedure
#   documented in the ParFlow wiki with adaptations for the TACC environment.
#
# Reference:
#   Original installation guide:
#   https://github.com/parflow/parflow/wiki/Ubuntu-20.04.1-LTS---Factory-condition
#
# Requirements:
#   - TACC Stampede3 access with required modules:
#     - intel/24.0
#     - impi/21.11
#     - autotools/1.4
#     - cmake/3.28.1
#     - xalt/3.1.1
#     - TACC
#     - hypre/2.30.0
#     - silo/git2024
#     - hdf5/1.14.4
#
# Usage:
#   ./install_parflow.sh [OPTIONS]
#   
#   Options:
#     -h, --help              Show help message
#     -b, --build-root DIR    Set build root directory
#     -i, --install-dir DIR   Set ParFlow installation directory
#
# Example:
#   ./install_parflow.sh --build-root /work/$USER/parflow_build \
#                       --install-dir /work/$USER/parflow
#
# Notes:
#   - Script creates timestamped log files in the build directory
#   - All build steps are logged and checked for errors
#   - Installation can be customized via command line arguments
#   - Default paths can be modified by changing DEFAULT_* variables
#
# Exit Codes:
#   0 - Success
#   1 - Error (with specific error message in log)
#
#===============================================================================

# Exit on error
set -e

# Default paths
DEFAULT_BUILD_ROOT="$HOME/parflow_build"
DEFAULT_INSTALL_DIR="$HOME/parflow"

# Initialize variables with defaults
BUILD_ROOT="$DEFAULT_BUILD_ROOT"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
LOG_FILE=""
SCRIPT_SUCCESS=true

# Logging function
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "${LOG_FILE}"
}

# Error logging function
error_log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $1" | tee -a "${LOG_FILE}"
    SCRIPT_SUCCESS=false
}

# Function to check if command succeeded
check_command() {
    if [ $? -ne 0 ]; then
        error_log "$1 failed"
        print_failure_message
        exit 1
    fi
}

# Print failure message
print_failure_message() {
    cat << EOF | tee -a "${LOG_FILE}"

==========================================================================
INSTALLATION FAILED!

See log file for details: ${LOG_FILE}
==========================================================================
EOF
}

# Print success message
print_success_message() {
    cat << EOF | tee -a "${LOG_FILE}"

==========================================================================
Installation completed successfully!

To use ParFlow, add these lines to your ~/.bashrc or ~/.profile:

export PARFLOW_DIR=${INSTALL_DIR}
export PATH=\$PARFLOW_DIR/bin:\$PATH

Log file: ${LOG_FILE}
==========================================================================
EOF
}

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Install ParFlow on TACC Stampede3 with Intel compilers.

Options:
    -h, --help              Show this help message
    -b, --build-root DIR    Set the build root directory
                           (default: $DEFAULT_BUILD_ROOT)
    -i, --install-dir DIR   Set the ParFlow installation directory
                           (default: $DEFAULT_INSTALL_DIR)
    
Examples:
    $(basename "$0")
    $(basename "$0") --build-root /work/\$USER/parflow_build --install-dir /work/\$USER/parflow

Notes:
    - Requires modules: intel, impi, autotools, cmake, xalt, TACC, hypre, silo
    - Will create build directory if it doesn't exist
    - Log file will be created in the build root directory
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -b|--build-root)
            BUILD_ROOT="$2"
            shift 2
            ;;
        -i|--install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Setup logging
timestamp=$(date '+%Y%m%d_%H%M%S')
mkdir -p "${BUILD_ROOT}"
LOG_FILE="${BUILD_ROOT}/parflow_install_${timestamp}.log"

# Start logging
log "Starting ParFlow installation"
log "Build root: ${BUILD_ROOT}"
log "Install directory: ${INSTALL_DIR}"
log "Log file: ${LOG_FILE}"

# Load required modules
log "Loading required modules..."
module purge
module load intel/24.0
module load impi/21.11
module load autotools/1.4
module load cmake/3.28.1
module load xalt/3.1.1
module load TACC
module load hypre/2.30.0
module load silo/git2024
module load hdf5/1.14.4
check_command "Module loading"

# Log loaded modules
log "Loaded modules:"
module list 2>&1 | tee -a "${LOG_FILE}"

# Export installation directory
export PARFLOW_DIR="${INSTALL_DIR}"
log "Set PARFLOW_DIR=${PARFLOW_DIR}"

# Create directory structure
log "Creating directory structure..."
mkdir -p "${BUILD_ROOT}"
cd "${BUILD_ROOT}" || {
    error_log "Failed to change to build directory ${BUILD_ROOT}"
    exit 1
}

# Clone ParFlow repository
log "Cloning ParFlow repository..."
if [ -d "parflow" ]; then
    log "ParFlow repository already exists, updating..."
    cd parflow || {
        error_log "Failed to change to parflow directory"
        exit 1
    }
    git pull
    check_command "Git pull"
else
    git clone https://github.com/parflow/parflow.git --branch master --single-branch
    check_command "Git clone"
    cd parflow || {
        error_log "Failed to change to parflow directory"
        exit 1
    }
fi

# Create and enter build directory
log "Creating build directory..."
rm -rf build
mkdir -p build
cd build || {
    error_log "Failed to change to build directory"
    exit 1
}

# Configure with CMake
log "Configuring ParFlow with CMake..."
if ! cmake .. \
    -DCMAKE_INSTALL_PREFIX="${PARFLOW_DIR}" \
    -DPARFLOW_AMPS_LAYER=mpi1 \
    -DPARFLOW_AMPS_SEQUENTIAL_IO=true \
    -DPARFLOW_ENABLE_TIMING=true \
    -DPARFLOW_HAVE_CLM=ON \
    -DHYPRE_ROOT="${TACC_HYPRE_DIR}" \
    -DSILO_ROOT="${TACC_SILO_DIR}" \
    -DCMAKE_C_COMPILER="${TACC_CC}" \
    -DCMAKE_CXX_COMPILER="${TACC_CXX}" \
    -DCMAKE_Fortran_COMPILER="${TACC_FC}" \
    -DMPIEXEC_EXECUTABLE="${TACC_IMPI_BIN}/mpirun" 2>&1 | tee -a "${LOG_FILE}"
then
    error_log "CMake configuration failed"
    exit 1
fi

# Build
log "Building ParFlow..."
if ! make -j4 2>&1 | tee -a "${LOG_FILE}"
then
    error_log "Build failed"
    exit 1
fi

# Install
log "Installing ParFlow..."
if ! make install 2>&1 | tee -a "${LOG_FILE}"
then
    error_log "Installation failed"
    exit 1
fi

# Run tests
log "Running tests..."
if ! make test 2>&1 | tee -a "${LOG_FILE}"
then
    error_log "Tests failed"
    exit 1
fi

# Check if script completed successfully
if [ "$SCRIPT_SUCCESS" = true ]; then
    log "Installation completed successfully"
    print_success_message
else
    error_log "Installation failed"
    print_failure_message
    exit 1
fi
