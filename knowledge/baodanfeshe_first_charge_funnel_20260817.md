# 暴弹飞射：首充付费率口径（2026-08-17）

## 口径

用于新增首日关卡漏斗中的首充转化分析。

- 项目：暴弹飞射（`ta.v_event_42` / `ta.v_user_42`）
- 新增首日：`date($part_date) = date(openid_create_role)`
- 2-1：`map_id = 20001`
- 首充商品：`pay_log.product_id = 42`
- 首充玩家：新增首日、首次 `2-1 battle_start` 之前购买 `product_id=42` 的玩家
- 购买判定：`$part_event='pay_log' AND product_id=42 AND payment>0`
- 首充人数：上述玩家去重人数
- 首充付费率：`2-1开始前首充人数 / 1-3结算人数`
- 当前漏斗口径中，1-3结算人数使用 `map_id=10003` 的 `battle_result` 去重玩家数

## SQL 接入建议

单独构建玩家级 `t_3`：按 `#account_id + $part_date` 标记是否在当日首次 2-1 开始前购买 product_id=42，再按新增首日与主查询 `t_1` 关联。外层按 `nb_open_id` 去重统计首充人数，并除以现有 1-3 战斗结算人数。
