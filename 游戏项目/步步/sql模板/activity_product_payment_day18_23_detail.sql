SELECT
    row_number() OVER (
        ORDER BY
            d."#event_time",
            d."#account_id"
    ) AS "序号",

    d."$part_date" AS "事件日期",
    d."#event_time" AS "付费时间",
    d."#account_id" AS "角色ID",
    d."region_id" AS "区服ID",
    d."开服日期",

    date_diff(
        'day',
        d."开服日期",
        date(d."#event_time")
    ) + 1 AS "开服天数",

    d."product_id" AS "付费项ID",
    d."product_name" AS "付费项名称",
    d."product_type" AS "付费项类型",
    d."pay_result" AS "pay_result",
    d."change_reason" AS "change_reason",
    d."system" AS "system",
    d."payment_method" AS "payment_method",
    d."payment" AS "埋点payment原值",

    round(
        coalesce(
            try_cast(d."payment" AS double),
            0
        ) / 100.0000,
        2
    ) AS "埋点payment（元）",

    d."配置金额（元）"

FROM
(
    SELECT
        e."$part_date",
        e."#event_time",
        cast(e."#account_id" AS varchar) AS "#account_id",
        e."region_id",
        user_base."开服日期",
        try_cast(e."product_id" AS bigint) AS "product_id",
        e."product_name",
        e."product_type",
        e."pay_result",
        e."change_reason",
        e."system",
        e."payment_method",
        e."payment",

        CASE try_cast(e."product_id" AS bigint)
            WHEN 20031 THEN 600 / 100.0000
            WHEN 20032 THEN 1200 / 100.0000
            WHEN 20033 THEN 3000 / 100.0000
            WHEN 20034 THEN 12800 / 100.0000
            WHEN 20035 THEN 32800 / 100.0000
            WHEN 20036 THEN 64800 / 100.0000
            ELSE 0
        END AS "配置金额（元）"

    FROM ta.v_event_22 e

    INNER JOIN
    (
        SELECT
            cast(u."#account_id" AS varchar) AS "#account_id",
            max(date(u."server_open_time")) AS "开服日期"

        FROM ta.v_user_22 u

        WHERE u."domain" = 'release'
          AND u."#account_id" IS NOT NULL
          AND u."server_open_time" IS NOT NULL

        GROUP BY 1
    ) user_base
        ON cast(e."#account_id" AS varchar)
            = user_base."#account_id"

    CROSS JOIN
    (
        SELECT
            min(cast(t."$part_date" AS date)) AS "统计开始日期",
            max(cast(t."$part_date" AS date)) AS "统计结束日期"

        FROM
        (
            SELECT "$part_date"
            FROM ta.v_event_22
            WHERE ${PartDate:date2}
        ) t
    ) stats_period

    WHERE ${PartDate:date2}
      AND e."domain" = 'release'
      AND e."$part_event" = 'pay_log'
      AND e."#account_id" IS NOT NULL

      AND try_cast(e."product_id" AS bigint) IN
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

      /* 按自然日限制开服第18~23天 */
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
) d

ORDER BY
    d."#event_time",
    d."#account_id"