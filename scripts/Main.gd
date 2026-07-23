extends Control
## Kicked-Ball Simulation — kavram yanılgısı simülasyonu (Simülasyon 1)
## Giriş akışı web test sistemiyle aynı mantık:
##  - Tek "Kod" alanı: katılımcı kodu VEYA yönetici kodu.
##  - Yönetici → panel: kod ara, veri toplamayı başlat/durdur.
##  - Katılımcı → kod kütüphanede olmalı; veri toplama aktifse kayıt yapılır,
##    değilse simülasyon "deneme modu"nda çalışır ve hiçbir şey kaydedilmez.

const GREEN := Color("15803d")
const DARK := Color("1f2937")
const MUTED := Color("64748b")
const RED := Color("b91c1c")

var participant_code := ""
var group := ""
var attempt := 0
var official := false
var v0 := 30.0   # doğru cevap (yerçekimi+hava) bu hızda topu kaleye sokar
var angle := 45.0
var friction_level := 1   # 0=Az, 1=Orta, 2=Fazla (Orta = doğru senaryo)
var kick_force := 6.0     # vuruş kuvveti F büyüklüğü (yanılgı; kullanıcı ayarlar)

var field: FieldView
var entry_center: CenterContainer
var code_edit: LineEdit
var group_lbl: Label
var err_lbl: Label
var admin_center: CenterContainer
var admin_search: LineEdit
var admin_status: Label
var btn_activate: Button
var btn_stop: Button
var kick_panel: PanelContainer
var mode_banner: Label
var cb_gravity: CheckBox
var cb_kick: CheckBox
var cb_air: CheckBox
var kick_box: VBoxContainer
var friction_box: HBoxContainer
var friction_btns: Array = []
var settings_box: VBoxContainer
var feedback_panel: PanelContainer
var fb_title: Label
var fb_text: Label
var header_sub: Label
var speed_lbl: Label
var save_dialog: FileDialog

func _ready() -> void:
	_build_header()
	_build_field()
	_build_entry_panel()
	_build_admin_panel()
	_build_kick_panel()
	_build_feedback_panel()
	_build_save_dialog()
	_show_entry()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

# ---------------------------------------------------------------- UI builders

