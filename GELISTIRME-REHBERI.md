# Geliştirme Rehberi — Kicked-Ball Simülasyonu (Godot)

> Bu dosya hem ekip için durum notu, hem de "görsel/ses asset'lerini kim, hangi
> formatta hazırlayacak" spec'i, hem de **bir Claude oturumuna verilecek brief**.
> Yeni bir Claude'a çalıştırırken: bu dosyayı + repoyu (`git pull`) ver, yeterli.

---

## 0. Bu proje nedir (1 paragraf)

TÜBİTAK 2209-A kapsamında **kavram yanılgısı** simülasyonu (Godot 4.5, GDScript).
Öğrenci topa vurulmadan önce "top havadayken hangi kuvvetler etki eder?" sorusuna
cevap veriyor (Yerçekimi / Vuruş kuvveti F / Hava direnci), sonra kendi seçtiği
dünyanın fiziğini izliyor. Doğru cevap = **yerçekimi + hava direnci** (vuruş kuvveti
kapalı). Amaç: öğrenci kendi yanılgısının sonucunu görüp (top uzaya uçar / kaleyi
ıskalar) "gerçek yörünge" ile karşılaştırarak fikrini değiştirsin. Fizik gerçek
sayısal entegrasyon (`scripts/Physics.gd`), görsel `scripts/FieldView.gd`, akış
`scripts/Main.gd`. UI tamamen kodla kuruluyor (`Main.tscn` neredeyse boş).

---

## 1. Bugün (2026-07-23) yapılan değişiklikler

- **Gol senaryosu:** doğru cevap topu kaleye sokacak şekilde ayarlandı (`GOAL_X`).
- **Kuvvet okları:** seçilen kuvvetler vektör oku olarak gösteriliyor (önizleme +
  uçuş); ok boyu kuvvet değeriyle orantılı; hava direnci oku kalın + koyu dış hatlı.
- **Sürtünme:** "Hava direnci" açıkken **Az / Orta / Fazla** seçimi (Orta = doğru senaryo).
- **Vuruş kuvveti F:** büyüklük kaydırıcısı (2–20); ok ve fizik ona göre ölçeklenir.
- **Kamera:** yerçekimi-sadece → geri çekilip topun kaleyi ıskaladığını gösterir,
  sonra topa yakınlaşır. Uzaya uçuş → kamera topu takip eder, top **ekranın üstünden
  çıkar**, çim/zemin aşağı kayıp gökyüzü/uzaya (kararan gök + yıldızlar) geçer.
- **Üst panelde canlı hız;** kuvvetsiz durumda "Hız: X m/s **(sabit)**".
- **Gol kutlaması:** örgü file topun girdiği yerden şişer + **konfeti patlaması** +
  **ekran sarsıntısı** + "GOL!" yazısı + art arda halkalar.
- **8-bit Messi** (kod çizimli piksel sprite), boyu çim üst kenarına denk gelir.
- **Koşu-vuruş girişi:** katılımcı girince önce Messi soldan koşup topa gelir, ayak
  değince donar; **sonra** soru paneli çıkar (Predict→Observe akışı).

Not: Şu an futbolcu/top/arka plan/file **tamamen kodla** (`draw_rect`/`draw_line`)
çiziliyor — bu yüzden "2D zayıf" görünüyor. Aşağıdaki asset'lerle sprite'a çevirince
görünüm ciddi profesyonelleşecek.

---

## 2. Görsel yükseltme için LAZIM OLAN ASSET'ler

### 2a. ÖNCE: tek bir stil seçin (önemli)
Şu an karışık (gerçekçi-denemesi file + düz şekiller + piksel Messi) olduğu için zayıf
duruyor. **Tek stile bağlanın.** Öneri: **piksel-art** (sevdiğiniz 8-bit Messi'yle
uyumlu). Alternatif: temiz düz-vektör. Tüm asset'ler **aynı stil ve palette** olmalı.

