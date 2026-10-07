## test_palette.gd
## 职责：调色板 Token 机制的验收 —— 35 个 Token 一个不少、枚举与资源一一对应、查不到不崩。
## 所属系统：tests
## 依赖：Palette
## 禁止：本文件不得写入颜色值，只断言。
##
## 为什么值得单独立一条：颜色在本工程里只有 Palette.get_color() 一个入口（04 §7），
## 所以「枚举里有一个 Token 而 palette.tres 里没有」这种错误的唯一表现就是
## 界面上某处变成 MISSING_COLOR 的洋红 —— 而洋红不容易在截图里被认出来是错误。
## 这里把它变成一条会失败的断言。

extends RefCounted

## docs/04 §3 登记的 Token 总数。少一个就有地方会画成洋红。
const EXPECTED_TOKENS: int = 35


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_palette")
	_check_resource(ctx)
	_check_token_count(ctx)
	_check_enum_matches_resource(ctx)
	_check_missing_color(ctx)
	_check_uniqueness(ctx)


func _check_resource(ctx: RefCounted) -> void:
	var palette: Palette = Palette.get_palette()
	ctx.check(palette != null, "调色板资源可加载：%s" % Palette.RESOURCE_PATH)
	if palette == null:
		return
	ctx.check(ResourceLoader.exists(Palette.RESOURCE_PATH), "调色板文件确实存在")
	# 同一份资源必须复用，而不是每次读盘 —— 它被每个绘制调用查。
	ctx.check(Palette.get_palette() == palette, "调色板被缓存（两次取到同一实例）")


func _check_token_count(ctx: RefCounted) -> void:
	var names: Array[StringName] = Palette.token_names()
	ctx.equal(names.size(), EXPECTED_TOKENS, "资源里有 %d 个 Token" % EXPECTED_TOKENS)
	# 枚举里也要有这么多 —— 少一个意味着有一个 Token 名写错了或漏登记。
	var enum_size: int = 0
	for key: int in Palette.Key.values():
		enum_size += 1
	ctx.equal(enum_size, EXPECTED_TOKENS, "Palette.Key 枚举也是 %d 项" % EXPECTED_TOKENS)


## 枚举 ↔ 资源一一对应。任何一个方向上缺一项都会让某处画成洋红。
func _check_enum_matches_resource(ctx: RefCounted) -> void:
	var palette: Palette = Palette.get_palette()
	var missing: PackedStringArray = PackedStringArray()
	var magenta: PackedStringArray = PackedStringArray()
	for key: int in Palette.Key.values():
		var name: StringName = Palette.key_to_name(key)
		if not palette.has_token(key):
			missing.append(String(name))
			continue
		if Palette.get_color(key) == Palette.MISSING_COLOR:
			magenta.append(String(name))
	ctx.equal(missing.size(), 0,
		"每个枚举项在资源里都有对应颜色" if missing.is_empty() else "缺颜色：%s" % ", ".join(missing))
	ctx.equal(magenta.size(), 0,
		"没有 Token 落回洋红兜底色" if magenta.is_empty() else "落回兜底：%s" % ", ".join(magenta))
	# 反向：资源里也不该有多出来的、枚举管不到的 Token。
	var extra: PackedStringArray = PackedStringArray()
	for name: StringName in Palette.token_names():
		var known: bool = false
		for key: int in Palette.Key.values():
			if Palette.key_to_name(key) == name:
				known = true
				break
		if not known:
			extra.append(String(name))
	ctx.equal(extra.size(), 0,
		"资源里没有枚举管不到的孤儿 Token" if extra.is_empty() else "孤儿 Token：%s" % ", ".join(extra))


## 04 §7：MISSING_COLOR 是「没设 / 查不到」的专用值 —— 它必须一眼认得出，且不属于正常色板。
func _check_missing_color(ctx: RefCounted) -> void:
	ctx.equal(Palette.MISSING_COLOR, Color.MAGENTA, "兜底色是洋红（一眼认得出）")
	for name: StringName in Palette.token_names():
		var token_color: Variant = Palette.get_palette().colors.get(String(name))
		ctx.check(token_color != Palette.MISSING_COLOR, "Token %s 不是兜底色" % name)
	# 反向对照：越界的枚举值必须返回兜底色，而不是崩溃或返回黑色。
	ctx.equal(Palette.get_color(9999), Palette.MISSING_COLOR, "反向对照：越界枚举返回兜底色")
	ctx.check(not Palette.get_palette().has_token(9999), "反向对照：越界枚举 has_token 为 false")


## 两个 Token 撞成同一个色值一定是复制粘贴事故 —— 界面会分不清两种语义。
func _check_uniqueness(ctx: RefCounted) -> void:
	var seen: Dictionary = {}
	var duplicated: PackedStringArray = PackedStringArray()
	for name: StringName in Palette.token_names():
		var value: Variant = Palette.get_palette().colors.get(String(name))
		var key: String = str(value)
		if seen.has(key):
			duplicated.append("%s = %s（与 %s 相同）" % [name, key, seen[key]])
		seen[key] = name
	ctx.equal(duplicated.size(), 0,
		"%d 个 Token 色值互不相同" % Palette.token_names().size() if duplicated.is_empty()
		else "重复色值：%s" % "; ".join(duplicated))
