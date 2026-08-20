SELECT
    row_number() OVER (
        ORDER BY
            q."周期排序",
            q."周期内第几天",
            q."分层排序"
    ) AS "序号",

    q."活动周期",
    q."周期内第几天",
    q."VIP层级（周期开始前）",
    q."活动活跃人数",
    q."矿脉参与人数",

    round(
        q."矿脉参与人数" * 1.0000
        / nullif(q."活动活跃人数", 0),
        4
    ) AS "矿脉参与率",

    q."活动付费人数",

    round(
        q."活动付费人数" * 1.0000
        / nullif(q."矿脉参与人数", 0),
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
        p."周期排序",
        p."周期内第几天",

        concat(
            '第',
            cast(p."周期排序" AS varchar),
            '周期'
        ) AS "活动周期",

        CASE
            WHEN grouping(p."VIP层级") = 1
                THEN '汇总'
            ELSE p."VIP层级"
        END AS "VIP层级（周期开始前）",

        CASE
            WHEN grouping(p."VIP层级") = 1
                THEN 0
            ELSE max(p."分层排序")
        END AS "分层排序",

        count(*) AS "活动活跃人数",

        sum(
            CASE
                WHEN p."是否参与矿脉" = 1
                    THEN 1
                ELSE 0
            END
        ) AS "矿脉参与人数",

        sum(
            CASE
                WHEN p."是否参与矿脉" = 1
                 AND p."当日活动付费金额" > 0
                    THEN 1
                ELSE 0
            END
        ) AS "活动付费人数",

        sum(
            CASE
                WHEN p."是否参与矿脉" = 1
                    THEN p."当日活动付费金额"
                ELSE 0
            END
        ) AS "活动付费金额"

    FROM
    (
        SELECT
            y."#account_id",
            y."region_id",
            y."周期排序",
            y."周期内第几天",

            CASE
                WHEN coalesce(y."周期开始前VIP等级", 0) BETWEEN 0 AND 3
                    THEN 'a.V0-V3'
                WHEN coalesce(y."周期开始前VIP等级", 0) BETWEEN 4 AND 6
                    THEN 'b.V4-V6'
                WHEN coalesce(y."周期开始前VIP等级", 0) BETWEEN 7 AND 9
                    THEN 'c.V7-V9'
                ELSE 'd.V10+'
            END AS "VIP层级",

            CASE
                WHEN coalesce(y."周期开始前VIP等级", 0) BETWEEN 0 AND 3 THEN 1
                WHEN coalesce(y."周期开始前VIP等级", 0) BETWEEN 4 AND 6 THEN 2
                WHEN coalesce(y."周期开始前VIP等级", 0) BETWEEN 7 AND 9 THEN 3
                ELSE 4
            END AS "分层排序",

            y."是否参与矿脉",
            y."当日活动付费金额"

        FROM
        (
            SELECT
                x."#account_id",
                x."region_id",
                x."周期排序",
                x."周期内第几天",
                x."活动日期",
                x."周期开始日期",
                x."是否参与矿脉",
                x."当日活动付费金额",

                max(
                    try_cast(
                        vip_e."after"
                        AS bigint
                    )
                ) AS "周期开始前VIP等级"

            FROM
            (
                SELECT
                    active_player."#account_id",
                    active_player."region_id",
                    active_player."周期排序",
                    active_player."周期内第几天",
                    active_player."活动日期",
                    active_player."周期开始日期",
                    user_base."开服日期",

                    CASE
                        WHEN mining_player."#account_id" IS NOT NULL
                            THEN 1
                        ELSE 0
                    END AS "是否参与矿脉",

                    coalesce(
                        pay_player."当日活动付费金额",
                        0
                    ) AS "当日活动付费金额"

                FROM
                (
                    SELECT DISTINCT
                        cast(a."#account_id" AS varchar) AS "#account_id",
                        cast(a."region_id" AS varchar) AS "region_id",
                        cycle_calendar."周期排序",
                        cycle_calendar."周期开始日期",
                        cycle_calendar."周期内第几天",
                        cycle_calendar."活动日期"

                    FROM ta.v_event_41 a

                    INNER JOIN
                    (
                        SELECT
                            mature_cycle."region_id",
                            mature_cycle."周期排序",
                            mature_cycle."周期开始日期",
                            day_offset."周期日偏移" + 1 AS "周期内第几天",

                            date_add(
                                'day',
                                day_offset."周期日偏移",
                                mature_cycle."周期开始日期"
                            ) AS "活动日期"

                        FROM
                        (
                            SELECT
                                cycle_start."region_id",
                                cycle_start."周期排序",
                                cycle_start."周期开始日期"

                            FROM
                            (
                                SELECT
                                    cycle_mark."region_id",
                                    cycle_mark."日志日期" AS "周期开始日期",

                                    sum(
                                        cycle_mark."是否新周期"
                                    ) OVER (
                                        PARTITION BY cycle_mark."region_id"
                                        ORDER BY cycle_mark."日志日期"
                                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                    ) AS "周期排序",

                                    cycle_mark."是否新周期"

                                FROM
                                (
                                    SELECT
                                        prev_day."region_id",
                                        prev_day."日志日期",

                                        CASE
                                            WHEN prev_day."上一日志日期" IS NULL
                                                THEN 1

                                            /*
                                             * 单期固定3天。
                                             * 周期内即使某天没人产生mining_log，
                                             * 也不能因此切断。
                                             * 相邻mining_log间隔超过3天才认为新一期。
                                             */
                                            WHEN date_diff(
                                                'day',
                                                prev_day."上一日志日期",
                                                prev_day."日志日期"
                                            ) > 3
                                                THEN 1

                                            ELSE 0
                                        END AS "是否新周期"

                                    FROM
                                    (
                                        SELECT
                                            server_day."region_id",
                                            server_day."日志日期",

                                            lag(
                                                server_day."日志日期"
                                            ) OVER (
                                                PARTITION BY server_day."region_id"
                                                ORDER BY server_day."日志日期"
                                            ) AS "上一日志日期"

                                        FROM
                                        (
                                            SELECT DISTINCT
                                                cast(m."region_id" AS varchar) AS "region_id",
                                                date(m."#event_time") AS "日志日期"

                                            FROM ta.v_event_41 m

                                            WHERE ${PartDate:date2}
                                              AND m."domain" = 'release'
                                              AND m."$part_event" = 'mining_log'
                                              AND m."region_id" IS NOT NULL
                                        ) server_day
                                    ) prev_day
                                ) cycle_mark
                            ) cycle_start

                            CROSS JOIN
                            (
                                SELECT
                                    min(cast(d."$part_date" AS date)) AS "统计开始日期",
                                    max(cast(d."$part_date" AS date)) AS "统计结束日期"

                                FROM
                                (
                                    SELECT "$part_date"
                                    FROM ta.v_event_41
                                    WHERE ${PartDate:date2}
                                ) d
                            ) stats_period

                            WHERE cycle_start."是否新周期" = 1

                              /*
                               * 完整3日周期只看查询日期是否覆盖：
                               * 周期开始日、开始日+1、开始日+2。
                               * 不要求后两日实际存在mining_log。
                               */
                              AND cycle_start."周期开始日期"
                                    >= stats_period."统计开始日期"

                              AND date_add(
                                    'day',
                                    2,
                                    cycle_start."周期开始日期"
                                  )
                                  <= stats_period."统计结束日期"
                        ) mature_cycle

                        CROSS JOIN UNNEST(
                            sequence(0, 2)
                        ) AS day_offset("周期日偏移")
                    ) cycle_calendar

                        ON cast(a."region_id" AS varchar)
                            = cycle_calendar."region_id"

                       AND date(a."#event_time")
                            = cycle_calendar."活动日期"

                    WHERE ${PartDate:date2}
                      AND a."domain" = 'release'
                      AND a."$part_event" = 'in_out_log'
                      AND a."#account_id" IS NOT NULL
                      AND a."region_id" IS NOT NULL
                ) active_player

                INNER JOIN
                (
                    SELECT
                        cast(u."#account_id" AS varchar) AS "#account_id",
                        max(date(u."server_open_time")) AS "开服日期"

                    FROM ta.v_user_41 u

                    WHERE u."domain" = 'release'
                      AND u."#account_id" IS NOT NULL
                      AND u."server_open_time" IS NOT NULL

                    GROUP BY 1
                ) user_base

                    ON active_player."#account_id"
                        = user_base."#account_id"

                LEFT JOIN
                (
                    SELECT DISTINCT
                        cast(m0."#account_id" AS varchar) AS "#account_id",
                        cast(m0."region_id" AS varchar) AS "region_id",
                        date(m0."#event_time") AS "参与日期"

                    FROM ta.v_event_41 m0

                    WHERE ${PartDate:date2}
                      AND m0."domain" = 'release'
                      AND m0."$part_event" = 'mining_log'
                      AND m0."#account_id" IS NOT NULL
                      AND m0."region_id" IS NOT NULL
                ) mining_player

                    ON mining_player."#account_id"
                        = active_player."#account_id"

                   AND mining_player."region_id"
                        = active_player."region_id"

                   AND mining_player."参与日期"
                        = active_player."活动日期"

                LEFT JOIN
                (
                    SELECT
                        cast(p0."#account_id" AS varchar) AS "#account_id",
                        cast(p0."region_id" AS varchar) AS "region_id",
                        date(p0."#event_time") AS "付费日期",

                        sum(
                            (
                                coalesce(
                                    try_cast(p0."payment" AS double),
                                    0
                                )
                                +
                                coalesce(
                                    try_cast(p0."token_payment" AS double),
                                    0
                                )
                            ) / 100.0000
                        ) AS "当日活动付费金额"

                    FROM ta.v_event_41 p0

                    INNER JOIN
                    (
                        SELECT
                            try_cast("product_id" AS bigint) AS "product_id"

                        FROM ta_ext.product_id_41

                        WHERE "product_id" IS NOT NULL
                          AND regexp_like(
                                coalesce(
                                    cast("product_type_two" AS varchar),
                                    ''
                                ),
                                '${Selector:selector1}'
                          )

                        GROUP BY 1
                    ) product_cfg

                        ON try_cast(p0."product_id" AS bigint)
                            = product_cfg."product_id"

                    WHERE ${PartDate:date2}
                      AND p0."domain" = 'release'
                      AND p0."$part_event" = 'pay_log'
                      AND p0."#account_id" IS NOT NULL
                      AND p0."region_id" IS NOT NULL

                      AND
                      (
                          coalesce(
                              try_cast(p0."payment" AS double),
                              0
                          ) > 0

                          OR

                          coalesce(
                              try_cast(p0."token_payment" AS double),
                              0
                          ) > 0
                      )

                    GROUP BY
                        1,
                        2,
                        3
                ) pay_player

                    ON pay_player."#account_id"
                        = active_player."#account_id"

                   AND pay_player."region_id"
                        = active_player."region_id"

                   AND pay_player."付费日期"
                        = active_player."活动日期"
            ) x

            LEFT JOIN ta.v_event_41 vip_e

                ON cast(vip_e."#account_id" AS varchar)
                    = x."#account_id"

               AND cast(vip_e."region_id" AS varchar)
                    = x."region_id"

               AND vip_e."$part_event" = 'vip_change_log'
               AND vip_e."domain" = 'release'

               AND vip_e."#event_time"
                    < cast(x."周期开始日期" AS timestamp)

               AND vip_e."$part_date"
                    BETWEEN cast(x."开服日期" AS varchar)
                    AND cast(
                        date_add(
                            'day',
                            -1,
                            x."周期开始日期"
                        ) AS varchar
                    )

            GROUP BY
                1,
                2,
                3,
                4,
                5,
                6,
                7,
                8
        ) y
    ) p

    GROUP BY GROUPING SETS
    (
        (
            p."周期排序",
            p."周期内第几天",
            p."VIP层级",
            p."分层排序"
        ),
        (
            p."周期排序",
            p."周期内第几天"
        )
    )
) q

ORDER BY
    q."周期排序",
    q."周期内第几天",
    q."分层排序"