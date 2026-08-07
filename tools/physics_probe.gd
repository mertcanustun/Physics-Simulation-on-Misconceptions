extends SceneTree
## Fizik doğruluğu ölçüm betiği (geçici — DEVIR-NOTU.md "İlk görev" için).
## Physics.gd'yi DEĞİŞTİRMEDEN, mevcut simulate()'i ve karşılaştırma için
## yerel bir RK4 kopyasını çağırıp sayısal ölçüm basar.
##   godot --headless --path . --script tools/physics_probe.gd

const G := 9.81
const V0 := 30.0
const ANGLE := 45.0
const MAX_T := 16.0

static func accel(v: Vector2, gravity: bool, air: bool, drag_k: float, kick: bool, imp: float) -> Vector2:
	var a := Vector2.ZERO
	if gravity:
		a.y -= G
	if air:
		a -= drag_k * v.length() * v
	if kick and v.length() > 0.01:
		a += v.normalized() * imp
	return a

## RK4 ile ilk zemin çarpma noktası (interpolasyonlu, dt neyse o çözünürlükte).
static func rk4_impact_x(gravity: bool, air: bool, drag_k: float, kick: bool, imp: float, dt: float) -> float:
	var ang := deg_to_rad(ANGLE)
	var v := Vector2(cos(ang), sin(ang)) * V0
	var p := Vector2.ZERO
	var t := 0.0
	while t < MAX_T:
		var prev_p := p
		var k1v := accel(v, gravity, air, drag_k, kick, imp)
		var k1p := v
		var v2 := v + k1v * dt * 0.5
		var k2v := accel(v2, gravity, air, drag_k, kick, imp)
		var k2p := v2
		var v3 := v + k2v * dt * 0.5
		var k3v := accel(v3, gravity, air, drag_k, kick, imp)
		var k3p := v3
		var v4 := v + k3v * dt
		var k4v := accel(v4, gravity, air, drag_k, kick, imp)
		var k4p := v4
		p += (dt / 6.0) * (k1p + 2.0 * k2p + 2.0 * k3p + k4p)
		v += (dt / 6.0) * (k1v + 2.0 * k2v + 2.0 * k3v + k4v)
		t += dt
		if p.y <= 0.0 and prev_p.y > 0.0:
			var f: float = prev_p.y / (prev_p.y - p.y)
			return prev_p.x + f * (p.x - prev_p.x)
		if p.x > 500.0 or p.y > 800.0:
			break
	return -1.0

## Mevcut Physics.gd ile birebir aynı semi-implicit Euler, ama zemin geçişini
## interpolasyonla buluyor (Physics.gd'nin kaba clamp'inden ayrı ölçmek için).
static func euler_impact_x_interp(gravity: bool, air: bool, drag_k: float, kick: bool, imp: float, dt: float) -> float:
	var ang := deg_to_rad(ANGLE)
	var v := Vector2(cos(ang), sin(ang)) * V0
	var p := Vector2.ZERO
	var t := 0.0
	while t < MAX_T:
		var prev_p := p
		var a := accel(v, gravity, air, drag_k, kick, imp)
		v += a * dt
		p += v * dt
		t += dt
		if p.y <= 0.0 and prev_p.y > 0.0:
			var f: float = prev_p.y / (prev_p.y - p.y)
			return prev_p.x + f * (p.x - prev_p.x)
		if p.x > 500.0 or p.y > 800.0:
			break
	return -1.0

