class_name SaveRepository
extends RefCounted
## Repository interface. Gameplay talks only to this API.
## Today: LocalSaveRepository (user:// → IndexedDB on Web).
## Later: a server repository (Supabase/Laravel) implements the same methods.

const SCHEMA_VERSION := 1

func load_state() -> Dictionary:
	push_error("SaveRepository.load_state not implemented")
	return {}

func save_state(_state: Dictionary) -> void:
	push_error("SaveRepository.save_state not implemented")

func clear() -> void:
	pass
