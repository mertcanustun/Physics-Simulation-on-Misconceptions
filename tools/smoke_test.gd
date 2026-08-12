extends SceneTree
## Başsız (headless) duman testi: gerçek arayüz akışını sürer ve
## loglamanın kullanıcı seçimlerini DOĞRU kaydettiğini doğrular.
##   godot --headless --path . --script tools/smoke_test.gd

const CODE := "L-0-NN-N-E-115"

func _init() -> void:
	var fails := 0

	# temiz başlangıç
	if FileAccess.file_exists(DataLog.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DataLog.PATH))

	# --- 1. Veri toplama KAPALIYKEN kayıt olmamalı (deneme modu) ---
	Session.deactivate(CODE)
	# --script modunda autoload'lar kurulmaz: Telemetry ve Strings'i elle ekle
	var tele = load("res://scripts/Telemetry.gd").new()
	tele.name = "Telemetry"
	root.add_child(tele)
	var strs = load("res://scripts/Strings.gd").new()
	strs.name = "Strings"
	root.add_child(strs)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame          # _ready() çalışsın (arayüz kodla kuruluyor)
	main.code_edit.text = CODE
	main._on_continue()
	main._on_intro_done()
	main.cb_gravity.button_pressed = true
	main.cb_air.button_pressed = true
	main._on_run()
	if DataLog.row_count() != 0:
		print("FAIL: deneme modunda kayıt yapıldı (%d satır)" % DataLog.row_count()); fails += 1
	else:
		print("OK  : deneme modunda hiç kayıt yok")

	# --- 2. Yönetici veri toplamayı açınca kayıt yapılmalı ---
	Session.activate(CODE)
	main._on_change_answer()
	main.cb_gravity.button_pressed = true
	main.cb_kick.button_pressed = false
	main.cb_air.button_pressed = true
	main.kick_force = 13.0
	main.v0 = 28.0
	main.angle = 40.0
	main._on_run()

	var txt := DataLog.read_all()
	var lines := txt.strip_edges().split("\n")
	if lines.size() < 2:
		print("FAIL: kayıt satırı yazılmadı"); fails += 1
	else:
		var hdr: PackedStringArray = lines[0].split(",")
		var row: PackedStringArray = lines[lines.size() - 1].split(",")
		print("SATIR: ", lines[lines.size() - 1])
		var got := {}
		for i in range(mini(hdr.size(), row.size())):
			got[hdr[i]] = row[i]
		# kullanıcının yaptığı her seçim doğru kaydedilmiş mi?
		var expect := {
			"participant_code": CODE,
			"gravity": "true",
			"kick_force_sel": "false",
			"air_resistance": "true",
			"kick_force_mag": "13.0",
			"v0_mps": "28.0",
			"angle_deg": "40.0",
			"correct": "true",
			"session_mode": "official",
		}
		for k in expect:
			if not got.has(k):
				print("FAIL: '%s' sütunu yok" % k); fails += 1
			elif got[k] != expect[k]:
				print("FAIL: %s = '%s' (beklenen '%s')" % [k, got[k], expect[k]]); fails += 1
		if fails == 0:
			print("OK  : tüm seçimler doğru kaydedildi (kuvvetler, F, hız, açı)")
		# kategori ve iniş mesafesi de yazılıyor mu
		if got.get("category", "") == "":
			print("FAIL: yanılgı kategorisi boş"); fails += 1
		else:
			print("OK  : kategori = %s" % got["category"])
		if got.get("landing_x_m", "") == "":
			print("FAIL: iniş mesafesi boş"); fails += 1
		else:
			print("OK  : iniş = %s m, gol = %s" % [got["landing_x_m"], got.get("goal", "?")])

	# --- 3. Yanlış seçim (vuruş kuvveti yanılgısı) doğru etiketlenmeli ---
	main._on_change_answer()
	main.cb_gravity.button_pressed = true
	main.cb_kick.button_pressed = true
	main.cb_air.button_pressed = false
	main._on_run()
	var l2 := DataLog.read_all().strip_edges().split("\n")
	var r2: PackedStringArray = l2[l2.size() - 1].split(",")
	if r2[13] != "false":   # sütun 13 = "correct" (friction_level kaldırıldıktan sonraki şema)
		print("FAIL: yanılgılı cevap 'doğru' işaretlendi"); fails += 1
	else:
		print("OK  : yanılgılı cevap correct=false olarak kaydedildi")
	if DataLog.row_count() != 2:
		print("FAIL: satır sayısı %d (beklenen 2)" % DataLog.row_count()); fails += 1
	else:
		print("OK  : toplam 2 resmi kayıt")

	# --- 4. Yönetici durdurunca tekrar kayıt olmamalı ---
	Session.deactivate(CODE)
	main._on_change_answer()
	main._on_run()
	if DataLog.row_count() != 2:
		print("FAIL: durdurulduktan sonra kayıt eklendi"); fails += 1
	else:
		print("OK  : durdurulduktan sonra kayıt eklenmiyor")

	# --- 5. TELEMETRİ: resmi modda olay yazılmalı, deneme modunda yazılmamalı ---
	tele.clear_all()
	Session.deactivate(CODE)
	main._show_entry()
	main.code_edit.text = CODE
	main._on_continue()          # official=false -> session_begin YAZILMAMALI
	main._on_intro_done()
	main.cb_gravity.button_pressed = true
	main.cb_gravity.toggled.emit(true)
	main._on_run()
	if tele.event_count() != 0:
		print("FAIL: deneme modunda %d telemetri olayı yazıldı" % tele.event_count()); fails += 1
	else:
		print("OK  : deneme modunda telemetri yazılmıyor")
	Session.activate(CODE)
	main._show_entry()
	main.code_edit.text = CODE
	main._on_continue()          # official=true
	main._on_intro_done()
	main.cb_air.button_pressed = true
	main.cb_air.toggled.emit(true)
	main._on_run()
	var tele_txt: String = tele.read_all()
	var types := {}
	for line in tele_txt.split("\n"):
		if line.strip_edges() == "":
			continue
		var d = JSON.parse_string(line)
		if d is Dictionary:
			types[d.get("type", "?")] = int(types.get(d.get("type", "?"), 0)) + 1
	print("OLAY TÜRLERİ: ", types)
	for must in ["session_begin", "decision_start", "option_toggle", "answer_submit"]:
		if not types.has(must):
			print("FAIL: '%s' olayı kaydedilmedi" % must); fails += 1
	if fails == 0:
		print("OK  : telemetri olay akışı tam (resmi modda)")

	print("\n=== SONUÇ: %s ===" % ("TÜM TESTLER GEÇTİ" if fails == 0 else "%d HATA" % fails))
	quit(0 if fails == 0 else 1)
