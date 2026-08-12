# Kod Gözden Geçirme (Task 2) ve Vercel Dağıtımı (Task 3)

## Yapılan değişiklikler (Task 1 + 2)

### 1. Vuruş kuvveti F artık SABİT YÖNLÜ (istenen değişiklik)
`Physics.gd` içinde F, topun anlık hızı yerine ATIŞ AÇISINA (cfg.angle_deg)
bağlandı — yön uçuş boyunca değişmez:

    if kick and not rolling:
        var force_dir := Vector2(cos(ang), sin(ang))
        acc += (force_dir * imp) / cfg.mass_kg

İki entegrasyon detayı bilinçli eklendi:
- `not rolling` koşulu: eski `vel.length() > 0.01` koruması hız-yönlü model
  içindi; sabit yönde o koruma yetmez — yerde durmuş topu 45° yukarı itip
  sonsuza dek süründürürdü.
- `FieldView.gd`deki "Vuruş F" oku ve `tools/physics_probe.gd`deki RK4
  referansı da aynı modele çevrildi (görsel/ölçüm fizikle çelişmesin).

### FİZİKSEL SONUÇ — ekip karar vermeli
Sabit yönlü F ile davranış büyüklüğe göre keskin değişir (v0=30, 45°, kütle 1):

| impetus_acc | g+F sonucu |
|---|---|
| > 13.87 (= g/sin45°) | dikey net ivme YUKARI → top hiç inmez, uzaya çıkar |
| 5 – 13.87 | iner ama 200 m sınırından önce ekranı terk eder |
| ≤ ~4 | ekran içinde yere iner (ör. imp=4 → 181 m, imp=3 → 149 m) |

Mevcut ayar (15) korundu → g+F yine "Top hiç yere inmedi" verir.
Topun ekranda İNMESİNİ istiyorsanız Inspector'dan
`config/sim_config.tres → impetus_acc`i 3–4 bandına çekin. Kod gerekmez.

### 2. Küçük temizlikler
- `FieldView.gd`: `f_impetus` ve `set_forces/set_preview` varsayılanları
  koddaki bayat `6.0` yerine `Physics.cfg.impetus_acc`e bağlandı (cfg'den
  kopuk ikinci bir doğruluk kaynağı kalmadı).
- Yetim `scripts/ui_block.gd.uid` silindi.

### Bilerek DOKUNULMADI
Kod tabanı zaten iyi katmanlanmış: SimConfig (Inspector'dan ayar),
Strings (CSV'den metin), Telemetry/DataLog ayrımı, tools/ altında ölçüm ve
testler. Veri toplama arifesinde büyük yeniden yazım = gereksiz risk;
davranışı değiştirmeyen kozmetik refactor bilinçli olarak yapılmadı.

## Vercel'e Web Dağıtımı (Task 3)

### Godot tarafı (bir kez)
1. Proje → Dışa Aktar → "Web" preset'i zaten `export_presets.cfg`de tanımlı.
   Önemli ayar: **variant/thread_support = false** (thread'siz build).
   Bu sayede COOP/COEP başlıkları OLMADAN da her statik sunucuda çalışır.
2. Komut satırından üretim:

       godot --headless --path . --export-release "Web" build/index.html

   (Editörden: Project → Export → Web → Export Project.)

### Vercel tarafı
1. `build/` içeriğini GitHub deposuna koy (kökte `index.html` olacak şekilde).
2. vercel.com → Add New → Project → repoyu Import et.
   Framework Preset: **Other** · Build Command: **boş** · Output Directory: **.**
3. Aşağıdaki `vercel.json` build klasöründe hazır — MIME tipleri + (thread'li
   sürüme geçilirse gerekli olacak) COOP/COEP başlıkları dahil.

### vercel.json ne yapıyor?
- `.wasm` → `application/wasm` (bazı CDN'ler yanlış tip verir, WebAssembly
  streaming derlemesi bozulur)
- `.pck` → `application/octet-stream`
- `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy:
  require-corp`: thread'siz build için ZORUNLU DEĞİL ama zararsız (tüm
  varlıklar aynı origin'de) ve ileride `thread_support=true` yapılırsa
  SharedArrayBuffer için şart. Şimdiden koyuldu ki sürüm değişiminde
  "sayfa neden açılmıyor" aramasına gerek kalmasın.
