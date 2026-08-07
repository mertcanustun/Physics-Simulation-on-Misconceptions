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

## 1b. Görsel/işitsel asset entegrasyonu (2026-07-25)

- **Futbolcu artık gerçek sprite** (kodla çizilen piksel Messi yedeğe alındı):
  koşu-vuruş girişinde **run → kick** animasyonu, sonra **idle**; şeffaf kareler
  `get_used_rect` ile otomatik kırpılıp ayakları zemine hizalanıyor.
- **Top gerçek sprite** (uçarken dönüyor); şeffaf PNG.
- **Sesler:** topa vuruşta **kick**, golde **tezahürat (applause)** — `AudioStreamPlayer`.
- Sprite'lar `res://assets/sprites/`, sesler `res://assets/audio/` altında; kod
  `draw_texture_rect_region` ile çiziyor, dosya yoksa piksel/kod yedeğe düşüyor.

### Kullanılan araçlar (deliverable notu)
- **PixelLab** (pixellab.ai) — 8-bit futbolcu karakteri + idle/koşu/vuruş animasyonları
  (Character Creator, v3, Sidescroller, east yönü, 124×124, şeffaf PNG kareler).
- **Pixabay** (pixabay.com/sound-effects) — ses efektleri: kick + crowd applause (bedava).
- **remove.bg** — top görselinin arka planını şeffaflaştırmak için.

> Not: futbolcu/top/file kodla da çizilebiliyor (yedek); asset'ler yalnızca görünümü
> yükseltiyor, fizik/pedagoji mantığına dokunmuyor. Kalan tek görsel: stadyum arka planı
> (opsiyonel — mevcut gradyan gök zaten çalışıyor).

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

---

# Güncelleme — arayüz, hız gösterimi, loglama ve web sürümü

## 1. Hız göstergesi topun üzerinde (üst çubuktan kaldırıldı)
- `Main.gd`: üstteki `speed_lbl` ve `_on_speed_report` TAMAMEN kaldırıldı.
- `FieldView._draw_velocity()`: topun merkezinden koyu antrasit **v oku**
  (kuvvet oklarının renklerinden ayrı) + ince **yatay/dikey bileşen okları**.
- `FieldView._draw_speed_readout()`: topun yanında `v = .. m/s` ve `vy = .. m/s`
  kutusu. Kutu ekran kenarına taşarsa otomatik olarak topun soluna geçer.
- Ayarlar: `VEL_SCALE` (px / m/s), `VEL_MAX` (ok üst sınırı), `C_VEL` (renk).

## 2. Tepe noktası vurgusu (kavramsal hedef)
- `|vy| < APEX_VY` olduğunda `apex_flash` tetiklenir ve rozet çizilir:
  **"TEPE NOKTASI / dikey hız vy = 0 / ama ivme ↓ devam ediyor"**.
- Aynı anda dikey bileşen oku kaybolur, mavi **Yerçekimi** oku tam boyda kalır —
  "hız sıfırlanır ama ivme devam eder" görsel olarak kanıtlanır.
- ÖNEMLİ: 45°'lik vuruşta tepede TOPLAM hız sıfır değildir, yalnızca dikey
  bileşen sıfırlanır (ör. v = 15 m/s, vy = 0). Bu ayrım bilerek korunmuştur;
  "hız tamamen sıfır" göstermek ön testteki 3. soruya ters bir kavram öğretirdi.

## 3. Sağdaki bilgi kutucukları kaldırıldı
- `_build_feedback_panel()` yerine `_build_control_bar()` geldi (altta ince çubuk).
- Geri bildirim METNİ artık ekranda gösterilmiyor; ancak `_feedback()` fonksiyonu
  duruyor ve seçilen yanılgı kategorisi CSV'ye `category` sütununda yazılıyor.
- Metni geri getirmek isterseniz: `_on_flight_finished()` içinde `_feedback(...)`
  sonucunu bir Label'a yazmanız yeterli (fonksiyon hazır duruyor).

