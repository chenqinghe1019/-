SELECT
    row_number() OVER (
        ORDER BY q."分层排序"
    ) AS "序号",

    q."活动付费分层",
    q."人数",

    round(
        q."人数" * 1.0000
        / nullif(q."总付费人数", 0),
        4
    ) AS "人数占比",

    round(q."付费金额", 2) AS "付费金额",

    round(
        q."付费金额" * 1.0000
        / nullif(q."总付费金额", 0),
        4
    ) AS "付费金额占比",

    round(
        q."付费金额" * 1.0000
        / nullif(q."人数", 0),
        2
    ) AS "人均付费金额"

FROM
(
    SELECT
        CASE
            WHEN grouping(p."活动付费分层") = 1 THEN '汇总'
            ELSE p."活动付费分层"
        END AS "活动付费分层",

        CASE
            WHEN grouping(p."活动付费分层") = 1 THEN 0
            ELSE p."分层排序"
        END AS "分层排序",

        count(*) AS "人数",
        sum(p."活动付费金额") AS "付费金额",
        max(p."总付费人数") AS "总付费人数",
        max(p."总付费金额") AS "总付费金额"

    FROM
    (
        SELECT
            z."#account_id",
            z."活动付费分层",
            z."分层排序",
            z."活动付费金额",

            count(*) OVER () AS "总付费人数",
            sum(z."活动付费金额") OVER () AS "总付费金额"

        FROM
        (
            SELECT
                pay_user."#account_id",
                pay_user."活动付费金额",

                CASE
                    WHEN pay_user."活动付费金额" <= 12
                        THEN 'a.(0,12]'
                    WHEN pay_user."活动付费金额" <= 30
                        THEN 'b.(12,30]'
                    WHEN pay_user."活动付费金额" <= 68
                        THEN 'c.(30,68]'
                    WHEN pay_user."活动付费金额" <= 196
                        THEN 'd.(68,196]'
                    WHEN pay_user."活动付费金额" <= 328
                        THEN 'e.(196,328]'
                    WHEN pay_user."活动付费金额" <= 648
                        THEN 'f.(328,648]'
                    WHEN pay_user."活动付费金额" <= 1000
                        THEN 'g.(648,1000]'
                    WHEN pay_user."活动付费金额" <= 3000
                        THEN 'h.(1000,3000]'
                    WHEN pay_user."活动付费金额" <= 10000
                        THEN 'i.(3000,10000]'
                    ELSE 'j.(10000,+)'
                END AS "活动付费分层",

                CASE
                    WHEN pay_user."活动付费金额" <= 12 THEN 1
                    WHEN pay_user."活动付费金额" <= 30 THEN 2
                    WHEN pay_user."活动付费金额" <= 68 THEN 3
                    WHEN pay_user."活动付费金额" <= 196 THEN 4
                    WHEN pay_user."活动付费金额" <= 328 THEN 5
                    WHEN pay_user."活动付费金额" <= 648 THEN 6
                    WHEN pay_user."活动付费金额" <= 1000 THEN 7
                    WHEN pay_user."活动付费金额" <= 3000 THEN 8
                    WHEN pay_user."活动付费金额" <= 10000 THEN 9
                    ELSE 10
                END AS "分层排序"

            FROM
            (
                SELECT
                    active_user."#account_id",

                    sum(
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
                        ) / 100.0000
                    ) AS "活动付费金额"

                FROM
                (
                    SELECT DISTINCT
                        cast(a."#account_id" AS varchar) AS "#account_id",

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

                    WHERE u."domain" = 'release'
                      AND u."server_open_time" IS NOT NULL

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
                        cast(e0."#account_id" AS varchar) AS "#account_id",
                        e0."#event_time",
                        e0."product_id",
                        e0."payment",
                        e0."token_payment"

                    FROM ta.v_event_41 e0

                    WHERE ${PartDate:date2}
                      AND e0."domain" = 'release'
                      AND e0."$part_event" = 'pay_log'
                      AND e0."#account_id" IS NOT NULL

                      AND
                      (
                          coalesce(
                              try_cast(e0."payment" AS double),
                              0
                          ) > 0

                          OR

                          coalesce(
                              try_cast(e0."token_payment" AS double),
                              0
                          ) > 0
                      )
                ) e
                    ON e."#account_id" = active_user."#account_id"
                   AND e."#event_time" >= active_user."活动开始时间"
                   AND e."#event_time" < active_user."活动结束时间"

                INNER JOIN
                (
                    SELECT
                        try_cast("product_id" AS bigint) AS "product_id"

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

                GROUP BY 1

                HAVING
                    sum(
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
                        ) / 100.0000
                    ) > 0
            ) pay_user
        ) z
    ) p

    GROUP BY GROUPING SETS
    (
        (p."活动付费分层", p."分层排序"),
        ()
    )
) q

ORDER BY q."分层排序"