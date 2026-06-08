---
name: tracking-yaml
description: Convert exported tracking / analytics event specification files into normalized YAML. Use when Codex needs to read local WeCom/Tencent Docs spreadsheet exports, CSV/TSV/text table dumps, or similar Chinese 埋点 documents, infer event structure, normalize event names, triggers, parameters, required flags, types, descriptions, and produce reviewable YAML. Do not use browser automation to access restricted online document URLs; operate on local files or user-provided table text.
---

# Tracking YAML

Use this skill to turn local tracking specification artifacts into clean YAML.

## Inputs

Prefer these inputs, in order:

1. Exported `.xlsx` files from the source document.
2. `.csv` or `.tsv` files for each sheet.
3. Copied table text in `.txt` or `.md`.
4. Screenshots only when no table export is available.

If online document access is blocked by tool policy, do not attempt alternate browser automation. Ask the user to authenticate manually and place exported files in the workspace or Downloads folder. After files are local, continue automatically.

## Workflow

1. Find candidate files in the workspace and Downloads:
   - `*.xlsx`, `*.xls`, `*.csv`, `*.tsv`, `*.txt`, `*.md`
   - Prefer recently modified files when the user just exported documents.
   - For a low-manual workflow, run `scripts/watch-tracking-inputs.ps1` while the user exports/downloads documents; it watches Downloads and the workspace, then writes `tracking_tables_extract.json`.
2. Extract tables:
   - Run `scripts/extract-tracking-tables.ps1 -InputPath <folder-or-file> -OutputPath <json>`.
   - For `.xlsx/.xls`, the script uses Excel COM if available.
   - For CSV/TSV/text, the script reads delimited rows directly.
3. Inspect sheet names, header rows, and dense row blocks before deciding the YAML shape.
4. Identify likely columns by Chinese and English aliases:
   - Event name: `事件名`, `事件名称`, `埋点名`, `event`, `event_name`, `name`
   - Trigger: `触发`, `触发时机`, `上报时机`, `trigger`, `when`
   - Page/module: `页面`, `模块`, `场景`, `page`, `module`, `screen`
   - Parameter name: `参数`, `参数名`, `字段`, `属性`, `param`, `property`, `key`
   - Type: `类型`, `字段类型`, `type`
   - Required: `必填`, `是否必传`, `required`
   - Description: `说明`, `描述`, `备注`, `含义`, `description`, `note`
5. Normalize into YAML while preserving source meaning. Keep original Chinese names in `source_name` or `description` when useful.
6. Include uncertainties in `notes` rather than silently inventing missing fields.

## YAML Shape

Use this default shape unless the user requests another one:

```yaml
projects:
  - project: "Project name"
    source_files:
      - "file.xlsx"
    events:
      - event_name: "event_name"
        source_name: "原始埋点名"
        page: "页面或模块"
        trigger: "触发时机"
        description: "用途说明"
        params:
          - name: "param_name"
            source_name: "原始字段名"
            type: "string"
            required: true
            description: "字段说明"
        notes:
          - "Any ambiguity or inferred mapping."
```

## Quality Rules

- Do not discard rows only because one column is blank; many tracking docs use merged cells or inherited event names.
- Carry event/page/module values downward within a table when the source clearly uses merged-cell style.
- Keep parameter order from the source table.
- Use `required: null` when the source does not say whether a field is required.
- Use conservative types: `string`, `number`, `integer`, `boolean`, `array`, `object`, or `unknown`.
- If multiple projects share the same document, split by sheet, project label, or section heading.
- Before finalizing, mention files processed and any sheets/sections skipped.
