-- 仅同步任务定义；使用部署连接提供的完整目录，不操作玩家进度和奖励。
BEGIN;
DO $$
DECLARE
    catalog JSONB := current_setting('maze.quest_catalog', true)::jsonb;
    quest JSONB;
    id TEXT;
BEGIN
    FOREACH id IN ARRAY ARRAY['chapter_1_salt_pool','yufeng_pool_clue'] LOOP
        quest := catalog->'quests'->id;
        IF quest IS NULL OR quest->>'type' <> 'exploration' OR jsonb_array_length(quest->'subtasks') < 1 THEN
            RAISE EXCEPTION '缺少已确认的探索子任务定义：%', id;
        END IF;
        INSERT INTO quest_definitions(quest_id,type_id,title,accept_condition,completion_condition,subtasks,definition_version)
        VALUES(id,quest->>'type',quest->>'title',quest->'accept_condition',quest->'completion_condition',quest->'subtasks',(catalog->>'version')::integer)
        ON CONFLICT(quest_id) DO UPDATE SET title=EXCLUDED.title,
            accept_condition=EXCLUDED.accept_condition, completion_condition=EXCLUDED.completion_condition,
            subtasks=EXCLUDED.subtasks, definition_version=EXCLUDED.definition_version;
    END LOOP;
END $$;
COMMIT;
