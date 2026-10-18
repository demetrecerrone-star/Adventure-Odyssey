extends "res://tests/home_cosmetics_integration_test.gd"
func capture(name: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK,"Capture "+name)
func run() -> void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(844,390)
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 var state=earned_state("Mage","female")
 var room=preload("res://src/bedroom.gd").new()
 room.state=state
 root.add_child(room)
 await process_frame
 room.open_cosmetics()
 for id in preload("res://src/cosmetic_catalog.gd").ITEMS:
  room.overlay.selected=id
  room.overlay._render()
  await capture("cosmetic_"+id+"_phone")
 room.overlay.selected="armor_moonweave"
 room.overlay._purchase()
 await capture("cosmetic_confirm_phone")
 room.overlay._purchase(); room.overlay._equip()
 await capture("cosmetic_owned_phone")
 room.overlay.selected="bed_riverside"
 room.overlay._purchase(); room.overlay._purchase(); room.overlay._equip()
 check(state.wallet_sigils==0,"Real earned wallet spent exactly seven Sigils")
 await capture("cosmetic_blanket_owned_phone")
 room.cancel_overlay()
 check(state.load_saved(),"Reload real purchased equipment")
 room._apply_cosmetics()
 for handed in [false,true]:
  room.control_preferences.left_handed=handed
  room._apply_control_layout()
  await capture("cosmetic_room_"+("left" if handed else "right")+"_phone")
 root.size=Vector2i(1280,720)
 await capture("cosmetic_equipped_room")
 root.size=Vector2i(844,390)
 await process_frame
 room.open_cosmetics()
 room.overlay.selected="armor_emberweave"
 room.overlay._purchase(); room.overlay._purchase()
 await capture("cosmetic_insufficient_phone")
 for path in paths: DirAccess.remove_absolute(path)
 print("HOME COSMETICS SCREENSHOTS: 13 views; %d checks; failures: %d" % [checks,failures])
 quit(1 if failures else 0)
