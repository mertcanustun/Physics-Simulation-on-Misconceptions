extends Node
## ============================================================================
## Telemetry — kullanıcı ETKİLEŞİM/DAVRANIŞ telemetrisi (kavramsal-değişim analizi)
## ============================================================================
## Her olayı `user://events_log.jsonl` dosyasına BİR JSON satırı olarak ekler
## (JSON Lines: her satır bağımsız bir JSON nesnesi). DataLog (deneme-başına
## ÖZET CSV) ile birlikte çalışır, onun YERİNE geçmez:
##   · DataLog  → "ne seçti, doğru muydu, gol mü" (deneme başına 1 satır)
##   · Telemetry→ "NASIL karar verdi" (olay akışı: hover, mouse yolu, tıklama...)
## İkisi sid + code + attempt üzerinden birleştirilebilir.
##
## OTOMATİK toplananlar (kod eklemeye gerek yok):
##   · mouse_move  — karar aşamasında mouse yörüngesi (~15 Hz, durunca seyrekleşir)
##   · click       — tıklama konumları (hangi ekranda nereye bastı)
## API ile bildirilenler (Main.gd'den çağrılır — bkz. docs/logger-entegrasyon.md):
##   decision_start, option_hover, option_toggle, param_change,
##   answer_submit, answer_change, replay, run_complete
##
## Bu bir AUTOLOAD'dur (Project Settings → Autoload, ad: "Telemetry").
## class_name YOK — global erişim autoload adından gelir.
##
## GİZLİLİK: Yalnızca yönetici bu kod için veri toplamayı AÇTIYSA (official) yazar;
## "deneme modu"nda hiçbir şey yazılmaz (DataLog ile aynı ilke). Geliştirme
## testinde geçici olarak DEBUG_LOG_IN_TRIAL = true yapılabilir.

const PATH := "user://events_log.jsonl"
const MOVE_INTERVAL := 1.0 / 15.0   # karar aşamasında mouse örnekleme periyodu (~15 Hz)
const MOVE_MIN_DIST := 3.0          # bu kadar px kımıldamadıysa örnekleme (dwell'i seyrekleştir)
const DEBUG_LOG_IN_TRIAL := false   # true → veri toplama kapalıyken de yazar (YALNIZ geliştirme testi)

var _sid := ""
var session_events: Array = []   # Tüm olayların birikeceği hafıza havuzu
var _code := ""
var _group := ""
var _seen := false
var _mode := "trial"
var _official := false
var _attempt := 0

var _deciding := false
var _decision_t0 := 0.0
var _first_done := false
var _toggle_count := 0
var _last_toggle_key := ""          # aynı tıklamanın çift toggle sinyalini elemek için
var _last_toggle_t := 0.0
var _hover_enter := {}              # faktör -> hover giriş zamanı (dwell hesabı için)
var _move_accum := 0.0
var _last_pos := Vector2(-1, -1)

var _f: FileAccess = null

# ---------------------------------------------------------------- yardımcı
func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0

func _active() -> bool:
	return _sid != "" and (_official or DEBUG_LOG_IN_TRIAL)

func _since_ms() -> int:
	return int(round((_now_s() - _decision_t0) * 1000.0)) if _deciding else -1

# ---------------------------------------------------------------- oturum / kimlik
## Katılımcı kod girip simülasyona girince çağrılır (Main._on_continue).
func begin_session(code: String, group: String, seen: bool, official: bool) -> void:
	_sid = "%d-%04d" % [int(Time.get_unix_time_from_system()), randi() % 10000]
	_code = code
	_group = group
	_seen = seen
	set_official(official)
	_attempt = 0
	_deciding = false
	
	session_events.clear() # <--- YENİ EKLENEN SATIR (Eski havuzu temizle)
	
	if _active():
		var vp := get_viewport().get_visible_rect().size
		_write("session_begin", {"viewport_w": int(vp.x), "viewport_h": int(vp.y)})

## Yönetici veri toplamayı açtı/kapadıysa modu güncelle (Main._on_run'da teyit edilir).
func set_official(on: bool) -> void:
	_official = on
	_mode = "official" if on else "trial"

