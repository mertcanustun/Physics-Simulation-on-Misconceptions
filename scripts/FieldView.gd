class_name FieldView
extends Control
## Sahne çizimi: zemin, oyuncu, YERE SERİLİ HEDEF TAHTASI (dart), top,
## tahmin yörüngesi (yeşil düz), GERÇEK yörünge (noktalı, üstte) ve
## GERÇEK yörüngeyle senkron hareket eden SOLUK TOP (ghost ball).

signal flight_finished
signal intro_done          # koşu-vuruş animasyonu bitti (soru gösterilebilir)
signal pre_kick            # ayak topa değdi (küçük sıçrama) — Main burada vuruş sesini çalar
signal target_hit          # GOL (alkış sesi)
signal speed_report(speed: float, vx: float, vy: float)   # sol HUD kartı için
signal altitude_report(alt_m: float, in_space: bool)   # Main burada rüzgar sesini yönetir

# --- sahne ölçüleri ---
## Vuruş noktası (px, soldan). MADDE 9 (kısmî): sabit 330 px dar telefonlarda
## ekranın ortasına düşüyor ve topun uçacağı yer kalmıyordu. Artık ekran
## genişliğine oranlı, ama sol HUD kartını kapatmayacak kadar sağda.
const ORIGIN_X_MAX := 330.0
const ORIGIN_X_MIN := 168.0
const RIGHT_MARGIN := 40.0
const DEFAULT_SPAN_M := 70.0 # zoom=1'de görünen yatay mesafe (m)

# --- KALE / GOL: bkz. res://config/sim_config.tres (Physics.cfg.goal_x vb.) ---
var target_x := 37.0          # doğru fiziğin indiği nokta (kale içi) — reset()'te güncellenir

# --- oynatma hızı: bkz. res://config/sim_config.tres (Physics.cfg.time_scale) ---
var time_scale := Physics.cfg.time_scale
var paused := false          # "Durdur" düğmesi

# --- kuvvet okları: bkz. res://config/sim_config.tres (Physics.cfg.arrow_scale vb.) ---

# --- hız vektörü ---
const VEL_SCALE := 3.4
const VEL_MAX := 135.0
const C_VEL := Color("111827")
const C_VX := Color("f59e0b")    # yatay hız bileşeni (vx)
const C_VY := Color("a855f7")    # dikey hız bileşeni (vy)
const C_COMP := Color("111827")
# APEX_VY eşiği: bkz. res://config/sim_config.tres (Physics.cfg.apex_vy)

# --- yörünge renkleri: bkz. res://config/sim_config.tres (Physics.cfg.predicted_path_color vb.) ---
const C_GHOST := Color(0.88, 0.91, 0.94) # soluk top

var predicted: Array = []
var real: Array = []
var real_landed := false
var playing := false
var finished := false
var play_t := 0.0
var trail: PackedVector2Array = []
var apex_flash := 0.0
var apex_seen := false
var hit_bulls := false
var impact_x := -1.0
var end_msg_t := 0.0         # "Simülasyon bitmiştir" mesajı için

# --- kuvvet durumu (ok çizimi) ---
var f_gravity := false
var f_kick := false
var f_air := false
var f_drag := 0.012
var f_impetus: float = Physics.cfg.impetus_acc
var pv_active := false

# --- kamera: TÜM SAHNEYİ kapsayan sabit uzaklaştırma (nokta takibi YOK) ---
var cam_zoom := 1.0
var cam_shift := 0.0         # dikey kaydırma (m)
# START_ZOOM/SPACE_START_M/SPACE_FULL_M: bkz. res://config/sim_config.tres
# (Physics.cfg.camera_start_zoom, .space_start_m, .space_full_m)
var space_f := 0.0           # 0=mavi gökyüzü, 1=uzay
var offscreen_t := 0.0       # top görünür alan dışında ne kadar kaldı (sn)
var fit_zoom := 1.0          # uçuş sonunda ulaşılacak uzaklaşma oranı
var zoom_prog := 0.0         # kamera ilerleme oranı — MONOTON (geri gitmez, bkz. madde 12)
var fit_maxx := 70.0
var fit_maxy := 20.0

# --- giriş animasyonu ---
const INTRO_DUR := 1.25
var intro_active := false
var intro_t := 0.0
# ayak topa değdi ama gerçek uçuş henüz yok: top küçük bir sıçrama yapar
# (vuruş sesini görsel olarak justify etmek için), sonra soru popup'ı açılır.
# süre: bkz. res://config/sim_config.tres (Physics.cfg.question_delay_s)
var prekick_active := false
var prekick_t := 0.0
var kick_hold := false
var kick_follow := false
var kick_follow_t := 0.0
const KICK_FOLLOW_DUR := 0.30

const MESSI := [
	"...HHHHH...",
	"..HHHHHHH..",
	".HHKKKKKHH.",
	".HKKKKKKKH.",
	".HKKKKKKKH.",
	"..KEKKKEK..",
	"..KKKKKKK..",
	"..BKKKKKB..",
	"..BBBBBBB..",
	"..WLWLWLW..",
	".LWLWLWLWL.",
	".LWLWLWLWL.",
	".LWLWLWLWL.",
	".LWLWLWLWL.",
	".LWLWLWLWL.",
	".LWLWLWLWL.",
	"..DDDDDDD..",
	"..DDDDDDD..",
	"..DD...DD..",
	"..KK...KK..",
	"..KK...KK..",
	"..SS...SS..",
	"..SS...SS..",
	"..SS...SS..",
	"..OO...OO..",
]
var sp_idle: Array = []
var sp_run: Array = []
var sp_kick: Array = []
var sp_ref_h := 0.0
var ball_tex: Texture2D = null
var ball_rect := Rect2()
var confetti: Array = []
var shake_t := 0.0
var shake_off := Vector2.ZERO
var stars: PackedVector2Array = []
@onready var S: StringsData = get_node("/root/Strings")   # KOD YAZMADAN düzenlenebilir metinler (bkz. Strings.gd)

