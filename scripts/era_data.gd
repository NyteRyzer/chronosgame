extends RefCounted
## Authored data for the three era snapshots of one Meridian street.
## Every era shares the same landmark footprint so the player can recognise
## the place; causal changes swap the plaza contents.

const PAST := 0
const PRESENT := 1
const FUTURE := 2

const WORLD_SIZE := Vector2(1600, 900)
const ROAD := Rect2(0, 300, 1600, 200)
const PLAZA := Rect2(600, 580, 400, 300)
const WATER := Rect2(1380, 520, 90, 380)
const PLOT := Rect2(770, 690, 60, 60)
const PLOT_CENTER := Vector2(800, 720)
const NPC_POS := Vector2(1060, 650)
const PLAYER_START := Vector2(160, 250)
const HAZARD_Y := 400.0


static func era_info(era: int) -> Dictionary:
	match era:
		PAST:
			return {
				"name": "Meridian, 1890", "short": "PAST", "year": 1890,
				"ground": Color("5e4e39"), "sidewalk": Color("8f7c5e"), "road": Color("7a6347"),
				"building": Color("5a3f2c"), "roof": Color("7d4c32"), "window": Color("e8c57a"),
				"water": Color("3d5a5c"), "water_name": "Meridian Creek",
				"hazard_name": "Runaway horse cart", "hazard_speed": 250.0, "hazard_color": Color("8b5a2b"),
				"tint": Color(1.0, 0.85, 0.6, 0.10),
			}
		FUTURE:
			return {
				"name": "Meridian, 2150", "short": "FUTURE", "year": 2150,
				"ground": Color("1c1f33"), "sidewalk": Color("2b3050"), "road": Color("15172a"),
				"building": Color("262b4a"), "roof": Color("3a4170"), "window": Color("2ee6d6"),
				"water": Color("3b1d5a"), "water_name": "Temporal Rift",
				"hazard_name": "Cargo drone", "hazard_speed": 430.0, "hazard_color": Color("2ee6d6"),
				"tint": Color(0.5, 0.3, 1.0, 0.08),
			}
		_:
			return {
				"name": "Meridian, 2025", "short": "PRESENT", "year": 2025,
				"ground": Color("4a5560"), "sidewalk": Color("8e979e"), "road": Color("33383d"),
				"building": Color("5d6670"), "roof": Color("737d88"), "window": Color("a9d6f5"),
				"water": Color("2f5f86"), "water_name": "Meridian Canal",
				"hazard_name": "Delivery truck", "hazard_speed": 340.0, "hazard_color": Color("c0392b"),
				"tint": Color(0, 0, 0, 0),
			}


static func common_walls() -> Array:
	return [
		# north row of landmarks (clock tower in the middle)
		Rect2(60, 40, 260, 150), Rect2(380, 40, 220, 150), Rect2(700, 20, 200, 170),
		Rect2(980, 40, 240, 150), Rect2(1280, 40, 260, 150),
		# south blocks
		Rect2(60, 580, 260, 280), Rect2(380, 620, 200, 240), Rect2(1490, 580, 90, 280),
		# world border
		Rect2(-40, -40, 1680, 40), Rect2(-40, 900, 1680, 40),
		Rect2(-40, 0, 40, 900), Rect2(1600, 0, 40, 900),
	]


## Era-specific solid obstacles. `changed` is true once the 1890 seed is planted.
static func era_walls(era: int, changed: bool) -> Array:
	match era:
		PAST:
			return [Rect2(220, 205, 120, 30)]  # seed merchant's stall
		PRESENT:
			if changed:
				return [Rect2(780, 700, 40, 40)]  # Founders' Oak trunk
			return [Rect2(650, 640, 46, 84), Rect2(720, 640, 46, 84), Rect2(880, 770, 46, 84), Rect2(940, 770, 46, 84)]
		FUTURE:
			if changed:
				return [Rect2(780, 700, 40, 40)]
			return [Rect2(660, 690, 70, 50), Rect2(900, 640, 60, 60), Rect2(860, 800, 50, 40)]
	return []


static func initial_props(era: int) -> Array:
	var props := [
		{"kind": "crate", "pos": Vector2(520, 260)},
		{"kind": "crate", "pos": Vector2(1160, 560)},
	]
	if era == PAST:
		props.append({"kind": "seed", "pos": Vector2(290, 265)})
	if era == FUTURE:
		props.append({"kind": "cell", "pos": Vector2(1250, 255)})
	return props


static func npc_line(era: int, changed: bool) -> Dictionary:
	match era:
		PAST:
			if changed:
				return {"name": "Gardener Ada", "line": "A seed in the old square! Best thing to happen to Meridian in years."}
			return {"name": "Gardener Ada", "line": "Square's been bare since the fire. Somebody ought to plant something."}
		FUTURE:
			if changed:
				return {"name": "Archivist Unit 7", "line": "Oak Biodome: protected since 2061. Seed lineage traced to 1890."}
			return {"name": "Archivist Unit 7", "line": "Plaza sector collapsed 2097. No historical significance on record."}
		_:
			if changed:
				return {"name": "Park Keeper Jo", "line": "Founders' Oak - planted 1890, nobody knows by whom. The city moved the parking for it."}
			return {"name": "Lot Attendant", "line": "Parking's been here forever. Used to be some old square, they say."}
