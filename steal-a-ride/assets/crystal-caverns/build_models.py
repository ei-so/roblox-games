"""Crystal Caverns models (biome 9): Crystal Golem (Body/LeftLeg/RightLeg/LeftArm/RightArm + Neon Core, origins at the
hinges), three pets (one joined mesh each, legs below one cut height) and props. Chunky faceted low-poly quartz.
1 Blender unit = 1 stud. Creatures face -Y (exports to Roblox -Z = forward).
Material slots are flat colours; export_models.py collapses them onto a palette texture (one material per mesh).
Headless:  blender -b --factory-startup -P build_models.py -- <out.blend>"""
import bpy, bmesh, math, random, sys
from mathutils import Vector, Euler

OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ---------------------------------------------------------------- flat colours (palette swatches)
def mat(name, rgb, transmission=0.0, rough=0.3, emit=0.0, coat=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = tuple((x / 255) ** 2.2 for x in rgb) + (1,)
    b.inputs["Base Color"].default_value = c
    b.inputs["Roughness"].default_value = rough
    b.inputs["Transmission Weight"].default_value = transmission
    b.inputs["IOR"].default_value = 1.45
    b.inputs["Coat Weight"].default_value = coat
    if emit:
        b.inputs["Emission Color"].default_value = c
        b.inputs["Emission Strength"].default_value = emit
    m["rgb"] = list(rgb)
    return m

M = {
    "quartz": mat("Quartz", (196, 222, 255), transmission=0.35, rough=0.1),     # clear blue-white crystal
    "milky": mat("MilkyQuartz", (236, 238, 250), rough=0.25),                  # body quartz
    "lilac": mat("LilacQuartz", (214, 200, 250), rough=0.2),                   # second crystal tint
    "shade": mat("QuartzShade", (150, 158, 198), rough=0.35),                  # joints, bellies, bands
    "stone": mat("CaveStone", (112, 114, 128), rough=0.8, coat=0),
    "dark": mat("Dark", (34, 36, 52), rough=0.25),
    "white": mat("EyeWhite", (252, 252, 255), rough=0.2),
    "cyan": mat("GemCyan", (70, 230, 255), emit=1.2, rough=0.1),
    "pink": mat("GemPink", (255, 120, 205), emit=1.0, rough=0.1),
    "gold": mat("GemAmber", (255, 196, 70), emit=0.8, rough=0.1),
    "violet": mat("GemViolet", (170, 120, 255), emit=1.0, rough=0.1),
    "mint": mat("GemMint", (110, 250, 180), emit=0.8, rough=0.1),
}
RAINBOW = ("pink", "gold", "mint", "cyan", "violet")

# ---------------------------------------------------------------- geometry helpers (all into one bmesh)
class Mesh:
    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def slot(self, key):
        if key not in self.mats:
            self.mats.append(key)
        return self.mats.index(key)

    def _faces(self, verts, key):
        i = self.slot(key)
        fs = {f for v in verts for f in v.link_faces}
        for f in fs:
            f.material_index = i
        return fs

    def blob(self, center, scale, key, subdiv=2, jitter=0.05, seed=0, rot=(0, 0, 0)):
        rng = random.Random(seed)
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1)["verts"]
        rm = Euler(rot).to_matrix()
        for v in r:
            p = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
            p += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jitter * min(scale)
            v.co = rm @ p + Vector(center)
        return self._faces(r, key)

    def crystal(self, base, direction, length, radius, key, tip=0.32, sides=6, twist=0.0):
        d = Vector(direction).normalized()
        q = Vector((0, 0, 1)).rotation_difference(d).to_matrix()
        ring0, ring1 = [], []
        for i in range(sides):
            a = twist + 2 * math.pi * i / sides
            x, y = math.cos(a) * radius, math.sin(a) * radius
            ring0.append(self.bm.verts.new(q @ Vector((x, y, 0)) + Vector(base)))
            ring1.append(self.bm.verts.new(q @ Vector((x * .95, y * .95, length * (1 - tip))) + Vector(base)))
        top = self.bm.verts.new(q @ Vector((0, 0, length)) + Vector(base))
        self.bm.faces.new(list(reversed(ring0)))
        for i in range(sides):
            j = (i + 1) % sides
            self.bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
            self.bm.faces.new((ring1[i], ring1[j], top))
        return self._faces(ring0 + ring1 + [top], key)

    def pillar(self, a, b, r1, r2, key, sides=6, twist=0.0):
        a, b = Vector(a), Vector(b)
        d = b - a
        q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
        ring0, ring1 = [], []
        for i in range(sides):
            ang = twist + 2 * math.pi * i / sides
            ring0.append(self.bm.verts.new(q @ Vector((math.cos(ang) * r1, math.sin(ang) * r1, 0)) + a))
            ring1.append(self.bm.verts.new(q @ Vector((math.cos(ang) * r2, math.sin(ang) * r2, d.length)) + a))
        self.bm.faces.new(list(reversed(ring0)))
        self.bm.faces.new(ring1)
        for i in range(sides):
            j = (i + 1) % sides
            self.bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
        return self._faces(ring0 + ring1, key)

    def box(self, center, size, key, rot=(0, 0, 0), taper=1.0):
        r = bmesh.ops.create_cube(self.bm, size=1)["verts"]
        rm = Euler(rot).to_matrix()
        for v in r:
            s = taper if v.co.z > 0 else 1.0
            v.co = rm @ Vector((v.co.x * size[0] * s, v.co.y * size[1] * s, v.co.z * size[2])) + Vector(center)
        return self._faces(r, key)

    def eye(self, center, r, seed, look=(0, -1, 0)):
        """cute eye: white ball + big dark pupil + a tiny highlight, facing `look`"""
        c, l = Vector(center), Vector(look).normalized()
        self.blob(c, (r, r, r), "white", subdiv=1, jitter=0, seed=seed)
        self.blob(c + l * r * .55, (r * .62, r * .62, r * .62), "dark", subdiv=1, jitter=0, seed=seed + 1)
        self.blob(c + l * r * .95 + Vector((r * .2, 0, r * .25)), (r * .18, r * .18, r * .18), "white", subdiv=1, jitter=0, seed=seed + 2)

    def finish(self, name, origin=(0, 0, 0), collection=None, bevel=0.0):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        for v in self.bm.verts:
            v.co -= Vector(origin)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for key in self.mats:
            me.materials.append(M[key])
        ob = bpy.data.objects.new(name, me)
        ob.location = origin
        (collection or scene.collection).objects.link(ob)
        if bevel:
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width, mod.segments, mod.limit_method, mod.angle_limit = bevel, 1, "ANGLE", math.radians(35)
        return ob