## 4. Oynatma hızı kontrolü
- Alt çubukta 0.25× / 0.5× / 1× / 2× düğmeleri.
- `FieldView.time_scale` yalnızca SİMÜLASYON zamanını ölçekler
  (`_process` içinde `sdt = delta * time_scale`); arayüz normal hızda kalır.

## 5. Vuruş animasyonundaki takılma giderildi
- SEBEP: giriş animasyonu bitince oyuncu tüm vuruş dizisini oynatıp bir anda
  `idle` karesine ZIPLIYORDU.
- ÇÖZÜM: `kick_hold` — ayağın topa değdiği karede (`_contact_index()`) donar;
  "Ne olacağını gör"e basılınca `kick_follow` ile kalan kareler akıcı oynar.
- Ayrıca `_ready()` içinde ısınma: integratör + font ölçümü bir kez önceden
  çalıştırılır (ilk vuruştaki tek karelik donma kalkar).

## 6. Loglama — EKSİK ALANLAR TAMAMLANDI
- ESKİ SÜRÜMDE sürtünme seviyesi ve vuruş kuvveti F büyüklüğü HİÇ KAYDEDİLMİYORDU.
- Yeni CSV başlığı:
  `timestamp_utc, session_id, participant_code, group, seen_topic, session_mode,
   attempt, gravity, kick_force_sel, air_resistance, friction_level,
   kick_force_mag, v0_mps, angle_deg, correct, category, goal, landing_x_m,
   decision_seconds`
- "veri durumu" penceresi artık kayıt sayısı + kayıt yeri + SON 3 KAYDI gösterir
  (loglamanın çalıştığını sunumda gözle doğrulamak için).
- Web sürümünde "CSV dışa aktar" tarayıcı indirmesi tetikler
  (`DataLog.web_download()` — masaüstündeki dosya diyaloğu tarayıcıda çalışmaz).

## 7. Testler (başsız — Godot açmadan çalışır)
    godot --headless --path . --script tools/smoke_test.gd     # loglama doğrulaması
    xvfb-run godot --path . --script tools/shots.gd            # ekran görüntüsü alır

`smoke_test.gd` şunları doğrular: deneme modunda kayıt YOK; yönetici açınca
kayıt VAR ve tüm seçimler birebir doğru; yanılgılı cevap `correct=false`;
yönetici durdurunca kayıt kesilir.

    godot --headless --path . --script tools/physics_probe.gd    # fizik doğruluğu ölçümü

`physics_probe.gd` — `Physics.gd`'yi DEĞİŞTİRMEDEN sayısal ölçüm basar (yerel
bir RK4 referansıyla): integratör yakınsaması (Euler dt=1/240 vs RK4), drag
katsayılarının gerçek topa (m/r/Cd) göre fiziksel türetimi, yuvarlanmada hava
direnci + ROLL_FRICTION çakışmasının büyüklüğü, menzil tablosu, sekme sayısı.
`Physics.gd` sabitleri (drag, IMPETUS_ACC, RESTITUTION vb.) değiştiğinde tekrar
çalıştırıp aşağıdaki tabloyu güncellemek için kullanılabilir.

## 8. Web (HTML5) sürümü
- `export_presets.cfg` eklendi (Web, **thread'siz** varyant → her statik
  sunucuda özel başlık gerekmeden çalışır).
- Dışa aktarma:

      godot --headless --path . --export-release "Web" build/index.html

- Hazır build ayrı zip olarak verildi (`kicked-ball-WEB-hazir.zip`).

## Doğrulanmış fizik değerleri (v0=30 m/s, 45°)
> Güncelleme (2026-08-07, `tools/physics_probe.gd` ile ölçüldü): hava direnci
> Az/Orta/Fazla seviyeleri kaldırıldı, tek sabit `Physics.DRAG_K = 0.025`
> oldu; kale konumu (`FieldView.GOAL_X`) buna göre 49 m'den 34 m'ye taşındı
> (doğru cevap yine GOL olsun diye). Tablo bu son koda göredir.

