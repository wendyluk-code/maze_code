# -*- coding: utf-8 -*-
"""
《料理迷宫》- 餐厅内部场景 v2 - 调整相机/光照/配色
"""
import bpy, mathutils, os

PREVIEW_DIR = r"F:/maze_code/tools/preview"
OUT_PREVIEW = os.path.join(PREVIEW_DIR, "restaurant_preview_v2.png")
OUT_GLB = r"F:/maze_code/assets/models/restaurant/restaurant_v2.glb"
os.makedirs(PREVIEW_DIR, exist_ok=True)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)

# ---------- 清理 ----------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != "Collection": bpy.data.collections.remove(c)
for m in list(bpy.data.materials): bpy.data.materials.remove(m)

# ---------- 材质 ----------
MATS = {}
def mat(name, rgb):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            n.inputs["Base Color"].default_value = (*rgb, 1.0)
            try: n.inputs["Roughness"].default_value = 1.0
            except: pass
            try: n.inputs["Specular IOR Level"].default_value = 0.1
            except:
                try: n.inputs["Specular"].default_value = 0.1
                except: pass
            break
    MATS[name] = m; return m

# ---------- helpers ----------
def box(name, x, z, y_bot, sx, sz, sy, color):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y_bot + sy/2, z))
    o = bpy.context.object; o.name = name; o.scale = (sx, sy, sz)
    o.data.materials.append(mat(name+"_m", color)); return o

def cyl(name, x, z, y_bot, r, h, color, v=20):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=v, location=(x, y_bot+h/2, z))
    o = bpy.context.object; o.name = name
    o.data.materials.append(mat(name+"_m", color)); return o

def sph(name, x, z, y_bot, r, color):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=12, ring_count=8,
                                         location=(x, y_bot+r, z))
    o = bpy.context.object; o.name = name
    o.data.materials.append(mat(name+"_m", color)); return o

# ---------- 色板 (更鲜明) ----------
WOOD_FLOOR  = (0.82, 0.65, 0.45)
WALL_CREAM  = (0.97, 0.94, 0.88)
WALL_PINK   = (0.93, 0.84, 0.80)   # 侧墙微粉，增加层次
WOOD_DARK   = (0.52, 0.34, 0.22)
WOOD_MID    = (0.68, 0.48, 0.30)
COUNT_TOP   = (0.92, 0.78, 0.62)
STEEL       = (0.80, 0.86, 0.89)
STEEL_TOP   = (0.90, 0.92, 0.94)
MINT        = (0.50, 0.75, 0.82)
ORANGE      = (0.92, 0.67, 0.50)
GREEN       = (0.40, 0.65, 0.40)
GREEN_L     = (0.55, 0.75, 0.50)
CREAM       = (0.98, 0.96, 0.90)
RED_ACC     = (0.82, 0.44, 0.38)
BLUE_BOX    = (0.58, 0.68, 0.80)
BROWN_BOX   = (0.72, 0.56, 0.40)
DOOR_BR     = (0.38, 0.26, 0.22)
BLACK       = (0.15, 0.15, 0.17)
GOLD        = (0.88, 0.70, 0.32)
POT_RED     = (0.78, 0.42, 0.35)

# ============ 场景 ============
box("Floor", 8, 5.2, 0.0, 16, 10.4, 0.2, WOOD_FLOOR)
# 后墙
box("Wall_Back", 8, 0.12, 0.0, 16, 0.25, 3.0, WALL_CREAM)
# 左墙 (含门洞 3.6~5.4)
box("Wall_L1", 0.12, 1.9, 0.0, 0.25, 3.35, 3.0, WALL_PINK)
box("Wall_L2", 0.12, 7.07, 0.0, 0.25, 3.35, 3.0, WALL_PINK)
box("Wall_Lint", 0.12, 4.5, 2.4, 0.25, 1.8, 0.6, WALL_PINK)
# 右墙
box("Wall_R", 15.87, 4.5, 0.0, 0.25, 9.0, 3.0, WALL_PINK)
# 前矮墙
box("Wall_F", 8, 8.87, 0.0, 16, 0.25, 0.65, WALL_CREAM)

