class_name Physics
## Yörünge integratörü — dünya birimleri (metre, y yukarı).
## Dönen sözlük:
##   points : [{p:Vector2, v:Vector2, t:float}]
##   impact_x : ilk yere çarpma noktası (hedef puanı BURADAN hesaplanır)
##   landed   : top yere indi mi (yerçekimsiz senaryolarda false)
##   rest_x   : top nerede durdu (sekmeler bitince)

## Ayarlanabilir parametreler artık burada DEĞİL — res://config/sim_config.tres
## içinde (kod yazmadan Godot Inspector'dan değiştirilir, bkz. SimConfig.gd).
static var cfg: SimConfig = preload("res://config/sim_config.tres")

const DT := 1.0 / 240.0        # entegrasyon adımı — TEKNİK, buraya dokunma
const MAX_X := 200.0           # ekran güvenlik sınırı — TEKNİK
const MAX_Y := 400.0           # ekran güvenlik sınırı — TEKNİK

## Kuvvet seçimine göre yörünge. Sekme ve yuvarlanma dahil; top DURUNCA biter,
## böylece "havada asılı kalma" hatası oluşmaz.
## stick_x >= 0 ise: top hedef tahtasına düşerse SAPLANIR (dart gibi), sekmez.
## Iskalarsa normal sekme/yuvarlanma uygulanır.
## drag_k/imp varsayılanları yalnızca güvenlik ağı — gerçek çağrılar hep
## cfg.drag_k / cfg.impetus_acc'i açıkça geçirir.
static func simulate(gravity: bool, kick: bool, air: bool,
		drag_k := 0.025, imp := 15.0,
		stick_x := -1.0, stick_r := 0.0) -> Dictionary:
	var ang := deg_to_rad(cfg.angle_deg)
	var vel := Vector2(cos(ang), sin(ang)) * cfg.v0
	var pos := Vector2.ZERO
	var t := 0.0
	var pts: Array = [{"p": pos, "v": vel, "t": 0.0}]
	var impact_x := -1.0
	var landed := false
	var rolling := false
	while t < cfg.max_t:
		var acc := Vector2.ZERO
		if gravity:
			acc.y -= cfg.gravity_g   # kütleden ETKİLENMEZ — gerçek fizik (Galileo)
		if air:
			acc -= (drag_k * vel.length() * vel) / cfg.mass_kg
		if kick and vel.length() > 0.01:
			acc += (vel.normalized() * imp) / cfg.mass_kg
		if rolling:
			# yerde yuvarlanma: hareket yönünün tersine sabit sürtünme
			if absf(vel.x) > 0.01:
				acc.x -= signf(vel.x) * cfg.roll_friction
			acc.y = 0.0
		vel += acc * DT
		pos += vel * DT
		t += DT

		if pos.y <= 0.0 and not rolling:
			# --- ZEMİNE ÇARPMA ---
			pos.y = 0.0
			if impact_x < 0.0:
				impact_x = pos.x        # PUAN: ilk temas noktası
				landed = true
				if stick_x >= 0.0 and absf(pos.x - stick_x) <= stick_r:
					vel = Vector2.ZERO   # hedefe saplandı — sekmez
					pts.append({"p": pos, "v": vel, "t": t})
					break
			if gravity and absf(vel.y) > cfg.rest_vy:
				vel.y = -vel.y * cfg.restitution      # sek
				vel.x *= cfg.bounce_friction
			else:
				vel.y = 0.0
				rolling = true                    # artık yuvarlanıyor
		if rolling and absf(vel.x) < 0.05:
			vel = Vector2.ZERO
			pts.append({"p": pos, "v": vel, "t": t})
			break                                  # TAM DURDU -> yörünge biter
		pts.append({"p": pos, "v": vel, "t": t})
		if pos.x > MAX_X or pos.y > MAX_Y:
			break                                  # ekranı terk etti (yerçekimsiz senaryo)
	return {
		"points": pts,
		"impact_x": impact_x,
		"landed": landed,
		"rest_x": pts[-1]["p"].x,
	}

## GERÇEK yörünge — her zaman doğru fizik (yerçekimi + gerçek hava direnci).
static func real_path(stick_x := -1.0, stick_r := 0.0) -> Dictionary:
	return simulate(true, false, true, cfg.drag_k, 0.0, stick_x, stick_r)

## Hedef tahtasının merkezi = gerçek fiziğin ilk yere değdiği nokta.
static func target_x() -> float:
	var r := real_path()
	return r["impact_x"] if r["impact_x"] > 0.0 else 52.0
