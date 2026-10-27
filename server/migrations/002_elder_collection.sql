-- 白虎爷爷定义增量导入；玩法仍只以 data/quests/catalog.json 为权威。
-- 部署者在同一连接先 set_config('maze.quest_catalog', <完整JSON文本>, false)。
-- 本迁移不创建玩家状态、不执行扣材、不授予奖励；当前仅提供迁移，未远端部署。
BEGIN;
DO $$
DECLARE
    catalog JSONB := current_setting('maze.quest_catalog', true)::jsonb;
    kind JSONB;
    quest JSONB;
BEGIN
    kind := catalog->'types'->'collection';
    quest := catalog->'quests'->'elder_firewood';
    IF kind IS NULL OR quest IS NULL
       OR quest->>'type' <> 'collection'
       OR quest->'completion_condition'->>'item_id' <> 'wood'
       OR quest->'completion_condition'->>'quantity' <> '12'
       OR quest->'subtasks' <> '[]'::jsonb THEN
        RAISE EXCEPTION '白虎爷爷任务定义缺失或与已确认边界不符';
    END IF;
    INSERT INTO quest_types VALUES (
        'collection', kind->>'name', kind->>'accept_event', kind->>'complete_event',
        kind->>'completion_handler', kind->>'interaction')
    ON CONFLICT (type_id) DO UPDATE SET
        display_name = EXCLUDED.display_name, accept_event = EXCLUDED.accept_event,
        complete_event = EXCLUDED.complete_event, completion_handler = EXCLUDED.completion_handler,
        interaction = EXCLUDED.interaction;
    INSERT INTO quest_definitions VALUES (
        'elder_firewood', 'collection', quest->>'title', quest->'accept_condition',
        quest->'completion_condition', quest->'subtasks', (catalog->>'version')::integer)
    ON CONFLICT (quest_id) DO UPDATE SET
        type_id = EXCLUDED.type_id, title = EXCLUDED.title,
        accept_condition = EXCLUDED.accept_condition, completion_condition = EXCLUDED.completion_condition,
        subtasks = EXCLUDED.subtasks, definition_version = EXCLUDED.definition_version;
END $$;
COMMIT;
