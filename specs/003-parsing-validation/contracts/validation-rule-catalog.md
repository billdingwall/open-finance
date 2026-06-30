# Contract: Validation Rule Catalog & Engine

## Rule shape (locked, Round 8)

```
ValidationRule {
  id: String,                 // VAL-<TIER>-<NNN>, e.g. VAL-CROSS-007
  tier: file | crossFile | domain,
  severity: error | warning | info,
  repairClass: auto | manual | none,
  messageTemplate: String,
  predicate: (WorkspaceContext) -> [ValidationIssue]
}
```

Rules are authored as **data** alongside the schemas. Each predicate is pure and returns zero or more issues.

## Catalog — one rule per condition (`rulesets-and-taxes.md §1`)

ID prefixes: `VAL-FILE-`, `VAL-CROSS-`, `VAL-DOMAIN-`. Numbers are assigned during authoring; the table fixes the *conditions* that MUST each have exactly one rule.

### File-level (`VAL-FILE-…`)
missing required file · unknown file type · invalid file name · duplicate monthly file · invalid CSV header · invalid date · invalid decimal · missing required front matter · invalid enum value

### Cross-file (`VAL-CROSS-…`)
unknown category reference · unknown account-group reference · unknown account reference · unknown asset reference · unknown liability reference · unknown portfolio reference · unknown sleeve reference · unknown goal reference · missing benchmark data · duplicate transaction ID · orphan note link

> **Delete reference-integrity** is *not* a statically-fired `VAL-CROSS` rule — there is nothing to validate on a static workspace. Phase 2 only builds the inbound-reference *lookups* (which rows reference a given account / group / category) on `WorkspaceContext`; the reassign-on-delete policy that consumes them is a Phase-6 write-time helper. No `VAL-CROSS` issue fires for it in this phase.

### Domain (`VAL-DOMAIN-…`)
budget period without budget rows · goal contribution without goal · asset without account · trade without a sending or receiving asset · multi-entry transfer group not netting to zero (`SUM(amount) WHERE group_id=X ≠ 0`) · gross/net group that does not reconcile (`net ≠ gross − Σ(withholding)`, or ≠ exactly one gross + one net) · tax payment outside tax year · business transaction with unknown account-group

## Classification defaults (locked)

| Condition | Severity | Repair |
|---|---|---|
| Missing optional column | warning | auto (inject empty column) |
| Unknown `category_id` | warning | manual (show "uncategorized"; don't block) |
| Unknown `account_id` on a transaction | error | manual (assisted create; never silent add) |
| Missing required folder | info | auto (create it) |

Severity philosophy: **errors block** projections/writes; **warnings surface** without blocking; **info is silent**.

## ValidationEngine

```
func validate(_ context: WorkspaceContext) -> ValidationResult
```

- Runs **full-workspace pass** (clarify Q4): file-level → cross-file → domain.
- **Lifts** parse/normalization warnings from each `CSVParseResult` into `ValidationResult` as file-level issues (clarify Q3) — single unified issue stream. Lifted issues use a `PARSE`/`VAL-FILE-…` mapping per `kind`.
- Groups issues by severity; marks each with its repair class and source location.
- No false positives on legitimately empty/sparse data (FR-011).

## Acceptance hooks (→ SC-003)

- Valid fixture ⇒ zero errors, zero false-positive warnings.
- Defect-seeded fixture ⇒ each rule fires **exactly once** with the correct id/tier/severity/repair-class.
