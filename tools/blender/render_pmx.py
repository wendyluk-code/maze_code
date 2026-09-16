# -*- coding: utf-8 -*-
"""MMD(PMX) 导入 + 三视角渲染 (mmd_tools)"""
import bpy, sys, os, math
from mathutils import Vector

EXT_MOD   = "bl_ext.user_default.mmd_tools"
PMX       = r"C:\Users\KSG\Downloads\taxi-PMX\塔西-PMX\塔西.pmx"
OUT_DIR   = r"F:\maze_code\tools\preview\mmd"
os.makedirs(OUT_DIR, exist_ok=True)

# ---------- 1. 启用 mmd_tools ----------
for m in list(bpy.context.preferences.addons.keys()):
    if "mmd_tools" in m:
        print("ALREADY_ENABLED", m); break
else:
    try:
        bpy.ops.preferences.addon_enable(module=EXT_MOD)
        print("ENABLE_OK", EXT_MOD)
    except Exception as e:
        print("ENABLE_FAIL", e); sys.exit(1)

try:
    import opencc
    print("OPENCC_OK", opencc.__file__)
except Exception as e:
    print("OPENCC_FAIL", e)

# 校验 operator 是否注册 (mmd_tools v4: mmd_tools.import_model)
try:
    bpy.ops.mmd_tools.import_model.get_rna_type()
    print("PMX_OP_OK")
except Exception as e:
    print("PMX_OP_FAIL", e); sys.exit(1)

# ---------- 2. 清空场景 ----------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for b in list(bpy.data.meshes): bpy.data.meshes.remove(b)
for b in list(bpy.data.materials): bpy.data.materials.remove(b)

# ---------- 3. 导入 PMX ----------
before = set(bpy.data.objects)
bpy.ops.mmd_tools.import_model(filepath=PMX, scale=0.08, types={'MESH','ARMATURE','MORPHS'})
new = [o for o in bpy.data.objects if o not in before]
meshes = [o for o in new if o.type == 'MESH']
print("IMPORT_OK objects:", len(new), "meshes:", len(meshes))
if not meshes: sys.exit(1)

# 模型朝向归零并放到原点
roots = [o for o in new if o.parent is None]
arm = next((o for o in new if o.type == 'ARMATURE'), None)
tgt = arm if arm else roots[0]
tgt.location = (0, 0, 0)

bpy.context.view_layer.update()

# ---------- 4. 包围盒 & 相机 ----------
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
rad = max(hi.x - lo.x, hi.y - lo.y, hgt) * 0.62
print("BBOX h=", round(hgt, 3))

# MMD 模型在 Blender 中面向 -Y，正面取 -Y 方向
# 按视野反推距离，保证全身入画
import math as _m
span = max(hi.x - lo.x, hgt) * 1.12   # 目标可见直径（留边）
LENS = 50
def add_cam(name, angle_deg):
    cd = bpy.data.cameras.new(name); cd.lens = LENS
    co = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(co)
    fov = 2 * _m.atan(18.0 / LENS)      # 全幅水平视角
    d = (span * 0.5) / _m.tan(fov * 0.5)
    a = math.radians(angle_deg)
    co.location = (ctr.x + d*math.sin(a), ctr.y - d*math.cos(a), ctr.z + hgt*0.03)
    dirv = Vector((ctr.x, ctr.y, ctr.z)) - co.location
    co.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()
    return co

camF = add_cam("CamFront", 0)
camT = add_cam("CamTQ", 38)
camB = add_cam("CamBack", 180)
sc = bpy.context.scene
sc.camera = camF

# ---------- 5. 灯光/世界 ----------
def mk_lt(nm, tp, loc, en, sz):
    ld = bpy.data.lights.new(nm, tp); ld.energy = en
    if tp == 'AREA': ld.size = sz
    lo_ = bpy.data.objects.new(nm, ld)
    bpy.context.scene.collection.objects.link(lo_); lo_.location = loc

mk_lt("Key",  'AREA', (ctr.x + hgt*0.7, ctr.y - hgt*1.3, ctr.z + hgt*0.75), 320, hgt*1.3)
mk_lt("Fill", 'AREA', (ctr.x - hgt*1.2, ctr.y - hgt*0.9, ctr.z + hgt*0.45), 150, hgt*1.5)
mk_lt("Rim",  'AREA', (ctr.x + hgt*0.2, ctr.y + hgt*1.4, ctr.z + hgt*0.9), 220, hgt*1.2)

w = bpy.data.worlds["World"] if "World" in bpy.data.worlds else bpy.data.worlds.new("World")
w.use_nodes = True
for n in w.node_tree.nodes:
    if n.type == "BACKGROUND":
        n.inputs["Color"].default_value = (0.85, 0.88, 0.92, 1)
        n.inputs["Strength"].default_value = 0.55

# 地面参考圆盘
bpy.ops.mesh.primitive_circle_add(vertices=48, radius=rad*1.05, fill_type='NGON',
                                  location=(ctr.x, ctr.y, lo.z - 0.001))
g = bpy.context.object; g.name = "Ground"
gm = bpy.data.materials.new("Ground_m"); gm.use_nodes = True
for n in gm.node_tree.nodes:
    if n.type == "BSDF_PRINCIPLED":
        n.inputs["Base Color"].default_value = (0.55, 0.55, 0.58, 1)
        n.inputs["Roughness"].default_value = 1.0
g.data.materials.append(gm)

# ---------- 6. 渲染 ----------
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 48
sc.render.resolution_x = 1280; sc.render.resolution_y = 1280
sc.render.image_settings.file_format = "PNG"
sc.render.film_transparent = False
out = []
for cam, tag in [(camF, "front"), (camT, "tq"), (camB, "back")]:
    sc.camera = cam
    p = os.path.join(OUT_DIR, f"taxi_{tag}.png")
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    out.append(p); print("RENDERED", p)

print("OUTPUT=" + out[0])
print("OUTPUT=" + out[1])
print("OUTPUT=" + out[2])
