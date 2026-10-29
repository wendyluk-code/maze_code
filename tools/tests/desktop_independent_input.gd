extends "res://tools/tests/ch1_qte_03_input.gd"
## 不通过操作系统鼠标完成悬停、点击与键盘输入；可无窗口运行。
func _run() -> void:
	get_window().size=Vector2i(800,600)
	_check(_verify_isolation(),"独立存档目录")
	if _arg("--normal-config=")=="true":
		_check(not ProjectSettings.get_setting_with_override("display/window/size/no_focus"),"正常启动不启用测试专用不可聚焦设置")
		_write_report()
		return
	_check(ProjectSettings.get_setting_with_override("display/window/size/no_focus"),"测试专用配置在创建窗口前禁止获取焦点")
	_check(has_method("_move_mouse"),"共用助手提供内部鼠标移动")
	if failures==0:
		var button:=Button.new()
		button.text="内部输入验证"
		button.position=Vector2(260,180)
		button.size=Vector2(200,70)
		add_child(button)
		var hovered: Array=[]
		var clicked: Array=[]
		button.mouse_entered.connect(func(): hovered.append(true))
		button.pressed.connect(func(): clicked.append(true))
		await get_tree().process_frame
		await call("_move_mouse",Vector2(20,20))
		await _click(button)
		_check(not hovered.is_empty(),"内部鼠标事件经过真实悬停处理")
		_check(clicked.size()==1,"内部按下和松开只激活一次按钮")
		_check(button.is_hovered(),"无需真实桌面鼠标也能保留悬停状态")
		if DisplayServer.get_name()!="headless":
			_check(get_window().unfocusable,"原生测试窗口保留不可聚焦属性")
			_check(not get_window().has_focus(),"原生测试窗口未获取桌面焦点")
		button.grab_focus()
		await _send_key(KEY_SPACE)
		_check(clicked.size()==2,"内部键盘输入可激活真实按钮")
	_write_report()

func _write_report() -> void:
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"headless":DisplayServer.get_name()=="headless","startup_no_focus":ProjectSettings.get_setting_with_override("display/window/size/no_focus")},"	"))
	get_tree().quit(1 if failures else 0)
