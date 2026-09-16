# -*- coding: utf-8 -*-
"""
《料理迷宫》- 餐厅场景 v3: Cycles 渲染 + 更清晰的配色
"""
import bpy, mathutils, os

PREVIEW_DIR = r"F:/maze_code/tools/preview"
OUT_PREVIEW = os.path.join(PREVIEW_DIR, "restaurant_v3.png")
OUT_GLB = r"F:/maze_code/assets/models/restaurant/restaurant_v3.glb"
os.makedirs(PREVIEW_DIR, exist_ok=True)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)

# 清理
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != "Collection": bpy.data.collections.remove(c)
for m in list(bpy.data.materials): bpy.data.materials.remove(m)

# ---- 材质 ----
MATS = {}
def mat(name, rgb, rough=1.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            n.inputs["Base Color"].default_value = (*rgb, 1.0)
            n.inputs["Roughness"].default_value = rough
            try: n.inputs["Specular IOR Level"].default_value = 0.1
            except:
                try: n.inputs["Specular"].default_value = 0.1
                except: pass
            break
    MATS[name] = m; return m

def box(n, x, z, yb, sx, sz, sy, c, r=1.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, yb+sy/2, z))
    o=bpy.context.object; o.name=n; o.scale=(sx,sy,sz)
    o.data.materials.append(mat(n+"_m", c, r)); return o

def cyl(n, x, z, yb, radius, h, c, v=20):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=h, vertices=v,
                                        location=(x, yb+h/2, z))
    o=bpy.context.object; o.name=n
    o.data.materials.append(mat(n+"_m", c)); return o

def sph(n, x, z, yb, r, c):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=12, ring_count=8,
                                         location=(x, yb+r, z))
    o=bpy.context.object; o.name=n
    o.data.materials.append(mat(n+"_m", c)); return o

# ---- 色板 ----
FLOOR   = (0.80, 0.63, 0.44)
WCREAM  = (0.96, 0.93, 0.87)
WPALE   = (0.91, 0.82, 0.78)
WDARK   = (0.52, 0.34, 0.22)
WMID    = (0.67, 0.48, 0.30)
CTOP    = (0.91, 0.77, 0.61)
STEEL   = (0.82, 0.88, 0.91)
STOPT   = (0.92, 0.94, 0.95)
MINT    = (0.50, 0.76, 0.83)
ORANGE  = (0.92, 0.67, 0.50)
GREEN   = (0.42, 0.66, 0.42)
GREENL  = (0.56, 0.76, 0.52)
CREAM   = (0.98, 0.96, 0.91)
RED     = (0.82, 0.44, 0.38)
BLUEBOX = (0.58, 0.68, 0.80)
BRBOX   = (0.72, 0.56, 0.40)
DBROWN  = (0.38, 0.26, 0.22)
BLACK   = (0.12, 0.12, 0.14)
GOLD    = (0.88, 0.70, 0.32)
POTRED  = (0.78, 0.42, 0.35)

# ============ 房间 ============
box("Floor", 8, 5.2, 0.0, 16, 10.4, 0.2, FLOOR)
box("WBack", 8, 0.12, 0.0, 16, 0.25, 3.0, WCREAM)
box("WL1", 0.12, 1.9, 0.0, 0.25, 3.35, 3.0, WPALE)
box("WL2", 0.12, 7.07, 0.0, 0.25, 3.35, 3.0, WPALE)
box("WLint", 0.12, 4.5, 2.4, 0.25, 1.8, 0.6, WPALE)
box("WR", 15.87, 4.5, 0.0, 0.25, 9.0, 3.0, WPALE)
box("WF", 8, 8.87, 0.0, 16, 0.25, 0.6, WCREAM)

# 门
box("DFL", 0.12, 3.56, 0.0, 0.15, 0.14, 2.4, WDARK)
box("DFR", 0.12, 5.44, 0.0, 0.15, 0.14, 2.4, WDARK)
box("DFT", 0.12, 4.5, 2.4, 0.15, 1.95, 0.12, WDARK)
box("Door", 0.36, 4.5, 0.0, 0.08, 1.65, 2.3, DBROWN)
box("Handle", 0.52, 4.05, 1.1, 0.05, 0.05, 0.30, GOLD)
# 门外迷宫
box("Entry", -0.35, 4.5, 0.0, 1.0, 2.2, 0.14, WMID)
box("ArchL", -0.85, 3.53, 0.0, 0.16, 0.16, 2.4, WDARK)
box("ArchR", -0.85, 5.47, 0.0, 0.16, 0.16, 2.4, WDARK)
box("ArchT", -0.85, 4.5, 2.4, 0.16, 2.1, 0.12, WDARK)
box("EFloor", -1.0, 4.5, 0.0, 1.2, 2.6, 0.12, (0.42,0.34,0.26))

