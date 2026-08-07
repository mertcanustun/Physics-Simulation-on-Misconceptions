class_name Physics
## Yörünge integratörü — dünya birimleri (metre, y yukarı).
## Dönen sözlük:
##   points : [{p:Vector2, v:Vector2, t:float}]
##   impact_x : ilk yere çarpma noktası (hedef puanı BURADAN hesaplanır)
##   landed   : top yere indi mi (yerçekimsiz senaryolarda false)
##   rest_x   : top nerede durdu (sekmeler bitince)

const G := 9.81
# Hava direnci — kuadratik direnç katsayısı. Tek sabit (seviye seçimi kaldırıldı,
# 2026-08-07): "Hava direnci" artık yerçekimi/vuruş kuvveti gibi basit açık/kapalı.
const DRAG_K := 0.025
const IMPETUS_ACC := 15.0   # "vuruş kuvveti itmeye devam eder" yanılgısı (m/s^2) — istenirse 30.0

# SABİT ATIŞ — kullanıcı artık hız/açı seçemez (deneysel kontrol).
const FIXED_V0 := 30.0
const FIXED_ANGLE := 45.0

const DT := 1.0 / 240.0
const MAX_T := 16.0
const MAX_X := 200.0
const MAX_Y := 400.0

# Sekme (zıplama) — hedef bir çukur değil, yere serili hedef tahtası olduğu için
# top çarpınca seker. Puan İLK çarpma noktasından verilir.
const RESTITUTION := 0.34      # dikey hız kaybı
const BOUNCE_FRICTION := 0.72  # çarpmada yatay hız kaybı
const ROLL_FRICTION := 6.5     # yuvarlanma sürtünmesi (m/s^2) — top hedefin yanında durur
const REST_VY := 1.2           # bu dikey hızın altında artık sekmez

## Kuvvet seçimine göre yörünge. Sekme ve yuvarlanma dahil; top DURUNCA biter,
## böylece "havada asılı kalma" hatası oluşmaz.
## stick_x >= 0 ise: top hedef tahtasına düşerse SAPLANIR (dart gibi), sekmez.
## Iskalarsa normal sekme/yuvarlanma uygulanır.
static func simulate(gravity: bool, kick: bool, air: bool,
		drag_k := DRAG_K, imp := IMPETUS_ACC,
		stick_x := -1.0, stick_r := 0.0) -> Dictionary:
	var ang := deg_to_rad(FIXED_ANGLE)
	var vel := Vector2(cos(ang), sin(ang)) * FIXED_V0
	var pos := Vector2.ZERO
	var t := 0.0
	var pts: Array = [{"p": pos, "v": vel, "t": 0.0}]
	var impact_x := -1.0
	var landed := false
	var rolling := false
	while t < MAX_T:
		var acc := Vector2.ZERO
		if gravity:
			acc.y -= G
		if air:
			acc -= drag_k * vel.length() * vel
		if kick and vel.length() > 0.01:
			acc += vel.normalized() * imp
		if rolling:
			# yerde yuvarlanma: hareket yönünün tersine sabit sürtünme
			if absf(vel.x) > 0.01:
				acc.x -= signf(vel.x) * ROLL_FRICTION
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
			if gravity and absf(vel.y) > REST_VY:
				vel.y = -vel.y * RESTITUTION      # sek
				vel.x *= BOUNCE_FRICTION
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
	return simulate(true, false, true, DRAG_K, 0.0, stick_x, stick_r)

## Hedef tahtasının merkezi = gerçek fiziğin ilk yere değdiği nokta.
static func target_x() -> float:
	var r := real_path()
	return r["impact_x"] if r["impact_x"] > 0.0 else 52.0
