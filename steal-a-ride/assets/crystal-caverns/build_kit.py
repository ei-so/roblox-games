"""Crystal Caverns environment kit (polish pass): reusable low-poly formations that hide the flat cave box.
Same conventions as build_models.py: 1 Blender unit = 1 stud, Z-up, origin at the base centre (ceiling pieces: top
centre), per-face material keys that bake_export.py turns into one gradient texture per mesh.
Keys: rock (cave slate), quartz (blue crystal), lilac (second crystal tint), glow (Neon in Studio, colour set there).
Headless:  blender -b --factory-startup -P build_kit.py -- <out.blend>"""
import bpy, bmesh, math, random, sys
from mathutils import Vector, Euler, noise

OUT = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
KEYS = {"rock": (74, 82, 108), "quartz": (90, 170, 250), "lilac": (150, 140, 245), "glow": (120, 240, 255)}
MATS = {}
for k, rgb in KEYS.items():
    m = bpy.data.materials.new("Kit_" + k)
    m.diffuse_color = tuple(c / 255 for c in rgb) + (1,)
    m["key"] = k
    MATS[k] = m
KIT = bpy.data.collections.new("Kit")
scene.collection.children.link(KIT)


class Mesh:
    def __init__(self):
        self.bm = bmesh.new()
        self.keys = []

    def _tag(self, faces, key):
        if key not in self.keys:
            self.keys.append(key)
        for f in faces:
            f.material_index = self.keys.index(key)

    def rock(self, center, scale, seed, key="rock", subdiv=2, rough=0.28, flat_bottom=None, rot=(0, 0, 0)):
        """lumpy faceted rock: icosphere pushed by 3D noise; optional flat cut so it sits on / hangs from a plane"""
        r = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1)
        off = Vector((seed * 7.3, seed * 3.1, seed * 5.7))
        for v in r["verts"]:
            n = noise.noise(v.co * 1.6 + off) * .6 + noise.noise(v.co * 3.4 + off) * .3
            p = v.co * (1 + rough * n)
            p = Euler(rot).to_matrix() @ Vector((p.x * scale[0], p.y * scale[1], p.z * scale[2])) + Vector(center)
            if flat_bottom is not None:
                p.z = max(p.z, flat_bottom) if flat_bottom <= center[2] else min(p.z, flat_bottom)
            v.co = p
        self._tag({f for v in r["verts"] for f in v.link_faces}, key)

    def crystal(self, base, direction, length, radius, key, tip=0.3, sides=6, twist=0.0):
        d = Vector(direction).normalized()
        q = Vector((0, 0, 1)).rotation_difference(d).to_matrix()
        r0, r1 = [], []
        for i in range(sides):
            a = twist + 2 * math.pi * i / sides
            x, y = math.cos(a) * radius, math.sin(a) * radius
            r0.append(self.bm.verts.new(q @ Vector((x, y, 0)) + Vector(base)))
            r1.append(self.bm.verts.new(q @ Vector((x * .95, y * .95, length * (1 - tip))) + Vector(base)))
        top = self.bm.verts.new(q @ Vector((0, 0, length)) + Vector(base))
        fs = [self.bm.faces.new(list(reversed(r0)))]
        for i in range(sides):
            j = (i + 1) % sides
            fs.append(self.bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
            fs.append(self.bm.faces.new((r1[i], r1[j], top)))
        self._tag(fs, key)

    def gem(self, center, size, key):
        """flat hexagonal gem plate facing +Y (a handhold), size = (width, thickness)"""
        w, t = size
        c = Vector(center)
        ring = [self.bm.verts.new(c + Vector((math.cos(a) * w / 2, 0, math.sin(a) * w / 2)))
                for a in [i * math.pi / 3 for i in range(6)]]
        front = self.bm.verts.new(c + Vector((0, t, 0)))
        fs = [self.bm.faces.new(ring)]
        for i in range(6):
            fs.append(self.bm.faces.new((ring[(i + 1) % 6], ring[i], front)))
        self._tag(fs, key)

    def finish(self, name, origin=(0, 0, 0)):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.001)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        for v in self.bm.verts:
            v.co -= Vector(origin)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for k in self.keys:
            me.materials.append(MATS[k])
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        KIT.objects.link(ob)
        return ob


def spray(m, rng, base, normal, n, lmin, lmax, rmin, rmax, keys=("quartz", "quartz", "lilac"), spread=.45):
    """a fan of crystals growing out of `base` around `normal`"""
    nrm = Vector(normal).normalized()
    for i in range(n):
        d = nrm + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * spread
        m.crystal(Vector(base) + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-.5, .5))) * rmax,
                  d, rng.uniform(lmin, lmax), rng.uniform(rmin, rmax), keys[i % len(keys)], twist=rng.uniform(0, 1))


