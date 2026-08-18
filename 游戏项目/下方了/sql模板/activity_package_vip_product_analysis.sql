SELECT
    row_number() OVER (
        ORDER BY
            q."分层排序",
            q."礼包类型",
            q."礼包名"
    ) AS "序号",

    q."VIP层级（活动开始前）",
    q."礼包类型",
    q."礼包名",
    q."活动活跃人数",
    q."付费人数",

    round(
        q."付费人数" * 1.0000
        / nullif(q."活动活跃人数", 0),
        4
    ) AS "活跃购买率",

    q."购买次数",

    round(
        q."购买次数" * 1.0000
        / nullif(q."付费人数", 0),
        2
    ) AS "人均购买次数",

    round(
        q."付费金额",
        2
    ) AS "付费金额",

    round(
        q."付费金额" * 1.0000
        / nullif(
            sum(q."付费金额") OVER (
                PARTITION BY
                    q."VIP层级（活动开始前）",
                    q."礼包类型"
            ),
            0
        ),
        4
    ) AS "付费金额占比（层内）",

    round(
        q."付费金额" * 1.0000
        / nullif(q."付费人数", 0),
        2
    ) AS "人均付费金额"

FROM
(
    SELECT
        r."VIP层级（活动开始前）",
        r."分层排序",
        r."礼包类型",
        r."礼包名",

        max(
            r."层内活动活跃人数"
        ) AS "活动活跃人数",

        count(*) AS "付费人数",

        sum(
            r."购买次数"
        ) AS "购买次数",

        sum(
            r."付费金额"
        ) AS "付费金额"

    FROM
    (
        SELECT
            s.*,

            sum(
                CASE
                    WHEN s."礼包类型" IS NULL
                     AND s."是否活动活跃" = 1
                        THEN 1
                    ELSE 0
                END
            ) OVER (
                PARTITION BY s."VIP层级（活动开始前）"
            ) AS "层内活动活跃人数"

        FROM
        (
            SELECT
                g."#account_id",

                CASE
                    WHEN coalesce(
                        g."活动开始前VIP等级",
                        0
                    ) BETWEEN 0 AND 3
                        THEN 'a.V0-V3'

                    WHEN coalesce(
                        g."活动开始前VIP等级",
                        0
                    ) BETWEEN 4 AND 6
                        THEN 'b.V4-V6'

                    WHEN coalesce(
                        g."活动开始前VIP等级",
                        0
                    ) BETWEEN 7 AND 9
                        THEN 'c.V7-V9'

                    ELSE 'd.V10+'
                END AS "VIP层级（活动开始前）",

                CASE
                    WHEN coalesce(
                        g."活动开始前VIP等级",
                        0
                    ) BETWEEN 0 AND 3
                        THEN 1

                    WHEN coalesce(
                        g."活动开始前VIP等级",
                        0
                    ) BETWEEN 4 AND 6
                        THEN 2

                    WHEN coalesce(
                        g."活动开始前VIP等级",
                        0
                    ) BETWEEN 7 AND 9
                        THEN 3

                    ELSE 4
                END AS "分层排序",

                g."是否活动活跃",
                g."礼包类型",
                g."礼包名",
                g."购买次数",
                g."付费金额"

            FROM
            (
                SELECT
                    d."#account_id",
                    d."活动开始前VIP等级",
                    d."是否活动活跃",
                    d."礼包类型",
                    d."礼包名",

                    sum(
                        CASE
                            WHEN d."是否有效礼包付费" = 1
                                THEN 1
                            ELSE 0
                        END
                    ) AS "购买次数",

                    sum(
                        CASE
                            WHEN d."是否有效礼包付费" = 1
                                THEN d."单笔付费金额"
                            ELSE 0
                        END
                    ) AS "付费金额"

                FROM
                (
                    SELECT
                        base."#account_id",
                        base."$part_event",
                        base."礼包类型",
                        base."礼包名",

                        max(
                            CASE
                                WHEN base."$part_event" = 'vip_change_log'
                                    THEN try_cast(
                                        base."after"
                                        AS bigint
                                    )
                            END
                        ) OVER (
                            PARTITION BY base."#account_id"
                        ) AS "活动开始前VIP等级",

                        max(
                            CASE
                                WHEN base."$part_event" = 'in_out_log'
                                    THEN 1
                                ELSE 0
                            END
                        ) OVER (
                            PARTITION BY base."#account_id"
                        ) AS "是否活动活跃",

                        CASE
                            WHEN base."$part_event" = 'pay_log'
                             AND base."礼包类型" IS NOT NULL
                             AND (
                                coalesce(
                                    try_cast(
                                        base."payment"
                                        AS double
                                    ),
                                    0
                                ) > 0

                                OR

                                coalesce(
                                    try_cast(
                                        base."token_payment"
                                        AS double
                                    ),
                                    0
                                ) > 0
                             )
                                THEN 1
                            ELSE 0
                        END AS "是否有效礼包付费",

                        (
                            coalesce(
                                try_cast(
                                    base."payment"
                                    AS double
                                ),
                                0
                            )
                            +
                            coalesce(
                                try_cast(
                                    base."token_payment"
                                    AS double
                                ),
                                0
                            )
                        ) / 100.0000 AS "单笔付费金额"

                    FROM
                    (
                        SELECT
                            user_cohort."#account_id",
                            e."$part_event",
                            e."#event_time",
                            e."payment",
                            e."token_payment",
                            e."after",
                            product_cfg."product_type_two" AS "礼包类型",
                            product_cfg."product_name" AS "礼包名"

                        FROM
                        (
                            SELECT
                                cast(
                                    u."#account_id"
                                    AS varchar
                                ) AS "#account_id",

                                cast(
                                    date_add(
                                        'day',
                                        activity_param."活动开始天数" - 1,
                                        date(u."server_open_time")
                                    )
                                    AS timestamp
                                ) AS "活动开始时间",

                                cast(
                                    date_add(
                                        'day',
                                        activity_param."活动结束天数",
                                        date(u."server_open_time")
                                    )
                                    AS timestamp
                                ) AS "活动结束时间"

                            FROM
                            (
                                SELECT
                                    "#account_id",
                                    "server_open_time",

                                    cast(
                                        date("create_role_time")
                                        AS varchar
                                    ) AS "$part_date"

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

                            WHERE ${PartDate:date2}
                        ) user_cohort

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
                                e0."token_payment",
                                e0."after"

                            FROM ta.v_event_41 e0

                            CROSS JOIN
                            (
                                SELECT
                                    cast(
                                        min(
                                            date(u0."create_role_time")
                                        )
                                        AS varchar
                                    ) AS "最早扫描日期",

                                    cast(
                                        max(
                                            date_add(
                                                'day',
                                                activity_param0."活动结束天数" - 1,
                                                date(u0."server_open_time")
                                            )
                                        )
                                        AS varchar
                                    ) AS "最晚扫描日期"

                                FROM
                                (
                                    SELECT
                                        "#account_id",
                                        "server_open_time",
                                        "create_role_time",

                                        cast(
                                            date("create_role_time")
                                            AS varchar
                                        ) AS "$part_date"

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
                                            )
                                            AS bigint
                                        ) AS "活动结束天数"
                                ) activity_param0

                                WHERE ${PartDate:date2}
                            ) scan_bounds

                            WHERE e0."domain" = 'release'
                              AND e0."#account_id" IS NOT NULL

                              AND e0."$part_event" IN
                              (
                                  'in_out_log',
                                  'pay_log',
                                  'vip_change_log'
                              )

                              AND e0."$part_date"
                                  BETWEEN scan_bounds."最早扫描日期"
                                      AND scan_bounds."最晚扫描日期"

                              AND
                              (
                                  e0."$part_event" IN
                                  (
                                      'in_out_log',
                                      'vip_change_log'
                                  )

                                  OR

                                  (
                                      e0."$part_event" = 'pay_log'

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
                                = user_cohort."#account_id"

                           AND
                           (
                               (
                                   e."$part_event" = 'vip_change_log'

                                   AND e."#event_time"
                                       < user_cohort."活动开始时间"
                               )

                               OR

                               (
                                   e."$part_event" IN
                                   (
                                       'in_out_log',
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
                                try_cast(
                                    "product_id"
                                    AS bigint
                                ) AS "product_id",

                                max(
                                    cast(
                                        "product_name"
                                        AS varchar
                                    )
                                ) AS "product_name",

                                max(
                                    cast(
                                        "product_type_two"
                                        AS varchar
                                    )
                                ) AS "product_type_two"

                            FROM ta_ext.product_id_41

                            WHERE "product_id" IS NOT NULL

                            GROUP BY
                                1

                            HAVING regexp_like(
                                coalesce(
                                    max(
                                        cast(
                                            "product_type_two"
                                            AS varchar
                                        )
                                    ),
                                    ''
                                ),
                                '${Selector:selector1}'
                            )
                        ) product_cfg

                            ON e."$part_event" = 'pay_log'

                           AND try_cast(
                               e."product_id"
                               AS bigint
                           ) = product_cfg."product_id"
                    ) base
                ) d

                GROUP BY
                    1,
                    2,
                    3,
                    4,
                    5
            ) g
        ) s
    ) r

    WHERE r."礼包类型" IS NOT NULL
      AND r."购买次数" > 0

    GROUP BY
        1,
        2,
        3,
        4
) q

ORDER BY
    q."分层排序",
    q."礼包类型",
    q."礼包名"