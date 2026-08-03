-- 下方了：新人特惠6元（免广告）且未买月卡玩家的购买后24小时留存
-- 项目：ta.v_user_41 / ta.v_event_41
-- 口径：
-- 1. 新人特惠6元 = pay_log.product_type = '新人特惠' AND product_id = 1。
-- 2. 首日付费金额 = 注册自然日全部 pay_log.payment / 100，不限制 pay_result。
-- 3. 未买月卡 = 注册时间至新人特惠购买后48小时内，product_type/product_name 均不包含“月卡”。
-- 4. 购买后24小时留存 = 购买后第24至48小时存在 in_out_log。
-- 5. 购买后24小时流失 = 购买后第24至48小时不存在 in_out_log。
-- 6. 仅纳入购买时间距当前时间已满48小时的完整观察样本。

SELECT
    concat(
        cast(min(q."新增日期") AS varchar),
        ' 至 ',
        cast(max(q."新增日期") AS varchar)
    ) AS "新增区间",

    CASE
        WHEN grouping(q."首日付费分层") = 1 THEN '汇总'
        ELSE q."首日付费分层"
    END AS "首日付费分层",

    count(DISTINCT q."账号ID") AS "新人特惠6元且未买月卡人数",

    count(
        DISTINCT CASE
            WHEN q."购买后0至24小时有活跃" = 1
            THEN q."账号ID"
        END
    ) AS "购买后0至24小时活跃人数",

    round(
        count(
            DISTINCT CASE
                WHEN q."购买后0至24小时有活跃" = 1
                THEN q."账号ID"
            END
        ) * 1.0
        / nullif(count(DISTINCT q."账号ID"), 0),
        4
    ) AS "购买后0至24小时活跃率",

    count(
        DISTINCT CASE
            WHEN q."购买后24至48小时有活跃" = 1
            THEN q."账号ID"
        END
    ) AS "购买后24至48小时留存人数",

    round(
        count(
            DISTINCT CASE
                WHEN q."购买后24至48小时有活跃" = 1
                THEN q."账号ID"
            END
        ) * 1.0
        / nullif(count(DISTINCT q."账号ID"), 0),
        4
    ) AS "购买后24小时留存率",

    count(
        DISTINCT CASE
            WHEN q."购买后24至48小时有活跃" = 0
            THEN q."账号ID"
        END
    ) AS "购买后24小时流失人数",

    round(
        count(
            DISTINCT CASE
                WHEN q."购买后24至48小时有活跃" = 0
                THEN q."账号ID"
            END
        ) * 1.0
        / nullif(count(DISTINCT q."账号ID"), 0),
        4
    ) AS "购买后24小时流失率",

    round(
        avg(
            CASE
                WHEN q."购买后0至24小时最后活跃时间" IS NOT NULL
                THEN date_diff(
                    'second',
                    q."新人特惠6元购买时间",
                    q."购买后0至24小时最后活跃时间"
                ) / 3600.0
            END
        ),
        2
    ) AS "购买后首24小时最后活跃距购买小时"

