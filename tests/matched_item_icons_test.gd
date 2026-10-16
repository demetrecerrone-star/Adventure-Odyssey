extends SceneTree
# Matching real wearable art and inventory icon source path are kept in sync.
func _initialize()->void:call_deferred("_run")
func _assert(ok:bool,detail:String)->bool:
	if not ok:
		push_error("AO MATCHED EQUIPMENT ICON TEST FAILED: "+detail)
		quit(1)
		return false
	return true
func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game._random_default()
	var panel=Control.new()
	game.add_child(panel)
	for key in game.ITEM_CATALOG.keys():
		var item:String=str(key)
		var slug:String=item.to_lower().replace("'","").replace(" ","_")
		game._item_icon(panel,item,Vector2(0,0),64)
		var node:TextureRect=panel.get_node_or_null("ItemIcon_"+slug)
		if not _assert(node!=null and node.texture!=null,"illustrated equipment icon: "+item):return
		if not _assert(node.texture.resource_path=="res://assets/equipment_item_icons/"+slug+".png","matched worn icon prioritized: "+item):return
	for item in game.GEAR_MATERIAL_NAMES:
		var slug:String=str(item).to_lower().replace(" ","_")
		game._item_icon(panel,str(item),Vector2(0,0),64)
		var node:TextureRect=panel.get_node_or_null("ItemIcon_"+slug)
		if not _assert(node!=null and node.texture!=null,"material icon intact: "+item):return
		if not _assert(node.texture.resource_path.ends_with(".svg"),"original material icon preserved: "+item):return
	print("ADVENTURE ODYSSEY MATCHED ITEM ICON TEST: PASS")
	quit(0)
