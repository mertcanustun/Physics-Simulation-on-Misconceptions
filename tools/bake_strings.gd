extends SceneTree
## res://localization/strings.csv  ->  res://scripts/StringsBaked.gd
##
## NİÇİN VAR: dışa aktarılmış (Web/Vercel) build'de ham CSV'nin pakete girmesi
## import ayarlarına bağlı ve kırılgan (bkz. GELISTIRME-REHBERI "Web export
## metin hatası"). GDScript dosyaları ise HER ZAMAN pakete girer. Bu araç
## CSV'yi bir GDScript sözlüğüne "pişirir"; Strings.gd önce CSV'yi dener
## (editörde canlı düzenleme çalışsın diye), bulamazsa pişmiş sözlüğe düşer.
## Böylece ekranda anahtar ismi görünmesi YAPISAL OLARAK imkânsız hale gelir.
##
## KULLANIM (strings.csv'yi her düzenledikten sonra):
##
##     godot --headless --path . --script tools/bake_strings.gd
##
## Çalıştırmayı unutursan: editörde ve CSV'nin pakete girdiği durumlarda yeni
## metinler yine görünür; yalnızca CSV'nin düştüğü senaryoda eski metne
## dönülür. Yani unutmak sessizce bozmaz, sadece yedeği bayatlatır.

const CSV := "res://localization/strings.csv"
const OUT := "res://scripts/StringsBaked.gd"

func _init() -> void:
	var f := FileAccess.open(CSV, FileAccess.READ)
	if f == null:
		push_error("bake_strings: %s açılamadı" % CSV)
		quit(1)
		return
	var rows: Array = []
	f.get_csv_line()   # başlık
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		rows.append([row[0], row[1]])
	f.close()

	var out := FileAccess.open(OUT, FileAccess.WRITE)
	if out == null:
		push_error("bake_strings: %s yazılamadı" % OUT)
		quit(1)
		return
	out.store_string("## OTOMATİK ÜRETİLDİ — ELLE DÜZENLEME.\n")
	out.store_string("## Kaynak: res://localization/strings.csv\n")
	out.store_string("## Yeniden üretmek için:\n")
	out.store_string("##     godot --headless --path . --script tools/bake_strings.gd\n")
	out.store_string("##\n")
	out.store_string("## Bu dosya, dışa aktarılmış build'de CSV pakete girmezse devreye giren\n")
	out.store_string("## yedektir (GDScript her zaman pakete girer). Bkz. Strings.gd.\n\n")
	out.store_string("const DATA := {\n")
	for r in rows:
		out.store_string("\t%s: %s,\n" % [_q(r[0]), _q(r[1])])
	out.store_string("}\n")
	out.close()
	print("bake_strings: %d anahtar -> %s" % [rows.size(), OUT])
	quit()

## GDScript string literali olarak güvenli biçimde kaçır.
func _q(s: String) -> String:
	var e := s.replace("\\", "\\\\").replace("\"", "\\\"")
	e = e.replace("\n", "\\n").replace("\r", "").replace("\t", "\\t")
	return "\"%s\"" % e
