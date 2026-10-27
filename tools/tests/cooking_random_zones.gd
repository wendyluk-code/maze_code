extends SceneTree
const J = preload("res://scripts/cooking/qte_judgement.gd")
func _initialize():
	for i in 1000:
		var z = J.random_zones()
		assert(z.perfect < z.good)
		assert(absf(z.center) + z.good/2 < 1)
		assert(J.stars_for_position(z.center,z.perfect,z.good,z.center)==3)
		assert(J.stars_for_position(z.center+(z.perfect+z.good)/4,z.perfect,z.good,z.center)==2)
		assert(J.stars_for_position(-1,z.perfect,z.good,z.center)==1)
		assert(J.stars_for_position(1,z.perfect,z.good,z.center)==1)
	print("1000组随机布局：嵌套、边界、三星/二星/一星判定通过")
	quit()
