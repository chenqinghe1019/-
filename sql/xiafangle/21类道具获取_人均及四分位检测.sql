-- 下方了｜21类道具获取分布检测
-- 日期：2026-08-24
--
-- 口径：
-- 1. 查询周期由数数动态日期参数 ${PartDate:date} 控制。
-- 2. 总体 = 查询周期内发生 in_out_log 的活跃角色。
-- 3. 获取 = change_type = 1；若 change_type 为空，则 item_num > 0 作为兜底。
-- 4. 未获取某道具的活跃玩家按 0 补齐后，再计算人均、P25、P50、P75。
-- 5. 代金券使用 voucher_log；其他资源从 item_log / money_log 获取。
-- 6. 高抽按“高级灵签/高级招募/高级召唤”等资源名识别，并保留 item_id=1000006 兜底。
-- 7. 种族抽按资源名称识别，不把 recruit_log 的实际抽卡次数混入本口径。
-- 8. 铁锭与升品石历史资料存在 item_id 冲突记录，因此本 SQL 优先按 item_name 区分，避免硬猜 ID。

SELECT
    row_number() OVER (ORDER BY q."排序") AS "序号",
    q."道具",
    q."活跃玩家数",
    q."获取玩家数",
    q."获取率",
    q."获取总量",
    q."人均获取数量",
    q."P25获取数量",
    q."P50获取数量",
    q."P75获取数量"