### 2b. Sprite (PNG) listesi — hepsi şeffaf arka plan (alpha), yandan görünüm, sağa bakan

| Dosya | İçerik | Öneri boyut | Not |
|---|---|---|---|
| `player_idle.png` | Futbolcu ayakta, yandan, **sağa** bakar | ~64×128 px | Ayaklar en altta (taban hizası sabit) |
| `player_run.png` | Koşu animasyonu **spritesheet** | 6 kare yan yana (ör. 6×64=384 × 128) | Giriş koşusunda oynatılacak |
| `player_kick.png` | Vuruş anı (bacak uzanmış) | ~64×128 px | 1 kare yeter (istersen 2) |
| `ball.png` | Futbol topu, yandan | 64×64 px | Yuvarlak + pentagonlar; dönüşü kodla yaparız |
| `sky_stadium.png` | Gökyüzü + bulanık tribün (arka plan) | 1920×1080 (geniş) | En arkada durur; **çim İÇERMESİN** (çim kodla çizilip kayıyor) |

İsteğe bağlı (etkisi yüksek ama şart değil):
| `grass_tile.png` | Tekrarlanabilir çim dokusu | 256×256, seamless | Düz yeşil yerine doku |
| `goal_frame.png` | Kale direği + üst kiriş (yandan) | ~200×260 px | **Ağ (file) DAHİL ETME** — file kodla çiziliyor ki şişebilsin |

**Kurallar:** PNG + şeffaflık; futbolcu ve top **sağa** baksın (kale sağda);
futbolcunun tabanı karenin en altında olsun (hizalama için); tüm karakter kareleri
aynı boyutta olsun.

### 2c. Ses (audio) listesi — `.ogg` tercih (kısa, mono yeterli)

| Dosya | Ne zaman | Süre |
|---|---|---|
| `kick.ogg` | Top vurulduğunda ("Ne olacağını gör") | ~0.3 s |
| `goal.ogg` | Gol olunca (tezahürat/düdük) | ~1–2 s |
| `whistle.ogg` (ops.) | Giriş/başlangıç düdüğü | ~0.5 s |
| `crowd.ogg` (ops.) | Arka plan taraftar uğultusu (loop) | ~5–10 s |

Godot `.ogg`, `.wav`, `.mp3` destekler; kısa efektler için `.ogg`/`.wav` ideal.
Dosyaları küçük tutun.

