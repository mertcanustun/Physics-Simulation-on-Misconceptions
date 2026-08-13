class_name SimConfig
extends Resource
## KOD YAZMADAN değiştirilebilir simülasyon parametreleri.
##
## NASIL DÜZENLENİR (teknik olmayan ekip arkadaşları için):
##   1. Godot editörünü aç (proje klasörünü sürükle-bırak yeter, kod açmana gerek yok).
##   2. Soldaki "FileSystem" panelinde res://config/sim_config.tres dosyasına TIKLA.
##   3. Sağda "Inspector" panelinde tüm değerler slider/sayı kutusu olarak çıkar.
##   4. Değiştir, Ctrl+S ile kaydet, projeyi çalıştır (F5) — kod dokunulmadı.
##
## NOT: DT (entegrasyon adım aralığı) ve MAX_X/MAX_Y (ekran güvenlik sınırı)
## burada YOK — bunlar teknik iç ayarlar, yanlış değer simülasyonu bozabilir.
## Buraya yeni bir parametre eklemek istersen: bir @export satırı ekle, sonra
## Physics.gd/FieldView.gd/Main.gd içindeki ilgili sabiti "cfg.<yeni_alan>" ile değiştir.
##
## TİP NOTU: alanlar bilerek `: float = ...` (açık tip) ile yazıldı, `:=` değil —
## Physics/FieldView/Main gibi başka scriptlerden "Physics.cfg.drag_k" şeklinde
## okunduğunda GDScript'in statik tip çıkarımı `:=` ile bunu çözemiyor
## ("Cannot infer the type" parse hatası); açık tip bu sorunu ortadan kaldırıyor.

# --- TELEMETRİ SUNUCUSU (Supabase) ---
## "Simülasyonu Bitir"de biriken Telemetry.session_events buraya POST edilir.
## Boş bırakılırsa (varsayılan) gönderim sessizce atlanır — yerel dosya kaydı
## (DataLog/Telemetry user://) etkilenmez, bu sadece merkezi kopyalama.
## KURULUM: bkz. docs/supabase-telemetri.md — kısaca Supabase'de bir proje +
## `telemetry_events` tablosu + "yalnızca INSERT" RLS politikası oluşturup
## Project Settings → API'den URL ve anon (public) anahtarı buraya yapıştır.
## anon anahtar GİZLİ DEĞİLDİR — web build'e gömülüp herkese görünür olabilir;
## güvenlik anahtarın gizliliğinden değil, RLS politikasından gelir (yalnızca
## ekleme izni var, okuma/silme yok — sızsa bile kimse veriyi geri okuyamaz).
@export_group("Telemetri Sunucusu (Supabase)")
@export var supabase_url: String = ""            ## ör: https://xxxxxxxx.supabase.co
@export var supabase_anon_key: String = ""       ## Project Settings → API → "anon public"
@export var supabase_table: String = "telemetry_events"

@export_group("Kuvvetler")
@export_range(1.0, 20.0, 0.01, "suffix:m/s²") var gravity_g: float = 9.81
@export_range(0.0, 0.1, 0.001, "suffix:kg/m") var drag_k: float = 0.025          ## hava direnci katsayısı
@export_range(0.0, 40.0, 0.5, "suffix:m/s²") var impetus_acc: float = 15.0       ## "vuruş kuvveti F" yanılgısının büyüklüğü
## Topun kütle ÇARPANI — 1.0 = mevcut ayarlanmış denge (dokunma). Artırırsan top
## hava direncine ve vuruş kuvvetine karşı daha "ağır/dirençli" davranır (ikisi
## de kütleye bölünür); yerçekimi ivmesi kütleden ETKİLENMEZ (gerçek fizik —
## Galileo). Gerçek bir top kütlesi (0.43 kg) DEĞİL, çarpan; drag_k zaten
## fiziksel türetimde kütleyi hesaba katıyor (bkz. tools/physics_probe.gd).
@export_range(0.2, 3.0, 0.05, "suffix:×") var mass_kg: float = 1.0

