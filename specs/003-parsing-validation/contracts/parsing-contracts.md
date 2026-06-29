# Contract: Parsing Services

## CSVParserService

```
func parse(fileAt relativePath: String, using schema: CSVSchema) throws -> CSVParseResult
```

- Reads via the Phase 1 `FileCoordinatorService` (coordinated access).
- Strips leading `#` comment rows (captures `# schema_version: N` into `schemaVersionFound`).
- RFC-4180 quoting: a quoted field may contain commas, quotes (`""`), and newlines and is one value.
- Maps headers → canonical columns (case-insensitive, trimmed).
- Produces one `ParsedRecord` per data row with `source_file`/`source_row`; defers value typing to `CSVNormalizer`.
- **Resilience**: a malformed row is captured as a `ParseWarning`, the file continues (SC-009). An empty file (header only) → zero records, not an error.

## CSVNormalizer

```
func normalize(_ raw: [String: String], against schema: CSVSchema,
               file: String, row: Int) -> (record: ParsedRecord, warnings: [ParseWarning])
```

- Converts to `Decimal` / `Date` (ISO 8601) / `Bool` / `Int` / enum case.
- **Partial record** on failure (clarify Q1): bad field → `FieldValue(raw:, typed: nil, isValid: false)`, a `ParseWarning` is emitted, all other fields type normally, the row is retained.
- Blank optional field → valid null (no warning). Blank required field → warning.
- Never flips amount signs (sign-flip is an explicit Phase 6 import-time declaration).

## FrontMatterParser

```
func extract(from markdown: String) -> (frontMatter: FrontMatter?, body: String)
```

- Extracts the `---`-delimited block at the top of the file into a flat `[String: FrontMatterValue]`.
- Missing or malformed front matter → `nil` front matter + full text as body (flagged downstream, not fatal).

## MarkdownParserService

```
func parse(fileAt relativePath: String) throws -> NoteRecord
```

- Classifies `noteType` from the `type` front-matter field and the folder path.
- Populates linked IDs, period, tax year from front matter.
- Preserves `body` as text; **does not render** it (v1 metadata-only).
- `frontMatterPresent == false` when extraction failed — surfaced as a `missing required front matter` validation issue, not a crash.

## Invariants (all services)

- Every produced record/note carries workspace-relative `source_file` provenance (Principle V).
- No service mutates a workspace file (read-only); writes belong to repair/settings/migration.
- One bad value never aborts a file; one bad file never aborts a workspace pass.
