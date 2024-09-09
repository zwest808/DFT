import numpy as np
import pymatgen
from pymatgen.core import Structure, Element
from pymatgen.symmetry.analyzer import SpacegroupAnalyzer

import os
current_directory = os.getcwd()
print(f"directory: {current_directory}")

# Load supercell
structure = Structure.from_file('AlN221.cif')

sga = SpacegroupAnalyzer(structure)
symmetrized_structure = sga.get_symmetrized_structure()

# find symmetrically distinct sites for Al atoms
al_sites = [site for site in symmetrized_structure if site.species_string == "Al"]

# permute Mg and Zn keeping in mind translational equivariance
unique_configs = []
for i, al_site in enumerate(al_sites):
    for j, other_al_site in enumerate(al_sites):
        if i != j:
            new_structure = structure.copy()
            new_structure.replace(i, Element("Mg"))
            new_structure.replace(j, Element("Zn"))
            if new_structure not in unique_configs:
                unique_configs.append(new_structure)

# save configurations
for idx, config in enumerate(unique_configs):
    config.to(filename=f'config_{idx}.cif')

print(f"Number of unique configurations: {len(unique_configs)}")
