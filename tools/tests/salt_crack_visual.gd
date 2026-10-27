extends "res://tools/tests/map04_flow.gd"

func _combat_scene() -> void:
    await _new_scene()
    maze.capture_flow.set_process(false)
    calm()
    _check(Run.change_region(sm,"salt_pool",SR.SPAWN).success,"进入实际盐池")
    await _close_scene()
    sm.data.erase(Crystal.KEY)
    sm.save()
    maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
    get_tree().root.add_child(maze)
    get_tree().current_scene=maze
    await get_tree().create_timer(0.5).timeout
    var flow=maze.capture_flow
    flow.set_process(false)
    flow.window_focused=true
    var visual=flow.crystal_visual
    _check(visual.get_index()<maze.player.get_index(),"裂纹层在人物之前")
    _check(visual.effect_count==0,"入场不震动")
    sm.data[Run.KEY].combat.attack=1
    var points=[Vector2(505,430),Vector2(1140,380)]
    for index in 2:
        maze.player.position=points[index]
        maze.camera.snap_to_target()
        for stage in 3:
            maze.player.position=points[index]
            maze.camera.snap_to_target()
            flow.window_focused=true
            calm()
            for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="return"
            sm.data[Run.KEY].combat.cooldown=0.0
            flow._process(0)
            await _send_key(KEY_2)
            var motion:=InputEventMouseMotion.new()
            motion.position=maze.get_viewport().get_canvas_transform()*maze.player.position
            get_viewport().push_input(motion)
            await get_tree().process_frame
            print("PRE ",index," ",stage," paused=",flow.combat_paused()," focus=",flow.window_focused," retry=",flow.save_retry_delay," busy=",flow.busy," mapbusy=",maze._busy," physics=",maze.player.is_physics_processing()," hp=",sm.data[Run.KEY].combat.hp," throws=",sm.data[Run.KEY].combat.throws)
            await mouse_at(Vector2(522,365) if index==0 else Vector2(1159,311))
            for tick in 10:
                flow._process(0.05)
                if maze._busy: break
            print("POST ",visual.counts," throws=",sm.data[Run.KEY].combat.throws," pending=",sm.data[Run.KEY].pending)
            _check(visual.counts[index]==stage+1,"真实土攻击更新裂纹 %s/%s"%[index,stage])
            _check(maze.camera.mining_shake>0,"成功命中触发短震")
            await get_tree().create_timer(0.12).timeout
            _check(visual.faces[index].material.get_shader_parameter("reveal")!=null and visual.faces[index].material.get_shader_parameter("reveal")<1.0,"裂纹逐渐展开")
            if stage==0: await _capture_image("spread_"+str(index))
            await get_tree().create_timer(0.5).timeout
            _check(maze.loot_modal.visible and maze._busy,"岩盐复用采集弹窗并锁输入")
            _check(maze.camera.mining_shake==0 and maze.camera.offset.length()<0.01,"震动结束归零")
            if index==0 and stage==0: await _capture_image("salt_reward")
            maze.loot_modal.close_modal()
            await get_tree().process_frame
            _check(not maze._busy and not maze.player.input_locked,"收下后恢复输入")
            for offset in [Vector2(85,0),Vector2(-85,0),Vector2(0,65),Vector2(65,30)]:
                if SR.is_walkable(points[index]+offset):
                    maze.player.position=points[index]+offset
                    break
            _check(SR.is_walkable(maze.player.position),"截图站位在合法道路")
            await get_tree().create_timer(0.25).timeout
            await _capture_image("crystal_"+str(index)+"_stage_"+str(stage+1))
        maze.player.position=points[index]
        var effects: int=visual.effect_count
        calm()
        sm.data[Run.KEY].combat.cooldown=0.0
        await mouse_at(Vector2(522,365) if index==0 else Vector2(1159,311))
        flow._process(0.2)
        _check(visual.effect_count==effects and not maze.loot_modal.visible,"耗尽命中不震动不发奖励")
    _check(sm.data[Run.KEY].bag.get("rock_salt",0)==6,"两簇各三份无重复发奖")
    var effects: int=visual.effect_count
    visual.feedback(["dull"])
    _check(visual.effect_count==effects,"非土不产生裂纹震动")
    var saved_state: Dictionary=sm.data.duplicate(true)
    sm.data.erase(Crystal.KEY)
    visual._sync(false)
    maze.player.position=points[0]
    calm()
    sm.data[Run.KEY].combat.cooldown=0.0
    _check(Run.combat_attack(sm,points[0],Vector2.UP).success,"建立保存失败实验的真实土攻击")
    var save_path: String=sm._active_save_path
    var before: Dictionary=sm.data.duplicate(true)
    sm._active_save_path=""
    var failed:=Run.combat_tick(sm,points[0],0.25)
    _check(not failed.success and sm.data==before,"保存失败盐与裂纹次数一起回滚")
    _check(not failed.has("mining_feedback") and visual.effect_count==effects,"失败事务无视觉反馈")
    sm._active_save_path=save_path
    sm.data=saved_state
    visual._sync(false)
    _check(visual.counts==[3,3] and visual.effect_count==effects,"静态恢复两簇裂纹不重播")
    _check(sm.save(),"保存裂纹状态")
    sm.load_data()
    visual._sync(false)
    _check(visual.effect_count==effects,"读档不重播动画")
    maze.camera.set_roar_shake(0.3)
    maze.camera.shake_mining()
    maze.camera._process(0.05)
    var offset_before: Vector2=maze.camera.offset
    maze.camera.set_roar_shake(0)
    _check(maze.camera.offset==offset_before,"战斗更新不会清掉正在播放的矿震")
    maze.camera.set_roar_shake(0.3)
    _check(maze.camera.roar_shake==0.3 and maze.camera.mining_shake>0,"矿震不覆盖怪物震屏")
    maze.camera.set_roar_shake(0)
    maze.camera._process(0.5)
    _check(maze.camera.offset==Vector2.ZERO,"叠加震动最终归零")
    await _close_scene()
