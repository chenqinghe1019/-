# 步步项目 v22 SQL 口径

- 项目映射：步步项目 = v22。
- 事件表：`ta.v_event_22`。
- 用户表：`ta.v_user_22`。
- 登录/登出事件：`log_in_out`。
- 主账号维度：`#account_id` / `account_id`。
- `total_payment` 口径：步步项目 v22 的 `total_payment` 已经是元，不需要 `/100`。
- 输出累计付费时：`round(COALESCE(total_payment, 0), 2)`，不要写 `total_payment / 100`。
- Trino/数数 SQL 规范：不用 WITH；尽量不用 USING，除非用户明确接受极简临时查询；字段名加双引号。
- SQL 排版偏好：模仿用户写法，整体紧凑，select/from/where/group by 缩进对齐，子查询闭合后直接接 join/别名，少空行，不要过度拆成很多层级和大段注释。
