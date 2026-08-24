-- 下方了｜道具获取异常监控（获取分布与尾部强度）
-- 版本：v1.2 2026-08-24
-- 口径：
-- 1. 最终维度 = 日期 × 开服天数 × 截至当天累计付费分层 × 道具。
-- 2. 活跃总体 = 当日存在 in_out_log 的角色；日期用于异常定位，开服当天记 D1。
-- 3. 累计付费 = 截至该活跃日（含当天）pay_log.payment / 100；payment>0，不额外限制pay_result。
-- 4. 获取 = change_type=1；change_type为空时 item_num>0 兜底；获取数量取 abs(item_num)。
-- 5. 获取率分母仍为全部活跃玩家。
-- 6. 获取者人均、P50/P95/P99只对获取数量>0的玩家计算，未获取玩家不参与尾部分布。
-- 7. 最大值倍数 = 最大获取数量 / P99获取数量。
-- 8. 当日该开服天数×付费分层×道具下获取玩家数=0时直接不输出。

SELECT
    row_number() OVER (
        ORDER BY q."日期",q."开服天数",q."分层排序",q."排序"
    ) "序号",
    q."日期",
    q."开服天数",
    q."累计付费分层",
    q."道具",
    q."活跃玩家数",
    q."获取玩家数",
    q."获取率",
    q."获取总量",
    q."获取玩家人均数量",
    q."P50获取数量",
    q."P95获取数量",
    q."P99获取数量",
    q."最大获取数量",
    q."最大值/P99倍数"
