# 游戏音效来源

2026-11-09：迷宫空格、1/2/3/4与Tab实际切换技能后统一播放interact。重复选择当前技能、长按echo、输入锁及保存失败不响。公共capture_flow入口覆盖迷宫技能切换；专项`output/skill_keys_audio_r1`在实际迷宫中34项通过，正式存档未变，仅系统证书环境告警。

最新交付音规则：按用户要求取消正确料理的food_enjoy（wow）和正确甘露水的water_enjoy（啊声），包含铁山首单；成功交付仅播放原serve_correct。两份素材保留作来源记录，不再自动触发。下方追加赞叹的历史记录不再代表当前行为。

## 当前捕获J短叮声（2026-11-06）

用户确认试听后接入`output/capture_ding_review/ding_01/02/03.wav`，对应`capture_ding_01/02/03.wav`，约0.140/0.132/0.148秒。本地Stable Audio生成基础音，经裁剪、淡化与轻微音高变化形成三种短音。每次有效J按1→2→3轮换，两个声部交替，极快输入只替换较早声部，不排队；停按自然收尾，完成、失焦、隐藏和离场立即停止。保留挣扎与闪光提示。沿用原`capture_press_continuous`混音配置键和默认-6 dB，调音目录名称已改为“捕获按键叮声”。下方历史三段摩擦循环及600ms停播规则不再用于当前J行为。

目标工作区验收`output/capture_ding_integrated_r1`57项通过，正式存档未变，无脚本错误，仅系统证书环境告警。覆盖三音轮换、快速叠接、长按去重、停按/失焦、闪光及结算。修改捕获输入、声部或混音绑定后复验`capture_process_audio.tscn`。

甘露水倒水音效 `ganlu_pour.ogg` 来自用户附件 `preview (7).m4a`，仅转换格式。成功开始倒水后循环播放（-6 dB），松手、失去窗口焦点、隐藏或离场停止。达标水量结果弹窗出现时复用 `cooking_complete`（-16 dB）；“水太少了”弹窗出现时复用上错料理的 `failure`，沿用混音音量，每次结果仅一次，重新倒水按钮和停留不重播；过量维持无结果音。端起保存重试不重复播放。

用户于 2026-11-05 确认接入首批本地模型生成的裁切版，来自 `output/audio_batch_20261105/clips/`，未重新生成或进一步截短。

| 文件 | 触发 |
| --- | --- |
| interaction_click.wav | 用户提供 preview.m4a 转换为 WAV；有效 E 交互及鼠标左、右、中键按下 |
| S06.wav | 旧交互音效留档，已由 interaction_click.wav 替换 |
| serve_correct.wav | 用户附件 preview (5).m4a；正确料理或达标水交付并保存成功，沿用 -6 dB |
| S08.wav | 旧正确交付音效留档，不再播放 |
| capture_success.wav | 用户提供 preview (2).m4a 转换为 WAV；捕获成功结果弹窗显示 |
| S18.wav | 旧捕获成功音效留档，已由 capture_success.wav 替换 |
| capture_failure.wav | 旧 preview (3).m4a 留档，当前由 failure_user.wav 替换 |
| S19.wav | 旧捕获失败音效留档，已由 capture_failure.wav 替换 |
| cooking_stove.ogg | 本地 Stable Audio 3 生成温和冒泡与轻柴火声；原6秒素材以0.5秒交叉淡化处理为5.5秒循环，烹饪成功开火后播放，-20 dB |
| cooking_user.ogg | 用户附件 preview (6).m4a 完整转换，无音量处理；替换 cooking_stove.ogg，烹饪中以 0 dB 循环播放 |

烹饪完成使用独立 `cooking_complete` 播放 `capture_success.wav`，-16 dB，比原来降低10 dB；所有捕获成功素材提示音统一为 -16 dB。

生成模型为本地 Stable Audio 3 Medium，原提示词和音频检查见该批次 manifest.json 与 checks.json。播放管理在 scripts/audio/game_audio.gd。资源接入不代表用户已经认可全部声音的主观听感。

捕获动作音：`capture_throw.wav` 来自 `preview (9).m4a`（0.664秒），`capture_press.wav` 来自 `preview (10).m4a`（1.168秒）。48kHz PCM16转换，不裁剪、不归一化，使用默认 -6 dB。抛网仅在新捕获开始时播放，恢复进度不播放；镇压阶段J有效按下播放，键盘重复和暂停不触发。宝箱、挖掘物品领取成功弹窗与战斗胜利弹窗复用 `capture_success`，统一 -16 dB。

