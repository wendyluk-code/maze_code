import bpy, re
p = bpy.context.scene.render
mt = bpy.types.ImageFormatSettings.bl_rna.properties["media_type"]
print("MEDIA_TYPE_ITEMS", [e.identifier for e in mt.enum_items])
print("CURRENT_MT", p.image_settings.media_type)
# ffmpeg 子结构属性
fp = bpy.types.FFmpegSettings.bl_rna.properties if hasattr(bpy.types, "FFmpegSettings") else []
print("FFMPEG_PROPS", [x.identifier for x in fp])
# 音频编码等
try:
    print("AUDIO_ITEMS", [e.identifier for e in bpy.types.FFmpegSettings.bl_rna.properties["audio_codec"].enum_items])
except Exception as e:
    print("AUDIO_ERR", e)
try:
    print("FMT_ITEMS", [e.identifier for e in bpy.types.FFmpegSettings.bl_rna.properties["format"].enum_items])
except Exception as e:
    print("FMT_ERR", e)
try:
    print("CODEC_ITEMS", [e.identifier for e in bpy.types.FFmpegSettings.bl_rna.properties["codec"].enum_items])
except Exception as e:
    print("CODEC_ERR", e)