func _panel_style(radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.shadow_size = 12
	sb.set_content_margin_all(22)
	return sb

func _build_header() -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = Color("e2e8f0")
	sb.border_width_bottom = 1
	sb.set_content_margin_all(12)
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	bar.add_child(h)
	var t := Label.new()
	t.text = "Kicked-Ball Simulation"
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", DARK)
	h.add_child(t)
	header_sub = Label.new()
	header_sub.add_theme_color_override("font_color", MUTED)
	h.add_child(header_sub)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	speed_lbl = Label.new()
	speed_lbl.add_theme_font_size_override("font_size", 16)
	speed_lbl.add_theme_color_override("font_color", GREEN)
	h.add_child(speed_lbl)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.x = 14
	h.add_child(spacer2)
	var status := LinkButton.new()
	status.text = "veri durumu"
	status.pressed.connect(_on_data_status)
	h.add_child(status)
	var exp := LinkButton.new()
	exp.text = "CSV dışa aktar"
	exp.pressed.connect(func(): save_dialog.popup_centered(Vector2i(720, 480)))
	h.add_child(exp)

func _build_field() -> void:
	field = FieldView.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.offset_top = 52
	field.flight_finished.connect(_on_flight_finished)
	field.speed_report.connect(_on_speed_report)
	add_child(field)
	move_child(field, 0)
	var bg := ColorRect.new()
	bg.color = Color("eef4fa")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

func _build_entry_panel() -> void:
	entry_center = CenterContainer.new()
	entry_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(entry_center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(460, 0)
	entry_center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_label("Kicked-Ball Simulation", 24, DARK))
	v.add_child(_label("Kuvvet ve Hareket · kavramsal değişim prototipi (Simülasyon 1)", 13, MUTED))
	v.add_child(_spacer(10))
	v.add_child(_label("Kod", 15, DARK))
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "Katılım kodu veya yönetici kodu"
	code_edit.text_changed.connect(_on_code_changed)
	code_edit.text_submitted.connect(func(_t): _on_continue())
	v.add_child(code_edit)
	v.add_child(_label("Yalnızca anonim kod. İsim kaydedilmez.", 12, MUTED))
	v.add_child(_spacer(6))
	group_lbl = _label("Grup: —", 14, MUTED)
	v.add_child(group_lbl)
	err_lbl = _label("", 12, RED)
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err_lbl.custom_minimum_size.x = 400
	v.add_child(err_lbl)
	v.add_child(_spacer(8))
	var btn := _green_button("Devam Et")
	btn.pressed.connect(_on_continue)
	v.add_child(btn)

func _build_admin_panel() -> void:
	admin_center = CenterContainer.new()
	admin_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(admin_center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(520, 0)
	admin_center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_label("Yönetici Paneli", 22, DARK))
	v.add_child(_label("Katılımcı kodunu ara, veri toplamayı başlat/durdur.", 13, MUTED))
	v.add_child(_spacer(8))
	admin_search = LineEdit.new()
	admin_search.placeholder_text = "örn. L-0-NN-N-E-428"
	admin_search.text_changed.connect(_on_admin_search)
	v.add_child(admin_search)
	admin_status = _label("", 14, MUTED)
	admin_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	admin_status.custom_minimum_size.x = 460
	v.add_child(admin_status)
	v.add_child(_spacer(6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	btn_activate = _green_button("Veri toplamayı başlat")
	btn_activate.disabled = true
	btn_activate.pressed.connect(_on_admin_activate)
	h.add_child(btn_activate)
	btn_stop = Button.new()
	btn_stop.text = "Durdur"
	btn_stop.custom_minimum_size = Vector2(120, 44)
	btn_stop.disabled = true
	btn_stop.pressed.connect(_on_admin_stop)
	h.add_child(btn_stop)
	v.add_child(_spacer(6))
	var back := Button.new()
	back.text = "Giriş ekranına dön"
	back.flat = true
	back.pressed.connect(_show_entry)
	v.add_child(back)

func _build_kick_panel() -> void:
	kick_panel = PanelContainer.new()
	kick_panel.add_theme_stylebox_override("panel", _panel_style())
	kick_panel.position = Vector2(28, 90)
	kick_panel.custom_minimum_size = Vector2(340, 0)
	add_child(kick_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	kick_panel.add_child(v)
	v.add_child(_label("Vuruştan önce", 19, DARK))
	mode_banner = _label("", 12, Color("c2660a"))
	v.add_child(mode_banner)
	var q := _label("Oyuncu topa vurmak üzere. Top havada uçarken topa hangi kuvvetler etki eder? Sence geçerli olanların tümünü işaretle.", 13, Color("475569"))
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size.x = 300
	v.add_child(q)
	v.add_child(_spacer(4))
	cb_gravity = _force_box(v, "Yerçekimi", "topu aşağı çeker")
	cb_kick = _force_box(v, "Vuruş kuvveti F", "temas bittikten sonra da itmeye devam eder")

	# Vuruş kuvveti büyüklüğü — yalnızca vuruş kuvveti seçiliyken görünür
	kick_box = VBoxContainer.new()
	kick_box.visible = false
	kick_box.add_theme_constant_override("separation", 2)
	var kf_lbl := _label("Vuruş kuvveti F: %d" % int(kick_force), 13, MUTED)
	kick_box.add_child(kf_lbl)
	var kf_slider := HSlider.new()
	kf_slider.min_value = 2
	kf_slider.max_value = 20
	kf_slider.value = kick_force
	kf_slider.value_changed.connect(func(val): kick_force = val; kf_lbl.text = "Vuruş kuvveti F: %d" % int(val); _update_preview())
	kick_box.add_child(kf_slider)
	v.add_child(kick_box)

	cb_air = _force_box(v, "Hava direnci", "topu yavaşlatır")

	# Sürtünme şiddeti — yalnızca hava direnci seçiliyken görünür
	friction_box = HBoxContainer.new()
	friction_box.add_theme_constant_override("separation", 6)
	friction_box.visible = false
	var fl := _label("Sürtünme:", 13, MUTED)
	friction_box.add_child(fl)
	for i in range(3):
		var b := Button.new()
		b.text = ["Az", "Orta", "Fazla"][i]
		b.toggle_mode = true
		b.button_pressed = (i == friction_level)
		b.custom_minimum_size = Vector2(56, 30)
		var idx := i
		b.pressed.connect(func(): _set_friction(idx))
		friction_btns.append(b)
		friction_box.add_child(b)
	v.add_child(friction_box)

	# kuvvet seçimleri değişince önizleme oklarını güncelle
	cb_gravity.toggled.connect(func(_p): _update_preview())
	cb_kick.toggled.connect(func(on):
		kick_box.visible = on
		_update_preview())
	cb_air.toggled.connect(func(on):
		friction_box.visible = on
		_update_preview())

	v.add_child(_spacer(4))
	var st := Button.new()
	st.text = "▸ Senaryo ayarları"
	st.flat = true
	st.alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(st)
	settings_box = VBoxContainer.new()
	settings_box.visible = false
	v.add_child(settings_box)
	st.pressed.connect(func():
		settings_box.visible = not settings_box.visible
		st.text = ("▾ Senaryo ayarları" if settings_box.visible else "▸ Senaryo ayarları"))
	var v0_lbl := _label("Vuruş hızı: %d m/s" % int(v0), 13, MUTED)
	settings_box.add_child(v0_lbl)
	var v0_slider := HSlider.new()
	v0_slider.min_value = 12; v0_slider.max_value = 36; v0_slider.value = v0
	v0_slider.value_changed.connect(func(val): v0 = val; v0_lbl.text = "Vuruş hızı: %d m/s" % int(val); _update_preview())
	settings_box.add_child(v0_slider)
	var ang_lbl := _label("Vuruş açısı: %d°" % int(angle), 13, MUTED)
	settings_box.add_child(ang_lbl)
	var ang_slider := HSlider.new()
	ang_slider.min_value = 15; ang_slider.max_value = 75; ang_slider.value = angle
	ang_slider.value_changed.connect(func(val): angle = val; ang_lbl.text = "Vuruş açısı: %d°" % int(val); _update_preview())
	settings_box.add_child(ang_slider)
	v.add_child(_spacer(6))
	var run := _green_button("Ne olacağını gör  →")
	run.pressed.connect(_on_run)
	v.add_child(run)

func _force_box(parent: VBoxContainer, title: String, sub: String) -> CheckBox:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f1f5f9")
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pc.add_child(h)
	var cb := CheckBox.new()
	h.add_child(cb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(_label(title, 15, DARK))
	v.add_child(_label(sub, 12, MUTED))
	pc.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cb.button_pressed = not cb.button_pressed)
	return cb

func _build_feedback_panel() -> void:
	feedback_panel = PanelContainer.new()
	feedback_panel.add_theme_stylebox_override("panel", _panel_style())
	feedback_panel.custom_minimum_size = Vector2(380, 0)
	feedback_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	feedback_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	feedback_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	feedback_panel.offset_right = -24
	feedback_panel.offset_bottom = -24
	add_child(feedback_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	feedback_panel.add_child(v)
	v.add_child(_label("GERÇEK YÖRÜNGEYLE KARŞILAŞTIR", 11, Color("c2660a")))
	fb_title = _label("", 19, DARK)
	v.add_child(fb_title)
	fb_text = _label("", 13, Color("475569"))
	fb_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fb_text.custom_minimum_size.x = 340
	v.add_child(fb_text)
	v.add_child(_spacer(6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var replay := Button.new()
	replay.text = "Tekrar oynat"
	replay.custom_minimum_size = Vector2(120, 42)
	replay.pressed.connect(_on_replay)
	h.add_child(replay)
	var change := _green_button("Cevabımı değiştir")
	change.pressed.connect(_on_change_answer)
	h.add_child(change)

func _build_save_dialog() -> void:
	save_dialog = FileDialog.new()
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.current_file = "kicked_ball_data.csv"
	save_dialog.filters = PackedStringArray(["*.csv ; CSV dosyaları"])
	save_dialog.file_selected.connect(func(p):
		var ok := DataLog.export_to(p)
		_toast("%d satır dışa aktarıldı" % DataLog.row_count() if ok else "Henüz kayıtlı veri yok"))
	add_child(save_dialog)

# ---------------------------------------------------------------- helpers

func _label(txt: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c

func _green_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(150, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GREEN
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate(); sbh.bg_color = Color("166534")
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	var sbd := sb.duplicate(); sbd.bg_color = Color("94a3b8")
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color.WHITE)
	return b

func _toast(msg: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = msg
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)

# ---------------------------------------------------------------- flow

func _show_entry() -> void:
	entry_center.visible = true
	admin_center.visible = false
	kick_panel.visible = false
	feedback_panel.visible = false
	field.visible = false
	header_sub.text = ""
	if speed_lbl:
		speed_lbl.text = ""
	code_edit.text = ""
	group_lbl.text = "Grup: —"
	err_lbl.text = ""

func _on_code_changed(txt: String) -> void:
	var c := txt.strip_edges().to_upper()
	err_lbl.text = ""
	if Session.is_admin(c):
		group_lbl.text = "Yönetici kodu"
	elif Codes.is_well_formed(c):
		group_lbl.text = "Grup: " + Codes.group_label(c)
		if not Codes.in_library(c):
			err_lbl.text = "Kod kütüphanede bulunamadı."
	else:
		group_lbl.text = "Grup: —"

func _on_continue() -> void:
	var c := code_edit.text.strip_edges().to_upper()
	if Session.is_admin(c):
		admin_search.text = ""
		admin_status.text = ""
		btn_activate.disabled = true
		btn_stop.disabled = true
		entry_center.visible = false
		admin_center.visible = true
		return
	if not Codes.is_well_formed(c):
		err_lbl.text = "Geçerli bir kod girin, örn. L-3-MF-B-K-123"
		return
	if not Codes.in_library(c):
		err_lbl.text = "Kod kütüphanede bulunamadı."
		return
	participant_code = c
	group = Codes.group_label(c)
	official = Session.is_active(c)
	attempt = 0
	var mode_txt := "VERİ TOPLANIYOR" if official else "DENEME MODU — veri kaydedilmiyor"
	header_sub.text = "%s · %s · %s" % [participant_code, Codes.short_group(c), mode_txt]
	mode_banner.text = mode_txt
	mode_banner.add_theme_color_override("font_color", GREEN if official else Color("c2660a"))
	entry_center.visible = false
	field.visible = true
	field.reset()
	kick_panel.visible = true
	feedback_panel.visible = false
	_update_preview()

# ------------------------------------------------------------ kuvvet önizleme

func _set_friction(idx: int) -> void:
	friction_level = idx
	for i in range(friction_btns.size()):
		friction_btns[i].button_pressed = (i == idx)
	_update_preview()

func _on_speed_report(sp: float, steady: bool) -> void:
	if steady:
		speed_lbl.text = "Hız: %d m/s (sabit)" % int(round(sp))
	else:
		speed_lbl.text = "Hız: %d m/s" % int(round(sp))

func _update_preview() -> void:
	# yalnızca karar aşamasında (kick paneli görünürken) önizleme çiz
	if kick_panel == null or not kick_panel.visible:
		return
	if speed_lbl:
		speed_lbl.text = ""   # karar aşamasında hız gösterme
	field.set_preview(cb_gravity.button_pressed, cb_kick.button_pressed,
		cb_air.button_pressed, v0, angle, Physics.drag_for_level(friction_level), kick_force)

# ------------------------------------------------------------ admin actions

func _on_admin_search(txt: String) -> void:
	var c := txt.strip_edges().to_upper()
	btn_activate.disabled = true
	btn_stop.disabled = true
	if not Codes.is_well_formed(c):
		admin_status.text = ""
		return
	if not Codes.in_library(c):
		admin_status.text = "Kod kütüphanede yok."
		return
	var st := Session.status(c)
	var parts := PackedStringArray()
	parts.append(Codes.group_label(c))
	if st.get("active", false):
		parts.append("Veri toplama: AKTİF")
		btn_stop.disabled = false
	else:
		parts.append("Veri toplama: kapalı" + (" (daha önce tamamlandı)" if st.get("completed", false) else ""))
		btn_activate.disabled = false
	parts.append("Kayıtlı resmi deneme: %d" % int(st.get("attempts", 0)))
	admin_status.text = " · ".join(parts)

func _on_admin_activate() -> void:
	Session.activate(admin_search.text.strip_edges().to_upper())
	_on_admin_search(admin_search.text)

func _on_admin_stop() -> void:
	Session.deactivate(admin_search.text.strip_edges().to_upper())
	_on_admin_search(admin_search.text)

# ------------------------------------------------------------ sim actions

func _on_run() -> void:
	attempt += 1
	var g := cb_gravity.button_pressed
	var k := cb_kick.button_pressed
	var a := cb_air.button_pressed
	var dk := Physics.drag_for_level(friction_level)
	var pred := Physics.simulate(v0, angle, g, k, a, dk, kick_force)
	var real := Physics.real_path(v0, angle, dk)
	var correct := g and a and not k
	# only record while an admin has this code's data collection active
	official = Session.is_active(participant_code)
	if official:
		DataLog.log_attempt(participant_code, group, Codes.has_seen_topic(participant_code),
			"official", attempt, g, k, a, correct, v0, angle)
		Session.count_attempt(participant_code)
	kick_panel.visible = false
	feedback_panel.visible = false
	field.set_forces(g, k, a, dk, kick_force)   # uçuş sırasında canlı kuvvet okları
	field.start_flight(pred, real)

func _on_flight_finished() -> void:
	var fb := _feedback(cb_gravity.button_pressed, cb_kick.button_pressed, cb_air.button_pressed)
	fb_title.text = fb[0]
	fb_text.text = fb[1]
	feedback_panel.visible = true

func _on_replay() -> void:
	feedback_panel.visible = false
	field.start_flight(field.predicted, field.real)

func _on_change_answer() -> void:
	feedback_panel.visible = false
	field.reset()
	kick_panel.visible = true
	_update_preview()

func _on_data_status() -> void:
	_toast("%d resmi deneme kayıtlı\nKayıt dosyası: %s" % [DataLog.row_count(),
		ProjectSettings.globalize_path(DataLog.PATH)])

# ---------------------------------------------------------------- feedback

func _feedback(g: bool, k: bool, a: bool) -> Array:
	if g and a and not k:
		return ["Yerçekimi + hava direnci",
			"Doğru! Top havadayken üzerine yalnızca yerçekimi ve hava direnci etki eder — yörüngen gerçek (kesikli) yörüngenin tam üstüne oturdu. Vuruş topu harekete geçirdi ama vuruş kuvveti, ayak toptan ayrıldığı an sona erdi."]
	if g and not k and not a:
		return ["Yalnızca yerçekimi",
			"İdeal vakum parabolü — şekli doğru, ama hava direncini dışarıda bıraktın; bu yüzden top gerçek (kesikli) yörüngeden belirgin biçimde daha uzağa ve daha hızlı gidiyor."]
	if g and k and a:
		return ["Yerçekimi + vuruş kuvveti + hava direnci",
			"İkisi doğru — yerçekimi ve hava direnci gerçekten etki eder. Ama vuruş kuvveti topla birlikte seyahat etmez: yalnızca temas sırasında etki eder. Onu itmeye devam ettirdiğin için top gerçek (kesikli) yörüngeyi aşıyor."]
	if g and k and not a:
		return ["Yerçekimi + vuruş kuvveti",
			"Vuruş kuvveti topla birlikte kalmaz. Kuvvet temas gerektirir — ayak toptan ayrıldığı an o itiş biter. Onu sürdürüp hava direncini de atınca top gerçek (kesikli) yörüngenin çok ötesine uçuyor."]
	if k and not g and not a:
		return ["Yalnızca vuruş kuvveti",
			"Yerçekimi olmadan topu aşağı çeken hiçbir şey yok — hızlanarak uzaklaşır ve asla yere inmez. Gerçek (kesikli) yörüngeyle karşılaştır: uçuşu kavise büken şey yerçekimidir."]
	if k and a and not g:
		return ["Vuruş kuvveti + hava direnci",
			"Yerçekimi olmadan top asla yere inmez — itiş ile sürtünme birbiriyle çekişirken düz bir çizgide kayıp gider. Gerçek (kesikli) yörüngedeki kavis yerçekiminin işidir."]
	if a and not g and not k:
		return ["Yalnızca hava direnci",
			"Sürtünme topu yalnızca hareket doğrultusunda yavaşlatır — aşağı çeken bir şey yok; bu yüzden düz bir çizgide süzülüp havada asılı kalıyor. Yerçekimi eksik."]
	return ["Hiç kuvvet yok",
		"Hiç kuvvet yoksa top fırlatma hızını sonsuza dek korur (Newton'un 1. yasası) ve asla yere inmez. Gerçek uçuşta hem yerçekimi hem hava direnci etki eder — kesikli yörüngeye bak."]
