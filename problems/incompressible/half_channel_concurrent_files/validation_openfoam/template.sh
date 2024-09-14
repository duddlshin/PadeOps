#!/bin/bash

#SBATCH -J half_channel                  # Job name
#SBATCH -n 32                            # Core count
#SBATCH -N 2                             # Node count
#SBATCH -t 10:00:00                      # Wall clock limit
#SBATCH -p cpu                           # Queue 
#SBATCH -o output_%j.txt                 # Redirect output to output_JOBID.txt
#SBATCH -e error_%j.txt                  # Redirect errors to error_JOBID.txt
#SBATCH --mail-type=BEGIN,END            # Mail when job starts and ends
#SBATCH --mail-user=youngin@mit.edu      # Email recipient

export inputFile="input_concurrent.dat"
export problemDir="/home/ctrsp-2024/youngin/mypadeops/PadeOps/problems/incompressible/half_channel_concurrent_files/validation_openfoam"

cd /home/ctrsp-2024/youngin/mypadeops/PadeOps/build_opti/problems/incompressible
date
pwd

mpirun ./half_channel_concurrent $problemDir/$inputFile
