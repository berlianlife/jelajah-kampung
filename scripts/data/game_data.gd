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
		state[k] = loaded[k]

func default_state() -> Dictionary:
	return {
		"quests": {"q.help_neighbor": 0},
		"inventory": [],
		"stickers": 0,
		"learned": [],
		"player": {"x": -10.0, "z": 1.0},
	}

func quest(id: String) -> int:
	return int(state["quests"].get(id, 0))

func set_quest(id: String, value: int) -> void:
	state["quests"][id] = value
	save()

func has_item(id: String) -> bool:
	return state["inventory"].has(id)

func add_item(id: String) -> void:
	if not has_item(id):
		state["inventory"].append(id)

func remove_item(id: String) -> void:
	state["inventory"].erase(id)

func save() -> void:
	repo.save_state(state)

func reset() -> void:
	repo.clear()
	state = default_state()

func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_SPACE],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
