SELECT
    row_number() OVER (
        ORDER BY q."分层排序"
    ) AS "序号",

    q."VIP层级（活动开始前）",
    q."活动活跃人数",
    q."活动付费人数",

    round(
        q."活动付费人数" * 1.0000
        / nullif(q."活动活跃人数", 0),
        4
    ) AS "活动付费率",

    round(q."活动付费金额", 2) AS "活动付费金额",

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
            WHEN grouping(p."VIP层级") = 1 THEN '汇总'
            ELSE p."VIP层级"
        END AS "VIP层级（活动开始前）",

        CASE
            WHEN grouping(p."VIP层级") = 1 THEN 99
            ELSE max(p."分层排序")
        END AS "分层排序",

        sum(p."活动活跃标记") AS "活动活跃人数",
        sum(p."活动付费标记") AS "活动付费人数",
        sum(p."活动付费金额") AS "活动付费金额"

    FROM
    (
        SELECT
            x."#account_id",

            CASE
                WHEN x."活动前历史累充" >= 9000 THEN 'd.V10+'
                WHEN x."活动前历史累充" >= 2000 THEN 'c.V7-V9'
                WHEN x."活动前历史累充" >= 200 THEN 'b.V4-V6'
                ELSE 'a.V0-V3'
            END AS "VIP层级",

            CASE
                WHEN x."活动前历史累充" >= 9000 THEN 4
                WHEN x."活动前历史累充" >= 2000 THEN 3
                WHEN x."活动前历史累充" >= 200 THEN 2
                ELSE 1
            END AS "分层排序",

            x."活动活跃标记",
            x."活动付费标记",
            x."活动付费金额"

        FROM
        (
            SELECT
                user_base."#account_id",

                sum(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND date(e."#event_time")
                             BETWEEN user_base."开服日期"
                                 AND date_add('day', 4, user_base."开服日期")
                         AND coalesce(try_cast(e."payment" AS double), 0) > 0
                            THEN coalesce(try_cast(e."payment" AS double), 0) / 100.0000
                        ELSE 0
                    END
                ) AS "活动前历史累充",

                max(
                    CASE
                        WHEN e."$part_event" = 'log_in_out'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 5, user_base."开服日期")
                                 AND date_add('day', 10, user_base."开服日期")
                            THEN 1
                        ELSE 0
                    END
                ) AS "活动活跃标记",

                max(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 5, user_base."开服日期")
                                 AND date_add('day', 10, user_base."开服日期")
                         AND try_cast(e."product_id" AS bigint) IN
                             (20002, 20003, 690, 20007, 20008, 20010)
                            THEN 1
                        ELSE 0
                    END
                ) AS "活动付费标记",

                sum(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 5, user_base."开服日期")
                                 AND date_add('day', 10, user_base."开服日期")
                            THEN
                            CASE try_cast(e."product_id" AS bigint)
                                WHEN 20002 THEN 1200 / 100.0000
                                WHEN 20003 THEN 3000 / 100.0000
                                WHEN 690   THEN 6800 / 100.0000
                                WHEN 20007 THEN 19800 / 100.0000
                                WHEN 20008 THEN 32800 / 100.0000
                                WHEN 20010 THEN 64800 / 100.0000
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

                WHERE date_add('day', 5, u0."开服日期")
                        >= stats_period."统计开始日期"
                  AND date_add('day', 10, u0."开服日期")
                        <= stats_period."统计结束日期"
            ) user_base

            INNER JOIN ta.v_event_22 e
                ON cast(e."#account_id" AS varchar) = user_base."#account_id"
               AND cast(e."$part_date" AS date)
                   BETWEEN user_base."开服日期"
                       AND date_add('day', 10, user_base."开服日期")

            WHERE e."domain" = 'release'
              AND e."#account_id" IS NOT NULL
              AND e."$part_event" IN ('pay_log', 'log_in_out')

            GROUP BY
                user_base."#account_id",
                user_base."开服日期"

            HAVING
                max(
                    CASE
                        WHEN e."$part_event" = 'log_in_out'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 5, user_base."开服日期")
                                 AND date_add('day', 10, user_base."开服日期")
                            THEN 1
                        ELSE 0
                    END
                ) = 1
                OR
                max(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND date(e."#event_time")
                             BETWEEN date_add('day', 5, user_base."开服日期")
                                 AND date_add('day', 10, user_base."开服日期")
                         AND try_cast(e."product_id" AS bigint) IN
                             (20002, 20003, 690, 20007, 20008, 20010)
                            THEN 1
                        ELSE 0
                    END
                ) = 1
        ) x
    ) p

    GROUP BY GROUPING SETS
    (
        (p."VIP层级", p."分层排序"),
        ()
    )
) q

ORDER BY q."分层排序"