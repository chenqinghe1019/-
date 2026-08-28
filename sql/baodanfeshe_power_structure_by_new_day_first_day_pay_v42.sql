-- 暴弹飞射 v42｜新增天数 × 首日付费分层 × 战力变化原因结构
-- 口径：
-- 1. ${PartDate:date1} 筛选新增日期，不筛 change_power_log 事件日期。
-- 2. 新增天数：创角当天=D1，即 date_diff('day', 新增日期, 事件日期)+1。
-- 3. create_role_time 兼容 timestamp / 历史 Unix 秒两种存储。
-- 4. 首日付费：仅统计新增当天 pay_log.payment>0；暴弹 payment 单位为元，不除以100。
-- 5. 首日付费分层：0、(0,6]、(6,30]、(30,100]、(100,300]、(300,500]、(500,1000]、1000+。
-- 6. 战力变化值 = after-before，不取 ABS；正向战力提升与战力下降量分开统计。
-- 7. 正向战力贡献占比 = 该变化原因正向战力提升 / 同新增天数、同首日付费分层全部变化原因正向战力提升。
-- 8. 仅统计 current_date 之前完整日期，避免当天数据未完整。

SELECT
    row_number() OVER (
        ORDER BY
            q."新增天数",
            q."分层排序",
            q."正向战力提升" DESC,
            q."变化原因"
    ) AS "序号",

    q."新增天数",
    q."首日付费分层",
    q."变化原因",
    q."战力变化玩家数",
    q."战力变化次数",

    round(q."正向战力提升", 2) AS "正向战力提升",
    round(q."战力下降量", 2) AS "战力下降量",
    round(q."净战力变化", 2) AS "净战力变化",

    round(
        q."净战力变化"
        / nullif(q."战力变化玩家数", 0),
        2
    ) AS "变动玩家人均净战力变化",

    round(
        q."净战力变化"
        / nullif(q."战力变化次数", 0),
        2
    ) AS "单次平均净战力变化",

    round(
        q."正向战力提升"
        / nullif(
            sum(q."正向战力提升") OVER (
                PARTITION BY
                    q."新增天数",
                    q."首日付费分层"
            ),
            0
        ),
        4
    ) AS "正向战力贡献占比",

    round(q."单次最大战力提升", 2) AS "单次最大战力提升",
    round(q."单次最大战力下降", 2) AS "单次最大战力下降"

FROM
(
    SELECT
        t."新增天数",
        t."首日付费分层",
        t."分层排序",
        t."变化原因",

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

        sum(t."战力变化值") AS "净战力变化",
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

            coalesce(
                nullif(
                    trim(
                        split_part(
                            cast(e."change_reason" AS varchar),
                            ':',
                            1
                        )
                    ),
                    ''
                ),
                '未知'
            ) AS "变化原因",

            cast(e."#account_id" AS varchar) AS "#account_id",

            try_cast(e."after" AS double)
            - try_cast(e."before" AS double) AS "战力变化值"

        FROM ta.v_event_42 e

        INNER JOIN
        (
            SELECT
                s."#account_id",
                s."新增日期",
                s."首日付费金额",

                CASE
                    WHEN s."首日付费金额" = 0
                        THEN 'a_free'
                    WHEN s."首日付费金额" <= 6
                        THEN 'b_(0,6]'
                    WHEN s."首日付费金额" <= 30
                        THEN 'c_(6,30]'
                    WHEN s."首日付费金额" <= 100
                        THEN 'd_(30,100]'
                    WHEN s."首日付费金额" <= 300
                        THEN 'e_(100,300]'
                    WHEN s."首日付费金额" <= 500
                        THEN 'f_(300,500]'
                    WHEN s."首日付费金额" <= 1000
                        THEN 'g_(500,1000]'
                    ELSE 'h_(1000,+)'
                END AS "首日付费分层",

                CASE
                    WHEN s."首日付费金额" = 0 THEN 1
                    WHEN s."首日付费金额" <= 6 THEN 2
                    WHEN s."首日付费金额" <= 30 THEN 3
                    WHEN s."首日付费金额" <= 100 THEN 4
                    WHEN s."首日付费金额" <= 300 THEN 5
                    WHEN s."首日付费金额" <= 500 THEN 6
                    WHEN s."首日付费金额" <= 1000 THEN 7
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
                            u0."#account_id",
                            u0."新增日期",
                            cast(u0."新增日期" AS varchar) AS "$part_date"

                        FROM
                        (
                            SELECT
                                cast(u."#account_id" AS varchar) AS "#account_id",

                                coalesce(
                                    date(
                                        try_cast(
                                            cast(u."create_role_time" AS varchar)
                                            AS timestamp
                                        )
                                    ),
                                    date(
                                        from_unixtime(
                                            try_cast(
                                                cast(u."create_role_time" AS varchar)
                                                AS double
                                            )
                                        )
                                    )
                                ) AS "新增日期"

                            FROM ta.v_user_42 u

                            WHERE u."domain" = 'release'
                              AND u."#account_id" IS NOT NULL
                              AND u."create_role_time" IS NOT NULL
                        ) u0

                        WHERE u0."新增日期" IS NOT NULL
                          AND u0."新增日期" < current_date
                    ) u1

                    WHERE ${PartDate:date1}
                ) u

                LEFT JOIN
                (
                    SELECT
                        cast(e."#account_id" AS varchar) AS "#account_id",
                        date(e."#event_time") AS "付费日期",

                        sum(
                            coalesce(
                                try_cast(e."payment" AS double),
                                0
                            )
                        ) AS "首日付费金额"

                    FROM ta.v_event_42 e

                    WHERE e."$part_event" = 'pay_log'
                      AND e."domain" = 'release'
                      AND e."#account_id" IS NOT NULL
                      AND coalesce(
                            try_cast(e."payment" AS double),
                            0
                          ) > 0
                      AND date(e."#event_time") < current_date

                    GROUP BY 1, 2
                ) p
                    ON u."#account_id" = p."#account_id"
                   AND u."新增日期" = p."付费日期"
            ) s
        ) c
            ON cast(e."#account_id" AS varchar) = c."#account_id"

        WHERE e."$part_event" = 'change_power_log'
          AND e."domain" = 'release'
          AND e."#account_id" IS NOT NULL
          AND try_cast(e."before" AS double) IS NOT NULL
          AND try_cast(e."after" AS double) IS NOT NULL
          AND date(e."#event_time") >= c."新增日期"
          AND date(e."#event_time") < current_date
    ) t

    GROUP BY
        t."新增天数",
        t."首日付费分层",
        t."分层排序",
        t."变化原因"
) q

ORDER BY
    q."新增天数",
    q."分层排序",
    q."正向战力提升" DESC,
    q."变化原因";
