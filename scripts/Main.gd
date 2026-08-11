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
var v0 := Physics.cfg.v0          # SABİT — kullanıcı değiştiremez (Inspector'dan ayarlanır)
var angle := Physics.cfg.angle_deg  # SABİT


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
var intro_panel: PanelContainer
var admin_panel: PanelContainer
var entry_panel: PanelContainer
var result_panel: PanelContainer
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
var btn_mute: Button
var muted := false
var master_db := 0.0     # açılıştaki Master bus seviyesi — sesi geri açarken buraya dönülür
var sim_paused := false
var decision_started := 0.0   # soru gösterildiği an (karar süresi ölçümü)
var sfx_kick: AudioStreamPlayer
var sfx_goal: AudioStreamPlayer
var sfx_wind: AudioStreamPlayer
var save_dialog: FileDialog
var events_dialog: FileDialog
@onready var Tele: Node = get_node("/root/Telemetry")
@onready var S: StringsData = get_node("/root/Strings")   # KOD YAZMADAN düzenlenebilir metinler (bkz. Strings.gd)

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
	# başlangıç ses durumu: sim_config.tres -> Ses -> Sound Enabled
	var mbus := AudioServer.get_bus_index("Master")
	master_db = AudioServer.get_bus_volume_db(mbus if mbus >= 0 else 0)
	_set_sound_enabled(Physics.cfg.sound_enabled)
	_show_entry()
	_apply_responsive_layout()
	resized.connect(_apply_responsive_layout)

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

## Panel genişliği: geniş ekranda istenen ölçü, dar (mobil) ekranda ekrana sığar.
func _panel_w(want: float) -> float:
	return minf(want, maxf(size.x - 32.0, 240.0))

