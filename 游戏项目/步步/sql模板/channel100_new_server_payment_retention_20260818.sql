-- 步步 v22：渠道100（支付宝）纯新增、纯新后续付费留存、服务器维度后续付费留存
-- 时间范围：2026-07-01 ~ 2026-08-15
-- 口径：
-- 1. 用户表渠道：cast(channel_id as varchar)='100'。
-- 2. 纯新：同一 nb_open_id 下 create_role_time 最早的角色；滚服角色剔除。
-- 3. create_role_time 为 Unix 秒，使用 from_unixtime(try_cast(... as double))。
-- 4. pay_log.payment 单位为分，/100 转元；仅统计 payment>0。
-- 5. D1=创角当天/开服当天；付费留存=D1付费用户中第N日再次付费人数 / D1付费用户数，不乘100。
-- 6. 服务器维度：按 server_open_time 日期分组，只取开服当天创建角色，不剔除滚服。
-- 7. GitHub 当前未记录步步 1-1 的明确 map_id；SQL1 暂以“出现成功 battle_result_sever”作为已通关1-1的代理口径。

/* ============================================================
   1. 2026-07-01~2026-08-15 渠道100纯新增情况
   ============================================================ */
SELECT
    u."新增日期" "日期",
    count(DISTINCT u."#account_id") "新增角色",
    count(DISTINCT CASE WHEN b."#account_id" IS NOT NULL THEN u."#account_id" END) "通关1-1角色数",
    count(DISTINCT CASE WHEN coalesce(p.first_day_pay,0) > 0 THEN u."#account_id" END) "首日付费用户数"
FROM
(
    SELECT
        a."新增日期",
        a."#account_id"
    FROM
    (
        SELECT
            cast(date(from_unixtime(try_cast(u."create_role_time" AS double))) AS varchar) "新增日期",
            cast(u."#account_id" AS varchar) "#account_id",
            cast(u."nb_open_id" AS varchar) "nb_open_id",
            cast(u."channel_id" AS varchar) "channel_id",
            row_number() OVER (
                PARTITION BY cast(u."nb_open_id" AS varchar)
                ORDER BY try_cast(u."create_role_time" AS double), cast(u."#account_id" AS varchar)
            ) rn
        FROM ta.v_user_22 u
        WHERE u."domain" = 'release'
          AND u."#account_id" IS NOT NULL
          AND u."nb_open_id" IS NOT NULL
          AND try_cast(u."create_role_time" AS double) IS NOT NULL
    ) a
    WHERE a.rn = 1
      AND a."channel_id" = '100'
      AND cast(a."新增日期" AS date) BETWEEN date '2026-07-01' AND date '2026-08-15'
) u
LEFT JOIN
(
    SELECT
        cast(e."#account_id" AS varchar) "#account_id"
    FROM ta.v_event_22 e
    WHERE e."$part_event" = 'battle_result_sever'
      AND e."domain" = 'release'
      AND e."#account_id" IS NOT NULL
      AND cast(e."$part_date" AS date) BETWEEN date '2026-07-01' AND current_date
      AND (
            try_cast(e."battle_result" AS bigint) = 1
            OR lower(trim(cast(e."battle_result" AS varchar))) IN ('true','win','success')
          )
    GROUP BY 1
) b
    ON u."#account_id" = b."#account_id"
LEFT JOIN
(
    SELECT
        cast(e."#account_id" AS varchar) "#account_id",
        e."$part_date",
        sum(coalesce(try_cast(e."payment" AS double),0)) / 100.0000 first_day_pay
    FROM ta.v_event_22 e
    WHERE e."$part_event" = 'pay_log'
      AND e."domain" = 'release'
      AND e."#account_id" IS NOT NULL
      AND try_cast(e."payment" AS double) > 0
      AND cast(e."$part_date" AS date) BETWEEN date '2026-07-01' AND date '2026-08-15'
    GROUP BY 1,2
) p
    ON u."#account_id" = p."#account_id"
   AND u."新增日期" = p."$part_date"
GROUP BY 1
ORDER BY 1;


/* ============================================================
   2. 2026-07-01~2026-08-15 渠道100纯新的后续N日付费和付费留存
   D1=创角当天；N自动延伸到今天
   ============================================================ */
SELECT
    q."新增日期" "日期",
    'D' || cast(q.day_no AS varchar) "新增后第N日",
    count(DISTINCT q."#account_id") "新增角色数",
    round(sum(q.daily_pay),2) "后续每日总付费",
    round(
        count(DISTINCT CASE
            WHEN q.first_day_pay > 0 AND q.daily_pay > 0 THEN q."#account_id"
        END) * 1.0000
        / nullif(
            count(DISTINCT CASE
                WHEN q.first_day_pay > 0 THEN q."#account_id"
            END),
            0
        ),
        4
    ) "每日付费留存"
