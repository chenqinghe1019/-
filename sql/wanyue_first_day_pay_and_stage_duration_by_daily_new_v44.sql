SELECT
    "新增时间",
    "媒体平台",

    count(
        DISTINCT CASE
            WHEN "首日登录次数" > 0
                THEN "nb_open_id"
        END
    ) AS "新增",

    count(
        DISTINCT CASE
            WHEN "1-1结算时间" IS NOT NULL
                THEN "nb_open_id"
        END
    ) AS "1-1战斗结算",

    count(
        DISTINCT CASE
            WHEN "1-2结算时间" IS NOT NULL
                THEN "nb_open_id"
        END
    ) AS "1-2战斗结算",

    count(
        DISTINCT CASE
            WHEN "1-3结算时间" IS NOT NULL
                THEN "nb_open_id"
        END
    ) AS "1-3战斗结算",

    count(
        DISTINCT CASE
            WHEN "首日首次付费时间" IS NOT NULL
                THEN "nb_open_id"
        END
    ) AS "首日破冰付费人数",

    if(
        count(
            DISTINCT CASE
                WHEN "首日登录次数" > 0
                    THEN "nb_open_id"
            END
        ) = 0,
        0,
        count(
            DISTINCT CASE
                WHEN "1-1结算时间" IS NOT NULL
                    THEN "nb_open_id"
            END
        ) * 1.00000
        /
        count(
            DISTINCT CASE
                WHEN "首日登录次数" > 0
                    THEN "nb_open_id"
            END
        )
    ) AS "1-1结算漏斗%",

    if(
        count(
            DISTINCT CASE
                WHEN "首日登录次数" > 0
                    THEN "nb_open_id"
            END
        ) = 0,
        0,
        count(
            DISTINCT CASE
                WHEN "1-2结算时间" IS NOT NULL
                    THEN "nb_open_id"
            END
        ) * 1.00000
        /
        count(
            DISTINCT CASE
                WHEN "首日登录次数" > 0
                    THEN "nb_open_id"
            END
        )
    ) AS "1-2结算漏斗%",

    if(
        count(
            DISTINCT CASE
                WHEN "首日登录次数" > 0
                    THEN "nb_open_id"
            END
        ) = 0,
        0,
        count(
            DISTINCT CASE
                WHEN "1-3结算时间" IS NOT NULL
                    THEN "nb_open_id"
            END
        ) * 1.00000
        /
        count(
            DISTINCT CASE
                WHEN "首日登录次数" > 0
                    THEN "nb_open_id"
            END
        )
    ) AS "1-3结算漏斗%",

    if(
        count(
            DISTINCT CASE
                WHEN "首日登录次数" > 0
                    THEN "nb_open_id"
            END
        ) = 0,
        0,
        count(
            DISTINCT CASE
                WHEN "首日首次付费时间" IS NOT NULL
                    THEN "nb_open_id"
            END
        ) * 1.00000
        /
        count(
            DISTINCT CASE
                WHEN "首日登录次数" > 0
                    THEN "nb_open_id"
            END
        )
    ) AS "首日破冰付费率%",

    cast(
        round(
            avg(
                CASE
                    WHEN "1-1结算时间" IS NOT NULL
                        THEN date_diff(
                                'second',
                                "openid创角时间",
                                "1-1结算时间"
                             ) / 60.0000
                END
            ),
            2
        ) AS decimal(18, 2)
    ) AS "1-1人均累计时长_分钟",

    cast(
        round(
            avg(
                CASE
                    WHEN "1-2结算时间" IS NOT NULL
                        THEN date_diff(
                                'second',
                                "openid创角时间",
                                "1-2结算时间"
                             ) / 60.0000
                END
            ),
            2
        ) AS decimal(18, 2)
    ) AS "1-2人均累计时长_分钟",

    cast(
        round(
            avg(
                CASE
                    WHEN "1-3结算时间" IS NOT NULL
                        THEN date_diff(
                                'second',
                                "openid创角时间",
                                "1-3结算时间"
                             ) / 60.0000
                END
            ),
            2
        ) AS decimal(18, 2)
    ) AS "1-3人均累计时长_分钟",

    cast(
        round(
            avg(
                CASE
                    WHEN "首日首次付费时间" IS NOT NULL
                        THEN date_diff(
                                'second',
                                "openid创角时间",
                                "首日首次付费时间"
                             ) / 60.0000
                END
            ),
            2
        ) AS decimal(18, 2)
    ) AS "首日破冰付费人均累计时长_分钟"

