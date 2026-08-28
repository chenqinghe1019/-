-- 下方了｜新增天数 × 首日付费分层 × 战力变化原因
-- 口径：
-- 1. ${PartDate:date1} 筛选新增日期，不直接筛 change_power_log 事件日期。
-- 2. 新增天数：创角当天 D1，次日 D2，以此类推。
-- 3. 首日付费：仅统计创角当天 payment>0 的 pay_log；payment 单位为分，/100 转元后分层。
-- 4. 战力变化值 = after - before。
-- 5. 每个“新增天数 × 首日付费分层”增加一条分层汇总，仅汇总变化原因，不跨付费分层汇总。
-- 6. 正向战力贡献占比 = 该变化原因正向战力提升 / 同新增天数、同首日付费分层全部明细原因正向战力提升。
-- 7. 净战力贡献占比 = 该变化原因净战力变化 / 同新增天数、同首日付费分层全部明细原因净战力变化。
-- 8. 分层汇总行的正向战力贡献占比、净战力贡献占比均固定为1。
-- 9. 保留 change_reason ID，并通过 ta_dim.dim_41_0_16734 映射原因名称。

SELECT
    row_number() OVER (
        ORDER BY
            q."新增天数",
            q."分层排序",
            q."汇总排序",
            q."正向战力提升" DESC,
            q."变化原因ID"
    ) AS "序号",

    q."新增天数",
    q."首日付费分层",

    CASE
        WHEN q."汇总排序" = 0 THEN 'ALL'
        ELSE q."变化原因ID"
    END AS "变化原因ID",

    CASE
        WHEN q."汇总排序" = 0 THEN '分层汇总'
        ELSE q."变化原因"
    END AS "变化原因",

    q."战力变化玩家数",
    q."战力变化次数",

    round(q."正向战力提升", 2) AS "正向战力提升",
    round(q."战力下降量", 2) AS "战力下降量",
    round(q."战力净变化", 2) AS "战力净变化",

    round(
        q."战力净变化"
        / nullif(q."战力变化玩家数", 0),
        2
    ) AS "变动玩家人均净战力变化",

    round(
        q."战力净变化"
        / nullif(q."战力变化次数", 0),
        2
    ) AS "单次平均净战力变化",

    CASE
        WHEN q."汇总排序" = 0 THEN 1.0000
        ELSE round(
            q."正向战力提升"
            / nullif(
                sum(
                    CASE
                        WHEN q."汇总排序" = 1 THEN q."正向战力提升"
                        ELSE 0
                    END
                ) OVER (
                    PARTITION BY
                        q."新增天数",
                        q."首日付费分层"
                ),
                0
            ),
            4
        )
    END AS "正向战力贡献占比",

    CASE
        WHEN q."汇总排序" = 0 THEN 1.0000
        ELSE round(
            q."战力净变化"
            / nullif(
                sum(
                    CASE
                        WHEN q."汇总排序" = 1 THEN q."战力净变化"
                        ELSE 0
                    END
                ) OVER (
                    PARTITION BY
                        q."新增天数",
                        q."首日付费分层"
                ),
                0
            ),
            4
        )
    END AS "净战力贡献占比",

    round(q."单次最大战力提升", 2) AS "单次最大战力提升",
    round(q."单次最大战力下降", 2) AS "单次最大战力下降"

