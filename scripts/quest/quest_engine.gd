class_name QuestEngine
extends RefCounted
## Data-driven quest runner. Quests live in data/quests/*.json.
## Node selection: state key ("0","1",...) then "default"; a key may hold a list of
## variants with "if" conditions (state_gte, counter_gte, counter_lt — all ANDed).
## Effects: set_state, counter_add, give_item, remove_item, add_sticker, hide_self,
## learn (+learn_title/learn_text), sfx, toast ({n} = counter, {goal} = quest goal).

signal changed
signal toast_requested(text: String)
signal learned(title: String, text: String)
signal hide_requested(key: String)
signal sfx_requested(name: String)

var quests: Array = []

func load_files(paths: Array) -> void:
	quests.clear()
	for p in paths:
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			push_error("Missing quest file: " + p)
			continue
		var d: Variant = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			quests.append(d)
		else:
			push_error("Invalid quest JSON: " + p)

func quest_by_id(id: String) -> Dictionary:
	for q in quests:
		if q.get("quest_id", "") == id:
			return q
	return {}

func requires_ok(q: Dictionary) -> bool:
	var req: Dictionary = q.get("requires", {})
	for k in req.keys():
		if GameData.quest(k) < int(req[k]):
			return false
	return true

func cond_ok(c: Dictionary, q: Dictionary) -> bool:
	var qid: String = q.get("quest_id", "")
	var st := GameData.quest(qid)
	var n := GameData.counter(qid)
	if c.has("state_gte") and st < int(c["state_gte"]):
		return false
	if c.has("counter_gte") and n < int(c["counter_gte"]):
		return false
	if c.has("counter_lt") and n >= int(c["counter_lt"]):
		return false
	return true

func _pick(v: Variant, q: Dictionary) -> Variant:
	if v is Array:
		for opt in v:
			if cond_ok(opt.get("if", {}), q):
				return opt
		return null
	if v is Dictionary and cond_ok(v.get("if", {}), q):
		return v
	return null

## Returns {"quest": Dictionary, "node": Dictionary} or {} when nothing applies.
func resolve(id: String, kind: String) -> Dictionary:
	for key_pass in ["state", "default"]:
		for q in quests:
			if not requires_ok(q):
				continue
			var group: Dictionary = q.get(kind, {})
			if not group.has(id):
				continue
			var entry: Dictionary = group[id]
			var key := str(GameData.quest(q["quest_id"])) if key_pass == "state" else "default"
			if entry.has(key):
				var node: Variant = _pick(entry[key], q)
				if node != null:
					return {"quest": q, "node": node}
	return {}

func fmt(text: String, q: Dictionary) -> String:
	return text.replace("{n}", str(GameData.counter(q.get("quest_id", "")))).replace("{goal}", str(q.get("goal", "")))

func apply(fx: Dictionary, q: Dictionary, instance_key := "") -> void:
	var qid: String = q.get("quest_id", "")
	var dirty := false
	if fx.has("counter_add"):
		GameData.add_counter(qid, int(fx["counter_add"]))
		dirty = true
	if fx.has("set_state"):
		GameData.set_quest(qid, int(fx["set_state"]))
		dirty = true
	if fx.has("give_item"):
		GameData.add_item(str(fx["give_item"]))
		dirty = true
	if fx.has("remove_item"):
		GameData.remove_item(str(fx["remove_item"]))
		dirty = true
	if fx.has("add_sticker"):
		GameData.state["stickers"] = int(GameData.state["stickers"]) + int(fx["add_sticker"])
		dirty = true
	if fx.get("hide_self", false) and instance_key != "":
		if not GameData.state["hidden"].has(instance_key):
			GameData.state["hidden"].append(instance_key)
		hide_requested.emit(instance_key)
		dirty = true
	if fx.has("sfx"):
		sfx_requested.emit(str(fx["sfx"]))
	if fx.has("toast"):
		toast_requested.emit(fmt(str(fx["toast"]), q))
	if fx.has("learn"):
		if not GameData.state["learned"].has(fx["learn"]):
			GameData.state["learned"].append(fx["learn"])
		learned.emit(str(fx.get("learn_title", "")), str(fx.get("learn_text", "")))
		dirty = true
	if dirty:
		GameData.save()
		changed.emit()

func _collect_learns(v: Variant, out: Dictionary) -> void:
	if v is Dictionary:
		if v.has("learn"):
			out[v["learn"]] = {"title": v.get("learn_title", ""), "text": v.get("learn_text", "")}
		for k in v.keys():
			_collect_learns(v[k], out)
	elif v is Array:
		for x in v:
			_collect_learns(x, out)

## Journal rows: every quest whose requirements are met, with status and its learning entry.
func journal_data() -> Array:
	var out: Array = []
	for q in quests:
		var st := GameData.quest(q["quest_id"])
		var steps: Array = q.get("steps", [])
		var done := not steps.is_empty()
		for s in steps:
			if not cond_ok(s.get("done_if", {}), q):
				done = false
		var status := "Selesai" if done else ("Berjalan" if st > 0 else ("Terkunci" if not requires_ok(q) else "Belum dimulai"))
		var learns := {}
		_collect_learns(q, learns)
		var lessons: Array = []
		for id in learns.keys():
			lessons.append({"id": id, "title": learns[id]["title"], "text": learns[id]["text"], "unlocked": GameData.state["learned"].has(id)})
		out.append({"title": q.get("title", ""), "type": q.get("type", "main"), "status": status, "lessons": lessons, "content_status": q.get("content_status", "")})
	return out

## Quest panel rows: main quests always, side quests once started.
func panel_data() -> Array:
	var out: Array = []
	for q in quests:
		if not requires_ok(q):
			continue
		var st := GameData.quest(q["quest_id"])
		if q.get("type", "main") == "side" and st == 0:
			continue
		var steps: Array = []
		for s in q.get("steps", []):
			steps.append({"text": fmt(str(s["text"]), q), "done": cond_ok(s.get("done_if", {}), q) and not s.get("done_if", {}).is_empty()})
		out.append({"title": q.get("title", ""), "type": q.get("type", "main"), "steps": steps})
	return out
