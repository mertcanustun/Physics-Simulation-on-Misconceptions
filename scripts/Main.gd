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
var sim_cfg: SimConfig = preload("res://config/sim_config.tres")
@onready var v0: float = sim_cfg.v0
@onready var angle: float = sim_cfg.angle_deg
@onready var kick_force: float = sim_cfg.impetus_acc
var time_panel: PanelContainer # Yeni yüzen panelimiz
var field: FieldView
var entry_center: CenterContainer
var code_edit: LineEdit
var group_lbl: Label
var err_lbl: Label
var admin_center: CenterContainer
var admin_search: LineEdit
var admin_status: Label
var admin_log_tree: Tree   # <--- YENİ EKLENEN SAT
var admin_log_display: RichTextLabel   # <--- SADECE BU SATIRI EKLEYİN
var _supabase_busy := false   # HTTP_LogSubmit aynı anda tek istek kaldırabiliyor — bkz. _sync_telemetry
var btn_activate: Button
var btn_stop: Button
var kick_panel: PanelContainer
var kick_center: CenterContainer
var kick_scroll: ScrollContainer   # soru paneli ekrana sığmazsa içerik kaydırılır
var kick_body: VBoxContainer
var intro_modal_center: CenterContainer
var intro_panel: PanelContainer
var intro_continue_btn: Button
var btn_info_icon: Button
var is_first_intro := true
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
var btn_finish: Button       # sonuç kutusu: "Simülasyonu Bitir" (yalnız GOL ekranında)
var btn_change: Button       # sonuç kutusu: "Kuvvetleri Değiştir"
var thanks_center: CenterContainer
var btn_anim: Button         # alt çubuk: giriş animasyonu aç/kapa
var btn_sound: Button        # alt çubuk: ses aç/kapa
var anim_enabled := true     # her soru öncesi koşu-vuruş animasyonu oynasın mı
var sound_enabled := true
var btn_pause: Button
var btn_reset: Button
var time_slider: HSlider
var time_slider_box: HBoxContainer
var sim_paused := false
var decision_started := 0.0   # soru gösterildiği an (karar süresi ölçümü)
var sfx_kick: AudioStreamPlayer
var sfx_goal: AudioStreamPlayer
var sfx_wind: AudioStreamPlayer
var save_dialog: FileDialog
var events_dialog: FileDialog
@onready var Tele: Node = get_node("/root/Telemetry")
@onready var S: StringsData = get_node("/root/Strings")   # KOD YAZMADAN düzenlenebilir metinler (bkz. Strings.gd)

## Hangi build'in çalıştığını tarayıcı konsolundan (F12) tek bakışta anlamak için.
## "Dağıttım ama eski sürümü mü görüyorum?" sorusunu bitirir. Yeni bir dağıtım
## yaparken bu satırı güncelle.
const BUILD_ID := "2026-08-12c"

## Modal panellerin kullanabileceği dikey alanı belirleyen paylar (px).
const TOP_BAR_H := 56.0
const BOTTOM_BAR_H := 90.0

func _process(_delta: float) -> void:
	# Eğer uçuş devam ettirildiyse (Resume), kaydırıcı çubuğu da animasyonla birlikte ilerlet
	if field and field.playing and time_panel and time_panel.visible:
		time_slider.set_value_no_signal(field.play_t)
		# Sona ulaşırsa pop-up'ı tekrar çıkart
		if field.play_t >= time_slider.max_value - 0.05:
			result_center.visible = true
			btn_pause.text = S.t("CTRL_PAUSE")
	
	# Bilgi ikonu görünür olduğu sürece HUD kartının tam 15 piksel altına kilitlensin
	if btn_info_icon != null and btn_info_icon.visible and hud_card != null:
		btn_info_icon.position = Vector2(24, hud_card.position.y + hud_card.size.y + 15)
		