## Kart konumları/genişlikleri ekran boyutuna göre yeniden hesaplanır.
## Mobil (dar/dikey) ekranda: yan kartlar daralır, kontrol çubuğu küçülür.
func _apply_responsive_layout() -> void:
	var narrow := size.x < 900.0
	if hud_card:
		hud_card.custom_minimum_size.x = 206.0 if not narrow else clampf(size.x * 0.42, 150.0, 206.0)
		hud_card.position = Vector2(12 if narrow else 24, 62 if narrow else 78)
	for pnl in [kick_panel, result_panel, entry_panel, admin_panel, intro_panel]:
		if pnl:
			pnl.custom_minimum_size.x = _panel_w(520.0)
	if control_bar:
		control_bar.offset_bottom = -4
	if q_intro:
		q_intro.custom_minimum_size.x = _panel_w(520.0) - 40.0
	for b in [btn_start, btn_pause, btn_reset, btn_mute]:
		if b:
			b.custom_minimum_size.y = 44.0 if narrow else 40.0
	# MADDE 3 — ÇAKIŞMA: soru/sonuç kutuları ekranın TAM ortasına yerleşiyordu;
	# panel uzayınca (3 kuvvet satırı + açıklama) alt kontrol çubuğunun ÜSTÜNE
	# biniyordu. Artık ortalama alanı üstte başlık çubuğunun, altta kontrol
	# çubuğunun BİTTİĞİ yerden hesaplanıyor -> asla üst üste gelmezler.
	var bar_h := control_bar.size.y if control_bar else 0.0
	if bar_h <= 0.0:
		bar_h = 56.0
	for c in [kick_center, result_center, intro_modal_center]:
		if c:
			c.offset_top = 56.0
			c.offset_bottom = -(bar_h + 16.0)

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
	hud_card.position = Vector2(24, 78)   # eski "Nasıl çalışır?" kartının yeri
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
	v.add_child(_label("—  senin tahminin", 12, Physics.cfg.predicted_path_color))
	v.add_child(_label("···  gerçek yol (hayalet)", 12, Physics.cfg.real_path_color))
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
	kick_panel.custom_minimum_size = Vector2(_panel_w(520.0), 0)
	kick_center.add_child(kick_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	kick_panel.add_child(v)
	v.add_child(_label(S.t("KICK_PANEL_TITLE"), 24, TXT))
	mode_banner = _label("", 11, Color("f59e0b"))
	v.add_child(mode_banner)
	q_intro = _label(S.t("KICK_PANEL_INTRO"), 14, TXT_MUTED)
	q_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_intro.custom_minimum_size.x = 480
	v.add_child(q_intro)
	v.add_child(_spacer(2))
	var question_lbl := _label(S.t("KICK_PANEL_QUESTION"), 17, TXT)
	question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_lbl.custom_minimum_size.x = 480
	v.add_child(question_lbl)
	q_hint = _label("SENİN SEÇİMİN", 11, Color(ACCENT, 0.9))
	q_hint.visible = false
	v.add_child(q_hint)
	v.add_child(_spacer(4))
	cb_gravity = _force_box(v, "gravity", S.t("FORCE_GRAVITY_TITLE"), S.t("FORCE_GRAVITY_SUB"))
	cb_kick = _force_box(v, "kick", S.t("FORCE_KICK_TITLE"), S.t("FORCE_KICK_SUB"))
	kick_box = VBoxContainer.new()
	kick_box.visible = false
	v.add_child(kick_box)
	cb_air = _force_box(v, "air", S.t("FORCE_AIR_TITLE"), S.t("FORCE_AIR_SUB"))
	v.add_child(_spacer(8))
	q_run_btn = Button.new()
	q_run_btn.text = S.t("KICK_PANEL_RUN_BTN")
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
	intro_panel = panel
	panel.add_theme_stylebox_override("panel", _card_style(18))
	panel.custom_minimum_size = Vector2(520, 0)
	intro_modal_center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label(S.t("POPUP_INTRO_TITLE"), 22, TXT))
	var body := _label(S.t("POPUP_INTRO_BODY"), 14, TXT_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 480
	v.add_child(body)
	v.add_child(_spacer(4))
	var btn := Button.new()
	btn.text = S.t("POPUP_INTRO_BTN")
	btn.custom_minimum_size = Vector2(480, 46)
	_style_button(btn, ACCENT_DK, Color.WHITE)
	btn.pressed.connect(_on_intro_modal_continue)
	v.add_child(btn)

func _on_intro_modal_continue() -> void:
	intro_modal_center.visible = false
	control_bar.visible = true
	# önce koşu-vuruş girişi; ayak topa değince (_on_intro_done) soru gösterilir
	field.start_intro()

## key: TELEMETRİ/log için SABİT dahili ad (CSV metni değişse de bozulmaz).
## display_title/sub: ekranda görünen metin — res://localization/strings.csv'den gelir.
func _force_box(parent: VBoxContainer, key: String, display_title: String, sub: String) -> CheckBox:
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
	var title_lbl := _label(display_title, 15, TXT)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.custom_minimum_size.x = 420
	v.add_child(title_lbl)
	if sub.strip_edges() != "":
		v.add_child(_label(sub, 12, TXT_MUTED))
	# hover kutunun tamamı için tek parça olsun: iç kontrolleri mouse'a kapat,
	# yalnızca pc mouse alsın → checkbox/label üstünde enter/leave titremesi olmaz
	for ch in pc.find_children("*", "Control", true, false):
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# telemetri: kutuya mouse girme/çıkma (ilk yaklaşılan seçenek + dwell) ve işaretleme
	pc.mouse_entered.connect(func(): Tele.option_hover(key, true))
	pc.mouse_exited.connect(func(): Tele.option_hover(key, false))
	pc.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cb.button_pressed = not cb.button_pressed
			cb.toggled.emit(cb.button_pressed))
	cb.toggled.connect(func(on):
		Tele.option_toggle(key, on)
		_update_preview())
	return cb

