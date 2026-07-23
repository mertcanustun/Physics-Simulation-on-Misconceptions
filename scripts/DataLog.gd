class_name DataLog
## Appends one row per attempt to user://session_log.csv
## (user:// = %APPDATA%/Godot/app_userdata/Kicked-Ball Simulation on Windows,
##  ~/.local/share/godot/app_userdata/... on Linux)

const PATH := "user://session_log.csv"
const HEADER := "timestamp_utc,participant_code,group,seen_topic,session_mode,attempt,gravity,kick_force,air_resistance,correct,v0_mps,angle_deg\n"

static func log_attempt(code: String, group: String, seen: bool, mode: String, attempt: int,
		g: bool, k: bool, a: bool, correct: bool, v0: float, ang: float) -> void:
	var exists := FileAccess.file_exists(PATH)
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		push_error("Cannot open log file: %s" % PATH)
		return
	if exists:
		f.seek_end()
	else:
		f.store_string(HEADER)
	var row := "%s,%s,\"%s\",%s,%s,%d,%s,%s,%s,%s,%.1f,%.1f\n" % [
		Time.get_datetime_string_from_system(true), code, group,
		str(seen), mode, attempt, str(g), str(k), str(a), str(correct), v0, ang]
	f.store_string(row)
	f.close()

static func row_count() -> int:
	if not FileAccess.file_exists(PATH):
		return 0
	var f := FileAccess.open(PATH, FileAccess.READ)
	var n := -1  # minus header
	while not f.eof_reached():
		if f.get_line().strip_edges() != "":
			n += 1
	return maxi(n, 0)

static func export_to(dest: String) -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var src := FileAccess.open(PATH, FileAccess.READ)
	var dst := FileAccess.open(dest, FileAccess.WRITE)
	if src == null or dst == null:
		return false
	dst.store_string(src.get_as_text())
	dst.close()
	return true
