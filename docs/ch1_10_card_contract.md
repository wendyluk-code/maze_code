# CH1-10 芽芽／铁山初始卡组契约

首章准备同行状态仍由 `SaveManager.is_ready_to_depart()` 判定。玩家在准备面板点击“查看芽芽与铁山卡组”时，`SaveManager.unlock_ch1_cards()` 原子写入 `chapter_1_departure.cards`，不推进教程步骤、不标记章节完成；重复查看是幂等操作。

卡组 schema 为：

```json
{
  "status": "unlocked",
  "unlocked": true,
  "card_ids": ["yaya_01", "...", "tieshan_08"],
  "deck_ids": ["yaya_01", "...", "tieshan_08"],
  "characters": {
    "yaya": {"attack": 2, "max_hp": 5},
    "tieshan": {"attack": 1, "max_hp": 6}
  }
}
```

旧存档若缺少卡牌字段，或仍使用 CH1-09 的 `{status: "pending_content", unlocked: false, card_ids: []}`，读取时安全归一化为 pending schema；不会自动解锁或补发奖励。正式解锁只接受完整 16 个 ID，保存失败回滚内存状态。

`SproutCardData.formal_set()` 提供 16 张正式设计牌，各角色 7 张 R 与 1 张 SR。方案 B 使用统一卡框、中文文字和现有芽芽／铁山肖像，不生成独立卡面素材。规则输入尚未实战平衡，验收只证明字段和最小教学结算规则，不宣称数值平衡。

`CardRules` 是后续战斗接缝：当前覆盖治疗上限与不复活、护甲先于生命、铁山回合开始清甲、入场不攻击、站稳首次入场、抽 2 回牌库底、减伤先于护甲及最小四张教学牌结算；敌人 AI、抽卡经济和完整迷宫战斗不在本票。
