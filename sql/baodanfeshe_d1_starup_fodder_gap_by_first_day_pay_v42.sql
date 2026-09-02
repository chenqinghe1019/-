SELECT
    row_number() OVER (
        ORDER BY
            q."新增天数",
            q."分层排序",
            q."阵营排序",
            q."目标星级"
    ) AS "序号",

    q."新增天数",
    q."首日付费分层",
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
                        cast(t."role_id" AS varchar)
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
                        cast(t."role_id" AS varchar)
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
            x."role_id",
            x."英雄名称",
            x."阵营",
            x."阵营排序",
            x."当前星级",

            greatest(
                x."剩余英雄数量" - 1,
                0
            ) AS "可用本体数",

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
                i."role_id",
                i."英雄名称",
                i."英雄类型",
                i."阵营",
                i."阵营排序",
                i."当前星级",
                i."剩余英雄数量",

                sum(
                    CASE
                        WHEN i."英雄类型" = '紫色狗粮'
                            THEN i."剩余英雄数量"
                        ELSE 0
                    END
                ) OVER (
                    PARTITION BY
                        i."#account_id",
                        i."新增天数",
                        i."阵营"
                ) AS "可用紫色狗粮数"

            FROM
            (
                SELECT
                    o."#account_id",
                    o."新增日期",
                    o."新增天数",
                    o."统计日期",
                    o."首日付费分层",
                    o."分层排序",
                    o."role_id",
                    o."英雄名称",
                    o."英雄类型",
                    o."阵营",
                    o."阵营排序",

                    coalesce(
                        max_by(
                            CASE
                                WHEN s."role_id" = o."role_id"
                                    THEN s."nstar"
                            END,
                            CASE
                                WHEN s."role_id" = o."role_id"
                                    THEN s."#event_time"
                            END
                        ),
                        o."初始星级"
                    ) AS "当前星级",

                    greatest(
                        o."获得数量"
                        -
                        coalesce(
                            sum(
                                CASE
                                    WHEN s."消耗英雄名称" = o."英雄名称"
                                        THEN s."消耗数量"
                                    ELSE 0
                                END
                            ),
                            0
                        ),
                        0
                    ) AS "剩余英雄数量"

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
                            e."role_id"
                            AS bigint
                        ) AS "role_id",

                        max(
                            trim(
                                cast(
                                    e."hero_name"
                                    AS varchar
                                )
                            )
                        ) AS "英雄名称",

                        CASE
                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100004,100005,
                                100009,100010,
                                100014,100015,
                                100038,100039,
                                100043,100044
                            )
                                THEN '紫色狗粮'

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100016,100017,
                                100018,100019,
                                100020,100021,
                                100045,100046,
                                100047,100048
                            )
                                THEN '低品质'

                            WHEN try_cast(e."role_id" AS bigint)
                                 BETWEEN 100001 AND 100048
                                THEN '本体'

                            ELSE '其他'
                        END AS "英雄类型",

                        CASE
                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100001,100002,100003,100004,100005,
                                100016,100017,100023,100032,100033
                            )
                                THEN '火'

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100006,100007,100008,100009,100010,
                                100018,100019,100024,100025,100030
                            )
                                THEN '水'

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100011,100012,100013,100014,100015,
                                100020,100021,100022,100031,100034
                            )
                                THEN '风'

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100026,100028,
                                100035,100036,100037,100038,100039,
                                100045,100046
                            )
                                THEN '光'

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100027,100029,
                                100040,100041,100042,100043,100044,
                                100047,100048
                            )
                                THEN '暗'

                            ELSE '其他'
                        END AS "阵营",

                        CASE
                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100001,100002,100003,100004,100005,
                                100016,100017,100023,100032,100033
                            )
                                THEN 1

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100006,100007,100008,100009,100010,
                                100018,100019,100024,100025,100030
                            )
                                THEN 2

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100011,100012,100013,100014,100015,
                                100020,100021,100022,100031,100034
                            )
                                THEN 3

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100026,100028,
                                100035,100036,100037,100038,100039,
                                100045,100046
                            )
                                THEN 4

                            WHEN try_cast(e."role_id" AS bigint) IN (
                                100027,100029,
                                100040,100041,100042,100043,100044,
                                100047,100048
                            )
                                THEN 5

                            ELSE 99
                        END AS "阵营排序",

                        max(
                            try_cast(
                                e."init_star"
                                AS bigint
                            )
                        ) AS "初始星级",

                        count(*) AS "获得数量"

                    FROM
                    (
                        SELECT
                            p."#account_id",
                            p."新增日期",
                            p."首日付费金额",

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
                                ) AS "首日付费金额"

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
                                                u."#account_id"
                                                AS varchar
                                            ) AS "#account_id",

                                            coalesce(
                                                date(
                                                    try_cast(
                                                        cast(
                                                            u."create_role_time"
                                                            AS varchar
                                                        )
                                                        AS timestamp
                                                    )
                                                ),

                                                date(
                                                    from_unixtime(
                                                        try_cast(
                                                            cast(
                                                                u."create_role_time"
                                                                AS varchar
                                                            )
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

                            LEFT JOIN ta.v_event_42 pay_e

                                ON cast(
                                    pay_e."#account_id"
                                    AS varchar
                                ) = u."#account_id"

                               AND pay_e."$part_event" = 'pay_log'
                               AND pay_e."domain" = 'release'

                               AND date(
                                    pay_e."$part_date"
                                   ) = u."新增日期"

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
                                    current_date - interval '1' day
                                ) + 1
                                AS integer
                            )
                        )
                    ) AS d("新增天数")

                    INNER JOIN ta.v_event_42 e

                        ON cast(
                            e."#account_id"
                            AS varchar
                        ) = c."#account_id"

                       AND e."$part_event" = 'role_obtain_log'
                       AND e."domain" = 'release'

                       AND date(e."$part_date")
                           BETWEEN c."新增日期"
                               AND date_add(
                                    'day',
                                    d."新增天数" - 1,
                                    c."新增日期"
                                   )

                    WHERE e."#account_id" IS NOT NULL
                      AND e."role_id" IS NOT NULL

                    GROUP BY
                        c."#account_id",
                        c."新增日期",
                        d."新增天数",
                        c."首日付费分层",
                        c."分层排序",
                        try_cast(
                            e."role_id"
                            AS bigint
                        )
                ) o

                LEFT JOIN
                (
                    SELECT
                        cast(
                            e."#account_id"
                            AS varchar
                        ) AS "#account_id",

                        date(
                            e."$part_date"
                        ) AS "事件日期",

                        e."#event_time",

                        try_cast(
                            e."role_id"
                            AS bigint
                        ) AS "role_id",

                        try_cast(
                            e."nstar"
                            AS bigint
                        ) AS "nstar",

                        trim(
                            cast(
                                x."name"
                                AS varchar
                            )
                        ) AS "消耗英雄名称",

                        coalesce(
                            x."num",
                            0
                        ) AS "消耗数量"

                    FROM ta.v_event_42 e

                    CROSS JOIN UNNEST(
                        e."cost_thing_list"
                    ) AS x(
                        "num",
                        "name",
                        "cid"
                    )

                    WHERE e."$part_event" = 'role_upstar_log'
                      AND e."domain" = 'release'
                      AND e."#account_id" IS NOT NULL
                      AND e."cost_thing_list" IS NOT NULL
                ) s

                    ON o."#account_id" = s."#account_id"

                   AND s."事件日期"
                       BETWEEN o."新增日期"
                           AND o."统计日期"

                GROUP BY
                    o."#account_id",
                    o."新增日期",
                    o."新增天数",
                    o."统计日期",
                    o."首日付费分层",
                    o."分层排序",
                    o."role_id",
                    o."英雄名称",
                    o."英雄类型",
                    o."阵营",
                    o."阵营排序",
                    o."初始星级",
                    o."获得数量"
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
    q."目标星级";