FROM
(
    SELECT
        x."新增日期",
        x."#account_id",
        x.day_no,
        x.daily_pay,
        max(CASE WHEN x.day_no = 1 THEN x.daily_pay ELSE 0 END) OVER (
            PARTITION BY x."#account_id"
        ) first_day_pay
    FROM
    (
        SELECT
            u."新增日期",
            u."#account_id",
            d.day_no,
            coalesce(p.daily_pay,0) daily_pay
        FROM
        (
            SELECT
                a."新增日期",
                a."#account_id"
            FROM
            (
                SELECT
                    cast(date(from_unixtime(try_cast(u."create_role_time" AS double))) AS varchar) "新增日期",
                    cast(u."#account_id" AS varchar) "#account_id",
                    cast(u."nb_open_id" AS varchar) "nb_open_id",
                    cast(u."channel_id" AS varchar) "channel_id",
                    row_number() OVER (
                        PARTITION BY cast(u."nb_open_id" AS varchar)
                        ORDER BY try_cast(u."create_role_time" AS double), cast(u."#account_id" AS varchar)
                    ) rn
                FROM ta.v_user_22 u
                WHERE u."domain" = 'release'
                  AND u."#account_id" IS NOT NULL
                  AND u."nb_open_id" IS NOT NULL
                  AND try_cast(u."create_role_time" AS double) IS NOT NULL
            ) a
            WHERE a.rn = 1
              AND a."channel_id" = '100'
              AND cast(a."新增日期" AS date) BETWEEN date '2026-07-01' AND date '2026-08-15'
        ) u
        CROSS JOIN UNNEST(
            sequence(
                1,
                cast(date_diff('day', cast(u."新增日期" AS date), current_date) + 1 AS integer)
            )
        ) AS d(day_no)
        LEFT JOIN
        (
            SELECT
                cast(e."#account_id" AS varchar) "#account_id",
                e."$part_date",
                sum(coalesce(try_cast(e."payment" AS double),0)) / 100.0000 daily_pay
            FROM ta.v_event_22 e
            WHERE e."$part_event" = 'pay_log'
              AND e."domain" = 'release'
              AND e."#account_id" IS NOT NULL
              AND try_cast(e."payment" AS double) > 0
              AND cast(e."$part_date" AS date) BETWEEN date '2026-07-01' AND current_date
            GROUP BY 1,2
        ) p
            ON u."#account_id" = p."#account_id"
           AND p."$part_date" = cast(
                date_add(
                    'day',
                    d.day_no - 1,
                    cast(u."新增日期" AS date)
                ) AS varchar
           )
    ) x
) q
GROUP BY 1,2,q.day_no
ORDER BY q."新增日期", q.day_no;


/* ============================================================
   3. 2026-07-01~2026-08-15 服务器维度后续N日付费和付费留存
   日期=开服日期；统计开服当天创建的渠道100角色；不剔除滚服
   D1=开服当天；N自动延伸到今天
   ============================================================ */
SELECT
    q."开服日期" "日期",
    'D' || cast(q.day_no AS varchar) "开服后第N日",
    count(DISTINCT q."#account_id") "新增角色数",
    round(sum(q.daily_pay),2) "后续每日总付费",
    round(
        count(DISTINCT CASE
            WHEN q.first_day_pay > 0 AND q.daily_pay > 0 THEN q."#account_id"
        END) * 1.0000
        / nullif(
            count(DISTINCT CASE
                WHEN q.first_day_pay > 0 THEN q."#account_id"
            END),
            0
        ),
        4
    ) "每日付费留存"
FROM
(
    SELECT
        x."开服日期",
        x."#account_id",
        x.day_no,
        x.daily_pay,
        max(CASE WHEN x.day_no = 1 THEN x.daily_pay ELSE 0 END) OVER (
            PARTITION BY x."#account_id"
        ) first_day_pay
    FROM
    (
        SELECT
            u."开服日期",
            u."#account_id",
            d.day_no,
            coalesce(p.daily_pay,0) daily_pay
        FROM
        (
            SELECT DISTINCT
                cast(date(u."server_open_time") AS varchar) "开服日期",
                cast(u."#account_id" AS varchar) "#account_id"
            FROM ta.v_user_22 u
            WHERE u."domain" = 'release'
              AND u."#account_id" IS NOT NULL
              AND u."server_open_time" IS NOT NULL
              AND try_cast(u."create_role_time" AS double) IS NOT NULL
              AND cast(u."channel_id" AS varchar) = '100'
              AND date(u."server_open_time") BETWEEN date '2026-07-01' AND date '2026-08-15'
              AND date(from_unixtime(try_cast(u."create_role_time" AS double))) = date(u."server_open_time")
        ) u
        CROSS JOIN UNNEST(
            sequence(
                1,
                cast(date_diff('day', cast(u."开服日期" AS date), current_date) + 1 AS integer)
            )
        ) AS d(day_no)
        LEFT JOIN
        (
            SELECT
                cast(e."#account_id" AS varchar) "#account_id",
                e."$part_date",
                sum(coalesce(try_cast(e."payment" AS double),0)) / 100.0000 daily_pay
            FROM ta.v_event_22 e
            WHERE e."$part_event" = 'pay_log'
              AND e."domain" = 'release'
              AND e."#account_id" IS NOT NULL
              AND try_cast(e."payment" AS double) > 0
              AND cast(e."$part_date" AS date) BETWEEN date '2026-07-01' AND current_date
            GROUP BY 1,2
        ) p
            ON u."#account_id" = p."#account_id"
           AND p."$part_date" = cast(
                date_add(
                    'day',
                    d.day_no - 1,
                    cast(u."开服日期" AS date)
                ) AS varchar
           )
    ) x
) q
GROUP BY 1,2,q.day_no
ORDER BY q."开服日期", q.day_no;
