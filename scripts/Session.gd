class_name Session
## Data-collection gating, mirroring the web test system's rules:
## - Admin codes (res://data/admin_codes.json) open the admin panel.
## - A participant code only produces LOGGED data while an admin has
##   activated collection for it. Otherwise the sim runs in practice
##   mode and nothing is saved.
## - State persists in user://participants.json:
##   { code: { "active": bool, "completed": bool, "attempts": int } }

const STATE_PATH := "user://participants.json"
const ADMIN_PATH := "res://data/admin_codes.json"

static var _state: Dictionary = {}
static var _admins: Array = []
static var _loaded := false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(ADMIN_PATH, FileAccess.READ)
	if f:
		var a = JSON.parse_string(f.get_as_text())
		if a is Array:
			_admins = a
	if FileAccess.file_exists(STATE_PATH):
		var s := FileAccess.open(STATE_PATH, FileAccess.READ)
		var d = JSON.parse_string(s.get_as_text())
		if d is Dictionary:
			_state = d

static func _save() -> void:
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_state, "\t"))
	f.close()

static func is_admin(code: String) -> bool:
	_load()
	return code in _admins

static func status(code: String) -> Dictionary:
	_load()
	return _state.get(code, {"active": false, "completed": false, "attempts": 0})

static func is_active(code: String) -> bool:
	return status(code).get("active", false)

static func activate(code: String) -> void:
	_load()
	var st := status(code)
	st["active"] = true
	_state[code] = st
	_save()

static func deactivate(code: String) -> void:
	_load()
	var st := status(code)
	st["active"] = false
	st["completed"] = true
	_state[code] = st
	_save()

static func count_attempt(code: String) -> void:
	_load()
	var st := status(code)
	st["attempts"] = int(st.get("attempts", 0)) + 1
	_state[code] = st
	_save()
