extends SceneTree
## Bu değişiklik listesinin (madde 8, 10, 12, 16 + kontrast/arka plan ayarları)
## başsız doğrulaması. Çalıştırma:
##   godot --headless --path . --script tools/change_list_test.gd
##
## smoke_test.gd'nin YERİNE geçmez — o veri/loglama akışını, bu ise bu
## oturumda değişen davranışları test eder. İkisi de yeşilse değişiklik güvenli.

const CODE := "L-0-NN-N-E-115"

var fails := 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("OK  : %s" % msg)
	else:
		print("FAIL: %s" % msg)
		fails += 1

func _init() -> void:
	var cfg: SimConfig = Physics.cfg

	# ---------------- MADDE 8: oyun alanı sınırı gerçekten kesiyor mu ----------
	# Yerçekimi kapalı + vuruş açık: top asla inmez -> yörünge world_max sınırında
	# KESİLMELİ, "landed" false kalmalı ve son nokta sınırı çok aşmamalı.
	var never_lands := Physics.simulate(false, true, false, cfg.drag_k, cfg.impetus_acc)
	var last: Vector2 = never_lands["points"][-1]["p"]
	_ok(not never_lands["landed"], "yerçekimsiz senaryo: landed=false (top inmedi)")
	_ok(last.x <= cfg.world_max_x + 1.0 and last.y <= cfg.world_max_y + 1.0,
		"yörünge oyun alanında kesildi (son nokta %.1f, %.1f m)" % [last.x, last.y])
	_ok(never_lands["impact_x"] < 0.0, "inmeyen atışta impact_x < 0 (sonuç metni doğru dallanır)")

	# doğru cevap (yerçekimi + hava direnci) hâlâ sahada iniyor ve GOL oluyor
	var correct := Physics.real_path(Physics.target_x(), cfg.ring_bulls)
	_ok(correct["landed"], "doğru cevap: top yere iniyor")
	_ok(correct["impact_x"] > cfg.goal_x - 2.0 and correct["impact_x"] < cfg.world_max_x,
		"doğru cevap kaleye ulaşıyor (iniş %.1f m, kale %.1f m)" % [correct["impact_x"], cfg.goal_x])

	# ---------------- MADDE 10: rüzgâr sesi yuvası -----------------------------
	_ok(cfg.wind_sfx != null, "Inspector: Wind Sfx dolu")
	var strs = load("res://scripts/Strings.gd").new()
	strs.name = "Strings"
	root.add_child(strs)
	var tele = load("res://scripts/Telemetry.gd").new()
	tele.name = "Telemetry"
	root.add_child(tele)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var wind: AudioStreamPlayer = main.sfx_wind
	_ok(wind != null and wind.stream != null, "rüzgâr oynatıcısına akış atandı")
	if wind and wind.stream is AudioStreamWAV:
		var w: AudioStreamWAV = wind.stream
		_ok(w.loop_mode == AudioStreamWAV.LOOP_FORWARD, "rüzgâr WAV'ı döngüde")
		_ok(w.loop_end > 0, "döngü sonu hesaplandı (%d kare)" % w.loop_end)
		# paylaşılan kaynak DEĞİŞTİRİLMEMELİ (duplicate edildi mi)
		_ok(w != cfg.wind_sfx, "rüzgâr akışı kopyalandı — .tres'teki kaynak bozulmadı")

	# ---------------- MADDE 16: ses düğmesi iki yönlü mü ------------------------
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		bus = 0
	main._set_sound_enabled(true)
	var on_db := AudioServer.get_bus_volume_db(bus)
	_ok(not AudioServer.is_bus_mute(bus), "ses AÇIK: bus mute değil")
	main._on_mute_toggle()          # -> KAPAT
	_ok(AudioServer.is_bus_mute(bus), "1. tıklama sesi KAPATTI")
	_ok(main.btn_mute.text.contains("kapalı"), "düğme metni 'kapalı' oldu")
	main._on_mute_toggle()          # -> tekrar AÇ  (eski hatanın tam yeri)
	_ok(not AudioServer.is_bus_mute(bus), "2. tıklama sesi TEKRAR AÇTI")
	_ok(is_equal_approx(AudioServer.get_bus_volume_db(bus), on_db),
		"seviye açılıştaki değere döndü (%.1f dB)" % AudioServer.get_bus_volume_db(bus))
	_ok(main.btn_mute.text.contains("açık"), "düğme metni 'açık' oldu")
	# üçüncü ve dördüncü tıklama da çalışmalı (durum takılmıyor)
	main._on_mute_toggle()
	main._on_mute_toggle()
	_ok(not AudioServer.is_bus_mute(bus), "4 tıklamadan sonra ses hâlâ doğru durumda")

	# ---------------- MADDE 12: kamera zoom'u pompalamıyor ---------------------
	# Uçuşu elle ilerletip zoom'u örnekle: monoton mod açıkken zoom hiç ARTMAMALI
	# (yalnız uzaklaşır) ve kare başına değişim hız sınırını aşmamalı.
	var field: FieldView = main.field
	field.size = Vector2(1280, 668)
	main.cb_gravity.button_pressed = true
	main.cb_air.button_pressed = true
	main._on_run()
	await process_frame
	var prev_zoom := field.cam_zoom
	var worst_step := 0.0
	var increases := 0
	var dt := 1.0 / 60.0
	var steps := 0
	while field.playing and steps < 3000:
		field._process(dt)
		var d := field.cam_zoom - prev_zoom
		worst_step = maxf(worst_step, absf(d))
		if d > 0.0005:
			increases += 1
		prev_zoom = field.cam_zoom
		steps += 1
	_ok(increases == 0, "monoton kamera: uçuş boyunca hiç geri yakınlaşma yok (%d)" % increases)
	_ok(worst_step <= Physics.cfg.camera_max_zoom_rate * dt + 0.0001,
		"kare başına zoom değişimi sınırda (%.4f <= %.4f)" % [worst_step, Physics.cfg.camera_max_zoom_rate * dt])
	_ok(field.cam_zoom < Physics.cfg.camera_start_zoom, "kamera uçuş boyunca uzaklaştı")

	# MADDE 12'nin bildirilen tekrar-üretim senaryosu: ÜÇ KUVVET DE seçili.
	# (yerçekimi + vuruş F + hava direnci -> top yükselirken ilerliyor, eski kodda
	#  en sert "pompalama" burada görülüyordu)
	main._on_change_answer()
	main.cb_gravity.button_pressed = true
	main.cb_kick.button_pressed = true
	main.cb_air.button_pressed = true
	main._on_run()
	await process_frame
	prev_zoom = field.cam_zoom
	var worst3 := 0.0
	var inc3 := 0
	steps = 0
	while field.playing and steps < 3000:
		field._process(dt)
		var d3 := field.cam_zoom - prev_zoom
		worst3 = maxf(worst3, absf(d3))
		if d3 > 0.0005:
			inc3 += 1
		prev_zoom = field.cam_zoom
		steps += 1
	_ok(inc3 == 0, "üç kuvvet birlikte: zoom pompalaması yok (%d geri yakınlaşma)" % inc3)
	_ok(worst3 <= Physics.cfg.camera_max_zoom_rate * dt + 0.0001,
		"üç kuvvet birlikte: zoom hızı sınırda (%.4f)" % worst3)

	# ---------------- kontrast yardımcıları -----------------------------------
	var base := Color("2563eb")
	cfg.contrast = 1.0
	cfg.high_contrast = false
	_ok(cfg.adj(base) == base, "kontrast=1.0 iken renk HİÇ değişmiyor (varsayılan korunuyor)")
	cfg.contrast = 1.6
	_ok(cfg.adj(base).v > base.v, "kontrast artınca renk parlaklaşıyor")
	cfg.high_contrast = true
	_ok(cfg.adj_width(4.0) > 4.0, "yüksek kontrastta ok kalınlığı artıyor")
	cfg.contrast = 1.0
	cfg.high_contrast = false

	print("")
	if fails == 0:
		print("=== SONUÇ: TÜM TESTLER GEÇTİ ===")
	else:
		print("=== SONUÇ: %d TEST BAŞARISIZ ===" % fails)
	quit(0 if fails == 0 else 1)
