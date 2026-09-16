# -*- coding: utf-8 -*-
"""MMD(PMX+VMD) 导入动作 + 渲染关键姿势(Cycles) + 动画MP4(EEVEE)"""
import bpy, sys, os, math
from mathutils import Vector

EXT_MOD = "bl_ext.user_default.mmd_tools"
PMX     = r"C:\Users\KSG\Downloads\taxi-PMX\塔西-PMX\塔西.pmx"
VMD     = r"F:\maze_code\tools\mmd_tools_src\samples\vmd\test.vmd"
OUT_DIR = r"F:\maze_code\tools\preview\mmd"
os.makedirs(OUT_DIR, exist_ok=True)

# ---------- 1. 启用 mmd_tools ----------
for m in list(bpy.context.preferences.addons.keys()):
    if "mmd_tools" in m:
        break
else:
    bpy.ops.preferences.addon_enable(module=EXT_MOD)
print("ADDON_OK")

# ---------- 2. 清空场景 ----------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.actions):
    for b in list(blk): blk.remove(b)

# ---------- 3. 导入 PMX ----------
before = set(bpy.data.objects)
bpy.ops.mmd_tools.import_model(filepath=PMX, scale=0.08)
new = [o for o in bpy.data.objects if o not in before]
meshes = [o for o in new if o.type == 'MESH']
arms   = [o for o in new if o.type == 'ARMATURE']
emptys = [o for o in new if o.type == 'EMPTY']
print("PMX_OK objects:", len(new))
if not meshes or not arms: sys.exit(1)

# ---------- 4. 导入 VMD（选中 root/骨架） ----------
bpy.ops.object.select_all(action="DESELECT")
for o in new: o.select_set(True)
root = None
# root 优先：骨架的父级（通常是 EMPTY 十字标）
root = arms[0].parent if arms[0].parent else (emptys[0] if emptys else arms[0])
bpy.context.view_layer.objects.active = root
root.select_set(True)
try:
    bpy.ops.mmd_tools.import_vmd(filepath=VMD, scale=0.08,
                                 bone_mapper='PMX', update_scene_settings=True)
    print("VMD_OK")
except Exception as e:
    print("VMD_FAIL", e); sys.exit(1)

arm = arms[0]
act = arm.animation_data.action if arm.animation_data else None
sc = bpy.context.scene
print("ACTION:", act.name if act else None)
fs, fe = sc.frame_start, sc.frame_end
print("FRAMES", fs, fe)

# 过长则截断前 5 秒
if fe - fs > 150:
    fe = fs + 150
    sc.frame_end = fe
    print("TRUNCATED_TO", fe)

# ---------- 5. 灯光/地面/相机 ----------
def world_bbox(objs):
    pts = []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        ev = o.evaluated_get(dg)
        for c in ev.bound_box:
            pts.append(ev.matrix_world @ Vector(c))
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi

lo, hi = world_bbox(meshes)
ctr = (lo + hi) / 2
hgt = hi.z - lo.z
wid = max(hi.x - lo.x, hi.y - lo.y)
rad = max(wid, hgt) * 0.62
print("BBOX h=", round(hgt, 3), "w=", round(wid, 3))

def mk_lt(nm, tp, loc, en, sz):
    ld = bpy.data.lights.new(nm, tp); ld.energy = en
    if tp == 'AREA': ld.size = sz
    ob = bpy.data.objects.new(nm, ld)
    sc.collection.objects.link(ob); ob.location = loc
mk_lt("Key",  'AREA', (ctr.x + 1.2, ctr.y - 2.2, ctr.z + hgt*0.75), 260, 2.2)
mk_lt("Fill", 'AREA', (ctr.x - 2.0, ctr.y - 1.6, ctr.z + hgt*0.45), 120, 2.6)
mk_lt("Rim",  'AREA', (ctr.x + 0.4, ctr.y + 2.4, ctr.z + hgt*0.9), 200, 2.0)

w = bpy.data.worlds["World"] if "World" in bpy.data.worlds else bpy.data.worlds.new("World")
w.use_nodes = True
for n in w.node_tree.nodes:
    if n.type == "BACKGROUND":
        n.inputs["Color"].default_value = (0.85, 0.88, 0.92, 1)
        n.inputs["Strength"].default_value = 0.45

bpy.ops.mesh.primitive_circle_add(vertices=48, radius=rad*1.05, fill_type='NGON',
                                  location=(ctr.x, ctr.y, lo.z - 0.001))
g = bpy.context.object; g.name = "Ground"
gm = bpy.data.materials.new("Ground_m"); gm.use_nodes = True
for n in gm.node_tree.nodes:
    if n.type == "BSDF_PRINCIPLED":
        n.inputs["Base Color"].default_value = (0.55, 0.55, 0.58, 1)
        n.inputs["Roughness"].default_value = 1.0
g.data.materials.append(gm)

cd = bpy.data.cameras.new("Cam"); cd.lens = 60; cd.clip_end = 100
co = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(co)
d = rad * 1.9
co.location = (ctr.x + d*0.25, ctr.y - d*0.97, ctr.z + hgt*0.28)
dirv = Vector((ctr.x, ctr.y, ctr.z + hgt*0.02)) - co.location
co.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()
sc.camera = co

# ---------- 6. 关键姿势 PNG (Cycles) ----------
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 36
sc.render.resolution_x = 900; sc.render.resolution_y = 900
sc.render.image_settings.file_format = "PNG"
pose_frames = [fs, (fs+fe)//2, fe]
outs = []
for i, fr in enumerate(pose_frames):
    sc.frame_set(fr)
    p = os.path.join(OUT_DIR, f"taxi_pose_{i}_{int(fr)}.png")
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    outs.append(p); print("POSE_DONE", p)

# ---------- 7. 动画 MP4 (EEVEE) ----------
sc.render.engine = "BLENDER_EEVEE"
try: sc.eevee.taa_render_samples = 8
except Exception: pass
sc.render.resolution_x = 720; sc.render.resolution_y = 720
sc.render.image_settings.file_format = "FFMPEG"
sc.render.ffmpeg.format = "MPEG4"
sc.render.ffmpeg.codec = "H264"
mp4 = os.path.join(OUT_DIR, "taxi_motion.mp4")
sc.render.filepath = mp4
try:
    bpy.ops.render.render(animation=True)
    print("MP4_DONE", mp4)
    outs.append(mp4)
except Exception as e:
    print("MP4_FAIL", e)

for p in outs:
    print("OUTPUT=" + p)
