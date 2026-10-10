"""Export crystal-caverns.blend to FBX for Roblox's 3D Importer (headless).
Every mesh except the Golem's Neon Core gets ONE material: a flat-colour palette texture (palette.png); each face's UVs
collapse onto its colour swatch. Y-up, -Z forward, 1 Blender unit = 1 stud (fix the scale in Studio if the importer
reads metres). Files: Golem.fbx (Body, LeftLeg, RightLeg, LeftArm, RightArm, Core), CrystalBeetle.fbx, GemGecko.fbx,
CrystalPangolin.fbx, Props.fbx.
blender -b crystal-caverns.blend -P export_models.py -- <out dir>"""
import bpy, os, sys

OUT = sys.argv[sys.argv.index("--") + 1]
CELL, GRID = 16, 4  # 4 x 4 swatches of 16 px = a 64 x 64 palette

colours = []
for m in bpy.data.materials:
    if "rgb" in m and m.name != "GemCyan" or m.name == "GemCyan":
        if "rgb" in m:
            colours.append(m.name)
assert len(colours) <= GRID * GRID, colours

img = bpy.data.images.new("CC_Palette", CELL * GRID, CELL * GRID)
px = [0.0] * (CELL * GRID * CELL * GRID * 4)
for idx, name in enumerate(colours):
    r, g, b = (c / 255 for c in bpy.data.materials[name]["rgb"])
    cx, cy = idx % GRID, idx // GRID
    for y in range(cy * CELL, (cy + 1) * CELL):
        for x in range(cx * CELL, (cx + 1) * CELL):
            i = (y * CELL * GRID + x) * 4
            px[i:i + 4] = [r, g, b, 1.0]
img.pixels = px
img.filepath_raw = os.path.join(OUT, "palette.png")
img.file_format = "PNG"
img.save()

pal = bpy.data.materials.new("CC_Palette")
pal.use_nodes = True
nodes = pal.node_tree.nodes
tex = nodes.new("ShaderNodeTexImage")
tex.image = img
tex.interpolation = "Closest"
bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
pal.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def swatch_uv(name):
    idx = colours.index(name)
    return ((idx % GRID + .5) / GRID, (idx // GRID + .5) / GRID)


for ob in [o for o in bpy.data.objects if o.type == "MESH"]:
    if ob.name == "Core":
        continue
    me = ob.data
    uv = me.uv_layers.new(name="Palette") if not me.uv_layers else me.uv_layers[0]
    for poly in me.polygons:
        u = swatch_uv(me.materials[poly.material_index].name)
        for li in poly.loop_indices:
            uv.data[li].uv = u
    me.materials.clear()
    me.materials.append(pal)


def export(path, objs, zero=False):
    saved = {o: o.location.copy() for o in objs}
    if zero:
        for o in objs:
            o.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, path), use_selection=True, object_types={"MESH"},
                             axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             use_mesh_modifiers=True, mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True,
                             bake_space_transform=False)
    for o, loc in saved.items():
        o.location = loc
    print("EXPORTED", path, [o.name for o in objs])


cols = bpy.data.collections
export("Golem.fbx", list(cols["Golem"].objects))
for o in cols["Pets"].objects:
    export(o.name + ".fbx", [o], zero=True)
export("Props.fbx", list(cols["Props"].objects), zero=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "crystal-caverns-export.blend"), copy=True)
