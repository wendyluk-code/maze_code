"""验证真实SQLite落库、幂等导入、非法配置回滚及类型外键。"""
import json
import sqlite3
import tempfile
import unittest
import threading
from urllib.request import urlopen
from contextlib import closing
from pathlib import Path
from quest_registry import DEFAULT_CATALOG, import_catalog, read_catalog, make_server


class RegistryTests(unittest.TestCase):
    def test_running_server_reads_persisted_types_and_filters_quests(self):
        with tempfile.TemporaryDirectory() as folder:
            database = Path(folder) / "quests.sqlite3"
            import_catalog(database, DEFAULT_CATALOG)
            with make_server(database, 0) as server:
                worker = threading.Thread(target=server.serve_forever)
                worker.start()
                try:
                    base = f"http://127.0.0.1:{server.server_port}"
                    with urlopen(base + "/quest-types", timeout=3) as response:
                        self.assertEqual(len(json.load(response)), 2)
                    with urlopen(base + "/quests?type=exploration", timeout=3) as response:
                        quests = json.load(response)
                        self.assertEqual(len(quests), 1)
                        self.assertEqual(quests[0]["title"], "前往迷宫第一层·盐池")
                finally:
                    server.shutdown()
                    worker.join(timeout=3)

    def test_database_failure_rolls_back_all_definitions(self):
        with tempfile.TemporaryDirectory() as folder:
            database = Path(folder) / "quests.sqlite3"
            before = import_catalog(database, DEFAULT_CATALOG)
            with closing(sqlite3.connect(database)) as connection, connection:
                connection.execute("""CREATE TRIGGER reject_definition BEFORE UPDATE ON quest_definitions
                    BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END""")
            changed = json.loads(DEFAULT_CATALOG.read_text(encoding="utf-8"))
            changed["types"]["order"]["name"] = "测试更新"
            source = Path(folder) / "changed.json"
            source.write_text(json.dumps(changed), encoding="utf-8")
            with self.assertRaises(sqlite3.IntegrityError):
                import_catalog(database, source)
            self.assertEqual(before, read_catalog(database))

    def test_persistence_and_idempotence(self):
        with tempfile.TemporaryDirectory() as folder:
            database = Path(folder) / "quests.sqlite3"
            first = import_catalog(database, DEFAULT_CATALOG)
            self.assertEqual(len(first["types"]), 2)
            self.assertEqual(len(first["quests"]), 2)
            self.assertEqual(first, read_catalog(database))
            self.assertEqual(first, import_catalog(database, DEFAULT_CATALOG))
            exploration = next(q for q in first["quests"] if q["type_id"] == "exploration")
            self.assertEqual(exploration["title"], "前往迷宫第一层·盐池")
            self.assertEqual(exploration["subtasks"], [])
            self.assertFalse(exploration["completion_condition"]["implemented"])

    def test_invalid_import_keeps_existing_database(self):
        with tempfile.TemporaryDirectory() as folder:
            database = Path(folder) / "quests.sqlite3"
            before = import_catalog(database, DEFAULT_CATALOG)
            invalid = json.loads(DEFAULT_CATALOG.read_text(encoding="utf-8"))
            invalid["quests"]["chapter_1_salt_pool"]["type"] = "unknown"
            source = Path(folder) / "invalid.json"
            source.write_text(json.dumps(invalid), encoding="utf-8")
            with self.assertRaises(ValueError):
                import_catalog(database, source)
            self.assertEqual(before, read_catalog(database))
            with closing(sqlite3.connect(database)) as connection, connection:
                connection.execute("PRAGMA foreign_keys = ON")
                with self.assertRaises(sqlite3.IntegrityError):
                    connection.execute("UPDATE quest_definitions SET type_id='unknown'")


if __name__ == "__main__":
    unittest.main()