FROM
(
    SELECT
        u."日期",
        u."开服天数",
        u."累计付费分层",
        u."分层排序",
        u."排序",
        u."道具",

        count(*) "活跃玩家数",

        sum(
            CASE
                WHEN u."获取数量">0 THEN 1
                ELSE 0
            END
        ) "获取玩家数",

        round(
            sum(
                CASE
                    WHEN u."获取数量">0 THEN 1
                    ELSE 0
                END
            ) * 1.0000 / nullif(count(*),0),
            4
        ) "获取率",

        round(
            sum(u."获取数量"),
            2
        ) "获取总量",

        round(
            avg(
                CASE
                    WHEN u."获取数量">0
                        THEN cast(u."获取数量" AS double)
                END
            ),
            2
        ) "获取玩家人均数量",

        round(
            max(u."P50获取数量"),
            2
        ) "P50获取数量",

        round(
            max(u."P95获取数量"),
            2
        ) "P95获取数量",

        round(
            max(u."P99获取数量"),
            2
        ) "P99获取数量",

        round(
            max(cast(u."获取数量" AS double)),
            2
        ) "最大获取数量",

        round(
            max(cast(u."获取数量" AS double))
            / nullif(max(u."P99获取数量"),0),
            2
        ) "最大值/P99倍数"

    FROM
    (
        SELECT
            t."日期",
            t."开服天数",
            t."#account_id",
            t."累计付费分层",
            t."分层排序",
            t."排序",
            t."道具",
            t."获取数量",

            approx_percentile(
                CASE
                    WHEN t."获取数量">0
                        THEN cast(t."获取数量" AS double)
                END,
                0.50
            ) OVER (
                PARTITION BY
                    t."日期",
                    t."开服天数",
                    t."累计付费分层",
                    t."分层排序",
                    t."排序",
                    t."道具"
            ) "P50获取数量",

            approx_percentile(
                CASE
                    WHEN t."获取数量">0
                        THEN cast(t."获取数量" AS double)
                END,
                0.95
            ) OVER (
                PARTITION BY
                    t."日期",
                    t."开服天数",
                    t."累计付费分层",
                    t."分层排序",
                    t."排序",
                    t."道具"
            ) "P95获取数量",

            approx_percentile(
                CASE
                    WHEN t."获取数量">0
                        THEN cast(t."获取数量" AS double)
                END,
                0.99
            ) OVER (
                PARTITION BY
                    t."日期",
                    t."开服天数",
                    t."累计付费分层",
                    t."分层排序",
                    t."排序",
                    t."道具"
            ) "P99获取数量"

        FROM
        (
            SELECT
                a."日期",
                a."开服天数",
                a."#account_id",
                a."累计付费分层",
                a."分层排序",
                c."排序",
                c."道具",
                coalesce(g."获取数量",0) "获取数量"

            FROM
            (
                SELECT
                    x."日期",
                    x."开服天数",
                    x."#account_id",

                    CASE
                        WHEN x."累计付费金额"=0 THEN 'a_free'
                        WHEN x."累计付费金额"<=6 THEN 'b_(0,6]'
                        WHEN x."累计付费金额"<=30 THEN 'c_(6,30]'
                        WHEN x."累计付费金额"<=100 THEN 'd_(30,100]'
                        WHEN x."累计付费金额"<=300 THEN 'e_(100,300]'
                        WHEN x."累计付费金额"<=500 THEN 'f_(300,500]'
                        WHEN x."累计付费金额"<=1000 THEN 'g_(500,1000]'
                        ELSE 'h_(1000,+)'
                    END "累计付费分层",

                    CASE
                        WHEN x."累计付费金额"=0 THEN 1
                        WHEN x."累计付费金额"<=6 THEN 2
                        WHEN x."累计付费金额"<=30 THEN 3
                        WHEN x."累计付费金额"<=100 THEN 4
                        WHEN x."累计付费金额"<=300 THEN 5
                        WHEN x."累计付费金额"<=500 THEN 6
                        WHEN x."累计付费金额"<=1000 THEN 7
                        ELSE 8
                    END "分层排序"

                FROM
                (
                    SELECT
                        a0."日期",
                        a0."开服天数",
                        a0."#account_id",
                        coalesce(sum(pay."当日付费金额"),0) "累计付费金额"

                    FROM
                    (
                        SELECT DISTINCT
                            date(e."#event_time") "日期",
                            cast(e."#account_id" AS varchar) "#account_id",

                            date_diff(
                                'day',
                                date(u."server_open_time"),
                                date(e."#event_time")
                            )+1 "开服天数"

                        FROM ta.v_event_41 e

                        INNER JOIN ta.v_user_41 u
                            ON cast(e."#account_id" AS varchar)
                             = cast(u."#account_id" AS varchar)

                        WHERE ${PartDate:date}
                          AND e."domain"='release'
                          AND u."domain"='release'
                          AND e."$part_event"='in_out_log'
                          AND e."#account_id" IS NOT NULL
                          AND u."server_open_time" IS NOT NULL
                          AND date(e."#event_time")>=date(u."server_open_time")
                    ) a0

                    LEFT JOIN
                    (
                        SELECT
                            cast(e."#account_id" AS varchar) "#account_id",
                            date(e."#event_time") "付费日期",

                            sum(
                                coalesce(
                                    try_cast(e."payment" AS double),
                                    0
                                )
                            )/100.0000 "当日付费金额"

                        FROM ta.v_event_41 e

                        WHERE e."domain"='release'
                          AND e."$part_event"='pay_log'
                          AND e."#account_id" IS NOT NULL
                          AND coalesce(
                                try_cast(e."payment" AS double),
                                0
                              )>0

                        GROUP BY 1,2
                    ) pay
                        ON a0."#account_id"=pay."#account_id"
                       AND pay."付费日期"<=a0."日期"

                    GROUP BY 1,2,3
                ) x
            ) a

            CROSS JOIN
            (
                VALUES
                    (1,'钻石'),
                    (2,'高抽'),
                    (3,'种族抽'),
                    (4,'星辰石'),
                    (5,'神器精华'),
                    (6,'黄金钥'),
                    (7,'远古精魄'),
                    (8,'铁锭'),
                    (9,'升品石'),
                    (10,'九天息壤'),
                    (11,'城墙阵图'),
                    (12,'龙珠积分'),
                    (13,'公会币'),
                    (14,'组队积分'),
                    (15,'英雄精魄'),
                    (16,'异能魂晶'),
                    (17,'竞技积分'),
                    (18,'诡矿积分'),
                    (19,'古墓币'),
                    (20,'1小时通用加速'),
                    (21,'代金券')
            ) c("排序","道具")

            LEFT JOIN
            (
                SELECT
                    s."日期",
                    s."#account_id",
                    s."道具",
                    sum(s."单次获取数量") "获取数量"

                FROM
                (
                    SELECT
                        r."日期",
                        r."#account_id",

                        CASE
                            WHEN r."$part_event"='voucher_log'
                              OR r."item_name"='代金券'
                                THEN '代金券'
                            WHEN r."$part_event"='money_log'
                             AND r."item_id"=1
                                THEN '钻石'
                            WHEN r."item_name"='钻石'
                                THEN '钻石'
                            WHEN r."$part_event"='item_log'
                             AND r."item_id"=1000006
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
                            WHEN r."item_name" IN ('星辰石','神器升星材料')
                                THEN '星辰石'
                            WHEN r."item_name" IN ('神器精华','神器升级材料')
                                THEN '神器精华'
                            WHEN regexp_like(r."item_name",'黄金钥|黄金钥匙')
                                THEN '黄金钥'
                            WHEN r."item_name"='远古精魄'
                                THEN '远古精魄'
                            WHEN r."item_name" IN ('铁锭','铁钉')
                                THEN '铁锭'
                            WHEN r."item_name"='升品石'
                                THEN '升品石'
                            WHEN r."item_name"='九天息壤'
                                THEN '九天息壤'
                            WHEN r."item_name"='城墙阵图'
                                THEN '城墙阵图'
                            WHEN r."item_name"='龙珠积分'
                                THEN '龙珠积分'
                            WHEN r."item_name" IN ('公会币','公会货币')
                                THEN '公会币'
                            WHEN r."item_name" IN ('组队积分','组队试炼积分')
                                THEN '组队积分'
                            WHEN r."item_name"='英雄精魄'
                                THEN '英雄精魄'
                            WHEN r."item_name"='异能魂晶'
                                THEN '异能魂晶'
                            WHEN r."item_name" IN ('竞技积分','竞技场积分')
                                THEN '竞技积分'
                            WHEN r."item_name" IN ('诡矿积分','矿脉积分')
                                THEN '诡矿积分'
                            WHEN r."item_name" IN ('古墓币','古墓积分')
                                THEN '古墓币'
                            WHEN regexp_like(
                                r."item_name",
                                '1小时.*通用.*加速|通用.*加速.*1小时'
                            )
                                THEN '1小时通用加速'
                            ELSE NULL
                        END "道具",

                        r."单次获取数量",
                        r."变化类型"

                    FROM
                    (
                        SELECT
                            date(e."#event_time") "日期",
                            cast(e."#account_id" AS varchar) "#account_id",
                            cast(e."$part_event" AS varchar) "$part_event",
                            try_cast(e."item_id" AS bigint) "item_id",
                            trim(
                                coalesce(
                                    cast(e."item_name" AS varchar),
                                    ''
                                )
                            ) "item_name",
                            abs(
                                coalesce(
                                    try_cast(e."item_num" AS double),
                                    0
                                )
                            ) "单次获取数量",
                            coalesce(
                                try_cast(e."change_type" AS bigint),
                                CASE
                                    WHEN try_cast(e."item_num" AS double)>0 THEN 1
                                    WHEN try_cast(e."item_num" AS double)<0 THEN 2
                                    ELSE 0
                                END
                            ) "变化类型"

                        FROM ta.v_event_41 e

                        WHERE ${PartDate:date}
                          AND e."domain"='release'
                          AND e."$part_event" IN (
                              'money_log',
                              'item_log',
                              'voucher_log'
                          )
                          AND e."#account_id" IS NOT NULL
                    ) r
                ) s

                WHERE s."道具" IS NOT NULL
                  AND s."变化类型"=1

                GROUP BY 1,2,3
            ) g
                ON a."日期"=g."日期"
               AND a."#account_id"=g."#account_id"
               AND c."道具"=g."道具"
        ) t
    ) u

    GROUP BY 1,2,3,4,5,6

    HAVING sum(
        CASE
            WHEN u."获取数量">0 THEN 1
            ELSE 0
        END
    )>0
) q

ORDER BY
    q."日期",
    q."开服天数",
    q."分层排序",
    q."排序";