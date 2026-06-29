# Data Model: Parsing, Validation & Infrastructure (Phase 2)

Phase 2 introduces the **parsing**, **validation**, and **settings** types and makes the Phase 1 `ValidationIssue`/`RepairAction` stubs concrete. The canonical *domain* entities (Account, UnifiedTransaction, etc.) already exist from Phase 1 and are consumed unchanged — parsed records map onto them.

Types live under `Sources/FinanceWorkspaceKit/{Parsing,Validation,Persistence}/`. All are Swift `struct`/`enum` value types (Observation for the settings store).

---

## Parsing types (`Parsing/`)

### ColumnType (enum)
`string | decimal | date | bool | integer | enum(values:[String])` — the target type a raw cell is normalized to.

### ColumnDefinition
| Field | Type | Notes |
|---|---|---|
| `name` | String | canonical column name |
| `type` | ColumnType | |
| `required` | Bool | required vs optional |
| `enumValues` | [String]? | present when `type == .enum` |

### CSVSchema
| Field | Type | Notes |
|---|---|---|
| `fileTypeKey` | String | domain + subtype key (e.g. `accounts`, `transactions`, `tax-adjustments`) |
| `schemaVersion` | Int | the current registry version for this type |
| `columns` | [ColumnDefinition] | ordered |
| `allowsExtraColumns` | Bool | unknown columns → warning, not fatal |

Loaded by `CSVSchemaRegistry` from **bundled** JSON resources (`Bundle.module`, `Resources/Schemas/`). One schema per managed file type (see registry list below).

### FieldValue
A normalized cell: the typed value (or null) **plus** a validity flag.
| Field | Type | Notes |
|---|---|---|
| `raw` | String | original string (provenance / re-export) |
| `typed` | Any? | normalized value; nil when invalid or blank |
| `isValid` | Bool | false when normalization failed |

### ParsedRecord
One typed row, retained even when partially invalid (clarify Q1).
| Field | Type | Notes |
|---|---|---|
| `fields` | [String: FieldValue] | keyed by canonical column |
| `sourceFile` | String | workspace-relative path (provenance) |
| `sourceRow` | Int | 1-based data-row index |
| `hasInvalidField` | Bool | derived; true if any field `isValid == false` |

### NormalizationError / ParseWarning
| Field | Type | Notes |
|---|---|---|
| `file` | String | |
| `row` | Int? | nil for file-level (e.g. bad header) |
| `column` | String? | |
| `kind` | enum | `invalidDate \| invalidDecimal \| invalidEnum \| invalidBool \| unknownColumn \| missingHeader \| schemaVersionMismatch \| missingSchemaVersion` |
| `message` | String | |

### CSVParseResult
| Field | Type | Notes |
|---|---|---|
| `fileTypeKey` | String | |
| `records` | [ParsedRecord] | typed rows (incl. partial) |
| `warnings` | [ParseWarning] | per-row + file-level; later **lifted** into the issue stream by the engine |
| `schemaVersionFound` | Int? | nil ⇒ marker absent (defaults to current + repair flag) |

### FrontMatter
Flat metadata extracted from the `---` block: `[String: FrontMatterValue]` where `FrontMatterValue = string | number | bool | list`.

### NoteRecord
| Field | Type | Notes |
|---|---|---|
| `noteType` | enum | from `type` field + folder path (e.g. `monthly`, `strategy`) |
| `period` | String? | e.g. `2026-05` |
| `linkedEntityIDs` / `linkedAccountIDs` / `linkedSleeveIDs` | [String] | |
| `taxYear` | Int? | |
| `body` | String | preserved, **not rendered** in v1 |
| `sourceFile` | String | |
| `frontMatterPresent` | Bool | false ⇒ flagged, not fatal |

---

## Validation types (`Validation/`)

### RuleTier (enum)
`file | crossFile | domain`

### Severity (enum)
`error | warning | info` — errors block projections/writes; warnings surface; info is silent/diagnostic.

### RepairClass (enum)
`auto | manual | none`

### ValidationRule (RuleCatalog entry)
| Field | Type | Notes |
|---|---|---|
| `id` | String | `VAL-<TIER>-<NNN>` (e.g. `VAL-CROSS-007`) |
| `tier` | RuleTier | |
| `severity` | Severity | |
| `repairClass` | RepairClass | |
| `messageTemplate` | String | |
| `predicate` | (WorkspaceContext) -> [ValidationIssue] | pure function |

