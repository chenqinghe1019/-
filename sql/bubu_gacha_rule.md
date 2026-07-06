# 步步项目抽卡统计口径

适用项目：步步项目。

## 表

- 用户表：`ta.v_user_22`
- 事件表：`ta.v_event_22`

## 抽卡事件

- 事件名：`recruit`
- 抽卡类型字段：`change_reason`
- 心愿招募：`change_reason = 1`
- 种族许愿：`change_reason in (1000, 1100, 1200, 1300)`

## 抽卡次数

抽卡次数不要按日志条数统计，应按 `award_ting` 数组长度统计：

```sql
coalesce(cardinality(e."award_ting"),0)
```

## 常用写法

```sql
sum(
    case
        when e."$part_event" = 'recruit'
             and try_cast(e."change_reason" as double) = 1
        then coalesce(cardinality(e."award_ting"),0)
        else 0
    end
) as wish_gacha_times,

sum(
    case
        when e."$part_event" = 'recruit'
             and try_cast(e."change_reason" as double) in (1000,1100,1200,1300)
        then coalesce(cardinality(e."award_ting"),0)
        else 0
    end
) as race_wish_times
```
