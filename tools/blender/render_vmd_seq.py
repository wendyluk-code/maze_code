# -*- coding: utf-8 -*-
"""MMD(PMX+VMD) 动画帧序列渲染: 输出 PNG 序列, 后续用 ffmpeg 合成 MP4"""
import bpy, sys, os, math
from mathutils import Vector

EXT_MOD = "bl_ext.user_default.mmd_tools"
PMX     = r"C:\Users\KSG\Downloads\taxi-PMX\塔西-PMX\塔西.pmx"
VMD     = r"F:\maze_code\tools\mmd_tools_src\samples\vmd\test.vmd"
OUT_DIR = r"F:\maze_code\tools\preview\mmd\frames"
os.makedirs(OUT_DIR, exist_ok=True)

# ---------- 1. 启用 mmd_tools ----------
try:
    bpy.ops.preferences.addon_enable(module=EXT_MOD)
    print("ADDON_OK")
except Exception as e:
    print("ADDON_FAIL", e); sys.exit(1)

# ---------- 2. 清空场景 ----------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.actions):
    for b in list(blk): blk.remove(b)

# ---------- 3. 导入 PMX ----------
bpy.ops.mmd_tools.import_model(filepath=PMX, scale=0.08,
                               types={'MESH', 'ARMATURE', 'MORPHS'})
new_o = list(bpy.context.scene.objects)
arm = next((o for o in new_o if o.type == 'ARMATURE'), None)
if not arm:
    print("NO_ARMATURE"); sys.exit(1)
print("PMX_OK objects:", len(new_o))

# ---------- 4. 导入 VMD 动作 ----------
# mmd 根对象(EMPTY, mmd_type=ROOT)导入骨骼+表情动画; 找不到就用骨架(仅骨骼动画)
root = next((o for o in new_o if o.get('mmd_type') == 'ROOT'), None) or arm
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root

bpy.ops.mmd_tools.import_vmd(filepath=VMD, scale=0.08, bone_mapper='PMX',
                             update_scene_settings=True, create_new_action=True)
print("VMD_IMPORT_OK")

act = arm.animation_data.action if arm.animation_data else None
if act:
    fr = act.frame_range
    f0, f1 = int(fr[0]), int(fr[1])
else:
    f0, f1 = 1, 25
print("FRAMES", f0, f1)

sc = bpy.context.scene
sc.frame_start, sc.frame_end = f0, f1
sc.render.fps = 30

# ---------- 5. 包围盒 / 相机 / 灯光 ----------
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

meshes = [o for o in new_o if o.type == 'MESH']
lo, hi = world_bbox(meshes)
ctr = (lo + hi) / 2
hgt = hi.z - lo.z
rad = max(hi.x - lo.x, hi.y - lo.y, hgt) * 0.62
print("BBOX h=", round(hgt, 3), "w=", round(hi.x - lo.x, 3))

cd = bpy.data.cameras.new("AnimCam"); cd.lens = 70; cd.clip_end = 60
co = bpy.data.objects.new("AnimCam", cd)
sc.collection.objects.link(co)
d = rad * 2.0
a = math.radians(18)  # 正面稍偏右
co.location = (ctr.x + d*math.sin(a), ctr.y - d*math.cos(a), ctr.z + hgt*0.05)
dirv = Vector((ctr.x, ctr.y, ctr.z + hgt*0.02)) - co.location
co.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()
sc.camera = co

def mk_lt(nm, loc, en, sz, col=(1, 1, 1)):
    ld = bpy.data.lights.new(nm, 'AREA'); ld.energy = en; ld.size = sz; ld.color = col
    ob = bpy.data.objects.new(nm, ld)
    sc.collection.objects.link(ob); ob.location = loc

mk_lt("Key",  (ctr.x + 1.5, ctr.y - 2.4, ctr.z + hgt*0.8), 300, 2.4, (1, .97, .92))
mk_lt("Fill", (ctr.x - 2.4, ctr.y - 1.4, ctr.z + hgt*0.4), 130, 3.0, (.92, .95, 1))
mk_lt("Rim",  (ctr.x + 0.3, ctr.y + 2.6, ctr.z + hgt*0.95), 220, 2.2)

w = bpy.data.worlds["World"] if "World" in bpy.data.worlds else bpy.data.worlds.new("World")
w.use_nodes = True
for n in w.node_tree.nodes:
    if n.type == "BACKGROUND":
        n.inputs["Color"].default_value = (0.85, 0.88, 0.92, 1)
        n.inputs["Strength"].default_value = 0.55

bpy.ops.mesh.primitive_circle_add(vertices=48, radius=rad*1.25, fill_type='NGON',
                                  location=(ctr.x, ctr.y, lo.z - 0.002))
g = bpy.context.object; g.name = "Ground"
gm = bpy.data.materials.new("Ground_m"); gm.use_nodes = True
for n in gm.node_tree.nodes:
    if n.type == "BSDF_PRINCIPLED":
        n.inputs["Base Color"].default_value = (0.55, 0.55, 0.58, 1)
        n.inputs["Roughness"].default_value = 1.0
        try: n.inputs["Specular IOR Level"].default_value = 0.1
        except Exception:
            try: n.inputs["Specular"].default_value = 0.1
            except Exception: pass
g.data.materials.append(gm)

# ---------- 6. 渲染帧序列 ----------
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 32
sc.render.resolution_x = 1280; sc.render.resolution_y = 1280
sc.render.image_settings.file_format = "PNG"
sc.render.filepath = os.path.join(OUT_DIR, "frame_####.png")

for f in range(f0, f1 + 1):
    sc.frame_set(f)
    sc.render.filepath = os.path.join(OUT_DIR, f"frame_{f:04d}.png")
    bpy.ops.render.render(write_still=True)
    print("FRAME_DONE", f)

print("SEQ_DONE", f0, f1)
print("OUTPUT=" + OUT_DIR)