`WorkspaceContext` = the parsed workspace (all `CSVParseResult`s + `NoteRecord`s + the resolved registries of accounts/categories/etc.) used by predicates for cross-file lookups.

### ValidationIssue (Phase 1 stub → concrete)
| Field | Type | Notes |
|---|---|---|
| `ruleID` | String | the `VAL-…` ID that fired (`PARSE` pseudo-tier for lifted parse warnings) |
| `tier` | RuleTier | |
| `severity` | Severity | |
| `repairClass` | RepairClass | |
| `message` | String | rendered from template |
| `sourceFile` | String | |
| `sourceRow` | Int? | |
| `column` | String? | |

### ValidationResult
| Field | Type | Notes |
|---|---|---|
| `issues` | [ValidationIssue] | includes parse/normalization warnings lifted from `CSVParseResult` (clarify Q3) |
| `bySeverity` | [Severity: [ValidationIssue]] | derived grouping |
| `errorCount` / `warningCount` / `infoCount` | Int | derived |

---

## Repair types (`Validation/`)

### RepairAction (Phase 1 stub → concrete)
| Field | Type | Notes |
|---|---|---|
| `id` | String | |
| `targetFile` | String | |
| `kind` | enum | `injectMissingColumn \| normalizeHeaderCasing \| createSeedFile \| createFolder \| normalizeBlankField` |
| `repairClass` | RepairClass | always `auto` for executable actions |
| `description` | String | |

### RepairPlan
| Field | Type | Notes |
|---|---|---|
| `actions` | [RepairAction] | |
| `diff` | [RowDiff] | before/after of affected rows (preview) |
| `backupPath` | String? | populated on apply |
| `requiresConfirmation` | Bool | always true |

### RepairLogEntry → `.finance-meta/logs/repair-log.csv`
| Column | Notes |
|---|---|
| `timestamp` | ISO 8601 |
| `target_file` | |
| `action_kind` | |
| `backup_path` | |
| `result` | `applied \| skipped (no-op) \| failed` |

---

## Settings types (`Persistence/`)

### FilingStatus (enum)
`single | marriedFilingJointly | marriedFilingSeparately | headOfHousehold | qualifyingWidow`

### WorkspaceSettings (`@Observable`)
| Field | Type | Notes |
|---|---|---|
| `filingStatus` | FilingStatus | |
| `taxYear` | Int | |
| `defaultCurrency` | String | ISO 4217 (default `USD`) |
| `timezone` | String | IANA (default device tz) |

Read/written by `SettingsStore` from/to `Taxes/settings.csv`; typed defaults produced when the file is absent.

---

## Managed file-type registry (one CSVSchema each)

The registry MUST cover every managed file type under R6 names (`fileTypeKey` in parentheses):

- **Accounts/**: `accounts.csv` (accounts), `account-groups.csv` (account-groups), `liabilities.csv` (liabilities), `account-rules.csv` (account-rules), `transactions/YYYY-MM.csv` (transactions)
- **Budget/**: `categories.csv` (categories), `budgets.csv` (budgets), `budget-allocations.csv` (budget-allocations)
- **Savings/**: `goals.csv` (goals), `progress.csv` (savings-progress)
- **Investments/**: `assets.csv` (assets), `prices.csv` (prices), `dividends.csv` (dividends), `tax-lots.csv` (tax-lots), `portfolios.csv` (portfolios), `sleeves.csv` (sleeves), `sleeve-targets.csv` (sleeve-targets), `benchmarks/sp500.csv` (benchmark-series)
- **Taxes/**: `tax-adjustments.csv` (tax-adjustments), `estimates.csv` (tax-estimates), `documents.csv` (tax-documents), `estimated-payments.csv` (estimated-payments), `settings.csv` (settings)
- **Notes/**: Markdown note types (`monthly`, `strategy`) — front matter is free-form in v1 (presence-validated only, no authored schema); typed by `type` field + folder path
- **Root**: `Workspace.md` (workspace descriptor — front matter)

Column-level specs (names, types, required/optional, enum sets) are authored from `docs/architecture/containers-and-budgets.md §3`. Phase 1 shipped `account` + `transaction` starter schemas; the rest are authored in this phase. Exact enum value sets (`account_group`, `account_type`, `trade_type`, `frequency`, `adjustment_type`, `status`) are enumerated here per the open Phase 2 work item.
