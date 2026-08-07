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

@export_group("Kuvvetler")
@export_range(1.0, 20.0, 0.01, "suffix:m/s²") var gravity_g: float = 9.81
@export_range(0.0, 0.1, 0.001, "suffix:kg/m") var drag_k: float = 0.025          ## hava direnci katsayısı
@export_range(0.0, 40.0, 0.5, "suffix:m/s²") var impetus_acc: float = 15.0       ## "vuruş kuvveti F" yanılgısının büyüklüğü

@export_group("Atış (deneysel kontrol — sabit)")
@export_range(5.0, 60.0, 0.5, "suffix:m/s") var v0: float = 30.0
@export_range(10.0, 80.0, 1.0, "suffix:derece") var angle_deg: float = 45.0

@export_group("Sekme / Yuvarlanma / Simülasyon Bitiş Koşulu")
@export_range(0.0, 1.0, 0.01) var restitution: float = 0.34          ## çarpmada dikey hız kaybı (sekme sertliği)
@export_range(0.0, 1.0, 0.01) var bounce_friction: float = 0.72      ## çarpmada yatay hız kaybı
@export_range(0.0, 20.0, 0.1, "suffix:m/s²") var roll_friction: float = 6.5   ## yuvarlanma sürtünmesi
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var rest_vy: float = 1.2         ## bu dikey hızın altında artık sekmez, yuvarlanmaya geçer
@export_range(1.0, 30.0, 0.5, "suffix:sn") var max_t: float = 16.0           ## yörünge en fazla bu kadar sürer, sonra zorla kesilir

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
