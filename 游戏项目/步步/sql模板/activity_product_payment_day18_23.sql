SELECT
    1 AS "序号",
    active_data."活动活跃人数",
    pay_data."活动付费人数",

    round(
        pay_data."活动付费人数" * 1.0000
        / nullif(active_data."活动活跃人数", 0),
        4
    ) AS "活动付费率",

    round(
        pay_data."活动付费金额",
        2
    ) AS "活动付费金额",

    round(
        pay_data."活动付费金额" * 1.0000
        / nullif(active_data."活动活跃人数", 0),
        2
    ) AS "活动ARPU",

    round(
        pay_data."活动付费金额" * 1.0000
        / nullif(pay_data."活动付费人数", 0),
        2
    ) AS "活动ARPPU"

FROM
(
    SELECT
        count(
            DISTINCT cast(a."#account_id" AS varchar)
        ) AS "活动活跃人数"

    FROM ta.v_event_22 a

    INNER JOIN
    (
        SELECT DISTINCT
            cast(u."#account_id" AS varchar) AS "#account_id",
            date(u."server_open_time") AS "开服日期"

        FROM ta.v_user_22 u

        WHERE u."domain" = 'release'
          AND u."#account_id" IS NOT NULL
          AND u."server_open_time" IS NOT NULL
    ) user_base
        ON cast(a."#account_id" AS varchar)
            = user_base."#account_id"

    CROSS JOIN
    (
        SELECT
            min(
                cast(d."$part_date" AS date)
            ) AS "统计开始日期",

            max(
                cast(d."$part_date" AS date)
            ) AS "统计结束日期"

        FROM
        (
            SELECT "$part_date"
            FROM ta.v_event_22
            WHERE ${PartDate:date2}
        ) d
    ) stats_period

    WHERE ${PartDate:date2}
      AND a."domain" = 'release'
      AND a."$part_event" = 'log_in_out'
      AND a."#account_id" IS NOT NULL

      /* 只保留开服第18~23天完整落在统计周期内的成熟区服 */
      AND date_add(
            'day',
            17,
            user_base."开服日期"
          ) >= stats_period."统计开始日期"

      AND date_add(
            'day',
            22,
            user_base."开服日期"
          ) <= stats_period."统计结束日期"

      /* 活跃按自然日统计开服第18~23天 */
      AND date(a."#event_time")
          BETWEEN date_add(
                'day',
                17,
                user_base."开服日期"
          )
          AND date_add(
                'day',
                22,
                user_base."开服日期"
          )
) active_data

CROSS JOIN
(
    SELECT
        count(
            DISTINCT cast(e."#account_id" AS varchar)
        ) AS "活动付费人数",

        sum(
            CASE try_cast(e."product_id" AS bigint)
                WHEN 20031 THEN 600 / 100.0000
                WHEN 20032 THEN 1200 / 100.0000
                WHEN 20033 THEN 3000 / 100.0000
                WHEN 20034 THEN 12800 / 100.0000
                WHEN 20035 THEN 32800 / 100.0000
                WHEN 20036 THEN 64800 / 100.0000
                ELSE 0
            END
        ) AS "活动付费金额"

    FROM ta.v_event_22 e

    INNER JOIN
    (
        SELECT DISTINCT
            cast(u."#account_id" AS varchar) AS "#account_id",
            date(u."server_open_time") AS "开服日期"

        FROM ta.v_user_22 u

        WHERE u."domain" = 'release'
          AND u."#account_id" IS NOT NULL
          AND u."server_open_time" IS NOT NULL
    ) user_base
        ON cast(e."#account_id" AS varchar)
            = user_base."#account_id"

    CROSS JOIN
    (
        SELECT
            min(
                cast(d."$part_date" AS date)
            ) AS "统计开始日期",

            max(
                cast(d."$part_date" AS date)
            ) AS "统计结束日期"

        FROM
        (
            SELECT "$part_date"
            FROM ta.v_event_22
            WHERE ${PartDate:date2}
        ) d
    ) stats_period

    WHERE ${PartDate:date2}
      AND e."domain" = 'release'
      AND e."$part_event" = 'pay_log'
      AND e."#account_id" IS NOT NULL

      AND try_cast(
            e."pay_result"
            AS bigint
          ) = 1

      AND try_cast(
            e."product_id"
            AS bigint
          ) IN
          (
              20031,
              20032,
              20033,
              20034,
              20035,
              20036
          )

      /* 只保留开服第18~23天完整落在统计周期内的成熟区服 */
      AND date_add(
            'day',
            17,
            user_base."开服日期"
          ) >= stats_period."统计开始日期"

      AND date_add(
            'day',
            22,
            user_base."开服日期"
          ) <= stats_period."统计结束日期"

      /* 付费同样按自然日统计开服第18~23天 */
      AND date(e."#event_time")
          BETWEEN date_add(
                'day',
                17,
                user_base."开服日期"
          )
          AND date_add(
                'day',
                22,
                user_base."开服日期"
          )
) pay_data