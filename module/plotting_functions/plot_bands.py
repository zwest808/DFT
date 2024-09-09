import matplotlib.pyplot as plt
import numpy as np
import os

#current_directory = os.getcwd()
#print(f"Current working directory: {current_directory}")

max_bands_plotted = 32 # half of the nearest bands on each side of fermi level
k_nearest = max_bands_plotted // 2 # on each side
dir = "../data/C_bulk"

def parse_kpbands(kpbands_file):
    high_sym_points = []
    indices = []
    with open(kpbands_file, 'r') as file:
        lines = file.readlines()
        num_points = 0
        for line in lines[1:]: # skip the first line (# high-sym points in DFT input file)
            point, n_points = line.split()
            n_points = int(n_points)
            if point == "gG":
                point = "$\Gamma$"
            high_sym_points.append(point)
            indices.append(num_points)
            num_points += n_points
        indices.append(num_points) # Add the last index
    return high_sym_points, indices

# Parse kbands
kpbands_file = 'structure/kpband'
high_sym_points, indices = parse_kpbands(kpbands_file)

data = np.loadtxt(f'{dir}/bands/bands.gnu')
k = np.unique(data[:, 0])
bands = np.reshape(data[:, 1], (-1, len(k)))
efermi = 5.4995

color = "g"
transparency = .5 # 1 opaque, 0 fully transparent
plt.figure(figsize=(12, 7))
# Plot Fermi energy line (shifted data by -efermi)
plt.axhline(0, c='gray', ls=':')

# Plot vertical lines at high-symmetry points in wurtzite/hexagonal structure
for index in indices[1:-1]: # Skip the first and last points as they are bounded by plot
    plt.axvline(k[index], c='gray')

num_bands = bands.shape[0]
max_k_nearest = num_bands // 2
# Avoid np array errors if there are less bands than max
if k_nearest > max_k_nearest:
    k_nearest = max_k_nearest

def get_k_nearest_bands(bands, efermi, k_nearest):
    band_diffs = bands - efermi
    num_bands = bands.shape[0]

    # Calculate the distance from the Fermi level for all bands
    distance_from_fermi = np.abs(band_diffs)

    # Identify the closest valence and conduction bands
    valence_bands = np.where(band_diffs < 0, band_diffs, -np.inf)
    conduction_bands = np.where(band_diffs > 0, band_diffs, np.inf)

    # Get the k nearest valence bands to Fermi level
    valence_band_indices = np.argsort(np.max(valence_bands, axis=1))[-k_nearest:]
    # Get the k nearest conduction bands to Fermi level
    conduction_band_indices = np.argsort(np.min(conduction_bands, axis=1))[:k_nearest]

    return valence_band_indices, conduction_band_indices

valence, conduction = get_k_nearest_bands(bands, efermi, k_nearest)
for band in valence:
    plt.plot(k, bands[band, :] - efermi, c=color, alpha=transparency)
for band in conduction:
    plt.plot(k, bands[band, :] - efermi, c=color, alpha=transparency)

"""
# Plot band structure
for band in range(len(bands)):
    plt.plot(k, bands[band, :] - efermi, c=color, alpha=transparency)
"""

plt.title('Band structure', fontsize=15)
plt.xlabel('Wave vector', fontsize=13)
plt.ylabel('Energy (eV)', fontsize=13)

plt.xlim(0, k[-1])

min_valence_energy = float('inf')
for band in valence:
    # Get the minimum energy for the current band (adjusted relative to the Fermi level)
    band_min_energy = np.min(bands[band, :] - efermi)
    if band_min_energy < min_valence_energy:
        min_valence_energy = band_min_energy

max_conduction_energy = float('-inf')

for band in conduction:
    band_max_energy = np.min(bands[band, :] - efermi)
    if band_max_energy > max_conduction_energy:
        max_conduction_energy = band_max_energy

plt.ylim(min_valence_energy-1, max_conduction_energy+1)

plt.xticks(k[indices[:-1]], high_sym_points)

plt.tick_params(axis='x', which='minor', bottom=False, top=False)

plt.savefig(f'{dir}/bands/plot-bands.pdf')
plt.show()