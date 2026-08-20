SELECT
    row_number() OVER (
        ORDER BY
            q."周期排序",
            q."分层排序"
    ) AS "序号",

    q."活动周期",
    q."VIP层级（周期开始前）",
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

        concat(
            '第',
            cast(
                p."周期排序"
                AS varchar
            ),
            '周期'
        ) AS "活动周期",

        CASE
            WHEN grouping(
                p."VIP层级"
            ) = 1
                THEN '汇总'
            ELSE p."VIP层级"
        END AS "VIP层级（周期开始前）",

        CASE
            WHEN grouping(
                p."VIP层级"
            ) = 1
                THEN 0
            ELSE max(
                p."分层排序"
            )
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
                 AND p."周期活动付费金额" > 0
                    THEN 1
                ELSE 0
            END
        ) AS "活动付费人数",

        sum(
            CASE
                WHEN p."是否参与矿脉" = 1
                    THEN p."周期活动付费金额"
                ELSE 0
            END
        ) AS "活动付费金额"

    FROM
    (
        SELECT
            y."#account_id",
            y."region_id",
            y."周期排序",

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

            y."是否参与矿脉",
            y."周期活动付费金额"

        FROM
        (
            SELECT
                x."#account_id",
                x."region_id",
                x."周期排序",
                x."周期开始日期",
                x."是否参与矿脉",
                x."周期活动付费金额",

                max(
                    try_cast(
                        vip_e."after"
                        AS bigint
                    )
                ) AS "周期开始前VIP等级"

            FROM
            (
                SELECT
                    active_player."#account_id",
                    active_player."region_id",
                    active_player."周期排序",
                    active_player."周期开始日期",
                    user_base."开服日期",

                    max(
                        CASE
                            WHEN e."$part_event"
                                    = 'mining_log'
                                THEN 1
                            ELSE 0
                        END
                    ) AS "是否参与矿脉",

                    sum(
                        CASE
                            WHEN e."$part_event"
                                    = 'pay_log'

                             AND product_cfg."product_id"
                                    IS NOT NULL

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
                    ) AS "周期活动付费金额"

                FROM
                (
                    /*
                     * 周期活跃玩家：
                     * 同一个玩家在3日周期任意一天有in_out_log，
                     * 周期内只保留1条。
                     */
                    SELECT DISTINCT
                        cast(
                            a."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        cast(
                            a."region_id"
                            AS varchar
                        ) AS "region_id",

                        mature_cycle."周期排序",
                        mature_cycle."周期开始日期"

                    FROM ta.v_event_41 a

                    INNER JOIN
                    (
                        SELECT
                            cycle_start."region_id",
                            cycle_start."周期排序",
                            cycle_start."周期开始日期"

                        FROM
                        (
                            SELECT
                                cycle_mark."region_id",
                                cycle_mark."日志日期"
                                    AS "周期开始日期",

                                sum(
                                    cycle_mark."是否新周期"
                                ) OVER (
                                    PARTITION BY
                                        cycle_mark."region_id"

                                    ORDER BY
                                        cycle_mark."日志日期"

                                    ROWS BETWEEN
                                        UNBOUNDED PRECEDING
                                        AND CURRENT ROW
                                ) AS "周期排序",

                                cycle_mark."是否新周期"

                            FROM
                            (
                                SELECT
                                    prev_day."region_id",
                                    prev_day."日志日期",

                                    CASE
                                        WHEN prev_day."上一日志日期"
                                                IS NULL
                                            THEN 1

                                        /*
                                         * 单期固定3天。
                                         * 周期内即使某天没有mining_log，
                                         * 也不能因此切成新一期。
                                         * 相邻mining_log间隔超过3天
                                         * 才视为下一期。
                                         */
                                        WHEN date_diff(
                                            'day',
                                            prev_day."上一日志日期",
                                            prev_day."日志日期"
                                        ) > 3
                                            THEN 1

                                        ELSE 0
                                    END AS "是否新周期"

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
                                        /*
                                         * mining_log按区服+自然日去重，
                                         * 各区服独立识别玩法实际起点和断点。
                                         */
                                        SELECT DISTINCT
                                            cast(
                                                m."region_id"
                                                AS varchar
                                            ) AS "region_id",

                                            date(
                                                m."#event_time"
                                            ) AS "日志日期"

                                        FROM ta.v_event_41 m

                                        WHERE ${PartDate:date2}

                                          AND m."domain"
                                              = 'release'

                                          AND m."$part_event"
                                              = 'mining_log'

                                          AND m."region_id"
                                              IS NOT NULL
                                    ) server_day
                                ) prev_day
                            ) cycle_mark
                        ) cycle_start

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

                        WHERE cycle_start."是否新周期" = 1

                          /*
                           * 完整3日周期只判断查询日期是否完整覆盖：
                           * 周期开始日、+1日、+2日。
                           * 不要求后两日真实出现mining_log。
                           */
                          AND cycle_start."周期开始日期"
                                >= stats_period."统计开始日期"

                          AND date_add(
                                'day',
                                2,
                                cycle_start."周期开始日期"
                              )
                              <= stats_period."统计结束日期"
                    ) mature_cycle

                        ON cast(
                            a."region_id"
                            AS varchar
                           ) = mature_cycle."region_id"

                       AND date(
                            a."#event_time"
                           ) BETWEEN mature_cycle."周期开始日期"
                               AND date_add(
                                    'day',
                                    2,
                                    mature_cycle."周期开始日期"
                               )

                    WHERE ${PartDate:date2}

                      AND a."domain"
                          = 'release'

                      AND a."$part_event"
                          = 'in_out_log'

                      AND a."#account_id"
                          IS NOT NULL

                      AND a."region_id"
                          IS NOT NULL
                ) active_player

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

                    WHERE u."domain"
                            = 'release'

                      AND u."#account_id"
                            IS NOT NULL

                      AND u."server_open_time"
                            IS NOT NULL

                    GROUP BY 1
                ) user_base

                    ON active_player."#account_id"
                        = user_base."#account_id"

                LEFT JOIN
                (
                    /*
                     * 周期事件：
                     * mining_log用于判断周期内是否参与；
                     * pay_log用于累计周期内目标礼包付费。
                     */
                    SELECT
                        cast(
                            e0."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        cast(
                            e0."region_id"
                            AS varchar
                        ) AS "region_id",

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

                      AND e0."region_id"
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
                        = active_player."#account_id"

                   AND e."region_id"
                        = active_player."region_id"

                   AND date(
                        e."#event_time"
                       ) BETWEEN active_player."周期开始日期"
                           AND date_add(
                                'day',
                                2,
                                active_player."周期开始日期"
                           )

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
                    5
            ) x

            LEFT JOIN ta.v_event_41 vip_e

                ON cast(
                    vip_e."#account_id"
                    AS varchar
                ) = x."#account_id"

               AND cast(
                    vip_e."region_id"
                    AS varchar
                   ) = x."region_id"

               AND vip_e."$part_event"
                    = 'vip_change_log'

               AND vip_e."domain"
                    = 'release'

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
                6
        ) y
    ) p

    GROUP BY GROUPING SETS
    (
        (
            p."周期排序",
            p."VIP层级",
            p."分层排序"
        ),
        (
            p."周期排序"
        )
    )
) q

ORDER BY
    q."周期排序",
    q."分层排序"