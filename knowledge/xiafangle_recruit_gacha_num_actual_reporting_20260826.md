# 下方了：recruit_log gacha_num 实际上报情况（2026-08-26）

## 结论
- `recruit_log.award_ting` 的类型结构包含 `gacha_num` 字段，但线上抽样数据中该字段实际为 `NULL`。
- 因此当前不能使用 `award_ting.gacha_num` 直接统计真实抽卡次数，也不能用于“平均多少抽产出1张”的分子。
- 后续若需要真实抽数，应先确认服务端是否补充上报 `gacha_num`，或使用其他已验证的抽数来源。

## 已验证样例
- `award_ting` 中 `type=2` 为英雄，`type=3` 可为异能魂晶等非英雄奖励。
- 抽样结果中同一 `recruit_log` 事件拆出的各奖励行 `gacha_num` 均为 NULL。

## 注意
- 不要把 `count(*)`、`cardinality(award_ting)` 或奖励元素数量直接等同为真实抽数，除非业务侧另行确认。
