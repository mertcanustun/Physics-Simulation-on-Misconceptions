# DEVİR NOTU — Kicked-Ball Simülasyonu (fizik doğruluğu oturumu)

> Bu dosya, yeni bir Claude Code (CLI + godot-mcp) oturumunu hızla başlatmak için yazıldı.
> **İlk iş:** bu dosyayı ve `GELISTIRME-REHBERI.md`'yi oku. Sonra aşağıdaki "İlk görev"e geç.

## 0. Bağlam / kapsam
- Proje: **TÜBİTAK 2209-A kavram yanılgısı simülasyonu** (Godot, GDScript). NGC/Millet Kütüphanesi PoC işinden **ayrı** bir iş; onunla karıştırma.
- Repo: `mertcanustun/Physics-Simulation-on-Misconceptions` — **ekipçe ortak kullanılan repo** (Defne + Mert). Lokal klon: `/Users/defne/physics-sim`.
- **Git kuralı:** commit/push **serbest** (ortak repo). Ama: anlamlı commit mesajı yaz, **co-author EKLEME** (Claude co-author satırı yok). Riskli/büyük değişikliklerde kullanıcıya danış.

## 1. Ortam / çalıştırma
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (sürüm **4.5.1 stable**; proje `project.godot`'ta "4.6" işaretli — çalışıyor, sadece ufak sürüm uyarısı normal).
- Ana sahne: `res://scenes/Main.tscn` (UI neredeyse tümüyle kodla kuruluyor, `Main.gd`).
- **godot-mcp kurulu** — projeyi `run_project` ile çalıştır, `get_debug_output` ile hataları/print'leri OKU. Manuel alternatif: kullanıcı editörde F5.

## 2. Dosya haritası (scripts/)
- `Physics.gd` — **yörünge integratörü** (bu oturumun asıl odağı). Saf statik fonksiyonlar, dünya birimi (metre, y yukarı).
- `FieldView.gd` — görsel/render, kamera, uçuşu oynatır; `flight_finished`, `target_hit` sinyalleri; GOL kararı (`hit_bulls`).
- `Main.gd` — akış/UI (Predict→Observe), soru paneli, sonuç kutusu, telemetri tetikleme.
- `Session.gd` / `Telemetry.gd` / `DataLog.gd` — oturum + veri toplama (JSONL/CSV; F8/F10 export).
- `Codes.gd` — katılımcı/yönetici kodları (yönetici: Y-ADM-996), grup etiketleri.

## 3. Fizik modeli (Physics.gd — mevcut durum)
- İntegrasyon: **semi-implicit (symplectic) Euler**, `DT = 1/240 s`, `MAX_T = 16 s`. (`vel += acc*DT; pos += vel*DT`)
- Sabit atış (deneysel kontrol): **v0 = 30 m/s, açı = 45°** — kullanıcı hız/açı seçemez; sonucu yalnız kuvvet seçimi belirler.
- Kuvvetler:
  - Yerçekimi: `acc.y -= G` (G = 9.81)
  - Hava direnci (kuadratik): `acc -= drag_k * vel.length() * vel`; tek sabit `DRAG_K = 0.025` (2026-08-07: Az/Orta/Fazla seviye seçimi kaldırıldı — artık Yerçekimi/F gibi basit açık/kapalı)
  - **Vuruş kuvveti F (impetus):** `acc += vel.normalized() * IMPETUS_ACC` (15 m/s²) — **KASITLI YANLIŞ FİZİK** (ortaçağ impetus yanılgısı: "temas bitince de itmeye devam eder"). Bu bir bug DEĞİL, pedagojinin kalbi. **DÜZELTME.**
- Zemin çarpması: `pos.y <= 0` → puan ilk temas `impact_x`; sonra sekme (RESTITUTION 0.34, BOUNCE_FRICTION 0.72) veya yuvarlanma (ROLL_FRICTION 6.5) → top DURUNCA yörünge biter.
- **`real_path()`** = her zaman doğru fizik (yerçekimi + DRAG_K, impetus KAPALI). Seviye seçimi kalktığından beri kullanıcının simülasyonuyla zaten aynı `DRAG_K`'yi kullanıyor — ayrıca sapma riski yok. **Bu tasarımı bozma.**
- Doğru cevap senaryosu = **yerçekimi + hava direnci**, vuruş kuvveti kapalı → top kaleye gider (GOL). Kale `FieldView.GOAL_X = 34.0` m'de (2026-08-07'de DRAG_K=0.025'e göre taşındı; doğru cevabın inişi ~37.0 m).

## 4. İLK GÖREV: fizik doğruluğu denetimi — ✅ TAMAMLANDI (2026-08-07)
`tools/physics_probe.gd` ile ölçüldü (bkz. `GELISTIRME-REHBERI.md` "Testler" ve
"Doğrulanmış fizik değerleri"). Özet: Euler@1/240 sapması <%0.3, RK4'e geçmeye
gerek yok; drag katsayısı sonradan tek sabite indirildi (`DRAG_K=0.025`, bkz.
madde 3); yuvarlanmadaki drag+ROLL_FRICTION çift sayım değil, iki ayrı gerçek
kuvvet; kale konumu (`GOAL_X`) yeni fiziğe göre 34.0 m'ye taşındı. Aşağıdaki
madde listesi orijinal görev tanımı olarak (tarihsel referans) korunuyor:

Amaç: "doğru" senaryonun (real_path) fiziği gerçekçi/tutarlı mı — **kasıtlı yanılgıları bozmadan**. İncelenecek adaylar:
1. **İntegratör doğruluğu:** Euler @ DT=1/240 kuadratik dragla enerji sürüklenmesi yaratıyor mu? RK4'e geçmek anlamlı mı, yoksa görsel farkı ihmal edilebilir mi? (önce ölç, sonra karar)
2. **Kuadratik drag katsayıları fiziksel mi:** drag_k değerleri (0.006–0.022) topun Cd/alan/kütlesinden türetilmemiş, elle ayarlı. Gerçek bir futbol topuna (m≈0.43 kg, r≈0.11 m, Cd≈0.25) göre büyüklük mertebesi tutuyor mu? Eğitim için "makul" yeterli olabilir ama teyit et.
3. **Yuvarlanma sırasında hava direnci:** rolling dalında `acc.x` içinde hem ROLL_FRICTION hem hava dragı var (satır 57-64). Bilinçli mi, çift sayım mı?
4. **Menzil kontrolü:** v0=30, 45°, dragsız menzil ≈ 91.7 m; DRAG_MED ile ne oluyor, hedef (`target_x`) makul bir sahaya denk geliyor mu?
5. **Sabitlerin tutarlılığı:** REST_VY, RESTITUTION, BOUNCE_FRICTION görsel olarak ikna edici sekme veriyor mu (öğrenci "sahte" hissetmesin)?

**Yöntem:** önce `run_project` + birkaç senaryo (doğru cevap / sadece yerçekimi / impetus açık) çalıştır, `get_debug_output`'tan sayısal çıktı/print al; gerekiyorsa `Physics.gd`'ye geçici `print` ekleyip menzil/enerji ölç. Değişiklik önermeden önce **ölçüp göster.**

## 5. Yapma / dikkat
- Impetus (vuruş kuvveti F) modelini "gerçekçi" diye düzeltme — kasıtlı yanılgı.
- `real_path`'in kullanıcı sürtünme seçiminden bağımsızlığını bozma.
- Sabit v0/açı deneysel kontrol; "kullanıcı açı seçsin" gibi öneri getirme (bilinçli kaldırılmış).
- Commit/push serbest (ortak repo) ama co-author ekleme; büyük değişiklikte danış.