## Giriş ekranına dönünce (Main._show_entry) — oturumu kapat.
func end_session() -> void:
	if _active():
		_write("session_end", {})
	_close()
	_sid = ""
	_deciding = false

# ---------------------------------------------------------------- karar aşaması
## Soru gösterilip karar aşaması başladığında (Main._on_intro_done /
## _on_change_answer / _on_reset_sim). attempt = birazdan yapılacak deneme no'su.
func decision_start(attempt: int) -> void:
	_attempt = attempt
	_deciding = true
	_decision_t0 = _now_s()
	_first_done = false
	_toggle_count = 0
	_hover_enter.clear()
	_last_pos = Vector2(-1, -1)
	_move_accum = 0.0
	if _active():
		_write("decision_start", {})

func _maybe_first(kind: String, extra: Dictionary) -> void:
	# karar aşamasındaki İLK anlamlı eylem — "düşünme süresi" bunun since_decision_ms'idir
	if _deciding and not _first_done:
		_first_done = true
		var d := {"kind": kind, "since_decision_ms": _since_ms()}
		d.merge(extra)
		if _active():
			_write("first_interaction", d)

# ---------------------------------------------------------------- opsiyon etkileşimleri
## Bir kuvvet kutusuna mouse girdi/çıktı (Main._force_box → mouse_entered/exited).
func option_hover(factor: String, entered: bool) -> void:
	if not _deciding:
		return
	if entered:
		_hover_enter[factor] = _now_s()
		_maybe_first("hover", {"factor": factor})   # İLK yaklaşılan seçenek burada yakalanır
		if _active():
			_write("option_hover", {"factor": factor, "phase": "enter", "since_decision_ms": _since_ms()})
	else:
		var dwell := -1
		if _hover_enter.has(factor):
			dwell = int(round((_now_s() - float(_hover_enter[factor])) * 1000.0))
			_hover_enter.erase(factor)
		if _active():
			_write("option_hover", {"factor": factor, "phase": "leave", "since_decision_ms": _since_ms(), "dwell_ms": dwell})

## Bir kuvvet işaretlendi/kaldırıldı (Main._force_box → cb.toggled).
func option_toggle(factor: String, checked: bool) -> void:
	if not _deciding:
		return
	# Godot: button_pressed set'i + manuel toggled.emit() aynı tıklamada iki sinyal
	# üretebilir; aynı faktör+durum 60ms içinde tekrar gelirse yok say.
	var key := "%s:%s" % [factor, str(checked)]
	var now := _now_s()
	if key == _last_toggle_key and (now - _last_toggle_t) < 0.06:
		return
	_last_toggle_key = key
	_last_toggle_t = now
	_toggle_count += 1
	_maybe_first("toggle", {"factor": factor})
	if _active():
		_write("option_toggle", {"factor": factor, "checked": checked, "order": _toggle_count, "since_decision_ms": _since_ms()})

## Bir parametre değişti — genel amaçlı, şu an aktif bir çağıran yok
## (sürtünme seviyesi seçimi 2026-08-07'de kaldırıldı); ileride yeniden
## seçilebilir bir parametre eklenirse kullanılabilir.
func param_change(pname: String, value) -> void:
	if not _deciding:
		return
	_maybe_first("param", {"name": pname})
	if _active():
		_write("param_change", {"name": pname, "value": value, "since_decision_ms": _since_ms()})

## "Ne olacağını gör / Vuruşu başlat" — cevap gönderildi (Main._on_run).
func answer_submit(gravity: bool, kick: bool, air: bool, correct: bool, category: String) -> void:
	var d := {
		"gravity": gravity, "kick": kick, "air": air,
		"correct": correct, "category": category,
		"decision_ms": _since_ms(), "toggle_count": _toggle_count,
	}
	if _active():
		_write("answer_submit", d)
	_deciding = false   # karar bitti → mouse örneklemeyi durdur

## "Yeni cevap dene" (Main._on_change_answer).
func answer_change() -> void:
	if _active():
		_write("answer_change", {"attempt": _attempt})

## "Tekrar dene" (Main._on_replay).
func replay() -> void:
	if _active():
		_write("replay", {"attempt": _attempt})

