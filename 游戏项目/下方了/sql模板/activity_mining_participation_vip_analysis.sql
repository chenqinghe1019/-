SELECT
    row_number() OVER (
        ORDER BY q."分层排序"
    ) AS "序号",

    q."VIP层级（活动开始前）",
    q."活动活跃人数",
    q."矿脉参与人数",

    round(
        q."矿脉参与人数" * 1.0000
        / nullif(q."活动活跃人数", 0),
        4
    ) AS "矿脉参与率"

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

        count(*) AS "活动活跃人数",

        sum(
            CASE
                WHEN p."是否参与矿脉" = 1
                    THEN 1
                ELSE 0
            END
        ) AS "矿脉参与人数"

    FROM
    (
        SELECT
            y."#account_id",

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

            y."是否参与矿脉"

        FROM
        (
            SELECT
                x."#account_id",
                x."是否参与矿脉",

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

                    max(
                        CASE
                            WHEN mining_e."#account_id" IS NOT NULL
                                THEN 1
                            ELSE 0
                        END
                    ) AS "是否参与矿脉"

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
                            "#event_time",
                            cast(
                                "region_id"
                                AS varchar
                            ) AS "region_id"

                        FROM ta.v_event_41

                        WHERE ${PartDate:date2}

                          AND "domain"
                              = 'release'

                          AND "$part_event"
                              = 'in_out_log'

                          AND "#account_id"
                              IS NOT NULL

                          AND "region_id"
                              IS NOT NULL
                    ) a

                    /*
                     * 只有“该区服当天真实出现过mining_log”的自然日
                     * 才纳入活动活跃分母
                     */
                    INNER JOIN
                    (
                        SELECT DISTINCT
                            cast(
                                m."region_id"
                                AS varchar
                            ) AS "region_id",

                            date(
                                m."#event_time"
                            ) AS "矿脉日期"

                        FROM ta.v_event_41 m

                        WHERE ${PartDate:date2}

                          AND m."domain"
                              = 'release'

                          AND m."$part_event"
                              = 'mining_log'

                          AND m."region_id"
                              IS NOT NULL
                    ) mining_server_day

                        ON a."region_id"
                            = mining_server_day."region_id"

                       AND date(
                            a."#event_time"
                           )
                           = mining_server_day."矿脉日期"

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

                      /* mining_log有效区服日仍需处于目标开服天数范围 */
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
                ) active_user

                LEFT JOIN
                (
                    SELECT
                        cast(
                            e0."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        e0."#event_time"

                    FROM ta.v_event_41 e0

                    WHERE ${PartDate:date2}

                      AND e0."domain"
                          = 'release'

                      AND e0."#account_id"
                          IS NOT NULL

                      AND e0."$part_event"
                          = 'mining_log'
                ) mining_e

                    ON mining_e."#account_id"
                        = active_user."#account_id"

                   AND mining_e."#event_time"
                        >= active_user."活动开始时间"

                   AND mining_e."#event_time"
                        < active_user."活动开始时间"
                            + interval '1' day
                            * (
                                date_diff(
                                    'day',
                                    date(active_user."活动开始时间"),
                                    date_add(
                                        'day',
                                        0,
                                        date(active_user."活动开始时间")
                                    )
                                ) + 1
                              )

                GROUP BY
                    1,
                    2,
                    3
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
                2
        ) y
    ) p

    GROUP BY GROUPING SETS
    (
        (
            p."VIP层级",
            p."分层排序"
        ),
        ()
    )
) q

ORDER BY
    q."分层排序"