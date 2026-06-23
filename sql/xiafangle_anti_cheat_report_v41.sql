SELECT
    r.role_id AS "角色ID",
    r.server_id AS "服务器ID",
    r.create_role_time AS "创角时间",
    r.abnormal_type AS "异常类型",
    max_by(r.deal_rule, r.abnormal_time) AS "客服封禁规则",
    max_by(r.vip_level, r.abnormal_time) AS "VIP等级",
    round(max_by(r.payment_amount, r.abnormal_time), 2) AS "累充金额",
    max(r.abnormal_time) AS "最后异常时间",
    count(*) AS "异常次数",
    max_by(r.season, r.abnormal_time) AS "赛季",
    round(max_by(r.player_power, r.abnormal_time), 2) AS "玩家战力",
    max_by(r.vip_group, r.abnormal_time) AS "VIP分层",
    max_by(r.channel_id, r.abnormal_time) AS "包体渠道ID"
FROM
(
    SELECT
        x.role_id,
        x.server_id,
        x.create_role_time,
        t.abnormal_type,
        CASE
            WHEN t.abnormal_type = 'PVE耗时异常' THEN '/'
            WHEN x.payment_amount >= 30000 THEN '评估'
            ELSE '直接封'
        END AS deal_rule,
        x.vip_level,
        x.payment_amount,
        x.abnormal_time,
        x.season,
        x.player_power,
        x.vip_group,
        x.channel_id
    FROM
    (
        SELECT
            b.*,

            avg(
                IF(b.event_name = 'battle_check' AND b.duration IS NOT NULL, b.duration, NULL)
            ) OVER (
                PARTITION BY
                    b.power_group,
                    b.reg_day_group,
                    b.battle_type,
                    b.map_id
            ) AS avg_duration,

            stddev_samp(
                IF(b.event_name = 'battle_check' AND b.duration IS NOT NULL, b.duration, NULL)
            ) OVER (
                PARTITION BY
                    b.power_group,
                    b.reg_day_group,
                    b.battle_type,
                    b.map_id
            ) AS std_duration,

            count(
                IF(b.event_name = 'battle_check' AND b.duration IS NOT NULL, 1, NULL)
            ) OVER (
                PARTITION BY
                    b.power_group,
                    b.reg_day_group,
                    b.battle_type,
                    b.map_id
            ) AS duration_sample_count,

            approx_percentile(
                IF(
                    b.event_name = 'boss_battle_result'
                    AND b.battle_value_num IS NOT NULL,
                    b.battle_value_num,
                    NULL
                ),
                0.99
            ) OVER (
                PARTITION BY
                    b.power_group,
                    b.season,
                    b.natural_week,
                    b.map_id
            ) AS boss_damage_max_p,

            count(
                IF(
                    b.event_name = 'boss_battle_result'
                    AND b.battle_value_num IS NOT NULL,
                    1,
                    NULL
                )
            ) OVER (
                PARTITION BY
                    b.power_group,
                    b.season,
                    b.natural_week,
                    b.map_id
            ) AS boss_damage_sample_count

        FROM
        (
            SELECT
                CAST(e."$part_event" AS varchar) AS event_name,
                CAST(e."#account_id" AS varchar) AS role_id,

                CAST(e."region_id" AS varchar) AS server_id,
                CAST(e."create_role_time" AS timestamp) AS create_role_time,
                v.vip_level,

                COALESCE(TRY_CAST(e."total_payment" AS double), 0) AS payment_amount,
                TRY_CAST(e."power" AS double) AS player_power,

                CAST(e."channel_id" AS varchar) AS channel_id,

                CAST(e."#event_time" AS timestamp) AS abnormal_time,
                CAST(e."$part_date" AS date) AS report_date,

                COALESCE(CAST(e."season" AS varchar), '未知') AS season,
                CAST(date_trunc('week', CAST(e."#event_time" AS timestamp)) AS date) AS natural_week,

                TRY_CAST(e."battle_type" AS integer) AS battle_type,
                TRY_CAST(e."map_id" AS integer) AS map_id,

                TRY_CAST(e."duration" AS double) AS duration,

                TRY_CAST(e."reportHpMax" AS double) AS report_hp_max,
                TRY_CAST(e."svrHpMax" AS double) AS svr_hp_max,
                TRY_CAST(e."reportNpcHpMax" AS double) AS report_npc_hp_max,
                TRY_CAST(e."svrNpcHpMax" AS double) AS svr_npc_hp_max,
                TRY_CAST(e."refreshCard" AS double) AS refresh_card,

                NULLIF(trim(CAST(e."battle_value" AS varchar)), '') AS battle_value_raw,
                TRY_CAST(NULLIF(trim(CAST(e."battle_value" AS varchar)), '') AS double) AS battle_value_num,

                CASE
                    WHEN TRY_CAST(e."power" AS double) IS NULL THEN 'z_未知'
                    WHEN TRY_CAST(e."power" AS double) < 50000 THEN 'a_<5w'
                    WHEN TRY_CAST(e."power" AS double) < 100000 THEN 'b_5w-10w'
                    WHEN TRY_CAST(e."power" AS double) < 200000 THEN 'c_10w-20w'
                    WHEN TRY_CAST(e."power" AS double) < 500000 THEN 'd_20w-50w'
                    WHEN TRY_CAST(e."power" AS double) < 1000000 THEN 'e_50w-100w'
                    ELSE 'f_100w+'
                END AS power_group,

                CASE
                    WHEN e."create_role_time" IS NULL THEN 'z_未知'
                    WHEN date_diff('day', date(CAST(e."create_role_time" AS timestamp)), date(CAST(e."#event_time" AS timestamp))) <= 0 THEN 'a_0日'
                    WHEN date_diff('day', date(CAST(e."create_role_time" AS timestamp)), date(CAST(e."#event_time" AS timestamp))) = 1 THEN 'b_1日'
                    WHEN date_diff('day', date(CAST(e."create_role_time" AS timestamp)), date(CAST(e."#event_time" AS timestamp))) <= 3 THEN 'c_2-3日'
                    WHEN date_diff('day', date(CAST(e."create_role_time" AS timestamp)), date(CAST(e."#event_time" AS timestamp))) <= 7 THEN 'd_4-7日'
                    WHEN date_diff('day', date(CAST(e."create_role_time" AS timestamp)), date(CAST(e."#event_time" AS timestamp))) <= 14 THEN 'e_8-14日'
                    WHEN date_diff('day', date(CAST(e."create_role_time" AS timestamp)), date(CAST(e."#event_time" AS timestamp))) <= 30 THEN 'f_15-30日'
                    ELSE 'g_30日+'
                END AS reg_day_group,

                CASE
                    WHEN COALESCE(TRY_CAST(e."total_payment" AS double), 0) = 0 THEN 'a_0'
                    WHEN COALESCE(TRY_CAST(e."total_payment" AS double), 0) < 1000 THEN 'b_(0,1000)'
                    WHEN COALESCE(TRY_CAST(e."total_payment" AS double), 0) < 30000 THEN 'c_[1000,30000)'
                    ELSE 'd_30000+'
                END AS vip_group

            FROM ta.v_event_41 e
            LEFT JOIN
            (
                SELECT
                    CAST("#account_id" AS varchar) AS role_id,
                    max_by(
                        TRY_CAST("after" AS double),
                        CAST("#event_time" AS timestamp)
                    ) AS vip_level
                FROM ta.v_event_41
                WHERE "$part_event" = 'vip_change_log'
                  AND "$part_date" >= '2023-10-01'
                GROUP BY CAST("#account_id" AS varchar)
            ) v
            ON CAST(e."#account_id" AS varchar) = v.role_id

            WHERE e."$part_event" IN ('battle_check', 'boss_battle_result')
              AND e."$part_date"${PartDate:date}
              AND COALESCE(CAST(e."domain" AS varchar), 'release') = 'release'
        ) b
    ) x

    CROSS JOIN UNNEST(
        ARRAY[
            CASE
                WHEN x.event_name = 'battle_check'
                 AND x.duration_sample_count >= 30
                 AND x.std_duration > 0
                 AND abs(x.duration - x.avg_duration) / x.std_duration > 3
                THEN 'PVE耗时异常'
            END,

            CASE
                WHEN x.event_name = 'battle_check'
                 AND x.svr_hp_max > 0
                 AND x.report_hp_max / x.svr_hp_max >= 5
                THEN '城墙最大生命值异常'
            END,

            CASE
                WHEN x.event_name = 'battle_check'
                 AND x.svr_npc_hp_max IS NOT NULL
                 AND x.report_npc_hp_max IS NOT NULL
                 AND x.svr_npc_hp_max * 0.75 > x.report_npc_hp_max
                THEN '怪物生命削弱'
            END,

            CASE
                WHEN x.event_name = 'battle_check'
                 AND x.refresh_card IS NOT NULL
                THEN '对局内刷卡次数修改'
            END,

            CASE
                WHEN x.event_name = 'boss_battle_result'
                 AND x.battle_value_raw IS NULL
                THEN '部落BOSS伤害溢出'
            END,

            CASE
                WHEN x.event_name = 'boss_battle_result'
                 AND x.battle_value_num IS NOT NULL
                 AND x.boss_damage_sample_count >= 30
                 AND x.boss_damage_max_p > 0
                 AND (
                        (
                            x.payment_amount < 1000
                            AND x.battle_value_num / x.boss_damage_max_p > 5.55
                        )
                        OR
                        (
                            x.payment_amount >= 1000
                            AND x.battle_value_num / x.boss_damage_max_p >= 10
                        )
                     )
                THEN '部落BOSS伤害异常'
            END
        ]
    ) AS t(abnormal_type)

    WHERE t.abnormal_type IS NOT NULL
) r
GROUP BY
    r.role_id,
    r.server_id,
    r.create_role_time,
    r.abnormal_type
ORDER BY
    "最后异常时间" DESC,
    "异常次数" DESC,
    "角色ID"
