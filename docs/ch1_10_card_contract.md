# CH1-10 芽芽／铁山初始卡组契约

> 保留范围：入队卡牌解锁、展示数据与旧存档兼容。旧战斗规则及独立制卡工具已移除，后续玩法需重新确认。

首章准备同行状态仍由 `SaveManager.is_ready_to_depart()` 判定。玩家在准备面板点击“查看芽芽与铁山卡组”时，`SaveManager.unlock_ch1_cards()` 原子写入 `chapter_1_departure.cards`，不推进教程步骤、不标记章节完成；重复查看是幂等操作。

卡组存档结构为：

```json
{
  "status": "unlocked",
  "unlocked": true,
  "card_ids": ["yaya_01", "...", "tieshan_08"],
  "deck_ids": ["yaya_01", "...", "tieshan_08"],
  "characters": {
    "yaya": {"attack": 2, "max_hp": 4},
    "tieshan": {"attack": 1, "max_hp": 5}
  }
}
```

旧存档若缺少卡牌字段，或仍使用 CH1-09 的 `{status: "pending_content", unlocked: false, card_ids: []}`，读取时安全归一化为 待解锁结构；不会自动解锁或补发奖励。正式解锁只接受完整 16 个 ID，保存失败回滚内存状态。

`SproutCardData.formal_set()` 提供 16 张正式设计牌，各角色 7 张 R 与 1 张 SR。方案 B 使用统一卡框、中文文字和现有芽芽／铁山肖像，不生成独立卡面素材。规则输入尚未实战平衡，保留数据用于当前显示，不据此声明存在战斗结算或数值平衡。

角色牌数据仍由 `data/cards/catalog.json` 的 `is_role_card`（角色牌标记）条目登记；入队展示另外读取 `data/cards/xlsx_remaining_cards.json` 与 `data/battle/tutorial_art.json`。这些保留文件只支持当前显示和存档，不表示卡牌战斗仍可进入。原始设计表与旧战斗规则资料已按用户确认删除。
