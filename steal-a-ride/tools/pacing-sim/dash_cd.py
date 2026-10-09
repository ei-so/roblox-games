"""Dash cooldown 8 / 10 / 12 s with the Giant Spider at 84 and 88: whole-game pacing + Mystic gap (real minutes)."""
import math, functools, mystic, rage, progress
from progress import run, HUMAN, escapeProb, S, NESTZ
d = -NESTZ[mystic.M] + progress.SAFEZ
for cd in (8, 10, 12):
    rage.DASH_CD = cd
    rage.use(1.15, 4, 0.85, forestSurge=True)  # fresh cache per cooldown
    for g in (84, 88):
        P = mystic.P(guard=g)
        cos, mys, gaps, first = [], [], [], 0
        for s in range(200):
            t, f = run(P, s, target=mystic.M)
            if "Cosmic" in f: cos.append(f["Cosmic"] / 60 * HUMAN / 60)
            if not math.isinf(t):
                mys.append(t / 60 * HUMAN / 60)
                if "Cosmic" in f and f["Cosmic"] < t:
                    first += 1; gaps.append((t - f["Cosmic"]) / 60 * HUMAN)
        med = lambda xs: sorted(xs)[len(xs) // 2] if xs else float("nan")
        p90 = lambda xs: sorted(xs)[int(.9 * len(xs))] if xs else float("nan")
        esc = " ".join(f"{v}:{escapeProb(g*S, round(v*.78,1), d, False, True, .95):.0%}" for v in (112, 118, 125))
        print(f"Dash cd {cd:2d}s spider {g}: Cosmic {med(cos):.2f} h | Mystic {med(mys):.2f} h (reached {len(mys)}/200, Cosmic first {first}) "
              f"| gap median {med(gaps):5.1f} p90 {p90(gaps):5.1f} min | Dash escape {esc}")
