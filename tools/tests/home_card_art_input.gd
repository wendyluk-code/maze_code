extends Node
const Modal := preload("res://scripts/ui/components/character_card_art_modal.gd")
const Art := preload("res://scripts/ui/components/home_card_art.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/maps/adventurer_home.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var modal := Modal.new()
	root.add_child(modal)
	for dimensions in [Vector2i(1152, 648), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(dimensions)
		await get_tree().process_frame
		for character in ["yaya", "tieshan"]:
			modal.present(character, Art.owned_for_character(character, Art.initial_counts(["yaya", "tieshan"]), ["yaya", "tieshan"]))
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var destination := "res://output/home_original_cards/%s_%dx%d.png" % [character, dimensions.x, dimensions.y]
			get_viewport().get_texture().get_image().save_png(destination)
			for slot in modal.strip.get_children():
				var card: TextureRect = slot.get_child(0)
				assert(card is TextureRect and not card.texture is AtlasTexture)
				assert(card.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
				assert(card.size == modal.CARD_SIZE and card.get_child_count() == 0)
	print("ORIGINAL_CARD_ART: full textures and two-resolution captures passed")
	get_tree().quit()