FROM
(
    SELECT
        t."新增天数",
        t."首日付费分层",
        t."分层排序",
        t."变化原因ID",
        t."变化原因",

        CASE
            WHEN grouping(t."变化原因ID") = 1 THEN 0
            ELSE 1
        END AS "汇总排序",

        count(DISTINCT t."#account_id") AS "战力变化玩家数",
        count(*) AS "战力变化次数",

        sum(
            CASE
                WHEN t."战力变化值" > 0 THEN t."战力变化值"
                ELSE 0
            END
        ) AS "正向战力提升",

        sum(
            CASE
                WHEN t."战力变化值" < 0 THEN -t."战力变化值"
                ELSE 0
            END
        ) AS "战力下降量",

        sum(t."战力变化值") AS "战力净变化",
        max(t."战力变化值") AS "单次最大战力提升",
        min(t."战力变化值") AS "单次最大战力下降"

    FROM
    (
        SELECT
            date_diff(
                'day',
                c."新增日期",
                date(e."#event_time")
            ) + 1 AS "新增天数",

            c."首日付费分层",
            c."分层排序",

            cast(e."change_reason" AS varchar) AS "变化原因ID",

            coalesce(
                d."change_reason@reason_name",
                cast(e."change_reason" AS varchar)
            ) AS "变化原因",

            cast(e."#account_id" AS varchar) AS "#account_id",

            try_cast(e."after" AS double)
            - try_cast(e."before" AS double) AS "战力变化值"

        FROM ta.v_event_41 e

        INNER JOIN
        (
            SELECT
                s."#account_id",
                s."新增日期",
                s."首日付费金额",

                CASE
                    WHEN s."首日付费金额" = 0 THEN 'a_free'
                    WHEN s."首日付费金额" > 0 AND s."首日付费金额" <= 6 THEN 'b_(0,6]'
                    WHEN s."首日付费金额" > 6 AND s."首日付费金额" <= 30 THEN 'c_(6,30]'
                    WHEN s."首日付费金额" > 30 AND s."首日付费金额" <= 100 THEN 'd_(30,100]'
                    WHEN s."首日付费金额" > 100 AND s."首日付费金额" <= 300 THEN 'e_(100,300]'
                    WHEN s."首日付费金额" > 300 AND s."首日付费金额" <= 500 THEN 'f_(300,500]'
                    WHEN s."首日付费金额" > 500 AND s."首日付费金额" <= 1000 THEN 'g_(500,1000]'
                    ELSE 'h_(1000,+)'
                END AS "首日付费分层",

                CASE
                    WHEN s."首日付费金额" = 0 THEN 1
                    WHEN s."首日付费金额" > 0 AND s."首日付费金额" <= 6 THEN 2
                    WHEN s."首日付费金额" > 6 AND s."首日付费金额" <= 30 THEN 3
                    WHEN s."首日付费金额" > 30 AND s."首日付费金额" <= 100 THEN 4
                    WHEN s."首日付费金额" > 100 AND s."首日付费金额" <= 300 THEN 5
                    WHEN s."首日付费金额" > 300 AND s."首日付费金额" <= 500 THEN 6
                    WHEN s."首日付费金额" > 500 AND s."首日付费金额" <= 1000 THEN 7
                    ELSE 8
                END AS "分层排序"

            FROM
            (
                SELECT
                    u."#account_id",
                    u."新增日期",
                    coalesce(p."首日付费金额", 0) AS "首日付费金额"

                FROM
                (
                    SELECT
                        u1."#account_id",
                        u1."新增日期"

                    FROM
                    (
                        SELECT
                            cast(u0."#account_id" AS varchar) AS "#account_id",
                            date(u0."create_role_time") AS "新增日期",
                            cast(date(u0."create_role_time") AS varchar) AS "$part_date"

                        FROM ta.v_user_41 u0

                        WHERE u0."domain" = 'release'
                          AND u0."#account_id" IS NOT NULL
                          AND u0."create_role_time" IS NOT NULL
                          AND date(u0."create_role_time") < current_date
                    ) u1

                    WHERE ${PartDate:date1}
                ) u

                LEFT JOIN
                (
                    SELECT
                        cast(p0."#account_id" AS varchar) AS "#account_id",
                        date(p0."#event_time") AS "付费日期",

                        sum(
                            coalesce(
                                try_cast(p0."payment" AS double),
                                0
                            )
                        ) / 100.0000 AS "首日付费金额"

                    FROM ta.v_event_41 p0

                    WHERE p0."$part_event" = 'pay_log'
                      AND p0."domain" = 'release'
                      AND p0."#account_id" IS NOT NULL
                      AND coalesce(try_cast(p0."payment" AS double), 0) > 0
                      AND date(p0."#event_time") < current_date

                    GROUP BY 1, 2
                ) p
                    ON u."#account_id" = p."#account_id"
                   AND u."新增日期" = p."付费日期"
            ) s
        ) c
            ON cast(e."#account_id" AS varchar) = c."#account_id"

        LEFT JOIN ta_dim.dim_41_0_16734 d
            ON cast(e."change_reason" AS varchar)
             = d."change_reason@change_reson"

        WHERE e."$part_event" = 'change_power_log'
          AND e."domain" = 'release'
          AND e."#account_id" IS NOT NULL
          AND try_cast(e."before" AS double) IS NOT NULL
          AND try_cast(e."after" AS double) IS NOT NULL
          AND date(e."#event_time") >= c."新增日期"
          AND date(e."#event_time") < current_date
    ) t

    GROUP BY GROUPING SETS
    (
        (
            t."新增天数",
            t."首日付费分层",
            t."分层排序",
            t."变化原因ID",
            t."变化原因"
        ),
        (
            t."新增天数",
            t."首日付费分层",
            t."分层排序"
        )
    )
) q

ORDER BY
    q."新增天数",
    q."分层排序",
    q."汇总排序",
    q."正向战力提升" DESC,
    q."变化原因ID";
