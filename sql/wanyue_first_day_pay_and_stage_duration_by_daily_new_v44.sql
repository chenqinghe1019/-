SELECT
    t.create_date AS "新增日期",
    count(DISTINCT t."#account_id") AS "新增玩家数",

    count(
        DISTINCT CASE
            WHEN t.first_pay_time IS NOT NULL
                THEN t."#account_id"
        END
    ) AS "首日破冰付费人数",

    cast(
        round(
            count(
                DISTINCT CASE
                    WHEN t.first_pay_time IS NOT NULL
                        THEN t."#account_id"
                END
            ) * 1.0000
            /
            nullif(count(DISTINCT t."#account_id"), 0),
            4
        ) AS decimal(18, 4)
    ) AS "首日破冰付费率",

    cast(
        round(
            avg(
                CASE
                    WHEN t.first_pay_time IS NOT NULL
                        THEN date_diff('second', t.create_role_time, t.first_pay_time) / 60.0000
                END
            ),
            2
        ) AS decimal(18, 2)
    ) AS "平均破冰付费时长_分钟",

    cast(
        round(
            approx_percentile(
                CASE
                    WHEN t.first_pay_time IS NOT NULL
                        THEN date_diff('second', t.create_role_time, t.first_pay_time) / 60.0000
                END,
                0.50
            ),
            2
        ) AS decimal(18, 2)
    ) AS "中位破冰付费时长_分钟",

    count(
        DISTINCT CASE
            WHEN t.pass_11_time IS NOT NULL
                THEN t."#account_id"
        END
    ) AS "通关1-1人数",

    cast(
        round(
            count(
                DISTINCT CASE
                    WHEN t.pass_11_time IS NOT NULL
                        THEN t."#account_id"
                END
            ) * 1.0000
            /
            nullif(count(DISTINCT t."#account_id"), 0),
            4
        ) AS decimal(18, 4)
    ) AS "1-1通关率",

    cast(
        round(
            avg(
                CASE
                    WHEN t.pass_11_time IS NOT NULL
                        THEN date_diff('second', t.create_role_time, t.pass_11_time) / 60.0000
                END
            ),
            2
        ) AS decimal(18, 2)
    ) AS "1-1人均累计时长_分钟",

    count(
        DISTINCT CASE
            WHEN t.pass_12_time IS NOT NULL
                THEN t."#account_id"
        END
    ) AS "通关1-2人数",

    cast(
        round(
            count(
                DISTINCT CASE
                    WHEN t.pass_12_time IS NOT NULL
                        THEN t."#account_id"
                END
            ) * 1.0000
            /
            nullif(count(DISTINCT t."#account_id"), 0),
            4
        ) AS decimal(18, 4)
    ) AS "1-2通关率",

    cast(
        round(
            avg(
                CASE
                    WHEN t.pass_12_time IS NOT NULL
                        THEN date_diff('second', t.create_role_time, t.pass_12_time) / 60.0000
                END
            ),
            2
        ) AS decimal(18, 2)
    ) AS "1-2人均累计时长_分钟",

    count(
        DISTINCT CASE
            WHEN t.pass_13_time IS NOT NULL
                THEN t."#account_id"
        END
    ) AS "通关1-3人数",

    cast(
        round(
            count(
                DISTINCT CASE
                    WHEN t.pass_13_time IS NOT NULL
                        THEN t."#account_id"
                END
            ) * 1.0000
            /
            nullif(count(DISTINCT t."#account_id"), 0),
            4
        ) AS decimal(18, 4)
    ) AS "1-3通关率",

    cast(
        round(
            avg(
                CASE
                    WHEN t.pass_13_time IS NOT NULL
                        THEN date_diff('second', t.create_role_time, t.pass_13_time) / 60.0000
                END
            ),
            2
        ) AS decimal(18, 2)
    ) AS "1-3人均累计时长_分钟"

