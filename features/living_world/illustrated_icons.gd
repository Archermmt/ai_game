# gdlint: disable=max-line-length
# SVG path literals remain intact as editable vector artwork.
class_name IllustratedIcons
extends RefCounted
## Original miniature drawings, rendered once and cached; no font glyph stand-ins.

static var _textures: Dictionary = {}


static func texture(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var art: String = drawing(key)
	var svg: String = (
		'<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 72 72"><g stroke="#655b43" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">'
		+ art
		+ "</g></svg>"
	)
	var image: Image = Image.new()
	image.load_svg_from_string(svg)
	var result: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = result
	return result


static func drawing(key: String) -> String:
	if key.contains("玻璃门"):
		return '<path d="M18 11h36v51H18z" fill="#b99568"/><path d="M24 17h24v37H24z" fill="#aac7c2"/><path d="M36 17v37M24 34h24"/><circle cx="47" cy="43" r="2" fill="#665b43"/>'
	if key.contains("浇水"):
		return '<path d="M20 31h28v28H20z" fill="#a6bcb0"/><path d="M48 34l15-13 4 5-19 22M20 35q-17-20 0-23l9 19" fill="none" stroke-width="4"/><path d="M61 15l6 6m-9 0l6 6"/>'
	if key.contains("灌木"):
		return '<path d="M10 47q-9-17 8-22-2-18 16-17 18-7 23 13 18 1 11 20-8 17-58 6z" fill="#a4b47e"/><path d="M36 62V30m0 14l-12-8m12 4l14-12" fill="none"/>'

	if key.contains("取消"):
		return '<path d="M24 21Q59 10 58 37 57 63 28 57M24 10v22h22" fill="none" stroke-width="4"/>'

	if key == "roof":
		return '<path d="M13 50l23-23 23 23z" fill="#c7976a"/><path d="M36 29V7m-8 9l8-9 8 9" fill="none"/>'
	if key in ["height", "width", "depth", "scale", "end_a", "end_b"]:
		if key == "height":
			return '<path d="M36 10v52m-9-43l9-9 9 9m-18 34l9 9 9-9" fill="none" stroke-width="4"/>'
		if key == "width":
			return '<path d="M10 36h52m-43-9l-9 9 9 9m34-18l9 9-9 9" fill="none" stroke-width="4"/>'
		return '<path d="M14 58l44-44m-29 0h29v29M14 29v29h29" fill="none" stroke-width="4"/>'
	if key == "rotate":
		return '<path d="M52 23a23 23 0 1 0 5 24M52 11v17H35" fill="none" stroke-width="4"/>'
	if key.contains("降低"):
		return '<path d="M8 55l15-16 14 4 16-16 11 28z" fill="#a8b889"/><path d="M34 8v28m-9-9l9 9 9-9" fill="none"/>'
	if key.contains("平滑"):
		return '<path d="M7 50q14-26 29-9t29-3v22H7z" fill="#a8b889"/><path d="M13 20h46m-8-8l8 8-8 8" fill="none"/>'
	if key.contains("恢复"):
		return '<path d="M10 56l18-18 15 7 17-20v35H10z" fill="#b8bf94"/><path d="M17 24a18 18 0 1 1 33 0M10 11v16h16" fill="none"/>'
	if key.contains("选择") or key.contains("浏览"):
		return '<path d="M19 10l37 29-19 3-9 19z" fill="#efe2bd"/>'
	if key.contains("黄昏") or key.contains("日间"):
		return '<path d="M10 48h52M20 47a17 17 0 0 1 34 0" fill="#e0b777"/><path d="M36 12v10M14 22l8 8m36-8l-8 8" fill="none"/>'
	if key.contains("岁月") or key.contains("新居"):
		return '<path d="M16 33l20-21 20 21v28H16z" fill="#d6c6a5"/><path d="M12 34l24-26 24 26" stroke="#b78463" stroke-width="5" fill="none"/><path d="M20 58q-3-23 18-17" stroke="#a4b17e" stroke-width="6" fill="none"/>'
	if key.contains("远景") or key.contains("庭院"):
		return '<path d="M10 16h52v42H10z" fill="#c9d2ba"/><path d="M11 53l17-24 12 16 10-12 12 20" fill="#9eb288"/><circle cx="47" cy="26" r="6" fill="#dfc382"/>'

	if key in ["paint", "palette"]:
		return '<path d="M15 51Q0 21 26 12q30-12 38 16 3 13-13 12-14-3-11 9 3 20-25 2z" fill="#cbb58e"/><circle cx="23" cy="27" r="5" fill="#a5b481"/><circle cx="39" cy="21" r="5" fill="#c18763"/><circle cx="53" cy="29" r="5" fill="#a6c4be"/>'
	if key.contains("针叶"):
		return '<path d="M33 48h7v17h-7z" fill="#aa865e"/><path d="M36 6L19 29h8L13 44h11L9 57h54L48 44h11L44 29h9z" fill="#88a47c"/>'
	if key.contains("果树"):
		return '<path d="M33 43h7v22h-7z" fill="#aa865e"/><ellipse cx="36" cy="28" rx="25" ry="23" fill="#a8b67b"/><circle cx="24" cy="24" r="4" fill="#c78967"/><circle cx="46" cy="35" r="4" fill="#c78967"/>'
	if key.contains("石") and not key.contains("石径"):
		return '<path d="M8 51l9-25 23-10 21 14 5 23-31 9z" fill="#b6b99c"/><path d="M17 26l17 18 27-14M34 44l1 18" fill="none"/><path d="M13 51q14-16 23-5" stroke="#8ea578" stroke-width="7" fill="none"/>'
	if key.contains("茶"):
		return '<ellipse cx="36" cy="56" rx="27" ry="7" fill="#bdab86"/><path d="M20 26h29v20q-14 17-29 0z" fill="#e4dcc0"/><path d="M49 29q20-1 9 16h-9M29 19q-6-7 0-13m11 13q-6-7 0-13" fill="none"/>'
	if key.contains("蕨"):
		return '<path d="M36 62Q17 27 40 9m-7 30L12 28m19-1l-15-9m19 0l-6-12m8 25l18-14m-22 30l25-12" stroke="#92aa74" stroke-width="6" fill="none"/>'

	if key.contains("取消") or key.contains("收起") or key.contains("结束") or key == "close":
		return '<circle cx="36" cy="36" r="22" fill="#f5e8c9"/><path d="M26 26l20 20m0-20L26 46"/>'
	if key.contains("删除") or key.contains("擦除") or key in ["erase", "eraser"]:
		return '<path d="M17 44l24-28 18 16-23 28H23z" fill="#bc9275"/><path d="M17 44l13 11 12-15-13-11" fill="#e6d8b7"/><path d="M16 62h43"/>'
	if key.contains("复制"):
		return '<path d="M16 15h29v35H16z" fill="#c6c89b"/><path d="M28 26h29v35H28z" fill="#f6e6be"/><path d="M34 35h17m-17 8h17m-17 8h10"/>'
	if key.contains("参数") or key == "settings":
		return '<path d="M17 19h38M17 36h38M17 53h38"/><circle cx="29" cy="19" r="6" fill="#d49b65"/><circle cx="46" cy="36" r="6" fill="#aaba84"/><circle cx="25" cy="53" r="6" fill="#a9c7c6"/>'
	if key.contains("桥"):
		return '<path d="M10 45l43-23 11 10-44 25z" fill="#c89964"/><path d="M15 34l43-22m-43 8v29m43-44v29M15 27l43-22M25 37l10 11m0-16l10 11m0-16l10 11" fill="none"/>'
	if key.contains("阶"):
		return '<path d="M12 56V44h14V33h14V22h18v34z" fill="#c6bfa0"/><path d="M12 44h46M26 33h32M40 22h18"/>'
	if key.contains("围栏") or key.contains("绿篱"):
		return '<path d="M14 18l5-6 5 6v42H14zM48 18l5-6 5 6v42H48z" fill="#b89a71"/><path d="M19 29h34v7H19zM19 46h34v7H19z" fill="#cfb184"/>'
	if key.contains("圆形小屋") or key == "round":
		return '<path d="M18 32v25q18 12 36 0V32" fill="#eddfba"/><path d="M14 33L36 8l22 25q-22 10-44 0z" fill="#ca916a"/><path d="M31 62V46q5-7 10 0v16" fill="#b29163"/>'
	if key.contains("小屋") or key in ["house", "build", "rect"]:
		return '<path d="M16 32l24-11 18 12v28H16z" fill="#eddfba"/><path d="M9 33L31 9l32 23-23 4-9-15-15 15z" fill="#cc9068"/><path d="M25 61V45h11v16" fill="#b19568"/><path d="M45 42h8v9h-8z" fill="#adc7bc"/>'
	if key.contains("门") and not key.contains("窗"):
		var arch: bool = key.contains("拱")
		return (
			(
				'<path d="M18 61V29q18-30 36 0v32z" fill="#c69865"/>'
				if arch
				else '<path d="M18 13h36v48H18z" fill="#c69865"/>'
			)
			+ '<path d="M23 23v33m9-33v33m9-33v33m8-33v33" stroke="#ab8057"/><circle cx="45" cy="40" r="2" fill="#655b43"/>'
		)
	if key.contains("窗") or key == "window":
		return (
			(
				'<circle cx="36" cy="36" r="23" fill="#b78e60"/><circle cx="36" cy="36" r="17" fill="#a9c9c4"/>'
				if key.contains("圆")
				else '<path d="M13 13h46v46H13z" fill="#bb9566"/><path d="M20 20h32v32H20z" fill="#a9c9c4"/>'
			)
			+ '<path d="M36 18v36M18 36h36"/>'
		)
	if (
		key.contains("抬高")
		or key.contains("降低")
		or key.contains("平滑")
		or key.contains("恢复")
		or key == "raise"
	):
		return '<path d="M7 55l13-18 14 5 13-23 18 36z" fill="#b1bd8a"/><path d="M36 30V9m-7 8l7-8 7 8" fill="none"/>'
	if key.contains("石径") or key.contains("路径") or key == "path":
		return '<path d="M18 64q38-18 17-31T50 8" stroke="#b9a285" stroke-width="15" fill="none"/><path d="M18 64q38-18 17-31T50 8" stroke="#eee0ba" stroke-width="10" stroke-dasharray="8 3" fill="none"/>'
	if key.contains("树") or key == "tree":
		return '<path d="M33 41h7v24h-7z" fill="#ac865f"/><path d="M18 42q-12-14 1-22 0-17 16-10 17-10 23 8 15 10 3 24-21 14-43 0z" fill="#9eae75"/><path d="M36 23v29m0-14l-12-9m12 3l12-12" fill="none"/>'
	if key.contains("花") or key.contains("植") or key.contains("灌") or key == "plant":
		return '<path d="M36 60V30m0 17Q9 49 16 31q18-2 20 16m0 9q25 1 21-20-17 0-21 20" fill="#9eb681"/><path d="M36 11q14-9 16 4 14 9 0 17-9 14-19 0-17-4-8-17 2-11 11-4z" fill="#ddbb9d"/><circle cx="39" cy="22" r="6" fill="#e4d29b"/>'
	if key.contains("池") or key == "pond":
		return '<ellipse cx="36" cy="40" rx="28" ry="17" fill="#a7c8c4"/><path d="M16 40q9-8 19 0t21 0M23 49q12-6 25-1" fill="none"/><path d="M48 27l-2-13m0 7l10-9"/>'
	if key.contains("移动") or key in ["move", "高", "宽", "移", "depth", "height", "width"]:
		return '<path d="M36 10v52M10 36h52m-34-18l8-8 8 8m-16 36l8 8 8-8M18 28l-8 8 8 8m36-16l8 8-8 8" fill="none"/>'
	if key.contains("旋转"):
		return '<path d="M52 23a23 23 0 1 0 5 24M52 11v17H35" fill="none" stroke-width="4"/>'
	if key.contains("晴") or key in ["sun", "clear", "summer"]:
		return '<circle cx="36" cy="36" r="15" fill="#e2bc6d"/><path d="M36 6v8m0 44v8M6 36h8m44 0h8M15 15l6 6m30 30l6 6m0-42l-6 6M21 51l-6 6"/>'
	if key in ["cloudy", "rain", "snow"]:
		return (
			'<path d="M12 40q-10-19 9-22 4-19 22-9 18-2 19 16 14 17-5 20H17z" fill="#c6cec5"/>'
			+ (
				'<path d="M22 51l-5 12m20-12l-5 12m20-12l-5 12" stroke="#80aebd"/>'
				if key == "rain"
				else (
					'<path d="M21 53v10m-5-5h10m20-5v10m-5-5h10" stroke="#91b5c3"/>'
					if key == "snow"
					else ""
				)
			)
		)
	if key in ["winter", "autumn", "spring"]:
		return (
			'<path d="M18 54Q10 12 58 10q9 39-40 44z" fill="'
			+ ("#c8d8d5" if key == "winter" else ("#cb9c5d" if key == "autumn" else "#a5bf80"))
			+ '"/><path d="M15 61l32-37m-18 17l-3-15m9 9l16-2" fill="none"/>'
		)
	if key.contains("摄影") or key == "photo":
		return '<path d="M10 24h13l5-8h17l6 8h12v34H10z" fill="#a9b7b0"/><circle cx="36" cy="40" r="13" fill="#e9dfbc"/><circle cx="36" cy="40" r="8" fill="#8a9c91"/>'
	# Eight prop families retain distinct illustrated silhouettes, not letter badges.
	var n: int = posmod(key.hash(), 5)
	if key.contains("信"):
		return '<path d="M14 22q18-22 36 0v22H14z" fill="#bf976d"/><path d="M35 44v20m-7 0h15M46 18l13-8v20" fill="none"/>'
	if key.contains("凳") or key.contains("椅"):
		return '<path d="M12 30h47v10H12zM15 42v19m40-19v19M14 13h43v12H14z" fill="#b99a6b"/>'
	if key.contains("灯"):
		return '<path d="M25 17q11-17 22 0M21 22h30l-3 34H24z" fill="#e1c481"/><path d="M29 28v22m14-22v22M21 59h30"/>'
	if key.contains("晾"):
		return '<path d="M12 12v51m48-51v51M12 22h48"/><path d="M22 22h25v28H22z" fill="#e8dec0"/>'
	if key.contains("盆") or key.contains("壶"):
		return '<path d="M20 36h32l-6 26H26z" fill="#c89472"/><path d="M36 36V14m0 12q-20 0-17-14 13-1 17 14m0 4q20-1 19-16-14 0-19 16" fill="#9db07b"/>'
	return (
		'<path d="M15 29l21-12 22 12v29H15z" fill="'
		+ ["#cead82", "#b6bd8e", "#d1bd91", "#acc3bb", "#d3ac88"][n]
		+ '"/><path d="M15 29l21 10 22-10M36 39v19M24 22l21 10" fill="none"/>'
	)
