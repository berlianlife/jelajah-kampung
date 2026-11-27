extends Node
## Autoload "GameData": input map, game state, persistence via repository.

var repo: SaveRepository
var state: Dictionary = {}

func _ready() -> void:
	_setup_input()
	repo = LocalSaveRepository.new()
	state = default_state()
	var loaded := repo.load_state()
	for k in loaded.keys():
		if k == "settings" and loaded[k] is Dictionary:
			for sk in loaded[k].keys():
				state["settings"][sk] = loaded[k][sk]
		else:
			state[k] = loaded[k]

func default_settings() -> Dictionary:
	return {"ortho": false, "pitch": 60.0, "distance": 24.0, "vol_voice": 1.0, "vol_amb": 0.4, "vol_sfx": 0.7, "day_cycle": true}

func default_state() -> Dictionary:
	return {
		"quests": {},
		"counters": {},
		"inventory": [],
		"hidden": [],
		"stickers": 0,
		"learned": [],
		"player": {"x": -10.0, "z": 1.0},
		"settings": default_settings(),
		"time": {"day": 1, "hour": 7.0},
	}

func quest(id: String) -> int:
	return int(state["quests"].get(id, 0))

func set_quest(id: String, value: int) -> void:
	state["quests"][id] = value

func counter(id: String) -> int:
	return int(state.get("counters", {}).get(id, 0))

func add_counter(id: String, n: int) -> void:
	if not state.has("counters"):
		state["counters"] = {}
	state["counters"][id] = counter(id) + n

func has_item(id: String) -> bool:
	return state["inventory"].has(id)

func add_item(id: String) -> void:
	if not has_item(id):
		state["inventory"].append(id)

func remove_item(id: String) -> void:
	state["inventory"].erase(id)

func save() -> void:
	repo.save_state(state)

## Clears progress but keeps the player's settings.
func reset() -> void:
	var keep: Dictionary = state.get("settings", default_settings()).duplicate()
	repo.clear()
	state = default_state()
	state["settings"] = keep
	save()

func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_SPACE],
		"settings": [KEY_ESCAPE],
		"journal": [KEY_J],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
