extends "res://tools/tests/salt_pool_flow.gd"

func _capture_image(label: String) -> void:
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 var folder:=_arg("--output-dir=")
 DirAccess.make_dir_recursive_absolute(folder)
 var image:=get_viewport().get_texture().get_image()
 if image: image.save_png(folder.path_join(label+suffix+".png"))
