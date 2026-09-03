SELECT
    row_number() OVER (
        ORDER BY
            q."新增天数",
            q."分层排序",
            q."阵营排序",
            q."hero_id",
            q."目标星级"
    ) AS "序号",

    q."新增天数",
    q."首日付费分层",
    q."hero_id" AS "英雄ID",
    q."英雄名称" AS "具体卡",
    q."阵营",
    q."当前星级",
    q."目标星级",
    q."需要本体数",
    q."需要紫色狗粮数",
    q."本体足够玩家数",
    q."本体足够英雄数",
    q."本体足够但狗粮不足玩家数",
    q."本体足够但狗粮不足英雄数",

    round(
        q."本体足够但狗粮不足玩家数" * 1.0000
        / nullif(q."本体足够玩家数", 0),
        4
    ) AS "狗粮不足玩家占比",

    round(
        q."本体足够但狗粮不足英雄数" * 1.0000
        / nullif(q."本体足够英雄数", 0),
        4
    ) AS "狗粮不足英雄占比"

FROM
(
    SELECT
        t."新增天数",
        t."首日付费分层",
        t."分层排序",
        t."hero_id",
        t."英雄名称",
        t."阵营",
        t."阵营排序",
        t."当前星级",
        t."目标星级",
        t."需要本体数",
        t."需要紫色狗粮数",

        count(
            DISTINCT CASE
                WHEN t."可用本体数" >= t."需要本体数"
                    THEN t."#account_id"
            END
        ) AS "本体足够玩家数",

        count(
            DISTINCT CASE
                WHEN t."可用本体数" >= t."需要本体数"
                    THEN concat(
                        t."#account_id",
                        '_',
                        cast(t."hero_id" AS varchar)
                    )
            END
        ) AS "本体足够英雄数",

        count(
            DISTINCT CASE
                WHEN t."可用本体数" >= t."需要本体数"
                 AND t."可用紫色狗粮数" < t."需要紫色狗粮数"
                    THEN t."#account_id"
            END
        ) AS "本体足够但狗粮不足玩家数",

        count(
            DISTINCT CASE
                WHEN t."可用本体数" >= t."需要本体数"
                 AND t."可用紫色狗粮数" < t."需要紫色狗粮数"
                    THEN concat(
                        t."#account_id",
                        '_',
                        cast(t."hero_id" AS varchar)
                    )
            END
        ) AS "本体足够但狗粮不足英雄数"

    FROM
    (
        SELECT
            x."#account_id",
            x."新增天数",
            x."首日付费分层",
            x."分层排序",
            x."hero_id",
            x."英雄名称",
            x."阵营",
            x."阵营排序",
            x."当前星级",
            x."可用本体数",
            x."可用紫色狗粮数",
            r."目标星级",
            r."需要本体数",
            r."需要紫色狗粮数"

        FROM
        (
            SELECT
                i."#account_id",
                i."新增天数",
                i."首日付费分层",
                i."分层排序",
                i."hero_id",
                i."英雄名称",
                i."英雄类型",
                i."阵营",
                i."阵营排序",
                i."当前星级",

                greatest(
                    i."累计获得数量"
                    - i."累计本体消耗数量"
                    - 1,
                    0
                ) AS "可用本体数",

                greatest(
                    sum(
                        CASE
                            WHEN i."英雄类型" = '紫色狗粮'
                                THEN i."累计获得数量"
                            ELSE 0
                        END
                    ) OVER (
                        PARTITION BY
                            i."#account_id",
                            i."新增天数",
                            i."阵营"
                    )
                    - i."阵营累计紫色消耗数量",
                    0
                ) AS "可用紫色狗粮数"

            FROM
            (
                SELECT
                    g."#account_id",
                    g."新增日期",
                    g."新增天数",
                    g."统计日期",
                    g."首日付费分层",
                    g."分层排序",
                    g."hero_id",
                    g."英雄名称",
                    g."英雄类型",
                    g."阵营",
                    g."阵营排序",
                    g."累计获得数量",

                    coalesce(
                        max(
                            CASE
                                WHEN s."hero_id" = g."hero_id"
                                    THEN s."升星后星级"
                            END
                        ),
                        g."初始星级"
                    ) AS "当前星级",

                    coalesce(
                        sum(
                            CASE
                                WHEN s."hero_id" = g."hero_id"
                                    THEN s."消耗本体数"
                                ELSE 0
                            END
                        ),
                        0
                    ) AS "累计本体消耗数量",

                    coalesce(
                        sum(
                            s."消耗紫色狗粮数"
                            + CASE
                                WHEN s."英雄类型" = '紫色狗粮'
                                    THEN s."消耗本体数"
                                ELSE 0
                              END
                        ),
                        0
                    ) AS "阵营累计紫色消耗数量"

                FROM
                (
                    SELECT
                        c."#account_id",
                        c."新增日期",
                        d."新增天数",

                        date_add(
                            'day',
                            d."新增天数" - 1,
                            c."新增日期"
                        ) AS "统计日期",

                        c."首日付费分层",
                        c."分层排序",

                        try_cast(
                            e."hero_id"
                            AS bigint
                        ) AS "hero_id",

                        max_by(
                            trim(
                                cast(
                                    e."hero_name"
                                    AS varchar
                                )
                            ),
                            e."#event_time"
                        ) AS "英雄名称",

                        CASE
                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100004,100005,
                                100009,100010,
                                100014,100015,
                                100038,100039,
                                100043,100044
                            )
                                THEN '紫色狗粮'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100016,100017,
                                100018,100019,
                                100020,100021,
                                100045,100046,
                                100047,100048
                            )
                                THEN '低品质'

                            WHEN try_cast(e."hero_id" AS bigint)
                                 BETWEEN 100001 AND 100048
                                THEN '本体'

                            ELSE '其他'
                        END AS "英雄类型",

                        CASE
                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100001,100002,100003,100004,100005,
                                100016,100017,100023,100032,100033
                            ) THEN '火'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100006,100007,100008,100009,100010,
                                100018,100019,100024,100025,100030
                            ) THEN '水'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100011,100012,100013,100014,100015,
                                100020,100021,100022,100031,100034
                            ) THEN '风'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100026,100028,
                                100035,100036,100037,100038,100039,
                                100045,100046
                            ) THEN '光'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100027,100029,
                                100040,100041,100042,100043,100044,
                                100047,100048
                            ) THEN '暗'

                            ELSE '其他'
                        END AS "阵营",

                        CASE
                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100001,100002,100003,100004,100005,
                                100016,100017,100023,100032,100033
                            ) THEN 1

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100006,100007,100008,100009,100010,
                                100018,100019,100024,100025,100030
                            ) THEN 2

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100011,100012,100013,100014,100015,
                                100020,100021,100022,100031,100034
                            ) THEN 3

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100026,100028,
                                100035,100036,100037,100038,100039,
                                100045,100046
                            ) THEN 4

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100027,100029,
                                100040,100041,100042,100043,100044,
                                100047,100048
                            ) THEN 5

                            ELSE 99
                        END AS "阵营排序",

                        max_by(
                            try_cast(
                                e."star"
                                AS bigint
                            ),
                            e."#event_time"
                        ) AS "初始星级",

                        sum(
                            coalesce(
                                try_cast(
                                    e."hero_num"
                                    AS double
                                ),
                                1
                            )
                        ) AS "累计获得数量"

                    FROM
                    (
                        SELECT
                            p."#account_id",
                            p."新增日期",

                            CASE
                                WHEN p."首日付费金额" = 0
                                    THEN 'a_free'
                                WHEN p."首日付费金额" <= 6
                                    THEN 'b_(0,6]'
                                WHEN p."首日付费金额" <= 30
                                    THEN 'c_(6,30]'
                                WHEN p."首日付费金额" <= 100
                                    THEN 'd_(30,100]'
                                WHEN p."首日付费金额" <= 300
                                    THEN 'e_(100,300]'
                                WHEN p."首日付费金额" <= 500
                                    THEN 'f_(300,500]'
                                WHEN p."首日付费金额" <= 1000
                                    THEN 'g_(500,1000]'
                                ELSE 'h_(1000,+)'
                            END AS "首日付费分层",

                            CASE
                                WHEN p."首日付费金额" = 0 THEN 1
                                WHEN p."首日付费金额" <= 6 THEN 2
                                WHEN p."首日付费金额" <= 30 THEN 3
                                WHEN p."首日付费金额" <= 100 THEN 4
                                WHEN p."首日付费金额" <= 300 THEN 5
                                WHEN p."首日付费金额" <= 500 THEN 6
                                WHEN p."首日付费金额" <= 1000 THEN 7
                                ELSE 8
                            END AS "分层排序"

                        FROM
                        (
                            SELECT
                                u."#account_id",
                                u."新增日期",

                                sum(
                                    coalesce(
                                        try_cast(
                                            pay_e."payment"
                                            AS double
                                        ),
                                        0
                                    )
                                ) / 100.0000 AS "首日付费金额"

                            FROM
                            (
                                SELECT
                                    u1."#account_id",
                                    u1."新增日期",
                                    u1."$part_date"

                                FROM
                                (
                                    SELECT
                                        u0."#account_id",
                                        u0."新增日期",
                                        cast(
                                            u0."新增日期"
                                            AS varchar
                                        ) AS "$part_date"

                                    FROM
                                    (
                                        SELECT
                                            cast(
                                                v."#account_id"
                                                AS varchar
                                            ) AS "#account_id",

                                            coalesce(
                                                date(
                                                    try_cast(
                                                        cast(
                                                            v."create_role_time"
                                                            AS varchar
                                                        )
                                                        AS timestamp
                                                    )
                                                ),
                                                date(
                                                    from_unixtime(
                                                        try_cast(
                                                            cast(
                                                                v."create_role_time"
                                                                AS varchar
                                                            )
                                                            AS double
                                                        )
                                                    )
                                                )
                                            ) AS "新增日期"

                                        FROM ta.v_user_44 v

                                        WHERE v."#account_id" IS NOT NULL
                                          AND v."create_role_time" IS NOT NULL
                                    ) u0

                                    WHERE u0."新增日期" IS NOT NULL
                                      AND u0."新增日期" <= current_date
                                ) u1

                                WHERE ${PartDate:date1}
                            ) u

                            LEFT JOIN ta.v_event_44 pay_e
                                ON cast(
                                    pay_e."#account_id"
                                    AS varchar
                                ) = u."#account_id"
                               AND pay_e."$part_event" = 'pay_log'
                               AND date(pay_e."#event_time") = u."新增日期"
                               AND coalesce(
                                    try_cast(
                                        pay_e."payment"
                                        AS double
                                    ),
                                    0
                                   ) > 0

                            GROUP BY
                                u."#account_id",
                                u."新增日期"
                        ) p
                    ) c

                    CROSS JOIN UNNEST(
                        sequence(
                            1,
                            cast(
                                date_diff(
                                    'day',
                                    c."新增日期",
                                    current_date
                                ) + 1
                                AS integer
                            )
                        )
                    ) AS d("新增天数")

                    INNER JOIN ta.v_event_44 e
                        ON cast(
                            e."#account_id"
                            AS varchar
                        ) = c."#account_id"
                       AND e."$part_event" = 'hero_get_log'
                       AND date(e."#event_time")
                           BETWEEN c."新增日期"
                               AND date_add(
                                    'day',
                                    d."新增天数" - 1,
                                    c."新增日期"
                                   )

                    WHERE e."hero_id" IS NOT NULL

                    GROUP BY
                        c."#account_id",
                        c."新增日期",
                        d."新增天数",
                        c."首日付费分层",
                        c."分层排序",
                        try_cast(
                            e."hero_id"
                            AS bigint
                        )
                ) g

                LEFT JOIN
                (
                    SELECT
                        cast(
                            e."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        date(
                            e."#event_time"
                        ) AS "事件日期",

                        try_cast(
                            e."hero_id"
                            AS bigint
                        ) AS "hero_id",

                        try_cast(
                            e."star_after"
                            AS bigint
                        ) AS "升星后星级",

                        CASE
                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100004,100005,
                                100009,100010,
                                100014,100015,
                                100038,100039,
                                100043,100044
                            ) THEN '紫色狗粮'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100016,100017,
                                100018,100019,
                                100020,100021,
                                100045,100046,
                                100047,100048
                            ) THEN '低品质'

                            WHEN try_cast(e."hero_id" AS bigint)
                                 BETWEEN 100001 AND 100048
                                THEN '本体'

                            ELSE '其他'
                        END AS "英雄类型",

                        CASE
                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100001,100002,100003,100004,100005,
                                100016,100017,100023,100032,100033
                            ) THEN '火'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100006,100007,100008,100009,100010,
                                100018,100019,100024,100025,100030
                            ) THEN '水'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100011,100012,100013,100014,100015,
                                100020,100021,100022,100031,100034
                            ) THEN '风'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100026,100028,
                                100035,100036,100037,100038,100039,
                                100045,100046
                            ) THEN '光'

                            WHEN try_cast(e."hero_id" AS bigint) IN (
                                100027,100029,
                                100040,100041,100042,100043,100044,
                                100047,100048
                            ) THEN '暗'

                            ELSE '其他'
                        END AS "阵营",

                        CASE try_cast(
                            e."star_after"
                            AS bigint
                        )
                            WHEN 6  THEN 1
                            WHEN 7  THEN 0
                            WHEN 8  THEN 1
                            WHEN 9  THEN 1
                            WHEN 10 THEN 2
                            WHEN 11 THEN 2
                            WHEN 12 THEN 3
                            WHEN 14 THEN 4
                            WHEN 15 THEN 5
                            ELSE 0
                        END AS "消耗本体数",

                        CASE try_cast(
                            e."star_after"
                            AS bigint
                        )
                            WHEN 6  THEN 0
                            WHEN 7  THEN 3
                            WHEN 8  THEN 3
                            WHEN 9  THEN 3
                            WHEN 10 THEN 1
                            WHEN 11 THEN 5
                            WHEN 12 THEN 1
                            WHEN 14 THEN 5
                            WHEN 15 THEN 3
                            ELSE 0
                        END AS "消耗紫色狗粮数"

                    FROM ta.v_event_44 e

                    WHERE e."$part_event" = 'hero_star_up_log'
                      AND e."#account_id" IS NOT NULL
                      AND e."hero_id" IS NOT NULL
                      AND e."star_after" IS NOT NULL
                ) s

                    ON g."#account_id" = s."#account_id"
                   AND g."阵营" = s."阵营"
                   AND s."事件日期"
                       BETWEEN g."新增日期"
                           AND g."统计日期"

                GROUP BY
                    g."#account_id",
                    g."新增日期",
                    g."新增天数",
                    g."统计日期",
                    g."首日付费分层",
                    g."分层排序",
                    g."hero_id",
                    g."英雄名称",
                    g."英雄类型",
                    g."阵营",
                    g."阵营排序",
                    g."初始星级",
                    g."累计获得数量"
            ) i
        ) x

        INNER JOIN
        (
            SELECT
                r."当前星级",
                r."目标星级",
                r."需要本体数",
                r."需要紫色狗粮数"

            FROM
            (
                VALUES
                    (6,  7, 0, 3),
                    (7,  8, 1, 3),
                    (8,  9, 1, 3),
                    (9, 10, 2, 1),
                    (10,11, 2, 5),
                    (11,12, 3, 1),
                    (12,14, 4, 5),
                    (14,15, 5, 3)
            ) AS r(
                "当前星级",
                "目标星级",
                "需要本体数",
                "需要紫色狗粮数"
            )
        ) r
            ON x."当前星级" = r."当前星级"

        WHERE x."英雄类型" = '本体'
          AND x."阵营" <> '其他'
    ) t

    GROUP BY
        t."新增天数",
        t."首日付费分层",
        t."分层排序",
        t."hero_id",
        t."英雄名称",
        t."阵营",
        t."阵营排序",
        t."当前星级",
        t."目标星级",
        t."需要本体数",
        t."需要紫色狗粮数"
) q

ORDER BY
    q."新增天数",
    q."分层排序",
    q."阵营排序",
    q."hero_id",
    q."目标星级";