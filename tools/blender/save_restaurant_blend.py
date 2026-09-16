# -*- coding: utf-8 -*-
"""
保存餐厅场景为 .blend 文件（不渲染、不退出，留给 GUI 模式打开）
"""
import bpy, mathutils, os

OUT_BLEND = r"F:/maze_code/assets/models/restaurant/restaurant.blend"
os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)

# ---------- 清理 ----------
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
FLOOR     = (0.78, 0.62, 0.43)
KITCHEN_F = (0.88, 0.85, 0.80)
DOOR_F    = (0.55, 0.42, 0.32)
WCREAM    = (0.96, 0.93, 0.87)
WPALE     = (0.93, 0.85, 0.81)
WDARK     = (0.50, 0.33, 0.21)
WMID      = (0.65, 0.47, 0.29)
CTOP      = (0.90, 0.76, 0.60)
STEEL     = (0.80, 0.86, 0.89)
STOPT     = (0.91, 0.93, 0.94)
MINT      = (0.50, 0.76, 0.83)
ORANGE    = (0.90, 0.64, 0.47)
GREEN     = (0.40, 0.64, 0.40)
GREENL    = (0.55, 0.75, 0.50)
CREAM     = (0.98, 0.96, 0.91)
RED       = (0.82, 0.44, 0.38)
BLUEBOX   = (0.58, 0.68, 0.80)
BRBOX     = (0.72, 0.56, 0.40)
DBROWN    = (0.36, 0.24, 0.20)
BLACK     = (0.10, 0.10, 0.12)
GOLD      = (0.86, 0.68, 0.30)
POTRED    = (0.78, 0.42, 0.35)
SHELF_C   = (0.58, 0.40, 0.25)

# ============ 地面 ============
box("Floor", 8, 5.2, 0.0, 16, 10.4, 0.2, FLOOR)
box("KitchenFloor", 6.5, 7.0, 0.19, 5.5, 3.5, 0.02, KITCHEN_F)
box("DoorFloor", 0.8, 4.5, 0.19, 2.5, 2.6, 0.02, DOOR_F)

# ============ 墙体 ============
box("WBack", 8, 0.12, 0.0, 16, 0.25, 3.0, WCREAM)
box("WL1", 0.12, 1.9, 0.0, 0.25, 3.35, 3.0, WPALE)
box("WL2", 0.12, 7.07, 0.0, 0.25, 3.35, 3.0, WPALE)
box("WLint", 0.12, 4.5, 2.4, 0.25, 1.8, 0.6, WPALE)
box("WR", 15.87, 4.5, 0.0, 0.25, 9.0, 3.0, WPALE)
box("WF", 8, 8.87, 0.0, 16, 0.25, 0.6, WCREAM)
box("DFL", 0.12, 3.55, 0.0, 0.14, 0.14, 2.4, WDARK)
box("DFR", 0.12, 5.45, 0.0, 0.14, 0.14, 2.4, WDARK)
box("DFT", 0.12, 4.5, 2.4, 0.14, 2.0, 0.12, WDARK)
box("DoorP", 0.35, 4.5, 0.0, 0.08, 1.7, 2.28, DBROWN)
box("Handle", 0.50, 4.02, 1.1, 0.045, 0.045, 0.28, GOLD)
box("Entry", -0.35, 4.5, 0.0, 1.0, 2.2, 0.14, DOOR_F)
box("ArchL", -0.85, 3.50, 0.0, 0.15, 0.15, 2.4, WDARK)
box("ArchR", -0.85, 5.50, 0.0, 0.15, 0.15, 2.4, WDARK)
box("ArchT", -0.85, 4.5, 2.4, 0.15, 2.15, 0.12, WDARK)
box("EFloor", -1.1, 4.5, 0.0, 1.2, 2.6, 0.12, (0.40,0.32,0.24))

# ============ 前台 ============
box("Cntr", 2.3, 1.3, 0.0, 3.2, 1.0, 1.05, WMID)
box("CntrTop", 2.3, 1.3, 1.05, 3.4, 1.15, 0.055, CTOP)
box("Sign", 2.3, 1.58, 1.50, 1.55, 0.085, 0.82, WDARK)
box("SignFace", 2.3, 1.62, 1.70, 1.25, 0.045, 0.48, CREAM)
box("SS1", 1.68, 1.3, 1.05, 0.06, 0.06, 0.48, WDARK)
box("SS2", 2.92, 1.3, 1.05, 0.06, 0.06, 0.48, WDARK)
cyl("FBottle", 1.45, 1.45, 1.10, 0.07, 0.24, GREEN)
cyl("FPlate", 3.20, 1.50, 1.10, 0.11, 0.028, CREAM)

