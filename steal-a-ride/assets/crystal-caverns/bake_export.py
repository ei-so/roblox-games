"""Polish pass texturing: bake one gradient texture per mesh (Mystic-style blending: smooth deep-base -> frosted-top
ramp per material family + soft AO in the creases), replacing the flat palette, then export FBX for Studio.
Runs on crystal-caverns.blend (creatures + original props) with crystal-caverns-kit.blend appended.
Glow pieces (kit key 'glow', the Golem Core) are left untextured: Studio makes them Neon.
Headless:  blender -b crystal-caverns.blend -P bake_export.py -- <out dir>"""
import bpy, os, sys
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
TEX = os.path.join(OUT, "textures")
os.makedirs(TEX, exist_ok=True)
scene = bpy.context.scene

with bpy.data.libraries.load(os.path.join(OUT, "crystal-caverns-kit.blend")) as (src, dst):
    dst.collections = ["Kit"]
kit = dst.collections[0]
scene.collection.children.link(kit)


def lin(rgb):
    return tuple((c / 255) ** 2.2 for c in rgb) + (1,)


# family -> (bottom, mid, top). Approved v3 direction: one cool hue family, deep base -> frost top.
RAMPS = {
    "MilkyQuartz": ((128, 160, 214), (160, 200, 250), (222, 238, 255)),
    "Quartz": ((56, 96, 200), (80, 175, 255), (206, 246, 255)),
    "LilacQuartz": ((100, 90, 200), (140, 140, 255), (214, 214, 255)),
    "QuartzShade": ((60, 76, 140), (90, 110, 175), (120, 142, 204)),
    "CaveStone": ((52, 58, 80), (70, 78, 104), (92, 100, 128)),
    "Kit_rock": ((44, 50, 70), (66, 74, 100), (98, 106, 134)),
    "Kit_quartz": ((56, 96, 200), (80, 175, 255), (206, 246, 255)),
    "Kit_lilac": ((100, 90, 200), (140, 140, 255), (214, 214, 255)),
    "WallQuartz": ((46, 72, 130), (120, 170, 230), (220, 240, 255)),
}
FLAT = {"Dark", "EyeWhite", "GemCyan", "GemPink", "GemAmber", "GemViolet", "GemMint"}  # small details stay flat


def bake_material(src, ramp):
    """emission-only shader the baker reads: ramp over the object's height x soft AO"""
    m = bpy.data.materials.new("Bake_" + src.name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    if ramp is None:
        rgb = src.get("rgb") or [int(c * 255) for c in src.diffuse_color[:3]]
        em.inputs["Color"].default_value = lin(rgb)
    else:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        cr = nt.nodes.new("ShaderNodeValToRGB")
        cr.color_ramp.interpolation = "EASE"
        cr.color_ramp.elements[0].color = lin(ramp[0])
        cr.color_ramp.elements[1].color = lin(ramp[2])
        cr.color_ramp.elements.new(.5).color = lin(ramp[1])
        ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 1.5
        ao.only_local = True  # kit pieces share the origin; only self-occlusion counts
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
        mix.inputs["Factor"].default_value = .5
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        nt.links.new(sep.outputs["Z"], cr.inputs["Fac"])
        nt.links.new(cr.outputs["Color"], mix.inputs["A"])
        nt.links.new(ao.outputs["AO"], mix.inputs["B"])
        nt.links.new(mix.outputs["Result"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


WALLQ = bpy.data.materials.new("WallQuartz")
for name in ("QuartzWallA", "QuartzWallB", "QuartzWallC"):  # calm climb walls: one gradient per slab
    me = bpy.data.objects[name].data
    me.materials.clear()
    me.materials.append(WALLQ)

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.render.bake.margin = 4

targets = []
for ob in [o for o in bpy.data.objects if o.type == "MESH"]:
    keys = [s.material.name for s in ob.material_slots if s.material]
    if ob.name == "Core" or keys == ["Kit_glow"]:
        continue
    targets.append(ob)

for ob in targets:
    me = ob.data
    size = 512 if ob.name in ("Body", "CrystalBeetle", "GemGecko", "CrystalPangolin") or ob.name.startswith(("CaveRock", "Ceiling", "QuartzWall")) else 256
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    for uv in list(me.uv_layers):
        me.uv_layers.remove(uv)
    me.uv_layers.new(name="UV")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = bpy.data.images.new("CC_" + ob.name, size, size)
    img.generated_color = (0, 0, 0, 1)
    originals = [s.material for s in ob.material_slots]
    for i, src in enumerate(originals):
        base = src.name.split(".")[0]
        bm = bake_material(src, None if base in FLAT or base == "Kit_glow" else RAMPS.get(base, RAMPS["Kit_rock"]))
        tex = bm.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        bm.node_tree.nodes.active = tex
        ob.material_slots[i].material = bm
    bpy.ops.object.bake(type="EMIT")
    img.filepath_raw = os.path.join(TEX, f"{ob.name}.png")
    img.file_format = "PNG"
    img.save()
    final = bpy.data.materials.new("Tex_" + ob.name)
    final.use_nodes = True
    t = final.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = img
    bsdf = next(n for n in final.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    final.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    me.materials.clear()
    me.materials.append(final)
    print("BAKED", ob.name, size)


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
    print("EXPORTED", path, len(objs))


cols = bpy.data.collections
export("Golem.fbx", list(cols["Golem"].objects))
for o in cols["Pets"].objects:
    export(o.name + ".fbx", [o], zero=True)
export("Props.fbx", list(cols["Props"].objects), zero=True)
export("Kit.fbx", list(kit.objects), zero=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "crystal-caverns-baked.blend"), copy=True)
