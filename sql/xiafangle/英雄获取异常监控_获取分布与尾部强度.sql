-- 下方了｜英雄获取异常监控（获取分布与尾部强度）
-- 版本：v1.0 2026-08-24
-- 事件：role_obtain_log
-- 口径：
-- 1. 最终维度 = 日期 × 开服天数 × 截至当天累计付费分层 × 英雄。
-- 2. 活跃总体 = 当日存在 in_out_log 的角色；日期用于异常定位，开服当天记 D1。
-- 3. 累计付费 = 截至该活跃日（含当天）pay_log.payment / 100；payment>0，不额外限制pay_result。
-- 4. role_obtain_log.role_id 当前实际上报为英雄名。
-- 5. 玩家当天同一英雄获取次数 = role_obtain_log 事件条数。
-- 6. 获取率分母 = 同日期、同开服天数、同累计付费分层的全部活跃玩家。
-- 7. 获取玩家人均、P50/P95/P99只对当天实际获取该英雄的玩家计算。
-- 8. 最大值倍数 = 最大获取次数 / P99获取次数。
-- 9. 当天没有任何获取玩家的英雄组合不输出。

SELECT
    row_number() OVER (
        ORDER BY q."日期", q."开服天数", q."分层排序", q."英雄"
    ) AS "序号",
    q."日期",
    q."开服天数",
    q."累计付费分层",
    q."英雄",
    q."活跃玩家数",
    q."获取玩家数",
    q."获取率",
    q."获取总次数",
    q."获取玩家人均次数",
    q."P50获取次数",
    q."P95获取次数",
    q."P99获取次数",
    q."最大获取次数",
    round(
        q."最大获取次数"
        / nullif(q."P99获取次数", 0),
        2
    ) AS "最大值/P99倍数"

FROM
(
    SELECT
        t."日期",
        t."开服天数",
        t."累计付费分层",
        t."分层排序",
        t."英雄",

        max(t."活跃玩家数") AS "活跃玩家数",

        count(*) AS "获取玩家数",

        round(
            count(*) * 1.0000
            / nullif(max(t."活跃玩家数"), 0),
            4
        ) AS "获取率",

        sum(t."获取次数") AS "获取总次数",

        round(
            avg(cast(t."获取次数" AS double)),
            2
        ) AS "获取玩家人均次数",

        round(
            approx_percentile(
                cast(t."获取次数" AS double),
                0.50
            ),
            2
        ) AS "P50获取次数",

        round(
            approx_percentile(
                cast(t."获取次数" AS double),
                0.95
            ),
            2
        ) AS "P95获取次数",

        round(
            approx_percentile(
                cast(t."获取次数" AS double),
                0.99
            ),
            2
        ) AS "P99获取次数",

        max(t."获取次数") AS "最大获取次数"

    FROM
    (
        SELECT
            a."日期",
            a."开服天数",
            a."#account_id",
            a."累计付费分层",
            a."分层排序",
            a."活跃玩家数",
            g."英雄",
            g."获取次数"

        FROM
        (
            SELECT
                y."日期",
                y."开服天数",
                y."#account_id",
                y."累计付费分层",
                y."分层排序",

                count(*) OVER (
                    PARTITION BY
                        y."日期",
                        y."开服天数",
                        y."累计付费分层",
                        y."分层排序"
                ) AS "活跃玩家数"

            FROM
            (
                SELECT
                    x."日期",
                    x."开服天数",
                    x."#account_id",

                    CASE
                        WHEN x."累计付费金额" = 0
                            THEN 'a_free'
                        WHEN x."累计付费金额" <= 6
                            THEN 'b_(0,6]'
                        WHEN x."累计付费金额" <= 30
                            THEN 'c_(6,30]'
                        WHEN x."累计付费金额" <= 100
                            THEN 'd_(30,100]'
                        WHEN x."累计付费金额" <= 300
                            THEN 'e_(100,300]'
                        WHEN x."累计付费金额" <= 500
                            THEN 'f_(300,500]'
                        WHEN x."累计付费金额" <= 1000
                            THEN 'g_(500,1000]'
                        ELSE 'h_(1000,+)'
                    END AS "累计付费分层",

                    CASE
                        WHEN x."累计付费金额" = 0 THEN 1
                        WHEN x."累计付费金额" <= 6 THEN 2
                        WHEN x."累计付费金额" <= 30 THEN 3
                        WHEN x."累计付费金额" <= 100 THEN 4
                        WHEN x."累计付费金额" <= 300 THEN 5
                        WHEN x."累计付费金额" <= 500 THEN 6
                        WHEN x."累计付费金额" <= 1000 THEN 7
                        ELSE 8
                    END AS "分层排序"

                FROM
                (
                    SELECT
                        a0."日期",
                        a0."开服天数",
                        a0."#account_id",

                        coalesce(
                            sum(pay."当日付费金额"),
                            0
                        ) AS "累计付费金额"

                    FROM
                    (
                        SELECT DISTINCT
                            date(e."#event_time") AS "日期",
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
                    ) a0

                    LEFT JOIN
                    (
                        SELECT
                            cast(e."#account_id" AS varchar) AS "#account_id",
                            date(e."#event_time") AS "付费日期",

                            sum(
                                coalesce(
                                    try_cast(e."payment" AS double),
                                    0
                                )
                            ) / 100.0000 AS "当日付费金额"

                        FROM ta.v_event_41 e

                        WHERE e."domain" = 'release'
                          AND e."$part_event" = 'pay_log'
                          AND e."#account_id" IS NOT NULL
                          AND coalesce(
                                try_cast(e."payment" AS double),
                                0
                              ) > 0

                        GROUP BY
                            1,
                            2
                    ) pay
                        ON a0."#account_id" = pay."#account_id"
                       AND pay."付费日期" <= a0."日期"

                    GROUP BY
                        a0."日期",
                        a0."开服天数",
                        a0."#account_id"
                ) x
            ) y
        ) a

        INNER JOIN
        (
            SELECT
                date(e."#event_time") AS "日期",
                cast(e."#account_id" AS varchar) AS "#account_id",

                trim(
                    cast(e."role_id" AS varchar)
                ) AS "英雄",

                count(*) AS "获取次数"

            FROM ta.v_event_41 e

            WHERE ${PartDate:date}
              AND e."domain" = 'release'
              AND e."$part_event" = 'role_obtain_log'
              AND e."#account_id" IS NOT NULL
              AND e."role_id" IS NOT NULL
              AND trim(cast(e."role_id" AS varchar)) <> ''

            GROUP BY
                date(e."#event_time"),
                cast(e."#account_id" AS varchar),
                trim(cast(e."role_id" AS varchar))
        ) g
            ON a."日期" = g."日期"
           AND a."#account_id" = g."#account_id"
    ) t

    GROUP BY
        t."日期",
        t."开服天数",
        t."累计付费分层",
        t."分层排序",
        t."英雄"
) q

ORDER BY
    q."日期",
    q."开服天数",
    q."分层排序",
    q."英雄";