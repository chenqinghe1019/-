# 下方了：种族抽按卡池等级统计口径（2026-08-26）

用于 `recruit_log` 的种族抽产出分析。

## 卡池等级

- 不按自然日累计后统一定级。
- 应按玩家历史招募事件的发生顺序累计经验，并在每次种族抽发生时判断当时已达到的卡池等级。
- 招募经验换算沿用既有口径：普通招募 = 1 经验/次；高级招募 = 10 经验/次；种族招募 = 30 经验/次。
- 卡池等级门槛：Lv1 0~999；Lv2 1000~3499；Lv3 3500~7499；Lv4 7500~12499；Lv5 12500~19999；Lv6 20000~34999；Lv7 35000~84999；Lv8 85000~184999；Lv9 185000~384999；Lv10 >=385000。
- 为避免同一天跨等级的数据被整体归到同一等级，累计顺序应使用 `#event_time`，而不是 `$part_date`。

## 种族抽抽数

- 事件：`recruit_log`。
- `gacha_type = 3` 为种族抽。
- `award_ting` 结构：`array(row(star double, num double, id varchar, "type" double, gacha_num double))`。
- 真实抽数使用 `award_ting.gacha_num`，不要用 `count(*)`、`cardinality(award_ting)` 或拆数组后的奖励行数代替。
- 统计某个卡池等级的总种族抽数时，应对该等级下 `award_ting.gacha_num` 求和。

## 英雄产出

- `award_ting.type = 2` 为英雄。
- 英雄数量使用 `award_ting.num`。
- 英雄归类沿用 `knowledge/xiafangle_gacha_hero_rarity_groups_20260826.md`：狗粮卡 / 传说卡 / 传说+。

## 指标

- 人均产出数量 = 某等级某类型英雄产出数量 / 该等级发生种族抽的去重玩家数。
- 平均多少抽产出1张 = 该等级种族抽总抽数（sum(gacha_num)） / 某等级某类型英雄产出数量。
- 等级内数量占比 = 某等级某类型英雄产出数量 / 该等级全部英雄产出数量。
