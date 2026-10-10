"""Simulated fresh player: no paid boosts, no gifts, solo server. Plays greedily to the first Cosmic deposit.
Models: real nest->safe-line distances, chase physics (chase.py), carry weight, Dash, Speed Soda, hatch odds/times,
nest stock+refill, pen income, saddle/incubator/pen-slot prices. Ignores: rebirth, weather, Mama, PvP, patches/lanes,
mutations, mistakes beyond a travel inefficiency factor."""
import io, contextlib, random, math, functools, statistics
with contextlib.redirect_stdout(io.StringIO()):
    from chase import chase
S = 1.25
BIOMES = ["Forest", "Lake", "Desert", "Jungle", "Tundra", "Volcano", "Cosmic"]
NESTZ = {"Forest": -273, "Lake": -475, "Desert": -737, "Jungle": -1066, "Tundra": -1465, "Volcano": -1941, "Cosmic": -2511}
SAFEZ, PLOTZ = -175, 35
FLY = {"Lake", "Cosmic"}
SPECIES = {"Forest": [("Chick", None), ("Bunny", "Jump"), ("Fox", "Dash")],
           "Lake": [("Duckling", "Swim"), ("Frog", "Jump"), ("Otter", "Swim")],
           "Desert": [("Scarab", None), ("Lizard", "Dash"), ("Vulture", "Glide")],
           "Jungle": [("Monkey", "Jump"), ("Parrot", "Glide"), ("Panther", "Dash")],
           "Tundra": [("Penguin", "Swim"), ("SnowOwl", "Glide"), ("Mammoth", None)],
           "Volcano": [("Salamander", "Fireproof"), ("EmberBat", "Glide"), ("Hellpup", "Dash")],
           "Cosmic": [("StarJelly", "Phase"), ("CometFox", "Dash"), ("BabyDragon", "Phase")]}
MOUNTBASE = {"Forest": 22.5, "Lake": 28.75, "Desert": 36.25, "Jungle": 43.75, "Tundra": 52.5, "Volcano": 63.75, "Cosmic": 75}
RAR = [("Common", 55, 1, 0), ("Uncommon", 28, 2, 2), ("Rare", 12, 4, 4), ("Epic", 4, 10, 7), ("Legendary", 1, 25, 12)]

BASE = dict(  # currently installed values
    guard={"Forest": 18, "Lake": 27, "Desert": 36, "Jungle": 48, "Tundra": 62, "Volcano": 72, "Cosmic": 92},  # raw, x1.25
    income={"Forest": 4, "Lake": 15, "Desert": 60, "Jungle": 200, "Tundra": 700, "Volcano": 2500, "Cosmic": 8000},
    carry={"Forest": .96, "Lake": .94, "Desert": .91, "Jungle": .88, "Tundra": .85, "Volcano": .82, "Cosmic": .80},
    hatch={"Forest": 10, "Lake": 20, "Desert": 30, "Jungle": 45, "Tundra": 60, "Volcano": 90, "Cosmic": 120},
    hatchX=[1, 1.5, 2, 3, 5], saddleBase=100, saddleGrowth=1.8, incub={3: 1e3, 4: 25e3, 5: 5e5, 6: 1e7},
    penBase=250, penGrowth=3, forestEggs=8, forestRefill=20, nestEggs=6, refill=300,
    gearSeconds=300, gearMin=500, inefficiency=1.3)


def saddleCost(P, level, ips):
    """fixed curve; with saddleSec set, at least saddleSec seconds of income x 1.15^level (scales with rebirths)"""
    fixed = P["saddleBase"] * P["saddleGrowth"] ** level
    return max(fixed, ips * P["saddleSec"] * 1.15 ** level) if P.get("saddleSec") else fixed


@functools.lru_cache(maxsize=None)
def escapeProb(gs, v, dist, fly, dash, tired):
    gaps = range(6, 37, 3)
    return sum(chase(gs, v, dist, g, tm=tired, dash=dash, lunge=not fly, dt=0.02).startswith("ESC") for g in gaps) / len(gaps)


