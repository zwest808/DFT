#!/bin/bash

#chmod +x master.sh run_master.sh
#ls -l master.sh run_master.sh
# Run commands and generate outputs for structure
# Parameter sweep across ecut, k-points, pseudopotentials, etc., and generate data/plots
# Hyperparameters:

LATTICE_PARAM_A=$(awk 'NR==1 {print $1}' "structure/cell_params") # sets lattice params to the ones in cell_params
LATTICE_PARAM_C=$(awk 'NR==3 {print $3}' "structure/cell_params")

OCCUPATION="smearing"
SMR_METHOD="gauss"
DEGAUSS=.02

ECUTWFC=80 #50
ECUTRHO=550 #550
K_POINTS="6 6 6 0 0 0"

E_MAXSTEP=100
DIAG_THRESHOLD=1.0d-4
SCF_CONV_THR=1.0d-4
NSCF_CONV_THR=1.0d-4
NBANDS=16 # number of valence electrons in system, Al has 3 and N has 5 therefore 3*#Al + 5*#N = 8*#Al because #N = #Al

MIX_MODE="TF"
MIX_BETA=.25 # initial mixing parameter
MIXING_NDIM=8

RELAX_POSITIONS=false # if we want to cell relax then use those relaxed positions and parameters

CORES=48

VERBOSITY="default" # for dft calculation outputs

name="C_bulk"

# Run master script
./master.sh $LATTICE_PARAM_A $LATTICE_PARAM_C $OCCUPATION $SMR_METHOD $DEGAUSS $ECUTWFC $ECUTRHO "$K_POINTS" $E_MAXSTEP $DIAG_THRESHOLD $SCF_CONV_THR $NSCF_CONV_THR $MIX_MODE $MIX_BETA $MIXING_NDIM $RELAX_POSITIONS $NBANDS $CORES $VERBOSITY $name