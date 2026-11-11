# 餐厅背景音乐

## 全迷宫探索背景音乐

`maze_exploration.ogg` 来自用户确认的 `output/maze_exploration_3min_v4/maze_exploration_active_128bpm_180s.wav`，只转换为 Vorbis 质量 6，保留三分钟原曲及末尾渐隐。由 `GameAudio` 全局播放器以 -12 dB 循环播放。

正式迷宫地图共用 `maze_entry` 场景组，包括入口、苔池、盐池、分水庭。目标场景就绪后按场景组判断：首次进入迷宫开始播放，迷宫之间切换保持同一播放器和播放位置，转场空窗不停止；进入非迷宫场景停止。离开后再次探索从头播放。无存档字段变动，场景音乐与点击、结果音独立。新增地图沿用该场景组即可共享音乐。验收入口 `tools/tests/maze_bgm.tscn`。

## 开始界面背景音乐

`start_screen.mp3` 为用户提供的 `61ca6b5a-0de4-4cde-aa87-0505877805b0.mp3` 原文件副本，字节一致，未转换或裁切。开始界面的 `StartScreenBGM` 以 -12 dB 自动循环播放；打开和关闭存档选择窗口不中断，进入游戏后随开始界面释放并停止，不与餐厅音乐叠播。验收入口为 `tools/tests/start_screen_bgm.tscn`。

## 餐厅音乐

`M01_restaurant.ogg` 来自用户于 2026-11-05 指定的 `output/M01_3min_original/M01_original_melody_180s.wav`，仅转换为 Vorbis 格式（质量 6），未裁切、改变旋律或重新生成。

正式餐厅场景的 `RestaurantBGM` 播放器进入场景后自动播放，音量 -12 dB，沿用 Master 总线。180 秒原曲包含末尾 10 秒渐隐，完整播放后从头循环，不额外拼接无缝过渡。餐厅界面和暂停期间继续播放，离开餐厅时随场景释放并停止；返回时从头播放。点击音和结果音使用独立播放器，不中断背景音乐。不新增存档字段。

验收入口：`tools/tests/restaurant_bgm.tscn`。更换资源或场景生命周期后，重新验证入场、曲尾循环、离场静音、返回无叠播和实际混音输出。
