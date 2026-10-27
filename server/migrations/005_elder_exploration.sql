-- 木材任务改归探索，新增收集材料子任务；同连接提供完整 maze.quest_catalog。
-- 仅更新定义，不修改玩家进度或重新发奖；远端部署另行执行。
BEGIN;
DO $$
DECLARE
    catalog JSONB := current_setting('maze.quest_catalog', true)::jsonb;
    quest JSONB;
BEGIN
    quest := catalog->'quests'->'elder_firewood';
    IF quest->>'type' IS DISTINCT FROM 'exploration'
       OR quest->>'title' IS DISTINCT FROM '帮助白虎爷爷收集木材'
       OR quest->'subtasks' IS DISTINCT FROM '[{"id":"collect_materials","title":"收集材料","handler":"elder_firewood_inventory_available","item_id":"wood","quantity":12}]'::jsonb THEN
        RAISE EXCEPTION '木材探索任务定义与确认范围不符';
    END IF;
    UPDATE quest_definitions SET type_id = quest->>'type', title = quest->>'title',
        subtasks = quest->'subtasks', definition_version = (catalog->>'version')::integer
        WHERE quest_id = 'elder_firewood';
    IF NOT FOUND THEN RAISE EXCEPTION '需先导入白虎爷爷任务定义'; END IF;
END $$;
COMMIT;
