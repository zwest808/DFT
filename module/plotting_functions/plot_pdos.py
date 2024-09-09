import numpy as np
import matplotlib.pyplot as plt

#import os
#current_directory = os.getcwd()
#print(f"Current working directory: {current_directory}")

dir = "../data/C_bulk"

sparse_plotting = False #makes plot more readable by removing data points

def r_dos(name):
    ener, dos = np.loadtxt(name, usecols=(0,1), unpack=True)
    return ener, dos

def read_atomic_positions(filename):
    with open(filename, 'r') as file:
        lines = file.readlines()
    atomic_positions = []
    for line in lines:
        parts = line.split()
        element = parts[0]
        coordinates = list(map(float, parts[1:]))
        atomic_positions.append((element, coordinates))
    return atomic_positions

def read_pdos(atom_number, element_symbol, orbital, orbital_type):
    filename = f'{dir}/dos/pdos_files/.pdos_atm#{atom_number}({element_symbol})_wfc#{orbital}({orbital_type})'
    return r_dos(filename)

def get_orbitals_for_element(element):
    # Each elements' orbitals
    orbitals = {
        'C': {1: 's', 2: 'p'},       # s and p orbitals
        'Al': {1: 's', 2: 'p'},      # s and p orbitals
        'N': {1: 's', 2: 'p'},       # s and p orbitals
        'Mg': {1: 's', 2: 's', 3: 'p'},      # s and p orbitals
        'Zn': {1: 's', 2: 'p', 3: 'd'}   # s, p, and d orbitals
    }
    return orbitals.get(element, {})

atomic_positions = read_atomic_positions('structure/atmpos')

ener, dos = r_dos(f'{dir}/dos/pdos_files/.pdos_tot')

# Define Fermi energy (assuming it is given)
efermi = 5.4995

# dictionary to store PDOS for each element and orbital type
pdos_summed = {}

# Loop through each atom and read PDOS files for each orbital
for i, (element_symbol, _) in enumerate(atomic_positions):
    atom_number = i + 1
    orbitals = get_orbitals_for_element(element_symbol)
    if element_symbol not in pdos_summed:
        pdos_summed[element_symbol] = {}
    for orbital, orbital_type in orbitals.items():
        ener_orb, dos_orb = read_pdos(atom_number, element_symbol, orbital, orbital_type)
        if orbital_type not in pdos_summed[element_symbol]:
            pdos_summed[element_symbol][orbital_type] = np.zeros_like(dos_orb)
        pdos_summed[element_symbol][orbital_type] += dos_orb

if sparse_plotting:
    n = 8 # Adjust n to make the plot more sparse
    ener = ener[::n]
    dos = dos[::n]
    for element_symbol in pdos_summed:
        for orbital, orbital_type in orbitals.items():
            if orbital_type in pdos_summed[element_symbol]:
                pdos_summed[element_symbol][orbital_type] = pdos_summed[element_symbol][orbital_type][::n]

# Plot the summed PDOS for each element and orbital type
color_map = {
    'Al': {'s': 'b', 'p': 'c'},
    'N': {'s': 'r', 'p': 'm'},
    'Mg': {'s': 'g', 'p': 'y'},
    'Zn': {'s': 'orange', 'p': 'purple', 'd': 'pink'},
    'C': {'s': 'r', 'p': 'orange'}
}

plt.figure(figsize=(12, 7))
# Plot the total DOS
plt.plot(ener - efermi, dos, c='k', label='Total DOS')

transparency = .85
# Plot PDOS
for element_symbol in pdos_summed:
    for orbital_type in pdos_summed[element_symbol]:
        color = color_map.get(element_symbol, {}).get(orbital_type, 'k')  # default to 'k' if not found
        plt.plot(ener - efermi, pdos_summed[element_symbol][orbital_type], 
                 label=f'{element_symbol} {orbital_type}-orbital contribution', color=color, alpha=transparency)

# plot fermi line
plt.axvline(0, c='gray', ls=':', label='Fermi Energy')
plt.xlabel('Energy (eV)', fontsize=13)
plt.ylabel('PDOS (state/eV/unit-cell)', fontsize=13)
plt.title('Partial density of states', fontsize=15)

x_min, x_max = -20, 15
mask = (ener - efermi >= x_min) & (ener - efermi <= x_max)
restricted_dos = dos[mask]
restricted_ener = ener[mask]

scaling_factor = 1.1
plt.xlim(x_min, x_max)
plt.ylim(0, np.max(restricted_dos)*scaling_factor)
plt.legend(fontsize=9)

plt.savefig(f'{dir}/dos/plot-pdos.pdf')
plt.show()