# ===== 前台 =====
box("Cntr", 2.3, 1.3, 0.0, 3.2, 1.0, 1.1, WMID)
box("CntrTop", 2.3, 1.3, 1.1, 3.4, 1.15, 0.06, CTOP)
box("Sign", 2.3, 1.58, 1.55, 1.6, 0.09, 0.8, WDARK)
box("SignF", 2.3, 1.62, 1.72, 1.3, 0.05, 0.46, CREAM)
box("SS1", 1.65, 1.3, 1.1, 0.065, 0.065, 0.5, WDARK)
box("SS2", 2.95, 1.3, 1.1, 0.065, 0.065, 0.5, WDARK)
cyl("FBottle", 1.42, 1.45, 1.16, 0.075, 0.26, GREEN)
cyl("FPlate", 3.22, 1.5, 1.16, 0.12, 0.03, CREAM)

# ===== 用餐区 =====
box("DRug", 12.9, 2.0, 0.03, 4.8, 3.5, 0.05, ORANGE)

def mkT(tx,tz,tg):
    for dx,dz in [(-.52,-.52),(.52,-.52),(-.52,.52),(.52,.52)]:
        box(f"TL{tg}_{dx}_{dz}", tx+dx, tz+dz, 0.0, 0.1, 0.1, 0.75, WMID)
    box(f"TT{tg}", tx, tz, 0.72, 1.2, 1.2, 0.08, WDARK)

def mkC(cx,cz,tg):
    box(f"CS{tg}", cx, cz, 0.44, 0.42, 0.42, 0.07, WDARK)
    box(f"CB{tg}", cx, cz-0.17, 0.5, 0.42, 0.06, 0.55, WMID)
    for dx,dz in [(-.15,-.15),(.15,-.15),(-.15,.15),(.15,.15)]:
        box(f"CL{tg}_{dx}_{dz}", cx+dx, cz+dz, 0.0, 0.05, 0.05, 0.44, WDARK)

mkT(11.6,1.5,"A"); mkT(14.2,2.4,"B")
for i,(cx,cz) in enumerate([(10.4,1.5),(12.8,1.5),(11.6,0.4),(11.6,2.6)]):
    mkC(cx,cz,f"A{i}")
for i,(cx,cz) in enumerate([(13.0,2.4),(15.4,2.4),(14.2,1.2),(14.2,3.6)]):
    mkC(cx,cz,f"B{i}")
cyl("TP1",11.6,1.5,0.8,0.11,0.03,CREAM)
cyl("TP2",14.2,2.4,0.8,0.11,0.03,CREAM)

# ===== 料理台 =====
box("Kit", 7.5, 7.3, 0.0, 4.0, 1.4, 0.9, STEEL)
box("KitTop", 7.5, 7.3, 0.9, 4.15, 1.55, 0.06, STOPT)
cyl("Pot1",6.2,7.3,0.96,0.19,0.18,BLACK)
cyl("Lid1",6.2,7.3,1.14,0.17,0.03,STOPT)
cyl("Pot2",8.7,7.3,0.96,0.19,0.18,POTRED)
box("Board",7.4,7.3,0.96,0.65,0.3,0.04,WMID)
cyl("Soy",6.8,6.9,0.96,0.045,0.15,WDARK)
cyl("Oil",8.2,6.9,0.96,0.045,0.14,GREEN)
box("RkL",6.0,6.4,0.9,0.07,0.07,1.1,WDARK)
box("RkR",9.0,6.4,0.9,0.07,0.07,1.1,WDARK)
box("RkS1",7.5,6.4,1.55,3.2,0.32,0.05,WMID)
box("RkS2",7.5,6.4,1.95,3.2,0.32,0.05,WMID)
for i,(rx,rz,ry,cl) in enumerate([(6.5,6.4,1.58,MINT),(7.0,6.4,1.58,ORANGE),
    (7.5,6.4,1.98,GREEN),(8.0,6.4,1.98,BLUEBOX),(8.5,6.4,1.58,CREAM)]):
    cyl(f"J{i}",rx,rz,ry,0.06,0.12,cl)

# ===== 冰柜 =====
box("Frig",4.6,6.0,0.0,0.85,0.7,2.0,MINT)
box("FrigT",4.6,6.0,2.0,0.92,0.78,0.06,CREAM)
box("FrigH",4.92,6.22,0.95,0.03,0.03,0.8,CREAM)

# ===== 仓库 =====
def mkSh(sx,sz,tg):
    box(f"ShL{tg}",sx-1.4,sz,0.0,0.06,0.48,2.2,WDARK)
    box(f"ShR{tg}",sx+1.4,sz,0.0,0.06,0.48,2.2,WDARK)
    for i,h in enumerate([0.7,1.4,2.1]):
        box(f"ShB{tg}_{i}",sx,sz,h-0.03,3.0,0.52,0.05,WMID)
mkSh(11.8,6.6,"A"); mkSh(14.6,6.6,"B")

def mkCr(cx,cz,cy,cl,s=0.5):
    box(f"Cr_{cx}_{cz}_{cy:.0f}",cx,cz,cy,s,s,0.46,cl)
