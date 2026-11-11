# 顾客透明五官层（2026-11-04）

已交付一张透明图集与可复用组件。三位普通冒险者共用失落、不耐烦、生气、疑惑四种五官；原角色贴图不改写，局部皮肤取样着色器只遮除原眉、嘴，再叠加透明眉毛和嘴巴；眼睛和瞳孔直接保留原角色像素，不使用图集中的眼睛区域。气泡预览只保留文字。

## 使用

scripts/ui/components/customer_expression.gd 提供 apply(actor, customer_id, kind) 与 clear(actor)。kind 为 sad（失落）、impatient（不耐烦）、angry（生气）、confused（疑惑）。适配 mage、dingdang、half_elf 的384像素动作格，第0行第0列站姿、第1行第0列坐姿。其他动作拒绝叠加；切帧或翻转变化自动移除，恢复调用前材质。反馈期间调用方应保持对应静止帧，改变姿态后重新调用，避免正常眨眼覆盖反馈。

该组件已在目标工作区的独立Godot预览中实际使用；尚未绑定正式经营的超时、交错料理、错误冰度等触发事件。接单流程、惩罚数值和离场流程未修改。未来更换人物素材或帧布局时须重新校准，不应直接用于铁山或其他剧情角色。

## 素材

assets/ui/customer_expressions/features.png 为唯一四格透明图集，内置imagegen生成，原件保留于生成目录exec-2dc42f16-b301-4cc8-9c89-901e191c60e8.png。运行时仅取样眉、嘴区域，三位顾客只配置各自的五官位置。不为每个角色生成图集。
提示词：横向四个等宽透明单元，依次失落、不耐烦、生气、疑惑；仅眉眼嘴，无脸、皮肤、头发、鼻子、身体、文字或装饰；深暖棕色细线、柔和棕色眼睛、暗珊瑚色小嘴，统一尺寸间距，手绘水彩Q版风格。失落内眉上抬、低垂眼、下垂嘴；不耐烦平压眉、半垂眼、平嘴；生气内压眉、眯眼、下压嘴；疑惑单眉抬高、圆眼、小幅张嘴。

## 验收

隔离运行 tools/tests/customer_expression_fit.tscn，145项通过：三人×四表情×两种姿态，透明背景、原图保留、移除恢复、镜像、动作切换清除及不支持动作拒绝。
证据：output/customer_expression_fit_verified/standing_matrix.png 和 seated_matrix.png。
六种状态实际组件合成：tools/tests/customer_feedback_preview.tscn；截图 output/customer_face_layers_v1/six_states.png。
正式存档指纹未变化。只有系统证书读取环境警告，无脚本或资源错误。此验收不代表经营事件和离场闭环已经接入。

瞳孔样式修正：用户要求与初始状态一致，因此停用新画的眼睛，保留原图中的瞳孔、眼白和高光。最新实际六状态截图：output/customer_original_eyes_preview/six_states.png。头顶动效：customer_emotion_mark.gd 提供混乱线、发怒、问号三种实时绘制动画。当前接入六状态预览，人物保留原始瞳孔；混乱线用于候客超时、甘露水超时与水不达标，发怒用于料理超时与交错料理，问号用于未点水收到水。GIF由实际Godot渲染帧编码，见output/customer_emotion_motion_final/six_states.gif，尚未绑定正式经营触发。
动效改稿：混乱线改为近圆形毛线团，轮廓稳定、内部环线扭动；三种标记统一移到头发右上侧，与发丝重叠。最新实际动画：output/customer_emotion_hair_final/six_states.gif。
正式反馈接入：customer_feedback统一显示2.2秒文案、人物表情与头发动效。customer_flow接入料理超时、错误料理、变质水离场；ganlu_controller接入未点水问号及不达标水反馈。反馈期间暂停眨眼替换并隐藏订单气泡，结束后恢复。实际餐厅专项26项通过，output/customer_feedback_live_visible。候客超时与饮水超时只提供表现映射，原经营服务尚未产生这些离场事件；三座地图及新惩罚规则尚未接入。旧经营回归存在冰度边界、返回字段及交互时序失败，日志output/customer_feedback_integrated，不宣称全量回归通过。

REST-3正式触发接入：候客超时、等水超时、料理超时、错料理、不达标水、未点水误上水全部复用原六状态映射。候客采用站姿，已入座客采用坐姿，原瞳孔和头发动效保留。文字气泡单独避开屏幕顶部与营业牌，不移动表情和动效。反馈后沿路径走到出口才移除；不达标水与误上水继续等料理。验收入口为 tools/tests/restaurant_three_seat.tscn；规则及实际交付边界见 restaurant_day_cycle.md。
