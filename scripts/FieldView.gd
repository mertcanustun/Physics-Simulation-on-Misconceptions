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

func _ready() -> void:
	set_process(true)

func _world_to_px(p: Vector2) -> Vector2:
	var ground_y := size.y * 0.82
	var ox := ORIGIN_X
	var s := maxf((size.x - ORIGIN_X - RIGHT_MARGIN) / FIELD_METERS, 1.0)
	return Vector2(ox + p.x * s, ground_y - p.y * s)

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
	queue_redraw()

func reset() -> void:
	predicted = []
	trail = PackedVector2Array()
	playing = false
	show_real = false
	pv_active = false
	queue_redraw()

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
	if not playing:
		return
	play_t += delta
	var last_t: float = predicted[-1]["t"] if not predicted.is_empty() else 0.0
	trail.append(_world_to_px(_point_at(predicted, play_t)))
	queue_redraw()
	if play_t >= last_t:
		playing = false
		show_real = true
		queue_redraw()
		flight_finished.emit()

func _draw() -> void:
	var ground_y := size.y * 0.82
	var grass_top := ground_y - size.y * 0.18
	# sky
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, grass_top)), Color("dbeafe"))
	draw_rect(Rect2(Vector2(0, grass_top * 0.55), Vector2(size.x, grass_top * 0.45)), Color("e8f2fb"))
	# grass (starts a bit above ground line, like the web version)
	draw_rect(Rect2(Vector2(0, grass_top), Vector2(size.x, size.y - grass_top)), Color("a7d7a0"))
	# ground line
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), Color("5b6b57"), 2.0)
	# player (simple figure at origin)
	var o := _world_to_px(Vector2.ZERO)
	_draw_player(o + Vector2(-26, 0))
	# goal at the correct-answer landing distance so a correct kick enters the net
	var gx := _world_to_px(Vector2(GOAL_X, 0.0)).x
	var gh := size.y * 0.28
	draw_rect(Rect2(Vector2(gx, ground_y - gh), Vector2(GOAL_DEPTH_PX, gh)), Color("f2f6f2"))
	draw_rect(Rect2(Vector2(gx, ground_y - gh), Vector2(GOAL_DEPTH_PX, gh)), Color("3d4a5c"), false, 3.0)
	for i in range(1, 6):
		draw_line(Vector2(gx + i * (GOAL_DEPTH_PX / 6.0), ground_y - gh), Vector2(gx + i * (GOAL_DEPTH_PX / 6.0), ground_y), Color(0.24, 0.29, 0.36, 0.25), 1.0)
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
	# predicted trail
	if trail.size() > 1:
		draw_polyline(trail, Color("15803d"), 3.0, true)
	# ball + kuvvet okları
	if not trail.is_empty():
		var bp := trail[-1]
		if playing:
			_draw_force_arrows(bp, _vel_at(predicted, play_t))   # uçuş sırasında canlı
		_draw_ball(bp)
	elif pv_active:
		# vuruş öncesi: topu orijinde göster + seçili kuvvetleri fırlatma büyüklüğünde
		var b0 := _world_to_px(Vector2.ZERO) + Vector2(0, -10)
		var launch := Vector2(cos(deg_to_rad(pv_angle)), sin(deg_to_rad(pv_angle))) * pv_v0
		_draw_force_arrows(b0, launch)
		_draw_ball(b0)

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
