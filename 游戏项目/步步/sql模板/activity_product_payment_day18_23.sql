SELECT
    1 AS "序号",
    q."活动活跃人数",
    q."活动付费人数",

    round(
        q."活动付费人数" * 1.0000
        / nullif(q."活动活跃人数", 0),
        4
    ) AS "活动付费率",

    round(
        q."活动付费金额",
        2
    ) AS "活动付费金额",

    round(
        q."活动付费金额" * 1.0000
        / nullif(q."活动活跃人数", 0),
        2
    ) AS "活动ARPU",

    round(
        q."活动付费金额" * 1.0000
        / nullif(q."活动付费人数", 0),
        2
    ) AS "活动ARPPU"

FROM
(
    SELECT
        count(*) AS "活动活跃人数",

        sum(
            CASE
                WHEN p."活动付费金额" > 0 THEN 1
                ELSE 0
            END
        ) AS "活动付费人数",

        sum(
            coalesce(p."活动付费金额", 0)
        ) AS "活动付费金额"

    FROM
    (
        SELECT DISTINCT
            cast(a."#account_id" AS varchar) AS "#account_id",

            cast(
                date_add(
                    'day',
                    17,
                    date(u."server_open_time")
                ) AS timestamp
            ) AS "活动开始时间",

            cast(
                date_add(
                    'day',
                    23,
                    date(u."server_open_time")
                ) AS timestamp
            ) AS "活动结束时间"

        FROM
        (
            SELECT
                "#account_id",
                "#event_time"

            FROM ta.v_event_22

            WHERE ${PartDate:date2}
              AND "domain" = 'release'
              AND "$part_event" = 'in_out_log'
              AND "#account_id" IS NOT NULL
        ) a

        INNER JOIN ta.v_user_22 u
            ON cast(a."#account_id" AS varchar)
                = cast(u."#account_id" AS varchar)

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

        WHERE u."domain" = 'release'
          AND u."server_open_time" IS NOT NULL

          /* 只保留开服第18~23天完整落在统计周期内的成熟区服 */
          AND date_add(
                'day',
                17,
                date(u."server_open_time")
              ) >= stats_period."统计开始日期"

          AND date_add(
                'day',
                22,
                date(u."server_open_time")
              ) <= stats_period."统计结束日期"

          /* 玩家必须在开服第18~23天内至少活跃过一次 */
          AND date(a."#event_time")
              BETWEEN date_add(
                    'day',
                    17,
                    date(u."server_open_time")
              )
              AND date_add(
                    'day',
                    22,
                    date(u."server_open_time")
              )
    ) active_user

    LEFT JOIN
    (
        SELECT
            pay_user."#account_id",
            sum(pay_user."配置金额") AS "活动付费金额"

        FROM
        (
            SELECT
                cast(e."#account_id" AS varchar) AS "#account_id",
                e."#event_time",

                CASE try_cast(e."product_id" AS bigint)
                    WHEN 20031 THEN 600 / 100.0000
                    WHEN 20032 THEN 1200 / 100.0000
                    WHEN 20033 THEN 3000 / 100.0000
                    WHEN 20034 THEN 12800 / 100.0000
                    WHEN 20035 THEN 32800 / 100.0000
                    WHEN 20036 THEN 64800 / 100.0000
                    ELSE 0
                END AS "配置金额"

            FROM ta.v_event_22 e

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
        ) pay_user

        GROUP BY
            1
    ) p
        ON p."#account_id" = active_user."#account_id"
) q