extends "res://tests/tutorial_save_test.gd"
func capture(name: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://screenshots/"+name+".png")==OK,name)
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 var state=fixture("Ranger","female")
 var point: Vector2=Save.Relic.point(state.hidden_relic)
 check(state.set_location("starter_region",point),"Reach tree")
 var world=preload("res://src/starter_world.gd").new(); world.state=state
 root.add_child(world); world.set_process(false); await process_frame
 world.player=point; world._update_actor(); world._process(0)
 await capture("hidden_stick_roots")
 world.interact()
 check(state.hidden_relic.claimed,"Actual world search grants stick")
 world._process(0)
 await capture("hidden_stick_found")
 check(state.equip(Save.Relic.ITEM),"Equip discovered weapon")
 world.actor.set_equipped_weapon(state.equipped_weapon)
 world.player=point+Vector2(0,100); world._update_actor()
 for direction in range(4):
  world.actor.advance(direction,true,0.2)
  await capture("hidden_stick_held_"+str(direction))
 check(state.unequip(),"Inspect saved stick in bag")
 world.actor.set_equipped_weapon(state.equipped_weapon)
 root.size=Vector2i(844,390)
 world.open_menu()
 world.overlay.selected_item=Save.Relic.ITEM
 world.overlay.show_page("inventory")
 world.overlay._reveal_inventory_details()
 await capture("hidden_stick_inventory_phone")
 for path in paths: DirAccess.remove_absolute(path)
 print("HIDDEN STICK SCREENSHOTS: %d; failures: %d" % [checks,failures])
 quit(1 if failures else 0)