# 门 + 门框
box("DFrame_L", 0.12, 3.56, 0.0, 0.16, 0.14, 2.4, WOOD_DARK)
box("DFrame_R", 0.12, 5.44, 0.0, 0.16, 0.14, 2.4, WOOD_DARK)
box("DFrame_T", 0.12, 4.5, 2.4, 0.16, 1.95, 0.12, WOOD_DARK)
box("Door", 0.36, 4.5, 0.0, 0.08, 1.65, 2.3, DOOR_BR)
box("Handle", 0.52, 4.05, 1.1, 0.06, 0.06, 0.32, GOLD)
# 门外
box("Entry", -0.35, 4.5, 0.0, 1.0, 2.2, 0.14, WOOD_MID)
box("Arch_L", -0.85, 3.53, 0.0, 0.18, 0.18, 2.4, WOOD_DARK)
box("Arch_R", -0.85, 5.47, 0.0, 0.18, 0.18, 2.4, WOOD_DARK)
box("Arch_T", -0.85, 4.5, 2.4, 0.18, 2.1, 0.12, WOOD_DARK)
# 暗色地面延伸（迷宫方向）
box("Entry_Floor", -1.0, 4.5, 0.0, 1.2, 2.6, 0.14, (0.45, 0.35, 0.28))

# ===== 前台 (左上) =====
box("Counter", 2.3, 1.3, 0.0, 3.2, 1.0, 1.1, WOOD_MID)
box("CounterTop", 2.3, 1.3, 1.1, 3.4, 1.15, 0.06, COUNT_TOP)
box("Sign", 2.3, 1.55, 1.6, 1.6, 0.1, 0.75, WOOD_DARK)
box("SignFace", 2.3, 1.6, 1.75, 1.3, 0.06, 0.45, CREAM)
box("SStem1", 1.65, 1.3, 1.1, 0.07, 0.07, 0.55, WOOD_DARK)
box("SStem2", 2.95, 1.3, 1.1, 0.07, 0.07, 0.55, WOOD_DARK)
cyl("FBottle", 1.4, 1.45, 1.16, 0.08, 0.28, GREEN)
cyl("FPlate", 3.25, 1.5, 1.16, 0.13, 0.035, CREAM)

# ===== 用餐区 (右上) =====
box("DiningRug", 12.9, 2.0, 0.03, 4.8, 3.5, 0.06, ORANGE)

def mkTable(tx, tz, tag):
    for dx, dz in [(-0.52,-0.52),(0.52,-0.52),(-0.52,0.52),(0.52,0.52)]:
        box(f"TL_{tag}_{dx}_{dz}", tx+dx, tz+dz, 0.0, 0.1, 0.1, 0.75, WOOD_MID)
    box(f"TT_{tag}", tx, tz, 0.72, 1.2, 1.2, 0.08, WOOD_DARK)

def mkChair(cx, cz, tag):
    box(f"CS_{tag}", cx, cz, 0.44, 0.42, 0.42, 0.07, WOOD_DARK)
    box(f"CB_{tag}", cx, cz-0.17, 0.5, 0.42, 0.07, 0.55, WOOD_MID)
    for dx, dz in [(-0.15,-0.15),(0.15,-0.15),(-0.15,0.15),(0.15,0.15)]:
        box(f"CL_{tag}_{dx}_{dz}", cx+dx, cz+dz, 0.0, 0.05, 0.05, 0.44, WOOD_DARK)

mkTable(11.6, 1.5, "A"); mkTable(14.2, 2.4, "B")
for i, (cx,cz) in enumerate([(10.4,1.5),(12.8,1.5),(11.6,0.4),(11.6,2.6)]):
    mkChair(cx, cz, f"A{i}")
for i, (cx,cz) in enumerate([(13.0,2.4),(15.4,2.4),(14.2,1.2),(14.2,3.6)]):
    mkChair(cx, cz, f"B{i}")
# 桌上餐盘
cyl("TP1", 11.6, 1.5, 0.8, 0.12, 0.03, CREAM)
cyl("TP2", 14.2, 2.4, 0.8, 0.12, 0.03, CREAM)