# ============ 用餐区 ============
box("DRug", 12.9, 2.0, 0.035, 4.6, 3.3, 0.045, ORANGE)
def mkT(tx,tz,tg):
    for dx,dz in [(-.50,-.50),(.50,-.50),(-.50,.50),(.50,.50)]:
        box(f"TL{tg}_{dx}_{dz}", tx+dx, tz+dz, 0.0, 0.09, 0.09, 0.72, WMID)
    box(f"TT{tg}", tx, tz, 0.69, 1.18, 1.18, 0.07, WDARK)
def mkC(cx,cz,tg):
    box(f"CS{tg}", cx, cz, 0.42, 0.40, 0.40, 0.065, WDARK)
    box(f"CB{tg}", cx, cz-0.16, 0.48, 0.40, 0.055, 0.52, WMID)
    for dx,dz in [(-.14,-.14),(.14,-.14),(-.14,.14),(.14,.14)]:
        box(f"CL{tg}_{dx}_{dz}", cx+dx, cz+dz, 0.0, 0.045, 0.045, 0.42, WDARK)

mkT(11.6,1.5,"A"); mkT(14.2,2.4,"B")
for i,(cx,cz) in enumerate([(10.4,1.5),(12.8,1.5),(11.6,0.4),(11.6,2.6)]): mkC(cx,cz,f"A{i}")
for i,(cx,cz) in enumerate([(13.0,2.4),(15.4,2.4),(14.2,1.2),(14.2,3.6)]): mkC(cx,cz,f"B{i}")
cyl("TP1",11.6,1.5,0.76,0.10,0.025,CREAM)
cyl("TP2",14.2,2.4,0.76,0.10,0.025,CREAM)

# ============ 料理台 ============
box("Kit",7.5,7.3,0.0,3.8,1.3,0.85,STEEL)
box("KitTop",7.5,7.3,0.85,3.95,1.45,0.055,STOPT)
cyl("Pot1",6.3,7.3,0.90,0.18,0.16,BLACK)
cyl("Lid1",6.3,7.3,1.06,0.16,0.025,STOPT)
cyl("Pot2",8.6,7.3,0.90,0.18,0.16,POTRED)
box("Board",7.4,7.3,0.90,0.60,0.28,0.035,WMID)
cyl("Soy",6.85,6.95,0.90,0.04,0.14,WDARK)
cyl("Oil",8.15,6.95,0.90,0.04,0.13,GREEN)
box("RkL",6.1,6.38,0.85,0.06,0.06,1.05,SHELF_C)
box("RkR",8.9,6.38,0.85,0.06,0.06,1.05,SHELF_C)
box("RkS1",7.5,6.38,1.48,2.95,0.30,0.045,WMID)
box("RkS2",7.5,6.38,1.88,2.95,0.30,0.045,WMID)
for i,(rx,rz,ry,cl) in enumerate([(6.5,6.38,1.50,MINT),(7.0,6.38,1.50,ORANGE),(7.5,6.38,1.90,GREEN),(8.0,6.38,1.90,BLUEBOX),(8.5,6.38,1.50,CREAM)]):
    cyl(f"J{i}",rx,rz,ry,0.055,0.11,cl)

# ============ 冰柜 ============
box("Frig",4.6,6.0,0.0,0.80,0.65,1.9,MINT)
box("FrigT",4.6,6.0,1.9,0.88,0.72,0.055,CREAM)
box("FrigH",4.90,6.20,0.90,0.03,0.03,0.75,CREAM)

# ============ 仓库 ============
def mkSh(sx,sz,tg):
    box(f"ShL{tg}",sx-1.35,sz,0.0,0.05,0.45,2.1,SHELF_C)
    box(f"ShR{tg}",sx+1.35,sz,0.0,0.05,0.45,2.1,SHELF_C)
    for i,h in enumerate([0.65,1.3,1.95]):
        box(f"ShB{tg}_{i}",sx,sz,h-0.025,2.85,0.48,0.045,WMID)
mkSh(11.8,6.6,"A"); mkSh(14.6,6.6,"B")
def mkCr(cx,cz,cy,cl,s=0.48):
    box(f"Cr_{cx}_{cz}_{cy:.0f}",cx,cz,cy,s,s,0.44,cl)
