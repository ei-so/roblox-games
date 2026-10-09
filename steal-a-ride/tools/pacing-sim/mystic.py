"""Mystic Grove (biome 8, Codex placeholders 2026-10-09) on top of the installed rage rules + Forest surge.
Run: python mystic.py  (from this folder)"""
import progress, rage
from progress import BIOMES, NESTZ, SPECIES, MOUNTBASE, report, escapeProb, S

M = "MysticGrove"
BIOMES.append(M)
NESTZ[M] = -3153                       # Studio: MysticGrove nest z
SPECIES[M] = [("Shroomling", None), ("GlowDeer", "Jump"), ("WispLynx", "Phase")]
MOUNTBASE[M] = 84                      # Config mountBase (x1.25 in-game = 105)
rage.EXIT[M] = -2705 - NESTZ[M]        # burst when the spider crosses its entrance (Cosmic far edge)

def P(guard=84, income=16000, carry=.78, hatch=240):
    return dict(rage.NOW, guard=dict(rage.NOW["guard"], **{M: guard}), income=dict(rage.NOW["income"], **{M: income}),
                carry=dict(rage.NOW["carry"], **{M: carry}), hatch=dict(rage.NOW["hatch"], **{M: hatch}))

if __name__ == "__main__":
    rage.use(1.15, 4, 0.85, forestSurge=True)
    dist = -NESTZ[M] + progress.SAFEZ
    print("escape odds from Mystic Grove nest (Codex values: spider 84 raw = 105, carry .78), by free riding speed:")
    for v in (94, 100, 106, 112, 118, 125):
        print(f"  ride {v:3d} -> carrying {v*.78:5.1f}: {escapeProb(84 * S, round(v * .78, 1), dist, False, False, .95):.0%}"
              f" | with Dash {escapeProb(84 * S, round(v * .78, 1), dist, False, True, .95):.0%}")
    report(P(), n=200, label="Cosmic (reference)", target="Cosmic")
    report(P(), n=200, label="Mystic, Codex values", target=M)
