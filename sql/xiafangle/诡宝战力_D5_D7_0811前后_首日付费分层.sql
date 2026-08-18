-- 下方了：8月11日前后新增玩家 D5-D7 诡宝相关战力提升对比
-- 口径：
-- 1. 新增日按 create_role_time；D1=创角当天，因此 D5-D7 为创角后第4~6个自然日。
-- 2. 仅纳入已经完整走到D7的新增，避免尚未成熟的新增被当成0。
-- 3. 首日付费分层沿用标准口径，pay_log.payment 单位分，/100转元，不限制 pay_result。
-- 4. 诡宝相关战力：change_power_log.change_reason=5635(升星)、5636(升阶)，num 为本次战力变化量，仅累计正向变化。
-- 5. ${PartDate:date} 控制新增日期范围。

SELECT
    row_number() over(
        ORDER BY q."新增第N天", q."首日付费分层"
    ) "序号",
    q."新增第N天",
    q."首日付费分层",

    q."8月11日前成熟新增人数",
    q."8月11日及后成熟新增人数",
    q."8月11日前当日活跃人数",
    q."8月11日及后当日活跃人数",

    q."8月11日前诡宝战力总提升",
    q."8月11日及后诡宝战力总提升",

    q."8月11日前新增人均诡宝战力提升",
    q."8月11日及后新增人均诡宝战力提升",
    round(
        q."8月11日及后新增人均诡宝战力提升"
        - q."8月11日前新增人均诡宝战力提升",
        2
    ) "新增人均提升差值",
    round(
        q."8月11日及后新增人均诡宝战力提升" * 1.0000
        / nullif(q."8月11日前新增人均诡宝战力提升", 0)
        - 1,
        4
    ) "新增人均提升变化率",

    q."8月11日前活跃人均诡宝战力提升",
    q."8月11日及后活跃人均诡宝战力提升",
    round(
        q."8月11日及后活跃人均诡宝战力提升"
        - q."8月11日前活跃人均诡宝战力提升",
        2
    ) "活跃人均提升差值",
    round(
        q."8月11日及后活跃人均诡宝战力提升" * 1.0000
        / nullif(q."8月11日前活跃人均诡宝战力提升", 0)
        - 1,
        4
    ) "活跃人均提升变化率",

    q."8月11日前诡宝战力提升覆盖率",
    q."8月11日及后诡宝战力提升覆盖率",
    round(
        q."8月11日及后诡宝战力提升覆盖率"
        - q."8月11日前诡宝战力提升覆盖率",
        4
    ) "提升覆盖率差值"
