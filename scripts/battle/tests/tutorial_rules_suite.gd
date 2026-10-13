extends SceneTree
const Rules = preload("res://scripts/battle/tutorial_rules.gd")
var checks := 0
var failures: Array[String] = []
var stages: Array = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func play(s: Dictionary, action: String, target := "tieshan") -> void:
	var result := Rules.transact(s, action, target)
	check(result.success, "操作成功 %d %s: %s" % [s.turn, action, str(result)])

func unchanged(s: Dictionary, action: String, target: String, reason: String) -> void:
	var snapshot := s.duplicate(true)
	var result := Rules.transact(s, action, target)
	check(not result.success, "拒绝：" + reason)
	check(s == snapshot, "原子拒绝：" + reason)

func conserved(s: Dictionary) -> void:
	check(s.hand.size() + s.deck.size() + s.discard.size() == 16, "总牌数16")
	for id in Rules.SKILLS:
		check(s.hand.count(id) + s.deck.count(id) + s.discard.count(id) == 2, "每种两张 " + id)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/card_tutorial_01")
	# 每个位置均可调整，并且后续预留牌不会被提前抽走。
	for slot in range(5):
		for trial in range(12):
			var s := Rules.new_state()
			for _i in range(3):
				check(Rules.replace(s, slot).success, "五个位置允许调整")
				check(s.hand.has("tieshan_strong") and s.hand.has("tieshan_guard"), "调整后关键起手保障")
				conserved(s)
			run_battle(s, trial == 0 and slot == 0)
	var s := Rules.new_state()
	Rules.begin_turn(s, "player")
	unchanged(s, "tieshan_guard", "tieshan", "乱序")
	unchanged(s, "end", "", "过早结束")
	unchanged(s, "tieshan_strong", "yaya", "非法目标")
	s.ap = 0
	unchanged(s, "tieshan_strong", "tieshan", "行动点不足")
	s.ap = 2
	s.characters.tieshan.satiety = 0
	unchanged(s, "tieshan_strong", "tieshan", "饱腹不足")
	s = Rules.new_state()
	Rules.begin_turn(s, "player")
	s.hand.append("yaya_magic_hit")
	s.characters.yaya.mana = 1
	unchanged(s, "yaya_magic_hit", "slime_a", "魔力不足")
	# 非教学限制下覆盖守护条件、单战斗位替换、普通出击共享配额。
	s = Rules.new_state()
	Rules.begin_turn(s, "player")
	check(Rules.transact(s, "attack", "yaya", false).success, "芽芽普通出击")
	var before := s.duplicate(true)
	check(not Rules.transact(s, "attack", "tieshan", false).success and s == before, "全队普通出击只一次")
	var hp: int = s.enemy_hp
	check(Rules.transact(s, "tieshan_guard", "tieshan", false).success, "战斗牌可追加并替换芽芽")
	check(s.zones.player == "tieshan" and s.enemy_hp == hp - 4, "守护条件+3只限本次")
	check(Rules.attack_value(s.characters.tieshan) == 1, "临时攻击恢复")
	# 饥饿增伤先抵盾；恢复到正数立即解除攻击减益。
	s.characters.yaya.satiety = 0
	s.characters.yaya.shield = 2
	Rules.damage(s, "yaya", 1, "spell", "slime_a")
	check(s.characters.yaya.hp == 4 and s.characters.yaya.shield == 0, "饥饿受伤+2先扣盾")
	check(Rules.attack_value(s.characters.yaya) == 0, "饥饿攻击最低0")
	s.characters.yaya.satiety = 1
	check(Rules.attack_value(s.characters.yaya) == 2, "饱腹正数立即解除")
	# 赋形在战斗区保护其他角色，保留原技能；死亡后三次己方开始复活。
	s = Rules.new_state()
	s.characters.tieshan.form = "tieshan_hold"
	s.zones.player = "tieshan"
	Rules.damage(s, "yaya", 99, "spell", "slime_a")
	check(s.characters.yaya.hp == 5, "坚守保护其他角色")
	Rules.end_turn(s, "player")
	check(s.characters.tieshan.shield == 2, "赋形保留原技能")
	s.zones.player = ""
	s.characters.tieshan.bonus_attack = 2
	s.characters.tieshan.bonus_hp = 2
	s.characters.tieshan.satiety = 0
	Rules.damage(s, "tieshan", 99, "spell", "slime_a")
	check(not s.characters.tieshan.alive and s.characters.tieshan.form == "" and s.characters.tieshan.revive == 3, "死亡清形态并倒计时3")
	for i in range(3):
		Rules.begin_turn(s, "enemy")
		check(s.characters.tieshan.revive == 3 - i, "敌方回合不扣我方倒计时")
		Rules.begin_turn(s, "player")
	check(s.characters.tieshan.alive and s.characters.tieshan.hp == 9 and Rules.attack_value(s.characters.tieshan) == 3, "复活基础角色并保留永久增益")
	check(s.characters.tieshan.satiety == 8 and s.characters.tieshan.mana == Rules.data().tieshan.mana_initial, "铁山复活恢复初始资源")
	s = Rules.new_state()
	s.characters.yaya.satiety = 0
	s.characters.yaya.mana = 0
	Rules.damage(s, "yaya", 99, "spell", "slime_a")
	for _i in range(3): Rules.begin_turn(s, "player")
	check(s.characters.yaya.alive and s.characters.yaya.satiety == 6 and s.characters.yaya.mana == 4, "芽芽复活先恢复初始魔力3，再触发回合开始+1")
	# 父史莱姆只有两只分裂体阵亡后计时；法术不附着粘液。
	s = Rules.new_state()
	Rules.damage(s, "slime_a", 5, "spell", "yaya")
	Rules.begin_turn(s, "enemy")
	check(s.characters.slime_a.revive == -1, "分裂体未全灭不计时")
	Rules.damage(s, "slime_a1", 4, "spell", "yaya")
	check(s.characters.yaya.satiety == 6 and s.characters.slime_a.revive == -1, "法术击杀无粘液且仍等待第二只")
	Rules.damage(s, "slime_a2", 4, "spell", "yaya")
	check(s.characters.slime_a.revive == 3, "分裂体全灭开始计时")
	for _i in range(3): Rules.begin_turn(s, "enemy")
	check(s.characters.slime_a.alive and s.characters.slime_a.hp == 5, "三次所属方开始后父体复活")
	# 群体法术同时覆盖准备区与战斗区，治疗各自计算溢出。
	s = Rules.new_state()
	Rules.begin_turn(s, "player")
	s.zones.enemy = "slime_a"
	if not s.hand.has("yaya_magic_wind"): s.hand.append("yaya_magic_wind")
	check(Rules.transact(s, "yaya_magic_wind", "slime_b", false).success, "群攻可从准备区目标施放")
	check(s.characters.slime_a.hp == 4 and s.characters.slime_b.hp == 4, "群攻同时覆盖战斗区和准备区")
	s = Rules.new_state()
	Rules.begin_turn(s, "player")
	s.zones.player = "tieshan"
	s.characters.yaya.hp = 4
	s.characters.tieshan.hp = 6
	if not s.hand.has("yaya_heal_wind"): s.hand.append("yaya_heal_wind")
	check(Rules.transact(s, "yaya_heal_wind", "yaya", false).success, "群体治疗可以选择准备区角色")
	check(s.characters.yaya.hp == 5 and s.characters.yaya.shield == 2 and s.characters.tieshan.hp == 7 and s.characters.tieshan.shield == 2, "两个区域分别治疗与溢出转盾")
	var file := FileAccess.open("res://output/card_tutorial_01/rules_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "stages": stages}, "\t"))
	file.close()
	print("CARD_TUTORIAL_RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func run_battle(s: Dictionary, record: bool) -> void:
	var expected := [
		[30, 6, 7, 6, 4, 6, 4], [28, 6, 7, 8, 0, 4, 3],
		[28, 6, 6, 4, 1, 6, 4], [28, 2, 5, 1, 0, 6, 5],
		[27, 2, 5, 3, 0, 4, 4], [27, 2, 7, 0, 1, 1, 2],
		[26, 2, 8, 2, 0, 0, 2], [26, 0, 8, 1, 1, 0, 3]]
	for turn in range(1, 9):
		Rules.begin_turn(s, "player")
		check(s.draw_count == turn, "包含第1回合在内每回合抽1张")
		for action in Rules.STEPS[turn - 1]:
			play(s, action, "slime_a" if action == "yaya_magic_hit" else ("slime_a2" if action == "yaya_magic_wind" else "tieshan"))
		if turn < 8:
			play(s, "end")
			check(Rules.enemy_turn(s).success, "固定敌方回合")
		var t: Dictionary = s.characters.tieshan
		var y: Dictionary = s.characters.yaya
		var actual := [s.player_hp, s.enemy_hp, t.hp, t.satiety, t.shield, y.satiety, y.mana]
		check(actual == expected[turn - 1], "第%d轮终值 %s 期望 %s" % [turn, str(actual), str(expected[turn - 1])])
		conserved(s)
		if record: stages.append({"turn": turn, "state": s.duplicate(true)})
	check(s.winner == "player" and s.characters.yaya.alive and s.characters.slime_a.revive == 1, "最终26/0、芽芽存活、史莱姆A倒计时1")
