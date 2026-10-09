"""Rebirth loop: a greedy bot plays from a fresh save through rebirth after rebirth (same chase/economy model as
progress.py, with the 2026-10-09 rage rework). Each rebirth resets cash, saddle and creatures except the best
`keep` ones; bought incubators/pen slots stay. Income x(1 + 0.5 * rebirths). Optional permanent luck: that share of
hatches rolls one rarity higher. Times are bot hours x HUMAN (the bot is faster than a person).
Run: python rebirth.py"""
import math, random, statistics
import progress, rage
from progress import BIOMES, NESTZ, PLOTZ, SAFEZ, FLY, SPECIES, MOUNTBASE, RAR, S, HUMAN

rage.use(1.15, 4, 0.85)
P = rage.NOW
BIOME_INDEX = {b: i + 1 for i, b in enumerate(BIOMES)}

# current table (Config.luau REBIRTHS): cash, biome needed
CURRENT = [(1e5, "Jungle"), (1e6, "Tundra"), (1e7, "Volcano"), (1e8, "Cosmic"), (4e8, "Cosmic"), (1.6e9, "Cosmic"),
           (6.4e9, "Cosmic"), (2.56e10, "Cosmic"), (1e11, "Cosmic"), (4e11, "Cosmic")]


def keepCount(n):
    return 1 + n // KEEP_EVERY


KEEP_EVERY = 3


def play(table, seed, luckAt=None, step=0.5, cap_h=400):
    """returns bot hours at which each rebirth happened"""
    rng = random.Random(seed)
    luckAt = luckAt or {}
    st = dict(t=0.0, cash=0.0)
    incN, penN, saddle, rebirths, best = 2, 6, 0, 0, 0
    pen, incub, mount = [], [], None
    stock = {b: P["nestEggs"] for b in BIOMES}
    nextRefill = {b: P["refill"] for b in BIOMES}
    times = []

    def mult(): return 1 + step * rebirths
    def income(c): return P["income"][c[0]] * RAR[c[3]][2]
    def ips(): return sum(income(c) for c in pen) * mult()
    def speedOf(c): return MOUNTBASE[c[0]] * S + RAR[c[3]][3] + (0 if c[2] else 2)
    def luck(): return max([v for k, v in luckAt.items() if rebirths >= k] or [0])

    def hatched(c):
        nonlocal mount
        if mount is None or speedOf(c) > speedOf(mount):
            if mount: pen.append(mount)
            mount = c
        else:
            pen.append(c)
        pen.sort(key=income, reverse=True)
        del pen[penN:]

    def advance(dt):
        end = st["t"] + dt
        while True:
            nxt = min([f for f, _ in incub] + [end] + list(nextRefill.values()))
            st["cash"] += ips() * (nxt - st["t"]); st["t"] = nxt
            for b in BIOMES:
                if nextRefill[b] <= st["t"] + 1e-9:
                    stock[b] = P["nestEggs"]; nextRefill[b] += P["refill"]
            for item in [i for i in incub if i[0] <= st["t"] + 1e-9]:
                incub.remove(item); hatched(item[1])
            if st["t"] >= end - 1e-9: return

    def shop(reserve):
        nonlocal saddle, incN, penN
        while True:
            opts = []
            if saddle < 20: opts.append((progress.saddleCost(P, saddle + 1, ips()), "saddle"))
            if incN < 6: opts.append((P["incub"][incN + 1], "incub"))
            if penN < 20: opts.append((P["penBase"] * P["penGrowth"] ** (penN + 1 - 7), "pen"))
            if not opts: return
            cost, what = min(opts)
            if cost > st["cash"] or (reserve and st["cash"] - cost < reserve * 0.5 and cost > ips() * 120): return
            st["cash"] -= cost
            if what == "saddle": saddle += 1
            elif what == "incub": incN += 1
            else: penN += 1

    while st["t"] < cap_h * 3600 and rebirths < len(table):
        cost, need = table[rebirths]
        if st["cash"] >= cost and best >= BIOME_INDEX[need]:
            times.append(st["t"] / 3600)
            rebirths += 1
            everything = sorted(pen + ([mount] if mount else []), key=income, reverse=True)
            keepN = keepCount(rebirths)
            fastest = max(everything, key=speedOf) if everything else None
            kept = ([fastest] if fastest else []) + [c for c in everything if c is not fastest][:keepN - 1]
            mount = fastest
            pen[:] = [c for c in kept if c is not fastest][:penN]
            incub.clear(); st["cash"] = 0.0; saddle = 0
            continue
        shop(cost)
        base = (speedOf(mount) if mount else 25) + saddle
        dash = mount is not None and mount[2] == "Dash"
        gear = max(P["gearMin"], math.floor(ips() * P["gearSeconds"]))
        pick = None
        for i, b in enumerate(BIOMES):
            if stock[b] <= 0: continue
            dist = -NESTZ[b] + SAFEZ
            for soda in (False, True):
                if soda and st["cash"] < gear: continue
                v = base * P["carry"][b] * (1.25 if soda else 1)
                p = progress.escapeProb(P["guard"][b] * S, round(v, 1), dist, b in FLY, dash, P.get("tired", .95))
                if p >= 0.35 and (pick is None or (i, p) > (pick[0], pick[2])):
                    pick = (i, b, p, soda)
        if pick is None or len(incub) >= incN:
            wait = min([f for f, _ in incub] + [st["t"] + 30]) - st["t"]
            advance(max(1.0, wait)); continue
        i, b, p, soda = pick
        if soda: st["cash"] -= gear
        trip = (PLOTZ - NESTZ[b]) * P["inefficiency"]
        advance(trip / base + 2)
        stock[b] -= 1
        back = trip / (base * P["carry"][b])
        if rng.random() < p:
            advance(back)
            k = rng.choices(range(3), weights=[50, 35, 15])[0]
            r = rng.choices(range(5), weights=[x[1] for x in RAR])[0]
            if rng.random() < luck(): r = min(4, r + 1)
            sp, ab = SPECIES[b][k]
            incub.append((st["t"] + P["hatch"][b] * P["hatchX"][r], (b, sp, ab, r)))
            best = max(best, BIOME_INDEX[b])
        else:
            stock[b] += 1
            advance(back * rng.uniform(.2, .6) + 1.5)
    return times


def report(table, label, n=12, **k):
    runs = [play(table, s, **k) for s in range(n)]
    print(f"\n{label}: real hours (median of {n} bots; bot hours x {HUMAN:.2f})")
    for i in range(len(table)):
        ts = [r[i] for r in runs if len(r) > i]
        if len(ts) < n // 2:
            print(f"  R{i + 1:2d} ${table[i][0]:.3g}: most bots never got here"); break
        tot = statistics.median(ts) * HUMAN
        prev = statistics.median([r[i - 1] for r in runs if len(r) > i]) * HUMAN if i else 0
        print(f"  R{i + 1:2d} ${table[i][0]:9.3g} total {tot:6.1f} h   this rebirth {tot - prev:5.1f} h")


if __name__ == "__main__":
    report(CURRENT, "current table (R1-R10)")