FROM
(
    SELECT
        s."账号ID",
        s."新增日期",
        s."新人特惠6元购买时间",
        s."购买后0至24小时有活跃",
        s."购买后24至48小时有活跃",
        s."购买后0至24小时最后活跃时间",

        CASE
            WHEN s."首日付费金额" = 0 THEN 'a_R0_免费'
            WHEN s."首日付费金额" <= 6 THEN 'b_(0,6]'
            WHEN s."首日付费金额" <= 30 THEN 'c_(6,30]'
            WHEN s."首日付费金额" <= 100 THEN 'd_(30,100]'
            WHEN s."首日付费金额" <= 300 THEN 'e_(100,300]'
            WHEN s."首日付费金额" <= 500 THEN 'f_(300,500]'
            WHEN s."首日付费金额" <= 1000 THEN 'g_(500,1000]'
            ELSE 'h_1000+'
        END AS "首日付费分层"

    FROM
    (
        SELECT
            t."账号ID",
            t."新增日期",
            t."首日付费金额",
            t."新人特惠6元购买时间",

            max(
                CASE
                    WHEN e."$part_event" = 'pay_log'
                     AND regexp_like(
                            concat(
                                coalesce(cast(e.product_type AS varchar), ''),
                                coalesce(cast(e.product_name AS varchar), '')
                            ),
                            '月卡'
                         )
                    THEN 1
                    ELSE 0
                END
            ) AS "观察期内是否购买月卡",

            max(
                CASE
                    WHEN e."$part_event" = 'in_out_log'
                     AND e."#event_time" > t."新人特惠6元购买时间"
                     AND e."#event_time" <= date_add(
                            'hour',
                            24,
                            t."新人特惠6元购买时间"
                         )
                    THEN 1
                    ELSE 0
                END
            ) AS "购买后0至24小时有活跃",

            max(
                CASE
                    WHEN e."$part_event" = 'in_out_log'
                     AND e."#event_time" > date_add(
                            'hour',
                            24,
                            t."新人特惠6元购买时间"
                         )
                     AND e."#event_time" <= date_add(
                            'hour',
                            48,
                            t."新人特惠6元购买时间"
                         )
                    THEN 1
                    ELSE 0
                END
            ) AS "购买后24至48小时有活跃",

            max(
                CASE
                    WHEN e."$part_event" = 'in_out_log'
                     AND e."#event_time" > t."新人特惠6元购买时间"
                     AND e."#event_time" <= date_add(
                            'hour',
                            24,
                            t."新人特惠6元购买时间"
                         )
                    THEN e."#event_time"
                END
            ) AS "购买后0至24小时最后活跃时间"

        FROM
        (
            SELECT
                u."账号ID",
                u."新增时间",
                u."新增日期",

                round(
                    sum(
                        coalesce(
                            try_cast(p.payment AS double),
                            0
                        )
                    ) / 100.0,
                    2
                ) AS "首日付费金额",

                min(
                    CASE
                        WHEN p.product_type = '新人特惠'
                         AND try_cast(p.product_id AS bigint) = 1
                        THEN p."#event_time"
                    END
                ) AS "新人特惠6元购买时间"

            FROM
            (
                SELECT
                    x."#account_id" AS "账号ID",
                    x.create_role_time AS "新增时间",
                    date(x.create_role_time) AS "新增日期"
                FROM
                (
                    SELECT
                        "#account_id",
                        create_role_time,
                        date_format(create_role_time, '%Y-%m-%d') AS "$part_date"
                    FROM ta.v_user_41
                    WHERE domain = 'release'
                      AND "#account_id" IS NOT NULL
                      AND create_role_time IS NOT NULL
                ) x
                WHERE ${PartDate:date}
            ) u

            LEFT JOIN ta.v_event_41 p
              ON p."#account_id" = u."账号ID"
             AND p.domain = 'release'
             AND p."$part_event" = 'pay_log'
             AND p."$part_date" = cast(u."新增日期" AS varchar)

            GROUP BY
                u."账号ID",
                u."新增时间",
                u."新增日期"

            HAVING min(
                CASE
                    WHEN p.product_type = '新人特惠'
                     AND try_cast(p.product_id AS bigint) = 1
                    THEN p."#event_time"
                END
            ) IS NOT NULL
        ) t

        LEFT JOIN ta.v_event_41 e
          ON e."#account_id" = t."账号ID"
         AND e.domain = 'release'
         AND e."$part_event" IN ('in_out_log', 'pay_log')
         AND e."#event_time" >= t."新增时间"
         AND e."#event_time" <= date_add(
                'hour',
                48,
                t."新人特惠6元购买时间"
             )
         AND cast(e."$part_date" AS date) BETWEEN t."新增日期"
                                             AND date(
                                                    date_add(
                                                        'hour',
                                                        48,
                                                        t."新人特惠6元购买时间"
                                                    )
                                                 )

        WHERE t."新人特惠6元购买时间" <= date_add(
                'hour',
                -48,
                localtimestamp
              )

        GROUP BY
            t."账号ID",
            t."新增日期",
            t."首日付费金额",
            t."新人特惠6元购买时间"
    ) s

    WHERE s."观察期内是否购买月卡" = 0
) q

GROUP BY GROUPING SETS
(
    (q."首日付费分层"),
    ()
)

ORDER BY
    grouping(q."首日付费分层"),
    q."首日付费分层";
