# -*- coding: utf-8 -*-
"""
《料理迷宫》- 餐厅内部场景生成脚本 (Blender 5.2 headless)
运行: blender --background --factory-startup --python gen_restaurant_scene.py
输出: 预览渲染图 + GLB 模型
"""
import bpy
import os

# ---------- 输出路径 ----------
PREVIEW_DIR = r"F:/maze_code/tools/preview"
OUT_PREVIEW = os.path.join(PREVIEW_DIR, "restaurant_preview.png")
OUT_GLB = r"F:/maze_code/assets/models/restaurant/restaurant.glb"

os.makedirs(PREVIEW_DIR, exist_ok=True)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)

# ---------- 清理默认场景 ----------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != "Collection":
        bpy.data.collections.remove(c)
for m in list(bpy.data.materials):
    bpy.data.materials.remove(m)

# ---------- 材质缓存 ----------
MATS = {}

def mat(name, rgb):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = None
    for n in nt.nodes:
        if n.type == "BSDF_PRINCIPLED":
            bsdf = n
            break
    if bsdf is None:
        bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    try:
        bsdf.inputs["Roughness"].default_value = 1.0
    except Exception:
        pass
    for key in ("Specular", "Specular IOR Level"):
        try:
            bsdf.inputs[key].default_value = 0.0
        except Exception:
            pass
    MATS[name] = m
    return m

# ---------- 几何 helpers (Blender Z-up, 地面 y=0) ----------
def box(name, x, z, y_bottom, sx, sz, sy, color):
    """立方体: x/z 为地面坐标, y_bottom 为底部高度"""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y_bottom + sy / 2.0, z))
    o = bpy.context.object
    o.name = name
    o.scale = (sx, sy, sz)
    o.data.materials.append(mat(name + "_m", color))
    return o

def cyl(name, x, z, y_bottom, r, h, color, verts=24):
    """圆柱体"""
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts,
                                        location=(x, y_bottom + h / 2.0, z))
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat(name + "_m", color))
    return o

def sph(name, x, z, y_bottom, r, color):
    """球体"""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y_bottom + r, z))
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat(name + "_m", color))
    return o

# ---------- 调色板 (卡通治愈系) ----------
WOOD_FLOOR   = (0.78, 0.61, 0.42)   # 暖木地板
WOOD_DARK    = (0.55, 0.37, 0.24)   # 深木
WOOD_MID     = (0.66, 0.45, 0.27)   # 中木
WALL_CREAM   = (0.96, 0.91, 0.84)   # 奶油白墙
COUNT_TOP    = (0.91, 0.77, 0.60)   # 前台台面
STEEL        = (0.78, 0.84, 0.87)   # 料理台不锈钢灰
STEEL_TOP    = (0.88, 0.91, 0.93)
MINT         = (0.50, 0.72, 0.79)   # 冰柜薄荷蓝
ORANGE       = (0.91, 0.66, 0.49)   # 暖橙地毯
GREEN        = (0.42, 0.62, 0.42)   # 植物绿
GREEN_LIGHT  = (0.55, 0.72, 0.50)
CREAM        = (0.98, 0.95, 0.87)
RED_ACC      = (0.80, 0.42, 0.36)   # 点缀红
BLUE_BOX     = (0.55, 0.66, 0.78)   # 箱子蓝
BROWN_BOX    = (0.71, 0.55, 0.38)   # 箱子棕
DOOR_BROWN   = (0.36, 0.25, 0.22)   # 门深棕
BLACK        = (0.18, 0.18, 0.20)
GOLD         = (0.85, 0.66, 0.30)

# ---------- 房间尺寸 ----------
ROOM_X, ROOM_Z, WALL_H = 16.0, 9.0, 3.0
WALL_T = 0.25

# ================= 1. 地板与墙体 =================
box("Floor", ROOM_X / 2, 5.2, 0.0, ROOM_X, 10.4, 0.2, WOOD_FLOOR)

