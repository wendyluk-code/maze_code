-- PostgreSQL 服务端接入草案。当前项目无数据库连接；此迁移尚未部署。
-- 定义从 data/quests/catalog.json 导入，不在迁移里维护第二份玩法配置。
BEGIN;
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
    accept_condition JSONB NOT NULL CHECK (jsonb_typeof(accept_condition) = 'object'),
    completion_condition JSONB NOT NULL CHECK (jsonb_typeof(completion_condition) = 'object'),
    subtasks JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(subtasks) = 'array'),
    definition_version INTEGER NOT NULL CHECK (definition_version > 0)
);
CREATE TABLE IF NOT EXISTS player_quest_instances (
    -- 玩家/存档标识由未来账户服务提供；当前不伪造账户表外键。
    owner_id TEXT NOT NULL,
    quest_id TEXT NOT NULL REFERENCES quest_definitions(quest_id),
    status TEXT NOT NULL CHECK (status IN ('active', 'archived')),
    unread BOOLEAN NOT NULL DEFAULT TRUE,
    progress JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(progress) = 'object'),
    PRIMARY KEY (owner_id, quest_id),
    CHECK (status <> 'archived' OR unread = FALSE)
);
CREATE INDEX IF NOT EXISTS player_quests_by_status ON player_quest_instances(owner_id, status);
COMMIT;
