SELECT
    row_number() OVER (
        ORDER BY q."排序"
    ) AS "序号",

    q."付费项ID",
    q."配置单价（元）",
    q."购买次数",
    q."付费人数",

    round(
        q."购买次数" * 1.0000
        / nullif(q."付费人数", 0),
        2
    ) AS "人均购买次数",

    round(
        q."付费金额",
        2
    ) AS "付费金额",

    CASE
        WHEN q."排序" = 0
            THEN 1.0000
        ELSE round(
            q."付费金额" * 1.0000
            / nullif(
                sum(
                    CASE
                        WHEN q."排序" > 0
                            THEN q."付费金额"
                        ELSE 0
                    END
                ) OVER (),
                0
            ),
            4
        )
    END AS "付费金额占比",

    round(
        q."付费金额" * 1.0000
        / nullif(q."付费人数", 0),
        2
    ) AS "人均付费金额"

FROM
(
    SELECT
        CASE
            WHEN grouping(d.product_id) = 1
                THEN '汇总'
            ELSE cast(d.product_id AS varchar)
        END AS "付费项ID",

        CASE
            WHEN grouping(d.product_id) = 1
                THEN NULL
            ELSE max(d.unit_price)
        END AS "配置单价（元）",

        CASE
            WHEN grouping(d.product_id) = 1
                THEN 0
            ELSE max(d.sort_no)
        END AS "排序",

        count(*) AS "购买次数",

        count(
            DISTINCT d."#account_id"
        ) AS "付费人数",

        sum(d.unit_price) AS "付费金额"

    FROM
    (
        SELECT
            cast(e."#account_id" AS varchar) AS "#account_id",
            product_cfg.product_id,
            product_cfg.payment_cent / 100.0000 AS unit_price,
            product_cfg.sort_no

        FROM ta.v_event_22 e

        INNER JOIN
        (
            SELECT DISTINCT
                user_base."#account_id",
                user_base.server_open_date

            FROM
            (
                SELECT
                    cast(u."#account_id" AS varchar) AS "#account_id",
                    date(u."server_open_time") AS server_open_date

                FROM ta.v_user_22 u

                WHERE u."domain" = 'release'
                  AND u."#account_id" IS NOT NULL
                  AND u."server_open_time" IS NOT NULL
            ) user_base

            CROSS JOIN
            (
                SELECT
                    min(
                        cast(d."$part_date" AS date)
                    ) AS stats_start_date,

                    max(
                        cast(d."$part_date" AS date)
                    ) AS stats_end_date

                FROM
                (
                    SELECT "$part_date"
                    FROM ta.v_event_22
                    WHERE ${PartDate:date2}
                ) d
            ) stats_period

            /* 只保留开服18-23天完整落在统计周期内的成熟区服 */
            WHERE date_add(
                    'day',
                    17,
                    user_base.server_open_date
                  ) >= stats_period.stats_start_date

              AND date_add(
                    'day',
                    22,
                    user_base.server_open_date
                  ) <= stats_period.stats_end_date
        ) mature_user
            ON cast(e."#account_id" AS varchar)
                = mature_user."#account_id"

        INNER JOIN
        (
            VALUES
                (20031, 600.0000, 1),
                (20032, 1200.0000, 2),
                (20033, 3000.0000, 3),
                (20034, 12800.0000, 4),
                (20035, 32800.0000, 5),
                (20036, 64800.0000, 6)
        ) AS product_cfg (
            product_id,
            payment_cent,
            sort_no
        )
            ON try_cast(
                e."product_id"
                AS bigint
            ) = product_cfg.product_id

        WHERE ${PartDate:date2}

          AND e."domain" = 'release'

          AND e."$part_event" = 'pay_log'

          /* 只统计成功付费 */
          AND try_cast(
                e."pay_result"
                AS bigint
              ) = 1

          /* 只看开服第18-23天 */
          AND cast(e."$part_date" AS date)
              BETWEEN date_add(
                    'day',
                    17,
                    mature_user.server_open_date
              )
              AND date_add(
                    'day',
                    22,
                    mature_user.server_open_date
              )
    ) d

    GROUP BY GROUPING SETS
    (
        (
            d.product_id,
            d.sort_no
        ),
        ()
    )
) q

ORDER BY q."排序"