class_name FieldView
extends Control
## Draws the pitch and animates the ball along the predicted trajectory,
## with the real (drag) path shown dashed for comparison.

signal flight_finished

const FIELD_METERS := 60.0
const GOAL_X := 49.0         # kale ön çizgisi (m). Doğru cevap ~52m'ye düşer, topu ağa sokar.
const GOAL_DEPTH_PX := 42.0  # kale kutusu derinliği (px)
const ORIGIN_X := 490.0      # kick noktası (px) — soldaki karar panelinin sağında kalsın
const RIGHT_MARGIN := 40.0   # kick noktasından sağ kenara boşluk

var predicted: Array = []      # [{p:Vector2 (m, y-up), v:Vector2, t:float}]
var real: Array = []
var playing := false
var play_t := 0.0
var trail: PackedVector2Array = []
var show_real := false

# --- kuvvet okları (vektörler) ---
const ARROW_SCALE := 4.7   # px / (m/s^2); yerçekimi (9.81) ~46 px olur
const ARROW_MAX := 95.0    # görsel sınır (px)
const C_GRAVITY := Color("2563eb")   # mavi
const C_AIR := Color("0891b2")       # camgöbeği
const C_KICK := Color("dc2626")      # kırmızı
var f_gravity := false
var f_kick := false
var f_air := false
var f_drag := 0.012   # Physics.DRAG_MED (Orta); set_forces ile güncellenir
var f_impetus := 6.0  # vuruş kuvveti büyüklüğü (kullanıcı ayarlar)
var pv_active := false      # vuruş öncesi önizleme (topu orijinde göster + oklar)
var pv_v0 := 0.0
var pv_angle := 0.0

# --- kamera (zoom/pan) ve uzay arka planı ---
# Varsayılan (cam_zoom=1, cam_focus=0) mevcut görüntüyle birebir aynıdır.
var cam_zoom := 1.0
var cam_focus := Vector2.ZERO     # dünya (m) — ekran çıpasında tutulan nokta
var target_zoom := 1.0
var target_focus := Vector2.ZERO
var stars: PackedVector2Array = []
var scored := false       # top file içinde mi (gol kutlaması)
var score_t := 0.0        # kutlama başından beri geçen süre

