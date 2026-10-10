"""Crystal Caverns placement layout (polish pass). One source of truth for the Blender preview and the Studio build.
Frame: x = lateral (-110..110), y = studs from the cave entrance toward the far end (0..700), z = up; rot = degrees
about the vertical axis. Studio: X = x, Y = z, Z = EntranceZ - y, CFrame.Angles(0, rad(rot), 0).
Gameplay rules kept here (asserted below):
  - 4 quartz walls evenly between the entrance and the nest, gaps alternate, gap width >= 2*pathRadius(6)+8 = 20
  - nothing that collides inside the play area except the walls (decor is CanCollide/CanQuery/CanTouch off)
  - wall gaps + their approach lanes, the 45-stud nest patrol circle and the strips along each wall stay clear
  - floor mounds <= 2 studs, only in the side bands, never in a gap lane
Run:  python layout.py  ->  layout.json"""
import json, math, os, random

W, D, H = 220, 700, 92          # cave width, depth, interior height (ceiling underside)
NEST_Y = D * .7                 # Config.Nests.depth 0.7 -> 490
WALL_YS = [round(NEST_Y * k / 5) for k in (1, 2, 3, 4)]   # 98 196 294 392
GAP = 28
WALL_T = 10
rng = random.Random(2026)
KB = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit_bounds.json")))


def front(asset, scale):
    """distance from origin to the face that points into the cave (kit fronts face -Y)"""
    return -KB[asset]["min"][1] * scale
items = []


def put(asset, x, y, z=0.0, rot=0.0, scale=1.0, kind="decor", **extra):
    items.append(dict(asset=asset, x=round(x, 2), y=round(y, 2), z=round(z, 2), rot=round(rot % 360, 1),
                      scale=round(scale, 3), kind=kind, **extra))


def gap_side(i):
    return 1 if i % 2 == 0 else -1          # +1: gap at +x end


def in_gap_lane(x, y, margin=0.0):
    """the open end of each wall plus the approach on both sides, where the Golem and non-Climb riders run"""
    for i, wy in enumerate(WALL_YS):
        g = gap_side(i)
        if abs(y - wy) < 38 + margin and g * x > W / 2 - GAP - 14 - margin:
            return True
    return False


def near_wall(y, pad=16):
    return any(abs(y - wy) < WALL_T / 2 + pad for wy in WALL_YS)


def in_nest(x, y, r=45):
    return math.hypot(x, y - NEST_Y) < r


# ---------------------------------------------------------------- climb walls (gameplay; existing QuartzWall meshes)
walls = []
for i, wy in enumerate(WALL_YS):
    g = gap_side(i)
    x0, x1 = (-W / 2, W / 2 - GAP) if g > 0 else (-W / 2 + GAP, W / 2)
    span = x1 - x0
    for j, name in enumerate(rng.sample(["QuartzWallA", "QuartzWallB", "QuartzWallC"], 3)):
        cx = x0 + span * (j + .5) / 3
        put(name, cx, wy, 0, 0, 1, kind="wall", sx=round(span / 3 / 60, 4), row=i + 1)
        put("WallCrest", cx, wy, 40, 0, 1, kind="glow", sx=round(span / 3 / 60, 4), color="cyan", row=i + 1)
        for face in (-1, 1):                 # flush handholds in a loose climbing route, both faces
            for route in (rng.choice((-1, 1)),):  # one diagonal climbing route per slab face
                lean = rng.choice((-1, 1))
                for k in range(5):
                    hx = cx + route * span / 9 + lean * (k - 2) * 2.2 + rng.uniform(-.8, .8)
                    put("Handhold", hx, wy + face * (WALL_T / 2 - .1), 6 + k * 7 + rng.uniform(-1, 1), 0 if face < 0 else 180,
                        1, kind="glow", color="cyan", row=i + 1)
    walls.append(dict(row=i + 1, y=wy, gap_side=g, gap=GAP, x0=x0, x1=x1))
    # gap markers: warm amber glow at the open end = "the way through for everyone"
    gx = g * (W / 2 - GAP / 2)
    for face in (-1, 1):
        put("GlowClusterBig", g * (W / 2 - GAP - 2), wy + face * 7.5, 0, rng.uniform(0, 360), 1.2, kind="glow", color="amber")
    put("light", gx, wy, 14, kind="light", color="amber", range=26, brightness=1.2)

