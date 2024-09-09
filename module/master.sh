#!/bin/bash

# check for correct # of arguments
if [ "$#" -lt 19 ]; then
    echo "Usage: $0 LATTICE_PARAM_A LATTICE_PARAM_C OCCUPATION SMR_METHOD DEGAUSS ECUTWFC ECUTRHO K_POINTS E_MAXSTEP DIAG_THRESHOLD SCF_CONV_THR NSCF_CONV_THR MIX_MODE MIX_BETA MIXING_NDIM RELAX_POSITIONS NBANDS VERBOSITY CORES"
    exit 1
fi

# Inputs
LATTICE_PARAM_A=$1
LATTICE_PARAM_C=$2
OCCUPATION=$3
SMR_METHOD=$4
DEGAUSS=$5
ECUTWFC=$6
ECUTRHO=$7
K_POINTS=$8
E_MAXSTEP=$9
DIAG_THRESHOLD=${10}
SCF_CONV_THR=${11}
NSCF_CONV_THR=${12}
MIX_MODE=${13}
MIX_BETA=${14}
MIXING_NDIM=${15}
RELAX_POSITIONS=${16}
NBANDS=${17}
CORES=${18}
VERBOSITY=${19}
name=${20}

# directories
TEMPLATE_DIR="./templates"
INPUT_DIR="./inputs"
OUTPUT_DIR="../data/${name}"
#HYPERPARAMETER_DIR="$OUTPUTDIR/hyperparameters.in"
BANDS_DIR="$OUTPUT_DIR/bands"
DOS_DIR="$OUTPUT_DIR/dos"
PDOS_DIR="$OUTPUT_DIR/dos/pdos_files"
FUNCTIONS_DIR="./plotting_functions"

# create output directories
mkdir -p $OUTPUT_DIR
mkdir -p $INPUT_DIR
mkdir -p $BANDS_DIR
mkdir -p $DOS_DIR
mkdir -p $PDOS_DIR
# clear old files
find "$PDOS_DIR" -mindepth 1 -delete

HYPERPARAMETER_DIR="$OUTPUT_DIR/hyperparameters"
if [ ! -f "$HYPERPARAMETER_DIR" ]; then
  #echo "File $HYPERPARAMETER_DIR does not exist. Creating it..."
  touch "$HYPERPARAMETER_DIR"
fi

# file permissions
chmod 644 "$HYPERPARAMETER_DIR"

ATOMIC_POSITIONS_DIR="structure/atmpos" # initial atomic positions file
kpband=$(cat structure/kpband)
pseudo_loader=$(cat structure/kpband)
cell_params=$(cat structure/cell_params)

VC_RELAX_INPUT="$INPUT_DIR/vc-relax.in"
VC_RELAX_OUTPUT="$OUTPUT_DIR/vc-relax.out"
SCF_INPUT="$INPUT_DIR/scf.in"
SCF_OUTPUT="$OUTPUT_DIR/scf.out"
#PW2CIF_INPUT="$INPUT_DIR/pw2scf.in"
#PW2CIF_OUTPUT="$OUTPUT_DIR/pw2scf.out"
NSCF_INPUT="$INPUT_DIR/nscf.in"
NSCF_OUTPUT="$OUTPUT_DIR/nscf.out"
BANDS_INPUT="$INPUT_DIR/bands.in"
BANDS_OUTPUT="$OUTPUT_DIR/bands.out"
DOS_INPUT="$INPUT_DIR/dos.in"
DOS_OUTPUT="$OUTPUT_DIR/dos.out"
PDOS_INPUT="$INPUT_DIR/pdos.in"
PDOS_OUTPUT="$OUTPUT_DIR/pdos.out"
RBANDS_INPUT="$INPUT_DIR/run_bands.in"
RBANDS_OUTPUT="$OUTPUT_DIR/run_bands.out"
RDOS_INPUT="$INPUT_DIR/run_dos.in"
RDOS_OUTPUT="$OUTPUT_DIR/run_dos.out"
RPDOS_INPUT="$INPUT_DIR/run_pdos.in"
RPDOS_OUTPUT="$OUTPUT_DIR/run_pdos.out"

# count # of total/unique atoms for input file writing
NAT=$(grep -v '^!' "$ATOMIC_POSITIONS_DIR" | wc -l)
NTYP=$(grep -v '^!' "$ATOMIC_POSITIONS_DIR" | awk '{print $1}' | sort | uniq | wc -l)

# output color codings:
generate_files="31" # red
start_dft="35" # magenta
start_calc="33" # yellow
finish_calc="32" # green
complete_dft="34" # blue
important_variable_color="36" # cyan

# toggle calculations to run
RUN_SCF=false
RUN_NSCF=false
RUN_BANDS=false
RUN_PDOS=true

