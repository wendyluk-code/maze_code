# -*- coding: utf-8 -*-
"""Blender 5.2 VSE 合成 MP4: media_type='VIDEO'"""
import bpy, os, glob

FRAMES_DIR = r"F:\maze_code\tools\preview\mmd\frames"
OUT_MP4    = r"F:\maze_code\tools\preview\mmd\taxi_test_motion.mp4"

# 清理上次误输出
import glob as _g
for f in _g.glob(os.path.join(os.path.dirname(OUT_MP4), "taxi_test_motion.mp4*.png")):
    os.remove(f)

pngs = sorted(glob.glob(os.path.join(FRAMES_DIR, "frame_*.png")))
if not pngs:
    raise SystemExit("NO_FRAMES")
n = len(pngs)
print("FRAMES_FOUND", n)

sc = bpy.context.scene
sc.frame_start = 1
sc.frame_end = n
sc.render.fps = 12

p = sc.render
p.image_settings.media_type = 'VIDEO'
p.ffmpeg.format = 'MPEG4'
p.ffmpeg.codec = 'H264'
p.ffmpeg.constant_rate_factor = 'HIGH'
p.ffmpeg.audio_codec = 'NONE'
p.use_file_extension = True

sc.render.resolution_x = 1280
sc.render.resolution_y = 1280
sc.render.resolution_percentage = 100
sc.render.filepath = OUT_MP4

sc.sequence_editor_create()
se = sc.sequence_editor
strip = se.strips.new_image(name="anim", filepath=pngs[0], channel=1, frame_start=1)
for fp in pngs[1:]:
    strip.elements.append(os.path.basename(fp))
print("STRIP_OK", len(strip.elements))

bpy.ops.render.render(animation=True)

# 校验输出
out = OUT_MP4 if os.path.exists(OUT_MP4) else OUT_MP4 + ".mp4"
print("MP4_DONE", out, os.path.getsize(out), "bytes")
print("OUTPUT=" + out)
