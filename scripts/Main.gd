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
var time_lbl: Label
var graph_panel: PanelContainer
var graph_tabs: TabContainer
var show_graph_x := true
var show_graph_y := true
var show_graph_net := true
var pop_slider: HSlider
var mini_view: Control
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
var btn_graph_icon: Button
var btn_fast_forward: Button
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
	# 1. Slider'ı güncelle
	if field and field.playing and time_panel and time_panel.visible:
		time_slider.set_value_no_signal(field.play_t)
		if field.play_t >= time_slider.max_value - 0.05:
			result_center.visible = true
			btn_pause.text = S.t("CTRL_PAUSE")
			
	# 2. İkonları HUD Kartının Altına Kilitle
	if btn_info_icon != null and btn_info_icon.visible and hud_card != null:
		btn_info_icon.position = Vector2(24, hud_card.position.y + hud_card.size.y + 15)
		
		# Grafikler butonu "i" ikonunun hemen sağında çıksın
		# Grafikler butonu "i" ikonunun hemen sağında çıksın
		if btn_graph_icon != null:
			# Eğer Teşekkür ekranı (thanks_center) görünürse, butonu ZORLA gizle
			var can_show_graph = field and (field.playing or field.finished or time_panel.visible) and not thanks_center.visible
			btn_graph_icon.visible = sim_cfg.show_kinematic_graphs and can_show_graph
			if btn_graph_icon.visible:
				btn_graph_icon.position = Vector2(btn_info_icon.position.x + btn_info_icon.size.x + 10, btn_info_icon.position.y)

	# 3. Zaman Metnini Güncelle
	if time_lbl:
		time_lbl.visible = sim_cfg.show_time_display
		if field and time_panel.visible:
			var display_t = field.play_t
			if sim_cfg.display_real_time and field.time_scale > 0.0:
				display_t = field.play_t / field.time_scale
			time_lbl.text = "%.2f s" % display_t
			
	# 4. Grafikler Açıksa Canlı Olarak Her Şeyi Güncelle
	if graph_panel and graph_panel.visible:
		var active_tab = graph_tabs.get_current_tab_control()
		if active_tab:
			if active_tab.name == "Hepsi":
				for child in active_tab.get_child(0).get_children():
					child.queue_redraw()
			else:
				active_tab.queue_redraw()
			
		if mini_view:
			mini_view.queue_redraw()
			
		if pop_slider and field.has_method("get_flight_duration"):
			if pop_slider.max_value != field.get_flight_duration():
				pop_slider.max_value = field.get_flight_duration()
			pop_slider.set_value_no_signal(field.play_t)
			
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
	_build_graphs() # Grafik panelini arka planda inşa et
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
	v.add_child(_label("···  gerçek yörünge", 12, Physics.cfg.real_path_color))
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
	
	# --- YENİ EKLENEN: GRAFİK POP-UP BUTONU ---
	btn_graph_icon = Button.new()
	btn_graph_icon.text = "Grafikler"
	btn_graph_icon.custom_minimum_size = Vector2(90, 40)
	_style_button(btn_graph_icon, CARD, Color("f59e0b"), Color(1, 1, 1, 0.1))
	btn_graph_icon.visible = false
	btn_graph_icon.z_index = 50 # Bütün pop-up'ların ve şeffaf katmanların ÜSTÜNDE durmasını sağlar
	btn_graph_icon.pressed.connect(_on_graph_icon_clicked)
	add_child(btn_graph_icon)
	
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
	result_center.mouse_filter = Control.MOUSE_FILTER_IGNORE # Tıklamaların alt katmandaki butonlara (Grafikler vb.) geçmesine izin verir!
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
	# Zaman çubuğunu ve bilgi ikonunu bitiş ekranında temizle
	if time_panel:
		time_panel.visible = false
	if btn_info_icon:
		btn_info_icon.visible = false
	if btn_graph_icon:
		btn_graph_icon.visible = false
	if graph_panel:
		graph_panel.visible = false # Açık unutulmuşsa dev grafik panelini de kapatır

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
	# Arka plan CARD2 (Gri), Yazı rengi Inspector'dan
	_style_button(btn_start, CARD2, sim_cfg.btn_replay_text, Color(sim_cfg.btn_replay_text, 0.55))
	btn_start.pressed.connect(_on_replay_or_run)
	h.add_child(btn_start)
	btn_start.visible = sim_cfg.show_replay_button

	btn_pause = Button.new()
	btn_pause.text = S.t("CTRL_PAUSE")
	btn_pause.custom_minimum_size = Vector2(120, 40)
	_style_button(btn_pause, CARD2, sim_cfg.btn_pause_text, Color(sim_cfg.btn_pause_text, 0.55))
	btn_pause.pressed.connect(_on_pause_toggle)
	h.add_child(btn_pause)
	
	# --- YENİ EKLENEN: SONA GİT BUTONU ---
	btn_fast_forward = Button.new()
	btn_fast_forward.text = "Sona Git"
	btn_fast_forward.custom_minimum_size = Vector2(100, 40)
	_style_button(btn_fast_forward, CARD2, sim_cfg.btn_fast_forward_text, Color(sim_cfg.btn_fast_forward_text, 0.55))
	btn_fast_forward.pressed.connect(_on_fast_forward)
	h.add_child(btn_fast_forward)
	btn_fast_forward.visible = sim_cfg.show_fast_forward_button
	# ------------------------------------
	
	btn_reset = Button.new()
	btn_reset.text = S.t("CTRL_RESET")
	btn_reset.custom_minimum_size = Vector2(120, 40)
	_style_button(btn_reset, CARD2, sim_cfg.btn_reset_text, Color(sim_cfg.btn_reset_text, 0.55))
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
	# Zamanı gösteren metin (Slider'ın sağ tarafına eklenir)
	time_lbl = _label("0.00 s", 14, ACCENT)
	time_lbl.custom_minimum_size = Vector2(50, 0)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_slider_box.add_child(time_lbl)
	# ----------------------------------------------------------------
	
	# --- AYARLAR: giriş animasyonu ve ses aç/kapa ---
	btn_anim = Button.new()
	btn_anim.custom_minimum_size = Vector2(150, 40)
	btn_anim.pressed.connect(_on_toggle_anim)
	h.add_child(btn_anim)
	btn_anim.visible = sim_cfg.show_anim_button
	btn_sound = Button.new()
	btn_sound.custom_minimum_size = Vector2(120, 40)
	btn_sound.pressed.connect(_on_toggle_sound)
	h.add_child(btn_sound)
	_refresh_toggle_buttons()