# generate input files from templates
generate_input_file() {
    local template_file=$1
    local output_file=$2
    echo -e "\033[${generate_files}m- Generating $output_file from $template_file\033[0m"
    sed -e "s|{LATTICE_PARAM_A}|$LATTICE_PARAM_A|g" \
        -e "s|{LATTICE_PARAM_C}|$LATTICE_PARAM_C|g" \
        -e "s|{OCCUPATION}|$OCCUPATION|g" \
        -e "s|{SMR_METHOD}|$SMR_METHOD|g" \
        -e "s|{DEGAUSS}|$DEGAUSS|g" \
        -e "/{PSEUDOS}/r structure/pseudo_loader" \
        -e "/{PSEUDOS}/d" \
        -e "s|{VERBOSITY}|$VERBOSITY|g" \
        -e "/{ATOMIC_POSITIONS}/r $ATOMIC_POSITIONS_DIR" \
        -e "/{ATOMIC_POSITIONS}/d" \
        -e "s|{ECUTWFC}|$ECUTWFC|g" \
        -e "s|{ECUTRHO}|$ECUTRHO|g" \
        -e "s|{NAT}|$NAT|g" \
        -e "s|{NTYP}|$NTYP|g" \
        -e "s|{NBNDS}|$NBANDS|g" \
        -e "s|{E_MAXSTEP}|$E_MAXSTEP|g" \
        -e "s|{DIAG_THRESHOLD}|$DIAG_THRESHOLD|g" \
        -e "s|{SCF_CONV_THR}|$SCF_CONV_THR|g" \
        -e "s|{NSCF_CONV_THR}|$NSCF_CONV_THR|g" \
        -e "s|{MIX_MODE}|$MIX_MODE|g" \
        -e "s|{MIX_BETA}|$MIX_BETA|g" \
        -e "s|{MIXING_NDIM}|$MIXING_NDIM|g" \
        -e "s|{ECUTWFC}|$ECUTWFC|g" \
        -e "s|{ECUTRHO}|$ECUTRHO|g" \
        -e "s|{K_POINTS}|$K_POINTS|g" \
        -e "/{K_POINTS_BAND}/r structure/kpband" \
        -e "/{K_POINTS_BAND}/d" \
        -e "/{CELL_PARAMS}/r structure/cell_params" \
        -e "/{CELL_PARAMS}/d" \
        -e "s|{OUTPUT_DIR}|$OUTPUT_DIR|g" \
        -e "s|{CORES}|$CORES|g" \
        $template_file > $output_file
}

timer() {
    local action=$1
    local temp_file="/tmp/timer_start_time"

    if [[ "$action" == "init" ]]; then
        date +%s > $temp_file
        return
    fi

    if [[ ! -f $temp_file ]]; then
        echo "Timer has not been initialized. Please run the script with 'init' first."
        return
    fi

    local start_time=$(cat $temp_file)
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))

    if [[ "$action" == "elapsed" ]]; then
        # convert to readable
        local hours=$((elapsed_time / 3600))
        local minutes=$(((elapsed_time % 3600) / 60))
        local seconds=$((elapsed_time % 60))

        printf "Elapsed time: %02d:%02d:%02d (hh:mm:ss)\n" $hours $minutes $seconds
    fi
    date +%s > $temp_file
}

# Extract relaxed positions from vc-relax
extract_atomic_positions() {
    grep -A $NAT "ATOMIC_POSITIONS" $1 | tail -n $NAT
}

extract_cell_parameters() {
    grep -A 3 "CELL_PARAMETERS" $1 | tail -n 3
}

timer init # reset between file runs
if [ "$RELAX_POSITIONS" = "true" ]; then
    # generate initial vc-relax input file
    generate_input_file "$TEMPLATE_DIR/vc-relax.in" "$VC_RELAX_INPUT"
    timer init
    echo -e "\033[${start_calc}mRunning vc-relax calculation...\033[0m"
    mpirun -np $CORES pw.x < $VC_RELAX_INPUT > $VC_RELAX_OUTPUT
    if [ $? -ne 0 ]; then
        echo -e "\033[${generate_files}mvc-relax calculation failed!\033[0m"
        exit 1
    fi
    echo -e "\033[${finish_calc}mvc-relax calculation completed in $(timer elapsed).\033[0m"
    ATOMIC_POSITIONS=$(extract_atomic_positions $VC_RELAX_OUTPUT)
    CELL_PARAMETERS=$(extract_cell_parameters $VC_RELAX_OUTPUT)
    CELL_PARAMS_DIR="structure/cell_params"
    
    # Write the atomic positions to the new file
    > "$ATOMIC_POSITIONS_DIR" # erase
    echo "$ATOMIC_POSITIONS" | while IFS= read -r line; do echo "$line"; done > "$ATOMIC_POSITIONS_DIR"
    > "$CELL_PARAMS_DIR" # erase
    echo "$CELL_PARAMETERS" | while IFS= read -r line; do echo "$line"; done > "$CELL_PARAMS_DIR"
    # extract lattice parameters from vc-relax output
    LATTICE_PARAM_A=$(awk '/CELL_PARAMETERS/ {getline; print $1; exit}' "$VC_RELAX_OUTPUT")
    LATTICE_PARAM_C=$(awk '/CELL_PARAMETERS/ {getline; getline; getline; print $3; exit}' "$VC_RELAX_OUTPUT")
    NAT=$(echo "$ATOMIC_POSITIONS" | wc -l) # Update the number of atoms if similar species converge together in position, idk why this would happen though
