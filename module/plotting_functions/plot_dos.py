import matplotlib.pyplot as plt
import numpy as np

dir = "../data/C_bulk"

efermi = 5.4995

# read dos from DFT
ener, dos, idos = np.loadtxt(f'{dir}/dos/pdos_files/.pdos_tot', unpack=True)

plt.figure(figsize=(12, 7))
plt.plot(ener-efermi, dos, c='k', label="Total DOS")
# plot fermi line
plt.axvline(0, c='gray', ls=':', label='Fermi Energy')

plt.xlabel('Energy (eV)', fontsize=13)
plt.ylabel('DOS (state/eV/unit-cell)', fontsize=13)
plt.title("Density of states", fontsize=15)

scaling_factor = 1.1
x_min, x_max = -20, 15
mask = (ener - efermi >= x_min) & (ener - efermi <= x_max)
restricted_dos = dos[mask]
restricted_ener = ener[mask]

plt.xlim(x_min, x_max)
plt.ylim(0, np.max(restricted_dos)*scaling_factor)
plt.legend(fontsize=9)

plt.savefig(f'{dir}/dos/plot-dos.pdf')
plt.show()

data = np.genfromtxt(f'{dir}/dos/pdos_files/.pdos_tot', skip_header=1)

# Write to CSV
np.savetxt(f'{dir}/dos/dos.csv', data, delimiter=',', header='E(eV),dos(E),pdos(E)', comments='')