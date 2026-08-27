# 暴弹飞射：新增首日关卡漏斗与新人特惠6元口径

## 项目与基础口径
- 项目：暴弹飞射（`ta.v_event_42` / `ta.v_user_42`）。
- 正式服：`domain='release'`。
- 新增账号口径：按 `nb_open_id` 去重，新增日取该 `nb_open_id` 最早创角日期。
- `create_role_time` 历史仓库类型按 Unix 秒兼容：`from_unixtime(try_cast(create_role_time AS double))`。
- 战斗开始：`battle_start`；战斗结算：`battle_result`。
- 付费：`pay_log AND payment>0`，`payment` 单位为元，不除以100。

## 与下方了统一的新增首日指标
按新增时间、媒体平台输出：
- 新增、首日付费、次留。
- 1-1~3-3 每关的战斗开始人数、战斗结算人数及各自 / 新增人数的漏斗率。
- 整体首日付费率 = 首日付费人数 / 新增人数。
- 次留率 = D2登录人数 / 新增人数。

暴弹关卡映射：
- 1-1=`10001`，1-2=`10002`，1-3=`10003`
- 2-1=`20001`，2-2=`20002`，2-3=`20003`
- 3-1=`30001`，3-2=`30002`，3-3=`30003`

## 新人特惠6元
- **最新商品ID：`product_id=40001`**。此前知识中的 `product_id=42` 已废弃，由本口径覆盖。
- 购买判定：`$part_event='pay_log' AND try_cast(product_id AS bigint)=40001 AND payment>0`。
- 购买时间：取玩家新增首日首笔 `product_id=40001` 的 `#event_time`。
- 计入“首充前最后主线为1-3人数”的条件：
  1. 购买前已出现 `map_id=10003` 的 `battle_result`；
  2. 购买前未出现 `map_id=20001` 的 `battle_start` 或 `battle_result`。
- 新人特惠6元首充付费率 = 上述人数 / 新增首日1-3战斗结算人数。
- 该分子按 `nb_open_id` 去重。

## SQL实现注意
- 事件表的战斗 map 判断统一 `try_cast(map_id AS bigint)`。
- 商品ID统一 `try_cast(product_id AS bigint)`，避免 double 转 varchar 出现 `40001.0`。
- 非战斗事件不要额外要求 `map_id IS NULL`，避免误过滤登录/付费事件。
- 1-3新人特惠逻辑不额外依赖 `battle_type`，直接使用明确的 `map_id` + 事件名判断。