| Seçim | İniş | Gol? |
|---|---|---|
| Yerçekimi + Hava — DOĞRU | 37.0 m | **EVET** (kale ~34–39 m) |
| Yalnız yerçekimi | 91.7 m | hayır |
| Yerçekimi + F | top hiç yere inmiyor (uzaya kaçıyor) | hayır |
| Yerçekimi + Hava + F | 93.0 m | hayır |

---
# Güncelleme — görev listesi uygulaması (koyu tema sürümü)

- **Kademeli zoom out:** Kamera artık tek noktaya odaklanmıyor; top ilerledikçe
  TÜM SAHNE yavaşça uzaklaşıyor (futbolcu küçülüyor). `FieldView._fit_camera()`
  uçuş sonundaki oranı hesaplar, `_process` içinde `cam_zoom` buna yumuşak
  geçişle iner.
- **Yerdeki hedef:** Kale ağzına yatay dart tahtası serildi
  (`_draw_ground_target`), merkezi doğru fiziğin indiği nokta.
- **"Simülasyon bitmiştir"** mesajı sonuç kutusunda (koyu modal) yer alıyor;
  FieldView'deki eski beyaz kutu kaldırıldı.
- **"Veri toplanıyor" yazısı** öğrenci ekranından kaldırıldı (F9 ile görülür).
- **Yönerge** soru modalinde "YAPMAN GEREKEN:" başlığıyla netleştirildi.
- **docs/arayuz-incelemesi.md**: görev listesindeki "diğer fizik
  simülasyonlarının arayüzünün incelenmesi" maddesi için hazırlanan not.

---
# Güncelleme — soru panelinin sabitlenmesi, sabit hız, vx

- **Oynatma hızı düğmeleri KALDIRILDI.** Hız sabit: `FieldView.time_scale = 0.42`
  (her kuvvet oku rahat izlenecek kadar yavaş). Değiştirmek isterseniz tek satır.
- **Soru paneli artık kaybolmuyor:**
  - Seçim aşamasında EKRANIN ORTASINDA, büyük (520 px).
  - "Ne olacağını gör"e basılınca `_dock_question_left()` ile SOLA sabitlenir
    (320 px): uzun yönerge ve düğme gizlenir, "SENİN SEÇİMİN" etiketi çıkar,
    kutucuklar devre dışı kalır (uçuş sırasında değiştirilemez).
  - "Yeni cevap dene" veya "Sıfırla" ile `_center_question()` -> yeniden ortada.
- **"Vuruşu başlat" düğmesi** atış sırasında gizlenir (`btn_start.visible`).
- **Bitişte** koyu sonuç kutusu: GOL / KAÇTI rozeti + "Simülasyon bitmiştir · ..."
- **HUD'a vx eklendi:** `vx (yatay)` ve `vy (dikey)` ayrı satırlarda.
  vx değişmediğinde yanına yeşil "· sabit" etiketi düşer — hava direnci
  seçilmediğinde yatay hızın SABİT kaldığını (Newton 1) görünür kılar.

---
# Güncelleme — yerleşim düzeltmesi, soru kutusunun kapanması, vuruş zamanlaması

- **Sabit yerleşim (referans görsellere göre):** "Nasıl çalışır?" kartı sol üstte
  (24, 78), HUD kartı solda (24, 390) — konumlar artık hiçbir aşamada değişmiyor.
  Soru kutusu ve sonuç kutusu ekranın ortasında.
- **"Top havada" kutusu atıştan sonra EKRANDAN KALKAR** (`_hide_question()`).
  Öğrencinin seçimi kaybolmaz: HUD kartının en üstünde
  "Seçimin: Yerçekimi, Hava direnci (Orta)" satırı olarak görünmeye devam eder
  (`_update_choice_summary`). "Yeni cevap dene" / "Sıfırla" ile kutu yeniden ortada açılır.