2026-11-05：`character/hit_01.wav` 至 `hit_03.wav` 原样复制已确认试听 `output/sfx_review_20261105/clips/`，怪物实际扣血且事务成功后按1→2→3循环。`character/hero_hurt.wav` 来自 preview (12).m4a，主角实际扣血时触发；`customer_arrival.wav` 来自 preview (13).m4a，完整6.06秒，到前台的状态提交成功时播放。`failure_user.wav` 来自 preview (14).m4a，供经营失败、捕获失败、战斗失败与探索失败共用。三附件完整转换48kHz PCM16，不裁剪、不归一化；上述新增播放器沿用默认 -6 dB。成功音仍为 -16 dB，出招音仍为 -20 dB。

营业完成：business_complete.wav 来自 preview (15).m4a，完整3.156秒，48kHz PCM16，默认 -6 dB。营业结算界面首次出现时触发，同一运行会话内按存档路径及营业天数去重；刷新或返回同一日结算不重播，歇业不响。

首章音效：party_join.wav 来自 preview (16).m4a（1.13秒，-16 dB），替换芽芽/铁山入队弹窗的烹饪完成提示；yaya_home_hint.wav 来自 preview (17).m4a（1.982秒），yaya_maze_hint.wav 来自 preview (18).m4a（2.994秒）。按用户最新要求，两句入口教学已停用这两条专属提示音，素材保留；对白打字音和E点击音不变。三份附件完整转48kHz PCM16，不裁切、不归一化。

对白循环音 dialogue_typing.ogg 来自 preview (19).m4a，完整转为Ogg Vorbis，不裁剪、不归一化。每个通用对白框持有独立播放器，默认 -6 dB，仅在当前句逐字显示期间循环；句子显示完、E/鼠标补全、隐藏、关闭、失焦及离场停止。下一句开始恢复，剧情专属提示音保留。

捕获过程更新（2026-11-06）：capture_struggle.wav 为附件20完整6.347秒，撒网动画结束、网完全罩住魔物（restrain阶段）后开始循环，满进度停止。附件21按0.03–1.93、2.60–4.82、5.73–7.66秒裁为 capture_press_01/02/03.wav，切口各5ms淡化。有效J按下刷新0.3秒续播期限，不打断当前段、不排队；段结束且仍在连按时启动下一段，超时立即停，重按从下一段开始。capture_flash.wav 为附件22完整1.831秒，满进度闪光时播放，音效与至少0.55秒闪光均完成后才发出结算请求。所有新过程播放器为 -6 dB，关闭/失焦/离场停止，原结果音保留。旧capture_press.wav留档不再由J触发。

2026-11-06挣扎音起点修正：throw阶段（前1.1秒撒网动画）不播放，切入restrain、网完全罩住魔物时开始；恢复restrain/suppress阶段也从该阶段播放。J音与满进度停止、闪光结算顺序保持不变。

2026-11-06连续J修正：三段裁短首尾静音，各接缝含3→1使用约35ms交叉淡化，合成capture_press_continuous.wav（5.497秒）。单一AudioStreamWAV底层循环，不再用finished事件逐段启动；播放器位置判断下一段。后续修复将未按J的停止期限从0.3秒改为0.6秒，避免人手连按节奏波动导致中途截断；重按从下一段起点继续，关闭、失焦和完成仍立即停止。对白逐字循环音由-6 dB提升为+2 dB；其他剧情音不变。

本次复现与验证：素材10ms窗口无持续40ms以上低于-50dB的区域；220–450ms间隔连按逐帧检查，旧逻辑出现33帧停播，修复后0帧。`output/capture_j_gap_after` 49项功能检查通过且无脚本错误，但正式存档指纹在运行期间变化，最终隔离验收未完成，未回写正式存档。正式游戏退出后重跑`tools/tests/capture_process_audio.tscn`确认；这些检查不代表完成主观听审。

顾客落座：customer_seated.wav 原样复制 output/diner_audio_review_20261106/sit.wav（本地模型生成、用户确认试听），播放增益 -1 dB，比默认 -6 dB 提高5 dB。顾客seating→waiting保存成功时播放一次，已在waiting状态的刷新/重入不补播；保存失败不响，成功重试响一次。Bravo和嗯声未接入。

正确交付追加音：food_enjoy.wav来自preview (23).m4a（1.323秒），water_enjoy.wav来自preview (24).m4a（1.3秒），完整转48kHz PCM16，不归一化。料理赞叹按最新确认以-6 dB播放，喝水赞叹保持0 dB。原serve_correct继续使用-6 dB，finished后接对应新音；连续交付完整序列排队，退出场景清空。覆盖普通上菜、甘露水与铁山首单。
