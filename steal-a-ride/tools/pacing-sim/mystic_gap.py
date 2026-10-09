"""Per-run gap from first Cosmic to first Mystic deposit, in real minutes (x HUMAN), per spider speed."""
import math, statistics, mystic, rage, progress
from progress import run, HUMAN
rage.use(1.15, 4, 0.85, forestSurge=True)
for g in (76, 80, 84, 88):
    P = mystic.P(guard=g)
    gaps, miss = [], 0
    for s in range(200):
        t, firsts = run(P, s, target=mystic.M)
        if math.isinf(t) or "Cosmic" not in firsts:
            miss += 1
            continue
        gaps.append((t - firsts["Cosmic"]) / 60 * HUMAN)
    gaps.sort()
    q = lambda f: gaps[min(len(gaps) - 1, int(f * len(gaps)))]
    print(f"spider raw {g}: reached {len(gaps)}/200 | Cosmic->Mystic real min: p10 {q(.1):5.1f}  median {q(.5):5.1f}  p90 {q(.9):5.1f}")
