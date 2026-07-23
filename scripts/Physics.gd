class_name Physics
## Trajectory integration in world units (meters, y-up).
## Returns Array of Dictionaries: { "p": Vector2, "v": Vector2, "t": float }
## "v" (hız) her noktada kaydedilir ki FieldView kuvvet oklarını çizebilsin.

const G := 9.81
# Sürtünme (hava direnci) seviyeleri — quadratic drag katsayısı (per meter).
const DRAG_LOW := 0.006     # "Az"
const DRAG_MED := 0.012     # "Orta"  (varsayılan; doğru senaryo topu kaleye sokar)
const DRAG_HIGH := 0.022    # "Fazla"
const IMPETUS_ACC := 6.0    # "vuruş kuvveti itmeye devam eder" yanılgısı, m/s^2 hız yönünde
const DT := 1.0 / 240.0
const MAX_T := 14.0
const MAX_X := 120.0

## 0=Az, 1=Orta, 2=Fazla  ->  drag katsayısı
static func drag_for_level(level: int) -> float:
	match level:
		0: return DRAG_LOW
		2: return DRAG_HIGH
		_: return DRAG_MED

static func simulate(v0: float, angle_deg: float, gravity: bool, kick: bool, air: bool, drag_k := DRAG_MED, imp := IMPETUS_ACC) -> Array:
	var ang := deg_to_rad(angle_deg)
	var vel := Vector2(cos(ang), sin(ang)) * v0
	var pos := Vector2.ZERO
	var t := 0.0
	var pts: Array = [{"p": pos, "v": vel, "t": 0.0}]
	while t < MAX_T:
		var acc := Vector2.ZERO
		if gravity:
			acc.y -= G
		if air:
			acc -= drag_k * vel.length() * vel
		if kick and vel.length() > 0.01:
			acc += vel.normalized() * imp
		vel += acc * DT
		pos += vel * DT
		t += DT
		pts.append({"p": pos, "v": vel, "t": t})
		if pos.y < 0.0 and t > 0.05:
			break
		if pos.x > MAX_X or pos.y > 200.0:
			break
	return pts

static func real_path(v0: float, angle_deg: float, drag_k := DRAG_MED) -> Array:
	return simulate(v0, angle_deg, true, false, true, drag_k)
