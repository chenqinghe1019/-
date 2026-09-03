# 弯月英雄上阵率 + 最高星级口径（v44 历史 SQL）

> 日期：2026-09-03
> 说明：该口径针对用户现有 `ta.v_event_44` SQL，不替代 `memory/projects/弯月勇者埋点口径.md` 中 v46 的正式埋点字典。

## 当前口径
- 英雄名称映射表：`ta_ext.hero_44`。
  - 关联键：战斗阵容 `battle_array` 拆出的 `roleid` = `ta_ext.hero_44.hero_id`。
  - 输出字段：`hero_name`。
- 英雄初始/获得星级来源：`hero_get_log.star`。
- 英雄升星后星级来源：`hero_star_up_log.star_after`。
- “最高星级”不再根据 `hero_quality` 人工映射默认星级。
- “最高星级”统计方式：
  1. 将 `hero_get_log.star` 与 `hero_star_up_log.star_after` 合并为同一星级流水；
  2. 对同一玩家、同一英雄，只使用截至当前统计日当天及以前的记录；
  3. 取这些记录中的最大星级；
  4. 在当前上阵率结果的 `D7_total_payment_R + days + roleid` 粒度下，再取该组的最高星级。
- 该方式保证：未升星英雄可以由 `hero_get_log.star` 得到初始星级；已升星英雄由更高的 `star_after` 覆盖。

## 时间口径
- `hero_get_log` 与 `hero_star_up_log` 均不能只套当前战斗日的 `${PartDate:date1}`，需要保留统计日以前的历史记录，再通过 `事件日期 <= 当前统计日` 约束，避免 D1/D2 被未来升星结果污染。

## 注意
- 当前 v44 SQL 中 `D7_total_payment_R` 的原始计算逻辑本次不改动；若后续需要严格“7日累计充值”口径，应单独重构为账号级 D0~D6 累计后再分层。
