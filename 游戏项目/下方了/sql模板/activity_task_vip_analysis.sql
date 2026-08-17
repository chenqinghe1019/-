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

        count(
            DISTINCT CASE
                WHEN p."是否活动活跃" = 1
                    THEN p."#account_id"
            END
        ) AS "活动活跃人数",

        count(
            DISTINCT CASE
                WHEN p."是否参与活动" = 1
                    THEN p."#account_id"
            END
        ) AS "活动参与人数",

        count(
            DISTINCT CASE
                WHEN p."是否参与活动" = 1
                 AND p."活动付费金额" > 0
                    THEN p."#account_id"
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
                WHEN coalesce(
                    v."活动开始前VIP等级",
                    0
                ) BETWEEN 0 AND 3
                    THEN 'a.V0-V3'

                WHEN coalesce(
                    v."活动开始前VIP等级",
                    0
                ) BETWEEN 4 AND 6
                    THEN 'b.V4-V6'

                WHEN coalesce(
                    v."活动开始前VIP等级",
                    0
                ) BETWEEN 7 AND 9
                    THEN 'c.V7-V9'

                ELSE 'd.V10+'
            END AS "VIP层级",

            CASE
                WHEN coalesce(
                    v."活动开始前VIP等级",
                    0
                ) BETWEEN 0 AND 3
                    THEN 1

                WHEN coalesce(
                    v."活动开始前VIP等级",
                    0
                ) BETWEEN 4 AND 6
                    THEN 2

                WHEN coalesce(
                    v."活动开始前VIP等级",
                    0
                ) BETWEEN 7 AND 9
                    THEN 3

                ELSE 4
            END AS "分层排序",

            x."是否活动活跃",
            x."是否参与活动",
            x."活动付费金额"

        FROM
        (
            SELECT
                cast(
                    e."#account_id"
                    AS varchar
                ) AS "#account_id",

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

                         AND try_cast(
                            e."task_type"
                            AS bigint
                         ) ${Selector:selector}

                            THEN 1
                        ELSE 0
                    END
                ) AS "是否参与活动",

                sum(
                    CASE
                        WHEN e."$part_event" = 'pay_log'

                         AND coalesce(
                            try_cast(
                                e."payment"
                                AS double
                            ),
                            0
                         ) > 0

                         AND regexp_like(
                            concat(
                                coalesce(
                                    cast(
                                        e."product_type"
                                        AS varchar
                                    ),
                                    ''
                                ),
                                '|',
                                coalesce(
                                    cast(
                                        e."product_name"
                                        AS varchar
                                    ),
                                    ''
                                )
                            ),
                            '${Selector:selector1}'
                         )

                            THEN coalesce(
                                try_cast(
                                    e."payment"
                                    AS double
                                ),
                                0
                            ) / 100.0000

                        ELSE 0
                    END
                ) AS "活动付费金额"

            FROM
            (
                SELECT
                    *

                FROM ta.v_event_41

                WHERE ${PartDate:date}

                  AND "domain" = 'release'

                  AND "#account_id" IS NOT NULL
            ) e

            GROUP BY
                1
        ) x

        LEFT JOIN
        (
            SELECT
                cast(
                    vip_e."#account_id"
                    AS varchar
                ) AS "#account_id",

                max_by(
                    try_cast(
                        vip_e."after"
                        AS bigint
                    ),
                    vip_e."#event_time"
                ) AS "活动开始前VIP等级"

            FROM ta.v_event_41 vip_e

            CROSS JOIN
            (
                SELECT
                    cast(
                        min(
                            cast(
                                d."$part_date"
                                AS date
                            )
                        )
                        AS timestamp
                    ) AS "活动开始时间"

                FROM
                (
                    SELECT
                        "$part_date"

                    FROM ta.v_event_41

                    WHERE ${PartDate:date}
                ) d
            ) activity_date

            WHERE vip_e."$part_event" = 'vip_change_log'

              AND vip_e."domain" = 'release'

              AND vip_e."#account_id" IS NOT NULL

              AND vip_e."#event_time"
                  < activity_date."活动开始时间"

            GROUP BY
                1
        ) v

            ON x."#account_id" = v."#account_id"
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