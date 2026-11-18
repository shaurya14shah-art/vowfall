extends SceneTree
## Tiles every PNG in a folder into one image. Headless.
##   godot --headless --script tools/contact_sheet.gd -- <dir> <out.png> [columns] [cell width]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := str(a[0])
	var cols := int(a[2]) if a.size() > 2 else 3
	var cell_w := int(a[3]) if a.size() > 3 else 800
	var files := DirAccess.get_files_at(dir)
	var names: Array = []
	for f in files:
		if f.ends_with(".png") and not f.begins_with("sheet"):
			names.append(f)
	names.sort()
	if names.is_empty():
		print("no images in " + dir)
		quit(1)
		return
	var imgs: Array = []
	var cell_h := 0
	for n: String in names:
		var img := Image.load_from_file(dir.path_join(n))
		img.resize(cell_w, int(float(cell_w) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
		img.convert(Image.FORMAT_RGBA8)
		cell_h = maxi(cell_h, img.get_height())
		imgs.append(img)
	var rows := int(ceil(float(imgs.size()) / cols))
	var gap := 6
	var sheet := Image.create(cols * cell_w + (cols + 1) * gap, rows * cell_h + (rows + 1) * gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i in imgs.size():
		var img: Image = imgs[i]
		var x := gap + (i % cols) * (cell_w + gap)
		var y := gap + (i / cols) * (cell_h + gap)
		sheet.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(x, y))
	sheet.save_png(str(a[1]))
	print("sheet: %d images, %dx%d" % [imgs.size(), sheet.get_width(), sheet.get_height()])
	quit()