func _ready() -> void:
	print("=== kicked-ball build %s | metin: %d anahtar (%s) | impetus_acc=%s drag_k=%s goal_x=%s ==="
		% [BUILD_ID, S.count(), S.source_name(), Physics.cfg.impetus_acc, Physics.cfg.drag_k, Physics.cfg.goal_x])
	_build_header()
	_build_field()
	_build_entry_panel()
	_build_admin_panel()
	_build_kick_panel()
	_build_intro_modal()
	_build_hud()
	_build_result_modal()
	_build_thanks_modal()
	_build_control_bar()
	_build_save_dialog()
	resized.connect(_fit_question_panel)
	
	# --- YENİ EKLENEN SATIRLAR ---
	var http_submit := HTTPRequest.new()
	http_submit.name = "HTTP_LogSubmit"
	http_submit.request_completed.connect(func(_r, _c, _h, _b): _supabase_busy = false)
	add_child(http_submit)
	# -----------------------------
	
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
	h.add_child(_label("Kicked-Ball Simulation", 18, TXT))
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
	hud_choice = _label("Seçimin: —", sim_cfg.hud_choice_font_size, Color("cbd5e1"))
	hud_choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_choice.custom_minimum_size.x = 190
	v.add_child(hud_choice)
	v.add_child(_spacer(6))
	v.add_child(_label("YÖRÜNGELER", 11, Color(ACCENT, 0.85)))
	v.add_child(_label("—  senin tahminin", 12, Physics.cfg.predicted_path_color))
	v.add_child(_label("···  gerçek yol (hayalet)", 12, Physics.cfg.real_path_color))
	v.add_child(_spacer(8))
	v.add_child(_label("TOPUN HIZI", 11, TXT_MUTED))
	hud_speed = _label("0.0 m/s", 15, ACCENT)
	v.add_child(hud_speed)
	hud_vx = _label(sim_cfg.text_hud_vx + ": 0.0 m/s", 13, Color("f59e0b"))
	v.add_child(hud_vx)
	hud_vy = _label(sim_cfg.text_hud_vy + ": 0.0 m/s", 13, Color("a855f7"))
	v.add_child(hud_vy)

func _on_speed_report(sp: float, vx: float, vy: float) -> void:
	if hud_speed:
		hud_speed.text = "%.1f m/s" % sp
	if hud_vx:
		var steady := absf(vx - last_vx) < 0.05 and last_vx > -900.0
		hud_vx.text = sim_cfg.text_hud_vx + ": %.1f m/s" % vx
		hud_vx.add_theme_color_override("font_color", ACCENT if steady else Color("f59e0b"))
		last_vx = vx
	if hud_vy:
		hud_vy.text = sim_cfg.text_hud_vy + ": %.1f m/s" % (0.0 if absf(vy) < 0.05 else vy)
		hud_vy.add_theme_color_override("font_color", DANGER if absf(vy) < 1.2 else Color("a855f7"))
		
