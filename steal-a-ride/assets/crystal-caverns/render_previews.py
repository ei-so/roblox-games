"""Preview renders of crystal-caverns.blend (headless).
blender -b crystal-caverns.blend -P render_previews.py -- <previews dir>"""
import bpy, math, sys
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.use_raytracing = True
scene.render.resolution_x, scene.render.resolution_y = 1400, 1000
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"

world = bpy.data.worlds.new("Cave")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.05, 0.06, 0.1, 1)
bg.inputs[1].default_value = 1.0
scene.world = world

floor_mat = bpy.data.materials.new("PreviewFloor")
floor_mat.use_nodes = True
next(n for n in floor_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.09, 0.09, 0.12, 1)
bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
bpy.context.object.data.materials.append(floor_mat)


def light(loc, energy, size, color=(1, 1, 1)):
    d = bpy.data.lights.new("PreviewLight", "AREA")
    d.energy, d.size, d.color = energy, size, color
    o = bpy.data.objects.new("PreviewLight", d)
    o.location = loc
    scene.collection.objects.link(o)
    return o

sun = bpy.data.lights.new("Sun", "SUN")
sun.energy, sun.angle = 3.0, math.radians(8)
so = bpy.data.objects.new("Sun", sun)
so.rotation_euler = (math.radians(50), 0, math.radians(-35))
scene.collection.objects.link(so)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam


def frame(objs, name, direction=(-0.75, -1.0, 0.45), lens=50, pad=1.15):
    lo = Vector((1e9, 1e9, 1e9)); hi = -lo
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    center, radius = (lo + hi) / 2, (hi - lo).length / 2
    cam.data.lens = lens
    fov = 2 * math.atan(18 / lens)
    dist = radius * pad / math.sin(fov / 2) * 0.82
    d = Vector(direction).normalized()
    cam.location = center - d * -dist if False else center + Vector((d.x, d.y, d.z)) * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    for L in [o for o in scene.objects if o.name.startswith("PreviewLight")]:
        bpy.data.objects.remove(L)
    light(center + Vector((-radius * 1.5, -radius * 2, radius * 2)), 4000 * (radius / 10) ** 2, radius * 2)
    light(center + Vector((radius * 2, -radius, radius)), 1500 * (radius / 10) ** 2, radius * 2, (0.8, 0.9, 1))
    light(center + Vector((0, radius * 2, radius * 1.5)), 2500 * (radius / 10) ** 2, radius * 2, (0.9, 0.85, 1))
    for o in scene.objects:
        if o.type == "MESH" and o.name != "Plane":
            o.hide_render = o not in objs
    scene.render.filepath = f"{OUT}/{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)


col = bpy.data.collections
frame(list(col["Golem"].objects), "golem")
frame(list(col["Golem"].objects), "golem_side", direction=(1, -0.35, 0.3))
frame(list(col["Pets"].objects), "pets", direction=(-0.6, -1, 0.5))
for o in col["Pets"].objects:
    frame([o], "pet_" + o.name, direction=(-0.9, -1, 0.55))
frame([o for o in col["Props"].objects if o.name.startswith("QuartzWall")], "walls", direction=(-0.5, -1, 0.35))
frame([o for o in col["Props"].objects if not o.name.startswith("QuartzWall")], "props", direction=(-0.3, -1, 0.6))