# 后墙 (z=0) 与 左右墙
box("Wall_Back", ROOM_X / 2, WALL_T / 2, 0.0, ROOM_X, WALL_T, WALL_H, WALL_CREAM)
box("Wall_Right", ROOM_X - WALL_T / 2, ROOM_Z / 2, 0.0, WALL_T, ROOM_Z, WALL_H, WALL_CREAM)
# 左墙分两段, 中间留门洞 (z: 3.6~5.4)
box("Wall_Left_1", WALL_T / 2, 1.92, 0.0, WALL_T, 3.35, WALL_H, WALL_CREAM)
box("Wall_Left_2", WALL_T / 2, 7.07, 0.0, WALL_T, 3.35, WALL_H, WALL_CREAM)
# 门洞过梁
box("Wall_Lintel", WALL_T / 2, 4.5, 2.4, WALL_T, 1.8, 0.6, WALL_CREAM)
# 前矮墙 (不挡视角) + 花盆基座
box("Wall_Front_Low", ROOM_X / 2, 8.75, 0.0, ROOM_X, WALL_T, 0.6, WALL_CREAM)

# 门 (通向迷宫)
box("Door_Frame_L", WALL_T / 2, 3.58, 0.0, 0.16, 0.16, 2.4, WOOD_DARK)
box("Door_Frame_R", WALL_T / 2, 5.42, 0.0, 0.16, 0.16, 2.4, WOOD_DARK)
box("Door_Frame_T", WALL_T / 2, 4.5, 2.4, 0.16, 1.9, 0.12, WOOD_DARK)
box("Door_Panel", 0.38, 4.5, 0.0, 0.08, 1.62, 2.3, DOOR_BROWN)
box("Door_Handle", 0.5, 4.05, 1.05, 0.06, 0.06, 0.35, GOLD)
# 门外平台 (迷宫方向)
box("Entry_Platform", -0.4, 4.5, 0.0, 1.1, 2.2, 0.16, WOOD_MID)
box("Entry_Arch_L", -0.9, 3.55, 0.0, 0.2, 0.2, 2.4, WOOD_DARK)
box("Entry_Arch_R", -0.9, 5.45, 0.0, 0.2, 0.2, 2.4, WOOD_DARK)
box("Entry_Arch_T", -0.9, 4.5, 2.4, 0.2, 2.1, 0.14, WOOD_DARK)

# ================= 2. 前台 (左上角) =================
box("Front_Counter", 2.3, 1.3, 0.0, 3.4, 1.05, 1.1, WOOD_MID)
box("Front_Counter_Top", 2.3, 1.3, 1.1, 3.55, 1.2, 0.06, COUNT_TOP)
# 前台招牌牌
box("Front_Sign", 2.3, 1.55, 1.6, 1.8, 0.1, 0.7, WOOD_DARK)
box("Front_Sign_Inner", 2.3, 1.6, 1.75, 1.5, 0.06, 0.4, CREAM)
box("Front_Sign_Stem", 1.6, 1.3, 1.1, 0.08, 0.08, 0.5, WOOD_DARK)
box("Front_Sign_Stem2", 3.0, 1.3, 1.1, 0.08, 0.08, 0.5, WOOD_DARK)
# 柜台装饰: 一瓶一碟
cyl("Front_Bottle", 1.35, 1.45, 1.16, 0.09, 0.3, GREEN)
cyl("Front_Plate", 3.35, 1.5, 1.16, 0.14, 0.04, CREAM)

# ================= 3. 用餐区 (右上角) =================
# 地毯
box("Dining_Rug", 12.9, 2.0, 0.03, 4.6, 3.4, 0.05, ORANGE)

def make_table(tx, tz):
    box(f"Table_{tx}_{tz}_Leg1", tx - 0.5, tz - 0.5, 0.0, 0.12, 0.12, 0.75, WOOD_MID)
    box(f"Table_{tx}_{tz}_Leg2", tx + 0.5, tz - 0.5, 0.0, 0.12, 0.12, 0.75, WOOD_MID)
    box(f"Table_{tx}_{tz}_Leg3", tx - 0.5, tz + 0.5, 0.0, 0.12, 0.12, 0.75, WOOD_MID)
    box(f"Table_{tx}_{tz}_Leg4", tx + 0.5, tz + 0.5, 0.0, 0.12, 0.12, 0.75, WOOD_MID)
    box(f"Table_{tx}_{tz}_Top", tx, tz, 0.72, 1.25, 1.25, 0.08, WOOD_DARK)

