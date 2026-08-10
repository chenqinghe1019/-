-- 下方了 v41：新增角色后7日每日神器总等级
-- 口径：
-- 1. D1=创角当天，D7=创角后第6个自然日。
-- 2. role_art_uplv_log：按 ins_id 记录神器升级，升级后当前等级取 nlv。
-- 3. role_art_reborn_lv_log：与升级流水按 ins_id 连续处理；发生等级重生后当前等级记为 0。
-- 4. 每个自然日日末，按 #account_id + ins_id 取截至当日日末最后一条状态，再对该角色所有 ins_id 求和。
-- 5. 当天没有新的神器事件时，沿用此前最后状态；没有任何神器升级/重生记录的角色总等级为0。

select      row_number() over(
                order by q."新增日期",
                         q."#account_id",
                         q.day_no
            ) "序号",
            q."新增日期",
            q."#account_id",
            'D' || cast(q.day_no as varchar) "新增后第N日",
            round(q.total_art_level,2) "神器总等级"
from
(
    select      x."新增日期",
                x."#account_id",
                x.day_no,
                sum(coalesce(x.current_art_level,0)) total_art_level
    from
    (
        select      d."新增日期",
                    d."#account_id",
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
                        t.day_no
            from
            (
                select      cast(date("create_role_time") as varchar) "$part_date",
                            cast(date("create_role_time") as varchar) "新增日期",
                            cast("#account_id" as varchar) "#account_id",
                            "create_role_time" create_role_time
                from        ta.v_user_41
                where       "domain" = 'release'
                            and "#account_id" is not null
            )u
            cross join unnest(sequence(1,7)) as t(day_no)
            where       u.${PartDate:date}
        )d
        left join
        (
            select      cast("#account_id" as varchar) "#account_id",
                        cast("ins_id" as varchar) ins_id,
                        "#event_time" event_time,
                        "$part_date",
                        coalesce(try_cast("nlv" as double),0) current_art_level
            from        ta.v_event_41
            where       "$part_event" = 'role_art_uplv_log'
                        and "domain" = 'release'
                        and "#account_id" is not null
                        and "ins_id" is not null

            union all

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
                    and cast(date_add('day',6,cast(d."新增日期" as date)) as varchar)
                    and e.event_time >= d.create_role_time
                    and e.event_time < cast(
                        date_add(
                            'day',
                            d.day_no,
                            cast(d."新增日期" as date)
                        ) as timestamp
                    )
        group by    1,2,3,4
    )x
    group by    1,2,3
)q
order by    q."新增日期",
            q."#account_id",
            q.day_no;
