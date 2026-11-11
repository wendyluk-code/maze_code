extends "res://tools/tests/yf04_flow.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	var queue: Array[Vector2]=[Sim.Terrain.SPAWN]
	var seen: Dictionary={Sim.Terrain.SPAWN:true}
	var crossings: Array[Vector2]=[]
	var water: Array[Vector2]=[]
	var cursor:=0
	while cursor<queue.size():
		var p: Vector2=queue[cursor]
		cursor+=1
		# 东侧返程石阵边缘的水像素不属于进入西侧水池的路线。
		if p.x<Sim.Terrain.SPAWN.x and Sim.Terrain.terrain_multiplier(p)<1.0: water.append(p)
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]:
			var next:=Sim.Terrain.move_on_road(p,direction*2.0)
			if seen.has(next): continue
			seen[next]=true
			if Sim.Site.should_trigger(next):
				crossings.append(next)
			else: queue.append(next)
	_check(not crossings.is_empty(),"入口通道可到达剧情触发线")
	_check(water.is_empty(),"按真实地形穷举入口八向绕行，向西进入水池前必经触发线",{"reachable":queue.size(),"water":water.slice(0,8)})
	for id in Sim.POSITIONS:
		_check(Sim.Terrain.is_walkable(Sim.POSITIONS[id]),"新站位脚底合法："+id)
	# 分别从通道上沿、中间、下沿跨线，使用真实移动规则与场景剧情处理。
	crossings.sort_custom(func(a,b): return a.y<b.y)
	if not crossings.is_empty():
		for index in [0,crossings.size()/2,crossings.size()-1]:
			setup_trip(18.0)
			await open_map()
			var e=maze.yf_encounter
			var frame: int=e.idle.frame
			await get_tree().create_timer(0.4).timeout
			_check(e.idle.visible and e.idle.is_playing() and e.idle.frame!=frame,"接近前聊天帧实际推进")
			maze.player.position=crossings[index]
			await get_tree().create_timer(0.1).timeout
			_check(e.phase=="intro" and not e.idle.visible and not e.idle.is_playing() and e.actors.yufeng.visible and e.actors.salia.visible,"跨入口线立即停聊并看向主角："+str(index))
			maze.queue_free()
			await get_tree().process_frame
			sm.load_data()
			await open_map()
			_check(maze.yf_encounter.phase=="intro" and not maze.yf_encounter.idle.visible,"对话中重进不重新聊天")
			maze.queue_free()
			await get_tree().process_frame
	var f:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
