"""Pre-rig the three pets in Blender: Roblox's CSG cut (CreatureRig) rejects their meshes as non-manifold (they are
overlapping closed shapes), so split each baked pet here into Body + one part per leg and record the hinges.
A loose piece whose centre sits below the pet's leg-cut height is a leg; legs are grouped by side (x) and
front/hind (y). Writes <Pet>.fbx (Body + legs, same baked texture) and pet_rigs.json (Roblox mesh space, relative to
the pet's ground-centre origin: part centres to recover the origin in Studio, hinges, Side = sign of Roblox x,
Front = -1 front legs / 1 hind legs, matching CreatureRig's own cut).
Headless:  blender -b crystal-caverns-baked.blend -P split_pets.py -- <out dir>"""
import bpy, bmesh, json, os, sys
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
CUTS = {"CrystalBeetle": .226, "GemGecko": .379, "CrystalPangolin": .238}  # = CreatureRig legCuts
rigs = {}


def roblox(v):  # FBX export: Blender (x, y, z) -> Roblox mesh (-x, z, y)
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


for name, frac in CUTS.items():
    ob = bpy.data.objects[name]
    origin = ob.location.copy()
    for m in ob.modifiers:  # bake the bevel in so pieces keep their exported shape
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=m.name)
    me = ob.data
    zs = [v.co.z for v in me.vertices]
    cut = min(zs) + (max(zs) - min(zs)) * frac
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    # loose pieces
    seen, islands = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, isl = [v], []
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            isl.append(cur.index)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        islands.append(isl)
    groups = {}
    for isl in islands:
        c = sum((bm.verts[i].co for i in isl), Vector()) / len(isl)
        if c.z < cut:
            key = ("R" if c.x < 0 else "L", "F" if c.y < 0 else "H")  # Blender -x = Roblox +x
            groups.setdefault(key, []).extend(isl)
    leg_verts = {i for g in groups.values() for i in g}
    bm.free()
    parts = {"Body": [i for i in range(len(me.vertices)) if i not in leg_verts]}
    for (side, front), verts in groups.items():
        parts[f"{side}{front}Leg"] = verts
    info = {"cut": round(cut, 4), "parts": {}}
    made = []
    for pname, verts in parts.items():
        keep = set(verts)
        new = ob.copy()
        new.data = me.copy()
        new.name = pname if pname != "Body" else name + "_Body"
        bpy.context.scene.collection.objects.link(new)
        nbm = bmesh.new()
        nbm.from_mesh(new.data)
        nbm.verts.ensure_lookup_table()
        bmesh.ops.delete(nbm, geom=[v for v in nbm.verts if v.index not in keep], context="VERTS")
        nbm.to_mesh(new.data)
        nbm.free()
        co = [v.co for v in new.data.vertices]
        lo = Vector([min(c[i] for c in co) for i in range(3)])
        hi = Vector([max(c[i] for c in co) for i in range(3)])
        entry = {"center": roblox((lo + hi) / 2)}
        if pname != "Body":
            hinge = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, cut))
            rx = -hinge.x
            entry.update(hinge=roblox(hinge), side=1 if rx > 0 else -1, front=-1 if hinge.y < 0 else 1)
        info["parts"][new.name if pname == "Body" else pname] = entry
        made.append(new)
    rigs[name] = info
    bpy.ops.object.select_all(action="DESELECT")
    for o in made:
        o.location = o.location - origin  # export around the pet's own ground centre
        o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), use_selection=True, object_types={"MESH"},
                             axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             use_mesh_modifiers=True, mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True,
                             bake_space_transform=False)
    print("SPLIT", name, "cut", round(cut, 3), sorted(info["parts"]))
json.dump(rigs, open(os.path.join(OUT, "pet_rigs.json"), "w"), indent=1)
