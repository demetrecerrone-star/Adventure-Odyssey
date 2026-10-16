extends SceneTree
# Verify the exact approved source, Godot project icon and Android export paths.
func _initialize()->void:
	call_deferred("_test")
func _check(ok:bool,description:String)->bool:
	if not ok:
		push_error("APP ICON TEST FAILED: "+description)
		quit(1)
		return false
	return true
func _test()->void:
	var original:Image=Image.load_from_file("res://assets/branding/Golden_AO_Fantasy_Compass_Emblem_original.png")
	if not _check(original!=null and original.get_size()==Vector2i(1254,1254),"original user-supplied icon preserved at full resolution"):return
	for size in [192,432,512]:
		var file_name:String="res://assets/branding/adventure_odyssey_icon_%d.png" % size
		var icon_image:Image=Image.load_from_file(file_name)
		if not _check(icon_image!=null and icon_image.get_size()==Vector2i(size,size),"correct Android/Godot icon size: "+file_name):return
		# Resampling maintains center artwork; no crop or alternative image.
		var cx:int=int(size/2)
		var p:Color=icon_image.get_pixel(cx,cx)
		if not _check(p.b>p.r and p.b>p.g,"central blue AO compass preserved at "+str(size)):return
	if not _check(str(ProjectSettings.get_setting("application/config/icon",""))=="res://assets/branding/adventure_odyssey_icon_512.png","Godot app icon references user's artwork"):return
	var cfg=ConfigFile.new()
	if not _check(cfg.load("res://export_presets.cfg")==OK,"Android export preset readable"):return
	if not _check(str(cfg.get_value("preset.0.options","launcher_icons/main_192x192",""))=="res://assets/branding/adventure_odyssey_icon_192.png","Android launcher icon uses user's artwork"):return
	if not _check(str(cfg.get_value("preset.0.options","launcher_icons/adaptive_foreground_432x432",""))=="res://assets/branding/adventure_odyssey_icon_432.png","Android adaptive foreground is original resized, not generated replacement"):return
	print("ADVENTURE ODYSSEY APP ICON TEST: PASS")
	quit(0)