## ------------------- SORU KUTUSU (ortada, modal) -------------------
func _build_kick_panel() -> void:
	kick_center = CenterContainer.new()
	kick_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ortalama alanı ÜST ÇUBUK ile ALT KONTROL ÇUBUĞU arasına daraltılır.
	# Aksi hâlde panel ekranın tam ortasına göre hizalanır ve uzun metinde
	# alt kenarı kontrol çubuğunun arkasında kalır. Bu offset'lerle mevcut
	# dikey alanın TAMAMI kullanılabiliyor (üstte boşa giden yer kalmıyor).
	kick_center.offset_top = TOP_BAR_H
	kick_center.offset_bottom = -BOTTOM_BAR_H
	add_child(kick_center)
	kick_panel = PanelContainer.new()
	kick_panel.add_theme_stylebox_override("panel", _card_style(18))
	kick_panel.custom_minimum_size = Vector2(520, 0)
	kick_center.add_child(kick_panel)
	# Metinler CSV'den geldiği için uzunlukları değişebilir; uzun metin paneli
	# taşırıp yeşil düğmeyi alt kontrol çubuğunun ARKASINA itiyordu. Yapı:
	#   PanelContainer
	#     └ VBox (dış)
	#         ├ ScrollContainer  -> başlık + metin + kuvvet kutuları (gerekirse kayar)
	#         └ q_run_btn        -> HER ZAMAN görünür, kaymaz (sabitlenmiş)
	# Böylece metin ne kadar uzarsa uzasın "Ne olacağını gör" düğmesi ekranda kalır.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	kick_panel.add_child(outer)
	kick_scroll = ScrollContainer.new()
	kick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kick_scroll.follow_focus = true
	kick_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(kick_scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kick_scroll.add_child(v)
	kick_body = v
	v.add_child(_label(S.t("KICK_PANEL_TITLE"), 22, TXT))
	mode_banner = _label("", 11, Color("f59e0b"))
	mode_banner.visible = false # Görünmez etiketi tamamen gizleyip yer kaplamasını önlüyoruz
	v.add_child(mode_banner)
	# Metni "•" işaretinden itibaren ikiye böl
	var full_intro = S.t("KICK_PANEL_INTRO")
	var split_idx = full_intro.find("•")
	
	var top_text = full_intro
	var bullet_text = ""
	if split_idx != -1:
		top_text = full_intro.substr(0, split_idx).strip_edges()
		bullet_text = full_intro.substr(split_idx).strip_edges()
		
	# 1. BÖLÜM (Üst Kısım): Eski boyut 12 idi, 2 punto büyütüp 14 yapıyoruz
	q_intro = _label(top_text, 13, TXT_MUTED)
	q_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_intro.custom_minimum_size.x = 480
	v.add_child(q_intro)
	
	# 2. BÖLÜM (Madde İmleri): 
	if bullet_text != "":
		v.add_child(_spacer(4)) # İki metin arasına hafif bir nefes boşluğu
		var q_bullets = _label(bullet_text, 12, TXT_MUTED)
		q_bullets.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q_bullets.custom_minimum_size.x = 480
		v.add_child(q_bullets)
	v.add_child(_spacer(2))
	var question_lbl := _label(S.t("KICK_PANEL_QUESTION"), 16, TXT)
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
	# --- SABİT (kaymayan) alt kısım ---
	q_run_btn = Button.new()
	q_run_btn.text = S.t("KICK_PANEL_RUN_BTN")
	q_run_btn.custom_minimum_size = Vector2(480, 46)
	_style_button(q_run_btn, ACCENT_DK, Color.WHITE)
	q_run_btn.pressed.connect(_on_run)
	outer.add_child(q_run_btn)

## ------------------- "NASIL ÇALIŞIR?" GİRİŞ POPUP'I (simülasyon başlamadan önce) -------------------
## Futbolcu koşup gelmeden, hatta saha görünür olmadan HEMEN önce çıkar; "Devam
## Et"e basılınca koşu-vuruş girişi (field.start_intro) başlar.
func _build_intro_modal() -> void:
	intro_modal_center = CenterContainer.new()
	intro_modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_modal_center.visible = false
	add_child(intro_modal_center)
	
	intro_panel = PanelContainer.new()
	intro_panel.add_theme_stylebox_override("panel", _card_style(18))
	intro_panel.custom_minimum_size = Vector2(520, 0)
	intro_modal_center.add_child(intro_panel)
	
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	intro_panel.add_child(v)
	v.add_child(_label(S.t("POPUP_INTRO_TITLE"), 22, TXT))
	
	var body := _label(S.t("POPUP_INTRO_BODY"), 14, TXT_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 480
	v.add_child(body)
	v.add_child(_spacer(4))
	
	intro_continue_btn = Button.new()
	intro_continue_btn.text = S.t("POPUP_INTRO_BTN")
	intro_continue_btn.custom_minimum_size = Vector2(480, 46)
	_style_button(intro_continue_btn, ACCENT_DK, Color.WHITE)
	intro_continue_btn.pressed.connect(_on_intro_modal_continue)
	v.add_child(intro_continue_btn)
	
	# Sol Altta Belirecek Küçük Bilgi İkonu
	btn_info_icon = Button.new()
	btn_info_icon.text = "i"
	btn_info_icon.custom_minimum_size = Vector2(80, 40)
	_style_button(btn_info_icon, CARD, TXT_MUTED, Color(1, 1, 1, 0.1))
	btn_info_icon.visible = false
	btn_info_icon.pressed.connect(_on_info_icon_clicked)
	add_child(btn_info_icon)
	
func _on_intro_modal_continue() -> void:
	# Küçülme efekti için paneli geçici olarak CenterContainer'dan çıkarıp serbest bırakıyoruz
	var start_pos = intro_panel.global_position
	if intro_panel.get_parent() == intro_modal_center:
		intro_modal_center.remove_child(intro_panel)
		add_child(intro_panel)
		intro_panel.global_position = start_pos
		
	# --- İŞTE HAYALETİ YOK EDEN VE TIKLAMALARI AÇAN SATIR ---
	intro_modal_center.visible = false 
	
	intro_panel.pivot_offset = intro_panel.size / 2.0
	var target_pos = Vector2(24, hud_card.position.y + hud_card.size.y + 15) # Sol HUD panelinin hemen altı
	
	# Küçülerek sol alta kayma animasyonu
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(intro_panel, "scale", Vector2(0.05, 0.05), 0.35)
	tween.tween_property(intro_panel, "global_position", target_pos, 0.35)
	tween.tween_property(intro_panel, "modulate:a", 0.0, 0.35)
	
	tween.chain().tween_callback(func():
		intro_panel.visible = false
		btn_info_icon.position = target_pos
		btn_info_icon.visible = true
		
		# Sadece simülasyon ilk açıldığında futbolcu animasyonunu başlat
		if is_first_intro:
			is_first_intro = false
			control_bar.visible = true
			field.start_intro()
	)
	
func _on_info_icon_clicked() -> void:
	btn_info_icon.visible = false
	intro_panel.visible = true
	intro_continue_btn.text = "Kapat" # Tekrar açıldığında buton metni Kapat olur
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	var target_pos = (size - intro_panel.size) / 2.0
	tween.tween_property(intro_panel, "scale", Vector2(1.0, 1.0), 0.4)
	tween.tween_property(intro_panel, "global_position", target_pos, 0.4)
	tween.tween_property(intro_panel, "modulate:a", 1.0, 0.4)
	
	# Büyüme bitince paneli tekrar CenterContainer içine al (ekran boyutlandırmaları bozulmasın diye)
	tween.chain().tween_callback(func():
		if intro_panel.get_parent() != intro_modal_center:
			intro_panel.get_parent().remove_child(intro_panel)
			intro_modal_center.add_child(intro_panel)
		intro_modal_center.visible = true
	)
	
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
	var title_lbl := _label(display_title, 14, TXT)
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
	# SOL: "Simülasyonu Bitir" — YALNIZCA başarılı (GOL) ekranında görünür.
	# Başarısız ekranda tek buton kalır: "Kuvvetleri Değiştir".
	btn_finish = Button.new()
	btn_finish.text = S.t("RESULT_BTN_FINISH")
	btn_finish.custom_minimum_size = Vector2(200, 46)
	_style_button(btn_finish, CARD2, TXT, Color(1, 1, 1, 0.10))
	btn_finish.pressed.connect(_on_finish_sim)
	row.add_child(btn_finish)
	btn_change = Button.new()
	btn_change.text = S.t("RESULT_BTN_CHANGE")
	btn_change.custom_minimum_size = Vector2(220, 46)
	_style_button(btn_change, ACCENT_DK, Color.WHITE)
	btn_change.pressed.connect(_on_change_answer)
	row.add_child(btn_change)

## ------------------- TEŞEKKÜR EKRANI (Simülasyonu Bitir) -------------------
## "Simülasyonu Bitir"e basılınca çıkar; geri dönüş yolu YOK — katılımcı için
## simülasyon burada biter, cihazı görevliye teslim eder. Görevli yeni katılımcı
## için sayfayı yeniler (web) veya F5 ile yeniden başlatır.
func _build_thanks_modal() -> void:
	thanks_center = CenterContainer.new()
	thanks_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	thanks_center.visible = false
	add_child(thanks_center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(18))
	panel.custom_minimum_size = Vector2(520, 0)
	thanks_center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var t := _label(S.t("THANKS_TITLE"), 24, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := _label(S.t("THANKS_BODY"), 14, TXT_MUTED)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 480
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)

## Katılımcı için son ekran. Oturum kapatılır, veri yazımı durur; alt kontrol
## çubuğu ve soru paneli gizlenir ki geri dönüp yeni deneme yapılamasın.
func _on_finish_sim() -> void:
	Tele.run_finish_pressed()
	_sync_telemetry()
	Tele.end_session()
	_stop_wind()
	result_center.visible = false
	kick_center.visible = false
	control_bar.visible = false
	hud_card.visible = false
	thanks_center.visible = true

## Biriken telemetri olaylarını Supabase'e gönderir (bkz. docs/supabase-telemetri.md).
## Yalnızca EN SON çağrıdan bu yana eklenen olaylar gider (Telemetry.gd
## _synced_count ile takip edilir) — birden çok yerden çağrılsa da (gol
## almadan "Kuvvetleri Değiştir" VE gol alıp "Simülasyonu Bitir") satırlar
## yinelenmez. "Deneme modu"nda hiçbir şey gönderilmez (DataLog ile aynı ilke).
func _sync_telemetry() -> void:
	if not Tele.is_official():
		return
	var http_node = get_node_or_null("HTTP_LogSubmit")
	var cfg := Physics.cfg
	if http_node == null or cfg.supabase_url == "" or cfg.supabase_anon_key == "":
		return
	if _supabase_busy:
		# HTTPRequest tek seferde tek istek kaldırabiliyor; bu senkronizasyonu
		# atla. _synced_count'a HENÜZ dokunmadık (supabase_rows_since_last_sync
		# çağrılmadı), o yüzden bu olaylar bir SONRAKİ _sync_telemetry() çağrısında
		# (ör. "Simülasyonu Bitir") otomatik olarak dahil edilecek — kayıp yok.
		return
	var rows: Array = Tele.supabase_rows_since_last_sync()
	if rows.is_empty():
		return
	var endpoint := "%s/rest/v1/%s" % [cfg.supabase_url.rstrip("/"), cfg.supabase_table]
	var payload := JSON.stringify(rows)
	var headers := [
		"Content-Type: application/json",
		"apikey: %s" % cfg.supabase_anon_key,
		"Authorization: Bearer %s" % cfg.supabase_anon_key,
		"Prefer: return=minimal",
	]
	_supabase_busy = true
	http_node.request(endpoint, headers, HTTPClient.METHOD_POST, payload)

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
	btn_start = Button.new()
	btn_start.text = S.t("CTRL_REPLAY")
	btn_start.custom_minimum_size = Vector2(160, 40)
	_style_button(btn_start, ACCENT_DK, Color.WHITE)
	btn_start.pressed.connect(_on_replay_or_run)
	h.add_child(btn_start)
	btn_pause = Button.new()
	btn_pause.text = S.t("CTRL_PAUSE")
	btn_pause.custom_minimum_size = Vector2(120, 40)
	_style_button(btn_pause, CARD2, DANGER, Color(DANGER, 0.55))
	btn_pause.pressed.connect(_on_pause_toggle)
	h.add_child(btn_pause)
	btn_reset = Button.new()
	btn_reset.text = S.t("CTRL_RESET")
	btn_reset.custom_minimum_size = Vector2(120, 40)
	_style_button(btn_reset, CARD2, INFO, Color(INFO, 0.55))
	btn_reset.pressed.connect(_on_reset_sim)
	h.add_child(btn_reset)
	
	# --- BAĞIMSIZ VE YÜZEN ZAMAN ÇİZGİSİ (İLERİ/GERİ SARMA) PANELİ ---
	time_panel = PanelContainer.new()
	time_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	time_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # Panel sağa-sola eşit büyüsün
	time_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN    # Panel aşağı değil YUKARI büyüsün
	time_panel.offset_bottom = -sim_cfg.slider_offset_y
	time_panel.custom_minimum_size = Vector2(sim_cfg.slider_width, 50)
	time_panel.visible = false
	
	var tp_sb = StyleBoxFlat.new()
	tp_sb.bg_color = sim_cfg.slider_bg
	tp_sb.set_corner_radius_all(25)
	tp_sb.border_color = Color(1, 1, 1, 0.08)
	tp_sb.set_border_width_all(1)
	tp_sb.content_margin_left = 20
	tp_sb.content_margin_right = 20
	time_panel.add_theme_stylebox_override("panel", tp_sb)
	add_child(time_panel) # Alt menüye değil, doğrudan ekrana eklenir (üstte yüzer)
	
	time_slider_box = HBoxContainer.new()
	time_slider_box.add_theme_constant_override("separation", 15)
	time_panel.add_child(time_slider_box)
	
	var scrub_lbl = _label("Zamanı İncele:", 14, TXT_MUTED)
	time_slider_box.add_child(scrub_lbl)
	
	time_slider = HSlider.new()
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_slider.step = 0.02
	time_slider.value_changed.connect(_on_time_scrub)
	time_slider_box.add_child(time_slider)
	# ----------------------------------------------------------------
	
	# --- AYARLAR: giriş animasyonu ve ses aç/kapa ---
	btn_anim = Button.new()
	btn_anim.custom_minimum_size = Vector2(150, 40)
	btn_anim.pressed.connect(_on_toggle_anim)
	h.add_child(btn_anim)
	btn_sound = Button.new()
	btn_sound.custom_minimum_size = Vector2(120, 40)
	btn_sound.pressed.connect(_on_toggle_sound)
	h.add_child(btn_sound)
	_refresh_toggle_buttons()

## Alt çubuktaki "Tekrar": uçuş BİTTİYSE aynı seçimi yeniden oynatır (yeni bir
## deneme KAYDEDİLMEZ — araştırma verisi şişmesin); henüz uçuş yoksa normal
## atışı başlatır. Eskiden bu düğme her basışta _on_run çağırıyordu.
func _on_replay_or_run() -> void:
	if field and field.finished:
		_on_replay()
	else:
		_on_run()

## Giriş (koşu-vuruş) animasyonu her soru öncesi oynasın mı?
## Kapalıyken soru paneli doğrudan açılır — tekrar tekrar deneyen katılımcı
## her seferinde animasyonu beklemek zorunda kalmaz.
func _on_toggle_anim() -> void:
	anim_enabled = not anim_enabled
	Tele.param_change("intro_animation", anim_enabled)
	_refresh_toggle_buttons()

## Tüm ses efektleri (vuruş, alkış, rüzgar) tek düğmeden susturulur.
func _on_toggle_sound() -> void:
	sound_enabled = not sound_enabled
	Tele.param_change("sound", sound_enabled)
	if not sound_enabled:
		for p in [sfx_kick, sfx_goal, sfx_wind]:
			if p and p.playing:
				p.stop()
	_refresh_toggle_buttons()

func _refresh_toggle_buttons() -> void:
	if btn_anim:
		btn_anim.text = S.t("CTRL_ANIM_ON") if anim_enabled else S.t("CTRL_ANIM_OFF")
		_style_button(btn_anim, CARD2, ACCENT if anim_enabled else TXT_MUTED,
			Color(ACCENT if anim_enabled else TXT_MUTED, 0.55))
	if btn_sound:
		btn_sound.text = S.t("CTRL_SOUND_ON") if sound_enabled else S.t("CTRL_SOUND_OFF")
		_style_button(btn_sound, CARD2, ACCENT if sound_enabled else TXT_MUTED,
			Color(ACCENT if sound_enabled else TXT_MUTED, 0.55))

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
	_fit_question_panel()

## Soru panelinin yüksekliğini pencereye göre sınırlar. Alt kontrol çubuğu ve
## üst çubuk için yer bırakır; içerik sığmazsa ScrollContainer devreye girer.
## Hem pencere yeniden boyutlandığında hem panel açılırken çağrılır.
func _fit_question_panel() -> void:
	if kick_scroll == null or kick_body == null:
		return
	# kick_center zaten üst/alt çubuk payları kadar daraltıldı, dolayısıyla
	# burada yalnızca panelin kendi iç boşlukları ve sabit düğme düşülür.
	var panel_pad := 40.0 + 56.0                # panel iç boşlukları + sabit düğme
	var avail := maxf(size.y - TOP_BAR_H - BOTTOM_BAR_H - panel_pad, 220.0)
	var needed := kick_body.get_combined_minimum_size().y
	kick_scroll.custom_minimum_size.y = minf(needed, avail)

## Atış başlayınca soru kutusu ("Top havada") ekrandan kalkar; öğrencinin
## seçimi kaybolmaz — sol HUD kartında özet satır olarak görünmeye devam eder.
func _reset_hud_values() -> void:
	last_vx = -999.0
	if hud_speed:
		hud_speed.text = "0.0 m/s"
	if hud_vx:
		hud_vx.text = sim_cfg.text_hud_vx + ": 0.0 m/s"
		hud_vx.add_theme_color_override("font_color", Color("f59e0b"))
	if hud_vy:
		hud_vy.text = sim_cfg.text_hud_vy + ": 0.0 m/s"
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
		parts.append("• " + S.t("FORCE_GRAVITY_TITLE"))
	if cb_kick.button_pressed:
		parts.append("• " + S.t("FORCE_KICK_TITLE"))
	if cb_air.button_pressed:
		parts.append("• " + S.t("FORCE_AIR_TITLE"))
		
	if parts.size() > 0:
		hud_choice.text = "Seçimin:\n" + "\n".join(parts)
	else:
		hud_choice.text = "Seçimin:\n• Hiçbir kuvvet"

func _set_force_rows_enabled(on: bool) -> void:
	for cb in [cb_gravity, cb_kick, cb_air]:
		if cb:
			cb.disabled = not on

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
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(460, 0)
	entry_center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_label("Kicked-Ball Simulation", 26, TXT))
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
	# --- ÜST BAŞLIK VE GERİ DÖN BUTONU ---
	var top_row := HBoxContainer.new()
	var title_lbl := _label("Yönetici Paneli", 22, TXT)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_lbl)
	
	var btn_back_top := Button.new()
	btn_back_top.text = "← Başka Kod Dene"
	_style_button(btn_back_top, CARD2, TXT_MUTED, Color(1, 1, 1, 0.05))
	btn_back_top.pressed.connect(_show_entry)
	top_row.add_child(btn_back_top)
	v.add_child(top_row)
	# --------------------------------------
	
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

	# --- YÖNETİCİ AĞAÇ (TREE) GÖRÜNÜMÜ ---
	v.add_child(_spacer(12))
	v.add_child(_label("Gelen Sonuçlar (Öğrenci Logları)", 16, TXT))

	admin_log_tree = Tree.new()
	admin_log_tree.custom_minimum_size = Vector2(480, 250)
	admin_log_tree.hide_root = true
	admin_log_tree.visible = false   # şimdilik kullanılmıyor — bkz. admin_log_display
	var tree_sb := StyleBoxFlat.new()
	tree_sb.bg_color = CARD2
	tree_sb.set_corner_radius_all(8)
	tree_sb.set_content_margin_all(8)
	admin_log_tree.add_theme_stylebox_override("panel", tree_sb)
	v.add_child(admin_log_tree)

	# Verilerin listeleneceği kaydırılabilir alan
	var log_scroll := ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(460, 80)
	var log_sb := StyleBoxFlat.new()
	log_sb.bg_color = CARD2
	log_sb.set_corner_radius_all(8)
	log_sb.set_content_margin_all(8)
	log_scroll.add_theme_stylebox_override("panel", log_sb)
	v.add_child(log_scroll)

	# NOT (2026-08-13): öğrenci logları artık burada listelenmiyor — veriler
	# doğrudan Supabase'e yazılıyor (bkz. docs/supabase-telemetri.md), analiz
	# için Supabase Studio'daki tablo görünümü / CSV dışa aktarma kullanılıyor.
	# Bu panel yalnızca yönlendirme mesajı gösteriyor.
	admin_log_display = RichTextLabel.new()
	admin_log_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	admin_log_display.fit_content = true
	admin_log_display.add_theme_font_size_override("normal_font_size", 12)
	admin_log_display.text = ("Öğrenci logları artık burada listelenmiyor. Verileri görmek için "
		+ "Supabase projenizin panelindeki '%s' tablosunu açın (Table Editor) "
		+ "veya CSV olarak dışa aktarın.") % Physics.cfg.supabase_table
	log_scroll.add_child(admin_log_display)

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
	is_first_intro = true
	if btn_info_icon:
		btn_info_icon.visible = false
	if intro_panel and intro_panel.get_parent() != intro_modal_center:
		intro_panel.get_parent().remove_child(intro_panel)
		intro_modal_center.add_child(intro_panel)
		intro_panel.scale = Vector2.ONE
		intro_panel.modulate.a = 1.0
		intro_panel.visible = true
	if intro_continue_btn:
		intro_continue_btn.text = S.t("POPUP_INTRO_BTN")
	Tele.end_session()
	_stop_wind()
	hud_card.visible = false
	result_center.visible = false
	top_bar.visible = false
	entry_center.visible = true
	admin_center.visible = false
	kick_center.visible = false
	intro_modal_center.visible = false
	thanks_center.visible = false
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
	if c == "DENEME-124-TEST":
		official = false # Bu kod için veri kaydını zorla kapat
		
	Tele.begin_session(participant_code, group, Codes.has_seen_topic(c), official)
	attempt = 0
	var _mode_txt := "VERİ TOPLANIYOR" if official else "DENEME MODU — veri kaydedilmiyor"
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
	sfx_kick.stream = Physics.cfg.kick_sfx   # Inspector: sim_config.tres -> Ses -> Kick Sfx
	add_child(sfx_kick)
	sfx_goal = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/applause.mp3"):
		sfx_goal.stream = load("res://assets/audio/applause.mp3")
	sfx_goal.volume_db = -3.0
	add_child(sfx_goal)
	sfx_wind = AudioStreamPlayer.new()
	sfx_wind.stream = Physics.cfg.wind_sfx   # Inspector: sim_config.tres -> Ses -> Wind Sfx (boşsa çalmaz)
	sfx_wind.volume_db = -6.0
	add_child(sfx_wind)

