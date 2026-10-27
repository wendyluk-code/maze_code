extends "res://tools/tests/combat_07_flow.gd"

# JSON默认十进制转换的末位误差，远小于Vector2世界位置的float32精度。
# 整数仍精确相等；结构、字段和数组长度继续用原递归检查。
func _same_saved(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:
		var difference := absf(float(a)-float(b))
		if difference > 0.000000000001:
			var file := FileAccess.open(_arg("--report=").get_base_dir().path_join("json_precision.jsonl"),FileAccess.READ_WRITE)
			if file == null: file = FileAccess.open(_arg("--report=").get_base_dir().path_join("json_precision.jsonl"),FileAccess.WRITE)
			file.seek_end()
			file.store_line(JSON.stringify({"loaded":a,"original":b,"absolute_difference":difference}))
		if float(a)==floor(float(a)) or float(b)==floor(float(b)): return float(a)==float(b)
		return difference < 0.000000001
	return super._same_saved(a,b)