FROM
(
    SELECT
        date(openid_create_role_time) AS "新增时间",
        "ad_platform" AS "媒体平台",
        "nb_open_id",

        min(openid_create_role_time) AS "openid创角时间",

        max(
            CASE
                WHEN day = 0
                    THEN coalesce("登录次数", 0)
                ELSE 0
            END
        ) AS "首日登录次数",

        min(
            CASE
                WHEN day = 0
                 AND first_battle_end_time_101 >= openid_create_role_time
                    THEN first_battle_end_time_101
            END
        ) AS "1-1结算时间",

        min(
            CASE
                WHEN day = 0
                 AND first_battle_end_time_102 >= openid_create_role_time
                    THEN first_battle_end_time_102
            END
        ) AS "1-2结算时间",

        min(
            CASE
                WHEN day = 0
                 AND first_battle_end_time_103 >= openid_create_role_time
                    THEN first_battle_end_time_103
            END
        ) AS "1-3结算时间",

        min(
            CASE
                WHEN day = 0
                 AND first_pay_time >= openid_create_role_time
                    THEN first_pay_time
            END
        ) AS "首日首次付费时间"

    FROM
    (
        SELECT
            t_1."#account_id",
            t_1."nb_open_id",
            t_1.openid_create_role_time,
            t_1."ad_platform",

            date_diff(
                'day',
                date(t_1.openid_create_role_time),
                date(t_2."$part_date")
            ) AS day,

            t_2."登录次数",
            t_2.first_battle_end_time_101,
            t_2.first_battle_end_time_102,
            t_2.first_battle_end_time_103,
            t_2.first_pay_time

        FROM
        (
            SELECT DISTINCT
                "#account_id",
                "nb_open_id",

                min(
                    from_unixtime("create_role_time")
                ) OVER (
                    PARTITION BY "nb_open_id"
                ) AS openid_create_role_time,

                "ad_platform"

            FROM ta.v_user_44

            WHERE "domain" = 'release'
              AND "#account_id" IS NOT NULL
              AND "nb_open_id" IS NOT NULL
              AND "create_role_time" IS NOT NULL
        ) t_1

        LEFT JOIN
        (
            SELECT
                "#account_id",
                "$part_date",

                count(
                    DISTINCT logintime
                ) AS "登录次数",

                min(
                    battle_end_time_101
                ) AS first_battle_end_time_101,

                min(
                    battle_end_time_102
                ) AS first_battle_end_time_102,

                min(
                    battle_end_time_103
                ) AS first_battle_end_time_103,

                min(
                    paytime
                ) AS first_pay_time

            FROM
            (
                SELECT
                    "#account_id",
                    "$part_date",
                    "#event_time",
                    "$part_event",

                    CASE
                        WHEN "$part_event" IN (
                            'ta_app_start',
                            'ta_app_end',
                            'active_log',
                            'in_out_log'
                        )
                            THEN "#event_time"
                    END AS logintime,

                    CASE
                        WHEN "$part_event" = 'battle_result'
                         AND "map_id" = 10001
                            THEN "#event_time"
                    END AS battle_end_time_101,

                    CASE
                        WHEN "$part_event" = 'battle_result'
                         AND "map_id" = 10002
                            THEN "#event_time"
                    END AS battle_end_time_102,

                    CASE
                        WHEN "$part_event" = 'battle_result'
                         AND "map_id" = 10003
                            THEN "#event_time"
                    END AS battle_end_time_103,

                    CASE
                        WHEN "$part_event" = 'pay_log'
                         AND "payment" > 0
                            THEN "#event_time"
                    END AS paytime

                FROM ta.v_event_44

                WHERE "$part_event" IN (
                    'ta_app_start',
                    'ta_app_end',
                    'active_log',
                    'in_out_log',
                    'pay_log',
                    'battle_result'
                )

                  AND date("$part_date")${Time:time1}

                  AND (
                        "$part_event" <> 'battle_result'
                        OR "map_id" IN (10001, 10002, 10003)
                      )
            ) event_detail

            GROUP BY
                "#account_id",
                "$part_date"
        ) t_2
            ON t_1."#account_id" = t_2."#account_id"

        WHERE date(t_1.openid_create_role_time)${Time:time2}
          AND t_1."ad_platform"${Text:text3}
    ) role_day

    GROUP BY
        date(openid_create_role_time),
        "ad_platform",
        "nb_open_id"
) player_day0

GROUP BY
    "新增时间",
    "媒体平台"

ORDER BY
    "新增时间" DESC,
    "媒体平台";