## Alt çubuktaki "Tekrar": uçuş BİTTİYSE aynı seçimi yeniden oynatır (yeni bir
## deneme KAYDEDİLMEZ — araştırma verisi şişmesin); henüz uçuş yoksa normal
## atışı başlatır. Eskiden bu düğme her basışta _on_run çağırıyordu.
func _on_replay_or_run() -> void:
	# Eğer uçuş bittiyse VEYA şu an top havadaysa (playing), aynı uçuşu başa sar
	if field and (field.finished or field.playing):
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
		var col_a = sim_cfg.btn_toggle_on_text if anim_enabled else sim_cfg.btn_toggle_off_text
		_style_button(btn_anim, CARD2, col_a, Color(col_a, 0.55))
	if btn_sound:
		btn_sound.text = S.t("CTRL_SOUND_ON") if sound_enabled else S.t("CTRL_SOUND_OFF")
		var col_s = sim_cfg.btn_toggle_on_text if sound_enabled else sim_cfg.btn_toggle_off_text
		_style_button(btn_sound, CARD2, col_s, Color(col_s, 0.55))
		
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
	btn_start.visible = sim_cfg.show_replay_button # Inspector ayarını dinler
	btn_start.disabled = (sim_cfg.lock_controls_until_answered and attempt == 0)
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
	btn_start.visible = sim_cfg.show_replay_button 
	btn_start.disabled = false         # ARTIK KİLİTLİ DEĞİL: Uçuş sırasında da tıklanabilir
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
	_update_control_bar_lock() # Yeni kullanıcı girdiği an alt çubuğu kilitle
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
	btn_start.disabled = (sim_cfg.lock_controls_until_answered and attempt == 0)
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
	_update_control_bar_lock() # Öğrenci cevabını verdi, kilidi tamamen kaldır
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
	
	# Uçuş bittiğinde Tekrar butonunu tıklanabilir hale getir
	if btn_start:
		btn_start.disabled = false
		
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
	if time_panel:
		time_panel.visible = false
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

