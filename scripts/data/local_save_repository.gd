class_name LocalSaveRepository
extends SaveRepository
## Saves to user://save.json. On Web export, user:// is persisted in IndexedDB.

const PATH := "user://save.json"

func load_state() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		# Future: migrate older schemas here instead of dropping them.
		return {}
	return parsed.get("data", {})

func save_state(state: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save file")
		return
	f.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"data": state,
	}))

func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