FROM
(
    SELECT
        t."新增第N天",
        t."首日付费分层",

        sum(
            CASE
                WHEN t."新增分组" = '8月11日前新增' THEN 1
                ELSE 0
            END
        ) "8月11日前成熟新增人数",

        sum(
            CASE
                WHEN t."新增分组" = '8月11日及后新增' THEN 1
                ELSE 0
            END
        ) "8月11日及后成熟新增人数",

        sum(
            CASE
                WHEN t."新增分组" = '8月11日前新增'
                 AND t."当日是否活跃" = 1
                THEN 1
                ELSE 0
            END
        ) "8月11日前当日活跃人数",

        sum(
            CASE
                WHEN t."新增分组" = '8月11日及后新增'
                 AND t."当日是否活跃" = 1
                THEN 1
                ELSE 0
            END
        ) "8月11日及后当日活跃人数",

        round(
            sum(
                CASE
                    WHEN t."新增分组" = '8月11日前新增'
                    THEN t."诡宝战力提升"
                    ELSE 0
                END
            ),
            2
        ) "8月11日前诡宝战力总提升",

        round(
            sum(
                CASE
                    WHEN t."新增分组" = '8月11日及后新增'
                    THEN t."诡宝战力提升"
                    ELSE 0
                END
            ),
            2
        ) "8月11日及后诡宝战力总提升",

        round(
            sum(
                CASE
                    WHEN t."新增分组" = '8月11日前新增'
                    THEN t."诡宝战力提升"
                    ELSE 0
                END
            ) * 1.0000
            / nullif(
                sum(
                    CASE
                        WHEN t."新增分组" = '8月11日前新增' THEN 1
                        ELSE 0
                    END
                ),
                0
            ),
            2
        ) "8月11日前新增人均诡宝战力提升",

        round(
            sum(
                CASE
                    WHEN t."新增分组" = '8月11日及后新增'
                    THEN t."诡宝战力提升"
                    ELSE 0
                END
            ) * 1.0000
            / nullif(
                sum(
                    CASE
                        WHEN t."新增分组" = '8月11日及后新增' THEN 1
                        ELSE 0
                    END
                ),
                0
            ),
            2
        ) "8月11日及后新增人均诡宝战力提升",

        round(
            sum(
                CASE
                    WHEN t."新增分组" = '8月11日前新增'
                     AND t."当日是否活跃" = 1
                    THEN t."诡宝战力提升"
                    ELSE 0
                END
            ) * 1.0000
            / nullif(
                sum(
                    CASE
                        WHEN t."新增分组" = '8月11日前新增'
                         AND t."当日是否活跃" = 1
                        THEN 1
                        ELSE 0
                    END
                ),
                0
            ),
            2
        ) "8月11日前活跃人均诡宝战力提升",

        round(
            sum(
                CASE
                    WHEN t."新增分组" = '8月11日及后新增'
                     AND t."当日是否活跃" = 1
                    THEN t."诡宝战力提升"
                    ELSE 0
                END
            ) * 1.0000
            / nullif(
                sum(
                    CASE
                        WHEN t."新增分组" = '8月11日及后新增'
                         AND t."当日是否活跃" = 1
                        THEN 1
                        ELSE 0
                    END
                ),
                0
            ),
            2
        ) "8月11日及后活跃人均诡宝战力提升",

        round(
            sum(
                CASE
                    WHEN t."新增分组" = '8月11日前新增'
                     AND t."诡宝战力提升" > 0
                    THEN 1
                    ELSE 0
                END
            ) * 1.0000
            / nullif(
                sum(
                    CASE
                        WHEN t."新增分组" = '8月11日前新增' THEN 1
                        ELSE 0
                    END
                ),
                0
            ),
            4
        ) "8月11日前诡宝战力提升覆盖率",

        round(
            sum(
                CASE
                    WHEN t."新增分组" = '8月11日及后新增'
                     AND t."诡宝战力提升" > 0
                    THEN 1
                    ELSE 0
                END
            ) * 1.0000
            / nullif(
                sum(
                    CASE
                        WHEN t."新增分组" = '8月11日及后新增' THEN 1
                        ELSE 0
                    END
                ),
                0
            ),
            4
        ) "8月11日及后诡宝战力提升覆盖率"
    FROM
    (
        SELECT
            b."#account_id",
            b."新增分组",
            b."首日付费分层",
            d."新增第N天",
            coalesce(a."当日是否活跃", 0) "当日是否活跃",
            coalesce(g."诡宝战力提升", 0) "诡宝战力提升"
        FROM
        (
            SELECT
                u."#account_id",
                u."新增日期",
                CASE
                    WHEN u."新增日期" < date '2026-08-11'
                    THEN '8月11日前新增'
                    ELSE '8月11日及后新增'
                END "新增分组",
                CASE
                    WHEN coalesce(p."首日付费金额", 0) = 0 THEN 'a_free'
                    WHEN coalesce(p."首日付费金额", 0) <= 6 THEN 'b_(0,6]'
                    WHEN coalesce(p."首日付费金额", 0) <= 30 THEN 'c_(6,30]'
                    WHEN coalesce(p."首日付费金额", 0) <= 100 THEN 'd_(30,100]'
                    WHEN coalesce(p."首日付费金额", 0) <= 300 THEN 'e_(100,300]'
                    WHEN coalesce(p."首日付费金额", 0) <= 500 THEN 'f_(300,500]'
                    WHEN coalesce(p."首日付费金额", 0) <= 1000 THEN 'g_(500,1000]'
                    ELSE 'h_1000+'
                END "首日付费分层"
            FROM
            (
                SELECT
                    u0."#account_id",
                    u0."新增日期",
                    u0."$part_date"
                FROM
                (
                    SELECT
                        "#account_id",
                        date("create_role_time") "新增日期",
                        cast(date("create_role_time") AS varchar) "$part_date"
                    FROM ta.v_user_41
                    WHERE "domain" = 'release'
                      AND "create_role_time" IS NOT NULL
                ) u0
                WHERE ${PartDate:date}
                  AND u0."新增日期" <= date_add('day', -6, current_date)
            ) u
            LEFT JOIN
            (
                SELECT
                    "#account_id",
                    "$part_date",
                    sum(coalesce("payment", 0)) * 1.0000 / 100 "首日付费金额"
                FROM ta.v_event_41
                WHERE "#event_name" = 'pay_log'
                  AND "domain" = 'release'
                GROUP BY
                    "#account_id",
                    "$part_date"
            ) p
                ON u."#account_id" = p."#account_id"
               AND u."$part_date" = p."$part_date"
        ) b
        CROSS JOIN UNNEST(sequence(5, 7)) d("新增第N天")
        LEFT JOIN
        (
            SELECT
                "#account_id",
                cast(
                    date_diff(
                        'day',
                        date("create_role_time"),
                        date("#event_time")
                    ) + 1
                    AS integer
                ) "新增第N天",
                1 "当日是否活跃"
            FROM ta.v_event_41
            WHERE "#event_name" = 'in_out_log'
              AND "domain" = 'release'
              AND "create_role_time" IS NOT NULL
              AND date_diff(
                    'day',
                    date("create_role_time"),
                    date("#event_time")
                  ) + 1 BETWEEN 5 AND 7
            GROUP BY
                "#account_id",
                cast(
                    date_diff(
                        'day',
                        date("create_role_time"),
                        date("#event_time")
                    ) + 1
                    AS integer
                )
        ) a
            ON b."#account_id" = a."#account_id"
           AND d."新增第N天" = a."新增第N天"
        LEFT JOIN
        (
            SELECT
                "#account_id",
                cast(
                    date_diff(
                        'day',
                        date("create_role_time"),
                        date("#event_time")
                    ) + 1
                    AS integer
                ) "新增第N天",
                sum(
                    CASE
                        WHEN try_cast("change_reason" AS bigint) IN (5635, 5636)
                        THEN greatest(coalesce("num", 0), 0)
                        ELSE 0
                    END
                ) "诡宝战力提升"
            FROM ta.v_event_41
            WHERE "#event_name" = 'change_power_log'
              AND "domain" = 'release'
              AND "create_role_time" IS NOT NULL
              AND try_cast("change_reason" AS bigint) IN (5635, 5636)
              AND date_diff(
                    'day',
                    date("create_role_time"),
                    date("#event_time")
                  ) + 1 BETWEEN 5 AND 7
            GROUP BY
                "#account_id",
                cast(
                    date_diff(
                        'day',
                        date("create_role_time"),
                        date("#event_time")
                    ) + 1
                    AS integer
                )
        ) g
            ON b."#account_id" = g."#account_id"
           AND d."新增第N天" = g."新增第N天"
    ) t
    GROUP BY
        t."新增第N天",
        t."首日付费分层"
) q
ORDER BY
    q."新增第N天",
    q."首日付费分层"
