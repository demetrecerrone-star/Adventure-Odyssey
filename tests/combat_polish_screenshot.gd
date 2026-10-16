extends SceneTree
# Native Godot effect galleries plus a separate HUD-on actual skill activation.
# Freeze normalized effect age so CPU speed does not decide which frame we see.
const CLASS_SKILLS={
	"Warrior":[["Power Slash","cleave"],["Shield Bash","stun"],["Battle Cry","buff"],["Earthshaker","advanced"]],
	"Ranger":[["Aimed Shot","ranged"],["Quick Volley","volley"],["Snare Trap","trap"],["Hunter's Mark","advanced"]],
	"Mage":[["Firebolt","burn"],["Frost Nova","nova"],["Arcane Barrier","barrier"],["Meteor Burst","advanced"]],
	"Necromancer":[["Raise Skeleton","summon"],["Soul Bolt","ranged"],["Life Drain","drain"],["Death Echo","advanced"]],
	"Assassin":[["Backstab","backstab"],["Shadowstep","step"],["Poison Blade","poison"],["Smoke Veil","advanced"]],
	"Paladin":[["Holy Strike","holy"],["Divine Heal","heal"],["Sacred Shield","shield"],["Consecration","advanced"]]
}
func _initialize()->void:
	call_deferred("_run")

func _snap(filename:String)->bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_viewport().get_texture().get_image()
	return image.get_width()>=500 and image.save_png("res://screenshots/"+filename)==OK

func _label(parent:Node,text:String,rect:Rect2,font_size:int)->void:
	var label=Label.new()
	label.text=text
	label.position=rect.position
	label.size=rect.size
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("#fff1d4"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _gallery(entries:Array,title:String,filename:String)->bool:
	var gallery=CanvasLayer.new()
	gallery.layer=10
	root.add_child(gallery)
	var dim=ColorRect.new()
	dim.size=Vector2(1280,720)
	dim.color=Color(0.025,0.045,0.07,0.90)
	dim.mouse_filter=Control.MOUSE_FILTER_IGNORE
	gallery.add_child(dim)
	_label(gallery,title,Rect2(20,32,1240,54),30)
	_label(gallery,"NATIVE GODOT EFFECT GALLERY  /  REVIEW LABELS ONLY",Rect2(20,92,1240,34),17)
	var columns:int=3 if entries.size()>4 else 4
	var width:float=1280.0/float(columns)
	var effects:Array=[]
	for i in range(entries.size()):
		var col:int=i%columns
		var row:int=i/columns
		var x:float=(float(col)+0.5)*width
		var y:float=260.0+float(row)*250.0 if entries.size()>4 else 370.0
		var name:String=str(entries[i][0])
		var kind:String=str(entries[i][1])
		_label(gallery,name,Rect2(float(col)*width+8.0,y-109.0,width-16.0,35.0),21)
		var center:Vector2=Vector2(x,y)
		var fx=Node2D.new()
		fx.set_script(load("res://scripts/skill_effect.gd"))
		gallery.add_child(fx)
		var origin:Vector2=center
		var target:Vector2=center
		if name in ["Aimed Shot","Quick Volley","Firebolt","Soul Bolt","Life Drain","Death Echo","Shadowstep"]:
			origin=center+Vector2(-70,0)
			target=center+Vector2(70,0)
		fx.call("configure",name,origin,target,Color.WHITE,kind)
		if name=="Quick Volley":fx.call("set_target_positions",[target+Vector2(0,-28),target,target+Vector2(0,28)])
		fx.set_process(false)
		fx.age=fx.duration*0.36
		fx.queue_redraw()
		effects.append(fx)
	_label(gallery,"CAST CUES ONLY  /  NO CHANGES TO DAMAGE, COOLDOWNS OR APPROVED ART",Rect2(20,660,1240,32),17)
	if not await _snap(filename):
		gallery.queue_free()
		return false
	for fx in effects:
		fx.age=fx.duration*0.78
		fx.queue_redraw()
	if not await _snap(filename.replace(".png","_impact.png")):
		gallery.queue_free()
		return false
	gallery.queue_free()
	await process_frame
	return true

func _run()->void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	game._random_default()
	game.data["class"]="Mage"
	game.data["guild_training_completed"]=true
	game._enter_world("forest",Vector2(1030,720))
	await process_frame
	game._dismiss_message()
	game.set_process(false)
	game.hud.hide()
	var starters:Array=[["Power Slash","cleave"],["Firebolt","burn"],["Frost Nova","nova"],["Arcane Barrier","barrier"],["Holy Strike","holy"],["Divine Heal","heal"]]
	var mentors:Array=[["Earthshaker","advanced"],["Hunter's Mark","advanced"],["Meteor Burst","advanced"],["Death Echo","advanced"],["Smoke Veil","advanced"],["Consecration","advanced"]]
	if not await _gallery(starters,"STARTING SKILLS / READABILITY PASS","combat_effects_starters.png"):
		push_error("AO COMBAT SCREENSHOT FAILED: starters")
		quit(1)
		return
	if not await _gallery(mentors,"MENTOR SKILLS / READABILITY PASS","combat_effects_mentors.png"):
		push_error("AO COMBAT SCREENSHOT FAILED: mentors")
		quit(1)
		return
	for hero_class in CLASS_SKILLS:
		if not await _gallery(CLASS_SKILLS[hero_class],str(hero_class).to_upper()+" / THREE STARTERS + MENTOR","combat_effects_"+str(hero_class).to_lower()+".png"):
			push_error("AO COMBAT SCREENSHOT FAILED: "+str(hero_class))
			quit(1)
			return

	# Separate capture: no gallery titles, actual skill button activation and HUD.
	game.hud.show()
	for mob in game.mobs:mob["alive"]=false
	var target:Dictionary=game.mobs[0]
	target["alive"]=true
	target["hp"]=35
	target["node"].visible=true
	target["node"].position=game.player.position+Vector2(160,0)
	game.skill_cooldowns[0]=0.0
	game._use_starting_skill(0)
	var captured:int=0
	for child in game.world.get_children():
		if child.get_script()!=null and child.get_script().resource_path=="res://scripts/skill_effect.gd":
			child.set_process(false)
			child.age=child.duration*0.36
			child.queue_redraw()
			captured+=1
	if captured==0 or not await _snap("combat_effects_gameplay_hud.png"):
		push_error("AO COMBAT SCREENSHOT FAILED: actual HUD-on skill activation")
		quit(1)
		return
	print("ADVENTURE ODYSSEY COMBAT SCREENSHOTS: PASS / 24 skills, deterministic travel and impact galleries, actual HUD-on cast")
	quit(0)
