-- 下方了｜按开服天数 × 截至当天累计付费分层 战力提升幅度监控
-- 口径：
-- 1. ${PartDate:date} 仅用于限定统计周期，日期不作为最终展示/分组维度。
-- 2. 只统计统计周期内存在 in_out_log 的活跃角色。
-- 3. 开服天数 = 活跃日期 - server_open_time + 1，开服当天记 D1。
-- 4. 累计付费 = 截至该活跃日（含当天）的 pay_log.payment / 100，按角色累计。
-- 5. 累计付费分层：0、(0,6]、(6,30]、(30,100]、(100,300]、(300,500]、(500,1000]、1000+。
-- 6. 当天开始战力 = 当天 change_power_log 第一条 before；当天结束战力 = 当天最后一条 after。
-- 7. 当天战力提升幅度 = (结束战力 - 开始战力) * 100 / 开始战力，12.35 代表 12.35%。
-- 8. 当天活跃但没有 change_power_log 的角色，提升幅度按 0。
-- 9. 若存在 change_power_log 但当天开始战力 <= 0，则百分比无意义，记为 NULL，不参与均值/最值/四分位。
-- 10. change_power_log 可能存在后台重算，因此只在 in_out_log 活跃日纳入统计。

select      row_number() over(
                order by q."开服天数",q."分层排序"
            ) "序号",
            q."开服天数",
            q."累计付费分层",
            q."活跃玩家数",
            q."有效战力样本数",
            q."战力有变动玩家数",
            q."战力提升玩家数",
            round(q."平均战力提升幅度",2) "平均战力提升幅度(%)",
            round(q."最小战力提升幅度",2) "最小战力提升幅度(%)",
            round(q."P25战力提升幅度",2) "P25战力提升幅度(%)",
            round(q."P50战力提升幅度",2) "P50战力提升幅度(%)",
            round(q."P75战力提升幅度",2) "P75战力提升幅度(%)",
            round(q."最大战力提升幅度",2) "最大战力提升幅度(%)"

