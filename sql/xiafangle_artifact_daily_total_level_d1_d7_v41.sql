-- 下方了 v41：新增角色后7日每日神器总等级（按首日付费分层汇总）
-- 口径：
-- 1. D1=创角当天，D7=创角后第6个自然日。
-- 2. role_art_uplv_log：按 ins_id 记录神器升级，升级后当前等级取 nlv。
-- 3. role_art_reborn_lv_log：与升级流水按 ins_id 连续处理；发生等级重生后当前等级记为 0。
-- 4. 每个自然日日末，按 #account_id + ins_id 取截至当日日末最后一条状态，再对该角色所有 ins_id 求和。
-- 5. 当天没有新的神器事件时，沿用此前最后状态；没有任何神器升级/重生记录的角色总等级为0。
-- 6. 首日付费金额取创角当天 pay_log.payment / 100，按固定首日付费分层拆分。
-- 7. 最终按 首日付费分层 × D1~D7 汇总；新增日期不拆日，只显示本次筛选对应的新增时间段。

select      row_number() over(
                order by q.pay_sort,
                         q.day_no
            ) "序号",
            case
                when q.min_create_date = q.max_create_date then q.min_create_date
                else q.min_create_date || '~' || q.max_create_date
            end "新增日期",
            q.pay_level "首日付费分层",
            'D' || cast(q.day_no as varchar) "新增后第N日",
            q.role_cnt "新增角色数",
            round(q.total_art_level,2) "神器总等级合计",
            round(q.avg_art_level,2) "人均神器总等级"
from
(
    select      x.pay_level,
                x.pay_sort,
                x.day_no,
                min(x."新增日期") min_create_date,
                max(x."新增日期") max_create_date,
                count(distinct x."#account_id") role_cnt,
                sum(x.total_art_level) total_art_level,
                avg(x.total_art_level) avg_art_level
    from
    (
        select      a."新增日期",
                    a."#account_id",
                    a.pay_level,
                    a.pay_sort,
                    a.day_no,
                    sum(coalesce(a.current_art_level,0)) total_art_level
        from
        (
            select      d."新增日期",
                        d."#account_id",
                        d.pay_level,
                        d.pay_sort,
                        d.day_no,
                        e.ins_id,
                        max_by(
                            e.current_art_level,
                            e.event_time
                        ) current_art_level
            from
            (
                select      u."新增日期",
                            u."#account_id",
                            u.create_role_time,
                            case
                                when coalesce(u.first_day_pay,0) = 0 then 'a_free'
                                when coalesce(u.first_day_pay,0) > 0 and coalesce(u.first_day_pay,0) <= 6 then 'b_(0,6]'
                                when coalesce(u.first_day_pay,0) > 6 and coalesce(u.first_day_pay,0) <= 30 then 'c_(6,30]'
                                when coalesce(u.first_day_pay,0) > 30 and coalesce(u.first_day_pay,0) <= 100 then 'd_(30,100]'
                                when coalesce(u.first_day_pay,0) > 100 and coalesce(u.first_day_pay,0) <= 300 then 'e_(100,300]'
                                when coalesce(u.first_day_pay,0) > 300 and coalesce(u.first_day_pay,0) <= 500 then 'f_(300,500]'
                                when coalesce(u.first_day_pay,0) > 500 and coalesce(u.first_day_pay,0) <= 1000 then 'g_(500,1000]'
                                when coalesce(u.first_day_pay,0) > 1000 then 'h_(1000,+)'
                            end pay_level,
                            case
                                when coalesce(u.first_day_pay,0) = 0 then 1
                                when coalesce(u.first_day_pay,0) > 0 and coalesce(u.first_day_pay,0) <= 6 then 2
                                when coalesce(u.first_day_pay,0) > 6 and coalesce(u.first_day_pay,0) <= 30 then 3
                                when coalesce(u.first_day_pay,0) > 30 and coalesce(u.first_day_pay,0) <= 100 then 4
                                when coalesce(u.first_day_pay,0) > 100 and coalesce(u.first_day_pay,0) <= 300 then 5
                                when coalesce(u.first_day_pay,0) > 300 and coalesce(u.first_day_pay,0) <= 500 then 6
                                when coalesce(u.first_day_pay,0) > 500 and coalesce(u.first_day_pay,0) <= 1000 then 7
                                when coalesce(u.first_day_pay,0) > 1000 then 8
                            end pay_sort,
                            t.day_no
                from
                (
                    select      b."$part_date",
                                b."新增日期",
                                b."#account_id",
                                b.create_role_time,
                                coalesce(p.first_day_pay,0) first_day_pay
                    from
                    (
                        select      cast(date("create_role_time") as varchar) "$part_date",
                                    cast(date("create_role_time") as varchar) "新增日期",
                                    cast("#account_id" as varchar) "#account_id",
                                    "create_role_time" create_role_time
                        from        ta.v_user_41
                        where       "domain" = 'release'
                                    and "#account_id" is not null
                    )b
                    left join
                    (
                        select      cast("#account_id" as varchar) "#account_id",
                                    "$part_date",
                                    sum(coalesce(try_cast("payment" as double),0)) / 100.0000 first_day_pay
                        from        ta.v_event_41
                        where       "$part_event" = 'pay_log'
                                    and "domain" = 'release'
                                    and "#account_id" is not null
                        group by    1,2
                    )p
                    on          b."#account_id" = p."#account_id"
                                and b."$part_date" = p."$part_date"
                )u
                cross join unnest(sequence(1,7)) as t(day_no)
                where       u.${PartDate:date}
            )d
            left join
            (
                /* 神器升级：升级后等级取 nlv */
                select      cast("#account_id" as varchar) "#account_id",
                            cast("ins_id" as varchar) ins_id,
                            "#event_time" event_time,
                            "$part_date",
                            coalesce(
                                try_cast("nlv" as double),
                                0
                            ) current_art_level
                from        ta.v_event_41
                where       "$part_event" = 'role_art_uplv_log'
                            and "domain" = 'release'
                            and "#account_id" is not null
                            and "ins_id" is not null

                union all

                /* 神器等级重生：重生后等级直接变为0 */
                select      cast("#account_id" as varchar) "#account_id",
                            cast("ins_id" as varchar) ins_id,
                            "#event_time" event_time,
                            "$part_date",
                            cast(0 as double) current_art_level
                from        ta.v_event_41
                where       "$part_event" = 'role_art_reborn_lv_log'
                            and "domain" = 'release'
                            and "#account_id" is not null
                            and "ins_id" is not null
            )e
            on          d."#account_id" = e."#account_id"
                        and e."$part_date" between d."新增日期"
                        and cast(
                            date_add(
                                'day',
                                d.day_no - 1,
                                cast(d."新增日期" as date)
                            ) as varchar
                        )
                        and e.event_time >= d.create_role_time
                        and e.event_time < cast(
                            date_add(
                                'day',
                                d.day_no,
                                cast(d."新增日期" as date)
                            ) as timestamp
                        )
            group by    1,2,3,4,5,6
        )a
        group by    1,2,3,4,5
    )x
    group by    1,2,3
)q
order by    q.pay_sort,
            q.day_no;
