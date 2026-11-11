-- 仅更新普通顾客订单定义；铁山首单、订单类型和其他任务保持不变。
BEGIN;
DO $$
DECLARE
    catalog JSONB := current_setting('maze.quest_catalog', true)::jsonb;
    quest JSONB;
BEGIN
    quest := catalog->'quests'->'restaurant_customer_order';
    IF quest IS NULL OR quest->>'type' <> 'order'
        OR quest->'accept_condition'->>'ordinary_service' <> 'seated_food_stage' THEN
        RAISE EXCEPTION '缺少已确认的普通营业料理阶段定义';
    END IF;
    INSERT INTO quest_definitions(quest_id,type_id,title,accept_condition,completion_condition,subtasks,definition_version)
    VALUES ('restaurant_customer_order',quest->>'type',quest->>'title',quest->'accept_condition',quest->'completion_condition',quest->'subtasks',(catalog->>'version')::integer)
    ON CONFLICT (quest_id) DO UPDATE SET type_id=EXCLUDED.type_id,title=EXCLUDED.title,
        accept_condition=EXCLUDED.accept_condition,completion_condition=EXCLUDED.completion_condition,
        subtasks=EXCLUDED.subtasks,definition_version=EXCLUDED.definition_version;
END $$;
COMMIT;