- **Top, cevap verilmeden VURULMUYOR:** giriş animasyonu artık temas karesinde
  değil, temastan HEMEN ÖNCEKİ karede duruyor (`_prekick_index()`), yani oyuncu
  ayağını kaldırmış bekliyor. Vuruş ve topun hareketi ancak öğrenci cevabını
  verip düğmeye bastığında gerçekleşiyor.
- **"Vuruşu başlat" düğmesi** giriş animasyonu sürerken ve uçuş sırasında pasif.

---
# Güncelleme — vx vektörü ve hız değerlerinin sol karta taşınması

- **vx ve vy artık gerçek, etiketli oklar** (eskiden soluk ince çizgilerdi):
  vx turuncu (`C_VX = f59e0b`), vy mor (`C_VY = a855f7`), toplam hız v koyu.
  Bileşenlerin uçlarından v'nin ucuna ince kılavuz çizgiler çizilir
  (vx + vy = v ilişkisi görünür olsun diye).
  - Hava direnci seçilmezse vx okunun boyu HİÇ değişmez (Newton 1).
  - Tepe noktasında vy oku tamamen kaybolur, yerçekimi oku tam boyda kalır.
- **Topun yanındaki beyaz değer kutusu kaldırıldı.** Hız değerleri artık
  yalnızca sol HUD kartında: "TOPUN HIZI" (büyük), altında vx ve vy.
  HUD'daki vx/vy yazı renkleri sahnedeki ok renkleriyle aynıdır; vy tepe
  noktasına yaklaşınca kırmızıya döner.
- Topun yanında yalnızca "TEPE NOKTASI" rozeti çizilmeye devam eder.

---
# Düzeltme — HUD hız değerleri 0.0'da takılı kalıyordu

SEBEP: `FieldView.speed_report` sinyali yayınlanıyordu ama `Main._ready()`
içindeki `connect` satırı önceki bir düzenlemede kaybolmuştu; bu yüzden
`_on_speed_report` hiç çağrılmıyor, HUD "0.0 m/s" olarak kalıyordu.

ÇÖZÜM:
- `field.speed_report.connect(_on_speed_report)` satırı `_ready()`e geri eklendi.
- `_reset_hud_values()`: yeni denemeye geçerken (Sıfırla / Yeni cevap dene)
  değerler ve renkler sıfırlanır, önceki uçuşun son değeri ekranda kalmaz.

---
# Güncelleme — F kuvveti, mavi gökyüzü + gezegenler, küçülen oyuncu, jenerik futbolcu

- **F kuvveti artırıldı:** `Physics.IMPETUS_ACC = 15.0` (istenirse 30.0, tek satır).
  15 ile "yerçekimi+F" seçen top artık hiç yere inmiyor — yanılgı çok daha dramatik.
- **Mavi gökyüzü:** gri arka plan yerine ufka açılan mavi; en üstte koyu UZAY
  bandı, içinde yıldızlar ve 3 gezegen (halkalı, kızıl, ay) — `_draw_planets()`.
  Ekran-sabit süslemedir, kamera zoomundan etkilenmez.
- **Oyuncu artık gerçekten küçülüyor.** İki sebep vardı: (1) kamera zaten
  ~1.0'da başlıyordu; şimdi `START_ZOOM = 1.55` ile yakından başlıyor.
  (2) ASIL HATA: oyuncu sabit ekran boyunda çiziliyordu (`size.y * 0.18`),
  zoom'u hiç hesaba katmıyordu; artık `size.y * 0.125 * cam_zoom`.
  Bu yüzden `ORIGIN_X` 150→330 alındı (oyuncu sol HUD kartının arkasında
  kalmasın diye).
- **vx/vy okları topun üzerinden kaldırıldı** — yalnızca toplam hız (v) oku
  kaldı; vx/vy sayısal değerleri sol HUD kartında görünmeye devam ediyor.
