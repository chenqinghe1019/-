-- 下方了：按首日付费分层统计远古精魄累计获取/消耗
-- 开服天数使用数数 SQL「可变内容」动态参数 ${OpenDay} 控制，默认建议 7。
-- 新增日期继续由 ${PartDate:date} 控制。

SELECT
    row_number() over(
        order by q."开服第N日", q."首日付费分层"
    ) "序号",
    q."开服第N日",
    q."首日付费分层",
    q."已创角人数",
    q."当日活跃人数",
    q."累计获取总量",
    q."累计人均获取",
    q."累计获取P75",
    q."累计获取P90",
    q."累计消耗总量",
    q."累计人均消耗",
    q."累计消耗P75",
    q."累计消耗P90"
FROM
(
    SELECT
        t."开服第N日",
        t."首日付费分层",
        count(*) "已创角人数",
        sum(t."当日是否活跃") "当日活跃人数",
        sum(t."累计获取") "累计获取总量",
        round(
            sum(
                CASE
                    WHEN t."当日是否活跃" = 1 THEN t."累计获取"
                    ELSE 0
                END
            ) * 1.00
            / nullif(sum(t."当日是否活跃"), 0),
            2
        ) "累计人均获取",
        round(
            approx_percentile(
                CASE
                    WHEN t."当日是否活跃" = 1 THEN cast(t."累计获取" AS double)
                END,
                0.75
            ),
            2
        ) "累计获取P75",
        round(
            approx_percentile(
                CASE
                    WHEN t."当日是否活跃" = 1 THEN cast(t."累计获取" AS double)
                END,
                0.90
            ),
            2
        ) "累计获取P90",
        sum(t."累计消耗") "累计消耗总量",
        round(
            sum(
                CASE
                    WHEN t."当日是否活跃" = 1 THEN t."累计消耗"
                    ELSE 0
                END
            ) * 1.00
            / nullif(sum(t."当日是否活跃"), 0),
            2
        ) "累计人均消耗",
        round(
            approx_percentile(
                CASE
                    WHEN t."当日是否活跃" = 1 THEN cast(t."累计消耗" AS double)
                END,
                0.75
            ),
            2
        ) "累计消耗P75",
        round(
            approx_percentile(
                CASE
                    WHEN t."当日是否活跃" = 1 THEN cast(t."累计消耗" AS double)
                END,
                0.90
            ),
            2
        ) "累计消耗P90"
    FROM
    (
        SELECT
            b."#account_id",
            b."首日付费分层",
            d."开服第N日",
            max(
                CASE
                    WHEN a."#account_id" IS NOT NULL THEN 1
                    ELSE 0
                END
            ) "当日是否活跃",
            coalesce(sum(r."获取数量"), 0) "累计获取",
            coalesce(sum(r."消耗数量"), 0) "累计消耗"
        FROM
        (
            SELECT
                u."#account_id",
                u."server_open_time",
                u."创角开服日",
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
                    "#account_id",
                    "server_open_time",
                    "$part_date",
                    "创角开服日"
                FROM
                (
                    SELECT
                        "#account_id",
                        "server_open_time",
                        cast(date("create_role_time") AS varchar) "$part_date",
                        cast(
                            date_diff(
                                'day',
                                date("server_open_time"),
                                date("create_role_time")
                            ) + 1
                            AS integer
                        ) "创角开服日"
                    FROM ta.v_user_41
                    WHERE "domain" = 'release'
                      AND "server_open_time" IS NOT NULL
                      AND "create_role_time" IS NOT NULL
                ) u0
                WHERE ${PartDate:date}
                  AND "创角开服日" BETWEEN 1 AND cast(${OpenDay} AS integer)
            ) u
            LEFT JOIN
            (
                SELECT
                    "#account_id",
                    "$part_date",
                    sum(coalesce("payment", 0)) * 1.00 / 100 "首日付费金额"
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
        CROSS JOIN UNNEST(
            sequence(
                cast(b."创角开服日" AS integer),
                cast(${OpenDay} AS integer)
            )
        ) d("开服第N日")
        LEFT JOIN
        (
            SELECT
                "#account_id",
                date("#event_time") "活跃日期"
            FROM ta.v_event_41
            WHERE "#event_name" = 'in_out_log'
              AND "domain" = 'release'
            GROUP BY
                "#account_id",
                date("#event_time")
        ) a
            ON b."#account_id" = a."#account_id"
           AND cast(
                date_diff(
                    'day',
                    date(b."server_open_time"),
                    a."活跃日期"
                ) + 1
                AS integer
            ) = d."开服第N日"
        LEFT JOIN
        (
            SELECT
                "#account_id",
                date("#event_time") "资源日期",
                sum(
                    CASE
                        WHEN try_cast("change_type" AS bigint) = 1
                        THEN abs(coalesce("item_num", 0))
                        ELSE 0
                    END
                ) "获取数量",
                sum(
                    CASE
                        WHEN try_cast("change_type" AS bigint) = 2
                        THEN abs(coalesce("item_num", 0))
                        ELSE 0
                    END
                ) "消耗数量"
            FROM ta.v_event_41
            WHERE "#event_name" = 'item_log'
              AND "domain" = 'release'
              AND cast("item_name" AS varchar) = '远古精魄'
            GROUP BY
                "#account_id",
                date("#event_time")
        ) r
            ON b."#account_id" = r."#account_id"
           AND date_diff(
                'day',
                date(b."server_open_time"),
                r."资源日期"
            ) BETWEEN 0 AND d."开服第N日" - 1
        GROUP BY
            b."#account_id",
            b."首日付费分层",
            d."开服第N日"
    ) t
    GROUP BY
        t."开服第N日",
        t."首日付费分层"
) q
ORDER BY
    q."开服第N日",
    q."首日付费分层"
