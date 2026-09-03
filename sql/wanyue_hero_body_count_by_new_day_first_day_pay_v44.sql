SELECT
    row_number() OVER (
        ORDER BY
            q."新增天数",
            q."分层排序",
            q."阵营排序",
            q."hero_id",
            q."累计本体数量"
    ) AS "序号",

    q."新增天数",
    q."首日付费分层",
    q."hero_id" AS "英雄ID",

    CASE q."hero_id"
        WHEN 100001 THEN '哪吒蕉'
        WHEN 100002 THEN '草帽蕉'
        WHEN 100003 THEN '一拳蕉'
        WHEN 100004 THEN '骑手蕉'
        WHEN 100005 THEN '六耳蕉'
        WHEN 100006 THEN '功夫蕉'
        WHEN 100007 THEN '海星蕉'
        WHEN 100008 THEN '白蛇蕉'
        WHEN 100009 THEN '高雅蕉'
        WHEN 100010 THEN '卡皮蕉'
        WHEN 100011 THEN '关羽蕉'
        WHEN 100012 THEN '冒险蕉'
        WHEN 100013 THEN '上将蕉'
        WHEN 100014 THEN '魔法蕉'
        WHEN 100015 THEN '僵尸蕉'
        WHEN 100016 THEN '炽热之蕉'
        WHEN 100017 THEN '火之蕉'
        WHEN 100018 THEN '凛冽之蕉'
        WHEN 100019 THEN '水之蕉'
        WHEN 100020 THEN '迅疾之蕉'
        WHEN 100021 THEN '风之蕉'
        WHEN 100022 THEN '疾风蕉'
        WHEN 100023 THEN '龙影蕉'
        WHEN 100024 THEN '熊猫蕉'
        WHEN 100025 THEN '电磁蕉'
        WHEN 100026 THEN '机甲蕉'
        WHEN 100027 THEN '黑猴蕉'
        WHEN 100028 THEN '逸仙蕉'
        WHEN 100029 THEN '吕布蕉'
        WHEN 100030 THEN '音律蕉'
        WHEN 100031 THEN '木兰蕉'
        WHEN 100032 THEN '张飞蕉'
        WHEN 100033 THEN '绯红蕉'
        WHEN 100034 THEN '灵越蕉'
        WHEN 100035 THEN '忍者蕉'
        WHEN 100036 THEN '星月蕉'
        WHEN 100037 THEN '伏特蕉'
        WHEN 100038 THEN '奶牛蕉'
        WHEN 100039 THEN '爱神蕉'
        WHEN 100040 THEN '草莓蕉'
        WHEN 100041 THEN '女仆蕉'
        WHEN 100042 THEN '魔焰蕉'
        WHEN 100043 THEN '光头蕉'
        WHEN 100044 THEN '魔藤蕉'
        WHEN 100045 THEN '昭明之蕉'
        WHEN 100046 THEN '光之蕉'
        WHEN 100047 THEN '玄幽之蕉'
        WHEN 100048 THEN '暗之蕉'
        ELSE q."英雄名称"
    END AS "具体卡",

    q."阵营",
    q."累计本体数量",
    q."玩家数",

    round(
        q."玩家数" * 1.0000
        / nullif(
            sum(q."玩家数") OVER (
                PARTITION BY
                    q."新增天数",
                    q."首日付费分层",
                    q."hero_id"
            ),
            0
        ),
        4
    ) AS "本体数量玩家占比"

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
        t."累计本体数量",
        count(DISTINCT t."#account_id") AS "玩家数"

    FROM
    (
        SELECT
            c."#account_id",
            c."新增日期",
            d."新增天数",
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

            cast(
                round(
                    coalesce(
                        max_by(
                            try_cast(
                                e."hero_result"
                                AS double
                            ),
                            e."#event_time"
                        ),
                        sum(
                            coalesce(
                                try_cast(
                                    e."hero_num"
                                    AS double
                                ),
                                1
                            )
                        )
                    )
                )
                AS bigint
            ) AS "累计本体数量"

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
          AND try_cast(e."hero_id" AS bigint)
              BETWEEN 100001 AND 100048

          AND try_cast(e."hero_id" AS bigint) NOT IN (
                100004,100005,
                100009,100010,
                100014,100015,
                100038,100039,
                100043,100044,
                100016,100017,
                100018,100019,
                100020,100021,
                100045,100046,
                100047,100048
          )

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
    ) t

    WHERE t."累计本体数量" IS NOT NULL

    GROUP BY
        t."新增天数",
        t."首日付费分层",
        t."分层排序",
        t."hero_id",
        t."英雄名称",
        t."阵营",
        t."阵营排序",
        t."累计本体数量"
) q

ORDER BY
    q."新增天数",
    q."分层排序",
    q."阵营排序",
    q."hero_id",
    q."累计本体数量";