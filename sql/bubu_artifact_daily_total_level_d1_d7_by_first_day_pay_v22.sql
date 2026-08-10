-- 步步项目 v22：新增角色后7日每日神器总等级，按首日付费分层
-- 口径：
-- 1. 固定使用 ta.v_user_22 / ta.v_event_22；步步 v21/v2 已作废。
-- 2. 用户范围：仅限制 domain='release'，不限制 area / merge_region_id。
-- 3. ta.v_user_22.create_role_time 实际为 double Unix 秒，必须先 from_unixtime()。
-- 4. 首日付费：创角自然日 pay_log.payment 合计 /100 转元，再按固定档位分层。
-- 5. 步步神器养成事件使用 artifact；hero_uid 为神器实例，level 作为该次事件后的当前等级。
-- 6. D1=创角当天，D7=创角后第6个自然日；每日日末按 #account_id + hero_uid 取最后一条 artifact.level，再对角色所有 hero_uid 求和。
-- 7. 若神器重生同样通过 artifact 上报且重生后 level=0，则该状态会自动覆盖此前等级；当前 GitHub 埋点未记录独立神器等级重生事件。

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
                        e.hero_uid,
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
                                when coalesce(u.first_day_pay,0) <= 6 then 'b_(0,6]'
                                when coalesce(u.first_day_pay,0) <= 30 then 'c_(6,30]'
                                when coalesce(u.first_day_pay,0) <= 100 then 'd_(30,100]'
                                when coalesce(u.first_day_pay,0) <= 300 then 'e_(100,300]'
                                when coalesce(u.first_day_pay,0) <= 500 then 'f_(300,500]'
                                when coalesce(u.first_day_pay,0) <= 1000 then 'g_(500,1000]'
                                else 'h_(1000,+)'
                            end pay_level,
                            case
                                when coalesce(u.first_day_pay,0) = 0 then 1
                                when coalesce(u.first_day_pay,0) <= 6 then 2
                                when coalesce(u.first_day_pay,0) <= 30 then 3
                                when coalesce(u.first_day_pay,0) <= 100 then 4
                                when coalesce(u.first_day_pay,0) <= 300 then 5
                                when coalesce(u.first_day_pay,0) <= 500 then 6
                                when coalesce(u.first_day_pay,0) <= 1000 then 7
                                else 8
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
                        select      cast(date(from_unixtime(try_cast("create_role_time" as double))) as varchar) "$part_date",
                                    cast(date(from_unixtime(try_cast("create_role_time" as double))) as varchar) "新增日期",
                                    cast("#account_id" as varchar) "#account_id",
                                    from_unixtime(try_cast("create_role_time" as double)) create_role_time
                        from        ta.v_user_22
                        where       "domain" = 'release'
                                    and "#account_id" is not null
                                    and try_cast("create_role_time" as double) is not null
                    )b
                    left join
                    (
                        select      cast("#account_id" as varchar) "#account_id",
                                    "$part_date",
                                    sum(
                                        coalesce(
                                            try_cast("payment" as double),
                                            0
                                        )
                                    ) / 100.0000 first_day_pay
                        from        ta.v_event_22
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
                select      cast("#account_id" as varchar) "#account_id",
                            cast("hero_uid" as varchar) hero_uid,
                            "#event_time" event_time,
                            "$part_date",
                            coalesce(
                                try_cast("level" as double),
                                0
                            ) current_art_level
                from        ta.v_event_22
                where       "$part_event" = 'artifact'
                            and "domain" = 'release'
                            and "#account_id" is not null
                            and "hero_uid" is not null
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
