"""Sweep the Giant Spider's speed: escape odds by riding speed (no Dash / Dash) and time to first Mystic deposit."""
import mystic, rage, progress
from progress import escapeProb, S, NESTZ, report
rage.use(1.15, 4, 0.85, forestSurge=True)
dist = -NESTZ[mystic.M] + progress.SAFEZ
cdist = -NESTZ["Cosmic"] + progress.SAFEZ
print("Cosmic dragon (raw 76, flies, carry .80) for reference:",
      " ".join(f"{v}:{escapeProb(76*S, round(v*.8,1), cdist, True, False, .95):.0%}" for v in (94, 106, 118)))
for g in (72, 76, 80, 84):
    row = " ".join(f"{v}:{escapeProb(g*S, round(v*.78,1), dist, False, False, .95):.0%}/{escapeProb(g*S, round(v*.78,1), dist, False, True, .95):.0%}"
                   for v in (94, 100, 106, 112, 118, 125))
    print(f"spider raw {g} (={g*S:.0f}) ride:noDash/Dash  {row}")
    report(mystic.P(guard=g), n=150, label=f"first Mystic, spider {g}", target=mystic.M)
