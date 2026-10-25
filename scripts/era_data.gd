extends RefCounted
## Authored data for New Meridian, a Manhattan-style grid city, in five eras:
## Cretaceous wilds, 1890, 2025, 2150 and a far-future wasteland.
## Every era shares the same block footprints so the city stays recognisable;
## heights, materials and the contents of Founders' Square change.
## World units are metres. The grid lies on the X/Z plane, +Z is "uptown".

const PREHISTORIC := 0
const PAST := 1
const PRESENT := 2
const FUTURE := 3
const WASTELAND := 4
const ERAS := [PREHISTORIC, PAST, PRESENT, FUTURE, WASTELAND]

const AVE_SPACING := 90.0   # avenues run along Z, at x = i * AVE_SPACING
const AVE_COUNT := 6
const AVE_WIDTH := 20.0
const ST_SPACING := 50.0    # streets run along X, at z = j * ST_SPACING
const ST_COUNT := 13
const ST_WIDTH := 12.0
const SIDEWALK := 5.0

const CITY_MIN := Vector2(-14.0, -20.0)  # (x, z)
const CITY_MAX := Vector2(480.0, 620.0)
const RIVER_X := -14.0                   # the North River lies at x < RIVER_X
const RIVER_BED_Y := -6.0
const SINK_Y := -1.0

const SQUARE_COL := 2
const SQUARE_ROWS := [5, 6]
const SQUARE := Rect2(190, 256, 60, 88)   # (x, z, size_x, size_z)
const SQUARE_CENTER := Vector3(220, 0, 300)
const PLOT_CENTER := Vector3(220, 0, 300)
const CLOCK_BLOCK := Vector2i(2, 9)
const NPC_POS := Vector3(198, 0, 262)
const PLAYER_START := Vector3(220, 0, 252)
const TRAFFIC_AVENUES := [1, 2, 3, 4]      # avenue indices that carry traffic


static func era_info(era: int) -> Dictionary:
	match era:
		PREHISTORIC:
			return {
				"name": "Cretaceous, 66,000,000 BC", "short": "PREHISTORIC", "year": -66000000, "year_label": "66,000,000 BC",
				"sky_top": Color("6f9fb0"), "sky_horizon": Color("d8e0b0"), "fog": Color("a8b890"), "fog_density": 0.006,
				"sun": Color("fff0c0"), "sun_energy": 1.0, "ambient": Color("70806a"),
				"ground": Color("4a5a2a"), "road": Color("6a5a3a"), "line": Color("6a5a3a"),
				"palettes": [Color("6a6a60"), Color("7a7060"), Color("5a5a52"), Color("807a6a")],
				"window": Color.BLACK, "window_lit": 0.0, "glow": false,
				"lamp": Color.BLACK,
				"vehicle": "Triceratops", "vehicle_speed": 8.5, "vehicle_color": Color("6a7a3a"),
			}
		WASTELAND:
			return {
				"name": "The Shattered Wastes, AD 30,000", "short": "FAR FUTURE", "year": 30000, "year_label": "AD 30,000",
				"sky_top": Color("5a3a2a"), "sky_horizon": Color("c87a3a"), "fog": Color("a0623a"), "fog_density": 0.009,
				"sun": Color("ff9a60"), "sun_energy": 0.8, "ambient": Color("7a5a4a"),
				"ground": Color("8a6a48"), "road": Color("5a4a3a"), "line": Color("5a4a3a"),
				"palettes": [Color("5a4a40"), Color("6a4a3a"), Color("4a4442"), Color("7a5a42")],
				"window": Color("1a1412"), "window_lit": 0.0, "glow": false,
				"lamp": Color("ff6a2a"),
				"vehicle": "Scrap crawler", "vehicle_speed": 10.0, "vehicle_color": Color("8a4a2a"),
			}
		PAST:
			return {
				"name": "New Meridian, 1890", "short": "PAST", "year": 1890, "year_label": "1890",
				"sky_top": Color("8fa3b8"), "sky_horizon": Color("e3c9a0"), "fog": Color("cdb38e"), "fog_density": 0.0045,
				"sun": Color("ffe0b0"), "sun_energy": 0.9, "ambient": Color("a08a70"),
				"ground": Color("5e4f3c"), "road": Color("6b543b"), "line": Color("4a3a28"),
				"palettes": [Color("7a3b2a"), Color("8a4a32"), Color("6e5844"), Color("9a7b5c")],
				"window": Color("f2cf86"), "window_lit": 0.35, "glow": false,
				"lamp": Color("ffcf7a"),
				"vehicle": "Horse cart", "vehicle_speed": 6.5, "vehicle_color": Color("7b4a26"),
			}
		FUTURE:
			return {
				"name": "New Meridian, 2150", "short": "FUTURE", "year": 2150, "year_label": "2150",
				"sky_top": Color("120a2a"), "sky_horizon": Color("5a2a7a"), "fog": Color("2a1640"), "fog_density": 0.0035,
				"sun": Color("b0a0ff"), "sun_energy": 0.6, "ambient": Color("4a4a8a"),
				"ground": Color("23253a"), "road": Color("14152a"), "line": Color("2ee6d6"),
				"palettes": [Color("1d2140"), Color("272b52"), Color("161a30"), Color("31285a")],
				"window": Color("2ee6d6"), "window_lit": 0.55, "glow": true,
				"lamp": Color("ff4fd8"),
				"vehicle": "Cargo drone", "vehicle_speed": 17.0, "vehicle_color": Color("2ee6d6"),
			}
		_:
			return {
				"name": "New Meridian, 2025", "short": "PRESENT", "year": 2025, "year_label": "2025",
				"sky_top": Color("4f86c6"), "sky_horizon": Color("c9dcef"), "fog": Color("b9c9da"), "fog_density": 0.0025,
				"sun": Color("fff4e0"), "sun_energy": 1.2, "ambient": Color("8090a8"),
				"ground": Color("7a7a77"), "road": Color("3a3c40"), "line": Color("f2c230"),
				"palettes": [Color("8c8f94"), Color("b7a98f"), Color("5f6f80"), Color("a35f46")],
				"window": Color("a9d6f5"), "window_lit": 0.25, "glow": false,
				"lamp": Color("fff2c0"),
				"vehicle": "Yellow cab", "vehicle_speed": 12.0, "vehicle_color": Color("f2c230"),
			}


