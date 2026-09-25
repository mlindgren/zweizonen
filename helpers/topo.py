"""Generate a single-colour topographic contour background for a round watch face.

Requires: numpy, scipy, matplotlib  (pip install numpy scipy matplotlib)
Usage:    python topo_bg.py            -> topo_bg_454.png
          python topo_bg.py --seed 12 --size 416 --levels 30 --out topo_416.png
"""
import argparse

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.ndimage import gaussian_filter


def smooth_noise(rng, n, sigma):
    """Random noise blurred to a given feature size, normalised to unit std."""
    z = gaussian_filter(rng.standard_normal((n, n)), sigma, mode="wrap")
    return z / z.std()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--size", type=int, default=454, help="output width/height in px")
    p.add_argument("--seed", type=int, default=7, help="change for a different terrain")
    p.add_argument("--levels", type=int, default=36, help="number of contour lines (density)")
    p.add_argument("--minor", default="#26292C", help="regular contour colour")
    p.add_argument("--major", default="#383C40", help="every-5th index contour colour")
    p.add_argument("--out", default=None)
    a = p.parse_args()

    n = a.size
    s = n / 454  # scale feature sizes with resolution
    rng = np.random.default_rng(a.seed)

    # Terrain height field: large rolling shapes + some mid-scale detail + a touch of fine detail
    z = np.zeros((n, n))
    for sigma, amp in [(60 * s, 1.0), (28 * s, 0.35), (14 * s, 0.04)]:
        z += amp * smooth_noise(rng, n, sigma)

    # A few hills/basins so it reads like real terrain rather than uniform noise
    y, x = np.mgrid[0:n, 0:n]
    for cx, cy, r, h in [(120, 140, 70, 1.6), (330, 300, 90, -1.3), (360, 90, 50, 0.9)]:
        cx, cy, r = cx * s, cy * s, r * s
        z += h * np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2 * r * r))

    levels = np.linspace(z.min(), z.max(), a.levels)
    minor = [l for i, l in enumerate(levels) if i % 5]
    major = [l for i, l in enumerate(levels) if i % 5 == 0]

    fig = plt.figure(figsize=(n / 100, n / 100), dpi=100)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_axis_off()
    fig.patch.set_facecolor("black")
    # linestyles='solid' matters: matplotlib dashes negative levels by default
    ax.contour(z, levels=minor, colors=a.minor, linewidths=0.9, linestyles="solid")
    ax.contour(z, levels=major, colors=a.major, linewidths=1.4, linestyles="solid")
    ax.set_xlim(0, n - 1)
    ax.set_ylim(n - 1, 0)

    out = a.out or f"topo_bg_{n}.png"
    fig.savefig(out, dpi=100, facecolor="black")
    print("wrote", out)


if __name__ == "__main__":
    main()