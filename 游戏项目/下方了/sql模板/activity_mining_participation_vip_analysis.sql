SELECT
    row_number() OVER (
        ORDER BY
            q."玩法轮次排序",
            q."周期排序",
            q."周期内第几天",
            q."分层排序"
    ) AS "序号",

    q."玩法轮次",
    q."活动周期",
    q."周期内第几天",
    q."VIP层级（周期开始前）",
    q."矿脉参与人数",
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
        / nullif(q."矿脉参与人数", 0),
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
        p."玩法轮次排序",
        p."周期排序",
        p."周期内第几天",

        concat(
            '第',
            cast(p."玩法轮次排序" AS varchar),
            '轮'
        ) AS "玩法轮次",

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

        count(*) AS "矿脉参与人数",

        sum(
            CASE
                WHEN p."当日活动付费金额" > 0
                    THEN 1
                ELSE 0
            END
        ) AS "活动付费人数",

        sum(
            p."当日活动付费金额"
        ) AS "活动付费金额"

    FROM
    (
        SELECT
            y."#account_id",
            y."玩法轮次排序",
            y."周期排序",
            y."周期内第几天",

            CASE
                WHEN coalesce(
                    y."周期开始前VIP等级",
                    0
                ) BETWEEN 0 AND 3
                    THEN 'a.V0-V3'

                WHEN coalesce(
                    y."周期开始前VIP等级",
                    0
                ) BETWEEN 4 AND 6
                    THEN 'b.V4-V6'

                WHEN coalesce(
                    y."周期开始前VIP等级",
                    0
                ) BETWEEN 7 AND 9
                    THEN 'c.V7-V9'

                ELSE 'd.V10+'
            END AS "VIP层级",

            CASE
                WHEN coalesce(
                    y."周期开始前VIP等级",
                    0
                ) BETWEEN 0 AND 3
                    THEN 1

                WHEN coalesce(
                    y."周期开始前VIP等级",
                    0
                ) BETWEEN 4 AND 6
                    THEN 2

                WHEN coalesce(
                    y."周期开始前VIP等级",
                    0
                ) BETWEEN 7 AND 9
                    THEN 3

                ELSE 4
            END AS "分层排序",

            y."当日活动付费金额"

        FROM
        (
            SELECT
                x."#account_id",
                x."玩法轮次排序",
                x."周期排序",
                x."周期内第几天",
                x."参与日期",
                x."周期开始日期",
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
                    participant."#account_id",
                    participant."region_id",
                    participant."玩法轮次排序",
                    participant."周期排序",
                    participant."周期内第几天",
                    participant."参与日期",
                    participant."周期开始日期",
                    user_base."开服日期",

                    sum(
                        CASE
                            WHEN pay_e."#account_id" IS NOT NULL
                             AND product_cfg."product_id" IS NOT NULL
                                THEN
                                (
                                    coalesce(
                                        try_cast(
                                            pay_e."payment"
                                            AS double
                                        ),
                                        0
                                    )
                                    +
                                    coalesce(
                                        try_cast(
                                            pay_e."token_payment"
                                            AS double
                                        ),
                                        0
                                    )
                                ) / 100.0000
                            ELSE 0
                        END
                    ) AS "当日活动付费金额"

                FROM
                (
                    SELECT DISTINCT
                        cast(
                            m."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        cast(
                            m."region_id"
                            AS varchar
                        ) AS "region_id",

                        cycle_map."玩法轮次排序",
                        cycle_map."周期排序",
                        cycle_map."周期内第几天",
                        cycle_map."周期开始日期",
                        date(m."#event_time") AS "参与日期"

                    FROM ta.v_event_41 m

                    INNER JOIN
                    (
                        SELECT
                            cycle_base."region_id",
                            cycle_base."日志日期",
                            cycle_base."玩法轮次排序",
                            cycle_base."周期排序",
                            cycle_base."周期开始日期",

                            date_diff(
                                'day',
                                cycle_base."周期开始日期",
                                cycle_base."日志日期"
                            ) + 1 AS "周期内第几天"

                        FROM
                        (
                            SELECT
                                round_base."region_id",
                                round_base."日志日期",
                                round_base."玩法轮次排序",

                                cast(
                                    floor(
                                        date_diff(
                                            'day',
                                            round_base."轮次开始日期",
                                            round_base."日志日期"
                                        ) / 3.0000
                                    ) + 1
                                    AS bigint
                                ) AS "周期排序",

                                date_add(
                                    'day',
                                    3 *
                                    (
                                        cast(
                                            floor(
                                                date_diff(
                                                    'day',
                                                    round_base."轮次开始日期",
                                                    round_base."日志日期"
                                                ) / 3.0000
                                            ) + 1
                                            AS bigint
                                        ) - 1
                                    ),
                                    round_base."轮次开始日期"
                                ) AS "周期开始日期"

                            FROM
                            (
                                SELECT
                                    round_day."region_id",
                                    round_day."日志日期",
                                    round_day."玩法轮次排序",

                                    min(
                                        round_day."日志日期"
                                    ) OVER (
                                        PARTITION BY
                                            round_day."region_id",
                                            round_day."玩法轮次排序"
                                    ) AS "轮次开始日期"

                                FROM
                                (
                                    SELECT
                                        breakpoint_day."region_id",
                                        breakpoint_day."日志日期",

                                        sum(
                                            breakpoint_day."是否新轮次"
                                        ) OVER (
                                            PARTITION BY
                                                breakpoint_day."region_id"
                                            ORDER BY
                                                breakpoint_day."日志日期"
                                            ROWS BETWEEN UNBOUNDED PRECEDING
                                                AND CURRENT ROW
                                        ) AS "玩法轮次排序"

                                    FROM
                                    (
                                        SELECT
                                            prev_day."region_id",
                                            prev_day."日志日期",

                                            CASE
                                                WHEN prev_day."上一日志日期" IS NULL
                                                    THEN 1

                                                WHEN date_diff(
                                                    'day',
                                                    prev_day."上一日志日期",
                                                    prev_day."日志日期"
                                                ) > 1
                                                    THEN 1

                                                ELSE 0
                                            END AS "是否新轮次"

                                        FROM
                                        (
                                            SELECT
                                                server_day."region_id",
                                                server_day."日志日期",

                                                lag(
                                                    server_day."日志日期"
                                                ) OVER (
                                                    PARTITION BY
                                                        server_day."region_id"
                                                    ORDER BY
                                                        server_day."日志日期"
                                                ) AS "上一日志日期"

                                            FROM
                                            (
                                                SELECT DISTINCT
                                                    cast(
                                                        e0."region_id"
                                                        AS varchar
                                                    ) AS "region_id",

                                                    date(
                                                        e0."#event_time"
                                                    ) AS "日志日期"

                                                FROM ta.v_event_41 e0

                                                WHERE ${PartDate:date2}
                                                  AND e0."domain" = 'release'
                                                  AND e0."$part_event" = 'mining_log'
                                                  AND e0."region_id" IS NOT NULL
                                            ) server_day
                                        ) prev_day
                                    ) breakpoint_day
                                ) round_day
                            ) round_base
                        ) cycle_base

                        CROSS JOIN
                        (
                            SELECT
                                min(
                                    cast(
                                        d."$part_date"
                                        AS date
                                    )
                                ) AS "统计开始日期",

                                max(
                                    cast(
                                        d."$part_date"
                                        AS date
                                    )
                                ) AS "统计结束日期"

                            FROM
                            (
                                SELECT
                                    "$part_date"

                                FROM ta.v_event_41

                                WHERE ${PartDate:date2}
                            ) d
                        ) stats_period

                        /* 仅保留完整3日周期 */
                        WHERE cycle_base."周期开始日期"
                                >= stats_period."统计开始日期"

                          AND date_add(
                                'day',
                                2,
                                cycle_base."周期开始日期"
                              ) <= stats_period."统计结束日期"
                    ) cycle_map

                        ON cast(
                            m."region_id"
                            AS varchar
                           ) = cycle_map."region_id"

                       AND date(
                            m."#event_time"
                           ) = cycle_map."日志日期"

                    WHERE ${PartDate:date2}
                      AND m."domain" = 'release'
                      AND m."$part_event" = 'mining_log'
                      AND m."#account_id" IS NOT NULL
                      AND m."region_id" IS NOT NULL
                ) participant

                INNER JOIN
                (
                    SELECT
                        cast(
                            u."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        max(
                            date(
                                u."server_open_time"
                            )
                        ) AS "开服日期"

                    FROM ta.v_user_41 u

                    WHERE u."domain" = 'release'
                      AND u."#account_id" IS NOT NULL
                      AND u."server_open_time" IS NOT NULL

                    GROUP BY 1
                ) user_base

                    ON participant."#account_id"
                        = user_base."#account_id"

                LEFT JOIN
                (
                    SELECT
                        cast(
                            p0."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        cast(
                            p0."region_id"
                            AS varchar
                        ) AS "region_id",

                        p0."#event_time",
                        p0."product_id",
                        p0."payment",
                        p0."token_payment"

                    FROM ta.v_event_41 p0

                    WHERE ${PartDate:date2}
                      AND p0."domain" = 'release'
                      AND p0."$part_event" = 'pay_log'
                      AND p0."#account_id" IS NOT NULL
                      AND
                      (
                          coalesce(
                              try_cast(
                                  p0."payment"
                                  AS double
                              ),
                              0
                          ) > 0

                          OR

                          coalesce(
                              try_cast(
                                  p0."token_payment"
                                  AS double
                              ),
                              0
                          ) > 0
                      )
                ) pay_e

                    ON pay_e."#account_id"
                        = participant."#account_id"

                   AND coalesce(
                        pay_e."region_id",
                        participant."region_id"
                       ) = participant."region_id"

                   /* 付费与参与按同一天归属 */
                   AND date(
                        pay_e."#event_time"
                       ) = participant."参与日期"

                LEFT JOIN
                (
                    SELECT
                        try_cast(
                            "product_id"
                            AS bigint
                        ) AS "product_id"

                    FROM ta_ext.product_id_41

                    WHERE "product_id" IS NOT NULL
                      AND regexp_like(
                            coalesce(
                                cast(
                                    "product_type_two"
                                    AS varchar
                                ),
                                ''
                            ),
                            '${Selector:selector1}'
                      )

                    GROUP BY 1
                ) product_cfg

                    ON try_cast(
                        pay_e."product_id"
                        AS bigint
                       ) = product_cfg."product_id"

                GROUP BY
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    8
            ) x

            LEFT JOIN ta.v_event_41 vip_e

                ON cast(
                    vip_e."#account_id"
                    AS varchar
                ) = x."#account_id"

               AND vip_e."$part_event" = 'vip_change_log'
               AND vip_e."domain" = 'release'

               /* VIP取该3日周期开始前 */
               AND vip_e."#event_time"
                    < cast(
                        x."周期开始日期"
                        AS timestamp
                    )

               AND vip_e."$part_date"
                    BETWEEN cast(
                        x."开服日期"
                        AS varchar
                    )
                    AND cast(
                        date_add(
                            'day',
                            -1,
                            x."周期开始日期"
                        )
                        AS varchar
                    )

            GROUP BY
                1,
                2,
                3,
                4,
                5,
                6,
                7
        ) y
    ) p

    GROUP BY GROUPING SETS
    (
        (
            p."玩法轮次排序",
            p."周期排序",
            p."周期内第几天",
            p."VIP层级",
            p."分层排序"
        ),
        (
            p."玩法轮次排序",
            p."周期排序",
            p."周期内第几天"
        )
    )
) q

ORDER BY
    q."玩法轮次排序",
    q."周期排序",
    q."周期内第几天",
    q."分层排序"