def coll(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c

# ================================================================= CRYSTAL GOLEM (~20 studs tall, hulking, big fists)
G = coll("Golem")
HIP_Z, SHOULDER_Z, HIP_X, SHOULDER_X = 7.0, 14.4, 2.6, 6.0

body = Mesh()
body.blob((0, 0.2, 11.8), (5.6, 4.2, 5.2), "milky", jitter=.07, seed=1)                  # barrel chest
body.blob((0, 0.3, 15.0), (6.3, 4.0, 2.6), "milky", jitter=.06, seed=2)                  # shoulder mass
body.blob((0, 0.5, 8.0), (3.9, 3.0, 1.9), "shade", jitter=.05, seed=4)                   # hip band
body.blob((0, -1.7, 17.4), (2.9, 2.5, 2.3), "milky", jitter=.05, seed=3)                 # big head, forward
body.box((0, -3.6, 18.4), (4.6, 1.0, 0.9), "shade", rot=(math.radians(-12), 0, 0), taper=.85)  # heavy brow
for side in (-1, 1):                                                                     # shoulder crystal crowns
    for i, (dx, dy, ln, r, tilt) in enumerate([(4.6, 0.6, 6.0, 1.1, .5), (3.4, 1.6, 4.6, .85, .3), (5.6, -0.8, 3.8, .75, .85),
                                                 (2.4, 2.2, 3.2, .65, .15), (5.0, 1.8, 3.0, .6, .6)]):
        body.crystal((side * dx, dy, 15.6), (side * tilt, 0.3, 1), ln, r, "quartz" if i % 2 == 0 else "lilac", twist=i)
for i, (x, z, ln, tilt) in enumerate([(0, 15.2, 5.0, 0), (-2.0, 13.4, 3.8, -.35), (2.0, 13.2, 3.6, .35), (0, 11.0, 3.2, 0),
                                       (-1.2, 9.6, 2.4, -.2), (1.2, 9.6, 2.4, .2)]):
    body.crystal((x, 3.4, z), (tilt, 1, .7), ln, .8, "quartz" if i % 2 else "lilac", twist=i)   # back spines
for i, (x, z) in enumerate([(-2.6, 13.4), (2.8, 12.6), (-3.2, 10.6), (3.0, 9.9)]):           # rainbow chips in the chest
    body.crystal((x, -3.4, z), (x * .1, -1, .3), .9, .35, RAINBOW[i], tip=.5)
body.finish("Body", (0, 0, 0), G)

core = Mesh()
core.blob((0, -3.9, 12.2), (1.7, .9, 1.7), "cyan", subdiv=1, jitter=.03, seed=9)           # chest core gem
core.crystal((0, -4.2, 12.2), (0, -1, 0), 1.0, 1.3, "cyan", tip=.6, sides=8)
for side in (-1, 1):
    core.blob((side * 1.05, -3.9, 17.6), (.55, .3, .42), "cyan", subdiv=1, jitter=0, seed=10)  # glowing eyes
core.finish("Core", (0, 0, 0), G)

for side, label in ((-1, "Left"), (1, "Right")):
    leg = Mesh()
    hip = (side * HIP_X, 0.4, HIP_Z)
    leg.blob((side * HIP_X, 0.4, HIP_Z), (1.9, 1.9, 1.7), "shade", subdiv=1, jitter=.04, seed=11)  # hip joint
    leg.pillar((side * HIP_X, 0.4, HIP_Z), (side * (HIP_X + .3), 0.1, 2.0), 2.2, 1.9, "milky", twist=.3)
    leg.box((side * (HIP_X + .3), -0.6, 0.9), (3.8, 4.8, 1.8), "milky", taper=.78)               # big blocky foot
    leg.crystal((side * (HIP_X + 1.5), -0.4, 4.4), (side, -.3, .6), 2.2, .55, "quartz")          # knee shard
    leg.finish(label + "Leg", hip, G)

    arm = Mesh()
    sh = (side * SHOULDER_X, 0.2, SHOULDER_Z)
    elbow = (side * (SHOULDER_X + 1.4), -0.3, 9.9)
    wrist = (side * (SHOULDER_X + 1.7), -0.9, 6.2)
    arm.blob(sh, (2.3, 2.3, 2.3), "shade", subdiv=1, jitter=.05, seed=20 + side)                  # shoulder ball
    arm.pillar(sh, elbow, 1.6, 1.45, "milky", twist=.2)
    arm.pillar(elbow, wrist, 1.6, 1.95, "milky", twist=.5)
    arm.pillar(wrist, (side * (SHOULDER_X + 1.75), -1.0, 5.5), 2.15, 2.15, "shade", sides=8)     # gauntlet band
    arm.blob((side * (SHOULDER_X + 1.8), -1.1, 4.0), (2.7, 2.5, 2.3), "milky", jitter=.06, seed=30 + side)  # huge fist
    for i, (dz, ln) in enumerate([(9.0, 3.0), (7.8, 2.4), (6.8, 1.8)]):                          # forearm shards
        arm.crystal((side * (SHOULDER_X + 2.9), 0.5, dz), (side, .6, .5), ln, .6, "lilac" if i == 1 else "quartz", twist=i)
    arm.finish(label + "Arm", sh, G)

# ================================================================= PETS (one joined mesh each; legs below the cut)
P = coll("Pets")
CUTS = {}


def pet(name, build, offset, bevel=0.025):
    m = Mesh()
    cut = build(m)
    ob = m.finish(name, (0, 0, 0), P, bevel=bevel)
    ob.location = offset
    zs = [v.co.z for v in ob.data.vertices]
    CUTS[name] = round((cut - min(zs)) / (max(zs) - min(zs)), 3)
    return ob


def beetle(m):  # round quartz dome shell with gem studs, cute big-eyed head, gem horn, 6 short legs
    cut = 0.55
    m.blob((0, 0.25, 1.35), (1.55, 1.75, 1.05), "quartz", jitter=.03, seed=41)             # shell dome
    m.box((0, 0.25, 1.95), (.12, 3.0, .5), "lilac")                                          # shell seam
    m.blob((0, 0.25, 0.95), (1.4, 1.6, .42), "shade", jitter=.02, seed=42)                   # belly (above the cut)
    m.blob((0, -1.55, 1.15), (.95, .8, .72), "shade", jitter=.03, seed=43)                   # head
    m.crystal((0, -2.15, 1.45), (0, -1, 1.1), 1.0, .3, "cyan")                                # horn
    for side in (-1, 1):
        m.eye((side * .48, -2.15, 1.3), .3, 44, look=(side * .25, -1, .1))
        for i, (y, z) in enumerate([(-0.6, 2.0), (0.4, 2.2), (1.3, 1.85)]):
            m.crystal((side * .78, y, z - .15), (side * .45, 0, 1), .55, .2, RAINBOW[(i + (side > 0) * 2) % 5])
        for y in (-0.85, -0.3, 0.9):                                                          # legs (none cross y = 0)
            m.pillar((side * .95, y, cut + .2), (side * 1.45, y - .15 * side, 0.25), .17, .14, "shade", sides=5)
            m.pillar((side * 1.45, y - .15 * side, 0.25), (side * 1.6, y - .2 * side, 0.02), .14, .1, "dark", sides=5)
    return cut


def gecko(m):  # chunky cute gecko: big head + eyes on top, gem studs down the back, sticky gem toe pads
    cut = 0.62
    m.blob((0, 0.25, 1.0), (.85, 1.45, .55), "milky", jitter=.03, seed=51)                   # body
    m.blob((0, 0.25, 0.8), (.7, 1.3, .25), "shade", jitter=.02, seed=56)                     # belly
    m.blob((0, -1.55, 1.25), (.85, .8, .55), "milky", jitter=.03, seed=52)                   # big head
    for side in (-1, 1):
        m.eye((side * .55, -1.7, 1.7), .33, 53, look=(side * .5, -1, .3))                    # eyes on top of the head
    m.box((0, -2.25, 1.08), (.7, .1, .08), "dark")                                           # smile
    m.pillar((0, 1.55, 1.0), (0.2, 2.6, 0.95), .45, .28, "milky", sides=6)                  # tail (above the cut)
    m.pillar((0.2, 2.6, 0.95), (.7, 3.2, 1.35), .28, .1, "milky", sides=6)
    for i, y in enumerate((-0.95, -0.35, 0.25, 0.85, 1.45)):                                 # rainbow back studs
        m.crystal((0, y, 1.48 - .06 * abs(y)), (0, 0, 1), .45, .2, RAINBOW[i])
    for side in (-1, 1):
        for front, y in ((-1, -0.65), (1, 0.95)):
            knee = (side * 1.15, y + .1 * front, cut + .15)
            m.pillar((side * .55, y, cut + .35), knee, .22, .19, "milky", sides=6)          # upper leg (into the body)
            m.pillar(knee, (side * 1.3, y + .2 * front, 0.1), .19, .16, "milky", sides=6)
            m.blob((side * 1.33, y + .25 * front, 0.08), (.3, .3, .08), "cyan", subdiv=1, jitter=0, seed=55)  # toe pad
    return cut + .15


def pangolin(m):  # big like the Mammoth: rows of overlapping quartz scale plates, cute face, curled gem tail
    cut = 0.95
    m.blob((0, 0.2, 1.85), (1.45, 1.75, 1.0), "shade", subdiv=1, jitter=.03, seed=61)          # body core (under the plates)
    rows = [(-1.25, 2.3, 1.2), (-0.75, 2.7, 1.45), (-0.2, 3.0, 1.6), (0.35, 3.1, 1.65), (0.9, 2.95, 1.55), (1.45, 2.6, 1.35),
            (1.9, 2.15, 1.1)]
    for row, (y, z, w) in enumerate(rows):
        for k in range(-3, 4):
            x = k * w * .3
            if abs(x) > w: continue
            ang = math.atan2(x, 1.0)
            m.box((x * 1.05, y, z - (abs(k) * .3) ** 1.6 - .1), (.95, 1.05, .28), ("quartz", "lilac", "milky")[(row + k) % 3],
                  rot=(math.radians(-24), ang * .95, 0), taper=.7)                         # overlapping scale plates
    m.blob((0, -1.95, 1.7), (.85, .9, .75), "shade", jitter=.03, seed=63)                    # head
    m.pillar((0, -2.6, 1.55), (0, -3.15, 1.35), .4, .2, "shade", sides=6)                   # snout
    m.blob((0, -3.2, 1.35), (.18, .14, .14), "pink", subdiv=1, jitter=0, seed=65)            # nose
    for side in (-1, 1):
        m.eye((side * .45, -2.55, 2.05), .26, 64, look=(side * .3, -1, 0))
        m.blob((side * .75, -1.6, 2.3), (.25, .15, .3), "shade", subdiv=1, jitter=0, seed=66)  # ears
    m.pillar((0, 2.0, 1.7), (0, 2.75, 1.3), .8, .5, "milky", sides=6)                        # tail curling up
    m.pillar((0, 2.75, 1.3), (0, 3.05, 2.2), .5, .25, "milky", sides=6)
    m.crystal((0, 3.05, 2.2), (0, .2, 1), .65, .25, "cyan")
    m.crystal((0, -0.2, 3.25), (0, 0, 1), .7, .28, "pink")
    for side in (-1, 1):
        for y in (-1.0, 1.15):
            m.pillar((side * 1.05, y, cut + .45), (side * 1.15, y, 0.05), .5, .42, "shade", sides=6)  # stubby legs
            for c in (-.2, 0, .2):
                m.crystal((side * 1.15 + c, y - .4, 0.12), (0, -1, -.1), .3, .09, "white", sides=4)  # claws
    return cut


pet("CrystalBeetle", beetle, (-6, 0, 0))
pet("GemGecko", gecko, (0, 0, 0))
pet("CrystalPangolin", pangolin, (6.5, 0, 0), bevel=0)  # its many plates would pass 4k tris bevelled

# ================================================================= PROPS
R = coll("Props")


def wall(name, seed, x):
    """60 wide (X), 40 tall, 10 deep faceted quartz slab: front/back faces chipped inward only (stays inside the box),
    flat walkable top at 40, patchy crystal colours, short shards along the foot"""
    rng = random.Random(seed)
    m = Mesh()
    nx, nz = 10, 6
    grid = {}
    for side in (-1, 1):
        for i in range(nx + 1):
            for k in range(nz + 1):
                edge = i in (0, nx) or k in (0, nz)
                px = -30 + 60 * i / nx + (0 if i in (0, nx) else rng.uniform(-1.8, 1.8))
                pz = 40 * k / nz + (0 if k in (0, nz) else rng.uniform(-2, 2))
                py = side * (5 - (0.3 if edge else rng.uniform(0.2, 1.6)))
                grid[side, i, k] = m.bm.verts.new((px, py, pz))
    keys = ("milky", "milky", "quartz", "lilac")
    for side in (-1, 1):
        for i in range(nx):
            for k in range(nz):
                q = [grid[side, i, k], grid[side, i + 1, k], grid[side, i + 1, k + 1], grid[side, i, k + 1]]
                for tri in ((q[0], q[1], q[2]), (q[0], q[2], q[3])):           # triangles = crisp facets
                    f = m.bm.faces.new(tri if side < 0 else tuple(reversed(tri)))
                    f.material_index = m.slot(keys[rng.randrange(4)])
    def strip(a, b):
        for n in range(len(a) - 1):
            f = m.bm.faces.new((a[n], a[n + 1], b[n + 1], b[n]))
            f.material_index = m.slot("milky")
    strip([grid[-1, i, nz] for i in range(nx + 1)], [grid[1, i, nz] for i in range(nx + 1)])        # top
    strip([grid[1, i, 0] for i in range(nx + 1)], [grid[-1, i, 0] for i in range(nx + 1)])          # bottom
    strip([grid[1, 0, k] for k in range(nz + 1)], [grid[-1, 0, k] for k in range(nz + 1)])          # ends
    strip([grid[-1, nx, k] for k in range(nz + 1)], [grid[1, nx, k] for k in range(nz + 1)])
    for n in range(14):                                                                            # foot shards
        side = rng.choice((-1, 1))
        px = rng.uniform(-28, 28)
        m.crystal((px, side * 4.2, 0), (rng.uniform(-.3, .3), side * .45, 1), rng.uniform(3, 6), rng.uniform(.6, 1.1),
                  ("quartz", "lilac", "milky")[n % 3], twist=rng.uniform(0, 1))
    ob = m.finish(name, (0, 0, 0), R)
    ob.location = (x, 40, 0)
    return ob


def cluster(name, seed, x, n, hmax):
    rng = random.Random(seed)
    m = Mesh()
    m.blob((0, 0, .4), (3.2, 2.6, 1.2), "stone", subdiv=1, jitter=.15, seed=seed)
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 1.8) if i else 0
        h = rng.uniform(hmax * .35, hmax * .8) if i else hmax
        m.crystal((math.cos(a) * r, math.sin(a) * r, .3), (math.cos(a) * rng.uniform(.15, .55), math.sin(a) * rng.uniform(.15, .55), 1),
                  h, (.55 + .5 * h / hmax) * 1.2, ("quartz", "milky", "lilac")[i % 3], twist=rng.uniform(0, 1))
    m.crystal((rng.uniform(-1, 1), rng.uniform(-1, 1), .5), (0, 0, 1), hmax * .25, .35, RAINBOW[seed % 5])
    ob = m.finish(name, (0, 0, 0), R)
    ob.location = (x, -20, 0)
    return ob


