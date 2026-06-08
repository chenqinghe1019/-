# Tracking YAML Schema Reference

Default top-level document:

```yaml
projects:
  - project: string
    source_files: [string]
    events:
      - event_name: string
        source_name: string|null
        page: string|null
        module: string|null
        trigger: string|null
        description: string|null
        params:
          - name: string
            source_name: string|null
            type: string
            required: true|false|null
            description: string|null
            example: string|number|boolean|null
        notes: [string]
```

Type normalization:

- Text-like values: `string`
- Numeric counters, prices, durations: `number`
- Integral IDs only when clearly numeric: `integer`
- True/false flags: `boolean`
- Lists: `array`
- JSON/map/object payloads: `object`
- Unclear or blank: `unknown`

Required normalization:

- `是`, `Y`, `Yes`, `必填`, `必传`, `required`, `true` -> `true`
- `否`, `N`, `No`, `选填`, `非必填`, `optional`, `false` -> `false`
- Blank or unclear -> `null`

Name normalization:

- Prefer existing machine-readable event names if present.
- If only Chinese event names exist, create lowercase snake_case only when the project already uses that convention; otherwise keep the source name as `event_name`.
- Preserve original labels in `source_name`.