func _on_goal_scored() -> void:
	if sound_enabled and sfx_goal and sfx_goal.stream:
		sfx_goal.play()

## Ayak topa değdi (küçük sıçrama, "Top havada" popup'ından HEMEN önce) —
## vuruş sesi burada çalar ki top biraz havalanması sesi görsel olarak justify etsin.
func _on_pre_kick() -> void:
	if sound_enabled and sfx_kick and sfx_kick.stream:
		sfx_kick.play()

## Rüzgar sesi: top "uzayda" DEĞİLKEN (in_space=false) uçuş boyunca çalar.
## sim_config.tres -> Ses -> Wind Sfx boşsa hiçbir şey yapmaz.
func _on_altitude_report(_alt_m: float, in_space: bool) -> void:
	if sfx_wind == null or sfx_wind.stream == null:
		return
	if not sound_enabled:
		if sfx_wind.playing:
			sfx_wind.stop()
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
		cb_air.button_pressed, Physics.cfg.drag_k, kick_force)

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
	var dk: float = Physics.cfg.drag_k
	var tx := field.target_x
	var pred := Physics.simulate(g, k, a, dk, kick_force, tx, Physics.cfg.ring_bulls)
	var real := Physics.real_path(tx, Physics.cfg.ring_bulls)
	var correct := g and a and not k
	var landing_x: float = pred["impact_x"]
	var is_goal: bool = landing_x > 0.0 and absf(landing_x - field.target_x) <= Physics.cfg.ring_bulls
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
	if time_slider_box:
		time_panel.visible = false
	sim_paused = false
	btn_pause.text = S.t("CTRL_PAUSE")
	field.set_paused(false)
	field.set_forces(g, k, a, dk, kick_force)   # uçuş sırasında canlı kuvvet okları
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
		result_sub.text = S.t("RESULT_NOLAND_SUB")
	elif field.impact_x < Physics.cfg.goal_x:
		result_title.text = S.t("RESULT_SHORT_TITLE")
		result_sub.text = S.t("RESULT_SHORT_SUB", ["%.1f" % (Physics.cfg.goal_x - field.impact_x)])
	else:
		result_title.text = S.t("RESULT_OVER_TITLE")
		result_sub.text = S.t("RESULT_OVER_SUB", ["%.1f" % (field.impact_x - Physics.cfg.goal_x)])
	# BAŞARILI ekran: "Simülasyonu Bitir" + "Kuvvetleri Değiştir"
	# BAŞARISIZ ekran: yalnızca "Kuvvetleri Değiştir"
	btn_finish.visible = gol
	result_center.visible = true
	# Uçuş bittiğinde sarma çubuğunu göster
	if field.has_method("get_flight_duration"):
		time_slider.max_value = field.get_flight_duration()
		time_slider.value = time_slider.max_value
		time_panel.visible= true
	Tele.run_complete(gol, field.impact_x)

