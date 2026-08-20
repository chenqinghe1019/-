SELECT
    row_number() OVER (
        ORDER BY
            q."周期排序",
            q."开服天数",
            q."分层排序"
    ) AS "序号",

    q."活动周期",
    q."周期内第几天",
    q."开服天数",
    q."VIP层级（活动开始前）",
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
        p."活动周期",
        p."周期内第几天",
        p."开服天数",

        CASE
            WHEN grouping(p."VIP层级") = 1
                THEN '汇总'
            ELSE p."VIP层级"
        END AS "VIP层级（活动开始前）",

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
            y."周期排序",
            y."活动周期",
            y."周期内第几天",
            y."开服天数",

            CASE
                WHEN coalesce(
                    y."活动开始前VIP等级",
                    0
                ) BETWEEN 0 AND 3
                    THEN 'a.V0-V3'

                WHEN coalesce(
                    y."活动开始前VIP等级",
                    0
                ) BETWEEN 4 AND 6
                    THEN 'b.V4-V6'

                WHEN coalesce(
                    y."活动开始前VIP等级",
                    0
                ) BETWEEN 7 AND 9
                    THEN 'c.V7-V9'

                ELSE 'd.V10+'
            END AS "VIP层级",

            CASE
                WHEN coalesce(
                    y."活动开始前VIP等级",
                    0
                ) BETWEEN 0 AND 3
                    THEN 1

                WHEN coalesce(
                    y."活动开始前VIP等级",
                    0
                ) BETWEEN 4 AND 6
                    THEN 2

                WHEN coalesce(
                    y."活动开始前VIP等级",
                    0
                ) BETWEEN 7 AND 9
                    THEN 3

                ELSE 4
            END AS "分层排序",

            y."是否参与矿脉",
            y."当日活动付费金额"

        FROM
        (
            SELECT
                x."#account_id",
                x."周期排序",
                x."活动周期",
                x."周期内第几天",
                x."开服天数",
                x."活动日期",
                x."是否参与矿脉",
                x."当日活动付费金额",

                max(
                    try_cast(
                        vip_e."after"
                        AS bigint
                    )
                ) AS "活动开始前VIP等级"

            FROM
            (
                SELECT
                    active_user."#account_id",
                    active_user."开服日期",
                    active_user."活动开始时间",
                    active_user."活动结束时间",
                    active_user."活动日期",
                    active_user."开服天数",
                    active_user."周期排序",
                    active_user."活动周期",
                    active_user."周期内第几天",

                    max(
                        CASE
                            WHEN e."$part_event" = 'mining_log'
                                THEN 1
                            ELSE 0
                        END
                    ) AS "是否参与矿脉",

                    sum(
                        CASE
                            WHEN e."$part_event" = 'pay_log'
                             AND product_cfg."product_id" IS NOT NULL
                                THEN
                                (
                                    coalesce(
                                        try_cast(
                                            e."payment"
                                            AS double
                                        ),
                                        0
                                    )
                                    +
                                    coalesce(
                                        try_cast(
                                            e."token_payment"
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
                    SELECT
                        active_day."#account_id",
                        active_day."开服日期",
                        active_day."活动开始时间",
                        active_day."活动结束时间",
                        active_day."活动日期",
                        active_day."开服天数",

                        cast(
                            floor(
                                (
                                    active_day."开服天数"
                                    - active_day."活动开始天数"
                                ) / 3.0000
                            ) + 1
                            AS bigint
                        ) AS "周期排序",

                        concat(
                            '第',
                            cast(
                                cast(
                                    floor(
                                        (
                                            active_day."开服天数"
                                            - active_day."活动开始天数"
                                        ) / 3.0000
                                    ) + 1
                                    AS bigint
                                )
                                AS varchar
                            ),
                            '周期'
                        ) AS "活动周期",

                        mod(
                            active_day."开服天数"
                            - active_day."活动开始天数",
                            3
                        ) + 1 AS "周期内第几天"

                    FROM
                    (
                        SELECT DISTINCT
                            cast(
                                a."#account_id"
                                AS varchar
                            ) AS "#account_id",

                            date(
                                u."server_open_time"
                            ) AS "开服日期",

                            date(
                                a."#event_time"
                            ) AS "活动日期",

                            date_diff(
                                'day',
                                date(
                                    u."server_open_time"
                                ),
                                date(
                                    a."#event_time"
                                )
                            ) + 1 AS "开服天数",

                            activity_param."活动开始天数",

                            cast(
                                date_add(
                                    'day',
                                    activity_param."活动开始天数" - 1,
                                    date(
                                        u."server_open_time"
                                    )
                                )
                                AS timestamp
                            ) AS "活动开始时间",

                            cast(
                                date_add(
                                    'day',
                                    activity_param."活动结束天数",
                                    date(
                                        u."server_open_time"
                                    )
                                )
                                AS timestamp
                            ) AS "活动结束时间"

                        FROM
                        (
                            SELECT
                                "#account_id",
                                "#event_time"

                            FROM ta.v_event_41

                            WHERE ${PartDate:date2}

                              AND "domain"
                                  = 'release'

                              AND "$part_event"
                                  = 'in_out_log'

                              AND "#account_id"
                                  IS NOT NULL
                        ) a

                        INNER JOIN ta.v_user_41 u

                            ON cast(
                                a."#account_id"
                                AS varchar
                            )
                            =
                            cast(
                                u."#account_id"
                                AS varchar
                            )

                        CROSS JOIN
                        (
                            SELECT
                                try_cast(
                                    regexp_extract(
                                        '${Selector:selector2}',
                                        '(?i)between *([0-9]+) *and *([0-9]+)',
                                        1
                                    )
                                    AS bigint
                                ) AS "活动开始天数",

                                try_cast(
                                    regexp_extract(
                                        '${Selector:selector2}',
                                        '(?i)between *([0-9]+) *and *([0-9]+)',
                                        2
                                    )
                                    AS bigint
                                ) AS "活动结束天数"
                        ) activity_param

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

                        WHERE u."domain"
                                = 'release'

                          AND u."server_open_time"
                                IS NOT NULL

                          /* 完整活动周期必须全部落在统计周期内 */
                          AND date_add(
                                'day',
                                activity_param."活动开始天数" - 1,
                                date(
                                    u."server_open_time"
                                )
                              )
                              >= stats_period."统计开始日期"

                          AND date_add(
                                'day',
                                activity_param."活动结束天数" - 1,
                                date(
                                    u."server_open_time"
                                )
                              )
                              <= stats_period."统计结束日期"

                          /* 活跃日必须处于目标活动开服天数 */
                          AND (
                                date_diff(
                                    'day',
                                    date(
                                        u."server_open_time"
                                    ),
                                    date(
                                        a."#event_time"
                                    )
                                ) + 1
                              ) ${Selector:selector2}
                    ) active_day
                ) active_user

                LEFT JOIN
                (
                    SELECT
                        cast(
                            e0."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        e0."$part_event",
                        e0."#event_time",
                        e0."product_id",
                        e0."payment",
                        e0."token_payment"

                    FROM ta.v_event_41 e0

                    WHERE ${PartDate:date2}

                      AND e0."domain"
                          = 'release'

                      AND e0."#account_id"
                          IS NOT NULL

                      AND
                      (
                          e0."$part_event"
                              = 'mining_log'

                          OR

                          (
                              e0."$part_event"
                                  = 'pay_log'

                              AND
                              (
                                  coalesce(
                                      try_cast(
                                          e0."payment"
                                          AS double
                                      ),
                                      0
                                  ) > 0

                                  OR

                                  coalesce(
                                      try_cast(
                                          e0."token_payment"
                                          AS double
                                      ),
                                      0
                                  ) > 0
                              )
                          )
                      )
                ) e

                    ON e."#account_id"
                        = active_user."#account_id"

                   /* 参与与付费均按当天统计 */
                   AND date(
                        e."#event_time"
                       ) = active_user."活动日期"

                   AND e."#event_time"
                        >= active_user."活动开始时间"

                   AND e."#event_time"
                        < active_user."活动结束时间"

                LEFT JOIN
                (
                    SELECT
                        try_cast(
                            "product_id"
                            AS bigint
                        ) AS "product_id"

                    FROM ta_ext.product_id_41

                    WHERE "product_id"
                            IS NOT NULL

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

                    ON e."$part_event"
                        = 'pay_log'

                   AND try_cast(
                        e."product_id"
                        AS bigint
                       )
                       = product_cfg."product_id"

                GROUP BY
                    1,
                    2,
                    3,
                    4,
                    5,
                    6,
                    7,
                    8,
                    9
            ) x

            LEFT JOIN ta.v_event_41 vip_e

                ON cast(
                    vip_e."#account_id"
                    AS varchar
                ) = x."#account_id"

               AND vip_e."$part_event"
                    = 'vip_change_log'

               AND vip_e."domain"
                    = 'release'

               AND vip_e."#event_time"
                    < x."活动开始时间"

               AND vip_e."$part_date"
                    BETWEEN cast(
                        x."开服日期"
                        AS varchar
                    )
                    AND cast(
                        date_add(
                            'day',
                            -1,
                            date(
                                x."活动开始时间"
                            )
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
                7,
                8
        ) y
    ) p

    GROUP BY GROUPING SETS
    (
        (
            p."周期排序",
            p."活动周期",
            p."周期内第几天",
            p."开服天数",
            p."VIP层级",
            p."分层排序"
        ),
        (
            p."周期排序",
            p."活动周期",
            p."周期内第几天",
            p."开服天数"
        )
    )
) q

ORDER BY
    q."周期排序",
    q."开服天数",
    q."分层排序"