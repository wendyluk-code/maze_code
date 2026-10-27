extends Node2D
## 仅在原晶石正面绘制已提交裂纹；不替换底图、不覆盖人物。
const Crystals=preload("res://scripts/maze/salt_crystals.gd")
const REVEAL=preload("res://scripts/maze/salt_crack_reveal.gdshader")
const TEXTURES=[
    preload("res://assets/effects/salt_cracks/stage_1.png"),
    preload("res://assets/effects/salt_cracks/stage_2.png"),
    preload("res://assets/effects/salt_cracks/stage_3.png")]
var flow: Node
var dull_hint:=false
var sound: AudioStreamPlayer
var counts: Array[int]=[0,0]
var faces: Array[Polygon2D]=[]
var animations: Array[Tween]=[null,null]
var effect_count:=0

func _ready() -> void:
    # 底图之后、人物之前；裂纹永远属于背景晶石。
    get_parent().move_child(self,1)
    for index in 2:
        var face:=Polygon2D.new()
        face.polygon=Crystals.SHAPES[index][0]
        face.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        var ink:=ShaderMaterial.new()
        ink.shader=REVEAL
        face.material=ink
        add_child(face)
        faces.append(face)
    _sync(false)
    sound=AudioStreamPlayer.new()
    var wav:=AudioStreamWAV.new()
    wav.format=AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate=22050
    var bytes:=PackedByteArray()
    bytes.resize(2205*2)
    for i in 2205:
        var value:=int(sin(i*TAU*170.0/22050)*exp(-float(i)/420)*1800)
        bytes.encode_s16(i*2,value)
    wav.data=bytes
    sound.stream=wav
    add_child(sound)

func feedback(events: Array) -> void:
    var amount:=events.count("salt")
    if amount>0:
        _sync(true)
        flow.maze.show_mined_salt(amount)
    for event in events:
        if event=="empty": flow.maze.show_toast("这簇盐晶今日已采尽")
        elif event=="dull":
            sound.play()
            if not dull_hint:
                dull_hint=true
                flow.maze.show_toast("土属性普攻可开采")

func _process(_dt: float) -> void:
    _sync(false)

func _sync(animate: bool) -> void:
    var ledger: Variant=SaveManager.get("_state").get(Crystals.KEY,{})
    if not Crystals.valid(ledger): return
    for index in 2:
        var count:=Crystals.used(ledger,"left" if index==0 else "right",Crystals.day())
        var face:=faces[index]
        face.visible=count>0
        if count==counts[index]: continue
        var increased:=count>counts[index]
        counts[index]=count
        if animations[index]!=null: animations[index].kill()
        if count==0: continue
        var texture: Texture2D=TEXTURES[count-1]
        face.texture=texture
        var size:=texture.get_size()* (58.0/texture.get_height())
        var center:=Vector2(523,360) if index==0 else Vector2(1159,307)
        var uv:=PackedVector2Array()
        for point in face.polygon:
            uv.append((point-center+size*0.5)/size*texture.get_size())
        face.uv=uv
        var ink:=face.material as ShaderMaterial
        ink.set_shader_parameter("reveal",0.0 if animate and increased else 1.0)
        if animate and increased:
            effect_count+=1
            flow.maze.camera.shake_mining()
            animations[index]=create_tween()
            animations[index].tween_method(func(value: float): ink.set_shader_parameter("reveal",value),0.0,1.0,0.4)
