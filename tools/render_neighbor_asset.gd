extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var avatar=load("res://src/layered_avatar.gd").new();viewport.add_child(avatar)
 var appearance={"schema_version":1,"base":"male","class":"Mage","hair":"male_hair_08","hair_color":"Silver","eyes":"Gray","skin":"brown","username":"WellsideScholar"}
 assert(avatar.configure("male","Mage",appearance));avatar.position=Vector2(128,240);avatar.advance(1,false,0)
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw
 assert(viewport.get_texture().get_image().save_png("res://assets/starter-region/residents/npc_well_scholar_idle_left.png")==OK)
 quit()
