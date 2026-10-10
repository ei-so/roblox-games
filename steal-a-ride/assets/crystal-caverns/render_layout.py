"""Preview of the polished Crystal Caverns from layout.json with the baked textures (what Studio will get).
Neon pieces are approximated with emission. Headless:
  blender -b crystal-caverns-baked.blend -P render_layout.py -- <layout.json> <out dir> [prefix]"""
import bpy, json, math, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
L = json.load(open(args[0]))
OUT, PREFIX = args[1], (args[2] if len(args) > 2 else "polish")
W, D, H = L["W"], L["D"], L["H"]
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
for attr, val in (("use_raytracing", True), ("use_volumetric_shadows", True), ("volumetric_tile_size", "4"),
                  ("taa_render_samples", 48)):
    try:
        setattr(scene.eevee, attr, val)
    except Exception as e:
        print("eevee", attr, e)
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
try:
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
except TypeError as e:
    print("view", e)

GLOW = {"cyan": (120, 240, 255), "amber": (255, 176, 70), "violet": (175, 120, 255), "blue": (90, 150, 255)}


def lin(rgb):
    return tuple((c / 255) ** 2.2 for c in rgb) + (1,)


def flat(name, rgb, rough=.85, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(rgb)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = lin(rgb)
        b.inputs["Emission Strength"].default_value = emit
    return m


NEON = {k: flat("Neon_" + k, v, .4, emit=5) for k, v in GLOW.items()}
for m in bpy.data.materials:                       # baked textures read as SmoothPlastic-ish
    if m.name.startswith("Tex_"):
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Roughness"].default_value = .55
src = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
for o in src.values():
    o.hide_render = True


def place(name, x, y, z, rot=0.0, s=1.0, sx=None, glow=None):
    o = src[name].copy()
    scene.collection.objects.link(o)
    o.hide_render = False
    o.location = (x, y, z)
    o.rotation_euler = (0, 0, math.radians(rot))
    o.scale = ((sx or 1) * s, s, s)
    if glow:
        o.data = o.data.copy()
        o.data.materials.clear()
        o.data.materials.append(NEON[glow])
    return o


def box(name, loc, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name, o.scale = name, size
    o.data.materials.append(mat)
    return o


# shell: floor, backing walls, ceiling slab with crack holes (Studio: plain Slate parts behind the formations)
FLOOR = flat("Floor", (84, 94, 120))
_fn = FLOOR.node_tree
_b = next(n for n in _fn.nodes if n.type == "BSDF_PRINCIPLED")
_noise = _fn.nodes.new("ShaderNodeTexNoise")
_noise.inputs["Scale"].default_value = .35
_ramp = _fn.nodes.new("ShaderNodeValToRGB")
_ramp.color_ramp.elements[0].color = lin((60, 68, 90))
_ramp.color_ramp.elements[1].color = lin((100, 110, 138))
_fn.links.new(_noise.outputs["Fac"], _ramp.inputs["Fac"])
_fn.links.new(_ramp.outputs["Color"], _b.inputs["Base Color"])
BACK = flat("Back", (34, 38, 52))
box("Floor", (0, D / 2, -.5), (W + 80, D + 80, 1), FLOOR)
for side in (-1, 1):
    box("Back", (side * (W / 2 + 40), D / 2, H / 2), (10, D + 80, H + 20), BACK)
box("Back", (0, D + 40, H / 2), (W + 80, 10, H + 20), BACK)
cracks = sorted(it["y"] for it in L["items"] if it["asset"] == "CeilingCrack")
y0 = -40
for c in cracks + [D + 40]:
    half = 13 if c < D else 0
    if c - half > y0:
        box("Ceiling", (0, (y0 + c - half) / 2, H + 18), (W + 80, c - half - y0, 8), BACK)
    y0 = c + half

walls = []
for it in L["items"]:
    k, a = it["kind"], it["asset"]
    if k == "light":
        d = bpy.data.lights.new("L", "POINT")
        d.energy = it["brightness"] * it["range"] ** 2 * 6
        d.color = [c / 255 for c in GLOW[it["color"]]]
        d.shadow_soft_size = 2
        d.use_shadow = False                      # Studio: Shadows = false
        o = bpy.data.objects.new("L", d)
        o.location = (it["x"], it["y"], it["z"])
        scene.collection.objects.link(o)
        continue
    if k in ("shaft", "marker"):
        continue
    o = place(a, it["x"], it["y"], it["z"], it["rot"], it["scale"], it.get("sx"), it.get("color") if k == "glow" else None)
    if k == "wall":
        walls.append(o)

# nest, eggs, guardian + pets (as GuardianService / the build will place them)
NY = L["NEST_Y"]
bpy.ops.mesh.primitive_torus_add(major_radius=9, minor_radius=2.2, location=(0, NY, 1))
bpy.context.object.data.materials.append(flat("Nest", (70, 80, 110)))
EGG = flat("Egg", (226, 236, 255), .3)
for k in range(5):
    a = k / 5 * 2 * math.pi
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.6, location=(math.cos(a) * 4, NY + math.sin(a) * 4, 2.2))
    e = bpy.context.object
    e.scale = (1, 1, 1.35)
    e.data.materials.append(EGG)
core = flat("Core", (90, 235, 255), .3, emit=6)
for n in ("Body", "Core", "LeftLeg", "LeftArm", "RightLeg", "RightArm"):
    o = place(n, src[n].location.x + 32, src[n].location.y + NY, src[n].location.z)
    if n == "Core":
        o.data = o.data.copy()
        o.data.materials.clear()
        o.data.materials.append(core)
place("CrystalBeetle", -22, NY - 40, 0, 40, 1.3)
place("GemGecko", 70, L["WALL_YS"][2] + 14, 0, 160, 1.3)
place("CrystalPangolin", -40, NY - 75, 0, -20, 1.3)

# light: dim cool ambient, sun only through the cracks, soft haze
world = bpy.data.worlds.new("Sky")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (.32, .4, .62, 1)
bg.inputs[1].default_value = .7
scene.world = world
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy, sun.angle, sun.color = 9, math.radians(2), (1, .96, .9)
so = bpy.data.objects.new("Sun", sun)
so.rotation_euler = (math.radians(14), math.radians(-8), 0)
scene.collection.objects.link(so)
for y in range(40, D, 110):                          # Studio equivalent: Lighting ambient (no extra lights)
    a = bpy.data.lights.new("Ambient", "AREA")
    a.energy, a.size, a.color, a.use_shadow = 15000, 140, (.72, .82, 1), False
    ao = bpy.data.objects.new("Ambient", a)
    ao.location = (0, y, H - 4)
    scene.collection.objects.link(ao)
hz = box("Haze", (0, D / 2, H / 2), (W, D, H), bpy.data.materials.new("Haze"))
nt = hz.data.materials[0].node_tree if hz.data.materials[0].use_nodes else None
hm = hz.data.materials[0]
hm.use_nodes = True
nt = hm.node_tree
nt.nodes.remove(next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"))
vs = nt.nodes.new("ShaderNodeVolumeScatter")
vs.inputs["Density"].default_value = .0016
vs.inputs["Color"].default_value = (.8, .88, 1, 1)
nt.links.new(vs.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Volume"])

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam


def shot(name, loc, target, lens, hide=()):
    hidden = [o for o in scene.objects if o.name.split(".")[0] in hide]
    for o in hidden:
        o.hide_render = True
    cam.location, cam.data.lens, cam.data.clip_end = Vector(loc), lens, 3000
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = f"{OUT}/{PREFIX}_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)
    for o in hidden:
        o.hide_render = False


WY = L["WALL_YS"]
shot("nest", (-30, NY - 70, 14), (10, NY + 10, 12), 24)
shot("climbwall", (-55, WY[1] - 38, 9), (10, WY[1], 22), 22)
shot("lane", (-90, WY[0] + 14, 8), (90, WY[0] + 40, 6), 18)
shot("entrance", (0, -30, 16), (0, 120, 10), 22)
shot("overview", (-200, -160, 330), (0, 330, 0), 30,
     hide=("Ceiling", "CeilingRockA", "CeilingRockB", "Stalactites", "CeilingCrack", "Haze", "Ambient"))
