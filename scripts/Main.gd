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
var v0 := Physics.FIXED_V0     # SABİT — kullanıcı değiştiremez
var angle := Physics.FIXED_ANGLE  # SABİT
var kick_force := Physics.IMPETUS_ACC   # SABİT (yanılgı kuvvetinin büyüklüğü)

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
var kick_center: CenterContainer
var intro_modal_center: CenterContainer
var q_intro: Label
var q_hint: Label
var q_run_btn: Button
var top_bar: PanelContainer
var hud_card: PanelContainer
var hud_speed: Label
var hud_choice: Label
var hud_vx: Label
var hud_vy: Label
var last_vx := -999.0
var result_center: CenterContainer
var result_badge: PanelContainer
var result_badge_lbl: Label
var result_title: Label
var result_sub: Label
var btn_start: Button
var header_sub: Label
var mode_banner: Label
var cb_gravity: CheckBox
var cb_kick: CheckBox
var cb_air: CheckBox
var kick_box: VBoxContainer
var control_bar: PanelContainer
var btn_replay: Button
var btn_change: Button
var btn_pause: Button
var btn_reset: Button
var sim_paused := false
var decision_started := 0.0   # soru gösterildiği an (karar süresi ölçümü)
var sfx_kick: AudioStreamPlayer
var sfx_goal: AudioStreamPlayer
var save_dialog: FileDialog
var events_dialog: FileDialog
@onready var Tele: Node = get_node("/root/Telemetry")

func _ready() -> void:
	_build_header()
	_build_field()
	_build_entry_panel()
	_build_admin_panel()
	_build_kick_panel()
	_build_intro_modal()
	_build_hud()
	_build_result_modal()
	_build_control_bar()
	_build_save_dialog()
	_show_entry()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		_export_events()                       # etkileşim (JSONL) verisini dışa aktar
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		_on_data_status()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		_export_csv()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

# ---------------------------------------------------------------- UI builders

## ============================ KOYU TEMA (dark UI) ============================
const BG := Color("0f1115")
const CARD := Color("1a1d24")
const CARD2 := Color("232833")
const TXT := Color("e8eaed")
const TXT_MUTED := Color("9aa3af")
const ACCENT := Color("22c55e")
const ACCENT_DK := Color("16a34a")
const DANGER := Color("ef4444")
const INFO := Color("3b82f6")

func _card_style(radius := 16, bg := CARD, border := Color(1, 1, 1, 0.07)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.set_content_margin_all(18)
	return sb

func _panel_style(radius := 16) -> StyleBoxFlat:
	return _card_style(radius)

func _btn_style(bg: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.0 else 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb

func _style_button(b: Button, bg: Color, fg: Color, border := Color(0, 0, 0, 0)) -> void:
	b.add_theme_stylebox_override("normal", _btn_style(bg, border))
	b.add_theme_stylebox_override("hover", _btn_style(bg.lightened(0.10), border))
	b.add_theme_stylebox_override("pressed", _btn_style(bg.darkened(0.15), border))
	b.add_theme_stylebox_override("focus", _btn_style(bg, border))
	b.add_theme_stylebox_override("disabled", _btn_style(bg.darkened(0.35), border))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))

