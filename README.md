# ParFlow Installation and Usage Guide

This guide explains how to install and run ParFlow simulations using the provided build and submission scripts. The scripts are designed for use on TACC Stampede3 but can be adapted for similar HPC systems.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Running Simulations](#running-simulations)
- [Example Usage](#example-usage)
- [Monitoring Jobs](#monitoring-jobs)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Modules

The current build of ParFlow on TACC's Stampede3 uses the following module stack:

```bash
intel/24.0
impi/21.11
autotools/1.4
cmake/3.28.1
xalt/3.1.1
TACC
hypre/2.30.0
silo/git2024
hdf5/1.14.4
```

## Installation

1. First, clone or copy both scripts to your working directory:
   - `build_parflow.sh`
   - `submit_parflow.sh`

2. Make the scripts executable:
   ```bash
   chmod +x build_parflow.sh submit_parflow.sh
   ```

3. Run the installation script:
   ```bash
   ./build_parflow.sh --build-root $WORK/parflow_build --install-dir $WORK/parflow
   ```

4. After successful installation, add these lines to your `~/.bashrc` or `~/.profile`:
   ```bash
   export PARFLOW_DIR=$WORK/parflow
   export PATH=$PARFLOW_DIR/bin:$PATH
   ```

5. Source your profile to apply changes:
   ```bash
   source ~/.bashrc  # or source ~/.profile
   ```

## Running Simulations

### Input Directory Structure
Your test case directory should contain:
- `.pfb` files (ParFlow binary files)
- `drv_*` files (driver files)
- `.tcl` files (TCL scripts)

### Basic Job Submission

The script `submit_parflow.sh` provides a skeleton for initializing job runs given an input directory and TCL script.
For example, for a basic test run using 1 node with 4 MPI tasks:

```bash
./submit_parflow.sh /path/to/test/case script.tcl -N 1 -n 4

# Using relative paths
./submit_parflow.sh ./test/case script.tcl -N 1 -n 4
```

### Full Command Options
```bash
Usage: submit_parflow.sh INPUT_DIR TCL_SCRIPT [OPTIONS]

Required arguments:
  INPUT_DIR                      Directory containing ParFlow simulation input files (absolute or relative path)
  TCL_SCRIPT                     TCL script to execute (e.g., LW_NetCDF_Test.tcl)

Optional arguments:
  -p, --parflow-dir DIR         ParFlow installation directory (default: $HOME/parflow)
  -r, --root-dir DIR            Root directory for job execution (default: $SCRATCH)
  -s, --stage-only              Only stage the job, don't submit to SLURM

SLURM job options:
  -j, --job-name NAME           Job name (default: derived from INPUT_DIR)
  -N, --nodes N                 Number of nodes (default: 1)
  -n, --tasks N                 Number of MPI tasks (default: 4)
  -t, --time HH:MM:SS          Wall time limit (default: 00:30:00)
  -q, --queue QUEUE            SLURM partition/queue (default: skx-dev)
  -A, --account ACCOUNT        SLURM account/allocation
  -m, --mail-address EMAIL     Email address for job notifications
```

## Example Usage

Here's a complete example for running a test case:

```bash
# Using absolute path
./submit_parflow.sh ~/parflow_tests/test_case1 run_simulation.tcl \
    -N 1 \
    -n 4 \
    -t 01:00:00 \
    -q skx-dev \
    -A your_allocation \
    -m your.email@example.com \
    -j test_simulation

# Using relative path
./submit_parflow.sh ./test_case1 run_simulation.tcl \
    -N 1 \
    -n 4 \
    -t 01:00:00 \
    -q skx-dev \
    -A your_allocation \
    -j test_simulation
```

## Monitoring Jobs

**Note**: Monitoring scripts are experimental and may not work properly.

After job submission, you'll receive instructions for monitoring your job:

```bash
# Single status check
./parflow_status.sh -j <job_id>

# Continuous monitoring (updates every 10 seconds)
./monitor_parflow.sh -- -j <job_id>

# Continuous monitoring with custom interval
./monitor_parflow.sh -i 5 -- -j <job_id>

# Monitor with detailed output
./monitor_parflow.sh -- -j <job_id> -n 10
```

## Troubleshooting

### Common Issues

1. **Module Loading Errors**
   - Ensure all required modules are available on your system
   - Check module versions match your system's available versions

2. **Build Failures**
   - Check the build log in `$BUILD_ROOT/parflow_install_<timestamp>.log`
   - Verify compiler versions and environment variables

3. **Job Submission Errors**
   - Verify your allocation/account is active
   - Check queue limits and restrictions
   - Ensure input files exist in the specified directory
   - Verify the specified TCL script exists in the input directory

### Log Files
- Build logs: `$BUILD_ROOT/parflow_install_<timestamp>.log`
- Job output: `<job_name>.o<job_id>`
- Job errors: `<job_name>.e<job_id>`

For additional support or issues, consult the ParFlow documentation. For issues running on TACC, reach out to carlosd@tacc.utexas.edu or open an issue at this repository.