from
(
    select      t."开服天数",
                t."累计付费分层",
                t."分层排序",

                count(*) "活跃玩家数",

                count(
                    t."当天战力提升幅度"
                ) "有效战力样本数",

                sum(
                    case
                        when t."当天战力提升幅度" <> 0 then 1
                        else 0
                    end
                ) "战力有变动玩家数",

                sum(
                    case
                        when t."当天战力提升幅度" > 0 then 1
                        else 0
                    end
                ) "战力提升玩家数",

                avg(
                    cast(
                        t."当天战力提升幅度"
                        as double
                    )
                ) "平均战力提升幅度",

                min(
                    cast(
                        t."当天战力提升幅度"
                        as double
                    )
                ) "最小战力提升幅度",

                approx_percentile(
                    cast(
                        t."当天战力提升幅度"
                        as double
                    ),
                    0.25
                ) "P25战力提升幅度",

                approx_percentile(
                    cast(
                        t."当天战力提升幅度"
                        as double
                    ),
                    0.50
                ) "P50战力提升幅度",

                approx_percentile(
                    cast(
                        t."当天战力提升幅度"
                        as double
                    ),
                    0.75
                ) "P75战力提升幅度",

                max(
                    cast(
                        t."当天战力提升幅度"
                        as double
                    )
                ) "最大战力提升幅度"

    from
    (
        select      s."日期",
                    s."#account_id",
                    s."开服天数",
                    s."累计付费金额",

                    case
                        when s."累计付费金额" = 0
                            then 'a_free'
                        when s."累计付费金额" > 0
                         and s."累计付费金额" <= 6
                            then 'b_(0,6]'
                        when s."累计付费金额" > 6
                         and s."累计付费金额" <= 30
                            then 'c_(6,30]'
                        when s."累计付费金额" > 30
                         and s."累计付费金额" <= 100
                            then 'd_(30,100]'
                        when s."累计付费金额" > 100
                         and s."累计付费金额" <= 300
                            then 'e_(100,300]'
                        when s."累计付费金额" > 300
                         and s."累计付费金额" <= 500
                            then 'f_(300,500]'
                        when s."累计付费金额" > 500
                         and s."累计付费金额" <= 1000
                            then 'g_(500,1000]'
                        else 'h_(1000,+)'
                    end "累计付费分层",

                    case
                        when s."累计付费金额" = 0 then 1
                        when s."累计付费金额" <= 6 then 2
                        when s."累计付费金额" <= 30 then 3
                        when s."累计付费金额" <= 100 then 4
                        when s."累计付费金额" <= 300 then 5
                        when s."累计付费金额" <= 500 then 6
                        when s."累计付费金额" <= 1000 then 7
                        else 8
                    end "分层排序",

                    case
                        when pw."#account_id" is null then 0
                        else pw."当天战力提升幅度"
                    end "当天战力提升幅度"

        from
        (
            select      a."日期",
                        a."#account_id",
                        a."开服天数",

                        coalesce(
                            sum(
                                pay."当日付费金额"
                            ),
                            0
                        ) "累计付费金额"

            from
            (
                select distinct
                            date(
                                e."#event_time"
                            ) "日期",

                            cast(
                                e."#account_id"
                                as varchar
                            ) "#account_id",

                            date_diff(
                                'day',
                                date(u."server_open_time"),
                                date(e."#event_time")
                            ) + 1 "开服天数"

                from        ta.v_event_41 e

                inner join  ta.v_user_41 u
                    on      cast(e."#account_id" as varchar)
                            = cast(u."#account_id" as varchar)

                where       ${PartDate:date}
                            and e."domain" = 'release'
                            and u."domain" = 'release'
                            and e."$part_event" = 'in_out_log'
                            and e."#account_id" is not null
                            and u."server_open_time" is not null
                            and date(e."#event_time") >= date(u."server_open_time")
            )a

            left join
            (
                select      cast(
                                e."#account_id"
                                as varchar
                            ) "#account_id",

                            date(
                                e."#event_time"
                            ) "付费日期",

                            sum(
                                coalesce(
                                    try_cast(
                                        e."payment"
                                        as double
                                    ),
                                    0
                                )
                            ) / 100.0000 "当日付费金额"

                from        ta.v_event_41 e

                where       e."domain" = 'release'
                            and e."$part_event" = 'pay_log'
                            and e."#account_id" is not null
                            and coalesce(
                                    try_cast(
                                        e."payment"
                                        as double
                                    ),
                                    0
                                ) > 0

                group by    1,2
            )pay

                on          a."#account_id" = pay."#account_id"
                and         pay."付费日期" <= a."日期"

            group by        1,2,3
        )s

        left join
        (
            select      z."日期",
                        z."#account_id",

                        case
                            when z."开始战力" > 0
                                then
                                (
                                    z."结束战力"
                                    -
                                    z."开始战力"
                                )
                                * 100.0000
                                / z."开始战力"
                            else null
                        end "当天战力提升幅度"

            from
            (
                select      date(
                                e."#event_time"
                            ) "日期",

                            cast(
                                e."#account_id"
                                as varchar
                            ) "#account_id",

                            min_by(
                                try_cast(
                                    e."before"
                                    as double
                                ),
                                e."#event_time"
                            ) "开始战力",

                            max_by(
                                try_cast(
                                    e."after"
                                    as double
                                ),
                                e."#event_time"
                            ) "结束战力"

                from        ta.v_event_41 e

                where       ${PartDate:date}
                            and e."domain" = 'release'
                            and e."$part_event" = 'change_power_log'
                            and e."#account_id" is not null
                            and try_cast(
                                    e."before"
                                    as double
                                ) is not null
                            and try_cast(
                                    e."after"
                                    as double
                                ) is not null

                group by    1,2
            )z
        )pw

            on          s."日期" = pw."日期"
            and         s."#account_id" = pw."#account_id"
    )t

    group by    1,2,3
)q

order by    q."开服天数",
            q."分层排序";
