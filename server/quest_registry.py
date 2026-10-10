"""任务定义数据库工具；仅管理定义，不接收或伪造玩家完成事件。"""
import argparse
import json
import sqlite3
from contextlib import closing
from functools import partial
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATABASE = ROOT / "server" / "var" / "quests.sqlite3"
DEFAULT_CATALOG = ROOT / "data" / "quests" / "catalog.json"
SCHEMA = """
CREATE TABLE IF NOT EXISTS quest_types (
    type_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    accept_event TEXT NOT NULL,
    complete_event TEXT NOT NULL,
    completion_handler TEXT NOT NULL,
    interaction TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS quest_definitions (
    quest_id TEXT PRIMARY KEY,
    type_id TEXT NOT NULL REFERENCES quest_types(type_id),
    title TEXT NOT NULL,
    accept_condition TEXT NOT NULL CHECK(json_type(accept_condition) = 'object'),
    completion_condition TEXT NOT NULL CHECK(json_type(completion_condition) = 'object'),
    subtasks TEXT NOT NULL CHECK(json_type(subtasks) = 'array'),
    definition_version INTEGER NOT NULL CHECK(definition_version > 0)
);
"""


def validate(catalog):
    if type(catalog.get("version")) is not int or catalog["version"] < 1:
        raise ValueError("配置版本必须为正整数")
    types, quests = catalog["types"], catalog["quests"]
    if not isinstance(types, dict) or not isinstance(quests, dict):
        raise ValueError("类型和任务必须为映射表")
    for type_id, item in types.items():
        for key in ("name", "accept_event", "complete_event", "completion_handler", "interaction"):
            if not isinstance(item.get(key), str) or not item[key].strip():
                raise ValueError(f"类型 {type_id} 缺少 {key}")
    for quest_id, item in quests.items():
        if item.get("type") not in types:
            raise ValueError(f"任务 {quest_id} 引用了未登记类型")
        if not isinstance(item.get("title"), str) or not item["title"].strip():
            raise ValueError(f"任务 {quest_id} 缺少名称")
        for key in ("accept_condition", "completion_condition"):
            if not isinstance(item.get(key), dict) or not item[key].get("handler"):
                raise ValueError(f"任务 {quest_id} 缺少 {key} 处理器")
        if not isinstance(item.get("subtasks"), list):
            raise ValueError(f"任务 {quest_id} 的子任务必须是列表")


def import_catalog(database, catalog_path):
    catalog = json.loads(Path(catalog_path).read_text(encoding="utf-8-sig"))
    validate(catalog)
    database = Path(database)
    database.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(database)) as connection, connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.executescript(SCHEMA)
        # 显式事务：全部定义一起更新；不删除已有定义或玩家实例。
        connection.execute("BEGIN IMMEDIATE")
        for type_id, item in catalog["types"].items():
            connection.execute("""INSERT INTO quest_types VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(type_id) DO UPDATE SET display_name=excluded.display_name,
                accept_event=excluded.accept_event, complete_event=excluded.complete_event,
                completion_handler=excluded.completion_handler, interaction=excluded.interaction""",
                (type_id, item["name"], item["accept_event"], item["complete_event"],
                 item["completion_handler"], item["interaction"]))
        for quest_id, item in catalog["quests"].items():
            connection.execute("""INSERT INTO quest_definitions VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(quest_id) DO UPDATE SET type_id=excluded.type_id, title=excluded.title,
                accept_condition=excluded.accept_condition, completion_condition=excluded.completion_condition,
                subtasks=excluded.subtasks, definition_version=excluded.definition_version""",
                (quest_id, item["type"], item["title"],
                 json.dumps(item["accept_condition"], ensure_ascii=False),
                 json.dumps(item["completion_condition"], ensure_ascii=False),
                 json.dumps(item["subtasks"], ensure_ascii=False), catalog["version"]))
    return read_catalog(database)


def read_catalog(database):
    # 只读连接，不会因为路径拼错创建一个空库。
    with closing(sqlite3.connect(Path(database).resolve().as_uri() + "?mode=ro", uri=True)) as connection:
        connection.row_factory = sqlite3.Row
        types = [dict(row) for row in connection.execute("SELECT * FROM quest_types ORDER BY type_id")]
        quests = [dict(row) for row in connection.execute("SELECT * FROM quest_definitions ORDER BY quest_id")]
    for quest in quests:
        for key in ("accept_condition", "completion_condition", "subtasks"):
            quest[key] = json.loads(quest[key])
    return {"types": types, "quests": quests}


class RegistryHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, database, **kwargs):
        self.database = database
        super().__init__(*args, **kwargs)

    def do_GET(self):
        route = urlsplit(self.path)
        if route.path not in ("/quest-types", "/quests"):
            self.send_error(404)
            return
        try:
            catalog = read_catalog(self.database)
        except sqlite3.Error:
            self.send_error(503, "Quest database unavailable")
            return
        result = catalog["types" if route.path == "/quest-types" else "quests"]
        type_id = parse_qs(route.query).get("type", [None])[0]
        if route.path == "/quests" and type_id is not None:
            result = [quest for quest in result if quest["type_id"] == type_id]
        body = json.dumps(result, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def make_server(database, port=8766):
    # 开发服务仅绑定本机；不对局域网或公网开放未认证的管理接口。
    read_catalog(database)
    return ThreadingHTTPServer(("127.0.0.1", port), partial(RegistryHandler, database=database))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("import", "list", "serve"))
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--database", type=Path, default=DEFAULT_DATABASE)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    args = parser.parse_args()
    if args.command == "serve":
        with make_server(args.database, args.port) as server:
            print(f"任务定义开发服务：http://127.0.0.1:{server.server_port}", flush=True)
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                pass
        return
    result = import_catalog(args.database, args.catalog) if args.command == "import" else read_catalog(args.database)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
