#!/bin/bash

#SBATCH -n 16

#SBATCH --output=%j.out
#SBATCH --error=%j.err
export OMPI_MCA_coll=^hcoll
ulimit -l unlimited
module load openmpi/5.0.5
export SPARTA_COMM_BUFFER_SIZE=4000

NP=$(srun hostname -s |wc -l)
mpirun -np $NP /data/user/shengpengju/sparta_20260714/src/spa_mpi <in.LH3