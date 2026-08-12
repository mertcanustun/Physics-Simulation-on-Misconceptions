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
##   3. Projeyi çalıştır (F5) — kod dokunulmadı.
##
## "key" sütununa DOKUNMA — kod o anahtarla arıyor.
##
## Kullanım (kod tarafı): S.t("ANAHTAR") -> metin.
## Yer tutuculu metin (ör. "...{0} m önüne düştü"): S.t("ANAHTAR", [değer]).
##
## ---------------------------------------------------------------------------
## METİN NEREDEN GELİR — ÜÇ KATMAN (yukarıdan aşağı denenir)
##
##   1. res://localization/strings.csv        <- ASIL KAYNAK, canlı düzenlenir
##   2. res://scripts/StringsBaked.gd         <- CSV'den "pişirilmiş" yedek
##   3. res://localization/*.text.translation <- Godot'un import ettiği çeviri
##
## NEDEN 2. KATMAN VAR: Godot projedeki her .csv'yi varsayılan olarak "CSV
## Translation" diye IMPORT eder; import edilmiş bir dosyanın KAYNAĞI .pck'ye
## konmaz. Sonuç: editörde (F5) her şey çalışır ama dışa aktarılmış Web/Vercel
## build'inde FileAccess.open() null döner ve tüm metinler anahtar isimlerine
## düşer ("POPUP_INTRO_TITLE" gibi). Bu tam olarak yaşandı.
##
## GDScript dosyaları ise HER ZAMAN pakete girer — bu yüzden CSV, derleme
## öncesi bir GDScript sözlüğüne pişiriliyor:
##
##     godot --headless --path . --script tools/bake_strings.gd
##
## Artık ekranda anahtar ismi görünmesi yapısal olarak imkânsız: CSV pakete
## girmese, import ayarı bozulsa, sunucu dosyayı yutsa bile 2. katman devrede.
##
## (1. katmanın da çalışması için strings.csv.import içeriği şu olmalı:
##      [remap]
##
##      importer="keep"
##  Editörde: strings.csv -> Import sekmesi -> Import As: "Keep File" -> Reimport.
##  export_presets.cfg'deki include_filter BU İŞİ GÖRMEZ, denendi.)
## ---------------------------------------------------------------------------

const PATH := "res://localization/strings.csv"
const FALLBACK_TR := "res://localization/strings.text.translation"

## Hangi katmandan okunduğu — Main._ready bunu konsola basar, tek bakışta belli olur.
enum Source { CSV, BAKED, TRANSLATION, NONE }

var _map: Dictionary = {}
var _tr: Translation = null
var source: Source = Source.NONE

func _ready() -> void:
	_load()

func _load() -> void:
	_map.clear()
	_tr = null
	source = Source.NONE
	if _load_csv():
		source = Source.CSV
		return
	if _load_baked():
		source = Source.BAKED
		push_warning("Strings.gd: CSV pakete girmemiş, pişirilmiş yedek kullanılıyor "
			+ "(strings.csv.import içinde importer=\"keep\" olmalı).")
		return
	if _load_translation():
		source = Source.TRANSLATION
		push_warning("Strings.gd: CSV ve pişirilmiş yedek yok, .translation kullanılıyor.")
		return
	push_error("Strings.gd: hiçbir metin kaynağı bulunamadı — ekranda anahtar isimleri görünecek.")

## 1. katman — canlı CSV.
func _load_csv() -> bool:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	f.get_csv_line()   # başlık satırı ("key,text") — atla
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		_map[row[0]] = row[1]
	f.close()
	return not _map.is_empty()

## 2. katman — tools/bake_strings.gd ile üretilen GDScript sözlüğü.
## preload ile YOL üzerinden alınıyor (class_name/global sınıf kaydına bağlı
## değil): autoload'lar global sınıf önbelleğinden ÖNCE yüklenebildiği için
## "Identifier not declared" hatası riski böylece tamamen ortadan kalkıyor.
const Baked := preload("res://scripts/StringsBaked.gd")

func _load_baked() -> bool:
	for k in Baked.DATA:
		_map[String(k)] = String(Baked.DATA[k])
	return not _map.is_empty()

## 3. katman — Godot'un CSV'den ürettiği Translation (anahtar listesi okunamaz,
## bu yüzden liste olarak değil t() içinde SORGU olarak kullanılır).
func _load_translation() -> bool:
	if not ResourceLoader.exists(FALLBACK_TR):
		return false
	_tr = ResourceLoader.load(FALLBACK_TR) as Translation
	return _tr != null

## Kaç metin yüklendi (0 = hiçbiri; .translation katmanında -1).
func count() -> int:
	if _map.is_empty() and _tr != null:
		return -1
	return _map.size()

func source_name() -> String:
	match source:
		Source.CSV: return "csv"
		Source.BAKED: return "baked"
		Source.TRANSLATION: return "translation"
		_: return "YOK"

## NOT: CSV'de bilerek BOŞ bırakılmış satırlar var (FORCE_*_SUB) — "boş metin"
## ile "anahtar yok"u karıştırmamak için has() ile bakılır, get(key,"") ile değil.
## Anahtar hiçbir katmanda yoksa anahtarın kendisi döner (eksiklik göze batsın).
func t(key: String, args: Array = []) -> String:
	var s: String
	if _map.has(key):
		s = _map[key]
	elif _tr != null:
		s = String(_tr.get_message(key))
		if s == "":
			s = key
	else:
		s = key
	return s.format(args) if not args.is_empty() else s
