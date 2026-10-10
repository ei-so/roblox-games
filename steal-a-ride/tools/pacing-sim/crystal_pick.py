"""Follow-up to crystal_gap.py: the picked egg weight (margin 0.945 at Golem 96) with more runs, and smaller Climb leads
when the lead is kept after the cave exit. Run: python crystal_pick.py -> appended to crystal-gap-out.txt"""
import math
import crystal, mystic
from crystal import C, P, odds
from progress import run, HUMAN, S
from crystal_gap import first_ride, q

crystal.use()
gs = 96 * S
ride = first_ride(P(guard=96))
for m in (0.945,):
    carry = round(m * gs / ride, 3)
    gaps = []
    for s in range(400):
        t, firsts = run(P(guard=96, carry=carry), s, target=C)
        if not math.isinf(t) and mystic.M in firsts:
            gaps.append((t - firsts[mystic.M]) / 60 * HUMAN)
    gaps.sort()
    print(f"PICK margin {m} carry {carry} (carrying {ride*carry:.1f} vs Golem {gs:.1f}): reached {len(gaps)}/400, "
          f"Mystic->Crystal real min p10 {q(gaps,.1):.1f} median {q(gaps,.5):.1f} p90 {q(gaps,.9):.1f}")
crystal.LEAD["keep"] = True
print("Lead kept after the exit, small leads (no Dash / Dash): lead per wall none | 5 | 10 | 15")
for r in (0.93, 0.95, 0.975, 1.0, 1.03):
    cells = []
    for lead in (None, 5, 10, 15):
        crystal.LEAD["perWall"] = lead or 0
        cells.append(f"{odds(gs, round(gs*r,1), C, False, lead is not None, n=44):4.0%}/{odds(gs, round(gs*r,1), C, True, lead is not None, n=44):4.0%}")
    print(f"  rider x{r:<5} " + " | ".join(cells), flush=True)
