-- 步步 v22：渠道100纯新/服务器维度后续N日付费，按 ad_platform 拆分
-- 时间范围：2026-07-01 ~ 2026-08-15
-- 口径：
-- 1. 用户表渠道：cast(channel_id as varchar)='100'。
-- 2. ad_platform 仅取用户表；空值/空字符串统一归为“自然量”。
-- 3. 纯新：同一 nb_open_id 下 create_role_time 最早的角色；滚服角色剔除。
-- 4. 服务器维度：按 server_open_time 日期 + region_id 分组，只取开服当天创建角色，不剔除滚服。
-- 5. create_role_time 为 Unix 秒，使用 from_unixtime(try_cast(... as double))。
-- 6. pay_log.payment 单位为分，/100 转元；仅统计 payment>0。
-- 7. D1=创角当天/开服当天；输出 day_no 为纯数字。
-- 8. 本版本仅输出后续N日付费，不输出付费留存。

/* ============================================================
   1. 2026-07-01~2026-08-15 渠道100纯新的后续N日付费
   按 ad_platform 拆分
   ============================================================ */
SELECT
    q."新增日期" "日期",
    q."ad_platform" "媒体平台",
    q.day_no "新增后第N日",
    count(DISTINCT q."#account_id") "新增角色数",
    round(sum(q.daily_pay), 2) "后续每日总付费"
FROM
(
    SELECT
        u."新增日期",
        u."ad_platform",
        u."#account_id",
        d.day_no,
        coalesce(p.daily_pay, 0) daily_pay
    FROM
    (
        SELECT
            x."新增日期",
            x."ad_platform",
            x."#account_id"
        FROM
        (
            SELECT
                cast(date(from_unixtime(try_cast(u."create_role_time" AS double))) AS varchar) "新增日期",
                coalesce(nullif(trim(cast(u."ad_platform" AS varchar)), ''), '自然量') "ad_platform",
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
        ) x
        WHERE x.rn = 1
          AND x."channel_id" = '100'
          AND cast(x."新增日期" AS date) BETWEEN date '2026-07-01' AND date '2026-08-15'
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
            sum(coalesce(try_cast(e."payment" AS double), 0)) / 100.0000 daily_pay
        FROM ta.v_event_22 e
        WHERE e."$part_event" = 'pay_log'
          AND e."domain" = 'release'
          AND e."#account_id" IS NOT NULL
          AND try_cast(e."payment" AS double) > 0
          AND cast(e."$part_date" AS date) BETWEEN date '2026-07-01' AND current_date
        GROUP BY 1, 2
    ) p
        ON u."#account_id" = p."#account_id"
       AND p."$part_date" = cast(
            date_add('day', d.day_no - 1, cast(u."新增日期" AS date))
            AS varchar
       )
) q
GROUP BY q."新增日期", q."ad_platform", q.day_no
ORDER BY q."新增日期", q."ad_platform", q.day_no;


/* ============================================================
   2. 2026-07-01~2026-08-15 服务器维度后续N日付费
   日期=开服日期；按 region_id + ad_platform 拆分；开服当天创建的渠道100角色；不剔除滚服
   ============================================================ */
SELECT
    q."开服日期" "日期",
    q."region_id" "服务器ID",
    q."ad_platform" "媒体平台",
    q.day_no "开服后第N日",
    count(DISTINCT q."#account_id") "新增角色数",
    round(sum(q.daily_pay), 2) "后续每日总付费"
FROM
(
    SELECT
        u."开服日期",
        u."region_id",
        u."ad_platform",
        u."#account_id",
        d.day_no,
        coalesce(p.daily_pay, 0) daily_pay
    FROM
    (
        SELECT DISTINCT
            cast(date(u."server_open_time") AS varchar) "开服日期",
            cast(u."region_id" AS varchar) "region_id",
            coalesce(nullif(trim(cast(u."ad_platform" AS varchar)), ''), '自然量') "ad_platform",
            cast(u."#account_id" AS varchar) "#account_id"
        FROM ta.v_user_22 u
        WHERE u."domain" = 'release'
          AND u."#account_id" IS NOT NULL
          AND u."server_open_time" IS NOT NULL
          AND u."region_id" IS NOT NULL
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
            sum(coalesce(try_cast(e."payment" AS double), 0)) / 100.0000 daily_pay
        FROM ta.v_event_22 e
        WHERE e."$part_event" = 'pay_log'
          AND e."domain" = 'release'
          AND e."#account_id" IS NOT NULL
          AND try_cast(e."payment" AS double) > 0
          AND cast(e."$part_date" AS date) BETWEEN date '2026-07-01' AND current_date
        GROUP BY 1, 2
    ) p
        ON u."#account_id" = p."#account_id"
       AND p."$part_date" = cast(
            date_add('day', d.day_no - 1, cast(u."开服日期" AS date))
            AS varchar
       )
) q
GROUP BY q."开服日期", q."region_id", q."ad_platform", q.day_no
ORDER BY q."开服日期", q."region_id", q."ad_platform", q.day_no;
