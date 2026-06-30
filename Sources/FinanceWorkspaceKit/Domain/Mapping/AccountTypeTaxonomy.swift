import Foundation

// T004 — Canonical `account_type` values per `account_group` (Phase 3, FR-020).
// `account_type` stays a free-string schema column for forward compatibility; this map is the
// seed/validation reference, not an enforced enum. See contracts/seed-data.md §1.

public enum AccountTypeTaxonomy {

    /// Canonical sub-types for each high-level `account_group`.
    public static let canonical: [AccountGroupClass: [String]] = [
        .checking: ["personal", "joint"],
        .savings: ["hysa", "standard", "money_market"],
        .investment: ["taxable", "roth_ira", "traditional_ira", "hsa", "401k", "sep_ira"],
        .creditCard: ["personal", "business"],
        .loan: ["mortgage", "auto", "personal", "student"],
        .employment: ["w2", "1099"],
        .business: ["sole_prop", "llc", "s_corp"],
    ]

    /// Whether `accountType` is a canonical value for `group` (used by seed validation; user-entered
    /// values outside the list remain valid at the schema level).
    public static func isCanonical(_ accountType: String, for group: AccountGroupClass) -> Bool {
        canonical[group]?.contains(accountType) ?? false
    }
}