def make_chair(cx, cz, rot_z=0.0):
    box(f"Chair_{cx}_{cz}_Seat", cx, cz, 0.45, 0.44, 0.44, 0.08, WOOD_DARK)
    box(f"Chair_{cx}_{cz}_Back", cx, cz + 0.2, 0.55, 0.44, 0.08, 0.5, WOOD_DARK)
    box(f"Chair_{cx}_{cz}_Leg1", cx - 0.16, cz - 0.16, 0.0, 0.06, 0.06, 0.45, WOOD_DARK)
    box(f"Chair_{cx}_{cz}_Leg2", cx + 0.16, cz - 0.16, 0.0, 0.06, 0.06, 0.45, WOOD_DARK)
    box(f"Chair_{cx}_{cz}_Leg3", cx - 0.16, cz + 0.16, 0.0, 0.06, 0.06, 0.45, WOOD_DARK)
    box(f"Chair_{cx}_{cz}_Leg4", cx + 0.16, cz + 0.16, 0.0, 0.06, 0.06, 0.45, WOOD_DARK)

# 餐桌1 + 4椅
make_table(11.6, 1.5)
make_chair(10.4, 1.5); make_chair(12.8, 1.5)
make_chair(11.6, 0.3); make_chair(11.6, 2.7)
# 餐桌2 + 4椅
make_table(14.2, 2.4)
make_chair(13.0, 2.4); make_chair(15.4, 2.4)
make_chair(14.2, 1.2); make_chair(14.2, 3.6)
# 桌上摆盘
cyl("Table1_Plate", 11.6, 1.5, 0.8, 0.12, 0.035, CREAM)
cyl("Table2_Plate", 14.2, 2.4, 0.8, 0.12, 0.035, CREAM)

# ================= 4. 料理台 (中下方) =================
box("Kitchen_Base", 7.5, 7.3, 0.0, 4.2, 1.5, 0.9, STEEL)
box("Kitchen_Top", 7.5, 7.3, 0.9, 4.35, 1.65, 0.06, STEEL_TOP)
# 台面上: 锅 x2 + 菜板 + 调料瓶
cyl("Pot_1", 6.3, 7.3, 0.96, 0.22, 0.2, BLACK)
cyl("Pot_Lid_1", 6.3, 7.3, 1.16, 0.2, 0.04, STEEL_TOP)
cyl("Pot_2", 8.6, 7.3, 0.96, 0.22, 0.2, RED_ACC)
box("CuttingBoard", 7.5, 7.3, 0.96, 0.7, 0.35, 0.05, WOOD_MID)
cyl("Bottle_Soy", 6.9, 6.9, 0.96, 0.05, 0.18, WOOD_DARK)
cyl("Bottle_Oil", 8.2, 6.9, 0.96, 0.06, 0.16, GREEN)
# 料理台上方搁架 (靠后)
box("Rack_Col_L", 6.0, 6.4, 0.9, 0.08, 0.08, 1.1, WOOD_DARK)
box("Rack_Col_R", 9.0, 6.4, 0.9, 0.08, 0.08, 1.1, WOOD_DARK)
box("Rack_Shelf_1", 7.5, 6.4, 1.55, 3.2, 0.35, 0.06, WOOD_MID)
box("Rack_Shelf_2", 7.5, 6.4, 1.95, 3.2, 0.35, 0.06, WOOD_MID)
cyl("Rack_Jar_1", 6.5, 6.4, 1.58, 0.07, 0.14, MINT)
cyl("Rack_Jar_2", 7.0, 6.4, 1.58, 0.07, 0.14, ORANGE)
cyl("Rack_Jar_3", 7.5, 6.4, 1.98, 0.07, 0.14, GREEN)
cyl("Rack_Jar_4", 8.0, 6.4, 1.98, 0.07, 0.14, BLUE_BOX)
cyl("Rack_Jar_5", 8.5, 6.4, 1.58, 0.07, 0.14, CREAM)