### 2d. Klasör yapısı (repoda oluşturun ve dosyaları buraya koyun)
```
res://assets/
├── sprites/   → player_idle.png, player_run.png, player_kick.png, ball.png, sky_stadium.png, (grass_tile.png, goal_frame.png)
└── audio/     → kick.ogg, goal.ogg, (whistle.ogg, crowd.ogg)
```
Godot bunları otomatik import eder (`.import` dosyaları oluşur — onları da commit'leyin).

---

## 3. Asset üretimi (nasıl elde edersiniz)

- **Bedava hazır (CC0):** kenney.nl (spor/karakter paketleri), itch.io, OpenGameArt.
- **AI ile piksel-art + animasyon:** **PixelLab** veya **Retro Diffusion**
  (karakterin idle/run/kick karelerini üretir; Aseprite eklentileri var).
- **AI ile tutarlı 2D asset:** Scenario.gg, Layer.ai.
- **Arka plan/stadyum:** Midjourney / Flux / SDXL, ya da hazır bir stadyum görseli.
- **Ses:** freesound.org (CC0 filtrele), pixabay.com/sound-effects, ya da AI ses.

> İpucu: bu araç seçimini not edin — projenin "hangi AI araçları kullanıldı" rehberi
> zaten bir TÜBİTAK deliverable'ı.

---

## 4. Asset'ler gelince ne yapılacak (entegrasyon — Claude yapar)

Kod şu an her şeyi `FieldView._draw()` içinde primitive'lerle çiziyor. Sprite'a
geçmek için **düğüm eklemeye gerek yok**: aynı yerlerde `draw_texture` /
`draw_texture_rect` kullanılır (kamera/animasyon mantığı korunur):
- `_draw_player()` → koşu için `player_run` spritesheet karesi (girişte), sonra
  `player_idle`; vuruş anında `player_kick`.
- Top → `ball.png` (dönüşü `draw_set_transform` ile).
- Arka plan → en başta `sky_stadium.png` tam ekran; çim kodla üstüne (kaymaya devam).
- File → **kodda kalır** (şişme/deformasyon için); istenirse sadece direkler
  `goal_frame.png`.
- Ses → `Main.gd`'ye iki `AudioStreamPlayer` (kick, goal); `_on_run`'da kick,
  gol tespitinde goal çalınır.

---

## 5. Claude'a nasıl promptlamalı (kopyala-yapıştır)

> Bu Godot 4.5 projesinde futbolcu, top, arka plan şu an kodla (`draw_rect`/
> `draw_line`) çiziliyor (`scripts/FieldView.gd`, `scripts/Main.gd`). `assets/`
> altına PNG ve ses dosyaları koydum. Şunları yap, **kamera/fizik/akış mantığını
> BOZMADAN**:
> 1. `_draw_player()`'ı sprite'a çevir: girişteki koşuda `assets/sprites/player_run.png`
>    (6 kare spritesheet) animasyonunu oynat, durunca `player_idle.png`, vuruş anında
>    `player_kick.png`. Futbolcu boyu şu anki gibi (başı çim üst kenarına denk gelsin).
> 2. Topu `assets/sprites/ball.png` ile çiz (uçarken hafif dönsün).
> 3. En arka plana `assets/sprites/sky_stadium.png`'i koy; çim kodda kalsın (kayma efekti bozulmasın).
> 4. `Main.gd`'ye iki `AudioStreamPlayer` ekle: `assets/audio/kick.ogg` topa vuruşta
>    (`_on_run`), `assets/audio/goal.ogg` gol olunca (FieldView gol tespitinde bir
>    sinyal yayınlasın, Main dinlesin).
> 5. File'ye (ağ) DOKUNMA — kodda kalsın, şişme çalışıyor.
>
> Godot'u sen çalıştıramıyorsan değişiklikten sonra bana "F6 ile test et" de; ben
> deneyip ekran görüntüsü/hatayı paylaşırım.

**Claude'a ne VERİLECEK:** (a) bu repo (`git clone`/`git pull`), (b) bu dosya
(`GELISTIRME-REHBERI.md`), (c) `assets/` altına konmuş PNG + ses dosyaları.

---

## 6. Kalan yol haritası / açık işler

- [ ] Sprite asset'leri + ses entegrasyonu (yukarıdaki).
- [ ] **Sürtünme seviyesi ve vuruş kuvveti değerini CSV loguna ekle** (`DataLog.log_attempt`
      şu an bunları kaydetmiyor; araştırma verisi için önemli).
- [ ] Geri bildirim vs gol tutarlılığı: "Doğru!" yalnızca kuvvet seçimine bakıyor;
      gol ise sürtünme dahil her şey doğru olunca oluyor — pedagojik karar (İlayda/Berk).
- [ ] Repo **public**: `data/admin_codes.json` (Y-ADM-996) ve `data/codes.json`
      herkese açık — gerçek veri toplamadan private yapın ya da admin kodunu değiştirin.
- [ ] Turkish/bilingual son okuma; sınıf projektöründe kontrast testi.

---

## 7. Çalıştırma hatırlatması

Godot 4.5 ile `project.godot`'u aç → **F6** (Run Current Scene). Girişte katılımcı
kodu iste: `data/codes.json`'daki herhangi biri (ör. `L-0-NN-N-E-428`). Admin paneli
için `Y-ADM-996`. Veri `user://session_log.csv`'ye yazılır (repoda değil).