func _on_graph_icon_clicked() -> void:
	if not graph_panel: return
	graph_panel.visible = not graph_panel.visible
	if graph_panel.visible:
		# Açıldığında ekranın tam ortasında şık bir pop-up olarak belirmesini sağla
		graph_panel.global_position = (size - graph_panel.size) / 2.0

func _on_fast_forward() -> void:
	# Eğer uçuş devam ediyorsa zamanı uçuşun en sonuna ışınla
	if field and field.playing:
		if field.has_method("get_flight_duration"):
			# Bitmesine milisaniyeler kala bırakıyoruz ki motor doğal bitiş sinyallerini tetikleyebilsin
			field.play_t = field.get_flight_duration() - 0.01
			
func _redraw_all_graphs(_dummy = null) -> void:
	if graph_panel and graph_panel.visible:
		var active_tab = graph_tabs.get_current_tab_control()
		if active_tab:
			if active_tab.name == "Hepsi":
				for child in active_tab.get_child(0).get_children():
					child.queue_redraw()
			else:
				active_tab.queue_redraw()

func _build_graphs() -> void:
	graph_panel = PanelContainer.new()
	graph_panel.add_theme_stylebox_override("panel", _card_style(16, Color(0.1, 0.11, 0.14, 0.98)))
	graph_panel.custom_minimum_size = Vector2(960, 560) # Dev boyuta çıkarıldı
	graph_panel.visible = false
	graph_panel.z_index = 55
	add_child(graph_panel)

	var outer_v = VBoxContainer.new()
	outer_v.add_theme_constant_override("separation", 12)
	graph_panel.add_child(outer_v)
	
	# Üst Bar (Başlık ve Kapatma Butonu)
	var top_h = HBoxContainer.new()
	var title = _label("Kinematik Grafikler ve Laboratuvar İncelemesi", 18, TXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 30)
	_style_button(close_btn, CARD2, DANGER)
	close_btn.pressed.connect(func(): graph_panel.visible = false)
	top_h.add_child(close_btn)
	outer_v.add_child(top_h)
	
	# X, Y ve Net Seçim Filtreleri
	var toggle_row = HBoxContainer.new()
	toggle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_row.add_theme_constant_override("separation", 30)
	
	var chk_x = CheckBox.new(); chk_x.text = "X (Yatay) Ekseni"; chk_x.button_pressed = show_graph_x
	var chk_y = CheckBox.new(); chk_y.text = "Y (Dikey) Ekseni"; chk_y.button_pressed = show_graph_y
	var chk_net = CheckBox.new(); chk_net.text = "Net (Bileşke)"; chk_net.button_pressed = show_graph_net
	
	chk_x.add_theme_color_override("font_color", Color("f59e0b"))
	chk_y.add_theme_color_override("font_color", Color("a855f7"))
	chk_net.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	
	chk_x.toggled.connect(func(on): show_graph_x = on; _redraw_all_graphs())
	chk_y.toggled.connect(func(on): show_graph_y = on; _redraw_all_graphs())
	chk_net.toggled.connect(func(on): show_graph_net = on; _redraw_all_graphs())
	
	toggle_row.add_child(chk_x); toggle_row.add_child(chk_y); toggle_row.add_child(chk_net)
	outer_v.add_child(toggle_row)

	# Orta Bölüm (Sol: Grafikler, Sağ: Mini-Görünüm)
	var main_h = HBoxContainer.new()
	main_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_h.add_theme_constant_override("separation", 15)
	outer_v.add_child(main_h)

	# Sol Taraf: Grafik Sekmeleri
	graph_tabs = TabContainer.new()
	graph_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_tabs.add_theme_font_size_override("font_size", 14)
	var sbt = StyleBoxFlat.new()
	sbt.bg_color = Color(0, 0, 0, 0)
	graph_tabs.add_theme_stylebox_override("panel", sbt)
	main_h.add_child(graph_tabs)

	var graph_names = ["Konum-Zaman", "Hız-Zaman", "İvme-Zaman", "Kuvvet-Zaman"]
	for g_name in graph_names:
		var c = Control.new()
		c.name = g_name
		c.draw.connect(_on_draw_graph.bind(c))
		graph_tabs.add_child(c)
		
	# Hepsi (4'lü Izgara) Sekmesi
	var hepsi_tab = MarginContainer.new()
	hepsi_tab.name = "Hepsi"
	hepsi_tab.add_theme_constant_override("margin_top", 10)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	hepsi_tab.add_child(grid)
	
	for g_name in graph_names:
		var mini_c = Control.new()
		mini_c.name = "Hepsi_" + g_name
		mini_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mini_c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mini_c.draw.connect(_on_draw_graph.bind(mini_c))
		grid.add_child(mini_c)
		
	graph_tabs.add_child(hepsi_tab)
		
	# Sağ Taraf: Mini Simülasyon Görünümü
	var right_v = VBoxContainer.new()
	right_v.custom_minimum_size = Vector2(300, 0)
	main_h.add_child(right_v)
	
	right_v.add_child(_label("Simülasyon (Anlık İzleme)", 13, TXT_MUTED))
	mini_view = Control.new()
	mini_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mini_view.draw.connect(_on_draw_mini_view)
	right_v.add_child(mini_view)

	# Alt Bölüm: Entegre Zaman Kaydırıcısı (Slider)
	var slider_row = HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 10)
	outer_v.add_child(slider_row)
	
	slider_row.add_child(_label("Zaman:", 14, TXT_MUTED))
	pop_slider = HSlider.new()
	pop_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pop_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pop_slider.step = 0.02
	pop_slider.value_changed.connect(_on_time_scrub)
	slider_row.add_child(pop_slider)