# ================= 5. 冰柜 (料理台左后) =================
box("Fridge", 4.6, 5.9, 0.0, 0.9, 0.75, 2.0, MINT)
box("Fridge_Top", 4.6, 5.9, 2.0, 0.95, 0.8, 0.06, CREAM)
box("Fridge_Handle", 4.95, 6.15, 0.9, 0.04, 0.04, 0.9, CREAM)
box("Fridge_Light", 4.6, 5.9, 1.1, 0.5, 0.05, 0.3, (0.85, 0.9, 1.0))

# ================= 6. 仓库 (右下角) =================
def make_shelf(sx, sz):
    box(f"Shelf_{sx}_{sz}_L", sx - 1.4, sz, 0.0, 0.07, 0.5, 2.2, WOOD_DARK)
    box(f"Shelf_{sx}_{sz}_R", sx + 1.4, sz, 0.0, 0.07, 0.5, 2.2, WOOD_DARK)
    for i, h in enumerate([0.7, 1.4, 2.1]):
        box(f"Shelf_{sx}_{sz}_B{i}", sx, sz, h - 0.03, 3.0, 0.55, 0.06, WOOD_MID)

make_shelf(11.8, 6.6)
make_shelf(14.6, 6.6)

def make_box(sx, sz, sy_b, color, s=0.55):
    box(f"Crate_{sx}_{sz}", sx, sz, sy_b, s, s, 0.5, color)

# 箱子堆
make_box(10.9, 7.7, 0.0, BROWN_BOX)
make_box(11.5, 8.0, 0.0, BLUE_BOX)
make_box(10.9, 7.7, 0.5, BLUE_BOX, 0.45)
make_box(13.3, 8.1, 0.0, BROWN_BOX)
make_box(15.4, 7.9, 0.0, BROWN_BOX)
make_box(15.4, 7.9, 0.5, RED_ACC, 0.45)
make_box(12.9, 7.5, 0.0, GREEN_LIGHT)
make_box(10.5, 6.8, 0.0, BROWN_BOX)

# ================= 7. 餐车 (料理台侧) =================
box("Cart_Body", 3.9, 4.9, 0.55, 0.9, 0.55, 0.35, CREAM)
box("Cart_Shelf", 3.9, 4.9, 0.9, 0.85, 0.5, 0.05, STEEL_TOP)
box("Cart_Handle", 3.9, 5.35, 0.55, 0.06, 0.5, 0.75, WOOD_DARK)
cyl("Cart_Wheel_1", 3.65, 4.7, 0.0, 0.09, 0.1, BLACK)
cyl("Cart_Wheel_2", 4.15, 4.7, 0.0, 0.09, 0.1, BLACK)
cyl("Cart_Wheel_3", 3.65, 5.1, 0.0, 0.09, 0.1, BLACK)
cyl("Cart_Wheel_4", 4.15, 5.1, 0.0, 0.09, 0.1, BLACK)
# 餐车上的便当盒
box("Cart_Bento", 3.9, 4.9, 0.98, 0.3, 0.25, 0.12, RED_ACC)

# ================= 8. 装饰 =================
# 吊灯 x2
cyl("Lamp_1_Rod", 5.2, 2.6, 2.4, 0.03, 0.6, BLACK)
sph("Lamp_1_Shade", 5.2, 2.6, 3.0, 0.28, (1.0, 0.9, 0.65))
cyl("Lamp_2_Rod", 10.8, 2.6, 2.4, 0.03, 0.6, BLACK)
sph("Lamp_2_Shade", 10.8, 2.6, 3.0, 0.28, (1.0, 0.9, 0.65))

