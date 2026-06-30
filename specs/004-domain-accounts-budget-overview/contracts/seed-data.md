# Contract: Seed Data — Account-Type Taxonomy & Default Category Set

No schema change: `account_type` stays a free-string column; categories gain *rows*, not columns. The
`# schema_version: 1` comment row and existing headers are unchanged (Constitution File & Schema
Conventions preserved).

## 1. Canonical account-type taxonomy (FR-020)

`Domain/Mapping/AccountTypeTaxonomy.swift` — `[AccountGroupClass: [String]]`. Used to seed correct
values and as a reference list; user-entered values outside it remain valid.

| `account_group` | canonical `account_type` values |
|---|---|
| `checking` | `personal`, `joint` |
| `savings` | `hysa`, `standard`, `money_market` |
| `investment` | `taxable`, `roth_ira`, `traditional_ira`, `hsa`, `401k`, `sep_ira` |
| `credit_card` | `personal`, `business` |
| `loan` | `mortgage`, `auto`, `personal`, `student` |
| `employment` | `w2`, `1099` |
| `business` | `sole_prop`, `llc`, `s_corp` |

### Seed-account correction

The six locked seed accounts in `WorkspaceLayout` currently carry non-canonical `account_type`
values (e.g. `personal`, `business`, `llc`, `taxable`, `standard`). Correct them to canonical values
for their group:

| account_id | account_group | account_type (corrected) |
|---|---|---|
| `acc-personal-bank` | `checking` | `personal` |
| `acc-personal-cc` | `credit_card` | `personal` |
| `acc-business-bank` | `business` | `llc` |
| `acc-business-cc` | `credit_card` | `business` |
| `acc-savings` | `savings` | `standard` |
| `acc-investment` | `investment` | `taxable` |

> The current seed already happens to use group-appropriate values for most rows; this task makes the
> mapping explicit and adds a `SeedDataTests` assertion that every seed `account_type` ∈ taxonomy for
> its `account_group`.

## 2. Default budget category set (FR-021)

Expanded `Budget/categories.csv` seed. Columns (unchanged):
`category_id,name,parent_category_id,category_group_id,default_budget_behavior,tax_relevant`.

| category_id | name | category_group_id | default_budget_behavior | tax_relevant |
|---|---|---|---|---|
| `cat-salary` | Salary | `grp-income` | fixed | true |
| `cat-business-income` | Business Income | `grp-income` | fixed | true |
| `cat-housing` | Housing | `grp-essentials` | fixed | false |
| `cat-groceries` | Groceries | `grp-essentials` | discretionary | false |
| `cat-utilities` | Utilities | `grp-essentials` | fixed | false |
| `cat-transport` | Transport | `grp-essentials` | discretionary | false |
| `cat-insurance` | Insurance | `grp-essentials` | fixed | true |
| `cat-dining` | Dining | `grp-lifestyle` | discretionary | false |
| `cat-entertainment` | Entertainment | `grp-lifestyle` | discretionary | false |
| `cat-shopping` | Shopping | `grp-lifestyle` | discretionary | false |
| `cat-travel` | Travel | `grp-lifestyle` | discretionary | false |
| `cat-emergency` | Emergency Fund | `grp-savings` | savings | false |
| `cat-goals` | Goal Savings | `grp-savings` | savings | false |
| `cat-retirement` | Retirement | `grp-investments` | investment | false |
| `cat-brokerage` | Brokerage | `grp-investments` | investment | false |
| `cat-transfers` | Transfers | `grp-transfers` | transfer | false |

Category groups referenced: `grp-income`, `grp-essentials`, `grp-lifestyle`, `grp-savings`,
`grp-investments`, `grp-transfers` (six groups — SC-007). `tax_relevant = true` on income and
insurance (health/business-relevant) categories.

> Replaces the current 6-row seed (`cat-income`, `cat-housing`, `cat-groceries`, `cat-transport`,
> `cat-savings`, `cat-investments`). The default budget/allocations seed files stay empty (a user
> defines budgets), consistent with today's `WorkspaceLayout`.

## 3. Validation expectation (SC-007)

After bootstrap, `validate-workspace` reports **zero errors** against the seeded files, and the seeded
categories cover all six groups. `SeedDataTests` asserts both, plus the taxonomy membership of every
seed account.
