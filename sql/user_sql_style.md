# 用户 SQL 写法风格

本文件记录用户在倍特工作室项目中偏好的 SQL 写法。后续写 TrinoSQL、数数看板 SQL、项目分析 SQL 时优先遵守本文件。

## 总体原则

- 优先给最终完整 SQL，不只给片段。
- 默认 TrinoSQL。
- 不用 `WITH` / CTE。
- 不用 `USING`。
- 不写过度抽象、过度套娃的通用模板。
- 不为了“简化”改变用户原有口径骨架；如果用户给了可参考 SQL，应基于该 SQL 改造。
- 排查和改造 SQL 时优先保持原 SQL 的别名、字段、子查询结构和展示顺序。

## 排版风格

- SQL 关键字尽量使用小写：`select`、`from`、`where`、`left join`、`group by`、`order by`。
- 字段按列纵向排布，不挤成一行。
- `select` 后字段对齐，别名直接跟在表达式后，例如：

```sql
select      row_number() over(order by q."首日付费分层",q."最终停留主线关卡ID",q.pass_sort) "序号",
            q."首日付费分层",
            q."最终停留主线关卡ID"
```

- `from`、`where`、`group by`、`order by` 保持用户常用的宽空格对齐风格，例如：

```sql
from        ta.v_event_41
where       "$part_event" = 'pay_log'
            and "#account_id" is not null
group by    1,2
```

- 子查询别名可保持用户写法：`)u`、`)pay`、`)ms`、`)br`、`)q`，不要强行改成完全不同的命名体系。

## 常用 SQL 结构

分布类需求优先使用用户常见骨架：

```text
最外层 q：负责 row_number、展示字段、占比、排序
  d：维度全集，例如 付费分层 × map_id
  s：状态全集，例如 未通过 / 已通过
  a：事实统计结果，例如 人数、次数、金额
  d cross join s left join a：保证每个维度都有状态补全，0 人也展示
```

这种结构尤其适用于：

- 每个 `map_id` 都要有“未通过 / 已通过”两行。
- 某个状态没有玩家也要展示 0。
- 最外层要算分层内占比、整体占比。

不要把这类需求简化成只按实际事实表聚合，否则缺失状态行。

## 人群与事实拆分

优先按下面顺序写：

1. 先固定目标人群，例如新增用户、人群日期、账号 ID。
2. 左连首日付费，得到 `pay_level`。
3. 左连行为事实汇总，例如最大关卡、是否通过、战力、留存、付费。
4. 最外层按展示维度聚合。

不要重复造太多次同一批用户；如果必须重复，为了保持用户原 SQL 骨架，可以重复，但不要无意义增加层级。

## 数数动态日期参数

- `${PartDate:date}` / `${PartDate:date1}` 本身会展开成 `"$part_date" between ...`。
- 禁止写：`"$part_date"${PartDate:date}`。
- 禁止写：`u."$part_date"${PartDate:date}`。
- 如果筛选项是新增日期，用户常用写法是先在新增用户子查询里生成：

```sql
cast(date("create_role_time") as varchar) "$part_date"
```

然后在外层使用：

```sql
where       u.${PartDate:date}
```

- 事件表不要直接套新增日期筛选项。首日事件通过：

```sql
u."#account_id" = e."#account_id"
and u."$part_date" = e."$part_date"
```

或同等写法限定。

## 下方了 v41 常用口径

- 用户表：`ta.v_user_41`。
- 事件表：`ta.v_event_41`。
- 正式环境需要加：`"domain" = 'release'`。
- 新增日期来自：`date("create_role_time")`。
- 账号字段常用：`cast("#account_id" as varchar) "#account_id"`。
- 首日付费分层使用 `pay_log` 的 `"payment" / 100.0000`，并带上：

```sql
coalesce(try_cast("pay_result" as double),1) = 1
```

- 不要把首日付费误写成 `total_payment`，除非用户明确指定。

## 下方了抽卡 recruit_log 口径

- 事件：`recruit_log`。
- 抽卡类型：`gacha_type = 2` 为高级招募，`gacha_type = 3` 为种族招募。
- 抽卡次数不要按日志条数统计。
- `award_ting` 在 Trino 中是 `array(row(star double, num double, id varchar, "type" double))`，不是 JSON 字符串，不能 `cast(award_ting as varchar)` 后 `json_parse`。
- 抽卡次数按 `award_ting` 数组长度统计：

