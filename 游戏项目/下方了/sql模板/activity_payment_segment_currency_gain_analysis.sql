SELECT
    row_number() OVER (
        ORDER BY
            q."分层排序",
            q."货币ID"
    ) AS "序号",

    q."活动付费分层",
    q."分层总人数",
    q."货币ID",
    q."货币名称",
    q."获取人数",

    round(
        q."获取货币数量",
        2
    ) AS "获取货币数量",

    round(
        q."获取货币数量" * 1.0000
        / nullif(q."分层总人数", 0),
        2
    ) AS "人均货币数量"

FROM
(
    SELECT
        r."活动付费分层",
        r."分层排序",
        r."货币ID",
        max(r."货币名称") AS "货币名称",
        max(r."分层总人数") AS "分层总人数",
        count(*) AS "获取人数",
        sum(r."获取货币数量") AS "获取货币数量"

    FROM
    (
        SELECT
            s."活动付费分层",
            s."分层排序",
            s."分层总人数",
            s."#account_id",

            cast(
                s."item_id"
                AS varchar
            ) AS "货币ID",

            coalesce(
                max(
                    cast(
                        s."item_name"
                        AS varchar
                    )
                ),
                '未知货币'
            ) AS "货币名称",

            sum(
                abs(
                    coalesce(
                        try_cast(
                            s."item_num"
                            AS double
                        ),
                        0
                    )
                )
            ) AS "获取货币数量"

        FROM
        (
            SELECT
                t.*,

                sum(
                    CASE
                        WHEN t."玩家序号" = 1 THEN 1
                        ELSE 0
                    END
                ) OVER (
                    PARTITION BY
                        t."活动付费分层"
                ) AS "分层总人数"

            FROM
            (
                SELECT
                    z.*,

                    CASE
                        WHEN z."活动付费金额" <= 12
                            THEN 'a.(0,12]'
                        WHEN z."活动付费金额" <= 30
                            THEN 'b.(12,30]'
                        WHEN z."活动付费金额" <= 68
                            THEN 'c.(30,68]'
                        WHEN z."活动付费金额" <= 196
                            THEN 'd.(68,196]'
                        WHEN z."活动付费金额" <= 328
                            THEN 'e.(196,328]'
                        WHEN z."活动付费金额" <= 648
                            THEN 'f.(328,648]'
                        WHEN z."活动付费金额" <= 1000
                            THEN 'g.(648,1000]'
                        WHEN z."活动付费金额" <= 3000
                            THEN 'h.(1000,3000]'
                        WHEN z."活动付费金额" <= 10000
                            THEN 'i.(3000,10000]'
                        ELSE 'j.(10000,+)'
                    END AS "活动付费分层",

                    CASE
                        WHEN z."活动付费金额" <= 12 THEN 1
                        WHEN z."活动付费金额" <= 30 THEN 2
                        WHEN z."活动付费金额" <= 68 THEN 3
                        WHEN z."活动付费金额" <= 196 THEN 4
                        WHEN z."活动付费金额" <= 328 THEN 5
                        WHEN z."活动付费金额" <= 648 THEN 6
                        WHEN z."活动付费金额" <= 1000 THEN 7
                        WHEN z."活动付费金额" <= 3000 THEN 8
                        WHEN z."活动付费金额" <= 10000 THEN 9
                        ELSE 10
                    END AS "分层排序",

                    row_number() OVER (
                        PARTITION BY z."#account_id"
                        ORDER BY
                            z."#event_time",
                            z."$part_event"
                    ) AS "玩家序号"

                FROM
                (
                    SELECT
                        b.*,

                        sum(
                            b."单笔活动付费金额"
                        ) OVER (
                            PARTITION BY
                                b."#account_id"
                        ) AS "活动付费金额"

                    FROM
                    (
                        SELECT
                            active_user."#account_id",
                            e."$part_event",
                            e."#event_time",
                            e."item_id",
                            e."item_name",
                            e."item_num",
                            e."change_type",

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
                            END AS "单笔活动付费金额"

                        FROM
                        (
                            SELECT DISTINCT
                                cast(
                                    a."#account_id"
                                    AS varchar
                                ) AS "#account_id",

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
                                    "#event_time"

                                FROM ta.v_event_41

                                WHERE ${PartDate:date2}
                                  AND "domain" = 'release'
                                  AND "$part_event" = 'in_out_log'
                                  AND "#account_id" IS NOT NULL
                            ) a

                            INNER JOIN ta.v_user_41 u
                                ON cast(a."#account_id" AS varchar)
                                    = cast(u."#account_id" AS varchar)

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

                            WHERE u."domain" = 'release'
                              AND u."server_open_time" IS NOT NULL

                              AND date_add(
                                    'day',
                                    activity_param."活动开始天数" - 1,
                                    date(u."server_open_time")
                                  ) >= stats_period."统计开始日期"

                              AND date_add(
                                    'day',
                                    activity_param."活动结束天数" - 1,
                                    date(u."server_open_time")
                                  ) <= stats_period."统计结束日期"

                              AND (
                                    date_diff(
                                        'day',
                                        date(u."server_open_time"),
                                        date(a."#event_time")
                                    ) + 1
                                  ) ${Selector:selector2}
                        ) active_user

                        INNER JOIN
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
                                e0."item_id",
                                e0."item_name",
                                e0."item_num",
                                e0."change_type"

                            FROM ta.v_event_41 e0

                            WHERE ${PartDate:date2}
                              AND e0."domain" = 'release'
                              AND e0."#account_id" IS NOT NULL

                              AND
                              (
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

                                  OR

                                  (
                                      e0."$part_event" = 'item_log'

                                      AND try_cast(
                                            e0."change_type"
                                            AS bigint
                                          ) = 1

                                      AND try_cast(
                                            e0."item_id"
                                            AS bigint
                                          ) ${Selector:selector3}
                                  )
                              )
                        ) e
                            ON e."#account_id"
                                = active_user."#account_id"

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

                            WHERE "product_id" IS NOT NULL

                            GROUP BY 1

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

                        WHERE e."$part_event" = 'item_log'
                           OR product_cfg."product_id" IS NOT NULL
                    ) b
                ) z

                WHERE z."活动付费金额" > 0
            ) t
        ) s

        WHERE s."$part_event" = 'item_log'
          AND s."item_id" IS NOT NULL
          AND try_cast(
                s."change_type"
                AS bigint
              ) = 1
          AND abs(
                coalesce(
                    try_cast(
                        s."item_num"
                        AS double
                    ),
                    0
                )
              ) > 0

        GROUP BY
            1,
            2,
            3,
            4,
            5
    ) r

    GROUP BY
        1,
        2,
        3
) q

ORDER BY
    q."分层排序",
    q."货币ID"
