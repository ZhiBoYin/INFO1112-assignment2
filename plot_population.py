"""Read year-population data and save population.png in the current directory."""

import matplotlib

matplotlib.use("Agg")  # Save images without opening a window.
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator


data = []
with open("population_data.txt", encoding="utf-8") as file:
    for line in file:
        line = line.strip()
        if line:
            year, population = line.split("-", 1)
            data.append((int(year), int(population)))

if not data:
    raise ValueError("population_data.txt contains no data.")

data.sort()  # Plot years in chronological order.
years, populations = zip(*data)

fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(years, populations, marker="o")
ax.set_xlabel("Year")
ax.set_ylabel("Population")
ax.set_title("Population by Year")
ax.xaxis.set_major_locator(MaxNLocator(integer=True))
ax.ticklabel_format(axis="both", style="plain", useOffset=False)
ax.grid(True, alpha=0.3)
fig.tight_layout()
fig.savefig("population.png", dpi=200)
plt.close(fig)

print("Saved population.png")