func _ready() -> void:
	set_process(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260723
	for i in range(60):
		stars.append(Vector2(rng.randf(), rng.randf() * 0.72))  # ekranın üst kısmına dağıt

func _base_scale() -> float:
	return maxf((size.x - ORIGIN_X - RIGHT_MARGIN) / FIELD_METERS, 1.0)

func _world_to_px(p: Vector2) -> Vector2:
	var ground_y := size.y * 0.82
	var s := _base_scale() * cam_zoom
	var anchor := Vector2(ORIGIN_X, ground_y)   # dünya cam_focus'u burada görünür
	return anchor + Vector2((p.x - cam_focus.x) * s, -(p.y - cam_focus.y) * s)

## Hangi kuvvetlerin oku çizilecek (uçuş + önizleme ortak).
func set_forces(g: bool, k: bool, a: bool, drag_k: float, imp := 6.0) -> void:
	f_gravity = g
	f_kick = k
	f_air = a
	f_drag = drag_k
	f_impetus = imp

## Vuruş öncesi önizleme: topu orijinde göster, seçili kuvvetleri fırlatma
## hızındaki büyüklükleriyle ok olarak çiz.
func set_preview(g: bool, k: bool, a: bool, v0: float, angle: float, drag_k: float, imp := 6.0) -> void:
	set_forces(g, k, a, drag_k, imp)
	pv_v0 = v0
	pv_angle = angle
	pv_active = true
	queue_redraw()

func start_flight(pred: Array, real_pts: Array) -> void:
	predicted = pred
	real = real_pts
	trail = PackedVector2Array()
	play_t = 0.0
	playing = true
	show_real = false
	pv_active = false
	_reset_camera()
	queue_redraw()

func reset() -> void:
	predicted = []
	trail = PackedVector2Array()
	playing = false
	show_real = false
	pv_active = false
	_reset_camera()
	queue_redraw()

func _reset_camera() -> void:
	cam_zoom = 1.0
	target_zoom = 1.0
	cam_focus = Vector2.ZERO
	target_focus = Vector2.ZERO
	scored = false
	score_t = 0.0

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
			return pts[i].get("v", Vector2.ZERO)
	return pts[-1].get("v", Vector2.ZERO)

func _process(delta: float) -> void:
	var animating := false
	if playing:
		play_t += delta
		var last_t: float = predicted[-1]["t"] if not predicted.is_empty() else 0.0
		trail.append(_point_at(predicted, play_t))   # DÜNYA koordinatı (zoom'da bozulmasın)
		_update_flight_camera()
		animating = true
		if play_t >= last_t:
			playing = false
			show_real = true
			_on_flight_end()
			flight_finished.emit()
	if scored:
		score_t += delta
		if score_t < 3.0:
			animating = true
	# kamerayı hedefe doğru yumuşat (uçuş bitse de iniş-zoom'u için sürsün)
	if absf(cam_zoom - target_zoom) > 0.002 or cam_focus.distance_to(target_focus) > 0.05:
		var k := clampf(delta * 3.5, 0.0, 1.0)
		cam_zoom = lerpf(cam_zoom, target_zoom, k)
		cam_focus = cam_focus.lerp(target_focus, k)
		animating = true
	if animating:
		queue_redraw()

## Uçuş sırasında: orijin ile topu çerçevede tutacak kadar geri çekil (yalnızca zoom-out).
func _update_flight_camera() -> void:
	var ball: Vector2 = _point_at(predicted, play_t)
	var maxx: float = maxf(ball.x * 1.12, FIELD_METERS)   # en az varsayılan alanı göster
	var maxy: float = maxf(ball.y * 1.15, 12.0)
	var avail_h_m: float = (size.y * 0.82 - 24.0) / _base_scale()  # zoom=1'de görünen yükseklik (m)
	target_zoom = minf(1.0, minf(FIELD_METERS / maxx, avail_h_m / maxy))
	target_focus = Vector2.ZERO

## Uçuş bitince: top file içindeyse GOL (kaleye yakınlaş + kutlama), değilse iniş-zoom.
func _on_flight_end() -> void:
	if trail.is_empty():
		return
	var landing: Vector2 = trail[-1]
	var goal_depth_m := GOAL_DEPTH_PX / _base_scale()
	if landing.y < 1.0 and landing.x >= GOAL_X - 1.0 and landing.x <= GOAL_X + goal_depth_m + 2.0:
		# GOL — kaleye yakınlaş, kutlamayı başlat
		scored = true
		score_t = 0.0
		target_focus = Vector2(GOAL_X + goal_depth_m * 0.5, 0.0)
		target_zoom = 1.4
	elif landing.y <= 0.5 and landing.x > GOAL_X + 6.0:
		# top kaleyi geçip uzağa indi — düştüğü yere yakınlaş
		target_focus = Vector2(landing.x, 0.0)
		target_zoom = 1.25
	# top havada uçup gittiyse (uzay) kamera geniş açıda kalır

func _draw() -> void:
	var ground_y := size.y * 0.82
	var grass_top := ground_y - size.y * 0.18
	# --- gökyüzü / uzay: top yükseldikçe gök kararır, yıldızlar belirir ---
	var ball_h := (trail[trail.size() - 1].y if not trail.is_empty() else 0.0)
	var space := clampf((ball_h - 45.0) / 90.0, 0.0, 1.0)   # 45m'de başlar, ~135m'de tam uzay
	var sky := Color("dbeafe").lerp(Color("060a1c"), space)
	var sky2 := Color("e8f2fb").lerp(Color("0d1430"), space)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, grass_top)), sky)
	draw_rect(Rect2(Vector2(0, grass_top * 0.55), Vector2(size.x, grass_top * 0.45)), sky2)
	if space > 0.02:
		for sf in stars:
			var sp := Vector2(sf.x * size.x, sf.y * grass_top)
			draw_circle(sp, 1.4, Color(1, 1, 1, space * (0.35 + 0.55 * sf.y)))
	# --- çim + zemin (uzayda bile zemin çizgisi ufuk olarak kalır) ---
	draw_rect(Rect2(Vector2(0, grass_top), Vector2(size.x, size.y - grass_top)), Color("a7d7a0"))
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), Color("5b6b57"), 2.0)
	# --- oyuncu ---
	var o := _world_to_px(Vector2.ZERO)
	_draw_player(o + Vector2(-26, 0))
	# --- kale: rijit çerçeve + örgü ağ; gol olunca top girdiği yerden ağı geri iter ---
	var goal_h_m := (size.y * 0.28) / _base_scale()
	var g0 := _world_to_px(Vector2(GOAL_X, 0.0))          # ön-alt köşe
	var g1 := _world_to_px(Vector2(GOAL_X, goal_h_m))     # ön-üst köşe
	var top_y := g1.y
	var base_y := g0.y
	var goal_h_px := base_y - top_y
	var depth := GOAL_DEPTH_PX * cam_zoom
	# gol anında ağ şişmesi: hızlı geri itilir, sönümlü salınımla dinginleşir
	var bulge := 0.0
	if scored:
		bulge = exp(-score_t * 2.0) * (20.0 + 7.0 * cos(score_t * 15.0)) * cam_zoom
	# şişme topun girdiği yükseklikte en fazla (file cebi orada oluşur)
	var hit_y := (_world_to_px(trail[trail.size() - 1]).y if not trail.is_empty() else base_y - goal_h_px * 0.15)
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
	# real path (dashed) after flight
	if show_real and real.size() > 1:
		var prev: Vector2 = _world_to_px(real[0]["p"])
		var on := true
		var acc := 0.0
		for i in range(1, real.size()):
			var cur := _world_to_px(real[i]["p"])
			acc += prev.distance_to(cur)
			if acc > 7.0:
				on = not on
				acc = 0.0
			if on:
				draw_line(prev, cur, Color("5b6b57"), 2.0)
			prev = cur
		var lbl := _world_to_px(real[real.size() >> 1]["p"]) + Vector2(10, 40)
		draw_string(get_theme_default_font(), lbl, "real path", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("5b6b57"))
	# predicted trail (dünya -> ekran, kamerayla)
	if trail.size() > 1:
		var scr := PackedVector2Array()
		for wp in trail:
			scr.append(_world_to_px(wp))
		draw_polyline(scr, Color("15803d"), 3.0, true)
	# ball + kuvvet okları
	if not trail.is_empty():
		var bp := _world_to_px(trail[trail.size() - 1])
		if playing:
			_draw_force_arrows(bp, _vel_at(predicted, play_t))   # uçuş sırasında canlı
		_draw_ball(bp)
	elif pv_active:
		# vuruş öncesi: topu orijinde göster + seçili kuvvetleri fırlatma büyüklüğünde
		var b0 := _world_to_px(Vector2.ZERO) + Vector2(0, -10)
		var launch := Vector2(cos(deg_to_rad(pv_angle)), sin(deg_to_rad(pv_angle))) * pv_v0
		_draw_force_arrows(b0, launch)
		_draw_ball(b0)
	# --- GOL kutlaması (en üstte) ---
	if scored:
		var bp := _world_to_px(trail[trail.size() - 1]) if not trail.is_empty() else _world_to_px(Vector2(GOAL_X, 0.0))
		# çarpma halkası (kehribar dış + beyaz iç — açık zeminde de görünür)
		if score_t < 0.6:
			var k := score_t / 0.6
			var ca := (1.0 - k) * 0.9
			var rr := 14.0 + k * 120.0 * cam_zoom
			draw_arc(bp, rr, 0, TAU, 40, Color("f59e0b", ca), 4.0)
			draw_arc(bp, rr * 0.6, 0, TAU, 40, Color(1, 1, 1, ca * 0.7), 2.0)
		# GOL! yazısı — belirip hafifçe zıplar
		var font := get_theme_default_font()
		var a := clampf(score_t * 3.0, 0.0, 1.0)
		var pop := 1.0 + 0.25 * exp(-score_t * 4.0) * sin(score_t * 22.0)
		var fs := int(54 * pop)
		var tw := font.get_string_size("GOL!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := Vector2(size.x * 0.5 - tw * 0.5, size.y * 0.30)
		draw_string(font, tp + Vector2(2, 2), "GOL!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a * 0.25))
		draw_string(font, tp, "GOL!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("15803d", a))

func _draw_ball(bp: Vector2) -> void:
	draw_circle(bp, 10.0, Color.WHITE)
	draw_arc(bp, 10.0, 0, TAU, 24, Color("1f2937"), 2.0)
	draw_circle(bp, 3.5, Color("1f2937"))

## Seçili kuvvetleri, o andaki hıza göre hesaplayıp ok olarak çizer.
## Yalnızca işaretli kuvvetin oku görünür; ok boyu kuvvet büyüklüğüyle orantılı.
func _draw_force_arrows(ball_px: Vector2, vel: Vector2) -> void:
	var arrows: Array = []   # [{a:Vector2 (world accel, y-up), c:Color, l:String}]
	if f_gravity:
		arrows.append({"a": Vector2(0, -Physics.G), "c": C_GRAVITY, "l": "Yerçekimi"})
	if f_air:
		arrows.append({"a": -f_drag * vel.length() * vel, "c": C_AIR, "l": "Hava direnci"})
	if f_kick and vel.length() > 0.01:
		arrows.append({"a": vel.normalized() * f_impetus, "c": C_KICK, "l": "Vuruş F"})
	for arr in arrows:
		var acc: Vector2 = arr["a"]
		if acc.length() < 0.05:
			continue
		var scr := Vector2(acc.x, -acc.y) * ARROW_SCALE   # dünya y-yukarı -> ekran y-aşağı
		if scr.length() > ARROW_MAX:
			scr = scr.normalized() * ARROW_MAX
		_draw_arrow(ball_px, ball_px + scr, arr["c"], arr["l"])

func _draw_arrow(from: Vector2, to: Vector2, col: Color, label: String) -> void:
	draw_line(from, to, col, 3.0)
	var dir := (to - from).normalized()
	var n := Vector2(-dir.y, dir.x)
	var h := 10.0
	draw_colored_polygon(PackedVector2Array([to, to - dir * h + n * h * 0.55, to - dir * h - n * h * 0.55]), col)
	draw_string(get_theme_default_font(), to + dir * 8 + Vector2(2, -2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

func _draw_player(feet: Vector2) -> void:
	var c := Color("e8862e")
	draw_circle(feet + Vector2(0, -46), 7, Color("f0b27a"))          # head
	draw_rect(Rect2(feet + Vector2(-7, -39), Vector2(14, 22)), c)     # torso
	draw_line(feet + Vector2(-4, -17), feet + Vector2(-6, 0), Color("4a5568"), 4.0)
	draw_line(feet + Vector2(4, -17), feet + Vector2(8, 0), Color("4a5568"), 4.0)
