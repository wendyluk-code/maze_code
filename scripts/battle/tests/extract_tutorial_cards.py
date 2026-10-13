"""只读提取用户表格，生成本关数值快照；不读取旧 catalog。

用法：python scripts/battle/tests/extract_tutorial_cards.py --source <原表路径>
默认只校验，不写入。显式 --write 才更新快照，并保留后续美术插画引用。
"""
import argparse
import hashlib
import json
from pathlib import Path

import openpyxl

IDS = {
    "芽芽": "yaya", "铁山": "tieshan", "恢复": "yaya_restore",
    "魔力一击": "yaya_magic_hit", "魔力之风": "yaya_magic_wind",
    "治愈之风": "yaya_heal_wind", "强力": "tieshan_strong",
    "斧冲": "tieshan_axe", "守护": "tieshan_guard", "坚守不移": "tieshan_hold",
    "史莱姆": "slime", "小小史莱姆": "small_slime",
}


def number(value, default=0):
    try:
        return int(value)
    except (ValueError, TypeError):
        return default


def extract(source):
    # 原件的工作表尺寸缓存不完整；普通只读使用（不保存）读取实际单元格。
    workbook = openpyxl.load_workbook(source, data_only=True)
    records = {}
    for sheet in workbook:
        for row_number, row in enumerate(sheet.values, 1):
            if len(row) < 9 or row[2] not in IDS:
                continue
            role = row[1] == "角色牌"
            card_id = IDS[row[2]]
            if card_id in records:
                raise ValueError(f"来源重复：{card_id}")
            records[card_id] = {
                "id": card_id, "character_name": row[0], "title": row[2],
                "card_type": row[1], "effect": row[3], "attack": number(row[4]),
                "health": number(row[5]), "shield": number(row[6]),
                "satiety_max": number(row[7], -1) if role else -1,
                "satiety_cost": 0 if role else abs(number(row[7])),
                "mana_enabled": role and number(row[8], -1) >= 0,
                "mana_initial": number(row[8], -1) if role else -1,
                "mana_cost": 0 if role else abs(number(row[8])),
                "cost": "" if role else "1", "is_role_card": role,
                "faction": "sprout" if row[0] == "芽芽" else ("tieshan" if row[0] == "铁山" else "monster"),
                "source_sheet": sheet.title, "source_row": row_number,
            }
            if card_id == "tieshan_guard":
                attack_text = str(row[4])
                if not attack_text.startswith("+3"):
                    raise ValueError("守护条件加攻单元格变化，须重新确认规则")
                records[card_id].update(conditional_attack=3, source_attack_text=attack_text)
    workbook.close()
    if set(records) != set(IDS.values()):
        raise ValueError("本关12项来源记录不完整")
    return {
        "schema_version": 1,
        "source": {"file": source.name, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                   "mana_max": 10, "rest_satiety": 2},
        "cards": records,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    target = Path(__file__).resolve().parents[3] / "data/battle/tutorial_cards.json"
    current = json.loads(target.read_text(encoding="utf-8"))
    extracted = extract(args.source)
    for card_id, card in extracted["cards"].items():
        if "illustration_path" in current["cards"][card_id]:
            card["illustration_path"] = current["cards"][card_id]["illustration_path"]
    if args.write:
        target.write_text(json.dumps(extracted, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    elif extracted != current:
        raise SystemExit("原表与本关快照不一致，请审查来源/规则变化")
    print("CARD_TUTORIAL_SOURCE 12项数据一致 SHA256=" + extracted["source"]["sha256"])


if __name__ == "__main__":
    main()