func _on_replay() -> void:
	Tele.replay()
	result_center.visible = false
	if time_panel:
		time_panel.visible = false
	var dk = Physics.cfg.drag_k
	var tx := field.target_x
	field.start_flight(
		Physics.simulate(cb_gravity.button_pressed, cb_kick.button_pressed,
			cb_air.button_pressed, dk, kick_force, tx, Physics.cfg.ring_bulls),
		Physics.real_path(tx, Physics.cfg.ring_bulls))

func _on_change_answer() -> void:
	Tele.answer_change()
	_sync_telemetry()   # gol alınmadan da bu ana kadarki deneme(ler) Supabase'e gitsin
	result_center.visible = false
	_stop_wind()
	field.reset()
	_reset_hud_values()
	_back_to_question()

## Soru ekranına dönüş — "Kuvvetleri Değiştir" ve "Sıfırla" ortak yolu.
## "Animasyon: Açık" ise koşu-vuruş girişi yeniden oynar ve soru paneli
## animasyon bitince (_on_intro_done) açılır; kapalıysa panel hemen açılır ve
## top doğrudan "vuruş sonrası havada" konumuna alınır.
func _back_to_question() -> void:
	if anim_enabled:
		btn_start.disabled = true
		field.start_intro(true)   # "true" koşuyu atlamasını sağlar
		return
	field.hold_after_kick()
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
	