FROM
(
    SELECT
        u.create_date,
        u."#account_id",
        u.create_role_time,
        p.first_pay_time,
        b.pass_11_time,
        b.pass_12_time,
        b.pass_13_time

    FROM
    (
        SELECT DISTINCT
            user_raw.create_date,
            user_raw."$part_date",
            user_raw."#account_id",
            user_raw.create_role_time

        FROM
        (
            SELECT
                coalesce(
                    try_cast(
                        cast(v."create_role_time" AS varchar)
                        AS timestamp
                    ),
                    cast(
                        from_unixtime(
                            try_cast(
                                cast(v."create_role_time" AS varchar)
                                AS double
                            )
                        )
                        AS timestamp
                    )
                ) AS create_role_time,

                date(
                    coalesce(
                        try_cast(
                            cast(v."create_role_time" AS varchar)
                            AS timestamp
                        ),
                        cast(
                            from_unixtime(
                                try_cast(
                                    cast(v."create_role_time" AS varchar)
                                    AS double
                                )
                            )
                            AS timestamp
                        )
                    )
                ) AS create_date,

                cast(
                    date(
                        coalesce(
                            try_cast(
                                cast(v."create_role_time" AS varchar)
                                AS timestamp
                            ),
                            cast(
                                from_unixtime(
                                    try_cast(
                                        cast(v."create_role_time" AS varchar)
                                        AS double
                                    )
                                )
                                AS timestamp
                            )
                        )
                    )
                    AS varchar
                ) AS "$part_date",

                cast(v."#account_id" AS varchar) AS "#account_id"

            FROM ta.v_user_44 v

            WHERE v."domain" = 'release'
              AND v."#account_id" IS NOT NULL
              AND v."create_role_time" IS NOT NULL
        ) user_raw

        WHERE user_raw.create_date IS NOT NULL
          AND user_raw.create_date < current_date
          AND user_raw.${PartDate:date}
    ) u

    LEFT JOIN
    (
        SELECT
            cast(pay_e."#account_id" AS varchar) AS "#account_id",
            date(pay_e."#event_time") AS pay_date,
            min(cast(pay_e."#event_time" AS timestamp)) AS first_pay_time

        FROM ta.v_event_44 pay_e

        CROSS JOIN
        (
            SELECT
                min(range_raw.create_date) AS min_create_date,
                max(range_raw.create_date) AS max_create_date

            FROM
            (
                SELECT
                    date(
                        coalesce(
                            try_cast(
                                cast(range_v."create_role_time" AS varchar)
                                AS timestamp
                            ),
                            cast(
                                from_unixtime(
                                    try_cast(
                                        cast(range_v."create_role_time" AS varchar)
                                        AS double
                                    )
                                )
                                AS timestamp
                            )
                        )
                    ) AS create_date,

                    cast(
                        date(
                            coalesce(
                                try_cast(
                                    cast(range_v."create_role_time" AS varchar)
                                    AS timestamp
                                ),
                                cast(
                                    from_unixtime(
                                        try_cast(
                                            cast(range_v."create_role_time" AS varchar)
                                            AS double
                                        )
                                    )
                                    AS timestamp
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
              AND range_raw.create_date < current_date
              AND range_raw.${PartDate:date}
        ) pay_range

        WHERE pay_e."$part_event" = 'pay_log'
          AND pay_e."#account_id" IS NOT NULL
          AND coalesce(
                try_cast(pay_e."payment" AS double),
                0
              ) > 0
          AND date(pay_e."$part_date")
              BETWEEN pay_range.min_create_date
                  AND pay_range.max_create_date
          AND date(pay_e."#event_time")
              BETWEEN pay_range.min_create_date
                  AND pay_range.max_create_date

        GROUP BY
            cast(pay_e."#account_id" AS varchar),
            date(pay_e."#event_time")
    ) p
        ON u."#account_id" = p."#account_id"
       AND u.create_date = p.pay_date
       AND p.first_pay_time >= u.create_role_time

    LEFT JOIN
    (
        SELECT
            cast(battle_e."#account_id" AS varchar) AS "#account_id",
            date(battle_e."#event_time") AS battle_date,

            min(
                CASE
                    WHEN cast(battle_e."map_id" AS varchar) = '1-1'
                        THEN cast(battle_e."#event_time" AS timestamp)
                END
            ) AS pass_11_time,

            min(
                CASE
                    WHEN cast(battle_e."map_id" AS varchar) = '1-2'
                        THEN cast(battle_e."#event_time" AS timestamp)
                END
            ) AS pass_12_time,

            min(
                CASE
                    WHEN cast(battle_e."map_id" AS varchar) = '1-3'
                        THEN cast(battle_e."#event_time" AS timestamp)
                END
            ) AS pass_13_time

        FROM ta.v_event_44 battle_e

        CROSS JOIN
        (
            SELECT
                min(range_raw.create_date) AS min_create_date,
                max(range_raw.create_date) AS max_create_date

            FROM
            (
                SELECT
                    date(
                        coalesce(
                            try_cast(
                                cast(range_v."create_role_time" AS varchar)
                                AS timestamp
                            ),
                            cast(
                                from_unixtime(
                                    try_cast(
                                        cast(range_v."create_role_time" AS varchar)
                                        AS double
                                    )
                                )
                                AS timestamp
                            )
                        )
                    ) AS create_date,

                    cast(
                        date(
                            coalesce(
                                try_cast(
                                    cast(range_v."create_role_time" AS varchar)
                                    AS timestamp
                                ),
                                cast(
                                    from_unixtime(
                                        try_cast(
                                            cast(range_v."create_role_time" AS varchar)
                                            AS double
                                        )
                                    )
                                    AS timestamp
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
              AND range_raw.create_date < current_date
              AND range_raw.${PartDate:date}
        ) battle_range

        WHERE battle_e."$part_event" = 'battle_result'
          AND battle_e."#account_id" IS NOT NULL
          AND cast(battle_e."map_id" AS varchar) IN ('1-1', '1-2', '1-3')
          AND coalesce(
                try_cast(battle_e."battle_result" AS integer),
                0
              ) = 1
          AND date(battle_e."$part_date")
              BETWEEN battle_range.min_create_date
                  AND battle_range.max_create_date
          AND date(battle_e."#event_time")
              BETWEEN battle_range.min_create_date
                  AND battle_range.max_create_date

        GROUP BY
            cast(battle_e."#account_id" AS varchar),
            date(battle_e."#event_time")
    ) b
        ON u."#account_id" = b."#account_id"
       AND u.create_date = b.battle_date
       AND (
            b.pass_11_time >= u.create_role_time
            OR b.pass_12_time >= u.create_role_time
            OR b.pass_13_time >= u.create_role_time
       )
) t

GROUP BY t.create_date

ORDER BY t.create_date DESC;