```sql
coalesce(cardinality(e."award_ting"),0)
```

- 拆分高级招募、种族招募时使用：

```sql
sum(case when e."$part_event" = 'recruit_log' and try_cast(e."gacha_type" as double) = 2 then coalesce(cardinality(e."award_ting"),0) else 0 end) high_gacha_times,
sum(case when e."$part_event" = 'recruit_log' and try_cast(e."gacha_type" as double) = 3 then coalesce(cardinality(e."award_ting"),0) else 0 end) race_gacha_times
```

## 下方了首日主线关卡停留口径

最终停留主线关卡 ID：

- 合并 `battle_star` 和 `battle_result`。
- 主线条件：`try_cast("battle_type" as double) = 1`。
- 关卡字段：`try_cast("map_id" as double) map_id`。
- 每人每天取 `max(map_id)`。
- 无主线记录记为 `0`。

示例骨架：

```sql
select      m."#account_id",
            m."$part_date",
            max(m.map_id) max_mainline_map_id
from
(
    select      cast("#account_id" as varchar) "#account_id",
                "$part_date",
                try_cast("map_id" as double) map_id
    from        ta.v_event_41
    where       "$part_event" = 'battle_star'
                and try_cast("battle_type" as double) = 1
                and "#account_id" is not null

    union all

    select      cast("#account_id" as varchar) "#account_id",
                "$part_date",
                try_cast("map_id" as double) map_id
    from        ta.v_event_41
    where       "$part_event" = 'battle_result'
                and try_cast("battle_type" as double) = 1
                and "#account_id" is not null
)m
where       m.map_id is not null
group by    1,2
```

## 下方了最终停留关卡是否通过口径

- 先取玩家最终停留关卡 `max_mainline_map_id`。
- 再用该关卡的 `battle_result` 判断是否通过。
- `battle_result = 0` 记为未通过。
- 没有 `battle_result` 默认视为已通过。
- 用户常用写法：

```sql
select      cast("#account_id" as varchar) "#account_id",
            "$part_date",
            try_cast("map_id" as double) map_id,
            min(case when try_cast("battle_result" as double) = 0 then 0 else 1 end) is_pass
from        ta.v_event_41
where       "$part_event" = 'battle_result'
            and try_cast("battle_type" as double) = 1
            and "#account_id" is not null
group by    1,2,3
```

然后：

```sql
case when coalesce(br.is_pass,1) = 1 then '已通过'
     else '未通过' end pass_name
```

## 付费分层固定写法

```sql
case
    when coalesce(pay.first_day_pay,0) = 0 then 'a_free'
    when coalesce(pay.first_day_pay,0) > 0 and coalesce(pay.first_day_pay,0) <= 6 then 'b_(0,6]'
    when coalesce(pay.first_day_pay,0) > 6 and coalesce(pay.first_day_pay,0) <= 30 then 'c_(6,30]'
    when coalesce(pay.first_day_pay,0) > 30 and coalesce(pay.first_day_pay,0) <= 100 then 'd_(30,100]'
    when coalesce(pay.first_day_pay,0) > 100 and coalesce(pay.first_day_pay,0) <= 300 then 'e_(100,300]'
    when coalesce(pay.first_day_pay,0) > 300 and coalesce(pay.first_day_pay,0) <= 500 then 'f_(300,500]'
    when coalesce(pay.first_day_pay,0) > 500 and coalesce(pay.first_day_pay,0) <= 1000 then 'g_(500,1000]'
    when coalesce(pay.first_day_pay,0) > 1000 then 'h_(1000,+)'
end pay_level
```

## 输出要求

- 展示列使用中文，例如 `"首日付费分层"`、`"最终停留主线关卡ID"`、`"最终停留关卡是否通过"`。
- 需要排序时保留内层辅助字段，例如 `pass_sort`，最外层可以不展示。
- 占比通常保留 4 位小数，不自动转百分比。
- 分布类结果优先输出：序号、维度、人数、分层内占比、整体占比。
- 若用户上传 SQL，必须优先基于上传 SQL 改造，不要重写成另一种结构。