func _on_draw_graph(c: Control) -> void:
	if not field or field.predicted.is_empty(): return
	
	# GÜVENLİK KONTROLÜ: Ekran yerleşmeden önce eksi boyutlu (hatalı) çizimleri engelle
	if c.size.x <= 55 or c.size.y <= 45: return 
	
	var is_pos = "Konum" in c.name
	var is_vel = "Hız" in c.name
	var is_acc = "İvme" in c.name
	var is_frc = "Kuvvet" in c.name
	var is_hepsi = "Hepsi" in c.name

	# Eksen sayılarına yer açmak için sol taraftan pay (padding) bırakıyoruz
	var rect = Rect2(45, 20, c.size.x - 55, c.size.y - 45)
	c.draw_rect(rect, Color(0, 0, 0, 0.3)) 

	var pts = field.predicted
	var max_t = pts[-1]["t"]
	if max_t <= 0: return

	# 1. ADIM: TEMEL VERİLERİ (Zaman ve Konum) ÇEK
	var t_arr = []
	var x_arr = []
	var y_arr = []
	for pt in pts:
		t_arr.append(pt["t"])
		x_arr.append(pt["p"].x)
		# Fizikte Y yukarı doğrudur. Godot'taki gibi eksi ile çarpmıyoruz!
		y_arr.append(pt["p"].y) 
		
	# 2. ADIM: MERKEZİ FARK (TÜREV) FONKSİYONU
	var get_deriv = func(vals: Array, times: Array) -> Array:
		var deriv = []
		var n = vals.size()
		for i in range(n):
			if i == 0 and n > 1:
				var dt = times[1] - times[0]
				deriv.append((vals[1] - vals[0]) / dt if dt > 0 else 0.0)
			elif i == n - 1 and n > 1:
				var dt = times[i] - times[i-1]
				deriv.append((vals[i] - vals[i-1]) / dt if dt > 0 else 0.0)
			else:
				# Ortadaki noktalar için Merkezi Türev (Daha pürüzsüz sonuç verir)
				var dt = times[i+1] - times[i-1]
				deriv.append((vals[i+1] - vals[i-1]) / dt if dt > 0 else 0.0)
		return deriv
		
	# 3. ADIM: ZİNCİRLEME TÜREV AL (Matematiksel Kanıt)
	var vx_arr = get_deriv.call(x_arr, t_arr) # v = dx/dt
	var vy_arr = get_deriv.call(y_arr, t_arr) 
	
	var ax_arr = get_deriv.call(vx_arr, t_arr) # a = dv/dt
	var ay_arr = get_deriv.call(vy_arr, t_arr)

	var vals_x = PackedVector2Array()
	var vals_y = PackedVector2Array()
	var vals_net = PackedVector2Array()
	var min_val = 0.0; var max_val = 0.0001

	var mass = 0.43 # Topun Ortalama Kütlesi (F = m*a için)

	for i in range(pts.size()):
		var t = t_arr[i]
		var vx = 0.0; var vy = 0.0

		if is_pos:
			vx = x_arr[i]; vy = y_arr[i]
		elif is_vel:
			vx = vx_arr[i]; vy = vy_arr[i]
		elif is_acc:
			vx = ax_arr[i]; vy = ay_arr[i]
		elif is_frc: # F = m * a
			vx = ax_arr[i] * mass; vy = ay_arr[i] * mass

		var vnet = sqrt(vx*vx + vy*vy) # Bileşke (Net) Büyüklük
		
		# Skalayı (Eksen limitlerini) sadece aktif olan filtrelere göre ayarla
		var active_vals = []
		if show_graph_x: active_vals.append(vx)
		if show_graph_y: active_vals.append(vy)
		if show_graph_net: active_vals.append(vnet)
		if active_vals.is_empty(): active_vals.append(0.0)
			
		var local_min = active_vals[0]
		var local_max = active_vals[0]
		for val in active_vals:
			local_min = minf(local_min, val)
			local_max = maxf(local_max, val)

		# Ani sekme/vuruş fırlamalarını (spike) sınırla ki grafik ezilmesin
		if is_acc:
			local_min = clampf(local_min, -40.0, 40.0)
			local_max = clampf(local_max, -40.0, 40.0)
		elif is_frc:
			local_min = clampf(local_min, -20.0, 20.0)
			local_max = clampf(local_max, -20.0, 20.0)

		if i == 0:
			min_val = local_min; max_val = local_max
		else:
			min_val = minf(min_val, local_min); max_val = maxf(max_val, local_max)
			
		# Sadece Zaman Kaydırıcısına (Slider) kadar olan kısmı çiz
		if t <= field.play_t:
			var nx = t / max_t
			vals_x.append(Vector2(nx, vx))
			vals_y.append(Vector2(nx, vy))
			vals_net.append(Vector2(nx, vnet))

	var r = max_val - min_val
	if r == 0: r = 1.0
	min_val -= r * 0.1; max_val += r * 0.1; r = max_val - min_val

	var f = get_theme_default_font()
	
	# Y Ekseni Etiketleri (Sayılar)
	if f:
		c.draw_string(f, Vector2(0, rect.position.y + 10), "%.1f" % max_val, HORIZONTAL_ALIGNMENT_RIGHT, 38, 11, Color(1,1,1,0.6))
		c.draw_string(f, Vector2(0, rect.position.y + rect.size.y), "%.1f" % min_val, HORIZONTAL_ALIGNMENT_RIGHT, 38, 11, Color(1,1,1,0.6))

	# Sıfır Çizgisi
	var zero_y = rect.position.y + rect.size.y
	if min_val < 0 and max_val > 0:
		zero_y = rect.position.y + rect.size.y * (1.0 - (0.0 - min_val) / r)
		c.draw_line(Vector2(rect.position.x, zero_y), Vector2(rect.position.x + rect.size.x, zero_y), Color(1, 1, 1, 0.4), 1.0)
		if f:
			c.draw_string(f, Vector2(0, zero_y + 4), "0", HORIZONTAL_ALIGNMENT_RIGHT, 38, 11, Color(1,1,1,0.6))

	# Çizgileri Çizme Yardımcısı
	var draw_line_arrays = func(arr, color, thickness):
		var poly = PackedVector2Array()
		for i in range(arr.size()):
			var px = rect.position.x + arr[i].x * rect.size.x
			# Grafik dışına taşmayı engelle
			var clamped_y = clampf(arr[i].y, min_val, max_val)
			var py = rect.position.y + rect.size.y * (1.0 - (clamped_y - min_val) / r)
			poly.append(Vector2(px, py))
		if poly.size() > 1:
			c.draw_polyline(poly, color, thickness, true)
			
	if show_graph_x: draw_line_arrays.call(vals_x, Color("f59e0b"), 2.0)
	if show_graph_y: draw_line_arrays.call(vals_y, Color("a855f7"), 2.0)
	if show_graph_net: draw_line_arrays.call(vals_net, Color(1, 1, 1, 0.8), 2.5)

	# Dikey Zaman İşaretçisi (Slider'ı takip eder)
	var marker_x = rect.position.x + (field.play_t / max_t) * rect.size.x
	c.draw_line(Vector2(marker_x, rect.position.y), Vector2(marker_x, rect.position.y + rect.size.y), Color.WHITE, 1.5)

	# X Ekseni Etiketleri (Zaman)
	if f:
		c.draw_string(f, Vector2(rect.position.x, rect.position.y + rect.size.y + 14), "0s", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1,1,1,0.6))
		c.draw_string(f, Vector2(rect.position.x + rect.size.x - 20, rect.position.y + rect.size.y + 14), "%.1fs" % max_t, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(1,1,1,0.6))
		
	# Hepsi sekmesindeysek küçük başlıklar ekle
	if is_hepsi and f:
		var title_str = c.name.replace("Hepsi_", "")
		c.draw_string(f, Vector2(rect.position.x + 8, rect.position.y + 16), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1,1,1,0.8))
	# --- FARE İLE ÜZERİNE GELİNCE (HOVER) DEĞERLERİ GÖSTERME ---
	var mpos = c.get_local_mouse_position()
	
	# Eğer fare grafiğin (dikdörtgenin) içindeyse değerleri hesapla
	if rect.has_point(mpos):
		# Farenin X konumuna denk gelen zamanı (t) bul
		var hover_nx = clampf((mpos.x - rect.position.x) / rect.size.x, 0.0, 1.0)
		var hover_t = hover_nx * max_t
		
		# Veri listemizdeki bu zamana en yakın noktayı bul
		var closest_i = 0
		var min_diff = 9999.0
		for i in range(t_arr.size()):
			var diff = absf(t_arr[i] - hover_t)
			if diff < min_diff:
				min_diff = diff
				closest_i = i
				
		# Sadece simülasyonun o ana kadar oynatılmış kısımlarını göster
		if t_arr[closest_i] <= field.play_t:
			var h_t = t_arr[closest_i]
			var h_vx = 0.0; var h_vy = 0.0
			
			if is_pos: h_vx = x_arr[closest_i]; h_vy = y_arr[closest_i]
			elif is_vel: h_vx = vx_arr[closest_i]; h_vy = vy_arr[closest_i]
			elif is_acc: h_vx = ax_arr[closest_i]; h_vy = ay_arr[closest_i]
			elif is_frc: h_vx = ax_arr[closest_i] * mass; h_vy = ay_arr[closest_i] * mass
			
			var h_net = sqrt(h_vx*h_vx + h_vy*h_vy)
			
			# İmleç Çizgisi ve Yuvarlağı
			var marker_px = rect.position.x + (h_t / max_t) * rect.size.x
			c.draw_line(Vector2(marker_px, rect.position.y), Vector2(marker_px, rect.position.y + rect.size.y), Color(1, 1, 1, 0.3), 1.0, true)
			c.draw_circle(Vector2(marker_px, mpos.y), 4.0, Color.WHITE)
			c.draw_arc(Vector2(marker_px, mpos.y), 6.0, 0, TAU, 12, Color(1, 1, 1, 0.5), 1.5)
			
			# Bilgi Kutucuğunu Çiz (Tooltip)
			if f:
				var lines = ["Zaman: %.2f s" % h_t]
				var colors = [Color.WHITE]
				
				if show_graph_x:
					lines.append("X: %.1f" % h_vx)
					colors.append(Color("f59e0b"))
				if show_graph_y:
					lines.append("Y: %.1f" % h_vy)
					colors.append(Color("a855f7"))
				if show_graph_net:
					lines.append("Net: %.1f" % h_net)
					colors.append(Color(1, 1, 1, 0.9))
					
				var box_w = 110.0
				var box_h = lines.size() * 18 + 10
				var box_p = Vector2(mpos.x + 15, mpos.y + 15)
				
				# Kutu ekranın sağından veya altından taşmasın diye sınır kontrolü
				if box_p.x + box_w > rect.position.x + rect.size.x:
					box_p.x = mpos.x - box_w - 15
				if box_p.y + box_h > rect.position.y + rect.size.y:
					box_p.y = mpos.y - box_h - 15
					
				# Arka Plan
				c.draw_rect(Rect2(box_p, Vector2(box_w, box_h)), Color(0.05, 0.05, 0.07, 0.95), true)
				c.draw_rect(Rect2(box_p, Vector2(box_w, box_h)), Color(1, 1, 1, 0.15), false, 1.0)
				
				# Yazılar
				for i in range(lines.size()):
					c.draw_string(f, Vector2(box_p.x + 10, box_p.y + 18 + i * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, colors[i])
		
func _on_draw_mini_view() -> void:
	if not field or field.predicted.is_empty(): return
	var c = mini_view
	var rect = Rect2(0, 0, c.size.x, c.size.y)
	
	c.draw_rect(rect, Color(0, 0, 0, 0.25), true) 
	c.draw_rect(rect, Color(1, 1, 1, 0.08), false, 1.0) 
	
	var pts = field.predicted
	var max_x = 0.001; var max_y = 0.001
	for pt in pts:
		max_x = maxf(max_x, pt["p"].x)
		max_y = maxf(max_y, pt["p"].y)
		
	max_x = maxf(max_x, Physics.cfg.goal_x + 5.0) 
	max_y = maxf(max_y, 10.0) 
	
	var pad = 15.0
	var scale_f = minf((c.size.x - pad*2) / max_x, (c.size.y - pad*2) / max_y)
	var origin = Vector2(pad, c.size.y - pad)
	
	c.draw_line(Vector2(0, origin.y), Vector2(c.size.x, origin.y), Color(1, 1, 1, 0.2), 1.0)
	
	var gx = origin.x + Physics.cfg.goal_x * scale_f
	var gw = maxf(2.0 * scale_f, 4.0) 
	c.draw_rect(Rect2(gx, origin.y - 12, gw, 12), Color(1, 1, 1, 0.5))
	
	var poly_full = PackedVector2Array(); var poly_active = PackedVector2Array()
	
	for pt in pts:
		var p = origin + Vector2(pt["p"].x * scale_f, -pt["p"].y * scale_f)
		poly_full.append(p)
		if pt["t"] <= field.play_t:
			poly_active.append(p)
			
	if poly_full.size() > 1:
		c.draw_polyline(poly_full, Color(1, 1, 1, 0.15), 1.5, true)
		
	if poly_active.size() > 1:
		c.draw_polyline(poly_active, Color("f59e0b"), 2.0, true)
		
	if poly_active.size() > 0:
		c.draw_circle(poly_active[-1], 4.0, Color.WHITE)
		c.draw_arc(poly_active[-1], 7.0, 0, TAU, 16, Color("f59e0b"), 1.5)

func _update_control_bar_lock() -> void:
	if not control_bar: return
	
	# Ayar aktifse ve henüz hiç cevap verilmediyse (ilk denemeyse) kilitle
	var locked = sim_cfg.lock_controls_until_answered and attempt == 0
	
	if btn_pause: btn_pause.disabled = locked
	if btn_reset: btn_reset.disabled = locked
	if btn_fast_forward: btn_fast_forward.disabled = locked
	if btn_anim: btn_anim.disabled = locked
	if btn_sound: btn_sound.disabled = locked
	if time_slider:
		time_slider.editable = not locked
		
	# Kilitliyken çubuğu yarı saydam (%50 şeffaf) yaparak tıklanmaz olduğunu görselleştir
	control_bar.modulate.a = 0.5 if locked else 1.0
