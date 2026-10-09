"""Rage rework (burst then winded) vs the current chase, on the values installed 2026-10-09.
Run: python rage.py  (from this folder)"""
import functools
import progress
from progress import BASE, BIOMES, NESTZ, report

# installed now (Config.luau): raw guardian speeds, hatch times, 5-min nest cycle, no Forest trickle, saddle x1.85
NOW = dict(BASE, guard=dict(BASE["guard"], Jungle=44, Tundra=52, Volcano=60, Cosmic=76),
           hatch={"Forest": 15, "Lake": 30, "Desert": 45, "Jungle": 68, "Tundra": 90, "Volcano": 135, "Cosmic": 180},
           refill=300, forestRefill=300, saddleGrowth=1.85)

# where the burst starts, in studs from the nest: the guardian crossing its biome's entrance (Forest: the carrier
# crossing the middle of the Forest, z -245)
ENTRANCE = {"Lake": -335, "Desert": -555, "Jungle": -835, "Tundra": -1185, "Volcano": -1605, "Cosmic": -2105}
DASH_CD = 8.0  # Config.Abilities.Dash.cooldown (2x for 1.5 s)
EXIT = {b: (-245 if b == "Forest" else ENTRANCE[b]) - NESTZ[b] for b in BIOMES}


def chase2(gs, v, dist, gap, exit, burst=1.15, burstS=8.0, winded=0.9, tm=0.95, dash=False, blood=False,
           lunge=False, dt=0.02, forest=False, surgeAt=None):
    p, g, t = 0.0, -gap, 0.0
    lungeReady, lungeUntil, burstAt = 0.0, -1.0, None
    while p < dist:
        f = min(1, .45 + .55 * t / 2)
        if burstAt is None and ((p if forest else g) >= exit):
            burstAt = t
        if (p >= surgeAt) if surgeAt is not None else (dist - p <= 60):
            f *= max(1.3, 1.15 if blood else 1)  # final surge; never stacks with Blood Moon
        elif burstAt is not None and t - burstAt < burstS:
            f *= max(burst, 1.15 if blood else 1)
        else:
            if burstAt is not None:
                f *= winded
            elif t > 12:
                f *= tm
            if blood:
                f *= 1.15
        sg = gs * f
        if lunge and p - g <= 15 and t >= lungeReady:
            lungeUntil, lungeReady = t + .4, t + 4
        if t < lungeUntil:
            sg *= 1.5
        sp = v * (2 if dash and (t % DASH_CD) < 1.5 else 1)
        p += sp * dt; g += sg * dt; t += dt
        if g >= p:
            return "CAUGHT"
    return "ESCAPED"


FOREST_FAR = -315  # deeper guardians surge once the carrier enters the Forest (2026-10-09); the Chicken keeps 60 studs


def use(burst, burstS, winded, forestSurge=False):
    @functools.lru_cache(maxsize=None)
    def escapeProb(gs, v, dist, fly, dash, tired):
        b = next(x for x in BIOMES if -NESTZ[x] - 175 == dist)
        gaps = range(6, 37, 3)
        return sum(chase2(gs, v, dist, gp, EXIT[b], burst, burstS, winded, tm=tired, dash=dash, lunge=not fly,
                          forest=b == "Forest",
                          surgeAt=FOREST_FAR - NESTZ[b] if forestSurge and b != "Forest" else None) == "ESCAPED"
                   for gp in gaps) / len(gaps)
    progress.escapeProb = escapeProb


if __name__ == "__main__":
    print("exit (studs from nest):", EXIT)
    use(1.15, 4, 0.85)
    report(NOW, n=300, label="installed: burst 4s winded 0.85, surge 60 studs")
    use(1.15, 4, 0.85, forestSurge=True)
    report(NOW, n=300, label="surge on entering the Forest (Chicken keeps 60 studs)")