# ---------------------------------------------------------------- cave shell formations (outside the play area)
for side in (-1, 1):
    y = -6.0
    n = 0
    while y < D + 10:
        a = ("CaveRockA", "CaveRockB", "CaveRockC")[n % 3]
        s = rng.uniform(.95, 1.2)
        put(a, side * (W / 2 + front(a, s) + 6), y, -2, 90 * -side + rng.uniform(-3, 3), s, kind="shell")  # front ~ at the boundary
        b, s2 = ("CaveRockB", "CaveRockC", "CaveRockA")[n % 3], rng.uniform(.9, 1.1)
        put(b, side * (W / 2 + front(b, s2) + 10), y + 20, 44, 90 * -side + rng.uniform(-4, 4), s2, kind="shell")
        y += rng.uniform(40, 50)
        n += 1
for k, x in enumerate(range(-100, 101, 50)):             # far end wall
    a = ("CaveRockC", "CaveRockA", "CaveRockB")[k % 3]
    put(a, x, D + front(a, 1.1), -2, 180 + rng.uniform(-6, 6), 1.1, kind="shell")
    b = ("CaveRockA", "CaveRockB")[k % 2]
    put(b, x + 20, D + front(b, 1) + 6, 44, 180 + rng.uniform(-6, 6), 1, kind="shell")

# ceiling: rock masses hang from the shell; open cracks (light shafts) at CRACKS; high clearance over the wall rows
CRACKS = [60, 250, NEST_Y, 610]
for y in range(-10, D + 20, 52):
    for x in range(-90, 91, 60):
        yy = y + rng.uniform(-8, 8)
        xx = x + rng.uniform(-10, 10)
        if any(abs(yy - c) < 30 for c in CRACKS) and abs(xx) < 70:
            continue
        drop_ok = not near_wall(yy, 26)
        put(rng.choice(["CeilingRockA", "CeilingRockB"]), xx, yy, H + (0 if drop_ok else 12), rng.uniform(0, 360),
            rng.uniform(.9, 1.15), kind="shell")
        if drop_ok and rng.random() < .55:
            put("Stalactites", xx + rng.uniform(-18, 18), yy + rng.uniform(-14, 14), H - 8, rng.uniform(0, 360),
                rng.uniform(.9, 1.4), kind="shell")
for c in CRACKS:
    put("CeilingCrack", 0 if c != NEST_Y else 0, c, H - 2, rng.uniform(0, 360), 1.7, kind="shell")
    put("shaft", 0, c, H / 2, kind="shaft", height=H, width=34 if c == NEST_Y else 22)

# floor-to-ceiling pillars in the side bands (decor, non-colliding), away from gap lanes
for y in (40, 150, 245, 345, 455, 560, 650):
    for side in (-1, 1):
        x = side * rng.uniform(92, 100)
        if in_gap_lane(x, y, 6) or near_wall(y, 10):
            continue
        if rng.random() < .7:
            put("RockPillar", x, y, -1, rng.uniform(0, 360), rng.uniform(1.0, 1.15), kind="shell")

# wall-embedded crystals on the cave sides: textured growths + a few glowing seams (purple/blue, never cyan)
for side in (-1, 1):
    for k in range(22):
        y = rng.uniform(10, D - 10)
        z = rng.uniform(6, 42)
        if in_gap_lane(side * (W / 2 - 1), y, 6):
            continue
        put("WallGrowth", side * (W / 2 - 1), y, z, 90 * -side + rng.uniform(-25, 25), rng.uniform(1.8, 2.6), kind="decor")
    for k in range(9):
        y = rng.uniform(15, D - 15)
        if in_gap_lane(side * (W / 2 - 3), y, 6):
            continue
        put("GlowClusterBig", side * (W / 2 - 3), y, rng.uniform(2, 30), rng.uniform(0, 360), rng.uniform(1, 1.6), kind="glow",
            color=("violet", "blue")[k % 2])

# ---------------------------------------------------------------- the nest: centrepiece crown (behind and around)
put("NestCrown", 0, NEST_Y, 0, kind="marker")
for k, (ang, r, tall) in enumerate([(-105, 54, 0), (-75, 60, 1), (-40, 52, 0), (-15, 66, 1), (15, 66, 1), (40, 52, 0),
                                     (75, 60, 1), (105, 54, 0)]):
    a = math.radians(ang + 90)               # 90 = the far side (+y); the exit side (-y) stays open
    x, y = math.cos(a) * r, NEST_Y + math.sin(a) * r
    put("CrystalSpireTall" if tall else "CrystalSpire", x, y, 0, rng.uniform(0, 360), rng.uniform(1.0, 1.2) * (1.2 if k in (3, 4) else 1))
