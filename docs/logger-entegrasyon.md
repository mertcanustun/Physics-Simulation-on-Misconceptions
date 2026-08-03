# Etkileşim Telemetrisi (Logger) — Entegrasyon Notu

> **Kim için:** Mert (sim geliştirme). **Kim yazdı:** Defne (logger).
> **Amaç:** Kullanıcının kararı NASIL verdiğini yakalamak — ilk yaklaştığı seçenek,
> hover süreleri, mouse yörüngesi, tıklamalar, karar gecikmesi, cevap değişiklikleri.
> Bu, `DataLog` (deneme-başına özet CSV) ile birlikte çalışır; onun yerine geçmez.

## 1. Ne eklendi

| Dosya | Değişiklik |
|---|---|
| `scripts/Telemetry.gd` | **YENİ** — olay-bazlı logger (autoload). Kendi başına mouse yolu + tıklama yakalar. |
| `project.godot` | `[autoload]` altına `Telemetry="*res://scripts/Telemetry.gd"` eklendi. |
| `scripts/Main.gd` | 15 satır **hook** çağrısı (aşağıda). Başka mantık değişmedi. |

Çıktı dosyası: **`user://events_log.jsonl`** (JSON Lines — her satır bağımsız JSON).
- Masaüstü konumu: `~/Library/Application Support/Godot/app_userdata/Kicked-Ball Simulation/events_log.jsonl` (mac) · Windows'ta `%APPDATA%\Godot\app_userdata\...`
- Web sürümünde: tarayıcı IndexedDB; **F8** ile indirilir.

## 2. Autoload kaydı (elle yapman gerekirse)

Project Settings → **Autoload** → Path: `res://scripts/Telemetry.gd`, Node Name: `Telemetry`, **Enable**.
(veya `project.godot` içine:)
```
[autoload]

Telemetry="*res://scripts/Telemetry.gd"
```
`Telemetry.gd` içinde `class_name` YOKTUR — global erişim autoload adından gelir.

## 3. Main.gd hook'ları (kendi sürümüne elle uygulayacaksan)

Hepsi tek satır. Doğru yerlere koymak yeter:

| Nerede | Satır |
|---|---|
| `_on_continue` — girişten sonra, `start_intro()` öncesi | `Telemetry.begin_session(participant_code, group, Codes.has_seen_topic(c), official)` |
| `_on_intro_done` — soru gösterilince | `Telemetry.decision_start(attempt + 1)` |
| `_on_change_answer` — başta | `Telemetry.answer_change()` |
| `_on_change_answer` — soru tekrar açılınca | `Telemetry.decision_start(attempt + 1)` |
| `_on_reset_sim` — soru tekrar açılınca | `Telemetry.decision_start(attempt + 1)` |
| `_force_box` — her kuvvet kutusuna | `pc.mouse_entered.connect(func(): Telemetry.option_hover(title, true))` |
| `_force_box` | `pc.mouse_exited.connect(func(): Telemetry.option_hover(title, false))` |
| `_force_box` — `cb.toggled` içinde | `Telemetry.option_toggle(title, on)` |
| `_set_friction` | `Telemetry.param_change("friction", ["Az","Orta","Fazla"][idx])` |
| `_on_run` — official teyidinden sonra | `Telemetry.set_official(official)` |
| `_on_run` | `Telemetry.answer_submit(g, k, a, ["Az","Orta","Fazla"][friction_level], correct, category)` |
| `_on_replay` — başta | `Telemetry.replay()` |
| `_on_flight_finished` — sonda | `Telemetry.run_complete(gol, field.impact_x)` |
| `_show_entry` — başta | `Telemetry.end_session()` |
| `_unhandled_input` — F8 | `_export_events()` (+ küçük FileDialog, bkz. Main.gd'deki `events_dialog`) |

**Otomatik** (hook gerekmez): `mouse_move` (karar aşamasında ~15 Hz) ve `click` — Telemetry
bunları `_process`/`_input` ile kendi yakalar.

## 4. Kaydedilen olaylar (event türleri)

Her satırda ortak alanlar: `ts_ms, sid, code, group, seen, mode, attempt, type`.
Türe özel alanlar:

| type | ek alanlar | ne anlatır |
|---|---|---|
| `session_begin` | viewport_w/h | oturum başladı |
| `decision_start` | — | soru gösterildi, karar aşaması başladı |
| `first_interaction` | kind, factor?, since_decision_ms | **düşünme süresi** = ilk eyleme kadar geçen ms |
| `option_hover` | factor, phase(enter/leave), since_decision_ms, dwell_ms | **ilk yaklaşılan seçenek** + her seçenekte durma süresi |
| `option_toggle` | factor, checked, order, since_decision_ms | işaretleme sırası ve zamanlaması |
| `param_change` | name, value, since_decision_ms | sürtünme Az/Orta/Fazla değişimi |
| `mouse_move` | x, y, since_decision_ms | karar sırasında mouse yörüngesi |
| `click` | x, y, button, deciding, since_decision_ms | tıklama konumları |
| `answer_submit` | gravity, kick, air, friction, correct, category, decision_ms, toggle_count | **karar gecikmesi** + kaç kez fikir değiştirdiği (toggle_count) |
| `answer_change` | attempt | "Yeni cevap dene"ye bastı |
| `replay` | attempt | "Tekrar dene" |
| `run_complete` | goal, impact_x, category | uçuş sonucu |
| `session_end` | — | giriş ekranına döndü |

Örnek satır:
```json
{"ts_ms":1.75e12,"sid":"1753900000-4821","code":"L-3-MF-B-K-123","group":"...","seen":false,"mode":"official","attempt":1,"type":"option_hover","factor":"Vuruş kuvveti F","phase":"enter","since_decision_ms":2140}
```

## 5. "Confusion" (kararsızlık) sinyalleri

Ayrı bir "confusion" olayı YOK; ham sinyalleri kaydediyoruz, analizde çıkarılır:
- **Yüksek `toggle_count`** (çok kez işaretleyip kaldırma),
- Aynı `factor`'a **tekrar tekrar hover** (option_hover enter sayısı),
- Uzun **`decision_ms`** / uzun ilk `first_interaction.since_decision_ms`,
- Çok sayıda **`answer_change`**,
- Mouse yörüngesinde ileri-geri gidip gelme (`mouse_move` analizi).

## 6. Analiz / birleştirme

- `DataLog` (CSV, deneme özeti) ile `Telemetry` (JSONL, olaylar) **`sid` + `code` + `attempt`** üzerinden birleşir.
- JSONL'yi Python'da: `pandas.read_json(path, lines=True)`.

## 7. Dışa aktarma & doğrulama

- **F8** — etkileşim verisini (JSONL) dışa aktar (web'de indirir).
- **F9** — kayıt durumu (DataLog özeti).
- **F10** — DataLog CSV dışa aktar.
- Geliştirme testi: veri toplama kapalıyken de yazması için `Telemetry.gd` içinde
  `DEBUG_LOG_IN_TRIAL = true` yap (canlı testte **false** bırak).

## 8. Gizlilik

`DataLog` ile aynı ilke: **yalnızca yönetici o kod için veri toplamayı açtıysa** (official)
yazılır; "deneme modu"nda hiçbir şey diske yazılmaz. Sadece anonim katılımcı kodu tutulur.
