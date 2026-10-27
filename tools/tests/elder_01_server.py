"""ELDER-01 定义验收：真实SQLite、HTTP查询、目录计数、原任务定义保护。"""
import json
import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from urllib.request import urlopen
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'server'))
from quest_registry import import_catalog, read_catalog, make_server, DEFAULT_CATALOG

class ElderDefinitions(unittest.TestCase):
    def test_collection_persistence_http_and_previous_definitions(self):
        source = json.loads(DEFAULT_CATALOG.read_text(encoding='utf-8-sig'))
        self.assertEqual(set(source['types']), {'order', 'exploration', 'collection'})
        self.assertEqual(set(source['quests']), {'restaurant_customer_order', 'chapter_1_first_order', 'chapter_1_salt_pool', 'elder_firewood'})
        with tempfile.TemporaryDirectory() as folder:
            db = Path(folder) / 'quests.sqlite3'
            first = import_catalog(db, DEFAULT_CATALOG)
            self.assertEqual(len(first['types']), 3)
            self.assertEqual(len(first['quests']), 4)
            self.assertEqual(first, read_catalog(db))
            self.assertEqual(first, import_catalog(db, DEFAULT_CATALOG))
            for item in first['quests']:
                original = source['quests'][item['quest_id']]
                self.assertEqual(item['type_id'], original['type'])
                for key in ('title', 'accept_condition', 'completion_condition', 'subtasks'):
                    self.assertEqual(item[key], original[key])
            elder = next(q for q in first['quests'] if q['quest_id'] == 'elder_firewood')
            self.assertEqual(elder['type_id'], 'collection')
            self.assertEqual(elder['title'], '为白虎爷爷收集12个木材')
            self.assertEqual(elder['completion_condition'], {'handler': 'elder_firewood_delivery', 'item_id': 'wood', 'quantity': 12})
            self.assertEqual(elder['subtasks'], [])
            with make_server(db, 0) as server:
                worker = threading.Thread(target=server.serve_forever)
                worker.start()
                try:
                    base = f'http://127.0.0.1:{server.server_port}'
                    with urlopen(base + '/quest-types', timeout=3) as response:
                        self.assertEqual(len(json.load(response)), 3)
                    with urlopen(base + '/quests?type=collection', timeout=3) as response:
                        self.assertEqual(json.load(response), [elder])
                    with urlopen(base + '/quests?type=exploration', timeout=3) as response:
                        items = json.load(response)
                        self.assertEqual(len(items), 1)
                        self.assertEqual(items[0]['quest_id'], 'chapter_1_salt_pool')
                finally:
                    server.shutdown()
                    worker.join(timeout=3)
        # 原三个定义和两个类型与冻结之前的原始基线逐字段比较。
        import subprocess
        # 合入验收可传入合入前目录，保留目标工作区已获授权的订单金币定义。
        baseline_path = os.environ.get('ELDER_BASELINE_CATALOG')
        baseline = json.loads(Path(baseline_path).read_text(encoding='utf-8-sig')) if baseline_path else json.loads(subprocess.check_output(['git', 'show', 'f406e35c99aaf06c091316dde9cca4ef2b7a45fc:data/quests/catalog.json'], cwd=ROOT))
        for key, value in baseline['quests'].items():
            self.assertEqual(source['quests'][key], value)
        for key, value in baseline['types'].items():
            self.assertEqual(source['types'][key], value)

if __name__ == '__main__':
    unittest.main()