for k in range(10):                          # low glowing ring just outside the eggs (no collision)
    a = 2 * math.pi * k / 10
    put("GlowCluster", math.cos(a) * 15, NEST_Y + math.sin(a) * 15, 0, rng.uniform(0, 360), rng.uniform(1.0, 1.4), kind="glow",
        color=("cyan", "violet")[k % 2])
put("light", 0, NEST_Y, 16, kind="light", color="cyan", range=40, brightness=1.6)
put("light", 0, NEST_Y + 55, 24, kind="light", color="violet", range=45, brightness=1.0)

# ---------------------------------------------------------------- scatter: crystals, debris, mounds (no straight corridor)
placed = 0
tries = 0
while placed < 60 and tries < 3000:
    tries += 1
    x, y = rng.uniform(-W / 2 + 10, W / 2 - 10), rng.uniform(20, D - 15)
    if in_gap_lane(x, y, 4) or near_wall(y) or in_nest(x, y, 48):
        continue
    if abs(x) < 70 and rng.random() < .55:   # the middle stays sparser but not empty
        continue
    r = rng.random()
    if r < .55:
        put("CrystalCluster%d" % rng.randint(1, 4), x, y, 0, rng.uniform(0, 360), rng.uniform(.9, 1.5))
    elif r < .8:
        put("ShardDebris", x, y, 0, rng.uniform(0, 360), rng.uniform(.9, 1.4))
    else:
        put(rng.choice(["Boulder1", "Boulder2"]), x, y, -.5, rng.uniform(0, 360), rng.uniform(.8, 1.3))
    placed += 1
for side in (-1, 1):                          # debris at the closed foot of each wall (never at the gap end)
    for i, wy in enumerate(WALL_YS):
        if side == gap_side(i):
            continue
        for face in (-1, 1):
            put("ShardDebris", side * rng.uniform(60, 95), wy + face * 9, 0, rng.uniform(0, 360), rng.uniform(1, 1.3))
for k in range(16):                           # floor swells: side bands only, outside gap lanes
    side = rng.choice((-1, 1))
    x, y = side * rng.uniform(80, 98), rng.uniform(15, D - 20)
    if in_gap_lane(x, y, 8) or near_wall(y, 8):
        continue
    put("FloorMound", x, y, 0, rng.uniform(0, 360), rng.uniform(1, 1.4), kind="mound")
for k in range(8):                            # entrance glow: soft cyan seams guiding into the cave
    side = (-1, 1)[k % 2]
    put("GlowClusterBig", side * rng.uniform(70, 96), rng.uniform(6, 40), 0, rng.uniform(0, 360), rng.uniform(1, 1.3), kind="glow",
        color="blue")
put("light", 0, 18, 18, kind="light", color="blue", range=40, brightness=.8)

# ---------------------------------------------------------------- checks
for w in walls:
    assert w["gap"] >= 2 * 6 + 8, w
for it in items:
    if it["kind"] in ("decor", "glow", "mound") and it["asset"] not in ("Handhold", "WallCrest", "GlowCluster"):
        for w in walls:
            g = w["gap_side"]
            gx0 = W / 2 - GAP if g > 0 else -W / 2
            inside_gap = gx0 <= it["x"] <= gx0 + GAP and abs(it["y"] - w["y"]) < 20
            assert not inside_gap, ("decor inside a wall gap", it)
    if it["kind"] == "mound":
        assert abs(it["x"]) >= 78, it
lights = sum(1 for it in items if it["kind"] == "light")
assert lights <= 12, lights
for it in items:                              # shell rock fronts never reach into the play area
    if it["asset"].startswith("CaveRock") and abs(abs(it["rot"]) % 180 - 90) < 10:
        assert abs(it["x"]) - front(it["asset"], it["scale"]) >= W / 2 - 1, it
json.dump(dict(W=W, D=D, H=H, NEST_Y=NEST_Y, WALL_YS=WALL_YS, GAP=GAP, walls=walls, items=items),
          open(__file__.replace("layout.py", "layout.json"), "w"), indent=1)
counts = {}
for it in items:
    counts[it["asset"]] = counts.get(it["asset"], 0) + 1
print("items", len(items), "lights", lights)
print(sorted(counts.items(), key=lambda kv: -kv[1]))