@export_group("Atış (deneysel kontrol — sabit)")
@export_range(5.0, 60.0, 0.5, "suffix:m/s") var v0: float = 30.0
@export_range(10.0, 80.0, 1.0, "suffix:derece") var angle_deg: float = 45.0

@export_group("Sekme / Yuvarlanma / Simülasyon Bitiş Koşulu")
@export_range(50.0, 1500.0, 10.0, "suffix:m") var max_y: float = 400.0  ## Top bu kadar yükselirse "yere inmedi" (uzaya kaçtı) sayılır
@export_range(50.0, 1500.0, 10.0, "suffix:m") var max_x: float = 200.0  ## Top yatayda bu kadar uzağa giderse zorla kesilir
@export_range(0.0, 1.0, 0.01) var restitution: float = 0.34          ## çarpmada dikey hız kaybı (sekme sertliği)
@export_range(0.0, 1.0, 0.01) var bounce_friction: float = 0.72      ## çarpmada yatay hız kaybı
@export_range(0.0, 20.0, 0.1, "suffix:m/s²") var roll_friction: float = 6.5   ## yuvarlanma sürtünmesi
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var rest_vy: float = 1.2         ## bu dikey hızın altında artık sekmez, yuvarlanmaya geçer
## Bu, GERÇEK (izlenen/duvar saati) saniye cinsindendir — SİMÜLE fizik saniyesi
## DEĞİL. Fizik entegratörü zaman_ölçeğinden (time_scale) bağımsız çalışır;
## bu değer Physics.gd içinde time_scale ile çarpılıp gerçek fizik-saniye
## bütçesine çevrilir. Yani time_scale'i değiştirsen bile "ekranda kaç saniye
## bekleteceğim" sezgisi hep doğru kalır — ayrıca hesap yapmana gerek yok.
@export_range(1.0, 60.0, 0.5, "suffix:sn (izlenen/gerçek süre)") var max_watch_seconds: float = 28.57   ## yörünge ekranda en fazla bu kadar SANİYE (gerçek zaman) sürer, sonra zorla kesilir

@export_group("Kale / Gol Koşulu")
@export_range(0.0, 100.0, 0.5, "suffix:m") var goal_x: float = 34.0          ## kale ön çizgisi — top buraya (+derinlik) düşerse GOL
@export_range(0.0, 20.0, 0.5, "suffix:m") var ring_bulls: float = 3.5        ## "isabet" toleransı
@export_range(0.0, 100.0, 1.0, "suffix:px") var goal_depth_px: float = 42.0  ## kale derinliği (ekran px)

@export_group("Kavramsal Vurgular")
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var apex_vy: float = 1.2         ## "tepe noktası" rozetinin tetiklendiği |vy| eşiği
@export_range(0.0, 100.0, 1.0, "suffix:m") var space_start_m: float = 34.0   ## bu irtifadan sonra arka plan uzaya dönmeye başlar
@export_range(0.0, 150.0, 1.0, "suffix:m") var space_full_m: float = 58.0    ## bu irtifada arka plan tamamen uzay

@export_group("Oynatma")
@export_range(0.05, 2.0, 0.01) var time_scale: float = 0.42   ## sahnenin oynatma hızı (1.0 = gerçek zaman)

@export_group("Vektör Okları")
@export_range(1.0, 30.0, 0.1, "suffix:px per m/s²") var arrow_scale: float = 7.2   ## okların uzunluk ölçeği
@export_range(20.0, 400.0, 5.0, "suffix:px") var arrow_max_px: float = 150.0       ## ok en fazla bu kadar uzayabilir
@export_range(0.3, 3.0, 0.05, "suffix:×") var arrow_head_ratio: float = 1.0        ## ok ucu / gövde oranı
@export var gravity_arrow_color: Color = Color("2563eb")
@export_range(1.0, 20.0, 0.5, "suffix:px") var gravity_arrow_thickness: float = 6.0
@export var air_arrow_color: Color = Color("0891b2")
@export_range(1.0, 20.0, 0.5, "suffix:px") var air_arrow_thickness: float = 6.0
@export var kick_arrow_color: Color = Color("dc2626")
@export_range(1.0, 20.0, 0.5, "suffix:px") var kick_arrow_thickness: float = 6.0