func _ready() -> void:
	set_process(true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260723
	for i in range(60):
		stars.append(Vector2(rng.randf(), rng.randf() * 0.72))
	var crng := RandomNumberGenerator.new()
	crng.seed = 20260807
	sp_idle = _load_frames("res://assets/sprites/player/idle", 4)
	sp_run = _load_frames("res://assets/sprites/player/run", 6)
	sp_kick = _load_frames("res://assets/sprites/player/kick", 7)
	if not sp_idle.is_empty():
		sp_ref_h = maxf(sp_idle[0]["rect"].size.y, 1.0)
	target_x = Physics.target_x()
	# ISINMA: ilk vuruştaki tek karelik takılmayı önler
	Physics.simulate(true, false, true)
	var wf := get_theme_default_font()
	if wf:
		wf.get_string_size("v = 00 m/s", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	if ResourceLoader.exists("res://assets/sprites/ball.png"):
		ball_tex = load("res://assets/sprites/ball.png") as Texture2D
		if ball_tex != null:
			var img := ball_tex.get_image()
			var ur := img.get_used_rect()
			ball_rect = Rect2(ur.position, ur.size) if ur.size.x > 0 else Rect2(Vector2.ZERO, ball_tex.get_size())

func _origin_x() -> float:
	return clampf(size.x * 0.26, ORIGIN_X_MIN, ORIGIN_X_MAX)

func _base_scale() -> float:
	return maxf((size.x - _origin_x() - RIGHT_MARGIN) / DEFAULT_SPAN_M, 1.0)

func _ground_y() -> float:
	return size.y * 0.80

func _world_to_px(p: Vector2) -> Vector2:
	var s := _base_scale() * cam_zoom
	var anchor := Vector2(_origin_x(), _ground_y()) + shake_off
	return anchor + Vector2(p.x * s, -(p.y - cam_shift) * s)

func set_forces(g: bool, k: bool, a: bool, drag_k: float, imp: float = Physics.cfg.impetus_acc) -> void:
	f_gravity = g
	f_kick = k
	f_air = a
	f_drag = drag_k
	f_impetus = imp

func set_preview(g: bool, k: bool, a: bool, drag_k: float, imp: float = Physics.cfg.impetus_acc) -> void:
	set_forces(g, k, a, drag_k, imp)
	pv_active = true
	queue_redraw()

## TÜM SAHNEYİ kapsayacak şekilde uzaklaştır: her iki yörünge de görünsün.
## (Tek bir noktaya odaklanma/kovalama YOK — sabit genel görünüm.)
func _fit_camera() -> void:
	# uçuş sonunda ulaşılacak "tam sığdırma" oranını hesapla; zoom buna
	# KADEMELİ olarak iner (top ilerledikçe futbolcu küçülür).
	var maxx := Physics.cfg.goal_x + 14.0
	var maxy := 8.0
	for arr in [predicted, real]:
		for pt in arr:
			var p: Vector2 = pt["p"]
			maxx = maxf(maxx, minf(p.x, 135.0))
			maxy = maxf(maxy, minf(p.y, 70.0))
	maxx += Physics.cfg.camera_margin_m
	maxy += Physics.cfg.camera_margin_m
	var avail_h_m := (_ground_y() - 70.0) / _base_scale()
	fit_zoom = clampf(minf(DEFAULT_SPAN_M / maxx, avail_h_m / maxy), Physics.cfg.camera_min_zoom, Physics.cfg.camera_max_zoom)
	fit_maxx = maxx
	fit_maxy = maxy
	cam_zoom = Physics.cfg.camera_start_zoom  # YAKINDAN başla: top uzaklaştıkça uzaklaş -> futbolcu KÜÇÜLÜR
	cam_shift = 0.0
	zoom_prog = 0.0

func start_flight(pred: Dictionary, real_res: Dictionary) -> void:
	predicted = pred["points"]
	impact_x = pred["impact_x"]
	real = real_res["points"]
	real_landed = real_res["landed"]
	trail = PackedVector2Array()
	play_t = 0.0
	playing = true
	finished = false
	paused = false
	pv_active = false
	apex_seen = false
	apex_flash = 0.0
	end_msg_t = 0.0
	var goal_depth_m := Physics.cfg.goal_depth_px / maxf(_base_scale(), 1.0)
	hit_bulls = impact_x > 0.0 and impact_x >= Physics.cfg.goal_x - 1.0 and impact_x <= Physics.cfg.goal_x + goal_depth_m + 2.0
	kick_hold = false
	kick_follow = true
	kick_follow_t = 0.0
	offscreen_t = 0.0
	confetti.clear()
	_fit_camera()
	queue_redraw()

func reset() -> void:
	predicted = []
	real = []
	trail = PackedVector2Array()
	playing = false
	finished = false
	paused = false
	pv_active = false
	intro_active = false
	prekick_active = false
	prekick_t = 0.0
	kick_hold = false
	kick_follow = false
	kick_follow_t = 0.0
	apex_seen = false
	apex_flash = 0.0
	end_msg_t = 0.0
	hit_bulls = false
	impact_x = -1.0
	confetti.clear()
	shake_t = 0.0
	shake_off = Vector2.ZERO
	cam_zoom = Physics.cfg.camera_start_zoom
	cam_shift = 0.0
	zoom_prog = 0.0
	space_f = 0.0
	offscreen_t = 0.0
	queue_redraw()

func start_intro() -> void:
	reset()
	intro_active = true
	intro_t = 0.0
	queue_redraw()

func set_paused(v: bool) -> void:
	paused = v

func _point_at(pts: Array, t: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	for i in range(pts.size() - 1):
		if pts[i + 1]["t"] >= t:
			var a: Dictionary = pts[i]
			var b: Dictionary = pts[i + 1]
			var f: float = clampf((t - a["t"]) / maxf(b["t"] - a["t"], 0.0001), 0.0, 1.0)
			return a["p"].lerp(b["p"], f)
	return pts[-1]["p"]

func _vel_at(pts: Array, t: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	for i in range(pts.size() - 1):
		if pts[i + 1]["t"] >= t:
			var a: Dictionary = pts[i]
			var b: Dictionary = pts[i + 1]
			var f: float = clampf((t - a["t"]) / maxf(b["t"] - a["t"], 0.0001), 0.0, 1.0)
			return a["v"].lerp(b["v"], f)
	return pts[-1]["v"]

func _process(delta: float) -> void:
	var animating := false
	var sdt := delta * time_scale
	if paused:
		sdt = 0.0
	if intro_active:
		intro_t += delta * time_scale
		animating = true
		if intro_t >= INTRO_DUR:
			intro_active = false
			prekick_active = true
			prekick_t = 0.0
			pre_kick.emit()   # ayak topa değdi: Main burada vuruş sesini çalar
	if prekick_active:
		prekick_t += delta * time_scale
		animating = true
		if prekick_t >= Physics.cfg.question_delay_s:
			prekick_active = false
			kick_hold = true
			intro_done.emit()   # şimdi soru popup'ı açılabilir
	if kick_follow:
		kick_follow_t += sdt
		animating = true
		if kick_follow_t >= KICK_FOLLOW_DUR:
			kick_follow = false
	if playing:
		play_t += sdt
		var last_t: float = predicted[-1]["t"] if not predicted.is_empty() else 0.0
		trail.append(_point_at(predicted, play_t))
		var vel := _vel_at(predicted, play_t)
		speed_report.emit(vel.length(), vel.x, vel.y)
		altitude_report.emit(trail[-1].y, space_f > 0.5)   # rüzgar sesi: "uzayda" değilken aktif
		# --- GENEL ZOOM OUT: topun kat ettiği yola göre tüm sahne uzaklaşır ---
		var bpos := _point_at(predicted, play_t)
		var prog := clampf(maxf(bpos.x / maxf(fit_maxx, 1.0), bpos.y / maxf(fit_maxy, 1.0)), 0.0, 1.0)
		# MADDE 12 — aşırı zoom in/out düzeltmesi:
		#   Eskiden `prog` doğrudan kullanılıyordu. Top TEPE NOKTASINI geçip
		#   alçalmaya başlayınca bpos.y küçülüyor -> prog düşüyor -> kamera geri
		#   YAKINLAŞIYOR, sonra yatayda ilerleyince tekrar uzaklaşıyordu. Sonuç:
		#   görünür "pompalama". Artık ilerleme geri gitmez (monoton) ve zoom
		#   saniyede en fazla camera_max_zoom_rate kadar değişir.
		if Physics.cfg.camera_zoom_monotonic:
			zoom_prog = maxf(zoom_prog, prog)
		else:
			zoom_prog = prog
		var want := lerpf(Physics.cfg.camera_start_zoom, fit_zoom, zoom_prog)
		var next_zoom := lerpf(cam_zoom, want, 1.0 - exp(-Physics.cfg.camera_smooth * delta))
		var max_step := Physics.cfg.camera_max_zoom_rate * delta
		cam_zoom = clampf(next_zoom, cam_zoom - max_step, cam_zoom + max_step)
		if not apex_seen and f_gravity and play_t > 0.15 and absf(vel.y) < Physics.cfg.apex_vy \
				and _point_at(predicted, play_t).y > 2.0:
			apex_seen = true
			apex_flash = 1.0
		if apex_flash > 0.0:
			apex_flash = maxf(apex_flash - delta * 0.55, 0.0)
		animating = true
		# --- EKRAN DIŞI: top görünür alanı terk ettiyse uçuşu bitir ---
		if not trail.is_empty():
			var bpx := _world_to_px(trail[-1])
			# MADDE 8 — "top ekrandan çıktı" koşulu:
			#   Eskiden tolerans ekran genişliğinin %20'si + 0.7 sn idi; top çoktan
			#   görünmez olduğu hâlde koşul geç tetikleniyor (bazı senaryolarda hiç
			#   tetiklenmiyor) ve öğrenci boş ekrana bakıyordu. Tolerans ve süre
			#   artık Inspector'dan (Oyun Alanı grubu) ayarlanabilir ve dar.
			var scr_rect := Rect2(Vector2.ZERO, size).grow(size.x * Physics.cfg.offscreen_margin)
			if scr_rect.has_point(bpx):
				offscreen_t = 0.0
			else:
				offscreen_t += delta
				if offscreen_t > Physics.cfg.offscreen_grace_s:
					play_t = last_t   # uçuşu sonlandır (sonuç zaten hesaplı)
		if play_t >= last_t:
			playing = false
			finished = true
			if hit_bulls:
				shake_t = 0.3
				_spawn_confetti(Vector2(size.x * 0.5, size.y * 0.28))
				target_hit.emit()
			flight_finished.emit()
	if finished:
		end_msg_t += delta
		animating = true
	if absf(space_f) > 0.005 and not playing and not finished:
		animating = true
	if shake_t > 0.0:
		shake_t = maxf(shake_t - delta, 0.0)
		shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_t * 14.0
		animating = true
	else:
		shake_off = Vector2.ZERO
	if not confetti.is_empty():
		for piece in confetti:
			piece["v"].y += 900.0 * delta
			piece["p"] += piece["v"] * delta
			piece["rot"] += delta * 6.0
			piece["life"] -= delta
		confetti = confetti.filter(func(c): return c["life"] > 0.0)
		animating = true
	if animating:
		queue_redraw()

func _draw() -> void:
	var ground_y := _ground_y() + (cam_shift * _base_scale() * cam_zoom)
	var grass_top := ground_y - size.y * 0.16
	# gökyüzü
	# GÖKYÜZÜ: TEK TON mavi. Top ekranı terk edecek kadar yükselirse
	# arka plan UZAY ortamına döner (yıldızlar + gezegenler belirir).
	var sky_h := maxf(grass_top, 0.0)
	var ball_alt := 0.0
	if (playing or finished) and not trail.is_empty():
		ball_alt = trail[trail.size() - 1].y
	var target_f := clampf((ball_alt - Physics.cfg.space_start_m) / maxf(Physics.cfg.space_full_m - Physics.cfg.space_start_m, 0.001), 0.0, 1.0)
	space_f = lerpf(space_f, target_f, 0.12)   # yumuşak geçiş (rüzgar sesi bunu kullanır)
	# MADDE 6 — SADE ARKA PLAN (varsayılan): düz mavi gökyüzü + düz yeşil çim.
	# Yıldız/gezegen/uzay geçişi yalnızca simple_background KAPALIYKEN çizilir.
	if Physics.cfg.simple_background:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, sky_h)), Physics.cfg.sky_color)
	else:
		var sky_col := Physics.cfg.sky_color.lerp(Color("0b1026"), space_f)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, sky_h)), sky_col)
		if space_f > 0.03 and sky_h > 8.0:
			for st in stars:
				var sp := Vector2(st.x * size.x, st.y * sky_h)
				draw_circle(sp, 1.2, Color(1, 1, 1, 0.85 * space_f))
			_draw_planets(sky_h, space_f)
	# çim: biçme şeritleri (koyu tasarıma uygun)
	if grass_top < size.y:
		draw_rect(Rect2(Vector2(0, grass_top), Vector2(size.x, size.y - grass_top)), Physics.cfg.grass_color)
	if ground_y >= 0.0 and ground_y < size.y:
		draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), Physics.cfg.ground_line_color, 2.0)
	# mesafe çizgileri (her 10 m) — uzaklığı okunur kılar
	var font := get_theme_default_font()
	var m := 10
	while m <= 130:
		var gx := _world_to_px(Vector2(float(m), 0.0)).x
		if gx > 0.0 and gx < size.x:
			draw_line(Vector2(gx, ground_y), Vector2(gx, ground_y + 7), Color(1, 1, 1, 0.35), 1.5)
			if font and m % 20 == 0:
				draw_string(font, Vector2(gx - 10, ground_y + 22), "%d m" % m,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
		m += 10
	_draw_goal()
	# --- oyuncu ---
	var o := _world_to_px(Vector2.ZERO)
	var pofs := Vector2(-38.0, 0.0)
	if intro_active:
		var p := clampf(intro_t / INTRO_DUR, 0.0, 1.0)
		var ep := 1.0 - pow(1.0 - p, 3.0)
		var offx := lerpf(-38.0 - 260.0, -38.0, ep)
		var bob := absf(sin(intro_t * 16.0)) * 8.0 * (1.0 - p)
		pofs = Vector2(offx, -bob)
	_draw_player(o + pofs)
	# --- 1) tahmin yörüngesi (yeşil, düz) ---
	if trail.size() > 1:
		var scr := PackedVector2Array()
		for wp in trail:
			scr.append(_world_to_px(wp))
		draw_polyline(scr, Physics.cfg.adj(Physics.cfg.predicted_path_color), Physics.cfg.adj_width(Physics.cfg.predicted_path_thickness), true)
	# --- 2) GERÇEK yörünge: NOKTALI ve yeşil yolun ÜSTÜNDE ---
	if (playing or finished) and real.size() > 1:
		_draw_dotted_real()
	# --- 3) SOLUK TOP (ghost): gerçek yörüngede, simülasyonla SENKRON ---
	if (playing or finished) and real.size() > 1:
		var gp := _world_to_px(_point_at(real, play_t))
		_draw_ghost_ball(gp)
	# --- 4) top + oklar (oklar topun ÖNÜNDE, TAM MERKEZDEN) ---
	if not trail.is_empty():
		var bp := _world_to_px(trail[trail.size() - 1])
		var vnow := _vel_at(predicted, play_t)
		_draw_ball(bp)
		if playing:
			_draw_force_arrows(bp, vnow)
			_draw_velocity(bp, vnow)
			_draw_speed_readout(bp, vnow)
	elif pv_active or intro_active or prekick_active:
		var b0 := _world_to_px(Vector2.ZERO) + Vector2(0, -10)
		if prekick_active:
			# ayak topa değdi: küçük bir sıçrama — vuruş sesini görsel olarak
			# justify eder ama gerçek uçuş DEĞİL (top aynı yere iner)
			var pk := clampf(prekick_t / Physics.cfg.question_delay_s, 0.0, 1.0)
			b0 += Vector2(6.0 * pk, -sin(PI * pk) * 16.0)
		_draw_ball(b0)
		if pv_active:
			var launch := Vector2(cos(deg_to_rad(Physics.cfg.angle_deg)), sin(deg_to_rad(Physics.cfg.angle_deg))) * Physics.cfg.v0
			_draw_force_arrows(b0, launch)
			_draw_velocity(b0, launch)
	# --- kuvvet renk anahtarı (MADDE 7) ---
	if Physics.cfg.force_legend and (playing or finished or pv_active):
		_draw_force_legend()
	# --- konfeti ---
	for piece in confetti:
		var col: Color = piece["c"]
		col.a = clampf(piece["life"], 0.0, 1.0)
		var r: float = piece["rot"]
		var u := Vector2(cos(r), sin(r)) * 6.0
		var w2 := Vector2(-u.y, u.x) * 0.55
		var pc: Vector2 = piece["p"]
		draw_colored_polygon(PackedVector2Array([pc - u - w2, pc + u - w2, pc + u + w2, pc - u + w2]), col)

## Uzay bandındaki gezegenler (ekran-sabit süsleme; kamera zoomundan etkilenmez).
## Basit prosedürel bulutlar (üst üste yumuşak daireler) — Physics.cfg.cloud_count/
## cloud_speed ile ayarlanır; top "uzaya" yaklaştıkça solar (a katsayısı ile).
func _draw_planets(sky_h: float, a: float) -> void:
	# halkalı gezegen (sağ üst)
	var c1 := Vector2(size.x * 0.84, sky_h * 0.15)
	var r1 := size.x * 0.028
	draw_circle(c1, r1, Color("e8b46a", a))
	draw_circle(c1 - Vector2(r1 * 0.3, r1 * 0.3), r1 * 0.72, Color("f2c88a", a))
	draw_set_transform(c1, -0.42, Vector2(1.0, 0.34))
	draw_arc(Vector2.ZERO, r1 * 1.7, 0, TAU, 40, Color("d9c9a8", 0.9 * a), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# kızıl gezegen
	var c2 := Vector2(size.x * 0.40, sky_h * 0.20)
	var r2 := size.x * 0.014
	draw_circle(c2, r2, Color("d1663f", a))
	draw_circle(c2 + Vector2(-r2 * 0.3, r2 * 0.2), r2 * 0.35, Color("b04f30", 0.8 * a))
	# ay
	var c3 := Vector2(size.x * 0.63, sky_h * 0.11)
	var r3 := size.x * 0.010
	draw_circle(c3, r3, Color("cfd6de", a))
	draw_circle(c3 + Vector2(r3 * 0.25, -r3 * 0.15), r3 * 0.30, Color("aab3bd", a))
	draw_circle(c3 + Vector2(-r3 * 0.35, r3 * 0.3), r3 * 0.22, Color("aab3bd", a))

## YERDEKİ HEDEF — kale ağzına serili yatay dart tahtası (basık elipsler).
## Merkezi, doğru fiziğin indiği nokta: doğru cevapta top tam ortaya düşer.
## KALE — rijit çerçeve + örgü ağ (gol olunca ağ topun girdiği yerden şişer).
func _draw_goal() -> void:
	var scored := hit_bulls and finished
	var score_t := end_msg_t
	var goal_h_m := (size.y * 0.28) / _base_scale()
	var g0 := _world_to_px(Vector2(Physics.cfg.goal_x, 0.0))          # ön-alt köşe
	var g1 := _world_to_px(Vector2(Physics.cfg.goal_x, goal_h_m))     # ön-üst köşe
	var top_y := g1.y
	var base_y := g0.y
	var goal_h_px := base_y - top_y
	var depth := Physics.cfg.goal_depth_px * cam_zoom
	# gol anında ağ şişmesi: hızlı geri itilir, sönümlü salınımla dinginleşir
	var bulge := 0.0
	if scored:
		bulge = exp(-score_t * 1.7) * (32.0 + 10.0 * cos(score_t * 16.0)) * cam_zoom
	# şişme topun girdiği yükseklikte en fazla (file cebi orada oluşur)
	var hit_y := (_world_to_px((trail[trail.size() - 1] if not trail.is_empty() else Vector2.ZERO)).y if not trail.is_empty() else base_y - goal_h_px * 0.15)
	var spread := maxf(goal_h_px * 0.30, 1.0)
	var mesh := Color(1, 1, 1, 0.42)
	var cols := 5
	var rows := 8
	# yatay örgü çizgileri — topun hizasında geri (sağa) doğru şişer
	for j in range(rows + 1):
		var yy := lerpf(top_y, base_y, float(j) / rows)
		var bxj := g0.x + depth + bulge * exp(-pow((yy - hit_y) / spread, 2.0))
		var hp := PackedVector2Array()
		for i in range(cols + 1):
			hp.append(Vector2(lerpf(g0.x, bxj, float(i) / cols), yy))
		draw_polyline(hp, mesh, 1.2)
	# dikey örgü çizgileri — şişme yüzünden ortada bükülür (cep hissi)
	for i in range(cols + 1):
		var fi := float(i) / cols
		var vp := PackedVector2Array()
		for j in range(rows + 1):
			var yy := lerpf(top_y, base_y, float(j) / rows)
			var bxj := g0.x + depth + bulge * exp(-pow((yy - hit_y) / spread, 2.0))
			vp.append(Vector2(lerpf(g0.x, bxj, fi), yy))
		draw_polyline(vp, mesh, 1.2)
	# rijit çerçeve (bükülmez): ön direk + üst kiriş + arka bacak
	var frame := Color("f5f8fa")
	draw_line(Vector2(g0.x, top_y), Vector2(g0.x, base_y), frame, 4.0)              # ön direk
	draw_line(Vector2(g0.x, top_y), Vector2(g0.x + depth, top_y), frame, 4.0)       # üst kiriş
	draw_line(Vector2(g0.x + depth, top_y), Vector2(g0.x + depth, base_y), Color(1, 1, 1, 0.45), 2.0)  # arka bacak

## GERÇEK yörünge — NOKTALI (nokta nokta), yeşil yolun üstünde çizilir.
func _draw_dotted_real() -> void:
	var acc := 0.0
	var prev := _world_to_px(real[0]["p"])
	var i := 1
	while i < real.size():
		var cur := _world_to_px(real[i]["p"])
		acc += prev.distance_to(cur)
		if acc >= Physics.cfg.real_path_dot_gap:
			acc = 0.0
			draw_circle(cur, Physics.cfg.real_path_dot_radius, Physics.cfg.adj(Physics.cfg.real_path_color))   # nokta
		prev = cur
		i += 1

## Gerçek yörüngedeki SOLUK TOP — tahmin topuyla aynı anda hareket eder.
func _draw_ghost_ball(gp: Vector2) -> void:
	draw_circle(gp, 15.0, Color(C_GHOST, 0.16))
	draw_circle(gp, 11.0, Color(1, 1, 1, 0.55))
	draw_arc(gp, 11.0, 0, TAU, 26, Color(C_GHOST, 0.85), 2.5)
	draw_arc(gp, 5.0, 0, TAU, 18, Color(C_GHOST, 0.55), 2.0)

func _draw_end_message() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var a := clampf(end_msg_t * 3.0, 0.0, 1.0)
	var title := ("GOL!" if hit_bulls else "SİMÜLASYON BİTMİŞTİR")
	var sub := ""
	if impact_x < 0.0:
		sub = "Top hiç yere inmedi — seçtiğin kuvvetlerle top asla düşmez."
	else:
		if hit_bulls:
			sub = "GOL! Top kaleye girdi."
		elif impact_x < Physics.cfg.goal_x:
			sub = "Top kaleye ulaşamadı — %.1f m önce yere düştü." % (Physics.cfg.goal_x - impact_x)
		else:
			sub = "Top kaleyi aştı — %.1f m ötede yere düştü." % (impact_x - Physics.cfg.goal_x)
	var fs := 34
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var bw := maxf(tw, sw) + 44.0
	var bx := size.x * 0.5 - bw * 0.5
	var by := size.y * 0.13
	draw_rect(Rect2(Vector2(bx, by), Vector2(bw, 92)), Color(1, 1, 1, 0.93 * a))
	draw_rect(Rect2(Vector2(bx, by), Vector2(bw, 92)), Color(Physics.cfg.predicted_path_color if hit_bulls else Color("64748b"), 0.85 * a), false, 3.0)
	draw_string(font, Vector2(size.x * 0.5 - tw * 0.5, by + 42), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Physics.cfg.predicted_path_color if hit_bulls else Color("1f2937"), a))
	draw_string(font, Vector2(size.x * 0.5 - sw * 0.5, by + 72), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("334155", a))

func _draw_ball(bp: Vector2) -> void:
	if ball_tex != null:
		var d := 58.0
		var ang := (play_t * 8.0) if playing else 0.0
		draw_set_transform(bp, ang, Vector2.ONE)
		draw_texture_rect_region(ball_tex, Rect2(-d * 0.5, -d * 0.5, d, d), ball_rect)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_circle(bp, 12.0, Color.WHITE)
	draw_arc(bp, 12.0, 0, TAU, 24, Color("1f2937"), 2.0)

## Kuvvet okları — topun TAM MERKEZİNDEN başlar, topun ÖNÜNDE çizilir.
## MADDE 7 (kuvveti daha görünür yap): her okun ucunda artık RENKLİ BİR ROZET
## içinde adı VE büyüklüğü (newton) yazıyor; rozetler üst üste binmesin diye
## çakışanlar kaydırılıyor. MADDE 13: oklar daha ince (kalınlıklar Inspector'dan).
## MADDE 14: hava direnci oku turkuaz değil, ayırt edilebilir mor-magenta.
func _draw_force_arrows(ball_px: Vector2, vel: Vector2) -> void:
	var arrows: Array = []
	if f_gravity:
		arrows.append({"a": Vector2(0, -Physics.cfg.gravity_g), "c": Physics.cfg.gravity_arrow_color, "l": "Yerçekimi", "w": Physics.cfg.gravity_arrow_thickness})
	if f_air:
		arrows.append({"a": (-f_drag * vel.length() * vel) / Physics.cfg.mass_kg, "c": Physics.cfg.air_arrow_color, "l": "Hava direnci", "w": Physics.cfg.air_arrow_thickness})
	if f_kick and vel.length() > 0.01:
		# F artık SABİT yönlü (atış açısı) — ok da hıza değil o yöne çizilir
		var fixed_dir := Vector2(cos(deg_to_rad(Physics.cfg.angle_deg)), sin(deg_to_rad(Physics.cfg.angle_deg)))
		arrows.append({"a": (fixed_dir * f_impetus) / Physics.cfg.mass_kg, "c": Physics.cfg.kick_arrow_color, "l": "Vuruş F", "w": Physics.cfg.kick_arrow_thickness})
	var used: Array = []           # yerleştirilmiş rozet dikdörtgenleri (çakışma önleme)
	for arr in arrows:
		var acc: Vector2 = arr["a"]
		if acc.length() < 0.05:
			continue
		var scr := Vector2(acc.x, -acc.y) * Physics.cfg.arrow_scale
		if scr.length() > Physics.cfg.arrow_max_px:
			scr = scr.normalized() * Physics.cfg.arrow_max_px
		var label: String = arr["l"]
		if Physics.cfg.arrow_label_show_magnitude:
			# F = m·a (kütle ÇARPANI cfg.mass_kg) — öğrenci "hangi kuvvet daha
			# büyük" sorusunu okla birlikte SAYIYLA da görsün
			label += "  %.1f N" % (acc.length() * Physics.cfg.mass_kg)
		_draw_arrow(ball_px, ball_px + scr, Physics.cfg.adj(arr["c"]), label,
			Physics.cfg.adj_width(arr["w"]), false, used)

## Kalıcı kuvvet renk anahtarı (sol alt) — hangi rengin hangi kuvvet olduğu
## ok ekranda olmasa da okunur. Inspector: Vektör Okları -> Force Legend.
func _draw_force_legend() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var rows: Array = [
		{"c": Physics.cfg.gravity_arrow_color, "l": "Yerçekimi", "on": f_gravity},
		{"c": Physics.cfg.air_arrow_color, "l": "Hava direnci", "on": f_air},
		{"c": Physics.cfg.kick_arrow_color, "l": "Vuruş F", "on": f_kick},
		{"c": C_VEL, "l": "v (hız)", "on": true},
	]
	var fs := 12
	var pad := 9.0
	var line_h := 18.0
	var w := 0.0
	for r in rows:
		w = maxf(w, font.get_string_size(r["l"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	w += pad * 2.0 + 26.0
	var h := rows.size() * line_h + pad * 2.0
	var org := Vector2(12.0, size.y - h - 12.0)
	draw_rect(Rect2(org, Vector2(w, h)), Color(0.06, 0.07, 0.09, 0.72))
	draw_rect(Rect2(org, Vector2(w, h)), Color(1, 1, 1, 0.10), false, 1.0)
	var y := org.y + pad + line_h * 0.5
	for r in rows:
		var a: float = 1.0 if r["on"] else 0.30
		var col: Color = Physics.cfg.adj(r["c"])
		draw_line(Vector2(org.x + pad, y), Vector2(org.x + pad + 18.0, y), Color(col, a), 3.0)
		draw_string(font, Vector2(org.x + pad + 26.0, y + 4.0), r["l"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color("e8eaed"), a))
		y += line_h

## HIZ vektörü + BİLEŞENLERİ. vx (yatay) ve vy (dikey) ayrı renkli, etiketli
## oklardır: hava direnci seçilmediğinde vx okunun boyu HİÇ DEĞİŞMEZ,
## tepe noktasında ise vy oku tamamen kaybolurken yerçekimi oku tam boyda kalır.
## HIZ vektörü — topun üzerinde YALNIZCA toplam hız (v) oku.
## vx/vy bileşen okları kaldırıldı; sayısal değerleri sol HUD kartında.
func _draw_velocity(ball_px: Vector2, vel: Vector2) -> void:
	if vel.length() < 0.05:
		return
	var scr := Vector2(vel.x, -vel.y) * VEL_SCALE
	if scr.length() > VEL_MAX:
		scr = scr.normalized() * VEL_MAX
	_draw_arrow(ball_px, ball_px + scr, Physics.cfg.adj(C_VEL), "v  %.0f m/s" % vel.length(), Physics.cfg.adj_width(4.0))

func _draw_speed_readout(ball_px: Vector2, vel: Vector2) -> void:
	if apex_flash <= 0.0:
		return
	var font := get_theme_default_font()
	if font == null:
		return
	var a := clampf(apex_flash, 0.0, 1.0)
	var l1 := S.t("APEX_L1")
	var l2 := S.t("APEX_L2")
	var l3 := S.t("APEX_L3")
	var bw := maxf(maxf(font.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x,
					font.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x),
					font.get_string_size(l3, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) + 20.0
	var bp2 := Vector2(ball_px.x - bw * 0.5, ball_px.y - 150.0)
	bp2.x = clampf(bp2.x, 8.0, size.x - bw - 8.0)
	bp2.y = maxf(bp2.y, 8.0)
	draw_rect(Rect2(bp2, Vector2(bw, 66.0)), Color(1, 1, 1, 0.94 * a))
	draw_rect(Rect2(bp2, Vector2(bw, 66.0)), Color("dc2626", 0.85 * a), false, 2.0)
	draw_string(font, bp2 + Vector2(10, 18), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("dc2626", a))
	draw_string(font, bp2 + Vector2(10, 38), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(C_VY, a))
	draw_string(font, bp2 + Vector2(10, 57), l3, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("2563eb", a))

## `used` verilirse: etiket rozeti daha önce yerleştirilmiş rozetlerle
## çakışmayacak şekilde aşağı kaydırılır ve kendi dikdörtgenini listeye ekler.
func _draw_arrow(from: Vector2, to: Vector2, col: Color, label: String, w := 4.0, thin := false, used: Array = []) -> void:
	var dir := (to - from).normalized()
	var n := Vector2(-dir.y, dir.x)
	var h := (7.0 + w * 1.7) * Physics.cfg.arrow_head_ratio
	if not thin:
		var oa := Physics.cfg.arrow_outline_alpha
		draw_line(from, to, Color(0, 0, 0, oa), w + 3.0)
		draw_colored_polygon(PackedVector2Array([to + dir * 2.0, to - dir * h + n * (h * 0.6 + 1.8), to - dir * h - n * (h * 0.6 + 1.8)]), Color(0, 0, 0, oa))
	draw_line(from, to, col, w)
	draw_colored_polygon(PackedVector2Array([to, to - dir * h + n * h * 0.6, to - dir * h - n * h * 0.6]), col)
	if label == "":
		return
	var f := get_theme_default_font()
	if f == null:
		return
	var fs: int = Physics.cfg.arrow_label_size
	var ts := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var padx := 7.0
	var pady := 4.0
	var bw := ts.x + padx * 2.0
	var bh := ts.y + pady * 2.0
	var lp := to + dir * 14.0
	# rozeti ekran içinde tut
	lp.x = clampf(lp.x - bw * 0.5, 4.0, maxf(size.x - bw - 4.0, 4.0))
	lp.y = clampf(lp.y - bh * 0.5, 4.0, maxf(size.y - bh - 4.0, 4.0))
	var rect := Rect2(lp, Vector2(bw, bh))
	# çakışan rozetleri aşağı kaydır (aynı anda 3 kuvvet açıkken okunur kalsın)
	var guard := 0
	while guard < 8:
		var moved := false
		for r in used:
			if rect.intersects(r):
				rect.position.y = r.position.y + r.size.y + 4.0
				moved = true
		if not moved:
			break
		guard += 1
	used.append(rect)
	if Physics.cfg.arrow_label_badge:
		# dolu renkli rozet + koyu metin: hem çim hem gökyüzü üzerinde okunur
		draw_rect(rect, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(rect.position, rect.size), col, false, 2.0)
		draw_string(f, rect.position + Vector2(padx, bh - pady - 2.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	else:
		var tp := rect.position + Vector2(padx, bh - pady - 2.0)
		draw_string(f, tp + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
		draw_string(f, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _load_frames(dir: String, n: int) -> Array:
	var out: Array = []
	for i in range(n):
		var path := "%s/frame_%03d.png" % [dir, i]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var rect := Rect2(0, 0, tex.get_width(), tex.get_height())
		var img := tex.get_image()
		if img != null:
			var ur := img.get_used_rect()
			if ur.size.x > 0 and ur.size.y > 0:
				rect = Rect2(ur.position, ur.size)
		out.append({"tex": tex, "rect": rect})
	return out

func _spawn_confetti(at: Vector2) -> void:
	var cols := [Color("f59e0b"), Color("15803d"), Color("2563eb"), Color("dc2626"), Color("f4f7fb"), Color("74add8")]
	var rng := RandomNumberGenerator.new()
	for i in range(70):
		var ang := rng.randf_range(-PI * 0.5 - 1.35, -PI * 0.5 + 1.35)  # geniş yukarı-dışa yelpaze
		var spd := rng.randf_range(160.0, 560.0)
		confetti.append({
			"p": at + Vector2(rng.randf_range(-40, 40), rng.randf_range(-14, 14)),
			"v": Vector2(cos(ang), sin(ang)) * spd,
			"c": cols[rng.randi() % cols.size()],
			"rot": rng.randf_range(0.0, TAU),
			"life": rng.randf_range(1.1, 2.2),
		})

func _messi_color(ch: String) -> Color:
	match ch:
		"H": return Color("3a2415")   # saç
		"B": return Color("e8b88a")   # (sakal kaldırıldı -> ten)
		"K": return Color("e8b88a")   # ten
		"E": return Color("20242a")   # göz
		"L": return Color("d84848")   # kırmızı (forma çizgisi — jenerik kit)
		"W": return Color("f4f7fb")   # beyaz (forma)
		"D": return Color("2b2f36")   # şort
		"S": return Color("e08a8a")   # çorap
		"O": return Color("d9a441")   # krampon
		_: return Color("e8b88a")

## Futbolcuyu 'feet' (alt-orta) noktasına çizer. Sprite yüklüyse duruma göre
## doğru kareyi; değilse jenerik piksel futbolcuyu çizer.

func _draw_player(feet: Vector2) -> void:
	var fr = _current_player_frame()
	if fr == null:
		_draw_player_fallback(feet)
		return
	var rect: Rect2 = fr["rect"]
	var scale := (size.y * 0.125 * cam_zoom) / maxf(sp_ref_h, 1.0)   # zoomla küçülür
	var w := rect.size.x * scale
	var h := rect.size.y * scale
	# ayaklar 'feet'te, yatayda ortalı; karenin dolgu payı get_used_rect ile kırpıldı
	var dest := Rect2(feet.x - w * 0.5, feet.y - h, w, h)
	draw_texture_rect_region(fr["tex"], dest, rect)

## Duruma göre gösterilecek kare ({tex,rect}) — sprite yoksa null.

func _contact_index() -> int:
	# ayağın topa değdiği kare (vuruş dizisinin ~%60'ı)
	return mini(int(sp_kick.size() * 0.6), maxi(sp_kick.size() - 1, 0))

## Girişin DURACAĞI kare: temastan HEMEN ÖNCE. Böylece öğrenci cevabını
## vermeden top vurulmuş olmaz; vuruş "Ne olacağını gör"e basınca gerçekleşir.
func _prekick_index() -> int:
	return maxi(_contact_index() - 1, 0)

func _current_player_frame():
	if intro_active:
		var p := intro_t / INTRO_DUR
		if p < 0.72 and not sp_run.is_empty():
			return sp_run[int(intro_t / 0.09) % sp_run.size()]         # koşu döngüsü
		elif not sp_kick.is_empty():
			# koşudan temasa: yalnızca temas karesine KADAR ilerle, orada dur.
			# (eskiden tüm vuruş dizisi burada bitip IDLE'a zıplıyordu = takılma)
			var kp := clampf((p - 0.72) / 0.28, 0.0, 1.0)
			return sp_kick[mini(int(kp * (_prekick_index() + 1)), _prekick_index())]
	if prekick_active and not sp_kick.is_empty():
		return sp_kick[_contact_index()]        # ayak topa değdi (küçük sıçrama anı)
	if kick_hold and not sp_kick.is_empty():
		return sp_kick[_prekick_index()]        # soru sorulurken: HENÜZ VURMADI
	if kick_follow and not sp_kick.is_empty():
		# vuruş sonrası kalan kareler (temas -> son) akıcı oynar, sonra idle'a döner
		var fp := clampf(kick_follow_t / KICK_FOLLOW_DUR, 0.0, 1.0)
		var ci := _prekick_index()
		var rem := maxi(sp_kick.size() - 1 - ci, 0)
		return sp_kick[mini(ci + int(fp * (rem + 1)), sp_kick.size() - 1)]
	if not sp_idle.is_empty():
		return sp_idle[0]   # dururken
	return null

## Sprite yüklenmezse: 8-bit jenerik futbolcu (kırmızı-beyaz kit).

func _draw_player_fallback(feet: Vector2) -> void:
	var w := 11
	var h := MESSI.size()
	var ps := (size.y * 0.125 * cam_zoom) / h
	var ox := feet.x - w * ps * 0.5
	var oy := feet.y - h * ps
	for r in range(h):
		var row: String = MESSI[r]
		for c in range(w):
			if row[c] == ".":
				continue
			draw_rect(Rect2(ox + c * ps, oy + r * ps, ps + 0.6, ps + 0.6), _messi_color(row[c]))