def boulder(name, seed, x, size):
    m = Mesh()
    m.blob((0, 0, size[2] * .8), size, "stone", subdiv=2, jitter=.12, seed=seed)
    ob = m.finish(name, (0, 0, 0), R)
    ob.location = (x, -45, 0)
    return ob


def ceiling_crack(x):
    """a jagged stone rim (about 46 x 28) framing an opening in the cave ceiling; light shafts come through it"""
    rng = random.Random(77)
    m = Mesh()
    n = 18
    for i in range(n):
        a = 2 * math.pi * i / n
        rx, ry = 18 + rng.uniform(-2, 2), 10 + rng.uniform(-1.5, 1.5)
        m.blob((math.cos(a) * rx, math.sin(a) * ry, 0), (4.2, 3.2, 1.6), "stone", subdiv=1, jitter=.25, seed=80 + i)
        if i % 3 == 0:
            m.crystal((math.cos(a) * (rx - 2.5), math.sin(a) * (ry - 1.5), -1), (-math.cos(a) * .4, -math.sin(a) * .4, -1),
                      rng.uniform(2, 4), .5, "quartz")
    ob = m.finish("CeilingCrack", (0, 0, 0), R)
    ob.location = (x, -80, 20)
    return ob


wall("QuartzWallA", 101, -70)
wall("QuartzWallB", 102, 0)
wall("QuartzWallC", 103, 70)
for i, (n, h) in enumerate([(5, 9), (7, 13), (4, 6), (9, 16)]):
    cluster(f"CrystalCluster{i + 1}", 200 + i, -30 + i * 20, n, h)
boulder("Boulder1", 301, -12, (5, 4, 3.5))
boulder("Boulder2", 302, 12, (7, 5.5, 4.5))
ceiling_crack(0)

# ---------------------------------------------------------------- report: triangles per object (modifiers applied)
dg = bpy.context.evaluated_depsgraph_get()
def tris(ob):
    me = ob.evaluated_get(dg).to_mesh()
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    ob.evaluated_get(dg).to_mesh_clear()
    return n

print("TRIS Golem total", sum(tris(o) for o in G.objects), {o.name: tris(o) for o in G.objects})
for o in list(P.objects) + list(R.objects):
    d = o.dimensions
    print("TRIS", o.name, tris(o), "size %.1f x %.1f x %.1f" % (d.x, d.y, d.z))
print("CUTS", CUTS)
scene["legCuts"] = str(CUTS)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT)
