extends Node
const Capture = preload("res://scripts/ui/components/capture_dialog.gd")
const Loot = preload("res://scripts/ui/components/loot_modal.gd")
func _ready():
 var cap = Capture.new()
 add_child(cap)
 await get_tree().process_frame
 await cap.present(true, "slime", true, 10, 5, 3)
 await get_tree().process_frame
 var a = cap._cancel_button.get_global_rect()
 var b = cap._confirm_button.get_global_rect()
 print("BUTTON_RECTS ",a," ",b)
 assert(absf(a.size.y-b.size.y)<0.1 and absf(a.position.y-b.position.y)<0.1)
 assert(cap.cost_row.get_child(2).text == "1）")
 assert(cap.satiety_icon.size.x >= 18)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://output/capture_layout_acceptance/confirm.png")
 cap.hide()
 var loot = Loot.new()
 add_child(loot)
 await get_tree().process_frame
 loot.show_items([{ "name":"岩盐", "quantity":1, "icon":preload("res://assets/ui/ingredients/rock_salt.png") }])
 loot._title_label.text = "捕获成功"
 loot._body_label.text = "获得食材"
 loot._body_label.show()
 await get_tree().process_frame
 await get_tree().process_frame
 var grid = loot._grid.get_global_rect()
 var panel = loot._panel.get_global_rect()
 print("LOOT_CENTERS ",grid.get_center().x," ",panel.get_center().x)
 assert(absf(grid.get_center().x-panel.get_center().x)<1.0)
 assert(loot._body_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://output/capture_layout_acceptance/loot.png")
 print("LAYOUT_PASS")
 get_tree().quit()