## "Simülasyonu Bitir" — katılımcı oturumu kendi isteğiyle bitirdi
## (Main._on_finish_sim). end_session'dan HEMEN ÖNCE yazılır ki oturumun
## normal mi bittiği yoksa yarıda mı kaldığı analizde ayırt edilebilsin.
func run_finish_pressed() -> void:
	if _active():
		_write("finish_pressed", {"attempt": _attempt})

## Uçuş bitti — sonuç (Main._on_flight_finished).
func run_complete(goal: bool, impact_x: float, category := "") -> void:
	if _active():
		_write("run_complete", {"goal": goal, "impact_x": impact_x, "category": category})

# ---------------------------------------------------------------- otomatik yakalama
func _process(delta: float) -> void:
	if not (_deciding and _active()):
		return
	_move_accum += delta
	if _move_accum < MOVE_INTERVAL:
		return
	_move_accum = 0.0
	var p := get_viewport().get_mouse_position()
	if _last_pos.x >= 0.0 and p.distance_to(_last_pos) < MOVE_MIN_DIST:
		return   # kımıldamadı → dwell'i seyrek örnekle (yine de bir sonraki hareket yakalanır)
	_last_pos = p
	_write("mouse_move", {"x": int(p.x), "y": int(p.y), "since_decision_ms": _since_ms()})

func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventMouseButton and event.pressed:
		_write("click", {
			"x": int(event.position.x), "y": int(event.position.y),
			"button": event.button_index, "deciding": _deciding,
			"since_decision_ms": _since_ms(),
		})

# ---------------------------------------------------------------- yazma
func _open() -> void:
	if _f != null:
		return
	var exists := FileAccess.file_exists(PATH)
	_f = FileAccess.open(PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if _f != null and exists:
		_f.seek_end()

func _close() -> void:
	if _f != null:
		_f.flush()
		_f.close()
		_f = null

func _write(type: String, payload: Dictionary) -> void:
	var row := {
		"ts_ms": Time.get_unix_time_from_system() * 1000.0,
		"sid": _sid, "code": _code, "group": _group, "seen": _seen, "mode": _mode,
		"attempt": _attempt, "type": type,
	}
	row.merge(payload)
	
	session_events.append(row) # <--- YENİ EKLENEN SATIR (Paketi hafızaya da at)
	
	_open()
	if _f == null:
		push_error("Telemetry: kayıt dosyası açılamadı: %s" % PATH)
		return
	_f.store_line(JSON.stringify(row))
	_f.flush()   # her olaydan sonra diske yaz (çökmede veri kaybını önler)

func _exit_tree() -> void:
	_close()

# ---------------------------------------------------------------- okuma / dışa aktarma
func read_all() -> String:
	_close()   # tamponu diske geçir, sonra oku
	if not FileAccess.file_exists(PATH):
		return ""
	var f := FileAccess.open(PATH, FileAccess.READ)
	return "" if f == null else f.get_as_text()

func event_count() -> int:
	var txt := read_all()
	if txt == "":
		return 0
	var n := 0
	for line in txt.split("\n"):
		if line.strip_edges() != "":
			n += 1
	return n

func clear_all() -> void:
	_close()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

## Masaüstünde dosya diyaloğundan seçilen yola kopyalar.
func export_to(dest: String) -> bool:
	var txt := read_all()
	if txt == "":
		return false
	var dst := FileAccess.open(dest, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_string(txt)
	dst.close()
	return true

## Tarayıcı (web) sürümünde JSONL'yi indirir — masaüstü dosya diyaloğu web'de çalışmaz.
func web_download() -> bool:
	if not OS.has_feature("web"):
		return false
	var txt := read_all()
	if txt == "":
		return false
	var js := """
	(function(t){
		var b = new Blob([t], {type:'application/x-ndjson;charset=utf-8;'});
		var u = URL.createObjectURL(b);
		var a = document.createElement('a');
		a.href = u; a.download = 'events_log.jsonl';
		document.body.appendChild(a); a.click();
		setTimeout(function(){ URL.revokeObjectURL(u); a.remove(); }, 100);
	})(%s);
	""" % JSON.stringify(txt)
	JavaScriptBridge.eval(js, true)
	return true
