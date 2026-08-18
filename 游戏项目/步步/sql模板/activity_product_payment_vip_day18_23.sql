SELECT
    row_number() OVER (
        ORDER BY q."排序"
    ) AS "序号",

    q."VIP等级",
    q."活动活跃人数",
    q."活动付费人数",

    round(
        q."活动付费人数" * 1.0000
        / nullif(q."活动活跃人数", 0),
        4
    ) AS "活动付费率",

    round(
        q."活动付费金额",
        2
    ) AS "活动付费金额",

    round(
        q."活动付费金额" * 1.0000
        / nullif(q."活动活跃人数", 0),
        2
    ) AS "活动ARPU",

    round(
        q."活动付费金额" * 1.0000
        / nullif(q."活动付费人数", 0),
        2
    ) AS "活动ARPPU"

FROM
(
    SELECT
        CASE
            WHEN grouping(p."VIP等级") = 1
                THEN '汇总'
            ELSE p."VIP等级"
        END AS "VIP等级",

        CASE
            WHEN grouping(p."VIP等级") = 1
                THEN 99
            ELSE max(p."VIP排序")
        END AS "排序",

        sum(p."活动活跃标记") AS "活动活跃人数",
        sum(p."活动付费标记") AS "活动付费人数",
        sum(p."活动付费金额") AS "活动付费金额"

    FROM
    (
        SELECT
            x."#account_id",

            CASE
                WHEN x."活动前VIP经验" >= 700000 THEN 'V16'
                WHEN x."活动前VIP经验" >= 500000 THEN 'V15'
                WHEN x."活动前VIP经验" >= 350000 THEN 'V14'
                WHEN x."活动前VIP经验" >= 250000 THEN 'V13'
                WHEN x."活动前VIP经验" >= 180000 THEN 'V12'
                WHEN x."活动前VIP经验" >= 120000 THEN 'V11'
                WHEN x."活动前VIP经验" >= 90000  THEN 'V10'
                WHEN x."活动前VIP经验" >= 60000  THEN 'V9'
                WHEN x."活动前VIP经验" >= 40000  THEN 'V8'
                WHEN x."活动前VIP经验" >= 20000  THEN 'V7'
                WHEN x."活动前VIP经验" >= 10000  THEN 'V6'
                WHEN x."活动前VIP经验" >= 5000   THEN 'V5'
                WHEN x."活动前VIP经验" >= 2000   THEN 'V4'
                WHEN x."活动前VIP经验" >= 900    THEN 'V3'
                WHEN x."活动前VIP经验" >= 300    THEN 'V2'
                WHEN x."活动前VIP经验" >= 60     THEN 'V1'
                ELSE 'V0'
            END AS "VIP等级",

            CASE
                WHEN x."活动前VIP经验" >= 700000 THEN 16
                WHEN x."活动前VIP经验" >= 500000 THEN 15
                WHEN x."活动前VIP经验" >= 350000 THEN 14
                WHEN x."活动前VIP经验" >= 250000 THEN 13
                WHEN x."活动前VIP经验" >= 180000 THEN 12
                WHEN x."活动前VIP经验" >= 120000 THEN 11
                WHEN x."活动前VIP经验" >= 90000  THEN 10
                WHEN x."活动前VIP经验" >= 60000  THEN 9
                WHEN x."活动前VIP经验" >= 40000  THEN 8
                WHEN x."活动前VIP经验" >= 20000  THEN 7
                WHEN x."活动前VIP经验" >= 10000  THEN 6
                WHEN x."活动前VIP经验" >= 5000   THEN 5
                WHEN x."活动前VIP经验" >= 2000   THEN 4
                WHEN x."活动前VIP经验" >= 900    THEN 3
                WHEN x."活动前VIP经验" >= 300    THEN 2
                WHEN x."活动前VIP经验" >= 60     THEN 1
                ELSE 0
            END AS "VIP排序",

            x."活动活跃标记",
            x."活动付费标记",
            x."活动付费金额"

        FROM
        (
            SELECT
                user_base."#account_id",

                /*
                 * 活动开启前历史累充：开服第1~17自然日
                 * payment为分，先/100转元，再按1元=10经验换算
                 * 不限制pay_result，仅统计payment>0
                 */
                sum(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND date(e."#event_time")
                             BETWEEN user_base."开服日期"
                                 AND date_add('day', 16, user_base."开服日期")
                         AND coalesce(try_cast(e."payment" AS double), 0) > 0
                        THEN coalesce(try_cast(e."payment" AS double), 0)
                             / 100.0000 * 10
                        ELSE 0
                    END
                ) AS "活动前VIP经验",

                max(
                    CASE
                        WHEN e."$part_event" = 'log_in_out'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 17, user_base."开服日期")
                                 AND date_add('day', 22, user_base."开服日期")
                        THEN 1
                        ELSE 0
                    END
                ) AS "活动活跃标记",

                max(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 17, user_base."开服日期")
                                 AND date_add('day', 22, user_base."开服日期")
                         AND try_cast(e."product_id" AS bigint) IN
                             (20031,20032,20033,20034,20035,20036)
                        THEN 1
                        ELSE 0
                    END
                ) AS "活动付费标记",

                sum(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 17, user_base."开服日期")
                                 AND date_add('day', 22, user_base."开服日期")
                        THEN
                            CASE try_cast(e."product_id" AS bigint)
                                WHEN 20031 THEN 600 / 100.0000
                                WHEN 20032 THEN 1200 / 100.0000
                                WHEN 20033 THEN 3000 / 100.0000
                                WHEN 20034 THEN 12800 / 100.0000
                                WHEN 20035 THEN 32800 / 100.0000
                                WHEN 20036 THEN 64800 / 100.0000
                                ELSE 0
                            END
                        ELSE 0
                    END
                ) AS "活动付费金额"

            FROM
            (
                SELECT
                    u0."#account_id",
                    u0."开服日期"

                FROM
                (
                    SELECT
                        cast(u."#account_id" AS varchar) AS "#account_id",
                        max(date(u."server_open_time")) AS "开服日期"

                    FROM ta.v_user_22 u

                    WHERE u."domain" = 'release'
                      AND u."#account_id" IS NOT NULL
                      AND u."server_open_time" IS NOT NULL

                    GROUP BY 1
                ) u0

                CROSS JOIN
                (
                    SELECT
                        min(cast(d."$part_date" AS date)) AS "统计开始日期",
                        max(cast(d."$part_date" AS date)) AS "统计结束日期"

                    FROM
                    (
                        SELECT "$part_date"
                        FROM ta.v_event_22
                        WHERE ${PartDate:date2}
                    ) d
                ) stats_period

                /* 只保留开服第18~23天完整落在统计周期内的成熟区服 */
                WHERE date_add('day', 17, u0."开服日期")
                          >= stats_period."统计开始日期"
                  AND date_add('day', 22, u0."开服日期")
                          <= stats_period."统计结束日期"
            ) user_base

            INNER JOIN ta.v_event_22 e
                ON cast(e."#account_id" AS varchar)
                    = user_base."#account_id"

               /* 扫描开服第1~23天，既取活动前累充，也取活动期活跃/付费 */
               AND cast(e."$part_date" AS date)
                    BETWEEN user_base."开服日期"
                        AND date_add('day', 22, user_base."开服日期")

            WHERE e."domain" = 'release'
              AND e."#account_id" IS NOT NULL
              AND e."$part_event" IN ('pay_log', 'log_in_out')

            GROUP BY
                user_base."#account_id",
                user_base."开服日期"

            /* 只保留活动期有活跃或目标商品付费的角色 */
            HAVING
                max(
                    CASE
                        WHEN e."$part_event" = 'log_in_out'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 17, user_base."开服日期")
                                 AND date_add('day', 22, user_base."开服日期")
                        THEN 1 ELSE 0
                    END
                ) = 1
                OR
                max(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 17, user_base."开服日期")
                                 AND date_add('day', 22, user_base."开服日期")
                         AND try_cast(e."product_id" AS bigint) IN
                             (20031,20032,20033,20034,20035,20036)
                        THEN 1 ELSE 0
                    END
                ) = 1
        ) x
    ) p

    GROUP BY GROUPING SETS
    (
        (p."VIP等级", p."VIP排序"),
        ()
    )
) q

ORDER BY q."排序"