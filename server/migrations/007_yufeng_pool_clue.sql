-- 分水庭友好委托定义；部署时传入完整 maze.quest_catalog。本地不自动连接远端。
BEGIN;
DO $$
DECLARE
    catalog JSONB := current_setting('maze.quest_catalog', true)::jsonb;
    quest JSONB;
BEGIN
    quest := catalog->'quests'->'yufeng_pool_clue';
    IF quest IS NULL OR quest->>'type' <> 'exploration'
        OR quest->'completion_condition'->>'handler' <> 'frog_pool_clue_reported' THEN
        RAISE EXCEPTION '缺少已确认的御风池中央调查定义';
    END IF;
    INSERT INTO quest_definitions(quest_id,type_id,title,accept_condition,completion_condition,subtasks,definition_version)
    VALUES ('yufeng_pool_clue',quest->>'type',quest->>'title',quest->'accept_condition',quest->'completion_condition',quest->'subtasks',(catalog->>'version')::integer)
    ON CONFLICT (quest_id) DO UPDATE SET type_id=EXCLUDED.type_id,title=EXCLUDED.title,
        accept_condition=EXCLUDED.accept_condition,completion_condition=EXCLUDED.completion_condition,
        subtasks=EXCLUDED.subtasks,definition_version=EXCLUDED.definition_version;
END $$;
COMMIT;