fi

# Generate remaining input files with the possibly updated atomic positions
generate_input_file "$TEMPLATE_DIR/hyperparameters.in" "$HYPERPARAMETER_DIR"
if [ "$RUN_SCF" = true ]; then
    generate_input_file "$TEMPLATE_DIR/scf.in" "$SCF_INPUT"
fi
if [ "$RUN_NSCF" = true ]; then
    generate_input_file "$TEMPLATE_DIR/nscf.in" "$NSCF_INPUT"
fi
if [ "$RUN_BANDS" = true ]; then
    generate_input_file "$TEMPLATE_DIR/bands.in" "$BANDS_INPUT"
    generate_input_file "$TEMPLATE_DIR/run_bands.in" "$RBANDS_INPUT"
fi
if [ "$RUN_DOS" = true ]; then
    generate_input_file "$TEMPLATE_DIR/dos.in" "$DOS_INPUT"
    generate_input_file "$TEMPLATE_DIR/run_dos.in" "$RDOS_INPUT"
fi
if [ "$RUN_PDOS" = true ]; then
    generate_input_file "$TEMPLATE_DIR/pdos.in" "$PDOS_INPUT"
    generate_input_file "$TEMPLATE_DIR/run_pdos.in" "$RPDOS_INPUT"
fi

# Function to run SCF calculation
run_scf() {
    echo -e "\033[${start_calc}mRunning SCF calculation...\033[0m"
    timer init
    mpirun -np $CORES pw.x < $SCF_INPUT > $SCF_OUTPUT
    if [ $? -ne 0 ]; then
        echo -e "\033[${generate_files}mSCF calculation failed!\033[0m"
        exit 1
    fi
    echo -e "\033[${finish_calc}mSCF calculation completed in $(timer elapsed).\033[0m"
}

build_cif() {
    echo -e "\033[${start_calc}mGenerating CIF...\033[0m"
    timer init
    mpirun -np $CORES pw2cif.x < $PW2CIF_INPUT > $OUTPUT_DIR/structure.cif
    if [ $? -ne 0 ]; then
        echo -e "\033[${generate_files}mGeneration failed!\033[0m"
        exit 1
    fi
    echo -e "\033[${finish_calc}mGeneration completed in $(timer elapsed).\033[0m"
}

# Function to run NSCF calculation
run_nscf() {
    echo -e "\033[${start_calc}mRunning NSCF calculation...\033[0m"
    timer init
    mpirun -np $CORES pw.x < $NSCF_INPUT > $NSCF_OUTPUT
    if [ $? -ne 0 ]; then
        echo -e "\033[${generate_files}mNSCF calculation failed!\033[0m"
        exit 1
    fi
    echo -e "\033[${finish_calc}mNSCF calculation completed in $(timer elapsed).\033[0m"
}

# Function to run bands calculation
run_bands() {
    echo -e "\033[${start_calc}mRunning Bands calculation...\033[0m"
    mpirun -np $CORES pw.x < $BANDS_INPUT > $BANDS_OUTPUT
    if [ $? -ne 0 ]; then
        echo -e echo -e "\033[${generate_files}mBands calculation failed!\033[0m"
        exit 1
    fi
    echo -e "\033[${finish_calc}mBands calculation completed in $(timer elapsed).\033[0m"
    mpirun -np $CORES bands.x < $RBANDS_INPUT > $RBANDS_OUTPUT
    PLOT_BANDS="$FUNCTIONS_DIR/plot_bands.py"
    # Replace fermi energy value in python file
    sed -i "s/^efermi = .*/efermi = ${SCF_FERMI_ENERGY}/" "$PLOT_BANDS"
    sed -i "s|^dir = \".*\"|dir = \"${OUTPUT_DIR}\"|" "$PLOT_BANDS"
    #echo -e "Updated efermi value in $PLOT_BANDS to \033[${important_variable_color}m$SCF_FERMI_ENERGY\033[0m eV"
    python3 $PLOT_BANDS
}

