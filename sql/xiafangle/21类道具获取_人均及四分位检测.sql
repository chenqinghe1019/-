-- 下方了｜21类道具按开服天数获取分布检测
-- 日期：2026-08-24
-- 口径：
-- 1. 查询周期由 ${PartDate:date} 控制，日期仅用于内部关联，不作为最终展示/分组维度。
-- 2. 开服天数 = 活跃日期 - server_open_time + 1，开服当天记 D1。
-- 3. 每个开服天数下，存在 in_out_log 的活跃角色作为总体。
-- 4. 获取 = change_type = 1；若 change_type 为空，则 item_num > 0 作为兜底。
-- 5. 活跃但未获取某道具的玩家按 0 补齐后，再计算人均、最小值、P25、P50、P75、P95、最大值。
-- 6. 获取率 = 获取玩家数 * 1.0000 / 活跃玩家数。
-- 7. 超出P95两倍玩家数 = 该开服天数下该道具获取数量 > P95获取数量 * 2 的玩家数。
-- 8. P95沿用全体活跃玩家口径，未获取玩家按0参与；若P95=0，则所有获取数量>0的玩家都会满足>2*P95。

SELECT
    row_number() OVER (
        ORDER BY q."开服天数", q."排序"
    ) AS "序号",
    q."开服天数",
    q."道具",
    q."活跃玩家数",
    q."获取玩家数",
    q."获取率",
    q."获取总量",
    q."人均获取数量",
    q."最小获取数量",
    q."P25获取数量",
    q."P50获取数量",
    q."P75获取数量",
    q."P95获取数量",
    q."最大获取数量",
    q."超出P95两倍玩家数"
FROM
(
    SELECT
        u."开服天数",
        u."排序",
        u."道具",
        count(*) AS "活跃玩家数",

        sum(
            CASE
                WHEN u."获取数量" > 0 THEN 1
                ELSE 0
            END
        ) AS "获取玩家数",

        round(
            sum(
                CASE
                    WHEN u."获取数量" > 0 THEN 1
                    ELSE 0
                END
            ) * 1.0000
            / nullif(count(*), 0),
            4
        ) AS "获取率",

        round(
            sum(u."获取数量"),
            2
        ) AS "获取总量",

        round(
            avg(cast(u."获取数量" AS double)),
            2
        ) AS "人均获取数量",

        round(
            min(cast(u."获取数量" AS double)),
            2
        ) AS "最小获取数量",

        round(
            approx_percentile(
                cast(u."获取数量" AS double),
                0.25
            ),
            2
        ) AS "P25获取数量",

        round(
            approx_percentile(
                cast(u."获取数量" AS double),
                0.50
            ),
            2
        ) AS "P50获取数量",

        round(
            approx_percentile(
                cast(u."获取数量" AS double),
                0.75
            ),
            2
        ) AS "P75获取数量",

        round(
            max(u."P95获取数量"),
            2
        ) AS "P95获取数量",

        round(
            max(cast(u."获取数量" AS double)),
            2
        ) AS "最大获取数量",

        sum(
            CASE
                WHEN cast(u."获取数量" AS double) > u."P95获取数量" * 2
                    THEN 1
                ELSE 0
            END
        ) AS "超出P95两倍玩家数"

    FROM
    (
        SELECT
            t."开服天数",
            t."#account_id",
            t."排序",
            t."道具",
            t."获取数量",

            approx_percentile(
                cast(t."获取数量" AS double),
                0.95
            ) OVER (
                PARTITION BY
                    t."开服天数",
                    t."排序",
                    t."道具"
            ) AS "P95获取数量"

        FROM
        (
            SELECT
                a."日期",
                a."开服天数",
                a."#account_id",
                c."排序",
                c."道具",
                coalesce(g."获取数量", 0) AS "获取数量"

            FROM
            (
                SELECT DISTINCT
                    cast(e."$part_date" AS varchar) AS "日期",
                    cast(e."#account_id" AS varchar) AS "#account_id",
                    date_diff(
                        'day',
                        date(u."server_open_time"),
                        date(e."#event_time")
                    ) + 1 AS "开服天数"

                FROM ta.v_event_41 e

                INNER JOIN ta.v_user_41 u
                    ON cast(e."#account_id" AS varchar)
                     = cast(u."#account_id" AS varchar)

                WHERE ${PartDate:date}
                  AND e."domain" = 'release'
                  AND u."domain" = 'release'
                  AND e."$part_event" = 'in_out_log'
                  AND e."#account_id" IS NOT NULL
                  AND u."server_open_time" IS NOT NULL
                  AND date(e."#event_time") >= date(u."server_open_time")
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
                    s."日期",
                    s."#account_id",
                    s."道具",
                    sum(s."单次获取数量") AS "获取数量"

                FROM
                (
                    SELECT
                        r."日期",
                        r."#account_id",

                        CASE
                            WHEN r."$part_event" = 'voucher_log'
                              OR r."item_name" = '代金券'
                                THEN '代金券'

                            WHEN r."$part_event" = 'money_log'
                             AND r."item_id" = 1
                                THEN '钻石'

                            WHEN r."item_name" = '钻石'
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
                            cast(e."$part_date" AS varchar) AS "日期",
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

                        WHERE ${PartDate:date}
                          AND e."domain" = 'release'
                          AND e."$part_event" IN (
                              'money_log',
                              'item_log',
                              'voucher_log'
                          )
                          AND e."#account_id" IS NOT NULL
                    ) r
                ) s

                WHERE s."道具" IS NOT NULL
                  AND s."变化类型" = 1

                GROUP BY
                    s."日期",
                    s."#account_id",
                    s."道具"
            ) g
                ON a."日期" = g."日期"
               AND a."#account_id" = g."#account_id"
               AND c."道具" = g."道具"
        ) t
    ) u

    GROUP BY
        u."开服天数",
        u."排序",
        u."道具"
) q

ORDER BY
    q."开服天数",
    q."排序";