FROM
(
    SELECT
        t."排序",
        t."道具",
        count(*) AS "活跃玩家数",
        sum(
            CASE
                WHEN t."获取数量" > 0 THEN 1
                ELSE 0
            END
        ) AS "获取玩家数",
        round(
            sum(
                CASE
                    WHEN t."获取数量" > 0 THEN 1.0
                    ELSE 0.0
                END
            ) / nullif(count(*), 0),
            4
        ) AS "获取率",
        round(sum(t."获取数量"), 2) AS "获取总量",
        round(avg(cast(t."获取数量" AS double)), 2) AS "人均获取数量",
        round(
            approx_percentile(cast(t."获取数量" AS double), 0.25),
            2
        ) AS "P25获取数量",
        round(
            approx_percentile(cast(t."获取数量" AS double), 0.50),
            2
        ) AS "P50获取数量",
        round(
            approx_percentile(cast(t."获取数量" AS double), 0.75),
            2
        ) AS "P75获取数量"
    FROM
    (
        SELECT
            a."#account_id",
            c."排序",
            c."道具",
            coalesce(g."获取数量", 0) AS "获取数量"
        FROM
        (
            SELECT DISTINCT
                cast(e."#account_id" AS varchar) AS "#account_id"
            FROM ta.v_event_41 e
            WHERE e."$part_event" = 'in_out_log'
              AND e."domain" = 'release'
              AND ${PartDate:date}
              AND e."#account_id" IS NOT NULL
        ) a
        CROSS JOIN
        (
            VALUES
                (1,  '钻石'),
                (2,  '高抽'),
                (3,  '种族抽'),
                (4,  '星辰石'),
                (5,  '神器精华'),
                (6,  '黄金钥'),
                (7,  '远古精魄'),
                (8,  '铁锭'),
                (9,  '升品石'),
                (10, '九天息壤'),
                (11, '城墙阵图'),
                (12, '龙珠积分'),
                (13, '公会币'),
                (14, '组队积分'),
                (15, '英雄精魄'),
                (16, '异能魂晶'),
                (17, '竞技积分'),
                (18, '诡矿积分'),
                (19, '古墓币'),
                (20, '1小时通用加速'),
                (21, '代金券')
        ) c("排序", "道具")
        LEFT JOIN
        (
            SELECT
                s."#account_id",
                s."道具",
                sum(s."单次获取数量") AS "获取数量"
            FROM
            (
                SELECT
                    r."#account_id",
                    CASE
                        WHEN r."$part_event" = 'voucher_log'
                          OR r."item_name" = '代金券'
                            THEN '代金券'

                        WHEN r."$part_event" = 'money_log'
                         AND r."item_id" = 1
                            THEN '钻石'
                        WHEN r."item_name" IN ('钻石', '宝石')
                            THEN '钻石'

                        WHEN r."$part_event" = 'item_log'
                         AND r."item_id" = 1000006
                            THEN '高抽'
                        WHEN regexp_like(
                                 r."item_name",
                                 '^(高级灵签|高级招募券|高级招募卡|高级召唤券|高级召唤卡|高抽)$'
                             )
                            THEN '高抽'

                        WHEN regexp_like(
                                 r."item_name",
                                 '^(种族抽)$|种族.*(灵签|招募|召唤|祈愿|许愿)'
                             )
                            THEN '种族抽'

                        WHEN r."item_name" IN ('星辰石', '神器升星材料')
                            THEN '星辰石'

                        WHEN r."item_name" IN ('神器精华', '神器升级材料')
                            THEN '神器精华'

                        WHEN regexp_like(r."item_name", '黄金钥|黄金钥匙')
                            THEN '黄金钥'

                        WHEN r."item_name" = '远古精魄'
                            THEN '远古精魄'

                        WHEN r."item_name" IN ('铁锭', '铁钉')
                            THEN '铁锭'

                        WHEN r."item_name" = '升品石'
                            THEN '升品石'

                        WHEN r."item_name" = '九天息壤'
                            THEN '九天息壤'

                        WHEN r."item_name" = '城墙阵图'
                            THEN '城墙阵图'

                        WHEN r."item_name" = '龙珠积分'
                            THEN '龙珠积分'

                        WHEN r."item_name" IN ('公会币', '公会货币')
                            THEN '公会币'

                        WHEN r."item_name" IN ('组队积分', '组队试炼积分')
                            THEN '组队积分'

                        WHEN r."item_name" = '英雄精魄'
                            THEN '英雄精魄'

                        WHEN r."item_name" = '异能魂晶'
                            THEN '异能魂晶'

                        WHEN r."item_name" IN ('竞技积分', '竞技场积分')
                            THEN '竞技积分'

                        WHEN r."item_name" IN ('诡矿积分', '矿脉积分')
                            THEN '诡矿积分'

                        WHEN r."item_name" IN ('古墓币', '古墓积分')
                            THEN '古墓币'

                        WHEN regexp_like(
                                 r."item_name",
                                 '1小时.*通用.*加速|通用.*加速.*1小时'
                             )
                            THEN '1小时通用加速'

                        ELSE NULL
                    END AS "道具",
                    r."单次获取数量",
                    r."变化类型"
                FROM
                (
                    SELECT
                        cast(e."#account_id" AS varchar) AS "#account_id",
                        cast(e."$part_event" AS varchar) AS "$part_event",
                        try_cast(e."item_id" AS bigint) AS "item_id",
                        trim(
                            coalesce(
                                cast(e."item_name" AS varchar),
                                ''
                            )
                        ) AS "item_name",
                        abs(
                            coalesce(
                                try_cast(e."item_num" AS double),
                                0
                            )
                        ) AS "单次获取数量",
                        coalesce(
                            try_cast(e."change_type" AS bigint),
                            CASE
                                WHEN try_cast(e."item_num" AS double) > 0 THEN 1
                                WHEN try_cast(e."item_num" AS double) < 0 THEN 2
                                ELSE 0
                            END
                        ) AS "变化类型"
                    FROM ta.v_event_41 e
                    WHERE e."$part_event" IN (
                              'money_log',
                              'item_log',
                              'voucher_log'
                          )
                      AND e."domain" = 'release'
                      AND ${PartDate:date}
                      AND e."#account_id" IS NOT NULL
                ) r
            ) s
            WHERE s."道具" IS NOT NULL
              AND s."变化类型" = 1
            GROUP BY
                s."#account_id",
                s."道具"
        ) g
            ON a."#account_id" = g."#account_id"
           AND c."道具" = g."道具"
    ) t
    GROUP BY
        t."排序",
        t."道具"
) q
ORDER BY
    q."排序";