func _init() -> void:
	print("\n=== 1. İNTEGRATÖR YAKINSAMASI (impact_x, metre) ===")
	print("Senaryo                          | Physics.gd(Euler,dt=1/240,clamp) | Euler+interp dt=1/240 | RK4 dt=1/240 | RK4 dt=1/24000 (referans)")
	var scenarios := [
		{"name": "Doğru (yerçekimi+hava)", "gravity": true, "kick": false, "air": true, "drag": Physics.cfg.drag_k, "imp": 0.0},
		{"name": "Yalnız yerçekimi", "gravity": true, "kick": false, "air": false, "drag": 0.0, "imp": 0.0},
		{"name": "Yerçekimi + F (impetus)", "gravity": true, "kick": true, "air": false, "drag": 0.0, "imp": Physics.cfg.impetus_acc},
		{"name": "Yerçekimi+Hava+F", "gravity": true, "kick": true, "air": true, "drag": Physics.cfg.drag_k, "imp": Physics.cfg.impetus_acc},
	]
	for s in scenarios:
		var cur: Dictionary = Physics.simulate(s.gravity, s.kick, s.air, s.drag if s.air else Physics.cfg.drag_k, s.imp)
		var cur_x: float = cur["impact_x"]
		var eu_interp: float = euler_impact_x_interp(s.gravity, s.air, s.drag, s.kick, s.imp, Physics.DT)
		var rk4_same: float = rk4_impact_x(s.gravity, s.air, s.drag, s.kick, s.imp, Physics.DT)
		var rk4_ref: float = rk4_impact_x(s.gravity, s.air, s.drag, s.kick, s.imp, Physics.DT * 0.1)
		print("%-33s | %8.4f m                    | %8.4f m         | %8.4f m  | %8.4f m" %
			[s.name, cur_x, eu_interp, rk4_same, rk4_ref])
		var err_current_vs_ref: float = cur_x - rk4_ref
		var err_rk4same_vs_ref: float = rk4_same - rk4_ref
		print("    -> Physics.gd sapması (referansa göre): %.4f m (%.3f%%)   |   RK4@aynı dt sapması: %.4f m (%.3f%%)" %
			[err_current_vs_ref, 100.0 * err_current_vs_ref / max(rk4_ref, 0.001),
			 err_rk4same_vs_ref, 100.0 * err_rk4same_vs_ref / max(rk4_ref, 0.001)])

	print("\n=== 2. KUADRATİK DRAG KATSAYISI — FİZİKSEL TÜRETİM ===")
	var m := 0.43   # kg, FIFA standart top kütlesi
	var r := 0.11   # m, yarıçap
	var A := PI * r * r
	for rho_cd in [[1.2, 0.25], [1.225, 0.25], [1.2, 0.20], [1.2, 0.35], [1.2, 0.42]]:
		var rho: float = rho_cd[0]
		var cd: float = rho_cd[1]
		var k_phys: float = 0.5 * rho * cd * A / m
		print("rho=%.3f Cd=%.2f -> k_fiziksel = %.5f  (DRAG_K=%.3f)" % [rho, cd, k_phys, Physics.cfg.drag_k])
	# DRAG_K=0.025'in örtük Cd'si (m/r/rho sabit tutulup Cd geriye çözülür)
	var cd_implied: float = Physics.cfg.drag_k * m / (0.5 * 1.2 * A)
	print("Not: k_fiziksel = 0.5*rho*Cd*A/m ; A = pi*r^2 = %.5f m^2" % A)
	print("DRAG_K=%.3f -> örtük Cd (rho=1.2) = %.3f" % [Physics.cfg.drag_k, cd_implied])

	print("\n=== 3. YUVARLANMA SIRASINDA HAVA DİRENCİ + ROLL_FRICTION ÇAKIŞMASI ===")
	var with_air: Dictionary = Physics.simulate(true, false, true, Physics.cfg.drag_k, 0.0)
	# aynı senaryoyu air=false ile tekrar koş (yuvarlanırken sürtünme kaynağı yalnız ROLL_FRICTION)
	var without_air: Dictionary = Physics.simulate(true, false, false, Physics.cfg.drag_k, 0.0)
	print("Hava AÇIK  -> impact_x=%.3f rest_x=%.3f (yuvarlanma mesafesi=%.3f m)" %
		[with_air["impact_x"], with_air["rest_x"], with_air["rest_x"] - with_air["impact_x"]])
	print("Hava KAPALI-> impact_x=%.3f rest_x=%.3f (yuvarlanma mesafesi=%.3f m)" %
		[without_air["impact_x"], without_air["rest_x"], without_air["rest_x"] - without_air["impact_x"]])
	# çarpma anındaki yatay hızı bul (impact noktasındaki nokta)
	var vx_at_impact := 0.0
	for pt in with_air["points"]:
		if absf(pt["p"].x - with_air["impact_x"]) < 0.01:
			vx_at_impact = pt["v"].x
			break
	var drag_acc_at_impact: float = Physics.cfg.drag_k * absf(vx_at_impact) * absf(vx_at_impact)
	print("Çarpma anı yatay hız ~ %.2f m/s -> o anki hava-direnci ivmesi ~ %.3f m/s^2 (ROLL_FRICTION=%.1f m/s^2, oran=%.1f%%)" %
		[vx_at_impact, drag_acc_at_impact, Physics.cfg.roll_friction, 100.0 * drag_acc_at_impact / Physics.cfg.roll_friction])

	print("\n=== 4. MENZİL TABLOSU + KALE UYUMU (GOAL_X=%.1f m, sim_config.tres) ===" % Physics.cfg.goal_x)
	var analytic_no_drag: float = V0 * V0 * sin(deg_to_rad(2.0 * ANGLE)) / G
	print("Analitik dragsız menzil (v0=30,45 derece) = %.3f m  (doküman: 91.7 m)" % analytic_no_drag)
	for s in scenarios:
		var res: Dictionary = Physics.simulate(s.gravity, s.kick, s.air, s.drag if s.air else Physics.cfg.drag_k, s.imp)
		var landed: bool = res["landed"]
		print("%-33s | impact_x=%8.3f m | landed=%s" % [s.name, res["impact_x"], str(landed)])
	var real: Dictionary = Physics.real_path()
	print("-> Doğru cevabın (real_path) iniş noktası = %.3f m; GOAL_X=%.1f m civarında olmalı (hit_bulls toleransı)." % [real["impact_x"], Physics.cfg.goal_x])

	print("\n=== 5. SEKME/YUVARLANMA GÖRSEL TUTARLILIK (doğru senaryo) ===")
	var r2: Dictionary = Physics.simulate(true, false, true, Physics.cfg.drag_k, 0.0)
	var bounces := 0
	var last_y := -1.0
	for pt in r2["points"]:
		if pt["p"].y <= 0.001 and last_y > 0.001:
			bounces += 1
		last_y = pt["p"].y
	print("Toplam sekme sayısı=%d, ilk temas=%.3f m, son durma=%.3f m, bitiş zamanı=%.3f s" %
		[bounces, r2["impact_x"], r2["rest_x"], r2["points"][-1]["t"]])

	print("\n=== BİTTİ ===")
	quit(0)