- **Jenerik futbolcu:** sprite karelerindeki Arjantin açık mavisi (Messi kiti)
  parlaklık korunarak kırmızıya boyandı (17 kare, kalıcı olarak PNG'lerde);
  piksel-art yedek çizimin paleti de kırmızı-beyaz jenerik kite çevrildi.

---
# Güncelleme — tek ton gökyüzü + uzaya geçiş

- Gökyüzü artık TEK TON mavi (`57a8ec`); sabit uzay bandı kaldırıldı.
- Top ekranı terk edecek kadar yükselirse arka plan UZAYA döner:
  `SPACE_START_M = 34` irtifasında geçiş başlar, `SPACE_FULL_M = 58`de
  tamamlanır (`space_f` yumuşak geçiş). Yıldızlar ve gezegenler yalnızca bu
  geçişle belirir. Doğru cevapta (tepe ~16 m) gökyüzü hep mavi kalır;
  "vuruş kuvveti F" yanılgısında top 60+ m'ye çıktığı için öğrenci topun
  uzaya kaçtığını görür — "bu kuvvetle top asla inmez" mesajını güçlendirir.
- Küçük koruma: uçuş sürerken `_on_intro_done` soru kutusunu artık yeniden açamaz.

---
# Güncelleme — etkileşim telemetrisi (Telemetry) entegrasyonu

- `scripts/Telemetry.gd` autoload olarak eklendi (project.godot → [autoload]).
  DataLog'un YERİNE geçmez, yanında çalışır:
  · DataLog  → deneme başına 1 özet satır (CSV)
  · Telemetry → olay akışı: hover + dwell, işaretleme sırası, sürtünme
    değişiklikleri, karar süresi, mouse yörüngesi (~15 Hz), tıklamalar,
    cevap gönderimi, tekrar/yeni cevap, uçuş sonucu (user://events_log.jsonl,
    JSON Lines). sid + code + attempt ile CSV'yle birleştirilir.
- GİZLİLİK: DataLog ile aynı ilke — yönetici veri toplamayı AÇMADIYSA hiçbir
  olay yazılmaz (başsız testle doğrulandı).
- Kısayol: **F8 = etkileşim (JSONL) verisini dışa aktar** (web'de doğrudan indirme).
- Ayrıntı: docs/logger-entegrasyon.md
- NOT (test altyapısı): `--script` kipinde autoload'lar kurulmadığı için
  Main.gd autoload'a `@onready var Tele = get_node("/root/Telemetry")` ile
  erişir; test betikleri aynı adla düğümü elle ekler. Oyun davranışı değişmez.
- `_force_box` iyileştirmesi (Defne): kutu içi kontroller mouse'a kapatıldı,
  hover artık kutunun tamamı için tek parça (dwell ölçümü titremiyor).

---
# Güncelleme — simülasyon öncesi giriş popup'ı, hava direnci sadeleştirmesi

## 1. "Nasıl çalışır?" giriş popup'ı
- Simülasyon HİÇBİR ŞEY başlamadan (futbolcu koşup gelmeden) önce ortada bir
  popup açılır; "Devam Et" düğmesine basılınca koşu-vuruş girişi başlar
  (`Main._build_intro_modal`, `_on_intro_modal_continue`).
- Sol üstteki eski sabit "ℹ Nasıl çalışır?" kartı (`howto_card`) tamamen
  kaldırıldı — aynı bilgiyi artık popup veriyor, ikisi birden gereksizdi.
- Not: `field.reset()` artık `_on_continue()` içinde de çağrılıyor (popup
  gösterilmeden önce), çünkü `field.start_intro()` artık hemen çağrılmıyor —
  eskiden reset yalnızca `start_intro()` içinden geliyordu.

## 2. Hava direnci: Az/Orta/Fazla seviyesi kaldırıldı
- "Hava direnci" artık Yerçekimi/Vuruş kuvveti gibi basit açık/kapalı bir
  seçenek; alt seviye seçme düğmeleri (`friction_box`/`friction_btns`,
  `_set_friction`) kaldırıldı.
- `Physics.gd`: `DRAG_LOW/DRAG_MED/DRAG_HIGH` + `drag_for_level()` yerine
  tek sabit **`DRAG_K = 0.025`** (`simulate()` ve `real_path()` bunu kullanır).
- **Kale konumu buna göre taşındı:** `FieldView.GOAL_X` 49.0 m → **34.0 m**
  (yeni k ile doğru cevabın inişi ~37.0 m'ye düştü; eski 49 m'de kale artık
  hiç yakalanamazdı). `tools/physics_probe.gd` ile doğrulandı: doğru senaryo
  yine GOL oluyor.
- CSV şeması değişti: `friction_level` sütunu kaldırıldı (`DataLog.gd`
  `HEADER`/`log_attempt`), `Telemetry.answer_submit`'ten `friction` parametresi
  kaldırıldı. Var olan eski CSV dosyalarıyla sütun sayısı artık uyuşmaz —
  yeni bir oturumda temiz başlamak gerekir.
- `tools/smoke_test.gd` yeni şemaya göre güncellendi (sabit sütun indeksleri
  kayan yerlerde düzeltildi, `param_change` artık tetiklenmediği için
  zorunlu olay listesinden çıkarıldı).

---
# Güncelleme — teknik olmayan ekip arkadaşları için KOD YAZMADAN ayar/metin değiştirme

İki mekanizma eklendi; ikisi de Godot editörünü açıp F5 ile çalıştırmaktan
başka bir şey gerektirmiyor, GDScript'e dokunulmuyor.

## 1. Sayısal parametreler → `res://config/sim_config.tres`
Drag katsayısı, vuruş kuvveti F, yerçekimi, sekme/yuvarlanma sabitleri, kale
konumu/toleransı, tepe noktası eşiği, uzay geçiş irtifaları, oynatma hızı —
hepsi `scripts/SimConfig.gd`'de `@export` alanı. FileSystem panelinde
`sim_config.tres`'e tıklayınca Inspector'da slider/sayı kutusu olarak çıkar.
Kod tarafı: her yerde `Physics.cfg.<alan>` ile okunuyor (`Physics.gd` bunu
`preload` ile bir kere yükler). DT (entegrasyon adımı) ve MAX_X/MAX_Y ekran
sınırı bilerek DIŞARIDA — bunlar teknik iç ayarlar.

## 2. Metinler → `res://localization/strings.csv`
Popup metinleri, kuvvet seçeneği başlık/alt metinleri, sonuç ekranı
yazıları, tepe noktası rozeti, geri bildirim kategorisi+mesajı — `key,text`
sütunlu düz bir CSV. Excel/Sheets'te açılıp "text" sütunu değiştirilir,
kaydedilir. `scripts/Strings.gd` (autoload `Strings`) her çalıştırmada okur;
kod tarafı `S.t("ANAHTAR")` ile çağırıyor (yer tutuculu metinlerde
`S.t("ANAHTAR", [değer])`). "key" sütununa dokunulmamalı.

Godot'un kendi `TranslationServer`/CSV import sistemi kullanılmadı; o çoklu
dil arasında GEÇİŞ için tasarlanmış ve editörde bir import adımı gerektiriyor.
Bu proje hep Türkçe olduğu için basit bir dosya-okuma yeterli — daha az
kırılgan.

**DİKKAT — veri şeması ile karışmasın:**
- `_force_box`'a artık kararlı bir dahili anahtar da veriliyor (`"gravity"`/
  `"kick"`/`"air"`) — telemetride (`option_hover`/`option_toggle` olaylarının
  `factor` alanı) bu kullanılıyor, CSV metnini değiştirmek bunu bozmaz.
- Geri bildirim kategorisi (`FB_*_CAT`) HEM ekranda HEM DataLog CSV'sinin
  `category` sütununda kullanılıyor (eskiden de böyleydi) — bu metni
  değiştirmek araştırma verisindeki kategori etiketini de değiştirir, bilerek
  öyle bırakıldı.

**Yeni bir parametre/metin eklemek istersen:** `SimConfig.gd`'ye bir
`@export` satırı veya `strings.csv`'ye bir satır eklemen, sonra ilgili
scriptte `cfg.<alan>` / `S.t("ANAHTAR")` ile okuman yeterli.
