# 弯月英雄上阵率 + 最高星级口径（v44 历史 SQL）

> 日期：2026-09-03
> 说明：该口径针对用户现有 `ta.v_event_44` SQL，不替代 `memory/projects/弯月勇者埋点口径.md` 中 v46 的正式埋点字典。

## 本次新增口径
- 英雄名称与初始品质映射表：`ta_ext.hero_44`。
  - 关联键：战斗阵容 `battle_array` 拆出的 `roleid` = `ta_ext.hero_44.hero_id`。
  - 输出/使用字段：`hero_name`、`hero_quality`。
- 英雄星级事件：`hero_star_up_log`。
  - 英雄 ID：`hero_id`。
  - 升星前：`star_before`。
  - 升星后：`star_after`。
- “最高星级”统计：对同一玩家、同一英雄，取截至当前统计日的 `star_after` 最大值；再在 `D7_total_payment_R + days + roleid` 分组内取最大值。
- 时间口径：只允许使用统计日当天及以前的升星记录，避免 D1/D2 等历史行被未来升星结果污染。
- 未发生过 `hero_star_up_log` 的英雄，根据 `ta_ext.hero_44.hero_quality` 赋默认初始星级：
  - `橙` = 5 星
  - `橙+` = 5 星
  - `紫` = 4 星
  - `蓝` = 3 星
  - `绿` = 2 星
- SQL 实现：`coalesce(升星最高star_after, CASE hero_quality ... END)`。

## 注意
- `hero_star_up_log` 不建议直接套 `${PartDate:date1}`，否则如果筛选的是较晚统计日，会丢失统计日前更早发生的升星记录。
- 当前 v44 SQL 中 `D7_total_payment_R` 的原始计算逻辑本次不改动；若后续需要严格“7日累计充值”口径，应单独重构为账号级 D0~D6 累计后再分层。
