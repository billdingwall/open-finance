# Contract — Import & Export (`FinanceWorkspaceKit/Persistence/Write/`)

## ImportMapper

```
public struct ImportMapper {
    /// Auto-detect a canonical mapping from external headers (case-insensitive synonym match).
    func autoDetect(sourceColumns: [String]) -> ColumnMapping

    /// Parse + normalize the external CSV under a confirmed mapping into an ImportBatch,
    /// splitting rows by YYYY-MM, stamping the target account, and flagging duplicates.
    func buildBatch(csv: String,
                    mapping: ColumnMapping,
                    existing: WorkspaceContext) throws -> ImportBatch

    /// Turn the user-confirmed (included) rows into a WritePlan appending to monthly files.
    func writePlan(from batch: ImportBatch, mapping: ColumnMapping) -> WritePlan
}
```

**Guarantees**
- **I1**: `buildBatch` blocks (throws) when a required canonical transaction column is unmapped
  (FR-015); unparseable rows go to `unparseable`, never to a monthly file.
- **I2**: Every produced row carries `mapping.targetAccountId` (FR-012a, clarify Q1).
- **I3**: Rows are grouped into the correct `YYYY-MM.csv` by parsed date (FR-014, multi-month split).
- **I4**: A row is `isDuplicate` iff an existing transaction in the target account matches on
  **date + amount + description/merchant** (FR-015a, clarify Q2/Q3); duplicates default
  `included = false` and are shown for per-row confirmation.
- **I5**: Sign convention is applied from `mapping.signConvention` via `CSVNormalizer`; never silently
  flipped (FR-013).
- **I6**: `writePlan` appends only `included` rows; the resulting plan flows through `WriteService`
  (backup per touched monthly file, atomic, logged).

## ExportService

```
public struct ExportService {
    /// Current-view rows → CSV text with appended source_file, source_row provenance columns.
    func csv(rows: [[String: String]], columns: [String],
             provenance: [(String, Int)]) -> String

    /// Budget month projection → Markdown summary (period header + category breakdown + totals).
    func budgetSummaryMarkdown(_ projection: BudgetOverviewProjection, period: String) -> String

    /// Write exported text to a user-chosen destination (never inside the workspace).
    func write(_ text: String, to destination: URL) throws
}
```

**Guarantees**
- **E1**: CSV output includes the visible rows plus `source_file` and `source_row` columns (FR-027,
  P-V traceability).
- **E2**: Markdown output starts with a `# Budget — <period>` header and contains a category table
  (plan/actual/variance/trailing-average) + totals line (FR-028).
- **E3**: `write` targets only `destination` (a save-panel URL); it MUST reject a path inside the
  workspace and MUST NOT modify any workspace file (FR-029).
- **E4**: An empty view exports headers with zero data rows (edge case).

## Contract tests (macOS CI)

- ImportMapper: required-column block (I1), target-account stamp (I2), month-split (I3),
  duplicate-flag on date+amount+description (I4), sign convention applied (I5), included-only plan (I6).
- ExportService: provenance columns present (E1), Markdown header+table (E2), workspace-path
  rejected (E3), empty-view headers-only (E4).