mkCr(10.9,7.7,0,BRBOX); mkCr(11.5,8.0,0,BLUEBOX)
mkCr(10.9,7.7,0.46,BLUEBOX,0.4)
mkCr(13.3,8.1,0,BRBOX); mkCr(15.4,7.9,0,BRBOX)
mkCr(15.4,7.9,0.46,RED,0.4)
mkCr(12.9,7.5,0,GREENL); mkCr(10.5,6.8,0,BRBOX)

# ===== 餐车 =====
box("Cart",3.9,5.0,0.52,0.85,0.52,0.32,CREAM)
box("CartSh",3.9,5.0,0.84,0.82,0.48,0.04,STOPT)
box("CartH",3.9,5.38,0.52,0.05,0.42,0.72,WDARK)
for wx,wz in [(3.68,4.82),(4.12,4.82),(3.68,5.18),(4.12,5.18)]:
    cyl(f"W{wx}_{wz}",wx,wz,0.0,0.07,0.08,BLACK)
box("Bento",3.9,5.0,0.9,0.26,0.22,0.09,RED)

# ===== 装饰 =====
cyl("LR1",5.2,2.6,2.4,0.025,0.55,BLACK)
sph("LS1",5.2,2.6,2.95,0.24,(1,.92,.68))
cyl("LR2",10.8,2.6,2.4,0.025,0.55,BLACK)
sph("LS2",10.8,2.6,2.95,0.24,(1,.92,.68))
box("P1",4.5,0.3,1.7,1.0,0.04,0.7,BLUEBOX)
box("P1I",4.5,0.32,1.7,0.75,0.03,0.46,CREAM)
box("P2",11.5,0.3,1.7,1.0,0.04,0.7,ORANGE)
box("P2I",11.5,0.32,1.7,0.75,0.03,0.46,CREAM)

def mkP(px,pz,tg):
    cyl(f"Pot{tg}",px,pz,0.0,0.18,0.26,POTRED)
    sph(f"Lf{tg}_1",px-0.08,pz-0.04,0.36,0.14,GREEN)
    sph(f"Lf{tg}_2",px+0.06,pz+0.07,0.40,0.16,GREENL)
mkP(15.3,0.7,"1"); mkP(0.7,8.3,"2"); mkP(2.5,8.75,"3")
mkP(7.0,8.75,"4"); mkP(10.0,8.75,"5"); mkP(14.0,8.75,"6")
box("PRug",7.5,4.3,0.03,4.0,2.4,0.04,GREENL)

# ===== 相机 =====
cam = bpy.data.cameras.new("Cam"); cam.angle = 0.93; cam.clip_end = 50
co = bpy.data.objects.new("Cam", cam)
bpy.context.scene.collection.objects.link(co)
# 从右上方向房间内俯视
co.location = (19.0, 10.0, 13.0)
tgt = mathutils.Vector((7.5, 0.3, 4.5))
d = (tgt - co.location).normalized()
co.rotation_euler = d.to_track_quat("-Z","Y").to_euler()
bpy.context.scene.camera = co

# ===== 灯光 =====
def mkLt(nm,tp,loc,energy,sz=None,col=(1,1,1)):
    ld=bpy.data.lights.new(nm,tp); ld.energy=energy; ld.color=col
    if sz and tp=="AREA": ld.size=sz[0]; ld.size_y=sz[1]
    lo=bpy.data.objects.new(nm,ld); bpy.context.scene.collection.objects.link(lo)
    lo.location=loc

mkLt("Key","SUN",(4,5,10), 4, None, (1,.98,.93))
mkLt("Fill","AREA",(0,3,5), 600, (10,10), (.93,.95,1))
mkLt("Back","AREA",(8,0.5,4), 400, (6,8), (1,.96,.9))
mkLt("Side","AREA",(16,4,4), 500, (6,8), (1,.95,.88))

# ===== 世界光 (低，避免过曝) =====
world = bpy.data.worlds["World"]; world.use_nodes = True
for n in world.node_tree.nodes:
    if n.type=="BACKGROUND":
        n.inputs["Color"].default_value=(1,.98,.95,1)
        n.inputs["Strength"].default_value=0.3

# ===== 渲染 (Cycles) =====
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.device="CPU"; sc.cycles.samples=64
sc.render.resolution_x=1600; sc.render.resolution_y=900
sc.render.image_settings.file_format="PNG"
sc.render.filepath=OUT_PREVIEW; sc.render.film_transparent=False
print("ENGINE=", sc.render.engine)
bpy.ops.render.render(write_still=True)
print("PREVIEW_DONE=", OUT_PREVIEW)

# ===== GLB 导出 =====
for o in bpy.data.objects:
    if o.type in ("CAMERA","LIGHT"): o.hide_render=True
try:
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_visible=True)
    print("GLB_DONE=", OUT_GLB)
except Exception as e: print("GLB_ERR:", e)

print("OUTPUT=" + OUT_PREVIEW)
print("OUTPUT=" + OUT_GLB)
