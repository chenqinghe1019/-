# 下方了：剔除“内充用户v2”的统一方法

## 适用场景

下方了项目（v41）在用户明确要求剔除“内充用户v2”时，所有新增、活跃、留存、付费、关卡、战斗及其汇总数据，都应先在用户样本层完成剔除，再进入后续事件关联与指标计算。

## 固定口径

- 用户表：`ta.v_user_41`
- 分群结果表：`ta.user_result_cluster_41`
- 分群名称：`cohort_20260705_114557`
- 展示名称：`内充用户v2`
- 关联字段：用户表 `#user_id` = 分群表 `#user_id`
- 不要使用 `#account_id` 直接关联该分群。

## 推荐 SQL 写法

```sql
FROM ta.v_user_41 vu

LEFT JOIN
(
    SELECT DISTINCT
        "#user_id"

    FROM ta.user_result_cluster_41

    WHERE cluster_name = 'cohort_20260705_114557'
      AND "#user_id" IS NOT NULL
) internal_user
    ON internal_user."#user_id" = vu."#user_id"

WHERE vu."domain" = 'release'
  AND vu."#account_id" IS NOT NULL
  AND vu."#user_id" IS NOT NULL
  AND internal_user."#user_id" IS NULL
```

## 使用原则

1. 排除逻辑应放在最前面的用户样本层，而不是只在某个事件子查询中剔除。
2. 多个固定新增区间、手动新增日期区间以及汇总层，必须共用同一套已剔除用户样本。
3. 分群表中同一 `#user_id` 可能重复，子查询必须使用 `SELECT DISTINCT`，避免把用户样本重复放大。
4. 后续关联付费和战斗事件时仍使用 `#account_id`；`#user_id` 只用于识别并排除内充用户。
5. 使用 `LEFT JOIN ... IS NULL` 方式，避免 `NOT IN` 遇到空值后导致结果异常。
6. 除非用户明确要求把它设为所有 SQL 的默认过滤条件，否则仅在要求剔除“内充用户v2”的分析中启用。

## 记录日期

2026-08-03