def run(P, seed, verbose=False, target="Cosmic", tries=None):
    rng = random.Random(seed)
    st = dict(t=0.0, cash=0.0)
    saddle, incN, penN = 0, 2, 6
    pen, incub = [], []
    mount = None
    stock = {b: (P["forestEggs"] if b == "Forest" else P["nestEggs"]) for b in BIOMES}
    nextRefill = {b: (P["forestRefill"] if b == "Forest" else P["refill"]) for b in BIOMES}
    firsts = {}

    def income(c): return P["income"][c[0]] * RAR[c[3]][2]
    def ips(): return sum(income(c) for c in pen)
    def speedOf(c): return MOUNTBASE[c[0]] * S + RAR[c[3]][3] + (0 if c[2] else 2)

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
                    if b == "Forest": stock[b] = min(P["forestEggs"], stock[b] + 1)
                    else: stock[b] = P["nestEggs"]
                    nextRefill[b] += P["forestRefill"] if b == "Forest" else P["refill"]
            for item in [i for i in incub if i[0] <= st["t"] + 1e-9]:
                incub.remove(item); hatched(item[1])
            if st["t"] >= end - 1e-9: return

    def shop():
        nonlocal saddle, incN, penN
        while True:
            opts = []
            if saddle < 20: opts.append((saddleCost(P, saddle + 1, ips()), "saddle"))
            if incN < 6: opts.append((P["incub"][incN + 1], "incub"))
            if penN < 20: opts.append((P["penBase"] * P["penGrowth"] ** (penN + 1 - 7), "pen"))
            if not opts: return
            cost, what = min(opts)
            if cost > st["cash"]: return
            st["cash"] -= cost
            if what == "saddle": saddle += 1
            elif what == "incub": incN += 1
            else: penN += 1

    while st["t"] < 10 * 3600:
        shop()
        base = (speedOf(mount) if mount else 25) + saddle
        dash = mount is not None and mount[2] == "Dash"
        if P.get("secondSlot"):  # 2nd mount slot (Rebirth 6 / pass): speed of the faster, both abilities -> any Dash pet counts
            dash = dash or any(c[2] == "Dash" for c in pen)
        climb = mount is not None and mount[2] == "Climb"  # Crystal Caverns walls (crystal.py); no other biome uses it
        if P.get("secondSlot"):
            climb = climb or any(c[2] == "Climb" for c in pen)
        gear = max(P["gearMin"], math.floor(ips() * P["gearSeconds"]))
        best = None
        for i, b in enumerate(BIOMES):
            if stock[b] <= 0: continue
            dist = -NESTZ[b] + SAFEZ
            for soda in (False, True):
                if soda and st["cash"] < gear: continue
                v = base * P["carry"][b] * (P.get("soda", 1.25) if soda else 1)
                kw = {"climb": True} if climb and b in P.get("climbBiomes", ()) else {}
                p = escapeProb(P["guard"][b] * S, round(v, 1), dist, b in FLY, dash, P.get("tired", .95), **kw)
                if p >= 0.35 and (best is None or (i, p) > (best[0], best[2])):
                    best = (i, b, p, soda)
        if best is None or len(incub) >= incN:
            wait = min([f for f, _ in incub] + [st["t"] + 30]) - st["t"]
            advance(max(1.0, wait)); continue
        i, b, p, soda = best
        if tries is not None:
            tries.setdefault(b, base)  # free riding speed (mount + rarity + saddle) at the first attempt of b
        if soda: st["cash"] -= gear
        trip = (PLOTZ - NESTZ[b]) * P["inefficiency"]
        advance(trip / base + 2)
        stock[b] -= 1
        back = trip / (base * P["carry"][b])
        if rng.random() < p:
            advance(back)
            k = rng.choices(range(3), weights=[50, 35, 15])[0]
            r = rng.choices(range(5), weights=[x[1] for x in RAR])[0]
            sp, ab = SPECIES[b][k]
            incub.append((st["t"] + P["hatch"][b] * P["hatchX"][r], (b, sp, ab, r)))
            firsts.setdefault(b, st["t"])
            if b == target:
                if verbose: print({k: round(v / 60, 1) for k, v in firsts.items()}, "saddle", saddle, "mount", mount)
                return st["t"], firsts
        else:
            stock[b] += 1  # egg goes back to its nest
            advance(back * rng.uniform(.2, .6) + 1.5)  # caught partway, stunned, then walk on
    return math.inf, firsts


HUMAN = 30 / 11.7  # friend's real 30-min Cosmic on the OLD values vs this bot's 11.7-min median


def report(P, n=60, label="", target="Cosmic"):
    res = [run(P, s, target=target) for s in range(n)]
    times = sorted(r[0] / 60 for r in res)
    per = {b: statistics.median([r[1][b] / 60 for r in res if b in r[1]] or [math.nan]) for b in BIOMES}
    q = lambda f: times[min(len(times) - 1, int(f * len(times)))]
    print(f"{label:24} sim median {q(.5):5.1f} min ~ real {q(.5)*HUMAN/60:4.1f} h (p10 {q(.1):5.1f}, p90 {q(.9):5.1f} min) (p10 {q(.1):6.1f}, p90 {q(.9):6.1f}) | first deposit (median min): "
          + " ".join(f"{b[:3]} {per[b]:5.1f}" for b in BIOMES))
    return q(.5)


OLD = dict(BASE, guard={"Forest": 17.5, "Lake": 25, "Desert": 32.5, "Jungle": 41.25, "Tundra": 50, "Volcano": 60, "Cosmic": 72.5},
           income={"Forest": 5, "Lake": 30, "Desert": 150, "Jungle": 800, "Tundra": 4000, "Volcano": 20000, "Cosmic": 100000},
           carry={b: 1 for b in BIOMES}, hatchX=[1] * 5, gearSeconds=30, gearMin=50, tired=.8)

if __name__ == "__main__":
    report(OLD, label="OLD (before today)")
    report(BASE, label="INSTALLED now")