mkCr(10.9,7.7,0,BRBOX); mkCr(11.5,8.0,0,BLUEBOX); mkCr(10.9,7.7,0.44,BLUEBOX,0.38)
mkCr(13.3,8.1,0,BRBOX); mkCr(15.4,7.9,0,BRBOX); mkCr(15.4,7.9,0.44,RED,0.38)
mkCr(12.9,7.5,0,GREENL); mkCr(10.5,6.8,0,BRBOX)

# ============ 餐车 ============
box("Cart",3.9,5.0,0.50,0.80,0.50,0.30,CREAM)
box("CartSh",3.9,5.0,0.80,0.78,0.46,0.04,STOPT)
box("CartH",3.9,5.35,0.50,0.045,0.40,0.68,WDARK)
for wx,wz in [(3.68,4.82),(4.12,4.82),(3.68,5.18),(4.12,5.18)]:
    cyl(f"W{wx}_{wz}",wx,wz,0.0,0.065,0.07,BLACK)
box("Bento",3.9,5.0,0.86,0.24,0.20,0.085,RED)

# ============ 装饰 ============
cyl("LR1",5.2,2.6,2.4,0.022,0.52,BLACK)
sph("LS1",5.2,2.6,2.92,0.22,(1,.92,.68))
cyl("LR2",10.8,2.6,2.4,0.022,0.52,BLACK)
sph("LS2",10.8,2.6,2.92,0.22,(1,.92,.68))
box("P1",4.5,0.3,1.7,0.95,0.035,0.68,BLUEBOX)
box("P1I",4.5,0.32,1.7,0.70,0.028,0.44,CREAM)
box("P2",11.5,0.3,1.7,0.95,0.035,0.68,ORANGE)
box("P2I",11.5,0.32,1.7,0.70,0.028,0.44,CREAM)
def mkP(px,pz,tg):
    cyl(f"Pot{tg}",px,pz,0.0,0.16,0.24,POTRED)
    sph(f"Lf{tg}_1",px-0.07,pz-0.04,0.34,0.13,GREEN)
    sph(f"Lf{tg}_2",px+0.05,pz+0.06,0.38,0.15,GREENL)
mkP(15.3,0.7,"1"); mkP(0.7,8.3,"2"); mkP(2.5,8.75,"3")
mkP(7.0,8.75,"4"); mkP(10.0,8.75,"5"); mkP(14.0,8.75,"6")
box("PRug",7.5,4.3,0.035,3.8,2.2,0.04,GREENL)

# ============ 相机 ============
cam = bpy.data.cameras.new("Cam_25D"); cam.angle = 0.88; cam.clip_end = 60
co = bpy.data.objects.new("Cam_25D", cam)
bpy.context.scene.collection.objects.link(co)
co.location = (19.5, 11.5, 13.5)
tgt = mathutils.Vector((7.5, 0.25, 4.5))
d = (tgt - co.location).normalized()
co.rotation_euler = d.to_track_quat("-Z","Y").to_euler()
bpy.context.scene.camera = co

# ============ 灯光 ============
def mkLt(nm,tp,loc,energy,sz=None,col=(1,1,1)):
    ld=bpy.data.lights.new(nm,tp); ld.energy=energy; ld.color=col
    if sz and tp=="AREA": ld.size=sz[0]; ld.size_y=sz[1]
    lo=bpy.data.objects.new(nm,ld); bpy.context.scene.collection.objects.link(lo)
    lo.location=loc
mkLt("Key","SUN",(3,6,10),3.5,None,(1,.98,.93))
mkLt("Fill","AREA",(1,4,5.5),700,(12,10),(.93,.95,1))
mkLt("Back","AREA",(8,0.5,4),500,(8,8),(1,.96,.90))
mkLt("Side","AREA",(16,5,4),550,(8,8),(1,.95,.88))
mkLt("Top","POINT",(8,4,5),300,None,(1,.97,.92))

# ============ 世界光 ============
world = bpy.data.worlds["World"]; world.use_nodes = True
for n in world.node_tree.nodes:
    if n.type=="BACKGROUND":
        n.inputs["Color"].default_value=(1,.98,.95,1)
        n.inputs["Strength"].default_value=0.25

# ============ 渲染设置 (默认 Cycles，打开后可切 EEVEE) ============
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 64
sc.render.resolution_x = 1600; sc.render.resolution_y = 900
sc.render.image_settings.file_format = "PNG"

# ============ 保存 ============
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("BLEND_SAVED=", OUT_BLEND)
print("OUTPUT=" + OUT_BLEND)
