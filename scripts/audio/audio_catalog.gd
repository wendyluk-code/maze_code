@tool
extends RefCounted
## 编辑器与游戏共用的用途目录。相同素材可对应多个独立用途。

static func entries() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	_add(rows, "music_boss", "Boss战斗音乐", "音乐", "bgm/boss_battle.mp3", -12, "Boss首次攻击前摇开始；倒下或探索失败恢复迷宫音乐，离场切换目标音乐。", ["scripts/audio/game_audio.gd", "scripts/maze/capture_flow.gd"])
	_add(rows, "music_home", "冒险者之家音乐", "音乐", "bgm/adventurer_home.ogg", -6, "确认进入即播放；返回餐厅立即切回，页面加载不重播。", ["scripts/audio/game_audio.gd", "scripts/ui/adventurer_home.gd"])
	_add(rows, "music_start", "开始界面音乐", "音乐", "bgm/start_screen.mp3", -12, "开始界面显示期间循环，离开界面停止。", ["scripts/audio/start_screen_music.gd", "scenes/start_screen.tscn"])
	_add(rows, "music_restaurant", "餐厅音乐", "音乐", "bgm/M01_restaurant.ogg", -12, "进入餐厅播放；旧场景内音乐节点仅保留兼容，不重复播放。", ["scripts/audio/game_audio.gd"])
	_add(rows, "music_maze", "迷宫探索音乐", "音乐", "bgm/maze_exploration.ogg", -12, "迷宫地图间连续播放；返回餐厅时切换。", ["scripts/audio/game_audio.gd", "scripts/ui/components/scene_transition.gd"])
	_add(rows, "interact", "点击与有效交互", "音效", "sfx/interaction_click.wav", -6, "全局鼠标点击、有效 E 交互；同一输入去重。", ["scripts/audio/game_audio.gd", "scripts/player_map.gd", "scripts/dialog_box.gd"])
	_add(rows, "dialogue_typing", "对白逐字声", "对白", "sfx/dialogue_typing.ogg", 2, "对白逐字显示时循环；补全、关闭、失焦时停止。", ["scripts/dialog_box.gd"])
	_add(rows, "customer_arrival", "顾客到达前台", "音效", "sfx/customer_arrival.wav", -6, "普通营业顾客到达前台。", ["scripts/restaurant/customer_flow.gd"])
	_add(rows, "order_accepted", "普通订单接单成功", "音效", "sfx/serve_correct.wav", -6, "普通接单保存成功后播放；铁山首单不播放。与交付共用素材，音量独立。", ["scripts/restaurant/customer_flow.gd"])
	_add(rows, "customer_seated", "顾客落座／铁山起身", "音效", "sfx/customer_seated.wav", -1, "普通顾客落座；首章铁山从地上起身时播放，恢复坐姿不补播。", ["scripts/restaurant/customer_flow.gd", "scripts/guest_placeholder.gd"])
	_add(rows, "serve_correct", "正确交付提示", "音效", "sfx/serve_correct.wav", -6, "料理或甘露水交付成功，完整播放后再接赞叹；连续交付排队。", ["scripts/audio/game_audio.gd", "scripts/restaurant/customer_flow.gd", "scripts/restaurant/ganlu_controller.gd", "scripts/tutorial_manager.gd"])
	_add(rows, "food_enjoy", "料理赞叹", "音效", "sfx/food_enjoy.wav", -6, "正确料理交付提示播完后播放，含铁山首单。", ["scripts/audio/game_audio.gd"])
	_add(rows, "water_enjoy", "甘露水赞叹", "音效", "sfx/water_enjoy.wav", 0, "正确甘露水交付提示播完后播放。", ["scripts/audio/game_audio.gd", "scripts/restaurant/ganlu_controller.gd"])
	_add(rows, "cooking_loop", "烹饪过程", "音效", "sfx/cooking_user.ogg", 0, "料理台成功开火后循环；结束、取消、关闭时停止。", ["scripts/ui/cooking_modal.gd"])
	_add(rows, "ganlu_pour", "甘露水倒水过程", "音效", "sfx/ganlu_pour.ogg", -6, "倒水操作期间循环，结束或关闭时停止。", ["scripts/ui/components/ganlu_pour_modal.gd"])
	_add(rows, "cooking_complete", "制作完成／章末／结算提示", "音效", "sfx/capture_success.wav", -16, "烹饪结果、甘露水制作成功、第一章结束标题及非关店结算开场共用此用途。", ["scripts/ui/cooking_modal.gd", "scripts/ui/components/ganlu_pour_modal.gd", "scripts/chapter_1_outro.gd", "scripts/ui/components/restaurant_settlement_intro.gd"])
	_add(rows, "business_complete", "营业完成结算", "音效", "sfx/business_complete.wav", -6, "当天营业结算出现时播放；同存档同一天去重。", ["scripts/ui/components/restaurant_day_settlement.gd", "scripts/audio/game_audio.gd"])
	_add(rows, "restaurant_closed", "关店结算开场", "音效", "sfx/restaurant_closed.wav", -6, "关店状态的结算开场提示。", ["scripts/ui/components/restaurant_settlement_intro.gd"])
	_add(rows, "failure", "错误交付／不满／失败", "音效", "sfx/failure_user.wav", -6, "错菜、错水、超时等顾客不满，以及战斗失败弹窗。", ["scripts/restaurant/customer_flow.gd", "scripts/ui/components/capture_dialog.gd"])
	_add(rows, "party_join", "第一章入队演出", "音效", "sfx/party_join.wav", -16, "第一章结尾入队卡面展示时播放。", ["scripts/chapter_1_outro.gd"])
	_add(rows, "tieshan_groan", "铁山呻吟", "音效", "sfx/character/tieshan_groan.wav", -12, "餐厅铁山剧情反馈。", ["scripts/guest_placeholder.gd"])
	for i in 4:
		_add(rows, "footstep_%02d" % (i+1), "行走脚步 %d" % (i+1), "音效", "sfx/character/footstep_%02d.wav" % (i+1), [-22, -22, -23, -27][i], "餐厅与迷宫真实位移触发，四段轮换；停止移动不响。", ["scripts/audio/character_motion_audio.gd", "scripts/player_map.gd", "scripts/maze/maze_player.gd"])
	_add(rows, "sprint_start", "冲刺起步", "音效", "sfx/character/sprint_start_clip1.wav", -10, "实际移动进入冲刺时播放。", ["scripts/audio/character_motion_audio.gd"])
	for i in 5:
		_add(rows, "attack_%02d" % (i+1), "普通攻击 %d" % (i+1), "音效", "sfx/character/attack_%02d.wav" % (i+1), -20, "迷宫有效攻击，五段轮换，并取消同次点击的通用声。", ["scripts/maze/capture_flow.gd", "scripts/audio/game_audio.gd"])
	for i in 3:
		_add(rows, "hit_%02d" % (i+1), "攻击命中 %d" % (i+1), "音效", "sfx/character/hit_%02d.wav" % (i+1), -6, "迷宫战斗命中反馈，三段轮换。", ["scripts/maze/capture_flow.gd", "scripts/audio/game_audio.gd"])
	_add(rows, "hero_hurt", "主角受伤", "音效", "sfx/character/hero_hurt.wav", -6, "迷宫战斗主角受伤反馈。", ["scripts/maze/capture_flow.gd"])
	_add(rows, "capture_throw", "捕获抛网", "音效", "sfx/capture_throw.wav", -6, "新捕获开始时抛网；恢复捕获不补播。", ["scripts/ui/components/capture_attempt_modal.gd"])
	_add(rows, "capture_struggle", "捕获挣扎", "音效", "sfx/capture_struggle.wav", -6, "捕获过程挣扎循环，关闭或失焦停止。", ["scripts/ui/components/capture_attempt_modal.gd"])
	_add(rows, "capture_press_continuous", "捕获按键叮声", "音效", "sfx/capture_ding_01.wav", -6, "每次有效J播放短ding，三种音高轮换，最多两声叠加；沿用原镇压音量配置键。", ["scripts/ui/components/capture_attempt_modal.gd"])
	_add(rows, "capture_flash", "捕获闪光", "音效", "sfx/capture_flash.wav", -6, "捕获窗口的闪光阶段反馈。", ["scripts/ui/components/capture_attempt_modal.gd"])
	_add(rows, "capture_success", "捕获成功／探索奖励", "音效", "sfx/capture_success.wav", -16, "捕获或战斗胜利、宝箱与挖掘奖励保存成功后提示。", ["scripts/maze/capture_flow.gd", "scripts/maze/maze_entry.gd", "scripts/ui/components/capture_dialog.gd"])
	_add(rows, "capture_failure", "捕获失败提示", "音效", "sfx/failure_user.wav", -6, "捕获失败反馈；使用 failure_user 素材，与通用失败音量独立。", ["scripts/ui/components/capture_dialog.gd"])
	_add(rows, "salt_dull", "盐晶无效敲击", "音效", "", 0, "不符合开采条件时的短促敲击；声音由代码生成。", ["scripts/maze/salt_crystal_visual.gd"])
	for id in ["yaya_home_hint", "yaya_maze_hint", "capture_press"]:
		_add(rows, id, {"yaya_home_hint":"芽芽冒险者之家提示", "yaya_maze_hint":"芽芽迷宫提示", "capture_press":"旧捕获单次镇压"}[id], "音效", "sfx/"+id+".wav", -6, "已在全局管理器登记，当前未发现生产播放调用。", ["scripts/audio/game_audio.gd"], "仅登记")
	for file in ["capture_failure.wav", "capture_press_01.wav", "capture_press_02.wav", "capture_press_03.wav", "cooking_stove.ogg", "S06.wav", "S08.wav", "S18.wav", "S19.wav", "character/sprint_start.wav"]:
		_add(rows, "unused_"+file.get_file().get_basename(), "备用素材 · "+file.get_file(), "音效", "sfx/"+file, -6, "未发现游戏代码直接引用，仅供试听。调音不会接入新的游戏事件。", [], "未发现引用")
	return rows

static func _add(rows: Array[Dictionary], id: String, title: String, category: String, path: String, db: float, usage: String, sources: Array, status: String = "使用中") -> void:
	rows.append({"id":id, "title":title, "category":category, "path":"res://assets/audio/"+path if not path.is_empty() else "", "db":db, "usage":usage, "sources":sources, "status":status})

static func salt_stream() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(2205 * 2)
	for i in 2205:
		bytes.encode_s16(i*2, int(sin(i*TAU*170.0/22050)*exp(-float(i)/420)*1800))
	wav.data = bytes
	return wav