static func avenue_name(i: int) -> String:
	return ["River Ave", "1st Ave", "2nd Ave", "3rd Ave", "4th Ave", "5th Ave"][i]


static func street_name(j: int) -> String:
	return "W %d St" % (20 + j)


static func block_rect(i: int, j: int) -> Rect2:
	return Rect2(i * AVE_SPACING + AVE_WIDTH / 2.0, j * ST_SPACING + ST_WIDTH / 2.0,
		AVE_SPACING - AVE_WIDTH, ST_SPACING - ST_WIDTH)


static func is_square_block(i: int, j: int) -> bool:
	return i == SQUARE_COL and j in SQUARE_ROWS


## Deterministic building lots: same footprints in every era.
## Returns [{rect: Rect2 (x,z), h: float 0..1, palette: int}].
static func building_lots() -> Array:
	var lots := []
	var rng := RandomNumberGenerator.new()
	for i in range(AVE_COUNT - 1):
		for j in range(ST_COUNT - 1):
			if is_square_block(i, j) or Vector2i(i, j) == CLOCK_BLOCK:
				continue
			rng.seed = hash(Vector2i(i, j))
			var b := block_rect(i, j).grow(-SIDEWALK)
			var nx := rng.randi_range(2, 4)
			var nz := rng.randi_range(1, 2)
			var w := b.size.x / nx
			var d := b.size.y / nz
			for a in range(nx):
				for c in range(nz):
					var r := Rect2(b.position.x + a * w + 0.4, b.position.y + c * d + 0.4, w - 0.8, d - 0.8)
					lots.append({"rect": r, "h": rng.randf(), "palette": rng.randi_range(0, 3)})
	return lots


static func building_height(era: int, h: float) -> float:
	match era:
		PREHISTORIC:
			return 8.0 + h * 22.0  # trees / rock outcrops
		WASTELAND:
			return 4.0 + pow(h, 1.6) * 60.0  # ruined stumps
		PAST:
			return 10.0 + h * 12.0
		FUTURE:
			return 40.0 + pow(h, 1.5) * 260.0
	return 16.0 + pow(h, 2.2) * 150.0


static func initial_props(era: int) -> Array:
	var block := "crate"
	if era == PREHISTORIC:
		block = "rock"
	elif era == WASTELAND:
		block = "scrap"
	var props := [
		{"kind": block, "pos": Vector3(206, 0.5, 248)},
		{"kind": block, "pos": Vector3(232, 0.5, 254)},
		{"kind": block, "pos": Vector3(-6, 0.5, 250)},
		{"kind": block, "pos": Vector3(-6, 0.5, 246)},
	]
	if era == PAST:
		props.append({"kind": "seed", "pos": Vector3(130, 0.5, 250)})
	if era == FUTURE:
		props.append({"kind": "cell", "pos": Vector3(310, 0.5, 250)})
	return props


static func is_block_kind(kind: String) -> bool:
	return kind in ["crate", "rock", "scrap"]


static func npc_line(era: int, changed: bool) -> Dictionary:
	match era:
		PREHISTORIC:
			return {"name": "Stranded Traveller", "line": "Mind the stampedes. And keep your head down - even the Bureau hates coming this far back."}
		WASTELAND:
			if changed:
				return {"name": "Wanderer Kade", "line": "The Last Grove. Every living seed on Earth came from that oak. Somebody planted it, long ago."}
			return {"name": "Wanderer Kade", "line": "Nothing grows here. Hasn't for ten thousand years. That crater used to be a square, the stories say."}
		PAST:
			if changed:
				return {"name": "Gardener Ada", "line": "A seed in Founders' Square! Best thing to happen to this city in years."}
			return {"name": "Gardener Ada", "line": "Square's been bare since the fire. There's a seed seller over on W 25 St, west of 1st Ave."}
		FUTURE:
			if changed:
				return {"name": "Archivist Unit 7", "line": "Oak Biodome: protected since 2061. Seed lineage traced to 1890."}
			return {"name": "Archivist Unit 7", "line": "Square sector collapsed 2097. No historical significance on record."}
		_:
			if changed:
				return {"name": "Park Keeper Jo", "line": "Founders' Oak - planted 1890, nobody knows by whom. The city never built the garage because of it."}
			return {"name": "Lot Attendant", "line": "Garage has been here forever. Used to be some old square, they say."}
