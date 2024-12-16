#!/bin/bash
#SBATCH -o output_.o%j             # Name of stdout output file
#SBATCH -e error_.e%j             # Name of stderr error file
#SBATCH -p skx                                # Queue (partition) name
#SBATCH -N 1                                     # Total # of nodes
#SBATCH --ntasks-per-node 48                     # Total # of cores
#SBATCH -t 01:00:00                               # Run time (hh:mm:ss)
#SBATCH -A TG-ATM170028                          # Allocation details


export inputFile="input_concurrent.dat"
export problemDir="/work2/09033/youngin/stampede3/PadeOps/problems/incompressible/half_channel_concurrent_files/padeops_runs_template"

cd /work2/09033/youngin/stampede3/PadeOps/build_opti/problems/incompressible
date
pwd

mpirun ./half_channel_concurrent $problemDir/$inputFile
