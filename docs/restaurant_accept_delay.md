# 接单后等待与营业暂停入口预览

2026-11-05：F:/maze_code普通经营成功接单时，将现有arrival_left重新设为随机2～5秒。与接单同一次保存，失败全量回滚，读档保持剩余值；首章/非cycle订单不受影响。空位、剩余菜单和营业状态仍决定是否实际生成下一客。首次开业立即来客及未接单期间规则保持原实现。

主目录restaurant_accept_delay.tscn使用现有隔离运行器，output/restaurant_accept_delay：54项通过，正式存档不变。覆盖旧计时为0/12秒、失败回滚、接单同帧/等待期不来客、读档不重置、结束等待来客、真实E接单后1.5秒无下一客。

UI仅制作预览，尚未接入生产：restaurant_pause_preview.tscn复用destination_confirmation和营业牌，在场景中将结束文字替换为原OpenMenu位置的暂停符号；问句仅“确定结束今日营业？”，保留“继续营业/结束营业”两按钮并居中。未修改生产restaurant_day_sign或destination_confirmation。output/restaurant_pause_preview双尺寸23项通过，正式存档不变。待用户审图后再接入这部分显示。

两轮仅系统证书环境警告。新增接单入口或改变经营计时暂停规则时，重验接单原子保存及等待边界；UI预览不作为生产接入完成证据。
