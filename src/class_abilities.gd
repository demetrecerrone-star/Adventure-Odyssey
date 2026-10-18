extends RefCounted
# Names/slots/effects restored from the original archived STARTING_CLASS_SKILLS.
# Mana costs and bounded encounter damage are provisional tuning, not XP gates.
const SETS := {
	"Warrior":[{"name":"Power Slash","short":"Slash","kind":"cleave","damage":18,"range":170.0,"cd":4.5,"mana":10},{"name":"Shield Bash","short":"Bash","kind":"stun","damage":10,"range":135.0,"cd":7.0,"mana":8},{"name":"Battle Cry","short":"Cry","kind":"buff","cd":15.0,"mana":12}],
	"Ranger":[{"name":"Aimed Shot","short":"Aim","kind":"ranged","damage":23,"range":360.0,"cd":5.5,"mana":10},{"name":"Quick Volley","short":"Volley","kind":"volley","damage":11,"range":330.0,"cd":8.0,"mana":14},{"name":"Snare Trap","short":"Snare","kind":"trap","cd":11.0,"mana":8}],
	"Mage":[{"name":"Firebolt","short":"Fire","kind":"burn","damage":17,"range":320.0,"cd":5.0,"mana":10},{"name":"Frost Nova","short":"Frost","kind":"nova","damage":9,"range":230.0,"cd":10.0,"mana":14},{"name":"Arcane Barrier","short":"Ward","kind":"barrier","cd":15.0,"mana":12}],
	"Necromancer":[{"name":"Raise Skeleton","short":"Raise","kind":"summon","cd":19.0,"mana":18},{"name":"Soul Bolt","short":"Soul","kind":"ranged","damage":18,"range":320.0,"cd":5.5,"mana":10},{"name":"Life Drain","short":"Drain","kind":"drain","damage":12,"range":250.0,"cd":9.0,"mana":12}],
	"Assassin":[{"name":"Backstab","short":"Stab","kind":"backstab","damage":17,"range":145.0,"cd":6.0,"mana":8},{"name":"Shadowstep","short":"Step","kind":"step","range":280.0,"cd":11.0,"mana":10},{"name":"Poison Blade","short":"Venom","kind":"poison","damage":9,"range":150.0,"cd":8.0,"mana":10}],
	"Paladin":[{"name":"Holy Strike","short":"Holy","kind":"holy","damage":18,"range":175.0,"cd":6.0,"mana":10},{"name":"Divine Heal","short":"Heal","kind":"heal","cd":13.0,"mana":16},{"name":"Sacred Shield","short":"Shield","kind":"shield","cd":18.0,"mana":14}]
}
static func for_class(selected_class: String) -> Array:
	return SETS.get(selected_class,[]).duplicate(true)
