# 下方了 SQL 口径

- 项目映射：下方了 = `ta.v_user_41` / `ta.v_event_41`。
- `create_role_time` 为 timestamp，创角日期可写：`cast(date("create_role_time") as varchar) "$part_date"`。
- 数数日期筛选规则：不要写 `"$part_date"${PartDate:date}`，也不要写 `u."$part_date"${PartDate:date}`；如果筛选子查询别名字段，写 `u.${PartDate:date}`；如果直接筛选当前查询的 `$part_date`，写 `${PartDate:date}`。
- 首日付费分层必须限定创角当天/active_days=0 的 `pay_log`，不要用查询范围累计付费代替。
- `pay_log.payment` 事件属性单位为分，统计金额和首日付费分层前必须 `/100` 转为元。
- 在线时长统计方法全项目通用：使用 `ta_app_end` 事件的 `#duration` 字段，按秒统计；输出分钟时 `/60`。
- `in_out_log` 当前属性为 `change_reason`、`online_time`；不要依赖 `log_type` 字段。次日登录/留存先按次日存在 `in_out_log` 事件判断，或按 `change_reason` 区分登录/登出。
- 英雄获得事件：`role_obtain_log`，英雄字段 `role_id`，但当前实际上报为英雄名；妖狐妲己筛选写 `cast("role_id" as varchar) = '妖狐妲己'`；初始星级字段 `init_star`。
- 英雄升星事件：`role_upstar_log`，英雄字段 `role_id`，但当前实际上报为英雄名；妖狐妲己筛选写 `cast("role_id" as varchar) = '妖狐妲己'`；新星级字段 `nstar`，原星级字段 `ostar`。
- 新人特惠前 3 档：`pay_log.product_type = '新人特惠'` 且 `product_id in (1,2,3)`。
- SQL 规范：不用 WITH，不用 USING，JOIN 显式写 `ON`，排版模仿用户紧凑风格。
