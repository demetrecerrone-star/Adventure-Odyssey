extends SceneTree
# Checks the 18 starting skill images and interactive touch HUD.
func _initialize()->void:
	call_deferred("_run")

func _ok(value:bool,description:String)->bool:
	if not value:
		push_error("SKILL ICONS TEST FAILED: "+description)
		quit(1)
		return false
	return true

func _run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	var classes=["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]
	var icons_seen:Dictionary={}
	for hero_class in classes:
		scene._random_default()
		scene.data["class"]=hero_class
		scene.data["guild_training_completed"]=false
		scene._enter_world("forest",Vector2(430,640))
		await process_frame
		scene._dismiss_message()
		for slot in range(3):
			var button:Button=scene.hud.get_node_or_null("SkillSlot%d" % slot) as Button
			if not _ok(button!=null,hero_class+" button "+str(slot)+" created"):return
			var ability:String=str(scene._starter_skills()[slot]["name"])
			if not _ok(button.text==ability.to_upper(),ability+" full skill name"):return
			var artwork:TextureRect=button.get_node_or_null("SkillIcon") as TextureRect
			if not _ok(artwork!=null and artwork.texture!=null,ability+" SVG texture imported"):return
			if not _ok(artwork.texture.get_size()==Vector2(96,96),ability+" 96px SVG dimensions"):return
			if not _ok(not icons_seen.has(artwork.texture.resource_path),ability+" unique skill image"):return
			icons_seen[artwork.texture.resource_path]=true
			var caption:Label=button.get_node_or_null("SkillName") as Label
			if not _ok(caption!=null and caption.text==ability.to_upper().replace(" ","\n"),ability+" fitted caption"):return
			scene.skill_cooldowns[slot]=2.25
			scene._refresh_skill_icon_cooldowns()
			var countdown:Label=button.get_node_or_null("Cooldown") as Label
			if not _ok(countdown!=null and countdown.text=="3",ability+" cooldown timer"):return
			scene.skill_cooldowns[slot]=0.0
			scene._refresh_skill_icon_cooldowns()
			if not _ok(countdown.text=="",ability+" cooldown reset"):return
	if not _ok(icons_seen.size()==18,"all 18 original skill symbols are distinct"):return
	print("ADVENTURE ODYSSEY SKILL ICONS TEST: PASS")
	quit(0)
