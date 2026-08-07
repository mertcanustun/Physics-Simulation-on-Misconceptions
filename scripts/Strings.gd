class_name StringsData
extends Node
## KOD YAZMADAN düzenlenebilir metinler — res://localization/strings.csv.
## (class_name "StringsData": autoload adı "Strings" ile çakışmasın diye farklı;
## autoload'a erişim @onready var S: StringsData = get_node("/root/Strings") ile.)
##
## NASIL DÜZENLENİR (teknik olmayan ekip arkadaşları için):
##   1. res://localization/strings.csv dosyasını Excel/Google Sheets/Numbers'ta aç
##      (CSV formatını korumak önemli — "CSV UTF-8" olarak kaydet).
##   2. "text" sütunundaki istediğin satırı değiştir, kaydet.
##   3. Projeyi çalıştır (F5) — kod dokunulmadı, Godot'a bile gerek yok aslında,
##      düz metin editörüyle de açılabilir (virgülle ayrılmış basit bir dosya).
##
## "key" sütununa DOKUNMA — kod o anahtarla arıyor, silinir/değişirse metin
## kaybolur (ekranda anahtarın kendisi görünür, fark edilir).
##
## Kullanım (kod tarafı): S.t("ANAHTAR") -> metin.
## Yer tutuculu metin (ör. "...{0} m önüne düştü"): S.t("ANAHTAR", [değer]).

const PATH := "res://localization/strings.csv"
var _map: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	_map.clear()
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("Strings.gd: %s açılamadı" % PATH)
		return
	f.get_csv_line()   # başlık satırı ("key,text") — atla
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		_map[row[0]] = row[1]
	f.close()

## Anahtar CSV'de yoksa anahtarın kendisini döndürür — ekranda "FB_G_MSG" gibi
## bir şey görürsen CSV'de o satır eksik/silinmiş demektir, fark edilsin diye.
func t(key: String, args: Array = []) -> String:
	var s: String = _map.get(key, key)
	return s.format(args) if not args.is_empty() else s
