# 下方了 SQL 口径

- 项目映射：下方了 = `ta.v_user_41` / `ta.v_event_41`。
- `create_role_time` 为 timestamp，创角日期可写：`cast(date("create_role_time") as varchar) "$part_date"`。
- 数数日期筛选规则：不要写 `"$part_date"${PartDate:date}`，也不要写 `u."$part_date"${PartDate:date}`；如果筛选子查询别名字段，写 `u.${PartDate:date}`；如果直接筛选当前查询的 `$part_date`，写 `${PartDate:date}`。
- 首日付费分层必须限定创角当天/active_days=0 的 `pay_log`，不要用查询范围累计付费代替。
- `pay_log.payment` 事件属性单位为分，统计金额和首日付费分层前必须 `/100` 转为元。
- 在线时长统计方法全项目通用：使用 `ta_mg_hide` 事件的 `#duration` 字段，按秒统计；输出分钟时 `/60`。
- 主线最大关卡 ID：使用 `battle_star` 事件，`battle_type = '1'`，取 `max(map_id)`；不要使用 `battle_start`，该事件服务端上报有误。
- `in_out_log` 当前属性为 `change_reason`、`online_time`；不要依赖 `log_type` 字段。次日登录/留存先按次日存在 `in_out_log` 事件判断，或按 `change_reason` 区分登录/登出。
- 英雄获得事件：`role_obtain_log`，英雄字段 `role_id`，但当前实际上报为英雄名；妖狐妲己筛选写 `cast("role_id" as varchar) = '妖狐妲己'`；初始星级字段 `init_star`。
- 英雄升星事件：`role_upstar_log`，英雄字段 `role_id`，但当前实际上报为英雄名；妖狐妲己筛选写 `cast("role_id" as varchar) = '妖狐妲己'`；新星级字段 `nstar`，原星级字段 `ostar`。
- 妖狐妲己配置表种族为 2（火系），同种族狗粮口径使用火系英雄名集合；火系 6 星傀儡道具为 `item_id = 1900026`，名称 `火系6星傀儡`。
- 统计妖狐妲己同种族 6 星英雄狗粮时：`role_upstar_log` 取 `nstar = 6` 的同火系英雄 `ins_id` 去重；当前剩余可用数可用 6 星获取去重数减去 `role_lost_log` 中同批 `ins_id` 去重数。
- `item_log` 道具当前数量优先取同 `#account_id + item_id` 最后一条 `item_result`；如没有事件时间可降级为 `max(item_result)`。
- 新人特惠前 3 档：`pay_log.product_type = '新人特惠'` 且 `product_id in (1,2,3)`。
- SQL 规范：不用 WITH，不用 USING，JOIN 显式写 `ON`，排版模仿用户紧凑风格。
