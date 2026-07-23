class_name Codes
## Validates participant codes against the embedded libraries
## the group label from the code structure:
##   L-<grade>-<dept>-<B/N>-<K/E>-<num>   (lise)
##   U-<grade>-<fac>-<A/G/F>-<K/E>-<num>  (üniversite)

static var _codes: Dictionary = {}

const L_GRADE := {"0": "Hazırlık", "1": "9. sınıf", "2": "10. sınıf", "3": "11. sınıf", "4": "12. sınıf"}
const U_GRADE := {"0": "Hazırlık", "1": "1. sınıf", "2": "2. sınıf", "3": "3. sınıf", "4": "4. sınıf"}
const L_DEPT := {"NN": "Bölüm belirsiz / Güzel Sanatlar", "MF": "Sayısal", "TM": "Eşit Ağırlık", "SZ": "Sözel", "DL": "Dil"}
const U_FAC := {"MH": "Mühendislik", "MI": "Mimarlık", "FE": "Fen-Edebiyat", "EF": "Eğitim Fak.", "FO": "Fizik Öğretmenliği", "FZ": "Fizik Bölümü", "GZ": "Güzel Sanatlar", "II": "İİBF"}
const L_STATUS := {"B": "konuyu gördü", "N": "konuyu görmedi"}
const U_STATUS := {"G": "Fizik 1 geçti", "F": "Fizik 1 kaldı", "A": "Fizik 1 almadı"}

static func _load() -> void:
	if not _codes.is_empty():
		return
	var f := FileAccess.open("res://data/codes.json", FileAccess.READ)
	if f == null:
		push_warning("codes.json not found — accepting any well-formed code")
		return
	var arr = JSON.parse_string(f.get_as_text())
	if arr is Array:
		for c in arr:
			_codes[c] = true

static func is_well_formed(code: String) -> bool:
	var re := RegEx.new()
	re.compile("^[LU]-[0-4]-[A-Z]{2}-[A-Z]-[KE]-\\d+$")
	return re.search(code) != null

static func in_library(code: String) -> bool:
	_load()
	if _codes.is_empty():
		return true
	return _codes.has(code)

static func group_label(code: String) -> String:
	var p := code.split("-")
	if p.size() < 6:
		return "?"
	if p[0] == "L":
		return "Lise %s · %s · %s" % [L_GRADE.get(p[1], "?"), L_DEPT.get(p[2], p[2]), L_STATUS.get(p[3], p[3])]
	return "Üni %s · %s · %s" % [U_GRADE.get(p[1], "?"), U_FAC.get(p[2], p[2]), U_STATUS.get(p[3], p[3])]

static func short_group(code: String) -> String:
	var p := code.split("-")
	if p.size() < 6:
		return "?"
	return "%s-%s-%s-%s" % [p[0], p[1], p[2], p[3]]

static func has_seen_topic(code: String) -> bool:
	var p := code.split("-")
	if p.size() < 4:
		return false
	return p[3] in ["B", "G", "F"]  # gördü / dersi aldı (geçti veya kaldı)