@export_group("Yörünge Çizgileri")
@export var predicted_path_color: Color = Color("dc2626")     ## öğrencinin tahmini (düz çizgi)
@export_range(1.0, 12.0, 0.5, "suffix:px") var predicted_path_thickness: float = 3.0
@export var real_path_color: Color = Color("e2e8f0")          ## GERÇEK yörünge (nokta nokta)
@export_range(1.0, 8.0, 0.2, "suffix:px") var real_path_dot_radius: float = 2.6
@export_range(3.0, 40.0, 1.0, "suffix:px") var real_path_dot_gap: float = 9.0     ## noktalar arası boşluk

@export_group("Kamera")
@export var dynamic_zoom_mode: bool = true   ## Sadece mesafeye (konuma) duyarlı, en pürüzsüz mod
@export var dynamic_zoom_with_speed: bool = false ## Hıza (Velocity) duyarlı mod (Kıyaslama testi için)

@export_range(0.0, 100.0, 1.0, "suffix:m") var altitude_zoom_threshold: float = 25.0  ## Bu yüksekliği (Y) geçince zoom out başlar
@export_range(0.0, 0.2, 0.001) var altitude_zoom_factor: float = 0.040  ## NORMAL MOD (Mesafe) dikey çarpanı
@export_range(0.0, 0.2, 0.001) var altitude_speed_factor: float = 0.035 ## HIZ MODU dikey çarpanı

@export_range(0.0, 150.0, 1.0, "suffix:m") var distance_zoom_threshold: float = 40.0  ## Bu yatay mesafeyi (X) geçince zoom out başlar
@export_range(0.0, 0.2, 0.001) var distance_zoom_factor: float = 0.040  ## NORMAL MOD (Mesafe) yatay çarpanı
@export_range(0.0, 0.2, 0.001) var distance_speed_factor: float = 0.035 ## HIZ MODU yatay çarpanı

@export_range(0.5, 3.0, 0.05, "suffix:×") var camera_start_zoom: float = 1.55  ## uçuş başındaki yakınlık
@export_range(0.05, 1.0, 0.01, "suffix:×") var camera_min_zoom: float = 0.16   ## en uzak (top ekrandan taşmasın)
@export_range(0.2, 2.0, 0.05, "suffix:×") var camera_max_zoom: float = 1.0     ## en yakın
@export_range(0.0, 30.0, 0.5, "suffix:m") var camera_margin_m: float = 6.0     ## top kenara bu kadar yaklaşınca kamera uzaklaşmaya başlar
@export_range(0.5, 15.0, 0.1) var camera_zoom_speed: float = 10.0

@export_group("Arayüz (UI)")
@export_range(8, 32, 1, "suffix:px") var hud_choice_font_size: int = 12  ## Sol üstteki seçilen kuvvetler listesinin yazı boyutu
@export var show_apex_popup: bool = false  ## Tepe noktası (apex) bilgi pop-up'ını ekranda göster

@export_group("Gökyüzü")
@export_range(0, 15, 1) var cloud_count: int = 4               ## arka planda kaç bulut olsun (0 = kapalı)
@export_range(0.0, 60.0, 1.0, "suffix:px/sn") var cloud_speed: float = 8.0   ## bulutların kayma hızı

@export_group("Ses")
@export var kick_sfx: AudioStream = preload("res://assets/audio/kick.mp3")   ## vuruş sesi (küçük top sıçraması anında çalar)
@export var wind_sfx: AudioStream   ## rüzgar sesi — top "uzayda" DEĞİLKEN, uçuş boyunca çalar (loop'lu bir dosya seç; henüz atanmadı, boşsa çalmaz)

@export_group("Zamanlama")
@export_range(0.0, 2.0, 0.02, "suffix:sn") var question_delay_s: float = 0.22   ## ayak topa değdikten kaç sn sonra "Top havada" sorusu çıksın
@export_range(0.0, 0.99, 0.01) var intro_skip_ratio: float = 0.72   ## tekrarlarda koşunun yüzde kaçı atlansın (0.72 = doğrudan vuruş)
