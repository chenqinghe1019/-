# 飞鱼游戏-倍特工作室 Codex 知识库

这个仓库用于同步项目相关的 Codex 知识资产，方便换电脑后继续使用同一套埋点、数数看板和分析流程。

## 内容

### Skill 定义（`.codex/skills/`）
- `SKILL.md`：触发描述、工作流、输出规范
- `agents/openai.yaml`：Codex agent 接口配置
- `references/*.md`：skill 引用的 schema 文档
- `scripts/*.ps1`：skill 配套的自动化脚本

### 埋点规格
- `tracking_projects.yaml`：埋点项目索引（项目名 → YAML 文件映射）
- `fangkuai_tracking.yaml`：方块也疯狂 埋点结构（事件、参数、用户属性、公共属性）
- `xiafangle_tracking.yaml`：下方了 埋点结构
- `xiafangle_anti_cheat_tracking.yaml`：下方了 外挂治理埋点与规则口径（表后缀 41）

### SQL 口径
- `sql/xiafangle_anti_cheat_report_v41.sql`：下方了 外挂异常玩家名单统计 SQL，按角色ID、区服、异常类型聚合，输出 VIP、累充、战力、赛季、渠道等字段。

### 操作地图（`*_operation_map.yaml`）
记录各系统的项目 ID、表结构规则、接口路径，供 Codex 操作时定位。
- `ta_data_operation_map.yaml`：数数后台
- `gravity_operation_map.yaml`：引力引擎
- `wechat_ad_operation_map.yaml`：微信广告后台

### 工作流规范（`*_workflow.yaml`）
记录操作流程、完成标准、注意事项。
- `ta_dashboard_report_workflow.yaml`：数数看板 / 报表编辑、保存、验收流程

### SQL 模板（`sql_templates.yaml`）
可复用的查询模板和口径说明，按项目或主题组织。

## 换电脑恢复

1. clone 这个仓库。
2. 把 `.codex/skills/tracking-yaml` 复制到新电脑的 `%USERPROFILE%\.codex\skills\tracking-yaml`。
3. 打开 Codex 后确认可用 skill 里出现 `tracking-yaml`。
4. 数数后台仍按安全策略处理：Codex 打开浏览器，你手动登录，Codex 只接管已登录会话，不保存账号密码。

## 同步规则

以后这个项目内的 skill 或 YAML 有新增、修改后，Codex 需要自动提交并推送到 GitHub：

```bash
git add .codex/skills *.yaml *.yml README.md .gitignore
git commit -m "Update Codex project knowledge"
git push
```

提交前仍要检查不要包含账号、密码、token、临时业务数据、截图或前端大包。

## 不提交的内容

`.gitignore` 默认忽略所有临时文件，只放行 YAML、README 和 `.codex` 项目 skill。以下内容不应进入 git：

- 登录 token、账号、密码。
- 浏览器抓取的前端大包，例如 `ta_umi.js`、`ta_micro_umi.js`。
- 临时接口脚本、截图、查询结果、导出的业务数据。
- Excel 原始导出文件，除非你明确需要归档。
