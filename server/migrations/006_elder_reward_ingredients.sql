-- 白虎爷爷奖励定义更新；部署前传入完整 maze.quest_catalog，远端不自动部署。
-- 此迁移仅登记定义，不补发已归档玩家奖励；实际奖励由交付事务一次发放。
BEGIN;
DO $$
DECLARE
    catalog JSONB := current_setting('maze.quest_catalog', true)::jsonb;
    quest JSONB;
BEGIN
    quest := catalog->'quests'->'elder_firewood';
    IF quest->'completion_condition'->'rewards' IS DISTINCT FROM
       '{"moondew_honey":3,"cooking_sake":3,"sour_vine_juice":3,"backpack_unlocked":true}'::jsonb THEN
        RAISE EXCEPTION '白虎爷爷食材奖励定义与确认范围不符';
    END IF;
    UPDATE quest_definitions SET completion_condition = quest->'completion_condition',
        definition_version = (catalog->>'version')::integer WHERE quest_id = 'elder_firewood';
    IF NOT FOUND THEN RAISE EXCEPTION '需先运行白虎爷爷收集任务定义迁移'; END IF;
END $$;
COMMIT;

