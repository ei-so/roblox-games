"""Leash chase (spec 2026-10-09-guardian-leash-design): phase 1 inside the guardian's biome as installed minus the
rage stages; phase 2 once the carrier leaves it: snap to BUFFER behind, full speed, no tiredness, no lunge, leash
every step. Derives per-biome egg weights so the typical first-attempt rider beats each guardian by MARGIN.
Run: python leash.py  (from this folder)  -> leash-out.txt"""
import functools, math, sys
import progress, rage, mystic
from progress import BIOMES, NESTZ, S, report, run

BUFFER, MARGIN = 15.0, 1.00  # 1.05 (spec) put first Cosmic at 1.7 h; 1.00 hits ~3 h (leash-sweep-out.txt)
MARGINS = {"MysticGrove": 0.975}  # per-biome override: first Mystic 30-45 real min after first Cosmic
if len(sys.argv) > 2: BUFFER, MARGIN = float(sys.argv[1]), float(sys.argv[2])
if len(sys.argv) > 3: MARGINS["MysticGrove"] = float(sys.argv[3])
SAFE = 175  # progress.SAFEZ is -175: dist = -NESTZ - 175


def chase_leash(gs, v, dist, exit_, gap, dash=False, lunge=False, dt=0.01, buffer=BUFFER, tm=0.95):
    p, g, t = 0.0, -gap, 0.0  # carrier and guardian (front of its catch reach) along the road
    lunge_ready, lunge_until = 0.0, -1.0
    while p < dist:
        phase2 = p >= exit_
        if phase2:
            g = max(g, p - buffer)  # leash
            f = 1.0
        else:
            f = min(1, .45 + .55 * t / 2)
            if t > 12: f *= tm
            if lunge and p - g <= 15 and t >= lunge_ready: lunge_until, lunge_ready = t + .4, t + 4
        sg = gs * f * (1.5 if (not phase2 and t < lunge_until) else 1)
        sp = v * (2 if dash and (t % 8) < 1.5 else 1)
        p += sp * dt; g += sg * dt; t += dt
        if g >= p:
            return False
    return True


def use(buffer=BUFFER):
    @functools.lru_cache(maxsize=None)
    def escape_prob(gs, v, dist, fly, dash, tired):
        b = next(x for x in BIOMES if -NESTZ[x] - SAFE == dist)
        exit_ = math.inf if b == "Forest" else rage.EXIT[b]
        gaps = range(6, 37, 3)
        return sum(chase_leash(gs, v, dist, exit_, gp, dash=dash, lunge=not fly, buffer=buffer, tm=tired)
                   for gp in gaps) / len(gaps)
    progress.escapeProb = escape_prob


def first_tries(P, n=200):
    """ride speed at the first attempt of each biome under the INSTALLED chase (rage burst + Forest surge)"""
    rage.use(1.15, 4, 0.85, forestSurge=True)
    seen = {b: [] for b in BIOMES}
    for s in range(n):
        d = {}
        run(P, s, target=mystic.M, tries=d)
        for b, v in d.items():
            seen[b].append(v)
    return seen


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else math.nan


if __name__ == "__main__":
    P = mystic.P(guard=88)
    seen = first_tries(P)
    carry, top = dict(P["carry"]), {}
    print(f"leash buffer {BUFFER}, margin x{MARGIN}")
    print(f"{'biome':12} {'guard':>6} {'ride med':>9} {'ride p90':>9} {'old w':>6} {'new w':>6} {'carry':>6} {'flag'}")
    for b in BIOMES[1:]:
        gs = P["guard"][b] * S
        med, p90 = pct(seen[b], .5), pct(seen[b], .9)
        m = MARGINS.get(b, MARGIN)
        raw = m * gs / med
        carry[b] = round(min(1.0, raw), 3)
        prev = BIOMES[BIOMES.index(b) - 1]  # spec "top upgrades": Legendary mount from the biome before + saddle 20
        topRide = progress.MOUNTBASE[prev] * S + progress.RAR[4][3] + 2 + 20
        top[b] = m * gs / (topRide * carry[b])
        print(f"{b:12} {gs:6.1f} {med:9.1f} {p90:9.1f} {P['carry'][b]:6.2f} {carry[b]:6.3f} {med*carry[b]:6.1f} {'NEEDS SLOWER GUARDIAN' if raw > 1 else ''}")
    secret = round(min(1.0, max(top.values())), 3)
    print(f"secretMult {secret} (Legendary mount from the previous biome + saddle 20 still beats every guardian)")
    old = dict(P)
    new = dict(P, carry=carry, soda=1.10)
    use()
    report(old, n=200, label="leash, OLD weights", target="Cosmic")
    report(new, n=200, label="leash, NEW weights", target="Cosmic")
    report(new, n=200, label="leash, NEW weights", target=mystic.M)
    print("CONFIG")
    for b in BIOMES:
        print(f"  carry {b} = {carry[b]}")
    print(f"  secretMult = {secret}")
    print(f"  leashBuffer = {BUFFER}")
