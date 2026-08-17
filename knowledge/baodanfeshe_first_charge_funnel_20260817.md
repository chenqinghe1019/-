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
- 首充分子判断采用直接存在/不存在逻辑，不再使用 `max_by`：
  1. 首充购买前必须已经出现 `map_id=10003` 的 `battle_result`；
  2. 首充购买前不能出现任何 `map_id=20001` 的 `battle_start` 或 `battle_result`。
- 因此：1-3结算后直接购买计入；1-3结算后若已出现2-1开始或2-1结算再购买则不计入。
- 不使用 `battle_type=1` 作为过滤条件，避免因实际编码差异导致分子丢失。
- 首充人数：上述玩家按 `nb_open_id` 去重人数。
- 首充付费率：`购买前已结算1-3且未开始/结算2-1的product_id=42购买人数 / 1-3结算人数`。
- 分母1-3结算人数仍使用新增首日 `map_id=10003` 的 `battle_result` 去重玩家数。

## SQL 接入建议

单独构建玩家级 `t_3`：先取每个玩家当日首笔 `product_id=42` 的购买时间；再 INNER JOIN 购买前的1-3 `battle_result` 以确认已结算1-3；再 LEFT JOIN 购买前的2-1 `battle_start`/`battle_result`，仅保留2-1匹配为空的玩家。随后按新增首日与主查询关联，外层按 `nb_open_id` 去重统计人数并除以1-3结算人数。