# ---------------------------------------------------------------- cave wall formations (line the sides, hide boxes)
def cave_rock(name, seed, width, height, depth, crystals):
    """a wall-sized cliff of overlapping angular strata (flat back = +Y into the cave wall, front = -Y to the route)"""
    rng = random.Random(seed)
    m = Mesh()
    rows = 5
    for r in range(rows):
        z = height * (r + .5) / rows
        inset = rng.uniform(0, depth * .18)                    # ledges step in and out row to row
        cols = 2 if r % 2 else 3
        for c in range(cols):
            x = width * ((c + .5) / cols - .5) + rng.uniform(-4, 4)
            sc = (width / 2.6 * rng.uniform(.75, .95), depth * rng.uniform(.42, .52), height / rows * rng.uniform(.55, .75))
            m.rock((x, inset, z), sc, seed * 10 + r * 3 + c, subdiv=1, rough=.38,
                   rot=(rng.uniform(-.12, .12), rng.uniform(-.25, .25), rng.uniform(-.15, .15)))
    for i in range(crystals):                                  # crystals growing out of the seams between strata
        x, z = rng.uniform(-width * .4, width * .4), height * (rng.randint(1, rows - 1) / rows)
        spray(m, rng, (x, -depth * .38, z), (0, -1, rng.uniform(-.1, .6)), rng.randint(3, 5), 4, 9, .7, 1.5)
    return m.finish(name)


def ceiling_rock(name, seed, width, depth, drop):
    """hanging ceiling mass: flat top at z=0, lumps + stalactites below; origin = top centre"""
    rng = random.Random(seed)
    m = Mesh()
    for i in range(6):
        x, y = rng.uniform(-width * .35, width * .35), rng.uniform(-depth * .35, depth * .35)
        m.rock((x, y, -drop * .3), (width * rng.uniform(.22, .32), depth * rng.uniform(.22, .32), drop * rng.uniform(.35, .5)),
               seed * 10 + i, rough=.3, flat_bottom=0.0)
    for i in range(7):
        x, y = rng.uniform(-width * .38, width * .38), rng.uniform(-depth * .38, depth * .38)
        m.crystal((x, y, -drop * .45), (rng.uniform(-.1, .1), rng.uniform(-.1, .1), -1), rng.uniform(drop * .5, drop * 1.1),
                  rng.uniform(1.4, 2.6), "rock", tip=.6, sides=5, twist=rng.uniform(0, 1))
    for i in range(3):
        x, y = rng.uniform(-width * .3, width * .3), rng.uniform(-depth * .3, depth * .3)
        spray(m, rng, (x, y, -drop * .55), (0, 0, -1), 3, 2.5, 5, .5, 1.0, spread=.35)
    return m.finish(name)


def stalactites(name, seed):
    rng = random.Random(seed)
    m = Mesh()
    m.rock((0, 0, -2), (6, 6, 3), seed, rough=.3, flat_bottom=0.0)
    for i in range(5):
        a = i * 2 * math.pi / 5 + rng.uniform(-.3, .3)
        r = rng.uniform(1.5, 4)
        m.crystal((math.cos(a) * r, math.sin(a) * r, -2.5), (rng.uniform(-.1, .1), rng.uniform(-.1, .1), -1),
                  rng.uniform(8, 18), rng.uniform(1.0, 1.8), "rock", tip=.7, sides=5, twist=a)
    spray(m, rng, (0, 0, -3.5), (0, 0, -1), 2, 3, 5, .5, .9, spread=.3)
    return m.finish(name)


def rock_pillar(name, seed, height):
    """floor-to-ceiling column: stalagmite + stalactite meeting in a pinched waist, crystals at the foot"""
    rng = random.Random(seed)
    m = Mesh()
    n = 7
    for i in range(n):
        t = (i + .5) / n
        w = 5.5 + 4 * abs(t - .5) * 2 + rng.uniform(-.8, .8)
        m.rock((rng.uniform(-.8, .8), rng.uniform(-.8, .8), height * t), (w, w * rng.uniform(.8, 1), height / n * .75),
               seed * 10 + i, rough=.25, subdiv=1)
    spray(m, rng, (0, -4, 1.5), (0, -1, .6), 4, 3, 7, .6, 1.2)
    spray(m, rng, (3, 3, 1.5), (1, 1, .6), 3, 3, 6, .5, 1.0)
    return m.finish(name)


# ---------------------------------------------------------------- crystal formations
def crystal_spire(name, seed, height):
    """the hero formation: one big crystal + a skirt of smaller ones on a rock base (nest crown, depth markers)"""
    rng = random.Random(seed)
    m = Mesh()
    m.rock((0, 0, .6), (5.5, 4.8, 2.2), seed, rough=.3, subdiv=1, flat_bottom=0.0)
    m.crystal((0, 0, .5), (rng.uniform(-.12, .12), rng.uniform(-.12, .12), 1), height, height * .11, "quartz", tip=.25)
    for i in range(6):
        a = i * 2 * math.pi / 6 + rng.uniform(-.3, .3)
        m.crystal((math.cos(a) * 2.6, math.sin(a) * 2.2, .5), (math.cos(a) * .55, math.sin(a) * .55, 1),
                  height * rng.uniform(.3, .55), height * rng.uniform(.05, .08), ("quartz", "lilac")[i % 2], twist=a)
    return m.finish(name)


