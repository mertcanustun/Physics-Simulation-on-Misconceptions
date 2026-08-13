# Telemetri → Supabase Entegrasyonu

> Bu, `webhook.site` denemesinin (bkz. git geçmişi: "logger denedim...") yerini
> alan kalıcı çözüm. Eskisiyle fark: webhook.site herkese açık, kalıcı olmayan
> bir test kutusuydu (repo'da token açıktaydı, veriler birkaç gün sonra
> siliniyordu). Supabase gerçek bir veritabanı; güvenlik gizli bir anahtarla
> değil, "yalnızca ekleme" (INSERT-only) veritabanı kuralıyla sağlanıyor —
> yani `supabase_anon_key` web build'e gömülüp herkese görünse bile, o
> anahtarla kimse veriyi OKUYAMAZ ya da SİLEMEZ, sadece yeni satır ekleyebilir.

## 1. Supabase projesi oluştur (bir kez, ekipten biri)

1. https://supabase.com → ücretsiz hesap → **New Project**.
2. Proje adı/şifre gir, bölge seç, oluşmasını bekle (~2 dk).

## 2. Tabloyu ve güvenlik kuralını kur

Sol menüden **SQL Editor** → yeni sorgu → aşağıdakini yapıştırıp çalıştır:

```sql
create table telemetry_events (
  id          bigint generated always as identity primary key,
  ts_ms       double precision,
  sid         text,
  code        text,
  group_label text,
  seen        boolean,
  mode        text,
  attempt     int,
  type        text,
  payload     jsonb,
  created_at  timestamptz default now()
);

alter table telemetry_events enable row level security;

-- anon (herkese açık) anahtarla SADECE ekleme yapılabilir — okuma/silme/güncelleme yok.
create policy "anon can insert" on telemetry_events
  for insert to anon
  with check (true);
```

Bu kadar. `select`/`update`/`delete` için hiç politika YOK — yani RLS varsayılan
olarak reddediyor, `anon` anahtarı sızsa bile kimse veriyi geri okuyamaz.

## 3. URL ve anahtarı Inspector'a yapıştır

1. Supabase panelinde **Project Settings → API**.
2. **Project URL**'i kopyala (örn. `https://xxxxxxxx.supabase.co`).
3. **anon public** anahtarını kopyala (bu GİZLİ DEĞİL — client'a gömülmesi
   tasarım gereği; `service_role` anahtarını ASLA buraya veya git'e koyma).
4. Godot'ta `config/sim_config.tres`'e tıkla → Inspector → **Telemetri
   Sunucusu (Supabase)** grubu:
   - `Supabase Url` → proje URL'in
   - `Supabase Anon Key` → anon public anahtar
   - `Supabase Table` → varsayılan `telemetry_events` (değiştirmene gerek yok)
5. Ctrl+S, F5 ile test et — "Simülasyonu Bitir"e bastığında satırlar tabloya
   düşer (Table Editor'den canlı izleyebilirsin).

Boş bırakılırsa (varsayılan) gönderim sessizce atlanır; yerel dosya kaydı
(`DataLog`/`Telemetry` → `user://...`) her zaman çalışmaya devam eder.

## 4. Veriyi analiz etme (teknik olmayan ekip arkadaşları için)

- **Table Editor** → `telemetry_events` → satırları filtrele/sırala, "Export
  to CSV" ile indir → Excel/SPSS/pandas'a aç.
  `payload` sütunu jsonb — event türüne göre değişen alanlar orada
  (`factor`, `x`/`y`, `dwell_ms`, `gravity`/`kick`/`air`, `decision_ms`, ...).
- SQL bilenler için: `payload->>'factor'`, `payload->>'decision_ms'` gibi
  ifadelerle jsonb içinden sütun gibi sorgulanabilir.
- `DataLog` (deneme özeti CSV, masaüstü/web `user://session_log.csv`) hâlâ
  ayrı çalışıyor — `sid` üzerinden Supabase verisiyle birleştirilebilir.

## 5. Vercel ile ilgisi

Godot web build'i `telemetry_events`'e DOĞRUDAN POST atıyor (Supabase'in REST
API'si — PostgREST — CORS'u destekliyor, ayrı bir sunucu fonksiyonuna gerek
yok). Yani Vercel'e sadece build'i export edip koymak yeterli; ekstra bir
API route/backend kurmaya gerek kalmadı.

## 6. Yönetici paneli (uygulama içi) hakkında not

Uygulama içindeki "Yönetici Paneli"nde artık öğrenci logları LİSTELENMİYOR —
önceki deneme (`webhook_fetch_url`) zaten çalışmayan bir yaklaşımdı (o URL
insan panosuydu, API değildi) ve sahte örnek veri gösteriyordu. Kaldırıldı;
onun yerine Supabase Table Editor'e yönlendiren bir not var. İleride
uygulama-içi canlı görünüm istenirse, Supabase'in `select` izni olan AYRI bir
salt-okunur anahtarla (ör. bir Edge Function arkasında) yapılması gerekir —
anon anahtara okuma izni açmak, o anahtar herkese açık olduğu için TÜM
katılımcı verisini herkese açık hale getirir.