## ------------------- SONUÇ KUTUSU (GOL / KAÇTI) -------------------
func _build_result_modal() -> void:
	result_center = CenterContainer.new()
	result_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_center.visible = false
	add_child(result_center)
	var panel := PanelContainer.new()
	result_panel = panel
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
	result_sub = _label(S.t("RESULT_DEFAULT_SUB"), 13, TXT_MUTED)
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
	control_bar.offset_bottom = -4   # soru/sonuç popup'larıyla çakışmasın diye biraz daha aşağı
	add_child(control_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	control_bar.add_child(h)
	# "Vuruşu başlat" KALDIRILDI — atışı başlatan tek yer soru kutusundaki
	# yeşil düğme (aynı işi yapan ikinci düğme kafa karıştırıyordu).
	# Yerine: TEKRAR = son atışı yeniden oynat (uçuş bittikten sonra aktif).
	# MADDE 3 — düğme metinleri: her düğme YAPTIĞI İŞİ söylüyor, tooltip'lerde
	# uzun açıklama var. "Vuruşu başlat" kaldırıldı (yukarıdaki nota bak) —
	# yerinde duran düğme son atışı YENİDEN OYNATIR, adı da bu yüzden "Tekrar".
	btn_start = Button.new()
	btn_start.text = "↻  Tekrar"
	btn_start.tooltip_text = "Son atışı baştan oynat (yeni cevap seçmez)"
	btn_start.custom_minimum_size = Vector2(0, 40)
	_style_button(btn_start, ACCENT_DK, Color.WHITE)
	btn_start.disabled = true
	btn_start.pressed.connect(_on_replay)
	h.add_child(btn_start)
	btn_pause = Button.new()
	btn_pause.text = "⏸  Durdur"
	btn_pause.tooltip_text = "Uçuşu dondur / kaldığı yerden devam ettir"
	btn_pause.custom_minimum_size = Vector2(0, 40)
	_style_button(btn_pause, CARD2, DANGER, Color(DANGER, 0.55))
	btn_pause.pressed.connect(_on_pause_toggle)
	h.add_child(btn_pause)
	btn_reset = Button.new()
	btn_reset.text = "↺  Sıfırla"
	btn_reset.tooltip_text = "Sahayı temizle ve soru ekranına dön"
	btn_reset.custom_minimum_size = Vector2(0, 40)
	_style_button(btn_reset, CARD2, INFO, Color(INFO, 0.55))
	btn_reset.pressed.connect(_on_reset_sim)
	h.add_child(btn_reset)
	# ---------- MADDE 11/16: SESLERİ AÇ/KAPAT ----------
	btn_mute = Button.new()
	btn_mute.custom_minimum_size = Vector2(0, 40)
	_style_button(btn_mute, CARD2, TXT, Color(1, 1, 1, 0.18))
	btn_mute.pressed.connect(_on_mute_toggle)
	h.add_child(btn_mute)

## SORU PANELİ: seçim aşamasında ORTADA (büyük), atış başlayınca SOLA sabitlenir
## (kaybolmaz — öğrenci ne seçtiğini uçuş boyunca görebilir).
func _center_question() -> void:
	if kick_panel.get_parent() != kick_center:
		kick_panel.get_parent().remove_child(kick_panel)
		kick_center.add_child(kick_panel)
	kick_panel.custom_minimum_size = Vector2(_panel_w(520.0), 0)
	q_intro.visible = true
	q_run_btn.visible = true
	q_hint.visible = false
	_set_force_rows_enabled(true)
	kick_center.visible = true
	btn_start.visible = true
	btn_start.disabled = true   # Tekrar: henüz oynatılacak atış yok
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
	kick_panel.custom_minimum_size = Vector2(_panel_w(520.0), 0)
	btn_start.visible = true
	btn_start.disabled = true          # uçuş sırasında atış yapılamaz
	_update_choice_summary()

func _update_choice_summary() -> void:
	if hud_choice == null:
		return
	var parts := PackedStringArray()
	if cb_gravity.button_pressed:
		parts.append(S.t("FORCE_GRAVITY_TITLE"))
	if cb_kick.button_pressed:
		parts.append(S.t("FORCE_KICK_TITLE"))
	if cb_air.button_pressed:
		parts.append(S.t("FORCE_AIR_TITLE"))
	hud_choice.text = "Seçimin: " + (", ".join(parts) if parts.size() > 0 else "hiçbir kuvvet")

func _set_force_rows_enabled(on: bool) -> void:
	for cb in [cb_gravity, cb_kick, cb_air]:
		if cb:
			cb.disabled = not on

## MADDE 16 — ses düğmesi tek yönlü çalışıyordu (kapanıyor, tekrar açılmıyordu).
## İki sebep vardı:
##   a) Yalnızca `AudioServer.set_bus_mute` kullanılıyordu; web (HTML5) export'ta
##      tarayıcı AudioContext'i askıya alındıktan sonra bu bayrağın geri
##      alınması her zaman sesi geri getirmiyor.
##   b) Sesi kapatınca çalan oynatıcılar (özellikle döngüdeki rüzgâr) durmuyor,
##      geri açınca da yeniden başlatılmıyordu.
## Çözüm: mute bayrağı + bus SEVİYESİ birlikte ayarlanıyor, oynatıcılar açıkça
## durdurulup geri açılınca uçuş sürüyorsa rüzgâr yeniden başlatılıyor. Düğme
## metni her seferinde GERÇEK duruma göre yazılıyor (tek doğruluk kaynağı).
func _set_sound_enabled(on: bool) -> void:
	muted = not on
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		bus = 0
	AudioServer.set_bus_mute(bus, muted)
	AudioServer.set_bus_volume_db(bus, -80.0 if muted else master_db)
	if muted:
		for pl in [sfx_kick, sfx_goal, sfx_wind]:
			if pl and pl.playing:
				pl.stop()
	elif field and field.playing:
		# ses geri açıldı ve top hâlâ uçuyor -> rüzgâr kaldığı yerden devam etsin
		if sfx_wind and sfx_wind.stream and not sfx_wind.playing:
			sfx_wind.play()
	if btn_mute:
		btn_mute.text = "🔇 Sesler kapalı" if muted else "🔊 Sesler açık"
		btn_mute.tooltip_text = "Tüm ses efektlerini aç/kapat"

func _on_mute_toggle() -> void:
	_set_sound_enabled(muted)   # muted=true iken AÇ, false iken KAPAT

func _on_pause_toggle() -> void:
	sim_paused = not sim_paused
	field.set_paused(sim_paused)
	btn_pause.text = "▶  Devam et" if sim_paused else "⏸  Durdur"

func _on_reset_sim() -> void:
	sim_paused = false
	field.set_paused(false)
	btn_pause.text = "⏸  Durdur"
	result_center.visible = false
	_stop_wind()
	field.reset()
	_reset_hud_values()
	Tele.decision_start(attempt + 1)
	if Physics.cfg.intro_before_each_question:
		# Inspector: sim_config.tres -> Zamanlama -> Intro Before Each Question
		kick_center.visible = false
		field.start_intro()          # soru, _on_intro_done içinde açılacak
	else:
		_center_question()
	decision_started = Time.get_ticks_msec() / 1000.0
	_update_preview()

func _build_field() -> void:
	field = FieldView.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.offset_top = 52
	field.flight_finished.connect(_on_flight_finished)
	field.intro_done.connect(_on_intro_done)
	field.pre_kick.connect(_on_pre_kick)
	field.target_hit.connect(_on_goal_scored)
	field.speed_report.connect(_on_speed_report)   # HUD'daki hız değerlerini besler
	field.altitude_report.connect(_on_altitude_report)   # rüzgar sesini yönetir
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
	entry_panel = panel
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
	admin_panel = panel
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
	_stop_wind()
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
	if field.playing or field.finished:
		return   # uçuş bir şekilde başladıysa soru kutusunu ÜSTÜNE açma
	Tele.decision_start(attempt + 1)
	_center_question()
	decision_started = Time.get_ticks_msec() / 1000.0
	_update_preview()

# ------------------------------------------------------------ kuvvet önizleme

func _build_audio() -> void:
	sfx_kick = AudioStreamPlayer.new()
	sfx_kick.stream = Physics.cfg.kick_sfx   # Inspector: sim_config.tres -> Ses -> Kick Sfx
	sfx_kick.volume_db = Physics.cfg.sfx_volume_db
	add_child(sfx_kick)
	sfx_goal = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/applause.mp3"):
		sfx_goal.stream = load("res://assets/audio/applause.mp3")
	sfx_goal.volume_db = -3.0
	add_child(sfx_goal)
	sfx_wind = AudioStreamPlayer.new()
	sfx_wind.stream = _loopable(Physics.cfg.wind_sfx)   # Inspector: sim_config.tres -> Ses -> Wind Sfx
	sfx_wind.volume_db = Physics.cfg.wind_volume_db
	add_child(sfx_wind)
	if Physics.cfg.wind_sfx == null:
		push_warning("Rüzgâr sesi atanmamış: sim_config.tres -> Ses -> Wind Sfx boş. Uçuşta rüzgâr çalmaz.")

## MADDE 10 — Inspector'daki rüzgâr sesi yuvasını GÜVENİLİR hâle getirir.
## Eski kod iki noktada kırılgandı:
##   a) Paylaşılan kaynağı (preload edilmiş .tres alanını) YERİNDE değiştiriyordu —
##      aynı dosyayı başka yerde kullanan herkes etkileniyordu. Artık duplicate().
##   b) Döngü uzunluğunu `data.size() / 2` ile hesaplıyordu: bu yalnız 16-bit MONO
##      için doğru. Inspector'dan STEREO ya da 8-bit bir WAV atanırsa döngü yanlış
##      yerden dönüyor / hiç dönmüyordu. Artık format ve kanal sayısı okunuyor.
## OGG/MP3 atanırsa `loop` özelliği kullanılır; tanınmayan tür olduğu gibi döner.
func _loopable(src: AudioStream) -> AudioStream:
	if src == null:
		return null
	if src is AudioStreamWAV:
		var w: AudioStreamWAV = (src as AudioStreamWAV).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		var bpf := 0
		match w.format:
			AudioStreamWAV.FORMAT_8_BITS:
				bpf = 1
			AudioStreamWAV.FORMAT_16_BITS:
				bpf = 2
			_:
				bpf = 0     # IMA-ADPCM / QOA (sıkıştırılmış): bayt başına kare SABİT DEĞİL
		if bpf > 0:
			if w.stereo:
				bpf *= 2
			w.loop_end = int(w.data.size() / bpf)
		else:
			# Sıkıştırılmış WAV (Godot'un varsayılan QOA içe aktarımı budur):
			# kare sayısı bayt sayısından türetilemez, süre × örnekleme hızından
			# hesaplanır. Bu dal olmadan loop_end 0 kalıyor ve döngü çalışmıyordu.
			w.loop_end = int(round(w.get_length() * float(w.mix_rate)))
		return w
	var d := src.duplicate()
	if "loop" in d:
		d.set("loop", true)
	return d

func _on_goal_scored() -> void:
	if muted:
		return
	if sfx_goal and sfx_goal.stream:
		sfx_goal.play()

## Ayak topa değdi (küçük sıçrama, "Top havada" popup'ından HEMEN önce) —
## vuruş sesi burada çalar ki top biraz havalanması sesi görsel olarak justify etsin.
func _on_pre_kick() -> void:
	if muted:
		return
	if sfx_kick and sfx_kick.stream:
		sfx_kick.play()

## Rüzgar sesi: top "uzayda" DEĞİLKEN (in_space=false) uçuş boyunca çalar.
## sim_config.tres -> Ses -> Wind Sfx boşsa hiçbir şey yapmaz.
func _on_altitude_report(_alt_m: float, in_space: bool) -> void:
	if sfx_wind == null or sfx_wind.stream == null or muted:
		return
	if in_space:
		if sfx_wind.playing:
			sfx_wind.stop()
	elif not sfx_wind.playing:
		sfx_wind.play()

func _stop_wind() -> void:
	if sfx_wind and sfx_wind.playing:
		sfx_wind.stop()

func _update_preview() -> void:
	_update_choice_summary()
	# yalnızca karar aşamasında (kick paneli görünürken) önizleme çiz
	if kick_panel == null or not kick_center.visible:
		return
	field.set_preview(cb_gravity.button_pressed, cb_kick.button_pressed,
		cb_air.button_pressed, Physics.cfg.drag_k, Physics.cfg.impetus_acc)

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
	var dk := Physics.cfg.drag_k
	var tx := field.target_x
	var pred := Physics.simulate(g, k, a, dk, Physics.cfg.impetus_acc, tx, Physics.cfg.ring_bulls)
	var real := Physics.real_path(tx, Physics.cfg.ring_bulls)
	var correct := g and a and not k
	var landing_x: float = pred["impact_x"]
	var is_goal := landing_x > 0.0 and absf(landing_x - field.target_x) <= Physics.cfg.ring_bulls
	var category: String = _feedback(g, k, a)[0]
	var decision_s := maxf(Time.get_ticks_msec() / 1000.0 - decision_started, 0.0)
	# yalnızca yönetici bu kod için veri toplamayı açtıysa kaydet
	official = Session.is_active(participant_code)
	Tele.set_official(official)
	Tele.answer_submit(g, k, a, correct, category)
	if official:
		DataLog.log_attempt(participant_code, group, Codes.has_seen_topic(participant_code),
			"official", attempt, g, k, a, Physics.cfg.impetus_acc, v0, angle,
			correct, category, is_goal, landing_x, decision_s)
		Session.count_attempt(participant_code)
	_hide_question()
	sim_paused = false
	btn_pause.text = "⏸  Durdur"
	field.set_paused(false)
	btn_start.disabled = true
	field.set_forces(g, k, a, dk, Physics.cfg.impetus_acc)   # uçuş sırasında canlı kuvvet okları
	# vuruş sesi artık burada değil — küçük sıçrama anında (_on_pre_kick) çalınıyor
	field.start_flight(pred, real)

func _on_flight_finished() -> void:
	_stop_wind()
	var gol := field.hit_bulls
	result_badge_lbl.text = S.t("BADGE_GOAL") if gol else S.t("BADGE_MISS")
	result_badge_lbl.add_theme_color_override("font_color", ACCENT if gol else DANGER)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(ACCENT if gol else DANGER, 0.15)
	bsb.set_corner_radius_all(999)
	bsb.content_margin_left = 16
	bsb.content_margin_right = 16
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 6
	result_badge.add_theme_stylebox_override("panel", bsb)
	result_sub.text = S.t("RESULT_DEFAULT_SUB")
	if gol:
		result_title.text = S.t("RESULT_GOAL_TITLE")
		result_sub.text = S.t("RESULT_GOAL_SUB")
	elif field.impact_x < 0.0:
		result_title.text = S.t("RESULT_NOLAND_TITLE")
	elif field.impact_x < Physics.cfg.goal_x:
		result_title.text = S.t("RESULT_SHORT_TITLE")
		result_sub.text = S.t("RESULT_SHORT_SUB", ["%.1f" % (Physics.cfg.goal_x - field.impact_x)])
	else:
		result_title.text = S.t("RESULT_OVER_TITLE")
		result_sub.text = S.t("RESULT_OVER_SUB", ["%.1f" % (field.impact_x - Physics.cfg.goal_x)])
	result_center.visible = true
	btn_start.disabled = false   # Tekrar artık oynatılabilir
	_stop_wind()
	Tele.run_complete(gol, field.impact_x)

func _on_replay() -> void:
	Tele.replay()
	result_center.visible = false
	var dk := Physics.cfg.drag_k
	var tx := field.target_x
	field.start_flight(
		Physics.simulate(cb_gravity.button_pressed, cb_kick.button_pressed,
			cb_air.button_pressed, dk, Physics.cfg.impetus_acc, tx, Physics.cfg.ring_bulls),
		Physics.real_path(tx, Physics.cfg.ring_bulls))

func _on_change_answer() -> void:
	Tele.answer_change()
	result_center.visible = false
	_stop_wind()
	field.reset()
	_reset_hud_values()
	Tele.decision_start(attempt + 1)
	if Physics.cfg.intro_before_each_question:
		# Inspector: sim_config.tres -> Zamanlama -> Intro Before Each Question
		kick_center.visible = false
		field.start_intro()          # soru, _on_intro_done içinde açılacak
	else:
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

## Not: dönen [0] (kategori) DataLog CSV'sinin "category" sütununa da yazılıyor
## (araştırma verisi) — res://localization/strings.csv'deki FB_*_CAT metnini
## değiştirirsen CSV'deki kategori etiketi de değişir (tasarım gereği, eskiden
## de böyleydi). FB_*_MSG şu an ekranda gösterilmiyor (bkz. GELISTIRME-REHBERI.md
## "geri bildirim metni kaldırıldı") ama ileride kullanılmak üzere hazır tutuluyor.
func _feedback(g: bool, k: bool, a: bool) -> Array:
	if g and a and not k:
		return [S.t("FB_GA_CAT"), S.t("FB_GA_MSG")]
	if g and not k and not a:
		return [S.t("FB_G_CAT"), S.t("FB_G_MSG")]
	if g and k and a:
		return [S.t("FB_GKA_CAT"), S.t("FB_GKA_MSG")]
	if g and k and not a:
		return [S.t("FB_GK_CAT"), S.t("FB_GK_MSG")]
	if k and not g and not a:
		return [S.t("FB_K_CAT"), S.t("FB_K_MSG")]
	if k and a and not g:
		return [S.t("FB_KA_CAT"), S.t("FB_KA_MSG")]
	if a and not g and not k:
		return [S.t("FB_A_CAT"), S.t("FB_A_MSG")]
	return [S.t("FB_NONE_CAT"), S.t("FB_NONE_MSG")]
