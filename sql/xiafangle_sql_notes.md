# 下方了 SQL 口径

- 项目映射：下方了 = `ta.v_user_41` / `ta.v_event_41`。
- `create_role_time` 为 timestamp，创角日期可写：`cast(date("create_role_time") as varchar) "$part_date"`。
- 数数日期筛选如果字段来自子查询别名，不要写 `u."$part_date"${PartDate:date}`，会被拼成错误字段；应写 `u.${PartDate:date}`。
- 首日付费分层必须限定创角当天/active_days=0 的 `pay_log`，不要用查询范围累计付费代替。
- `pay_log.payment` 事件属性单位为分，统计金额和首日付费分层前必须 `/100` 转为元。
- `in_out_log` 当前属性为 `change_reason`、`online_time`；不要依赖 `log_type` 字段。次日登录/留存先按次日存在 `in_out_log` 事件判断，或按 `change_reason` 区分登录/登出。
- 英雄获得事件：`role_obtain_log`，英雄字段 `role_id`，初始星级字段 `init_star`。
- 英雄升星事件：`role_upstar_log`，英雄字段 `role_id`，新星级字段 `nstar`，原星级字段 `ostar`。
- 新人特惠前 3 档：`pay_log.product_type = '新人特惠'` 且 `product_id in (1,2,3)`。
- SQL 规范：不用 WITH，不用 USING，JOIN 显式写 `ON`，排版模仿用户紧凑风格。
