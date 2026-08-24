-- 下方了｜英雄获取分布检测：开服天数 × 截至当天累计付费分层 × 英雄
-- 事件：role_obtain_log
-- 日期：2026-08-24
--
-- 口径：
-- 1. ${PartDate:date} 仅控制统计周期，日期只用于内部关联，不作为最终展示/分组维度。
-- 2. 开服天数 = 活跃日期 - server_open_time + 1，开服当天记 D1。
-- 3. 每个开服天数下，存在 in_out_log 的角色作为活跃总体。
-- 4. 累计付费 = 截至该活跃日（含当天）的 pay_log.payment / 100，按角色累计；payment > 0，不额外限制 pay_result。
-- 5. 累计付费分层：0、(0,6]、(6,30]、(30,100]、(100,300]、(300,500]、(500,1000]、1000+。
-- 6. role_obtain_log.role_id 当前实际上报为英雄名。
-- 7. 玩家当天同一英雄的获取次数 = role_obtain_log 事件条数。
-- 8. 活跃但未获取该英雄的玩家补 0 后参与人均、最小值、P25、P50、P75、最大值计算。
-- 9. 获取率 = 获取玩家数 * 1.0000 / 活跃玩家数，不乘100。
-- 10. 英雄集合取查询周期内 role_obtain_log 中出现过的全部 role_id。

SELECT
    row_number() OVER (
        ORDER BY q."开服天数", q."分层排序", q."英雄"
    ) AS "序号",
    q."开服天数",
    q."累计付费分层",
    q."英雄",
    q."活跃玩家数",
    q."获取玩家数",
    q."获取率",
    q."获取总次数",
    q."人均获取次数",
    q."最小获取次数",
    q."P25获取次数",
    q."P50获取次数",
    q."P75获取次数",
    q."最大获取次数"
FROM
(
    SELECT
        t."开服天数",
        t."累计付费分层",
        t."分层排序",
        t."英雄",

        count(*) AS "活跃玩家数",

        sum(
            CASE
                WHEN t."获取次数" > 0 THEN 1
                ELSE 0
            END
        ) AS "获取玩家数",

        round(
            sum(
                CASE
                    WHEN t."获取次数" > 0 THEN 1
                    ELSE 0
                END
            ) * 1.0000
            / nullif(count(*), 0),
            4
        ) AS "获取率",

        sum(t."获取次数") AS "获取总次数",

        round(
            avg(
                cast(t."获取次数" AS double)
            ),
            2
        ) AS "人均获取次数",

        min(t."获取次数") AS "最小获取次数",

        round(
            approx_percentile(
                cast(t."获取次数" AS double),
                0.25
            ),
            2
        ) AS "P25获取次数",

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
                0.75
            ),
            2
        ) AS "P75获取次数",

        max(t."获取次数") AS "最大获取次数"

    FROM
    (
        SELECT
            a."日期",
            a."开服天数",
            a."#account_id",
            a."累计付费分层",
            a."分层排序",
            h."英雄",

            coalesce(
                g."获取次数",
                0
            ) AS "获取次数"

        FROM
        (
            SELECT
                x."日期",
                x."开服天数",
                x."#account_id",
                x."累计付费金额",

                CASE
                    WHEN x."累计付费金额" = 0
                        THEN 'a_free'

                    WHEN x."累计付费金额" > 0
                     AND x."累计付费金额" <= 6
                        THEN 'b_(0,6]'

                    WHEN x."累计付费金额" > 6
                     AND x."累计付费金额" <= 30
                        THEN 'c_(6,30]'

                    WHEN x."累计付费金额" > 30
                     AND x."累计付费金额" <= 100
                        THEN 'd_(30,100]'

                    WHEN x."累计付费金额" > 100
                     AND x."累计付费金额" <= 300
                        THEN 'e_(100,300]'

                    WHEN x."累计付费金额" > 300
                     AND x."累计付费金额" <= 500
                        THEN 'f_(300,500]'

                    WHEN x."累计付费金额" > 500
                     AND x."累计付费金额" <= 1000
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
                        date(
                            cast(e."$part_date" AS varchar)
                        ) AS "日期",

                        cast(
                            e."#account_id" AS varchar
                        ) AS "#account_id",

                        date_diff(
                            'day',
                            date(u."server_open_time"),
                            date(cast(e."$part_date" AS varchar))
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
                      AND date(cast(e."$part_date" AS varchar))
                          >= date(u."server_open_time")
                ) a0

                LEFT JOIN
                (
                    SELECT
                        cast(
                            e."#account_id" AS varchar
                        ) AS "#account_id",

                        date(
                            cast(e."$part_date" AS varchar)
                        ) AS "付费日期",

                        sum(
                            coalesce(
                                try_cast(
                                    e."payment" AS double
                                ),
                                0
                            )
                        ) / 100.0000 AS "当日付费金额"

                    FROM ta.v_event_41 e

                    WHERE e."domain" = 'release'
                      AND e."$part_event" = 'pay_log'
                      AND e."#account_id" IS NOT NULL
                      AND coalesce(
                            try_cast(
                                e."payment" AS double
                            ),
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
        ) a

        CROSS JOIN
        (
            SELECT DISTINCT
                trim(
                    cast(
                        e."role_id" AS varchar
                    )
                ) AS "英雄"

            FROM ta.v_event_41 e

            WHERE ${PartDate:date}
              AND e."domain" = 'release'
              AND e."$part_event" = 'role_obtain_log'
              AND e."role_id" IS NOT NULL
              AND trim(
                    cast(
                        e."role_id" AS varchar
                    )
                  ) <> ''
        ) h

        LEFT JOIN
        (
            SELECT
                date(
                    cast(e."$part_date" AS varchar)
                ) AS "日期",

                cast(
                    e."#account_id" AS varchar
                ) AS "#account_id",

                trim(
                    cast(
                        e."role_id" AS varchar
                    )
                ) AS "英雄",

                count(*) AS "获取次数"

            FROM ta.v_event_41 e

            WHERE ${PartDate:date}
              AND e."domain" = 'release'
              AND e."$part_event" = 'role_obtain_log'
              AND e."#account_id" IS NOT NULL
              AND e."role_id" IS NOT NULL
              AND trim(
                    cast(
                        e."role_id" AS varchar
                    )
                  ) <> ''

            GROUP BY
                date(cast(e."$part_date" AS varchar)),
                cast(e."#account_id" AS varchar),
                trim(cast(e."role_id" AS varchar))
        ) g
            ON a."日期" = g."日期"
           AND a."#account_id" = g."#account_id"
           AND h."英雄" = g."英雄"
    ) t

    GROUP BY
        t."开服天数",
        t."累计付费分层",
        t."分层排序",
        t."英雄"
) q

ORDER BY
    q."开服天数",
    q."分层排序",
    q."英雄";