# ===== 料理台 (中下) =====
box("Kitchen", 7.5, 7.3, 0.0, 4.0, 1.4, 0.9, STEEL)
box("KitchenTop", 7.5, 7.3, 0.9, 4.15, 1.55, 0.06, STEEL_TOP)
# 锅
cyl("Pot1", 6.2, 7.3, 0.96, 0.2, 0.18, BLACK)
cyl("Lid1", 6.2, 7.3, 1.14, 0.18, 0.03, STEEL_TOP)
cyl("Pot2", 8.7, 7.3, 0.96, 0.2, 0.18, POT_RED)
box("Board", 7.4, 7.3, 0.96, 0.65, 0.3, 0.045, WOOD_MID)
cyl("Soy", 6.8, 6.9, 0.96, 0.05, 0.16, WOOD_DARK)
cyl("Oil", 8.2, 6.9, 0.96, 0.05, 0.15, GREEN)
# 上架
box("RkL", 6.0, 6.4, 0.9, 0.07, 0.07, 1.1, WOOD_DARK)
box("RkR", 9.0, 6.4, 0.9, 0.07, 0.07, 1.1, WOOD_DARK)
box("RkS1", 7.5, 6.4, 1.55, 3.2, 0.32, 0.055, WOOD_MID)
box("RkS2", 7.5, 6.4, 1.95, 3.2, 0.32, 0.055, WOOD_MID)
for i,(rx,rz,ry,col) in enumerate([(6.5,6.4,1.58,MINT),(7.0,6.4,1.58,ORANGE),
                                    (7.5,6.4,1.98,GREEN),(8.0,6.4,1.98,BLUE_BOX),(8.5,6.4,1.58,CREAM)]):
    cyl(f"Jar{i}", rx, rz, ry, 0.065, 0.13, col)

# ===== 冰柜 (料理台左侧) =====
box("Fridge", 4.6, 6.0, 0.0, 0.85, 0.7, 2.0, MINT)
box("FridgeTop", 4.6, 6.0, 2.0, 0.92, 0.78, 0.06, CREAM)
box("FridgeH", 4.92, 6.22, 0.95, 0.035, 0.035, 0.8, CREAM)
box("FridgeL", 4.6, 6.36, 1.1, 0.45, 0.04, 0.28, (0.85, 0.9, 1.0))

# ===== 仓库 (右下) =====
def mkShelf(sx, sz, tag):
    box(f"SL_{tag}", sx-1.4, sz, 0.0, 0.06, 0.48, 2.2, WOOD_DARK)
    box(f"SR_{tag}", sx+1.4, sz, 0.0, 0.06, 0.48, 2.2, WOOD_DARK)
    for i,h in enumerate([0.7,1.4,2.1]):
        box(f"SS_{tag}_{i}", sx, sz, h-0.03, 3.0, 0.52, 0.055, WOOD_MID)

mkShelf(11.8, 6.6, "A"); mkShelf(14.6, 6.6, "B")

def mkCrate(cx, cz, cy, col, s=0.52):
    box(f"Crate_{cx}_{cz}_{cy:.0f}", cx, cz, cy, s, s, 0.48, col)

mkCrate(10.9,7.7,0,BROWN_BOX); mkCrate(11.5,8.0,0,BLUE_BOX)
mkCrate(10.9,7.7,0.48,BLUE_BOX,0.42)
mkCrate(13.3,8.1,0,BROWN_BOX); mkCrate(15.4,7.9,0,BROWN_BOX)
mkCrate(15.4,7.9,0.48,RED_ACC,0.42)
mkCrate(12.9,7.5,0,GREEN_L); mkCrate(10.5,6.8,0,BROWN_BOX)

# ===== 餐车 =====
box("Cart", 3.9, 5.0, 0.52, 0.85, 0.52, 0.32, CREAM)
box("CartSh", 3.9, 5.0, 0.84, 0.82, 0.48, 0.05, STEEL_TOP)
box("CartH", 3.9, 5.38, 0.52, 0.05, 0.45, 0.72, WOOD_DARK)
for wcx, wcz in [(3.68,4.82),(4.12,4.82),(3.68,5.18),(4.12,5.18)]:
    cyl(f"W{wcx}_{wcz}", wcx, wcz, 0.0, 0.08, 0.08, BLACK)
box("Bento", 3.9, 5.0, 0.9, 0.28, 0.24, 0.1, RED_ACC)

# ===== 装饰 =====
# 吊灯
cyl("Lamp1R", 5.2, 2.6, 2.4, 0.025, 0.6, BLACK)
sph("Lamp1S", 5.2, 2.6, 3.0, 0.25, (1, 0.92, 0.68))
cyl("Lamp2R", 10.8, 2.6, 2.4, 0.025, 0.6, BLACK)
sph("Lamp2S", 10.8, 2.6, 3.0, 0.25, (1, 0.92, 0.68))