# Function to run DOS calculations (old)
run_dos() {
    echo -e "\033[${start_calc}mRunning DOS calculation...\033[0m"
    mpirun -np $CORES pw.x < $DOS_INPUT > $DOS_OUTPUT
    if [ $? -ne 0 ]; then
        echo -e "\033[${generate_files}mDOS calculation failed!\033[0m"
        exit 1
    fi
    mpirun -np $CORES dos.x < $RDOS_INPUT > $RDOS_OUTPUT
    PLOT_DOS="$FUNCTIONS_DIR/plot_dos.py"
    # Replace fermi energy value in python file
    sed -i "s/^efermi = .*/efermi = ${SCF_FERMI_ENERGY}/" "$PLOT_DOS"
    sed -i "s|^dir = \".*\"|dir = \"${OUTPUT_DIR}\"|" "$PLOT_DOS"
    #echo -e "Updated efermi value in $PLOT_DOS to \033[${important_variable_color}m$SCF_FERMI_ENERGY\033[0m eV"
    python3 $PLOT_DOS
    echo -e "\033[${finish_calc}mDOS calculation completed in $(timer elapsed).\033[0m"
}

# Function to run PDOS calculation
run_pdos() {
    echo -e "\033[${start_calc}mRunning DOS calculations...\033[0m"
    #mpirun -np $CORES pw.x < $DOS_INPUT > $DOS_OUTPUT
    mpirun -np $CORES projwfc.x < $RPDOS_INPUT > $OUTPUT_DIR/run_pdos.out
    if [ $? -ne 0 ]; then
        echo -e "\033[${generate_files}mDOS calculations failed!\033[0m"
        exit 1
    fi
    PLOT_DOS="$FUNCTIONS_DIR/plot_dos.py"
    # Replace fermi energy value in python file
    sed -i "s/^efermi = .*/efermi = ${SCF_FERMI_ENERGY}/" "$PLOT_DOS"
    sed -i "s|^dir = \".*\"|dir = \"${OUTPUT_DIR}\"|" "$PLOT_DOS"
    PLOT_PDOS="$FUNCTIONS_DIR/plot_pdos.py"
    # Replace fermi energy value in python file
    sed -i "s/^efermi = .*/efermi = ${SCF_FERMI_ENERGY}/" "$PLOT_PDOS"
    sed -i "s|^dir = \".*\"|dir = \"${OUTPUT_DIR}\"|" "$PLOT_PDOS"
    #echo -e "Updated efermi value in $PLOT_PDOS to \033[${important_variable_color}m$SCF_FERMI_ENERGY\033[0m eV"
    python3 $PLOT_DOS
    python3 $PLOT_PDOS
    echo -e "\033[${finish_calc}mDOS calculations completed in $(timer elapsed).\033[0m"
}

# Main script execution
echo -e "\033[${important_variable_color}mUsing $CORES cores\033[0m"
echo -e "\033[${start_dft}mStarting DFT calculations...\033[0m"

# Run SCF calculation
if [ "$RUN_SCF" = true ]; then
  run_scf
fi

SCF_FERMI_ENERGY=$(awk '/highest occupied level \(ev\):/ {print $NF} /the Fermi energy is/ {print $(NF-1)}' "$SCF_OUTPUT")
if [ -n "$SCF_FERMI_ENERGY" ]; then
    echo -e "Highest occupied level (Fermi energy) found by SCF calculation: \033[${important_variable_color}m$SCF_FERMI_ENERGY\033[0m eV"
else
    echo "Fermi level not found in $SCF_OUTPUT."
fi

# Run NSCF calculation
if [ "$RUN_NSCF" = true ]; then
  run_nscf
fi

NSCF_FERMI_ENERGY=$(awk '/highest occupied level \(ev\):/ {print $NF} /the Fermi energy is/ {print $(NF-1)}' "$NSCF_OUTPUT")
if [ -n "$SCF_FERMI_ENERGY" ]; then
    echo -e "Highest occupied level (Fermi energy) found by NSCF calculation: \033[${important_variable_color}m$NSCF_FERMI_ENERGY\033[0m eV"
else
    echo "Fermi level not found in $NSCF_OUTPUT."
fi

# Run Bands calculation
if [ "$RUN_BANDS" = true ]; then
  run_bands
fi

# Run DOS calculation
#if [ "$RUN_DOS" = true ]; then
#  run_dos
#fi

# Run PDOS calculation
if [ "$RUN_PDOS" = true ]; then
  run_pdos
fi

echo -e "\033[${complete_dft}mDFT calculations completed successfully.\033[0m"
