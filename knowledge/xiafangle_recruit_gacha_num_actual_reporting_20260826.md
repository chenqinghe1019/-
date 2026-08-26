# 下方了：recruit_log gacha_num 字段层级说明（2026-08-26）

## 结论
- `recruit_log` 存在顶层事件属性 `gacha_num`，该字段才是后续抽数统计使用的字段。
- `award_ting` 的 row 结构中也存在一个同名子字段 `gacha_num`，但已验证线上抽样中 `award_ting.gacha_num` 为 NULL。
- 因此必须区分两者：真实抽数使用顶层 `recruit_log.gacha_num`，不要使用 `award_ting.gacha_num`。

## 已验证样例
- `award_ting.type=2` 为英雄，`award_ting.type=3` 可为异能魂晶等非英雄奖励。
- 2026-08-02~2026-08-25 抽样中，拆出的 236650 条 `award_ting` 奖励明细里，子字段 `award_ting.gacha_num` 非空行数为 0。
- 该验证只能说明数组子字段为空，不能据此判断顶层 `recruit_log.gacha_num` 为空。

## SQL 使用注意
- 顶层字段写法：`e."gacha_num"`。
- 顶层 `gacha_num` 应在 `cross join unnest(e."award_ting")` 之前保留。
- 若拆数组后直接 `sum(e.gacha_num)`，同一 recruit_log 会因多个奖励元素被重复计算。
- 卡池经验及“平均多少抽产出1张”均应使用顶层 `recruit_log.gacha_num`。
- 不要用 `count(*)`、`cardinality(award_ting)` 或奖励元素数量替代真实抽数。
