-- 下方了 v41：新增角色后7日每日神器总等级（两步排查版）
--
-- 第一步：检查 role_art_uplv_log + role_art_reborn_lv_log 是否按 #account_id + ins_id 连续。
-- 升级后等级取 nlv；等级重生后状态等级直接记为0。
--
-- 第二步：按 D1~D7 每个自然日日末，取每个 #account_id + ins_id 截至当日日末最后状态，
-- 再汇总到角色神器总等级，最终按所选新增时间段聚合展示人均神器总等级。

/* ============================================================
   第一步：神器升级/重生连续事件明细
   ============================================================ */
select      row_number() over(
                order by q."#account_id",
                         q.ins_id,
                         q.event_time,
                         q.event_sort
            ) "序号",
            q."新增日期",
            q."#account_id",
            q.ins_id "神器实例ID",
            q.role_id "神器ID",
            'D' || cast(q.day_no as varchar) "新增后第N日",
            q.event_time "事件时间",
            q.event_name "事件类型",
            q.old_level "事件前等级",
            q.new_level "事件后等级"
from
(
    select      u."新增日期",
                u."#account_id",
                e.ins_id,
                e.role_id,
                date_diff(
                    'day',
                    cast(u."新增日期" as date),
                    date(e.event_time)
                ) + 1 day_no,
                e.event_time,
                e.event_name,
                e.old_level,
                e.new_level,
                e.event_sort
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
    inner join
    (
        select      cast("#account_id" as varchar) "#account_id",
                    cast("ins_id" as varchar) ins_id,
                    cast("role_id" as varchar) role_id,
                    "#event_time" event_time,
                    "$part_date",
                    '升级' event_name,
                    try_cast("olv" as double) old_level,
                    try_cast("nlv" as double) new_level,
                    1 event_sort
        from        ta.v_event_41
        where       "$part_event" = 'role_art_uplv_log'
                    and "domain" = 'release'
                    and "#account_id" is not null
                    and "ins_id" is not null

        union all

        select      cast("#account_id" as varchar) "#account_id",
                    cast("ins_id" as varchar) ins_id,
                    cast("role_id" as varchar) role_id,
                    "#event_time" event_time,
                    "$part_date",
                    '等级重生' event_name,
                    try_cast("lv" as double) old_level,
                    cast(0 as double) new_level,
                    2 event_sort
        from        ta.v_event_41
        where       "$part_event" = 'role_art_reborn_lv_log'
                    and "domain" = 'release'
                    and "#account_id" is not null
                    and "ins_id" is not null
    )e
    on          u."#account_id" = e."#account_id"
                and e.event_time >= u.create_role_time
                and e.event_time < cast(
                    date_add(
                        'day',
                        7,
                        cast(u."新增日期" as date)
                    ) as timestamp
                )
                and e."$part_date" between u."新增日期"
                and cast(
                    date_add(
                        'day',
                        6,
                        cast(u."新增日期" as date)
                    ) as varchar
                )
    where       u.${PartDate:date}
)q
where       q.day_no between 1 and 7
order by    q."#account_id",
            q.ins_id,
            q.event_time,
            q.event_sort;


/* ============================================================
   第二步：D1~D7 汇总结果
   输出：新增时间段、新增后第N日、新增角色数、神器总等级合计、人均神器总等级
   ============================================================ */
select      row_number() over(order by q.day_no) "序号",
            case
                when q.min_create_date = q.max_create_date then q.min_create_date
                else q.min_create_date || '~' || q.max_create_date
            end "新增日期",
            'D' || cast(q.day_no as varchar) "新增后第N日",
            q.role_cnt "新增角色数",
            round(q.total_art_level,2) "神器总等级合计",
            round(q.avg_art_level,2) "人均神器总等级"
from
(
    select      x.day_no,
                min(x."新增日期") min_create_date,
                max(x."新增日期") max_create_date,
                count(distinct x."#account_id") role_cnt,
                sum(x.total_art_level) total_art_level,
                avg(x.total_art_level) avg_art_level
    from
    (
        select      a."新增日期",
                    a."#account_id",
                    a.day_no,
                    sum(coalesce(a.current_art_level,0)) total_art_level
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
            group by    1,2,3,4
        )a
        group by    1,2,3
    )x
    group by    1
)q
order by    q.day_no;