## ---------------------------- ÜST ÇUBUK (koyu) ----------------------------
func _build_header() -> void:
	top_bar = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("14171d")
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.border_width_bottom = 1
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	top_bar.add_theme_stylebox_override("panel", sb)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(top_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	top_bar.add_child(h)
	h.add_child(_label("⚽  Kicked-Ball Simulation", 18, TXT))
	header_sub = _label("", 13, TXT_MUTED)
	h.add_child(header_sub)

## ------------------- SOL HUD: yörünge açıklaması + HIZ -------------------
func _build_hud() -> void:
	hud_card = PanelContainer.new()
	hud_card.add_theme_stylebox_override("panel", _card_style(14))
	hud_card.position = Vector2(24, 390)
	hud_card.custom_minimum_size = Vector2(206, 0)
	add_child(hud_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	hud_card.add_child(v)
	hud_choice = _label("Seçimin: —", 12, Color("cbd5e1"))
	hud_choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_choice.custom_minimum_size.x = 190
	v.add_child(hud_choice)
	v.add_child(_spacer(6))
	v.add_child(_label("YÖRÜNGELER", 11, Color(ACCENT, 0.85)))
	v.add_child(_label("—  senin tahminin", 12, Color("6ee7a8")))
	v.add_child(_label("···  gerçek yol (hayalet)", 12, Color("cbd5e1")))
	v.add_child(_spacer(8))
	v.add_child(_label("TOPUN HIZI", 11, TXT_MUTED))
	hud_speed = _label("0.0 m/s", 30, ACCENT)
	v.add_child(hud_speed)
	hud_vx = _label("vx (yatay) 0.0 m/s", 13, Color("f59e0b"))
	v.add_child(hud_vx)
	hud_vy = _label("vy (dikey) 0.0 m/s", 13, Color("a855f7"))
	v.add_child(hud_vy)

func _on_speed_report(sp: float, vx: float, vy: float) -> void:
	if hud_speed:
		hud_speed.text = "%.1f m/s" % sp
	if hud_vx:
		# yatay hız: hava direnci yoksa DEĞİŞMEZ -> "sabit" etiketi bunu görünür kılar
		var steady := absf(vx - last_vx) < 0.05 and last_vx > -900.0
		hud_vx.text = "vx (yatay) %.1f m/s%s" % [vx, "   · sabit" if steady else ""]
		hud_vx.add_theme_color_override("font_color", ACCENT if steady else Color("f59e0b"))
		last_vx = vx
	if hud_vy:
		hud_vy.text = "vy (dikey) %.1f m/s" % (0.0 if absf(vy) < 0.05 else vy)
		hud_vy.add_theme_color_override("font_color", DANGER if absf(vy) < 1.2 else Color("a855f7"))

## ------------------- SORU KUTUSU (ortada, modal) -------------------
func _build_kick_panel() -> void:
	kick_center = CenterContainer.new()
	kick_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(kick_center)
	kick_panel = PanelContainer.new()
	kick_panel.add_theme_stylebox_override("panel", _card_style(18))
	kick_panel.custom_minimum_size = Vector2(520, 0)
	kick_center.add_child(kick_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	kick_panel.add_child(v)
	v.add_child(_label("Top havada  🏃 ➡ ⚽", 24, TXT))
	mode_banner = _label("", 11, Color("f59e0b"))
	v.add_child(mode_banner)
	q_intro = _label("Az önce bir futbol oyuncusu topa vurdu; top şu anda havada.\n\nYAPMAN GEREKEN: Topa etki ettiğini düşündüğün kuvvetlerin HEPSİNİ işaretle, sonra aşağıdaki yeşil düğmeye bas. Top senin seçimine göre uçacak; kesikli çizgi ve soluk top ise gerçekte olanı gösterecek. Doğru seçersen top kaledeki hedefe düşer.", 14, TXT_MUTED)
	q_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_intro.custom_minimum_size.x = 480
	v.add_child(q_intro)
	q_hint = _label("SENİN SEÇİMİN", 11, Color(ACCENT, 0.9))
	q_hint.visible = false
	v.add_child(q_hint)
	v.add_child(_spacer(4))
	cb_gravity = _force_box(v, "Yerçekimi", "topu aşağı çeker")
	cb_kick = _force_box(v, "Vuruş kuvveti F", "temas bittikten sonra da itmeye devam eder")
	kick_box = VBoxContainer.new()
	kick_box.visible = false
	v.add_child(kick_box)
	cb_air = _force_box(v, "Hava direnci", "topu yavaşlatır")
	v.add_child(_spacer(8))
	q_run_btn = Button.new()
	q_run_btn.text = "Ne olacağını gör"
	q_run_btn.custom_minimum_size = Vector2(480, 46)
	_style_button(q_run_btn, ACCENT_DK, Color.WHITE)
	q_run_btn.pressed.connect(_on_run)
	v.add_child(q_run_btn)

## ------------------- "NASIL ÇALIŞIR?" GİRİŞ POPUP'I (simülasyon başlamadan önce) -------------------
## Futbolcu koşup gelmeden, hatta saha görünür olmadan HEMEN önce çıkar; "Devam
## Et"e basılınca koşu-vuruş girişi (field.start_intro) başlar.
func _build_intro_modal() -> void:
	intro_modal_center = CenterContainer.new()
	intro_modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_modal_center.visible = false
	add_child(intro_modal_center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(18))
	panel.custom_minimum_size = Vector2(520, 0)
	intro_modal_center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label("ℹ  Nasıl çalışır?", 22, TXT))
	var body := _label(
		"Birazdan başlayacak olan simülasyonda, bir futbolcunun topa vuruş anını izleyeceksiniz. Vuruş gerçekleştikten hemen sonra simülasyon duraklatılacak ve karşınıza şu soru çıkacaktır: \"Topa hangi kuvvetler etki etmektedir?\" Lütfen topa etki ettiğini düşündüğünüz kuvvetleri işaretleyiniz. Ardından, yaptığınız kuvvet seçimlerinin topun hareketini nasıl etkilediğini ekranda gözlemleyiniz.\n\nSimülasyon esnasında meydana gelen hız değişimlerini ve oluşan yörüngelerin (path) hangileri olduğunu soldaki panelden takip edebilirsiniz. Ayrıca, simülasyonu çalıştırdıktan sonra daha detaylı bir inceleme yapmak isterseniz alt kısımdaki kontrolleri kullanarak simülasyonu dilediğiniz yerde durdurabilir, tekrar oynatabilir veya sistemi sıfırlayarak soru ekranına geri dönebilirsiniz.\n\nBaşlamak için hazır olduğunuzda \"Devam Et\" butonuna tıklayınız.",
		14, TXT_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 480
	v.add_child(body)
	v.add_child(_spacer(4))
	var btn := Button.new()
	btn.text = "Devam Et"
	btn.custom_minimum_size = Vector2(480, 46)
	_style_button(btn, ACCENT_DK, Color.WHITE)
	btn.pressed.connect(_on_intro_modal_continue)
	v.add_child(btn)

func _on_intro_modal_continue() -> void:
	intro_modal_center.visible = false
	control_bar.visible = true
	# önce koşu-vuruş girişi; ayak topa değince (_on_intro_done) soru gösterilir
	field.start_intro()

func _force_box(parent: VBoxContainer, title: String, sub: String) -> CheckBox:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD2
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	sb.border_color = Color(1, 1, 1, 0.05)
	sb.set_border_width_all(1)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	var cb := CheckBox.new()
	cb.add_theme_color_override("font_color", TXT)
	h.add_child(cb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	v.add_child(_label(title, 15, TXT))
	v.add_child(_label(sub, 12, TXT_MUTED))
	# hover kutunun tamamı için tek parça olsun: iç kontrolleri mouse'a kapat,
	# yalnızca pc mouse alsın → checkbox/label üstünde enter/leave titremesi olmaz
	for ch in pc.find_children("*", "Control", true, false):
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# telemetri: kutuya mouse girme/çıkma (ilk yaklaşılan seçenek + dwell) ve işaretleme
	pc.mouse_entered.connect(func(): Tele.option_hover(title, true))
	pc.mouse_exited.connect(func(): Tele.option_hover(title, false))
	pc.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cb.button_pressed = not cb.button_pressed
			cb.toggled.emit(cb.button_pressed))
	cb.toggled.connect(func(on):
		Tele.option_toggle(title, on)
		_update_preview())
	return cb

## ------------------- SONUÇ KUTUSU (GOL / KAÇTI) -------------------
func _build_result_modal() -> void:
	result_center = CenterContainer.new()
	result_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_center.visible = false
	add_child(result_center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(18))
	panel.custom_minimum_size = Vector2(520, 0)
	result_center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(badge_row)
	result_badge = PanelContainer.new()
	badge_row.add_child(result_badge)
	result_badge_lbl = _label("", 13, DANGER)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(DANGER, 0.15)
	bsb.set_corner_radius_all(999)
	bsb.content_margin_left = 16
	bsb.content_margin_right = 16
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 6
	result_badge.add_theme_stylebox_override("panel", bsb)
	result_badge.add_child(result_badge_lbl)
	result_title = _label("", 22, TXT)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(result_title)
	result_sub = _label("Simülasyon bitmiştir.", 13, TXT_MUTED)
	result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(result_sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	btn_replay = Button.new()
	btn_replay.text = "Tekrar dene"
	btn_replay.custom_minimum_size = Vector2(200, 46)
	_style_button(btn_replay, CARD2, TXT, Color(1, 1, 1, 0.10))
	btn_replay.pressed.connect(_on_replay)
	row.add_child(btn_replay)
	btn_change = Button.new()
	btn_change.text = "Yeni cevap dene"
	btn_change.custom_minimum_size = Vector2(220, 46)
	_style_button(btn_change, ACCENT_DK, Color.WHITE)
	btn_change.pressed.connect(_on_change_answer)
	row.add_child(btn_change)

## ------------------- ALT KONTROL ÇUBUĞU -------------------
func _build_control_bar() -> void:
	control_bar = PanelContainer.new()
	control_bar.add_theme_stylebox_override("panel", _card_style(16, Color("14171d")))
	control_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	control_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	control_bar.offset_bottom = -20
	add_child(control_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	control_bar.add_child(h)
	btn_start = Button.new()
	btn_start.text = "▶  Vuruşu başlat"
	btn_start.custom_minimum_size = Vector2(160, 40)
	_style_button(btn_start, ACCENT_DK, Color.WHITE)
	btn_start.pressed.connect(_on_run)
	h.add_child(btn_start)
	btn_pause = Button.new()
	btn_pause.text = "⏸  Durdur"
	btn_pause.custom_minimum_size = Vector2(120, 40)
	_style_button(btn_pause, CARD2, DANGER, Color(DANGER, 0.55))
	btn_pause.pressed.connect(_on_pause_toggle)
	h.add_child(btn_pause)
	btn_reset = Button.new()
	btn_reset.text = "↺  Sıfırla"
	btn_reset.custom_minimum_size = Vector2(120, 40)
	_style_button(btn_reset, CARD2, INFO, Color(INFO, 0.55))
	btn_reset.pressed.connect(_on_reset_sim)
	h.add_child(btn_reset)

## SORU PANELİ: seçim aşamasında ORTADA (büyük), atış başlayınca SOLA sabitlenir
## (kaybolmaz — öğrenci ne seçtiğini uçuş boyunca görebilir).
func _center_question() -> void:
	if kick_panel.get_parent() != kick_center:
		kick_panel.get_parent().remove_child(kick_panel)
		kick_center.add_child(kick_panel)
	kick_panel.custom_minimum_size = Vector2(520, 0)
	q_intro.visible = true
	q_run_btn.visible = true
	q_hint.visible = false
	_set_force_rows_enabled(true)
	kick_center.visible = true
	btn_start.visible = true
	btn_start.disabled = false
	_update_choice_summary()

## Atış başlayınca soru kutusu ("Top havada") ekrandan kalkar; öğrencinin
## seçimi kaybolmaz — sol HUD kartında özet satır olarak görünmeye devam eder.
func _reset_hud_values() -> void:
	last_vx = -999.0
	if hud_speed:
		hud_speed.text = "0.0 m/s"
	if hud_vx:
		hud_vx.text = "vx (yatay) 0.0 m/s"
		hud_vx.add_theme_color_override("font_color", Color("f59e0b"))
	if hud_vy:
		hud_vy.text = "vy (dikey) 0.0 m/s"
		hud_vy.add_theme_color_override("font_color", Color("a855f7"))

func _hide_question() -> void:
	kick_center.visible = false
	if kick_panel.get_parent() != kick_center:
		kick_panel.get_parent().remove_child(kick_panel)
		kick_center.add_child(kick_panel)
	kick_panel.custom_minimum_size = Vector2(520, 0)
	btn_start.visible = true
	btn_start.disabled = true          # uçuş sırasında atış yapılamaz
	_update_choice_summary()

func _update_choice_summary() -> void:
	if hud_choice == null:
		return
	var parts := PackedStringArray()
	if cb_gravity.button_pressed:
		parts.append("Yerçekimi")
	if cb_kick.button_pressed:
		parts.append("Vuruş kuvveti F")
	if cb_air.button_pressed:
		parts.append("Hava direnci")
	hud_choice.text = "Seçimin: " + (", ".join(parts) if parts.size() > 0 else "hiçbir kuvvet")

func _set_force_rows_enabled(on: bool) -> void:
	for cb in [cb_gravity, cb_kick, cb_air]:
		if cb:
			cb.disabled = not on

func _on_pause_toggle() -> void:
	sim_paused = not sim_paused
	field.set_paused(sim_paused)
	btn_pause.text = "▶  Devam et" if sim_paused else "⏸  Durdur"

func _on_reset_sim() -> void:
	sim_paused = false
	field.set_paused(false)
	btn_pause.text = "⏸  Durdur"
	result_center.visible = false
	field.reset()
	_reset_hud_values()
	Tele.decision_start(attempt + 1)
	_center_question()
	decision_started = Time.get_ticks_msec() / 1000.0
	_update_preview()

func _build_field() -> void:
	field = FieldView.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.offset_top = 52
	field.flight_finished.connect(_on_flight_finished)
	field.intro_done.connect(_on_intro_done)
	field.target_hit.connect(_on_goal_scored)
	field.speed_report.connect(_on_speed_report)   # HUD'daki hız değerlerini besler
	add_child(field)
	_build_audio()
	move_child(field, 0)
	var bg := ColorRect.new()
	bg.color = BG
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
	v.add_child(_label("⚽  Kicked-Ball Simulation", 26, TXT))
	v.add_child(_label("Kuvvet ve Hareket · kavramsal değişim prototipi (Simülasyon 1)", 13, TXT_MUTED))
	v.add_child(_spacer(10))
	v.add_child(_label("Kod", 15, TXT))
	code_edit = LineEdit.new()
	code_edit.add_theme_color_override("font_color", TXT)
	code_edit.add_theme_stylebox_override("normal", _btn_style(CARD2, Color(1,1,1,0.10)))
	code_edit.add_theme_stylebox_override("focus", _btn_style(CARD2, Color(ACCENT,0.6)))
	code_edit.placeholder_text = "Katılım kodu veya yönetici kodu"
	code_edit.text_changed.connect(_on_code_changed)
	code_edit.text_submitted.connect(func(_t): _on_continue())
	v.add_child(code_edit)
	v.add_child(_label("Yalnızca anonim kod. İsim kaydedilmez.", 12, TXT_MUTED))
	v.add_child(_spacer(6))
	group_lbl = _label("Grup: —", 14, TXT_MUTED)
	v.add_child(group_lbl)
	err_lbl = _label("", 12, RED)
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err_lbl.custom_minimum_size.x = 400
	v.add_child(err_lbl)
	v.add_child(_spacer(8))
	var btn := _dark_green_button("Devam Et")
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
	v.add_child(_label("Yönetici Paneli", 22, TXT))
	v.add_child(_label("Katılımcı kodunu ara, veri toplamayı başlat/durdur.", 13, TXT_MUTED))
	v.add_child(_spacer(8))
	admin_search = LineEdit.new()
	admin_search.add_theme_color_override("font_color", TXT)
	admin_search.add_theme_stylebox_override("normal", _btn_style(CARD2, Color(1,1,1,0.10)))
	admin_search.placeholder_text = "örn. L-0-NN-N-E-428"
	admin_search.text_changed.connect(_on_admin_search)
	v.add_child(admin_search)
	admin_status = _label("", 14, TXT_MUTED)
	admin_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	admin_status.custom_minimum_size.x = 460
	v.add_child(admin_status)
	v.add_child(_spacer(6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	btn_activate = _dark_green_button("Veri toplamayı başlat")
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
	# etkileşim (JSONL) verisi için ayrı dışa-aktarma diyaloğu (F8)
	events_dialog = FileDialog.new()
	events_dialog.access = FileDialog.ACCESS_FILESYSTEM
	events_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	events_dialog.current_file = "events_log.jsonl"
	events_dialog.filters = PackedStringArray(["*.jsonl ; JSON Lines"])
	events_dialog.file_selected.connect(func(p):
		var ok: bool = Tele.export_to(p)
		_toast("%d etkileşim olayı dışa aktarıldı" % int(Tele.event_count()) if ok else "Henüz etkileşim verisi yok"))
	add_child(events_dialog)

# ---------------------------------------------------------------- helpers

func _dark_green_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(150, 44)
	_style_button(b, ACCENT_DK, Color.WHITE)
	return b

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
	Tele.end_session()
	hud_card.visible = false
	result_center.visible = false
	top_bar.visible = false
	entry_center.visible = true
	admin_center.visible = false
	kick_center.visible = false
	intro_modal_center.visible = false
	control_bar.visible = false
	field.visible = false
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
	Tele.begin_session(participant_code, group, Codes.has_seen_topic(c), official)
	attempt = 0
	var mode_txt := "VERİ TOPLANIYOR" if official else "DENEME MODU — veri kaydedilmiyor"
	mode_banner.text = ""   # veri kaydı bilgisi öğrenciye gösterilmez (F9 ile görülür)
	mode_banner.add_theme_color_override("font_color", GREEN if official else Color("c2660a"))
	entry_center.visible = false
	field.visible = true
	btn_start.disabled = true      # giriş animasyonu bitmeden atış yok
	hud_card.visible = true
	top_bar.visible = true
	kick_center.visible = false
	control_bar.visible = false
	field.reset()   # önceki oturumdan kalan playing/finished bayraklarını temizle
	# saha görünür ama HENÜZ HİÇBİR ŞEY OYNAMIYOR: önce "nasıl çalışır" popup'ı
	# çıkar (alt kontrol çubuğu da onunla birlikte gelir), "Devam Et"e basılınca
	# koşu-vuruş girişi (field.start_intro) başlar
	intro_modal_center.visible = true

func _on_intro_done() -> void:
	btn_start.disabled = false
	if field.playing or field.finished:
		return   # uçuş bir şekilde başladıysa soru kutusunu ÜSTÜNE açma
	Tele.decision_start(attempt + 1)
	_center_question()
	decision_started = Time.get_ticks_msec() / 1000.0
	_update_preview()

# ------------------------------------------------------------ kuvvet önizleme

func _build_audio() -> void:
	sfx_kick = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/kick.mp3"):
		sfx_kick.stream = load("res://assets/audio/kick.mp3")
	add_child(sfx_kick)
	sfx_goal = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/applause.mp3"):
		sfx_goal.stream = load("res://assets/audio/applause.mp3")
	sfx_goal.volume_db = -3.0
	add_child(sfx_goal)

func _on_goal_scored() -> void:
	if sfx_goal and sfx_goal.stream:
		sfx_goal.play()

func _update_preview() -> void:
	_update_choice_summary()
	# yalnızca karar aşamasında (kick paneli görünürken) önizleme çiz
	if kick_panel == null or not kick_center.visible:
		return
	field.set_preview(cb_gravity.button_pressed, cb_kick.button_pressed,
		cb_air.button_pressed, Physics.DRAG_K, kick_force)

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
	var dk := Physics.DRAG_K
	var tx := field.target_x
	var pred := Physics.simulate(g, k, a, dk, kick_force, tx, FieldView.RING_BULLS)
	var real := Physics.real_path(tx, FieldView.RING_BULLS)
	var correct := g and a and not k
	var landing_x: float = pred["impact_x"]
	var is_goal := landing_x > 0.0 and absf(landing_x - field.target_x) <= FieldView.RING_BULLS
	var category: String = _feedback(g, k, a)[0]
	var decision_s := maxf(Time.get_ticks_msec() / 1000.0 - decision_started, 0.0)
	# yalnızca yönetici bu kod için veri toplamayı açtıysa kaydet
	official = Session.is_active(participant_code)
	Tele.set_official(official)
	Tele.answer_submit(g, k, a, correct, category)
	if official:
		DataLog.log_attempt(participant_code, group, Codes.has_seen_topic(participant_code),
			"official", attempt, g, k, a, kick_force, v0, angle,
			correct, category, is_goal, landing_x, decision_s)
		Session.count_attempt(participant_code)
	_hide_question()
	sim_paused = false
	btn_pause.text = "⏸  Durdur"
	field.set_paused(false)
	field.set_forces(g, k, a, dk, kick_force)   # uçuş sırasında canlı kuvvet okları
	if sfx_kick and sfx_kick.stream:
		sfx_kick.play()                          # topa vuruş sesi
	field.start_flight(pred, real)

func _on_flight_finished() -> void:
	var gol := field.hit_bulls
	result_badge_lbl.text = "GOL" if gol else "KAÇTI"
	result_badge_lbl.add_theme_color_override("font_color", ACCENT if gol else DANGER)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(ACCENT if gol else DANGER, 0.15)
	bsb.set_corner_radius_all(999)
	bsb.content_margin_left = 16
	bsb.content_margin_right = 16
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 6
	result_badge.add_theme_stylebox_override("panel", bsb)
	result_sub.text = "Simülasyon bitmiştir."
	if gol:
		result_title.text = "Top kaleye girdi!"
		result_sub.text = "Simülasyon bitmiştir · tam isabet"
	elif field.impact_x < 0.0:
		result_title.text = "Top hiç yere inmedi"
	elif field.impact_x < FieldView.GOAL_X:
		result_title.text = "Top kaleye ulaşamadı"
		result_sub.text = "Simülasyon bitmiştir · hedefin %.1f m önüne düştü" % (FieldView.GOAL_X - field.impact_x)
	else:
		result_title.text = "Top kaleyi aştı"
		result_sub.text = "Simülasyon bitmiştir · hedefi %.1f m geçti" % (field.impact_x - FieldView.GOAL_X)
	result_center.visible = true
	Tele.run_complete(gol, field.impact_x)

func _on_replay() -> void:
	Tele.replay()
	result_center.visible = false
	var dk := Physics.DRAG_K
	var tx := field.target_x
	field.start_flight(
		Physics.simulate(cb_gravity.button_pressed, cb_kick.button_pressed,
			cb_air.button_pressed, dk, kick_force, tx, FieldView.RING_BULLS),
		Physics.real_path(tx, FieldView.RING_BULLS))

func _on_change_answer() -> void:
	Tele.answer_change()
	result_center.visible = false
	field.reset()
	_reset_hud_values()
	Tele.decision_start(attempt + 1)
	_center_question()
	decision_started = Time.get_ticks_msec() / 1000.0
	_update_preview()

func _export_events() -> void:
	if OS.has_feature("web"):
		if not Tele.web_download():
			_toast("Henüz etkileşim verisi yok")
	else:
		events_dialog.popup_centered(Vector2i(720, 480))

func _export_csv() -> void:
	if OS.has_feature("web"):
		if not DataLog.web_download():
			_toast("Henüz kayıtlı veri yok")
	else:
		save_dialog.popup_centered(Vector2i(720, 480))

func _on_data_status() -> void:
	var where := "Tarayıcı deposu (IndexedDB)" if OS.has_feature("web") \
		else ProjectSettings.globalize_path(DataLog.PATH)
	var mode_now := "AKTİF" if (participant_code != "" and Session.is_active(participant_code)) else "kapalı"
	_toast("Kayıtlı resmi deneme: %d\nBu kod için veri toplama: %s\nKayıt yeri: %s\n\nSon kayıtlar:\n%s" % [
		DataLog.row_count(), mode_now, where, DataLog.tail(3)])

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
