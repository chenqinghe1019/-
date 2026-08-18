SELECT
    row_number() OVER (
        ORDER BY q."分层排序"
    ) AS "序号",

    q."VIP层级（活动开始前）",
    q."活动活跃人数",
    q."活动参与人数",

    round(
        q."活动参与人数" * 1.0000
        / nullif(q."活动活跃人数", 0),
        4
    ) AS "活动参与率",

    q."活动付费人数",

    round(
        q."活动付费人数" * 1.0000
        / nullif(q."活动参与人数", 0),
        4
    ) AS "活动付费率",

    round(
        q."活动付费金额",
        2
    ) AS "活动付费金额",

    round(
        q."活动付费金额" * 1.0000
        / nullif(q."活动参与人数", 0),
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
            WHEN grouping(p."VIP层级") = 1
                THEN '汇总'
            ELSE p."VIP层级"
        END AS "VIP层级（活动开始前）",

        CASE
            WHEN grouping(p."VIP层级") = 1
                THEN 0
            ELSE p."分层排序"
        END AS "分层排序",

        sum(
            CASE
                WHEN p."是否活动活跃" = 1 THEN 1
                ELSE 0
            END
        ) AS "活动活跃人数",

        sum(
            CASE
                WHEN p."是否参与活动" = 1 THEN 1
                ELSE 0
            END
        ) AS "活动参与人数",

        sum(
            CASE
                WHEN p."是否参与活动" = 1
                 AND p."活动付费金额" > 0
                    THEN 1
                ELSE 0
            END
        ) AS "活动付费人数",

        sum(
            CASE
                WHEN p."是否参与活动" = 1
                    THEN p."活动付费金额"
                ELSE 0
            END
        ) AS "活动付费金额"

    FROM
    (
        SELECT
            x."#account_id",

            CASE
                WHEN coalesce(x."活动开始前VIP等级", 0) BETWEEN 0 AND 3
                    THEN 'a.V0-V3'
                WHEN coalesce(x."活动开始前VIP等级", 0) BETWEEN 4 AND 6
                    THEN 'b.V4-V6'
                WHEN coalesce(x."活动开始前VIP等级", 0) BETWEEN 7 AND 9
                    THEN 'c.V7-V9'
                ELSE 'd.V10+'
            END AS "VIP层级",

            CASE
                WHEN coalesce(x."活动开始前VIP等级", 0) BETWEEN 0 AND 3 THEN 1
                WHEN coalesce(x."活动开始前VIP等级", 0) BETWEEN 4 AND 6 THEN 2
                WHEN coalesce(x."活动开始前VIP等级", 0) BETWEEN 7 AND 9 THEN 3
                ELSE 4
            END AS "分层排序",

            x."是否活动活跃",
            x."是否参与活动",
            x."活动付费金额"

        FROM
        (
            SELECT
                user_cohort."#account_id",

                max(
                    CASE
                        WHEN e."$part_event" = 'in_out_log'
                            THEN 1
                        ELSE 0
                    END
                ) AS "是否活动活跃",

                max(
                    CASE
                        WHEN e."$part_event" = 'mission_reward_log'
                            THEN 1
                        ELSE 0
                    END
                ) AS "是否参与活动",

                sum(
                    CASE
                        WHEN e."$part_event" = 'pay_log'
                         AND product_cfg."product_id" IS NOT NULL
                            THEN
                            (
                                coalesce(
                                    try_cast(e."payment" AS double),
                                    0
                                )
                                +
                                coalesce(
                                    try_cast(e."token_payment" AS double),
                                    0
                                )
                            ) / 100.0000
                        ELSE 0
                    END
                ) AS "活动付费金额",

                max(
                    CASE
                        WHEN e."$part_event" = 'vip_change_log'
                            THEN try_cast(e."after" AS bigint)
                    END
                ) AS "活动开始前VIP等级"

            FROM
            (
                SELECT
                    cast(u."#account_id" AS varchar) AS "#account_id",

                    cast(
                        date_add(
                            'day',
                            activity_param."活动开始天数" - 1,
                            date(u."server_open_time")
                        ) AS timestamp
                    ) AS "活动开始时间",

                    cast(
                        date_add(
                            'day',
                            activity_param."活动结束天数",
                            date(u."server_open_time")
                        ) AS timestamp
                    ) AS "活动结束时间"

                FROM
                (
                    SELECT
                        "#account_id",
                        "server_open_time",
                        cast(date("create_role_time") AS varchar) AS "$part_date"

                    FROM ta.v_user_41

                    WHERE "domain" = 'release'
                      AND "#account_id" IS NOT NULL
                      AND "create_role_time" IS NOT NULL
                      AND "server_open_time" IS NOT NULL
                ) u

                CROSS JOIN
                (
                    SELECT
                        try_cast(
                            regexp_extract(
                                '${Selector:selector2}',
                                '(?i)between *([0-9]+) *and *([0-9]+)',
                                1
                            ) AS bigint
                        ) AS "活动开始天数",

                        try_cast(
                            regexp_extract(
                                '${Selector:selector2}',
                                '(?i)between *([0-9]+) *and *([0-9]+)',
                                2
                            ) AS bigint
                        ) AS "活动结束天数"
                ) activity_param

                WHERE ${PartDate:date2}
            ) user_cohort

            LEFT JOIN
            (
                SELECT
                    cast(e0."#account_id" AS varchar) AS "#account_id",
                    e0."$part_event",
                    e0."#event_time",
                    e0."product_id",
                    e0."payment",
                    e0."token_payment",
                    e0."after"

                FROM ta.v_event_41 e0

                CROSS JOIN
                (
                    SELECT
                        cast(
                            min(date(u0."create_role_time"))
                            AS varchar
                        ) AS "最早扫描日期",

                        cast(
                            max(
                                date_add(
                                    'day',
                                    activity_param0."活动结束天数" - 1,
                                    date(u0."server_open_time")
                                )
                            ) AS varchar
                        ) AS "最晚扫描日期"

                    FROM
                    (
                        SELECT
                            "#account_id",
                            "server_open_time",
                            "create_role_time",
                            cast(date("create_role_time") AS varchar) AS "$part_date"

                        FROM ta.v_user_41

                        WHERE "domain" = 'release'
                          AND "#account_id" IS NOT NULL
                          AND "create_role_time" IS NOT NULL
                          AND "server_open_time" IS NOT NULL
                    ) u0

                    CROSS JOIN
                    (
                        SELECT
                            try_cast(
                                regexp_extract(
                                    '${Selector:selector2}',
                                    '(?i)between *([0-9]+) *and *([0-9]+)',
                                    2
                                ) AS bigint
                            ) AS "活动结束天数"
                    ) activity_param0

                    WHERE ${PartDate:date2}
                ) scan_bounds

                WHERE e0."domain" = 'release'
                  AND e0."#account_id" IS NOT NULL

                  AND e0."$part_event" IN (
                        'in_out_log',
                        'mission_reward_log',
                        'pay_log',
                        'vip_change_log'
                  )

                  AND e0."$part_date"
                      BETWEEN scan_bounds."最早扫描日期"
                          AND scan_bounds."最晚扫描日期"

                  AND
                  (
                        e0."$part_event" IN (
                            'in_out_log',
                            'vip_change_log'
                        )

                        OR

                        (
                            e0."$part_event" = 'mission_reward_log'
                            AND try_cast(e0."task_type" AS bigint)
                                ${Selector:selector}
                        )

                        OR

                        (
                            e0."$part_event" = 'pay_log'
                            AND
                            (
                                coalesce(
                                    try_cast(e0."payment" AS double),
                                    0
                                ) > 0
                                OR
                                coalesce(
                                    try_cast(e0."token_payment" AS double),
                                    0
                                ) > 0
                            )
                        )
                  )
            ) e

                ON e."#account_id" = user_cohort."#account_id"

               AND
               (
                    (
                        e."$part_event" = 'vip_change_log'
                        AND e."#event_time"
                            < user_cohort."活动开始时间"
                    )

                    OR

                    (
                        e."$part_event" IN (
                            'in_out_log',
                            'mission_reward_log',
                            'pay_log'
                        )
                        AND e."#event_time"
                            >= user_cohort."活动开始时间"
                        AND e."#event_time"
                            < user_cohort."活动结束时间"
                    )
               )

            LEFT JOIN
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

                ON e."$part_event" = 'pay_log'
               AND try_cast(e."product_id" AS bigint)
                    = product_cfg."product_id"

            GROUP BY
                1

            HAVING
                max(
                    CASE
                        WHEN e."$part_event" = 'in_out_log'
                            THEN 1
                        WHEN e."$part_event" = 'mission_reward_log'
                            THEN 1
                        WHEN e."$part_event" = 'pay_log'
                         AND product_cfg."product_id" IS NOT NULL
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