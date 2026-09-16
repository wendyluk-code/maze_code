import bpy
sc = bpy.context.scene
print("RENDER_PROPS", [p.identifier for p in sc.render.bl_rna.properties])
ifs = sc.render.image_settings
print("IFS_PROPS", [p.identifier for p in ifs.bl_rna.properties])
ok = None
for cand in ("FFMPEG", "AVI_JPEG", "QUICKTIME_CARBON", "QUICKTIME", "MPEG4", "WEBM"):
    try:
        ifs.file_format = cand
        ok = cand
        print("FORMAT_OK", cand)
        break
    except Exception as e:
        print("FORMAT_NO", cand)
print("IS_MOVIE", sc.render.is_movie_format() if callable(sc.render.is_movie_format) else sc.render.is_movie_format)
print("PROBE_DONE ok=", ok)