func _on_time_scrub(val: float) -> void:
	if field.has_method("set_ball_time"):
		field.set_ball_time(val)
	
	# Eğer çubuk en sonda DEĞİLSE pop-up'ı kapat ve "Devam" yap
	if val < time_slider.max_value - 0.05:
		result_center.visible = false
		btn_pause.text = "Devam"
		btn_pause.add_theme_color_override("font_color", ACCENT)
	else:
		# En sona sarılırsa sonuç pop-up'ı geri gelsin
		result_center.visible = true
		btn_pause.text = S.t("CTRL_PAUSE")
		btn_pause.add_theme_color_override("font_color", DANGER)

func _on_pause_toggle() -> void:
	if field.finished and time_slider.value < time_slider.max_value:
		# Zaman tünelinden kaldığı yerden devam etme (RESUME)
		field.resume_flight()
		btn_pause.text = S.t("CTRL_PAUSE")
		btn_pause.add_theme_color_override("font_color", DANGER)
		result_center.visible = false
	else:
		# Normal Durdur / Başlat mekanizması
		sim_paused = not sim_paused
		field.set_paused(sim_paused)
		btn_pause.text = S.t("CTRL_RESUME") if sim_paused else S.t("CTRL_PAUSE")

func _on_reset_sim() -> void:
	if time_panel:
		time_panel.visible = false
	sim_paused = false
	field.set_paused(false)
	btn_pause.text = S.t("CTRL_PAUSE")
	btn_pause.add_theme_color_override("font_color", DANGER)
	result_center.visible = false
	_stop_wind()
	field.reset()
	_reset_hud_values()
	_back_to_question()
