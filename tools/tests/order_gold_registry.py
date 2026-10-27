"""验证金币奖励沿用任务定义 JSON 列持久化；比较既有服务端测试的基线失败。"""
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "server"))
import quest_registry as registry
import test_quest_registry as existing_tests

OUTPUT = ROOT / "output" / "order_gold" / "registry"
OUTPUT.mkdir(parents=True, exist_ok=True)
baseline_path = OUTPUT / "baseline_catalog.json"
baseline_path.write_bytes(subprocess.check_output([
    "git", "-C", str(ROOT), "show",
    "04b509913793be8f350a065947b3d6369a79adaa:data/quests/catalog.json",
]))

failures = {}
for name, source in [("baseline", baseline_path), ("current", registry.DEFAULT_CATALOG)]:
    existing_tests.DEFAULT_CATALOG = source
    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromModule(existing_tests)
    )
    (OUTPUT / (name + "_existing_tests.log")).write_text(stream.getvalue(), encoding="utf-8")
    assert not result.errors, stream.getvalue()
    failures[name] = sorted(test.id() for test, _ in result.failures)
assert failures["baseline"] == failures["current"], failures

source = registry.DEFAULT_CATALOG
database = OUTPUT / "quests.sqlite3"
first = registry.import_catalog(database, source)
assert first == registry.read_catalog(database) == registry.import_catalog(database, source)
for quest_id in ["chapter_1_first_order", "restaurant_customer_order"]:
    record = next(item for item in first["quests"] if item["quest_id"] == quest_id)
    reward = record["completion_condition"]["gold_reward"]
    assert reward == dict(recipe_id="salt_grilled_rockmane", amount=5,
                        config_field="order_gold", min=5, max=20, quality_scaled=False)
baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
current = json.loads(source.read_text(encoding="utf-8"))
assert baseline["types"] == current["types"]
for quest_id, item in current["quests"].items():
    old = baseline["quests"][quest_id]
    assert item["accept_condition"] == old["accept_condition"]
    actual = item["completion_condition"].copy()
    actual.pop("gold_reward", None)
    assert actual == old["completion_condition"]
report = dict(reward_import_persistence_idempotence=True,
              original_types_triggers_completion_preserved=True,
              existing_failures_unchanged=failures)
(OUTPUT / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report, ensure_ascii=False))
