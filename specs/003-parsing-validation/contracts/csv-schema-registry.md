# Contract: CSV Schema Registry

`CSVSchemaRegistry` is the authoritative source of column definitions for every managed file type. Schemas are **bundled with the app** (clarify Q2) and loaded via `Bundle.module`.

## Registry surface

```
func schema(for fileTypeKey: String) -> CSVSchema?
func schema(forPath relativePath: String) -> CSVSchema?   // classify by path → filename → headers
var allFileTypeKeys: [String] { get }
var currentSchemaVersion(for fileTypeKey: String) -> Int
```

- Loads bundled JSON from `Resources/Schemas/*.schema.json` at init; **never** reads the workspace `.finance-meta/schemas/` mirror at runtime.
- Bootstrap copies the bundled set into the workspace mirror; the registry and bootstrap derive from the same files so they cannot drift.

## Schema JSON shape (one file per managed type)

```json
{
  "fileTypeKey": "tax-adjustments",
  "schemaVersion": 1,
  "allowsExtraColumns": false,
  "columns": [
    { "name": "tax_adjustment_id", "type": "string",  "required": true },
    { "name": "adjustment_type",   "type": "enum",    "required": true,
      "enumValues": ["above_the_line", "schedule_a", "schedule_c", "credit", "standard"] },
    { "name": "amount",            "type": "decimal", "required": true },
    { "name": "tax_year",          "type": "integer", "required": true },
    { "name": "status",            "type": "enum",    "required": false,
      "enumValues": ["draft", "confirmed"] }
  ]
}
```

> Column sets above are illustrative; the authoritative per-column specs come from `docs/architecture/containers-and-budgets.md §3`. The full enum value sets (`account_group`, `account_type`, `trade_type`, `frequency`, `adjustment_type`, `status`) are enumerated as part of this phase.

## Coverage requirement

The registry MUST contain one schema for every managed file type listed in `data-model.md` ("Managed file-type registry"). Phase 1 shipped only `account` and `transaction`; the remainder are authored here. A missing schema for a discovered managed file is itself a file-level validation issue (`unknown file type`).

## Behavior

- Header mapping is case-insensitive and whitespace-trimmed.
- A file whose `# schema_version: N` is **older** than `currentSchemaVersion` routes to the migration/repair path (never parsed against a mismatched schema).
- A file with **no** `# schema_version` marker is treated as the current version with a repair flag.
- Unknown/extra columns: warning when `allowsExtraColumns == false`; ignored otherwise. Known columns still parse.
