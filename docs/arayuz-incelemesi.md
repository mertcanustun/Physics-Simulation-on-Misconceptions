# Diğer Fizik Simülasyonlarının Arayüz İncelemesi
(Görev listesindeki "Diğer Fizik Simülasyonlarının arayüzünün incelenmesi" maddesi için not.)

Bu, alanda yerleşmiş simülasyonların arayüz kalıplarının özeti ve bizim
simülasyonumuzla karşılaştırmasıdır. Kaynakları ekipçe doğrudan açıp
denemenizde fayda var; aşağıdaki başlıklar rapora da temel olabilir.

## İncelenmesi önerilen kaynaklar
| Simülasyon | Neden bakmalı |
|---|---|
| **PhET – Projectile Motion / Forces and Motion: Basics** (Colorado Üniv.) | Alanın referansı; kuvvet vektörü gösterimi ve katman katman açılabilen "değerleri göster" kutucukları |
| **oPhysics** (Tom Walsh) | Tek konuya odaklı, sade, tek ekranlı sim tasarımı |
| **The Physics Classroom – Interactives** | Öğretim senaryosuna gömülü, adım adım yönergeli yapı |
| **Walter Fendt – HTML5 Physics Applets** | Minimum arayüz, maksimum parametre kontrolü (bizim tersimiz: iyi bir karşıt örnek) |
| **Algodoo / Physion** | Serbest kurgulu sanal laboratuvar; bizim kapalı-uçlu tasarımımızla farkı tartışılabilir |

## Ortak arayüz kalıpları
1. **Örtük iskele (implicit scaffolding):** Kullanıcıya uzun yönerge verilmez;
   arayüz doğru sırayı kendisi dayatır. Bizde bunu "önce soru modalı, sonra
   atış" akışı sağlıyor.
2. **Katmanlı gösterim:** Vektörler, değerler, iz (trace) ayrı ayrı
   açılıp kapanan kutucuklardır — hepsi aynı anda açık gelmez.
3. **Her zaman görünür Play / Pause / Step / Reset ve yavaşlatma (slow motion).**
   Neredeyse istisnasız her ciddi simülasyonda vardır.
4. **Doğrudan manipülasyon:** Sürüklenebilen nesneler, anında tepki.
5. **Az metin, çok görsel geri bildirim:** Sayı yerine ok uzunluğu, renk, iz.
6. **Karşılaştırma için hayalet/iz gösterimi:** Önceki denemenin veya ideal
   durumun soluk gösterilmesi.

## Bizim simülasyonla karşılaştırma
| Kalıp | Bizde durum |
|---|---|
| Play/Pause/Reset | ✔ alt çubukta (Vuruşu başlat / Durdur / Sıfırla) |
| Yavaşlatma | ✔ 0.25× – 2× |
| Kuvvet vektörleri | ✔ yalnızca seçilen kuvvet, büyüklükle orantılı |
| Katmanlı gösterim | ~ kısmi: hız/vy HUD'da sabit açık |
| Hayalet/karşılaştırma izi | ✔ kesikli gerçek yol + soluk top |
| Doğrudan manipülasyon | ✘ (bilinçli tercih: açı/kuvvet sabit, deneysel kontrol) |
| Az metin | ~ soru modalinde yönerge metni uzun |

## Bizi ayıran yön (rapora yazılabilir)
PhET ve benzerleri **doğru fiziği** simüle eder; öğrenci parametre değiştirir.
Bizim simülasyon **öğrencinin seçtiği (yanlış olabilen) fizik modelini**
simüle edip gerçeğiyle yan yana koyar. Literatürdeki kavramsal değişim
(conceptual change) yaklaşımına — özellikle tahmin–gözlem–açıklama
(predict–observe–explain) döngüsüne — doğrudan karşılık gelir. Serbest
parametre vermeyip açı ve kuvveti sabitlememiz de bu yüzdendir: iniş
noktasındaki farkın TEK sebebi öğrencinin kuvvet seçimi olsun diye.
