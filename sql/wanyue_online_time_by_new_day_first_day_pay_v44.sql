SELECT
    "新增日期",
    "新增首日付费分层",
    "新增第N天",
    "新增玩家数",
    "Dn成熟新增玩家数",
    "当天活跃玩家数",
    "当天活跃率",
    "人均在线时长_分钟",
    "玩家最大在线时长_分钟",
    "玩家最小在线时长_分钟"

FROM
(
    SELECT
        CASE
            WHEN grouping(p.create_date) = 1
                THEN '日期汇总'
            ELSE cast(p.create_date AS varchar)
        END AS "新增日期",

        CASE
            WHEN grouping(p.create_date) = 1
                THEN 0
            ELSE 1
        END AS "日期排序",

        CASE
            WHEN grouping(p.pay_level) = 1
                THEN '汇总'
            ELSE p.pay_level
        END AS "新增首日付费分层",

        CASE
            WHEN grouping(p.pay_level) = 1
                THEN 0
            ELSE p.pay_sort
        END AS "分层排序",

        concat(
            'D',
            cast(p.day_num AS varchar)
        ) AS "新增第N天",

        p.day_num AS "天数排序",

        count(
            DISTINCT p."#account_id"
        ) AS "新增玩家数",

        count(
            DISTINCT CASE
                WHEN p.is_mature = 1
                    THEN p."#account_id"
            END
        ) AS "Dn成熟新增玩家数",

        count(
            DISTINCT CASE
                WHEN p.is_mature = 1
                 AND p.is_active = 1
                    THEN p."#account_id"
            END
        ) AS "当天活跃玩家数",

        cast(
            round(
                count(
                    DISTINCT CASE
                        WHEN p.is_mature = 1
                         AND p.is_active = 1
                            THEN p."#account_id"
                    END
                ) * 1.0000
                /
                nullif(
                    count(
                        DISTINCT CASE
                            WHEN p.is_mature = 1
                                THEN p."#account_id"
                        END
                    ),
                    0
                ),
                4
            ) AS decimal(18, 4)
        ) AS "当天活跃率",

        cast(
            round(
                sum(
                    CASE
                        WHEN p.is_mature = 1
                         AND p.is_active = 1
                            THEN p.online_minutes
                        ELSE 0
                    END
                ) * 1.0000
                /
                nullif(
                    count(
                        DISTINCT CASE
                            WHEN p.is_mature = 1
                             AND p.is_active = 1
                                THEN p."#account_id"
                        END
                    ),
                    0
                ),
                2
            ) AS decimal(18, 2)
        ) AS "人均在线时长_分钟",

        cast(
            round(
                max(
                    CASE
                        WHEN p.is_mature = 1
                         AND p.is_active = 1
                            THEN p.online_minutes
                    END
                ),
                2
            ) AS decimal(18, 2)
        ) AS "玩家最大在线时长_分钟",

        cast(
            round(
                min(
                    CASE
                        WHEN p.is_mature = 1
                         AND p.is_active = 1
                            THEN p.online_minutes
                    END
                ),
                2
            ) AS decimal(18, 2)
        ) AS "玩家最小在线时长_分钟"

    FROM
    (
        SELECT
            c.create_date,
            c."#account_id",
            c.pay_level,
            c.pay_sort,
            d.day_num,

            CASE
                WHEN date_add(
                        'day',
                        d.day_num - 1,
                        c.create_date
                     ) < current_date
                    THEN 1
                ELSE 0
            END AS is_mature,

            coalesce(e.is_active, 0) AS is_active,
            coalesce(e.online_minutes, 0) AS online_minutes

        FROM
        (
            SELECT
                u.create_date,
                u."#account_id",

                CASE
                    WHEN coalesce(fp.first_day_pay, 0) = 0 THEN 'a_free'
                    WHEN coalesce(fp.first_day_pay, 0) <= 6 THEN 'b_(0,6]'
                    WHEN coalesce(fp.first_day_pay, 0) <= 30 THEN 'c_(6,30]'
                    WHEN coalesce(fp.first_day_pay, 0) <= 100 THEN 'd_(30,100]'
                    WHEN coalesce(fp.first_day_pay, 0) <= 300 THEN 'e_(100,300]'
                    WHEN coalesce(fp.first_day_pay, 0) <= 500 THEN 'f_(300,500]'
                    WHEN coalesce(fp.first_day_pay, 0) <= 1000 THEN 'g_(500,1000]'
                    ELSE 'h_(1000,+)'
                END AS pay_level,

                CASE
                    WHEN coalesce(fp.first_day_pay, 0) = 0 THEN 1
                    WHEN coalesce(fp.first_day_pay, 0) <= 6 THEN 2
                    WHEN coalesce(fp.first_day_pay, 0) <= 30 THEN 3
                    WHEN coalesce(fp.first_day_pay, 0) <= 100 THEN 4
                    WHEN coalesce(fp.first_day_pay, 0) <= 300 THEN 5
                    WHEN coalesce(fp.first_day_pay, 0) <= 500 THEN 6
                    WHEN coalesce(fp.first_day_pay, 0) <= 1000 THEN 7
                    ELSE 8
                END AS pay_sort

            FROM
            (
                SELECT DISTINCT
                    user_raw.create_date,
                    user_raw."$part_date",
                    user_raw."#account_id"

                FROM
                (
                    SELECT
                        coalesce(
                            date(
                                try_cast(
                                    cast(v."create_role_time" AS varchar)
                                    AS timestamp
                                )
                            ),
                            date(
                                from_unixtime(
                                    try_cast(
                                        cast(v."create_role_time" AS varchar)
                                        AS double
                                    )
                                )
                            )
                        ) AS create_date,

                        cast(
                            coalesce(
                                date(
                                    try_cast(
                                        cast(v."create_role_time" AS varchar)
                                        AS timestamp
                                    )
                                ),
                                date(
                                    from_unixtime(
                                        try_cast(
                                            cast(v."create_role_time" AS varchar)
                                            AS double
                                        )
                                    )
                                )
                            )
                            AS varchar
                        ) AS "$part_date",

                        cast(
                            v."#account_id"
                            AS varchar
                        ) AS "#account_id"

                    FROM ta.v_user_44 v

                    WHERE v."domain" = 'release'
                      AND v."#account_id" IS NOT NULL
                      AND v."create_role_time" IS NOT NULL
                ) user_raw

                WHERE user_raw.create_date IS NOT NULL
                  AND user_raw.${PartDate:date}
            ) u

            LEFT JOIN
            (
                SELECT
                    cast(
                        pay_e."#account_id"
                        AS varchar
                    ) AS "#account_id",

                    date(
                        pay_e."#event_time"
                    ) AS pay_date,

                    sum(
                        coalesce(
                            try_cast(
                                pay_e."payment"
                                AS double
                            ),
                            0
                        )
                    ) / 100.0000 AS first_day_pay

                FROM ta.v_event_44 pay_e

                CROSS JOIN
                (
                    SELECT
                        min(pay_range_raw.create_date) AS min_create_date,
                        max(pay_range_raw.create_date) AS max_create_date

                    FROM
                    (
                        SELECT
                            coalesce(
                                date(
                                    try_cast(
                                        cast(pay_range_v."create_role_time" AS varchar)
                                        AS timestamp
                                    )
                                ),
                                date(
                                    from_unixtime(
                                        try_cast(
                                            cast(pay_range_v."create_role_time" AS varchar)
                                            AS double
                                        )
                                    )
                                )
                            ) AS create_date,

                            cast(
                                coalesce(
                                    date(
                                        try_cast(
                                            cast(pay_range_v."create_role_time" AS varchar)
                                            AS timestamp
                                        )
                                    ),
                                    date(
                                        from_unixtime(
                                            try_cast(
                                                cast(pay_range_v."create_role_time" AS varchar)
                                                AS double
                                            )
                                        )
                                    )
                                )
                                AS varchar
                            ) AS "$part_date"

                        FROM ta.v_user_44 pay_range_v

                        WHERE pay_range_v."domain" = 'release'
                          AND pay_range_v."#account_id" IS NOT NULL
                          AND pay_range_v."create_role_time" IS NOT NULL
                    ) pay_range_raw

                    WHERE pay_range_raw.create_date IS NOT NULL
                      AND pay_range_raw.${PartDate:date}
                ) pay_range

                WHERE pay_e."$part_event" = 'pay_log'
                  AND pay_e."#account_id" IS NOT NULL
                  AND coalesce(
                        try_cast(
                            pay_e."payment"
                            AS double
                        ),
                        0
                      ) > 0
                  AND date(pay_e."$part_date")
                      BETWEEN pay_range.min_create_date
                          AND pay_range.max_create_date
                  AND date(pay_e."#event_time")
                      BETWEEN pay_range.min_create_date
                          AND pay_range.max_create_date

                GROUP BY
                    cast(
                        pay_e."#account_id"
                        AS varchar
                    ),
                    date(
                        pay_e."#event_time"
                    )
            ) fp
                ON u."#account_id" = fp."#account_id"
               AND u.create_date = fp.pay_date
        ) c

        CROSS JOIN UNNEST(
            sequence(1, 14)
        ) AS d(day_num)

        LEFT JOIN
        (
            SELECT
                cast(
                    event_e."#account_id"
                    AS varchar
                ) AS "#account_id",

                date(
                    event_e."#event_time"
                ) AS event_date,

                1 AS is_active,

                sum(
                    coalesce(
                        try_cast(
                            event_e."online_time"
                            AS double
                        ),
                        0
                    )
                ) / 60.0000 AS online_minutes

            FROM ta.v_event_44 event_e

            CROSS JOIN
            (
                SELECT
                    min(range_raw.create_date) AS min_create_date,

                    date_add(
                        'day',
                        13,
                        max(range_raw.create_date)
                    ) AS max_event_date

                FROM
                (
                    SELECT
                        coalesce(
                            date(
                                try_cast(
                                    cast(range_v."create_role_time" AS varchar)
                                    AS timestamp
                                )
                            ),
                            date(
                                from_unixtime(
                                    try_cast(
                                        cast(range_v."create_role_time" AS varchar)
                                        AS double
                                    )
                                )
                            )
                        ) AS create_date,

                        cast(
                            coalesce(
                                date(
                                    try_cast(
                                        cast(range_v."create_role_time" AS varchar)
                                        AS timestamp
                                    )
                                ),
                                date(
                                    from_unixtime(
                                        try_cast(
                                            cast(range_v."create_role_time" AS varchar)
                                            AS double
                                        )
                                    )
                                )
                            )
                            AS varchar
                        ) AS "$part_date"

                    FROM ta.v_user_44 range_v

                    WHERE range_v."domain" = 'release'
                      AND range_v."#account_id" IS NOT NULL
                      AND range_v."create_role_time" IS NOT NULL
                ) range_raw

                WHERE range_raw.create_date IS NOT NULL
                  AND range_raw.${PartDate:date}
            ) event_range

            WHERE event_e."$part_event" = 'in_out_log'
              AND event_e."#account_id" IS NOT NULL
              AND coalesce(
                    try_cast(
                        event_e."online_time"
                        AS double
                    ),
                    0
                  ) <= 86400
              AND date(event_e."$part_date")
                  BETWEEN event_range.min_create_date
                      AND event_range.max_event_date
              AND date(event_e."#event_time")
                  BETWEEN event_range.min_create_date
                      AND event_range.max_event_date

            GROUP BY
                cast(
                    event_e."#account_id"
                    AS varchar
                ),
                date(
                    event_e."#event_time"
                )
        ) e
            ON c."#account_id" = e."#account_id"
           AND e.event_date = date_add(
                'day',
                d.day_num - 1,
                c.create_date
               )
    ) p

    GROUP BY GROUPING SETS
    (
        (
            p.create_date,
            p.pay_level,
            p.pay_sort,
            p.day_num
        ),
        (
            p.create_date,
            p.day_num
        ),
        (
            p.pay_level,
            p.pay_sort,
            p.day_num
        ),
        (
            p.day_num
        )
    )
)

ORDER BY
    "日期排序",
    try_cast(
        "新增日期"
        AS date
    ) DESC,
    "天数排序",
    "分层排序",
    "新增首日付费分层";