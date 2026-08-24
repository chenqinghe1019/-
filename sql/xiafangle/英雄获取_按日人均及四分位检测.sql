-- 下方了｜英雄获取分布检测
-- 事件：role_obtain_log
-- 日期：2026-08-24
--
-- 口径：
-- 1. 按自然日 + 英雄统计。
-- 2. 当日发生 in_out_log 的角色作为当天总体。
-- 3. role_obtain_log.role_id 当前实际上报为英雄名。
-- 4. 玩家当天同一英雄的获取数量 = role_obtain_log 事件条数。
-- 5. 当日未获取该英雄的活跃玩家补 0 后参与人均、最小值和四分位计算。
-- 6. 获取率 = 获取玩家数 * 1.0000 / 活跃玩家数，不乘100。
-- 7. 英雄集合取查询周期内 role_obtain_log 中出现过的全部 role_id，因此某英雄只要周期内出现过，即会在周期内每天参与统计。

SELECT
    row_number() OVER (
        ORDER BY q."日期", q."英雄"
    ) AS "序号",
    q."日期",
    q."英雄",
    q."活跃玩家数",
    q."获取玩家数",
    q."获取率",
    q."获取总次数",
    q."人均获取次数",
    q."最小获取次数",
    q."P25获取次数",
    q."P50获取次数",
    q."P75获取次数",
    q."最大获取次数"
FROM
(
    SELECT
        t."日期",
        t."英雄",
        count(*) AS "活跃玩家数",
        sum(
            CASE
                WHEN t."获取次数" > 0 THEN 1
                ELSE 0
            END
        ) AS "获取玩家数",
        round(
            sum(
                CASE
                    WHEN t."获取次数" > 0 THEN 1
                    ELSE 0
                END
            ) * 1.0000
            / nullif(count(*), 0),
            4
        ) AS "获取率",
        sum(t."获取次数") AS "获取总次数",
        round(
            avg(cast(t."获取次数" AS double)),
            2
        ) AS "人均获取次数",
        min(t."获取次数") AS "最小获取次数",
        round(
            approx_percentile(
                cast(t."获取次数" AS double),
                0.25
            ),
            2
        ) AS "P25获取次数",
        round(
            approx_percentile(
                cast(t."获取次数" AS double),
                0.50
            ),
            2
        ) AS "P50获取次数",
        round(
            approx_percentile(
                cast(t."获取次数" AS double),
                0.75
            ),
            2
        ) AS "P75获取次数",
        max(t."获取次数") AS "最大获取次数"
    FROM
    (
        SELECT
            a."日期",
            a."#account_id",
            h."英雄",
            coalesce(g."获取次数", 0) AS "获取次数"
        FROM
        (
            SELECT DISTINCT
                cast(e."$part_date" AS varchar) AS "日期",
                cast(e."#account_id" AS varchar) AS "#account_id"
            FROM ta.v_event_41 e
            WHERE ${PartDate:date}
              AND e."domain" = 'release'
              AND e."$part_event" = 'in_out_log'
              AND e."#account_id" IS NOT NULL
        ) a
        CROSS JOIN
        (
            SELECT DISTINCT
                trim(cast(e."role_id" AS varchar)) AS "英雄"
            FROM ta.v_event_41 e
            WHERE ${PartDate:date}
              AND e."domain" = 'release'
              AND e."$part_event" = 'role_obtain_log'
              AND e."role_id" IS NOT NULL
              AND trim(cast(e."role_id" AS varchar)) <> ''
        ) h
        LEFT JOIN
        (
            SELECT
                cast(e."$part_date" AS varchar) AS "日期",
                cast(e."#account_id" AS varchar) AS "#account_id",
                trim(cast(e."role_id" AS varchar)) AS "英雄",
                count(*) AS "获取次数"
            FROM ta.v_event_41 e
            WHERE ${PartDate:date}
              AND e."domain" = 'release'
              AND e."$part_event" = 'role_obtain_log'
              AND e."#account_id" IS NOT NULL
              AND e."role_id" IS NOT NULL
              AND trim(cast(e."role_id" AS varchar)) <> ''
            GROUP BY
                cast(e."$part_date" AS varchar),
                cast(e."#account_id" AS varchar),
                trim(cast(e."role_id" AS varchar))
        ) g
            ON a."日期" = g."日期"
           AND a."#account_id" = g."#account_id"
           AND h."英雄" = g."英雄"
    ) t
    GROUP BY
        t."日期",
        t."英雄"
) q
ORDER BY
    q."日期",
    q."英雄";
