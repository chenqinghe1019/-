# 暴弹飞射：首充付费率口径（2026-08-17）

## 口径

用于新增首日关卡漏斗中的首充转化分析。

- 项目：暴弹飞射（`ta.v_event_42` / `ta.v_user_42`）
- 新增首日：`date($part_date) = date(openid_create_role)`
- 1-3：`map_id = 10003`
- 首充商品：`pay_log.product_id = 42`
- 购买判定：`$part_event='pay_log' AND product_id=42 AND payment>0`
- 首充购买时间：取玩家新增首日首笔 `product_id=42` 的 `#event_time`
- 首充玩家：以首充购买时间为锚点，向前查找购买前最近一次主线 `battle_result`；若该次结算 `map_id=10003`，则计入首充分子。
- 不再使用“首次2-1 battle_start之前购买”作为边界；玩家未进入2-1，或已经开始2-1但尚未产生2-1主线结算时购买，只要购买前最近主线结算仍为1-3，都应计入分子。
- 首充人数：上述玩家按 `nb_open_id` 去重人数。
- 首充付费率：`购买前最后主线关卡为1-3的product_id=42购买人数 / 1-3结算人数`。
- 当前漏斗分母中的1-3结算人数使用 `map_id=10003` 的 `battle_result` 去重玩家数。

## SQL 接入建议

单独构建玩家级 `t_3`：先取每个玩家新增首日首笔 `product_id=42` 的购买时间，再关联早于购买时间的主线 `battle_result`，通过 `max_by(map_id, #event_time)` 或按 `#event_time` 倒序排名取购买前最后一次主线结算；仅保留最后主线 `map_id=10003` 的玩家。随后按新增首日与主查询 `t_1` 关联，外层按 `nb_open_id` 去重统计人数，并除以现有1-3战斗结算人数。