# 挂画
box("Painting_1", 4.5, 0.32, 1.7, 1.1, 0.05, 0.75, BLUE_BOX)
box("Painting_1_Inner", 4.5, 0.34, 1.7, 0.85, 0.03, 0.5, CREAM)
box("Painting_2", 11.5, 0.32, 1.7, 1.1, 0.05, 0.75, ORANGE)
box("Painting_2_Inner", 11.5, 0.34, 1.7, 0.85, 0.03, 0.5, CREAM)

# 盆栽
def make_plant(px, pz):
    cyl(f"Plant_{px}_{pz}_Pot", px, pz, 0.0, 0.22, 0.3, RED_ACC)
    sph(f"Plant_{px}_{pz}_Leaf1", px - 0.1, pz - 0.05, 0.45, 0.16, GREEN)
    sph(f"Plant_{px}_{pz}_Leaf2", px + 0.08, pz + 0.1, 0.5, 0.18, GREEN_LIGHT)
    sph(f"Plant_{px}_{pz}_Leaf3", px + 0.05, pz - 0.12, 0.52, 0.14, GREEN)

make_plant(15.4, 0.7)
make_plant(0.6, 8.3)
make_plant(7.0, 8.75)
make_plant(10.0, 8.75)
make_plant(14.0, 8.75)
make_plant(2.5, 8.75)
# 中央操作区小地垫
box("Play_Rug", 7.5, 4.2, 0.03, 4.0, 2.6, 0.05, GREEN_LIGHT)

# ================= 9. 相机 (2.5D 视角) =================
import mathutils
cam_data = bpy.data.cameras.new("Cam_2_5D")
cam_data.angle = 0.95  # ~54°
cam_obj = bpy.data.objects.new("Cam_2_5D", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
cam_obj.location = (17.5, 11.0, 12.0)
target = mathutils.Vector((7.5, 0.4, 4.5))
direction = (target - cam_obj.location).normalized()
cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = cam_obj

# ================= 10. 灯光 =================
def add_light(lname, ltype, loc, energy, size=None, color=(1, 1, 1)):
    ldata = bpy.data.lights.new(lname, type=ltype)
    ldata.energy = energy
    ldata.color = color
    if size and ltype == "AREA":
        ldata.size = size[0]
        ldata.size_y = size[1]
    lo = bpy.data.objects.new(lname, ldata)
    bpy.context.scene.collection.objects.link(lo)
    lo.location = loc
    return lo

add_light("KeyLight", "AREA", (8, 8, 6), 600, (12, 8), (1, 0.97, 0.92))
add_light("FillLight", "AREA", (2, 3.5, 5), 350, (7, 7), (0.92, 0.95, 1.0))
add_light("RimLight", "AREA", (15, 3, 4), 300, (6, 6), (1, 0.94, 0.86))
add_light("FridgeGlow", "POINT", (4.6, 2.6, 5.9), 80, None, (0.75, 0.85, 1.0))

# 世界光
world = bpy.data.worlds["World"]
world.use_nodes = True
for n in world.node_tree.nodes:
    if n.type == "BACKGROUND":
        n.inputs["Color"].default_value = (1.0, 0.97, 0.93, 1.0)
        n.inputs["Strength"].default_value = 0.45

# ================= 11. 渲染设置 =================
scene = bpy.context.scene
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUT_PREVIEW
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
    try:
        scene.render.engine = eng
        if eng != "BLENDER_WORKBENCH":
            break
    except Exception:
        continue
print("RENDER_ENGINE =", scene.render.engine)

scene.render.film_transparent = False
bpy.ops.render.render(write_still=True)
print("PREVIEW_RENDERED =", OUT_PREVIEW)

# ================= 12. 导出 GLB =================
# 相机/灯光不导出
for o in bpy.data.objects:
    if o.type in ("CAMERA", "LIGHT"):
        o.hide_render = True
try:
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format="GLB",
        use_visible=True,
    )
    print("GLB_EXPORTED =", OUT_GLB)
except Exception as e:
    print("GLB_EXPORT_FAILED:", e)

print("OUTPUT=" + OUT_PREVIEW)
print("OUTPUT=" + OUT_GLB)
