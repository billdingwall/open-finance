# Contract: Test & QA Hardening (US6)

## Validation fixture matrix (FR-023)

- **One valid + one invalid fixture per managed file type**; each invalid fixture surfaces **exactly
  its intended** validation issue (asserted against `RuleCatalog` ids), no more.

## Integration tests (FR-024)

- **Read flow**: bootstrap → index → parse → validate → project (end-to-end).
- **Each write flow**: intent → preview → backup → apply → re-index → re-validate (add/edit/delete,
  multi-entry group, delete-with-reassignment, import).
- **Each auto-repair flow**: preview → apply → re-validate clears the issue.
- **App-target view-model suites** (deferred from Phase 6): WritePreview (apply→re-index / cancel /
  drift→re-preview), Import (required-unmapped blocks, duplicates default-excluded, target required),
  Reassignment (blocked until all chosen, self-deleted target rejected), RepairApply (clears after
  re-validate; manual-only offers no apply).

## XCUITest smoke (FR-024)

- New App-side UI test target loads **every module view** and exercises its primary interaction;
  asserts **no module ships a permanently-disabled write button** (SC-001). Runs on the macOS runner.

## Backup retention + prune (FR-025)

**`BackupPruneService` (+ `backup-prune` CLI)**

- Policy: keep **last 10 per source file** and prune **> 30 days** (whichever more conservative).
- Trigger: **after each successful write** and **once on launch**.
- Safety: **never** removes a backup a current `WritePlan` references.
- Test: an over-limit backup set reduces to the policy; the newest are kept; an in-flight-write's
  backup is retained; pruning is idempotent.

**Guarantees**: green CI (fixture matrix + integration + view-model + XCUITest); backups never exceed
the retention policy; SC-005/006/007 covered.
