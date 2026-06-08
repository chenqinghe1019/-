# 飞鱼游戏-倍特工作室 Codex 知识库

这个仓库用于同步项目相关的 Codex 知识资产，方便换电脑后继续使用同一套埋点、数数看板和分析流程。

## 内容

- `tracking_projects.yaml`：埋点项目索引。
- `fangkuai_tracking.yaml`：方块也疯狂埋点结构。
- `xiafangle_tracking.yaml`：下方了埋点结构。
- `ta_data_operation_map.yaml`：数数后台项目、表后缀、接口和操作规则。
- `ta_dashboard_report_workflow.yaml`：数数看板/报表编辑、保存、验收流程。
- `.codex/skills/tracking-yaml/`：本项目自定义埋点文档转 YAML skill。

## 换电脑恢复

1. clone 这个仓库。
2. 把 `.codex/skills/tracking-yaml` 复制到新电脑的 `%USERPROFILE%\.codex\skills\tracking-yaml`。
3. 打开 Codex 后确认可用 skill 里出现 `tracking-yaml`。
4. 数数后台仍按安全策略处理：Codex 打开浏览器，你手动登录，Codex 只接管已登录会话，不保存账号密码。

## 不提交的内容

`.gitignore` 默认忽略所有临时文件，只放行 YAML、README 和 `.codex` 项目 skill。以下内容不应进入 git：

- 登录 token、账号、密码。
- 浏览器抓取的前端大包，例如 `ta_umi.js`、`ta_micro_umi.js`。
- 临时接口脚本、截图、查询结果、导出的业务数据。
- Excel 原始导出文件，除非你明确需要归档。
