# CH1-12 铁山连续动作资源说明

- `tieshan_collapse_sheet.png`：4×2 原始动作表。
- `collapse_00.png`–`collapse_07.png`：统一脚底到 y=448 的 480×480 帧。
- `tieshan_collapse.tres`：Godot `SpriteFrames`，8 帧、非循环；顺序为站立、屈膝、深蹲、跪倒、前倾、四肢着地、低头、趴下。
- `guest_placeholder.tscn` 使用 `AnimatedSprite2D`，站立可见高度约为主角 1.00 倍；根节点 `Vector2(910,198)` 固定为地面锚点。
- `tieshan_collapse_preview.gif` 由 CH1-04 真实餐厅捕获帧编码。

验收证据：`tools/tests/ch1_12_evidence/accepted/ch1_04-runner-summary.json`、`CH1-04-tieshan-dialog.png`、`motion_*.png`。
