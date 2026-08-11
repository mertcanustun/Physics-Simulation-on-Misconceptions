extends SceneTree
const CODE := "L-0-NN-N-E-115"
const OUT := "user://shots"
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var tele = load("res://scripts/Telemetry.gd").new()
	tele.name = "Telemetry"
	root.add_child(tele)
	var strs = load("res://scripts/Strings.gd").new()
	strs.name = "Strings"
	root.add_child(strs)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	Session.activate(CODE)
	main.code_edit.text = CODE
	main._on_continue()
	await _w(3.4); await _s("01_soru")
	main.cb_gravity.button_pressed = true
	main.cb_air.button_pressed = true
	main.cb_air.toggled.emit(true)
	main._update_preview()
	main._on_run()
	await _w(3.0); await _s("02_ucus")
	await _w(9.0); await _s("03_bitis")
	print("bitti"); quit(0)
func _w(sec: float) -> void: await create_timer(sec).timeout
func _s(n: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, n])
