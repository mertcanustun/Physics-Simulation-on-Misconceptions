#!/usr/bin/env bash
# Web (HTML5) sürümünü üretir ve Vercel'e hazır hâle getirir.
#   ./tools/build_web.sh              -> build/ klasörünü üretir
#   ./tools/build_web.sh --deploy     -> üretir + vercel'e yükler (vercel CLI gerekir)
#
# Godot yolu ortam değişkeniyle değiştirilebilir:
#   GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./tools/build_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null || { echo "Godot bulunamadı. GODOT=/yol/godot ./tools/build_web.sh"; exit 1; }

# vercel.json'ı koru: export klasörü siler
TMP="$(mktemp -d)"
[ -f build/vercel.json ] && cp build/vercel.json "$TMP/"

mkdir -p build
"$GODOT" --headless --path . --export-release "Web" build/index.html

[ -f "$TMP/vercel.json" ] && cp "$TMP/vercel.json" build/
rm -rf "$TMP"

echo "✓ build/ hazır ($(du -sh build | cut -f1))"

if [ "${1:-}" = "--deploy" ]; then
  command -v vercel >/dev/null || { echo "vercel CLI yok: npm i -g vercel"; exit 1; }
  cd build && vercel deploy --prod --yes
fi
