SELECT
    row_number() OVER (
        ORDER BY
            q."分层排序",
            q."汇总排序",
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

    round(q."付费金额", 2) AS "付费金额",

    CASE
        WHEN q."汇总排序" = 0
            THEN 1.0000
        ELSE round(
            q."付费金额" * 1.0000
            / nullif(
                sum(
                    CASE
                        WHEN q."汇总排序" = 1
                            THEN q."付费金额"
                        ELSE 0
                    END
                ) OVER (
                    PARTITION BY
                        q."VIP层级（活动开始前）",
                        q."礼包类型"
                ),
                0
            ),
            4
        )
    END AS "付费金额占比（层内）",

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

        CASE
            WHEN grouping(r."礼包类型") = 1
                THEN 'VIP汇总'
            ELSE r."礼包类型"
        END AS "礼包类型",

        CASE
            WHEN grouping(r."礼包名") = 1
                THEN 'VIP汇总'
            ELSE r."礼包名"
        END AS "礼包名",

        CASE
            WHEN grouping(r."礼包类型") = 1
                THEN 0
            ELSE 1
        END AS "汇总排序",

        max(r."层内活动活跃人数") AS "活动活跃人数",

        count(
            DISTINCT r."#account_id"
        ) AS "付费人数",

        sum(r."购买次数") AS "购买次数",
        sum(r."付费金额") AS "付费金额"

    FROM
    (
        SELECT
            s."#account_id",
            s."VIP层级（活动开始前）",
            s."分层排序",
            s."层内活动活跃人数",
            p."礼包类型",
            p."礼包名",

            count(p."#event_time") AS "购买次数",

            sum(
                coalesce(
                    p."单笔付费金额",
                    0
                )
            ) AS "付费金额"

        FROM
        (
            SELECT
                z.*,

                count(*) OVER (
                    PARTITION BY
                        z."VIP层级（活动开始前）"
                ) AS "层内活动活跃人数"

            FROM
            (
                SELECT
                    y."#account_id",
                    y."活动开始时间",
                    y."活动结束时间",

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
                    END AS "VIP层级（活动开始前）",

                    CASE
                        WHEN coalesce(
                            y."活动开始前VIP等级",
                            0
                        ) BETWEEN 0 AND 3 THEN 1

                        WHEN coalesce(
                            y."活动开始前VIP等级",
                            0
                        ) BETWEEN 4 AND 6 THEN 2

                        WHEN coalesce(
                            y."活动开始前VIP等级",
                            0
                        ) BETWEEN 7 AND 9 THEN 3

                        ELSE 4
                    END AS "分层排序"

                FROM
                (
                    SELECT
                        active_user."#account_id",
                        active_user."活动开始时间",
                        active_user."活动结束时间",

                        max(
                            try_cast(vip_e."after" AS bigint)
                        ) AS "活动开始前VIP等级"

                    FROM
                    (
                        SELECT DISTINCT
                            cast(a."#account_id" AS varchar) AS "#account_id",
                            date(u."server_open_time") AS "开服日期",

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
                                min(cast(d."$part_date" AS date)) AS "统计开始日期",
                                max(cast(d."$part_date" AS date)) AS "统计结束日期"
                            FROM
                            (
                                SELECT "$part_date"
                                FROM ta.v_event_41
                                WHERE ${PartDate:date2}
                            ) d
                        ) stats_period

                        WHERE u."domain" = 'release'
                          AND u."server_open_time" IS NOT NULL

                          /* 仅保留活动完整周期全部落在统计周期内的成熟区服 */
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

                          /* 玩家必须在真实活动周期内有活跃 */
                          AND (
                                date_diff(
                                    'day',
                                    date(u."server_open_time"),
                                    date(a."#event_time")
                                ) + 1
                              ) ${Selector:selector2}
                    ) active_user

                    LEFT JOIN ta.v_event_41 vip_e
                        ON cast(vip_e."#account_id" AS varchar)
                            = active_user."#account_id"
                       AND vip_e."$part_event" = 'vip_change_log'
                       AND vip_e."domain" = 'release'
                       AND vip_e."#event_time"
                            < active_user."活动开始时间"
                       AND vip_e."$part_date"
                           BETWEEN cast(
                                active_user."开服日期"
                                AS varchar
                           )
                           AND cast(
                                date_add(
                                    'day',
                                    -1,
                                    date(active_user."活动开始时间")
                                ) AS varchar
                           )

                    GROUP BY
                        1,
                        2,
                        3
                ) y
            ) z
        ) s

        LEFT JOIN
        (
            SELECT
                cast(e."#account_id" AS varchar) AS "#account_id",
                e."#event_time",
                product_cfg."product_type_two" AS "礼包类型",
                product_cfg."product_name" AS "礼包名",

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
                ) / 100.0000 AS "单笔付费金额"

            FROM
            (
                SELECT
                    "#account_id",
                    "#event_time",
                    "product_id",
                    "payment",
                    "token_payment"

                FROM ta.v_event_41

                WHERE ${PartDate:date2}
                  AND "domain" = 'release'
                  AND "$part_event" = 'pay_log'
                  AND "#account_id" IS NOT NULL

                  AND
                  (
                      coalesce(
                          try_cast("payment" AS double),
                          0
                      ) > 0

                      OR

                      coalesce(
                          try_cast("token_payment" AS double),
                          0
                      ) > 0
                  )
            ) e

            INNER JOIN
            (
                SELECT
                    try_cast("product_id" AS bigint) AS "product_id",
                    max(
                        cast("product_name" AS varchar)
                    ) AS "product_name",
                    max(
                        cast("product_type_two" AS varchar)
                    ) AS "product_type_two"

                FROM ta_ext.product_id_41

                WHERE "product_id" IS NOT NULL

                GROUP BY 1

                HAVING regexp_like(
                    coalesce(
                        max(
                            cast("product_type_two" AS varchar)
                        ),
                        ''
                    ),
                    '${Selector:selector1}'
                )
            ) product_cfg
                ON try_cast(e."product_id" AS bigint)
                    = product_cfg."product_id"
        ) p
            ON p."#account_id" = s."#account_id"
           AND p."#event_time" >= s."活动开始时间"
           AND p."#event_time" < s."活动结束时间"

        GROUP BY
            1,
            2,
            3,
            4,
            5,
            6

        HAVING count(p."#event_time") > 0
    ) r

    GROUP BY GROUPING SETS
    (
        (
            r."VIP层级（活动开始前）",
            r."分层排序"
        ),
        (
            r."VIP层级（活动开始前）",
            r."分层排序",
            r."礼包类型",
            r."礼包名"
        )
    )
) q

ORDER BY
    q."分层排序",
    q."汇总排序",
    q."礼包类型",
    q."礼包名"