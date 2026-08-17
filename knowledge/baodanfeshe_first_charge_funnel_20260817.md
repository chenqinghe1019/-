# 暴弹飞射：首充付费率口径（2026-08-17）

## 口径

用于新增首日关卡漏斗中的首充转化分析。

- 项目：暴弹飞射（`ta.v_event_42` / `ta.v_user_42`）
- 新增首日：`date($part_date) = date(openid_create_role)`
- 1-3：`map_id = 10003`
- 2-1：`map_id = 20001`
- 首充商品：`pay_log.product_id = 42`
- 购买判定：`$part_event='pay_log' AND product_id=42 AND payment>0`
- 首充购买时间：取玩家新增首日首笔 `product_id=42` 的 `#event_time`。
- 首充分子判断：以首充购买时间为锚点，向前查找主线相关的 `battle_start` 和 `battle_result`，按 `#event_time` 取购买前最后一条关卡事件；其 `map_id=10003` 时计入分子。
- 2-1开始和2-1结算都属于进度越过1-3的信号：只要购买前出现 `map_id=20001` 的 `battle_start` 或 `battle_result`，该玩家不计入1-3阶段首充分子。
- 不使用 `battle_type=1` 作为主线过滤条件，避免因暴弹实际 battle_type 编码不同导致分子为0；以明确的主线 `map_id` 范围判断。
- 首充人数：上述玩家按 `nb_open_id` 去重人数。
- 首充付费率：`购买前最后主线开始/结算关卡为1-3的product_id=42购买人数 / 1-3结算人数`。
- 分母1-3结算人数仍使用新增首日 `map_id=10003` 的 `battle_result` 去重玩家数。

## SQL 接入建议

单独构建玩家级 `t_3`：先取每个玩家当日首笔 `product_id=42` 的购买时间，再关联购买之前的 `battle_start`/`battle_result`，仅保留主线关卡 map_id（当前漏斗至少包含 `10001,10002,10003,20001,20002,20003`，如主线范围更完整可继续补充），通过 `max_by(map_id,#event_time)` 取购买前最后一条主线关卡事件，仅保留 `map_id=10003` 的玩家。随后按新增首日与主查询关联，外层按 `nb_open_id` 去重统计人数并除以1-3结算人数。
