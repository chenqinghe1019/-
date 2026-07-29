SELECT
    x.season_id AS "赛季ID",
    x.role_id AS "角色ID",
    x.server_id AS "服务器ID",
    round(x.payment_amount, 2) AS "累充金额",
    x.abnormal_time AS "异常时间",

    array_join(
        filter(
            ARRAY[
                CASE
                    WHEN x.svr_hp_max > 0
                     AND x.report_hp_max / x.svr_hp_max >= 2
                    THEN '城墙最大生命值异常'
                END,
                CASE
                    WHEN x.svr_npc_hp_max > 0
                     AND x.report_npc_hp_max / x.svr_npc_hp_max < 0.9
                    THEN '怪物生命削弱'
                END,
                CASE
                    WHEN x.refresh_card > 2
                    THEN '对局内刷卡次数修改'
                END
            ],
            abnormal_name -> abnormal_name IS NOT NULL
        ),
        '、'
    ) AS "异常情况",

    x.refresh_card AS "修改刷卡次数",

    round(
        x.report_npc_hp_max / NULLIF(x.svr_npc_hp_max, 0),
        4
    ) AS "怪物异常生命比例（客户端/服务端）",

    round(
        x.report_hp_max / NULLIF(x.svr_hp_max, 0),
        4
    ) AS "城墙异常生命比例（客户端/服务端）",

    x.battle_uid AS "异常battle_uid",
    x.battle_type AS "battle_type",
    x.map_id AS "map_id"

FROM
(
    SELECT
        l.season_id,
        CAST(e."#account_id" AS varchar) AS role_id,
        TRY_CAST(e."region_id" AS bigint) AS server_id,
        COALESCE(TRY_CAST(e."total_payment" AS double), 0) / 100.0 AS payment_amount,
        CAST(e."#event_time" AS timestamp) AS abnormal_time,

        NULLIF(trim(CAST(e."battle_uid" AS varchar)), '') AS battle_uid,
        TRY_CAST(e."battle_type" AS integer) AS battle_type,
        TRY_CAST(e."map_id" AS integer) AS map_id,

        TRY_CAST(NULLIF(trim(CAST(e."refreshCard" AS varchar)), '') AS double) AS refresh_card,

        TRY_CAST(NULLIF(trim(CAST(e."reportNpcHpMax" AS varchar)), '') AS double) AS report_npc_hp_max,
        TRY_CAST(NULLIF(trim(CAST(e."svrNpcHpMax" AS varchar)), '') AS double) AS svr_npc_hp_max,

        TRY_CAST(NULLIF(trim(CAST(e."reportHpMax" AS varchar)), '') AS double) AS report_hp_max,
        TRY_CAST(NULLIF(trim(CAST(e."svrHpMax" AS varchar)), '') AS double) AS svr_hp_max

    FROM ta.v_event_41 e

    LEFT JOIN
    (
        SELECT
            CAST(login_e."#account_id" AS varchar) AS role_id,
            CAST(login_e."$part_date" AS date) AS login_date,

            max_by(
                TRY_CAST(login_e."season" AS bigint),
                CAST(login_e."#event_time" AS timestamp)
            ) FILTER
            (
                WHERE TRY_CAST(login_e."season" AS bigint) IS NOT NULL
            ) AS season_id

        FROM ta.v_event_41 login_e
        WHERE login_e."$part_event" = 'in_out_log'
          AND login_e.${PartDate:date}
          AND COALESCE(CAST(login_e."domain" AS varchar), 'release') = 'release'
          AND login_e."#account_id" IS NOT NULL

        GROUP BY
            CAST(login_e."#account_id" AS varchar),
            CAST(login_e."$part_date" AS date)
    ) l
    ON CAST(e."#account_id" AS varchar) = l.role_id
   AND CAST(e."$part_date" AS date) = l.login_date

    WHERE e."$part_event" = 'battle_check'
      AND e.${PartDate:date}
      AND COALESCE(CAST(e."domain" AS varchar), 'release') = 'release'
) x

WHERE
    x.battle_type <> 8
    AND
    (
           (
                x.svr_hp_max > 0
            AND x.report_hp_max / x.svr_hp_max >= 2
           )
        OR (
                x.svr_npc_hp_max > 0
            AND x.report_npc_hp_max / x.svr_npc_hp_max < 0.9
           )
        OR x.refresh_card > 2
    )

ORDER BY
    x.abnormal_time DESC,
    x.role_id,
    x.battle_uid