def wall_growth(name, seed):
    """crystals growing sideways out of a rock face; origin on the face, crystals point -Y (into the cave)"""
    rng = random.Random(seed)
    m = Mesh()
    m.rock((0, 1, 0), (4.5, 2.2, 3.5), seed, rough=.3, subdiv=1)
    spray(m, rng, (0, -.5, 0), (0, -1, .35), 6, 4, 9, .7, 1.5, spread=.5)
    return m.finish(name)


def shard_debris(name, seed):
    rng = random.Random(seed)
    m = Mesh()
    for i in range(4):
        m.rock((rng.uniform(-4, 4), rng.uniform(-4, 4), .2), (rng.uniform(1, 2), rng.uniform(1, 2), .5), seed * 10 + i,
               rough=.3, subdiv=1, flat_bottom=0.0)
    for i in range(9):
        m.crystal((rng.uniform(-4.5, 4.5), rng.uniform(-4.5, 4.5), 0), (rng.uniform(-.8, .8), rng.uniform(-.8, .8), 1),
                  rng.uniform(.8, 2.4), rng.uniform(.2, .45), ("quartz", "lilac")[i % 2], twist=rng.uniform(0, 1))
    return m.finish(name)


def floor_mound(name, seed, w, d, h):
    """low irregular floor swell (Studio: non-colliding, <= 2 studs), sits on z=0"""
    m = Mesh()
    m.rock((0, 0, 0), (w / 2, d / 2, h), seed, rough=.18, flat_bottom=0.0)
    return m.finish(name)


# ---------------------------------------------------------------- climb-wall readability
def handhold(name):
    """flush glowing gem plate on a climb wall face (Studio: Neon, CanCollide/CanQuery/CanTouch off)"""
    m = Mesh()
    m.gem((0, 0, 0), (2.4, -.35), "glow")
    return m.finish(name)


def wall_crest(name, seed):
    """irregular glowing clumps along a climb wall's top edges, with gaps (decor; riders cross the flat top between)"""
    rng = random.Random(seed)
    m = Mesh()
    for side in (-1, 1):
        x = -29.0 + rng.uniform(0, 4)
        while x < 27:
            for k in range(rng.randint(2, 5)):
                m.crystal((x + rng.uniform(-1.2, 1.2), side * rng.uniform(3.9, 4.6), 0),
                          (rng.uniform(-.5, .5), side * rng.uniform(.2, .6), 1), rng.uniform(1.2, 4.5) * (1.4 if k == 0 else 1),
                          rng.uniform(.35, .8), "glow", twist=rng.uniform(0, 1))
            x += rng.uniform(5, 10)
    return m.finish(name)


def glow_cluster(name, seed, n, lmax):
    """crystals only, no rock base: the one piece that is Neon in Studio (wall seams, nest ring, gap markers)"""
    rng = random.Random(seed)
    m = Mesh()
    spray(m, rng, (0, 0, 0), (0, 0, 1), n, lmax * .4, lmax, .35, .8, keys=("glow",), spread=.55)
    return m.finish(name)


cave_rock("CaveRockA", 11, 54, 62, 26, 4)
cave_rock("CaveRockB", 12, 48, 50, 24, 3)
cave_rock("CaveRockC", 13, 60, 70, 28, 5)
ceiling_rock("CeilingRockA", 21, 70, 60, 16)
ceiling_rock("CeilingRockB", 22, 56, 70, 13)
stalactites("Stalactites", 31)
rock_pillar("RockPillar", 41, 78)
crystal_spire("CrystalSpire", 51, 30)
crystal_spire("CrystalSpireTall", 52, 44)
wall_growth("WallGrowth", 61)
shard_debris("ShardDebris", 71)
floor_mound("FloorMound", 81, 26, 18, 1.6)
handhold("Handhold")
wall_crest("WallCrest", 91)
glow_cluster("GlowCluster", 101, 5, 5)
glow_cluster("GlowClusterBig", 102, 7, 9)


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


for ob in KIT.objects:
    lo = Vector([min(v.co[i] for v in ob.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in ob.data.vertices) for i in range(3)])
    print("KIT", ob.name, tris(ob), "tris", tuple(round(x, 1) for x in (hi - lo)))
import json, os
json.dump({ob.name: {"min": [round(min(v.co[i] for v in ob.data.vertices), 2) for i in range(3)],
                     "max": [round(max(v.co[i] for v in ob.data.vertices), 2) for i in range(3)]} for ob in KIT.objects},
          open(os.path.join(os.path.dirname(OUT), "kit_bounds.json"), "w"), indent=1)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
