"""Crystal Caverns sweep: Golem speed x Climb lead per wall. For each Golem speed the egg weight (carry) is derived like
Mystic's (leash.py, margin 0.975 x guard / median ride speed at the first Crystal attempt), then:
reached/200, the first Mystic -> first Crystal gap in real minutes, and escape odds for a rider at that median speed
with/without Dash and with/without Climb. Climb can't change the first-Crystal gap: Climb only comes from a Crystal egg.
Run: python crystal_gap.py  (from this folder) -> crystal-gap-out.txt"""
import math, statistics
import crystal, mystic, progress
from crystal import C, P, odds
from progress import run, HUMAN, S

crystal.use()
MARGIN = 0.975
N = 200


def first_ride(Q):
    rides = []
    for s in range(N):
        d = {}
        run(Q, s, target=C, tries=d)
        if C in d: rides.append(d[C])
    return statistics.median(rides)


def q(xs, f):
    return xs[min(len(xs) - 1, int(f * len(xs)))] if xs else math.nan


if __name__ == "__main__":
    print(f"{'golem':>9} {'carry':>6} {'ride':>6} {'reached':>8} {'Mystic->Crystal real min p10/med/p90':>38}   "
          f"escape at median ride (no Dash / Dash), lead/wall: none | 20 | 35 | 50")
    for g in (92, 94, 96, 98, 100):
        gs = g * S
        ride = first_ride(P(guard=g))  # ride speed barely depends on Crystal's own carry
        carry = round(min(1.0, MARGIN * gs / ride), 3)
        Q = P(guard=g, carry=carry)
        gaps, miss = [], 0
        for s in range(N):
            t, firsts = run(Q, s, target=C)
            if math.isinf(t) or mystic.M not in firsts:
                miss += 1
                continue
            gaps.append((t - firsts[mystic.M]) / 60 * HUMAN)
        gaps.sort()
        v = round(ride * carry, 1)
        cells = []
        for lead in (None, 20, 35, 50):
            crystal.LEAD["perWall"] = lead or 0
            cells.append(f"{odds(gs, v, C, False, lead is not None):4.0%}/{odds(gs, v, C, True, lead is not None):4.0%}")
        print(f"{g:4d}={gs:5.1f} {carry:6.3f} {ride:6.1f} {len(gaps):5d}/{N} {q(gaps, .1):10.1f} {q(gaps, .5):8.1f} {q(gaps, .9):8.1f}   "
              + " | ".join(cells), flush=True)

    print("\nEgg weight (margin) sweep at Golem 96: heavier eggs = later first Crystal")
    gs = 96 * S
    ride = first_ride(P(guard=96))
    for m in (0.93, 0.94, 0.95, 0.96, 0.975):
        carry = round(min(1.0, m * gs / ride), 3)
        Q = P(guard=96, carry=carry)
        gaps = []
        for s in range(N):
            t, firsts = run(Q, s, target=C)
            if not math.isinf(t) and mystic.M in firsts:
                gaps.append((t - firsts[mystic.M]) / 60 * HUMAN)
        gaps.sort()
        print(f"  margin {m:<5} carry {carry:5.3f} (carrying {ride * carry:5.1f} vs Golem {gs:5.1f}) reached {len(gaps):3d}/{N} "
              f"gap p10 {q(gaps, .1):5.1f} median {q(gaps, .5):5.1f} p90 {q(gaps, .9):5.1f}", flush=True)

    for keep in (False, True):
        crystal.LEAD["keep"] = keep
        print("\nEscape odds by carrying speed / Golem 96 (no Dash / Dash), lead per wall none | 20 | 35 | 50 -- "
              + ("PROPOSAL: Climb lead kept after the cave exit (leash 30 + lead)" if keep else "INSTALLED leash: lead lost at the cave exit"))
        for r in (0.90, 0.93, 0.95, 0.975, 1.0, 1.03, 1.05):
            cells = []
            for lead in (None, 20, 35, 50):
                crystal.LEAD["perWall"] = lead or 0
                cells.append(f"{odds(gs, round(gs * r, 1), C, False, lead is not None, n=44):4.0%}/"
                             f"{odds(gs, round(gs * r, 1), C, True, lead is not None, n=44):4.0%}")
            print(f"  rider x{r:<5} " + " | ".join(cells), flush=True)
