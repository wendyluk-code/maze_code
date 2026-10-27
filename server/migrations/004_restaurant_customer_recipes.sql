-- 从完整 maze.quest_catalog 读取本票配方定义；只登记，不发奖，不自动部署。
BEGIN;
DO $$
DECLARE
    catalog JSONB := current_setting('maze.quest_catalog', true)::jsonb;
    recipes JSONB;
BEGIN
    recipes := catalog->'quests'->'restaurant_customer_order'->'completion_condition'->'customer_recipes';
    IF recipes IS DISTINCT FROM
       '{"slime_candy":{"gold":10},"brick_snail_sashimi":{"gold":20},"lizard_tail_skewer":{"gold":40}}'::jsonb THEN
        RAISE EXCEPTION '三席顾客配方奖励与确认范围不符';
    END IF;
    UPDATE quest_definitions SET
        title = catalog->'quests'->'restaurant_customer_order'->>'title',
        completion_condition = jsonb_set(completion_condition, '{customer_recipes}', recipes),
        definition_version = (catalog->>'version')::integer
    WHERE quest_id = 'restaurant_customer_order';
    IF NOT FOUND THEN RAISE EXCEPTION '需先导入餐厅订单任务定义'; END IF;
END $$;
COMMIT;