# 挂画
box("Paint1", 4.5, 0.3, 1.7, 1.05, 0.04, 0.72, BLUE_BOX)
box("Paint1I", 4.5, 0.32, 1.7, 0.8, 0.03, 0.48, CREAM)
box("Paint2", 11.5, 0.3, 1.7, 1.05, 0.04, 0.72, ORANGE)
box("Paint2I", 11.5, 0.32, 1.7, 0.8, 0.03, 0.48, CREAM)

# 盆栽
def mkPlant(px, pz, tag):
    cyl(f"P{tag}", px, pz, 0.0, 0.2, 0.28, POT_RED)
    sph(f"PL{tag}_1", px-0.08, pz-0.05, 0.38, 0.15, GREEN)
    sph(f"PL{tag}_2", px+0.07, pz+0.08, 0.42, 0.17, GREEN_L)

mkPlant(15.3,0.7,"1"); mkPlant(0.7,8.3,"2"); mkPlant(2.5,8.75,"3")
mkPlant(7.0,8.75,"4"); mkPlant(10.0,8.75,"5"); mkPlant(14.0,8.75,"6")
# 中央地垫
box("PlayRug", 7.5, 4.3, 0.03, 4.0, 2.4, 0.05, GREEN_L)
# 右侧小地毯 (仓库前)
box("WareRug", 12.5, 7.5, 0.03, 2.5, 1.8, 0.04, (0.85, 0.72, 0.55))

# ===== 相机 (修正 v2: 从 +X +Y +Z 对角俯视) =====
cam = bpy.data.cameras.new("Cam25D"); cam.angle = 0.93
co = bpy.data.objects.new("Cam25D", cam)
bpy.context.scene.collection.objects.link(co)
# 相机从右前上方俯视, 看向房间中心
co.location = (18.0, 10.5, 12.0)
tgt = mathutils.Vector((8.0, 0.3, 4.5))
dir = (tgt - co.location).normalized()
co.rotation_euler = dir.to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = co

# ===== 灯光 (增强) =====
def addLt(nm, tp, loc, energy, sz=None, col=(1,1,1)):
    ld = bpy.data.lights.new(nm, tp); ld.energy = energy; ld.color = col
    if sz and tp == "AREA": ld.size = sz[0]; ld.size_y = sz[1]
    lo = bpy.data.objects.new(nm, ld); bpy.context.scene.collection.objects.link(lo)
    lo.location = loc

addLt("Key","AREA",(8,9,6), 800, (14,10),(1,0.97,0.92))
addLt("Fill","AREA",(1,4,5), 450, (8,8),(0.93,0.95,1.0))
addLt("Rim","AREA",(16,3,4.5), 350, (6,6),(1,0.95,0.87))
addLt("Over","POINT",(8,3,4), 200,None,(1,0.96,0.90))

# ===== 世界光 =====
world = bpy.data.worlds["World"]; world.use_nodes = True
for n in world.node_tree.nodes:
    if n.type == "BACKGROUND":
        n.inputs["Color"].default_value = (1.0, 0.98, 0.95, 1.0)
        n.inputs["Strength"].default_value = 1.2

# ===== 渲染 =====
sc = bpy.context.scene
sc.render.resolution_x = 1600; sc.render.resolution_y = 900
sc.render.image_settings.file_format = "PNG"
sc.render.filepath = OUT_PREVIEW; sc.render.film_transparent = False
for eng in ("BLENDER_EEVEE_NEXT","BLENDER_EEVEE","BLENDER_WORKBENCH"):
    try: sc.render.engine = eng
    except: continue
    if eng != "BLENDER_WORKBENCH": break
print("ENGINE=", sc.render.engine)
bpy.ops.render.render(write_still=True)
print("PREVIEW_DONE=", OUT_PREVIEW)

# ===== GLB 导出 =====
for o in bpy.data.objects:
    if o.type in ("CAMERA","LIGHT"): o.hide_render = True
try:
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_visible=True)
    print("GLB_DONE=", OUT_GLB)
except Exception as e: print("GLB_ERR:", e)

print("OUTPUT=" + OUT_PREVIEW)
print("OUTPUT=" + OUT_GLB)
