-- 下方了：新人特惠6元（免广告）且未买月卡玩家的自然日次留及24小时拆解
-- 项目：ta.v_user_41 / ta.v_event_41
-- 口径：
-- 1. 新人特惠6元 = pay_log.product_type = '新人特惠' AND product_id = 1。
-- 2. 首日付费金额 = 注册自然日全部 pay_log.payment / 100，不限制 pay_result。
-- 3. 未买月卡 = 注册时间至新人特惠购买后48小时内，product_type/product_name 均不包含“月卡”。
-- 4. 次留 = 注册次日自然日存在 in_out_log。
-- 5. 次留中24小时内/外，按注册次日第一条 in_out_log 距新人特惠购买时间是否超过24小时拆分。
-- 6. 两类互斥且完整：次留人数 = 24小时内次留人数 + 24小时外次留人数。
-- 7. 剔除内充用户分群 cohort_20260705_114557，使用 ta.user_result_cluster_41.#user_id 关联用户表 #user_id。
-- 8. 比例字段先乘100再 round(..., 2)，输出真实百分比数值，如66.67。
-- 9. 仅纳入新人特惠购买时间距当前时间已满48小时的完整观察样本。

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
            WHEN q."次日首次活跃时间" IS NOT NULL
            THEN q."账号ID"
        END
    ) AS "次留人数",

    round(
        count(
            DISTINCT CASE
                WHEN q."次日首次活跃时间" IS NOT NULL
                THEN q."账号ID"
            END
        ) * 100.0
        / nullif(count(DISTINCT q."账号ID"), 0),
        2
    ) AS "次留率",

    count(
        DISTINCT CASE
            WHEN q."次日首次活跃时间" IS NOT NULL
             AND q."次日首次活跃时间" <= date_add(
                    'hour',
                    24,
                    q."新人特惠6元购买时间"
                 )
            THEN q."账号ID"
        END
    ) AS "次留中24小时内人数",

    round(
        count(
            DISTINCT CASE
                WHEN q."次日首次活跃时间" IS NOT NULL
                 AND q."次日首次活跃时间" <= date_add(
                        'hour',
                        24,
                        q."新人特惠6元购买时间"
                     )
                THEN q."账号ID"
            END
        ) * 100.0
        / nullif(
            count(
                DISTINCT CASE
                    WHEN q."次日首次活跃时间" IS NOT NULL
                    THEN q."账号ID"
                END
            ),
            0
        ),
        2
    ) AS "次留中24小时内占比",

    count(
        DISTINCT CASE
            WHEN q."次日首次活跃时间" > date_add(
                    'hour',
                    24,
                    q."新人特惠6元购买时间"
                 )
            THEN q."账号ID"
        END
    ) AS "次留中24小时外人数",

    round(
        count(
            DISTINCT CASE
                WHEN q."次日首次活跃时间" > date_add(
                        'hour',
                        24,
                        q."新人特惠6元购买时间"
                     )
                THEN q."账号ID"
            END
        ) * 100.0
        / nullif(
            count(
                DISTINCT CASE
                    WHEN q."次日首次活跃时间" IS NOT NULL
                    THEN q."账号ID"
                END
            ),
            0
        ),
        2
    ) AS "次留中24小时外占比"

FROM
(
    SELECT
        s."账号ID",
        s."新增日期",
        s."新人特惠6元购买时间",
        s."次日首次活跃时间",

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

            min(
                CASE
                    WHEN e."$part_event" = 'in_out_log'
                     AND date(e."$part_date") = date_add(
                            'day',
                            1,
                            t."新增日期"
                         )
                    THEN e."#event_time"
                END
            ) AS "次日首次活跃时间"

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
                        vu."#account_id",
                        vu.create_role_time,

                        date_format(
                            vu.create_role_time,
                            '%Y-%m-%d'
                        ) AS "$part_date"

                    FROM ta.v_user_41 vu

                    LEFT JOIN
                    (
                        SELECT DISTINCT
                            "#user_id"

                        FROM ta.user_result_cluster_41

                        WHERE cluster_name = 'cohort_20260705_114557'
                          AND "#user_id" IS NOT NULL
                    ) internal_user
                      ON internal_user."#user_id" = vu."#user_id"

                    WHERE vu.domain = 'release'
                      AND vu."#account_id" IS NOT NULL
                      AND vu.create_role_time IS NOT NULL
                      AND internal_user."#user_id" IS NULL
                ) x

                WHERE ${PartDate:date}
            ) u

            LEFT JOIN ta.v_event_41 p
              ON p."#account_id" = u."账号ID"
             AND p.domain = 'release'
             AND p."$part_event" = 'pay_log'
             AND p."$part_date" = cast(
                    u."新增日期" AS varchar
                 )

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
         AND e."$part_event" IN (
                'in_out_log',
                'pay_log'
             )
         AND e."#event_time" >= t."新增时间"
         AND e."#event_time" <= date_add(
                'hour',
                48,
                t."新人特惠6元购买时间"
             )
         AND cast(e."$part_date" AS date)
                BETWEEN t."新增日期"
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
