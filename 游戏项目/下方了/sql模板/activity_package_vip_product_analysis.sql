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
        a."VIP层级（活动开始前）",
        a."分层排序",
        p."礼包类型",
        p."礼包名",

        max(a."活动活跃人数") AS "活动活跃人数",

        count(
            DISTINCT a."#account_id"
        ) AS "付费人数",

        count(*) AS "购买次数",

        sum(
            p."单笔付费金额"
        ) AS "付费金额"

    FROM
    (
        SELECT
            z."#account_id",
            z."VIP层级（活动开始前）",
            z."分层排序",

            count(*) OVER (
                PARTITION BY z."VIP层级（活动开始前）"
            ) AS "活动活跃人数"

        FROM
        (
            SELECT
                act."#account_id",

                CASE
                    WHEN coalesce(
                        vip."活动开始前VIP等级",
                        0
                    ) BETWEEN 0 AND 3
                        THEN 'a.V0-V3'

                    WHEN coalesce(
                        vip."活动开始前VIP等级",
                        0
                    ) BETWEEN 4 AND 6
                        THEN 'b.V4-V6'

                    WHEN coalesce(
                        vip."活动开始前VIP等级",
                        0
                    ) BETWEEN 7 AND 9
                        THEN 'c.V7-V9'

                    ELSE 'd.V10+'
                END AS "VIP层级（活动开始前）",

                CASE
                    WHEN coalesce(
                        vip."活动开始前VIP等级",
                        0
                    ) BETWEEN 0 AND 3
                        THEN 1

                    WHEN coalesce(
                        vip."活动开始前VIP等级",
                        0
                    ) BETWEEN 4 AND 6
                        THEN 2

                    WHEN coalesce(
                        vip."活动开始前VIP等级",
                        0
                    ) BETWEEN 7 AND 9
                        THEN 3

                    ELSE 4
                END AS "分层排序"

            FROM
            (
                SELECT DISTINCT
                    cast(
                        e."#account_id"
                        AS varchar
                    ) AS "#account_id"

                FROM ta.v_event_41 e

                WHERE ${PartDate:date}

                  AND e."domain" = 'release'

                  AND e."$part_event" = 'in_out_log'

                  AND e."#account_id" IS NOT NULL
            ) act

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
            ) vip
                ON act."#account_id" = vip."#account_id"
        ) z
    ) a

    INNER JOIN
    (
        SELECT
            cast(
                e."#account_id"
                AS varchar
            ) AS "#account_id",

            product_cfg."product_type_two" AS "礼包类型",
            product_cfg."product_name" AS "礼包名",

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
            ) / 100.0000 AS "单笔付费金额"

        FROM
        (
            SELECT
                *

            FROM ta.v_event_41

            WHERE ${PartDate:date}

              AND "domain" = 'release'

              AND "$part_event" = 'pay_log'

              AND "#account_id" IS NOT NULL
        ) e

        INNER JOIN
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
        ) product_cfg
            ON try_cast(
                e."product_id"
                AS bigint
               ) = product_cfg."product_id"

        WHERE
        (
            coalesce(
                try_cast(
                    e."payment"
                    AS double
                ),
                0
            ) > 0

            OR

            coalesce(
                try_cast(
                    e."token_payment"
                    AS double
                ),
                0
            ) > 0
        )

          AND regexp_like(
                coalesce(
                    product_cfg."product_type_two",
                    ''
                ),
                '${Selector:selector1}'
              )
    ) p
        ON a."#account_id" = p."#account_id"

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