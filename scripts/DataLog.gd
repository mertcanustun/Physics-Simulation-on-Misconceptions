class_name DataLog
## Her denemeyi user://session_log.csv dosyasına bir satır olarak ekler.
## Masaüstünde: %APPDATA%/Godot/app_userdata/... | Linux: ~/.local/share/godot/app_userdata/...
## Web (tarayıcı) sürümünde: kalıcı IndexedDB alanı — CSV indirmesi JavaScriptBridge ile yapılır.
##
## KAYDEDİLEN ALANLAR (kullanıcının yaptığı TÜM seçimler dahil):
##   kuvvet seçimleri (yerçekimi / vuruş kuvveti / hava direnci),
##   sürtünme seviyesi (Az/Orta/Fazla), vuruş kuvveti F büyüklüğü,
##   vuruş hızı ve açısı, sonucun doğruluğu, gol olup olmadığı, iniş mesafesi,
##   yanılgı kategorisi ve denemenin ne kadar sürdüğü.

const PATH := "user://session_log.csv"
const HEADER := "timestamp_utc,session_id,participant_code,group,seen_topic,session_mode,attempt,gravity,kick_force_sel,air_resistance,friction_level,kick_force_mag,v0_mps,angle_deg,correct,category,goal,landing_x_m,decision_seconds\n"

const FRICTION_NAMES := ["Az", "Orta", "Fazla"]

static var session_id := ""

static func _sid() -> String:
	if session_id == "":
		session_id = "%d-%04d" % [int(Time.get_unix_time_from_system()), randi() % 10000]
	return session_id

static func _csv(v: String) -> String:
	# virgül/tırnak içeren alanları güvenle kaçır
	if v.contains(",") or v.contains("\"") or v.contains("\n"):
		return "\"%s\"" % v.replace("\"", "\"\"")
	return v

static func log_attempt(code: String, group: String, seen: bool, mode: String, attempt: int,
		g: bool, k: bool, a: bool, friction_level: int, kick_mag: float,
		v0: float, ang: float, correct: bool, category: String,
		goal: bool, landing_x: float, decision_s: float) -> void:
	var exists := FileAccess.file_exists(PATH)
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		push_error("Kayıt dosyası açılamadı: %s" % PATH)
		return
	if exists:
		f.seek_end()
	else:
		f.store_string(HEADER)
	var fr: String = FRICTION_NAMES[clampi(friction_level, 0, 2)]
	var row := "%s,%s,%s,%s,%s,%s,%d,%s,%s,%s,%s,%.1f,%.1f,%.1f,%s,%s,%s,%.2f,%.1f\n" % [
		Time.get_datetime_string_from_system(true), _sid(), _csv(code), _csv(group),
		str(seen), mode, attempt,
		str(g), str(k), str(a), fr, kick_mag, v0, ang,
		str(correct), _csv(category), str(goal), landing_x, decision_s]
	f.store_string(row)
	f.close()

static func read_all() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var f := FileAccess.open(PATH, FileAccess.READ)
	return "" if f == null else f.get_as_text()

static func row_count() -> int:
	var txt := read_all()
	if txt == "":
		return 0
	var n := -1  # başlık satırını sayma
	for line in txt.split("\n"):
		if line.strip_edges() != "":
			n += 1
	return maxi(n, 0)

## Son N kaydı kısa özet olarak döndürür — "veri durumu" penceresinde
## loglamanın gerçekten çalıştığını gözle doğrulamak için.
static func tail(n := 3) -> String:
	var txt := read_all()
	if txt == "":
		return "(henüz kayıt yok)"
	var lines: Array = []
	for line in txt.split("\n"):
		if line.strip_edges() != "":
			lines.append(line)
	if lines.size() <= 1:
		return "(henüz kayıt yok)"
	var out := PackedStringArray()
	var start := maxi(1, lines.size() - n)
	for i in range(start, lines.size()):
		var c: PackedStringArray = String(lines[i]).split(",")
		if c.size() >= 17:
			out.append("· %s | deneme %s | Y:%s F:%s H:%s (%s) | doğru:%s gol:%s" % [
				c[2], c[6], c[7], c[8], c[9], c[10], c[14], c[16]])
	return "\n".join(out) if out.size() > 0 else "(okunamadı)"

static func export_to(dest: String) -> bool:
	var txt := read_all()
	if txt == "":
		return false
	var dst := FileAccess.open(dest, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_string(txt)
	dst.close()
	return true

## Tarayıcı sürümünde CSV'yi indirir (masaüstündeki dosya diyaloğu web'de çalışmaz).
static func web_download() -> bool:
	if not OS.has_feature("web"):
		return false
	var txt := read_all()
	if txt == "":
		return false
	var js := """
	(function(t){
		var b = new Blob([t], {type:'text/csv;charset=utf-8;'});
		var u = URL.createObjectURL(b);
		var a = document.createElement('a');
		a.href = u; a.download = 'kicked_ball_data.csv';
		document.body.appendChild(a); a.click();
		setTimeout(function(){ URL.revokeObjectURL(u); a.remove(); }, 100);
	})(%s);
	""" % JSON.stringify(txt)
	JavaScriptBridge.eval(js, true)
	return true
