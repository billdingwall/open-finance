---
round: 6
date: 2026-06-16
type: prototype-review
summary: Fourth prototype review — data structuring and information architecture
status: in-progress
---

## Object definitions

### Overview of Object Definitions
To ensure consistency and clarity across the architecture, every object is defined using a standard set of attributes. This uniform structure helps in understanding the role, data composition, and relationships of each object within the system. If a specific attribute does not apply to an object, its bullet is left blank.

The standard property groupings are:
- **description**: A brief, high-level summary of what the object represents.
- **purpose**: The "why"—the specific role this object plays in the overall system and the value it provides to the user.
- **properties**: The core data fields, metadata, or state variables stored within the object.
- **aggregates**: A list of child objects or lower-level entities that this object contains or groups together.
- **connections**: Other related objects that this object interacts with or references, outside of direct parent-child aggregation.
- **actions**: The operations, state changes, or user interactions that can be performed on or by this object.

### Core Objects
These are objects that are used throughout the system and act as primary stores of value and means of organization. Core objects represent the raw financial data that everything else in the system is built upon.

##### Account
- description: Represents a specific account like savings, checking, brokerage, etc. Stores transactions, assets, and debts.
- purpose: Acts as the primary ledger for tracking balances, liquidity, and financial activity for a specific financial institution or holding.
- properties:
	- Account-ID (string, primary key)
	- Name (string)
	- Account-type-ID (reference)
	- Group-ID (reference, optional)
	- Current-balance (number)
	- Available-balance (number)
	- Status (string/enum: draft, active, frozen, closed)
- aggregates:
	- Transaction
	- Asset
	- Debt
- connections:
	- Account-group
	- Budget
	- Account-type
- actions:
	- Add, Edit, Delete
	- Manage transactions (add, edit, delete)
	- Manage assets (add, edit, delete)
	- Manage debts (add, edit, delete)

##### Account-type
- description: A classification label for accounts (e.g., checking, savings, brokerage, credit card). Defines how an account behaves within the system.
- purpose: Categorizes accounts to enable standardized rulesets, UI treatments, and aggregated reporting by account type.
- properties:
	- Account-type-ID (string, primary key)
	- Name (string)
	- Order-index (number)
- aggregates:
	- Account
- connections:
	- Account
- actions:
	- Add, Edit, Delete, Reorder

##### Transaction
- description: A purchase, sale, or transfer of money to obtain a service or good. Defines values for all financial items and keeps a record of how values change over time. Transactions are the backbone of the entire system because the full list of transactions gives a clear view of current and past financial states.
- purpose: Serves as the fundamental unit of financial activity, tracking the flow of money in, out, and within the user's financial ecosystem.
- properties:
	- Transaction-ID (string, primary key)
	- Description (string)
	- Date (date)
	- Amount (number)
	- Account-ID (reference)
	- Type (string/enum: income, expense, transfer)
	- Status (string/enum: pending, posted, reconciled, failed, refunded)
	- Category-ID (reference, optional)
	- Source-ID (reference, optional)
	- Tags (array of references, optional)
	- Notes (string, optional)
- aggregates:
	- 
- connections:
	- Account
	- Transaction-category
	- Transaction-source
	- Transaction-tag
	- Tax-report
- actions:
	- Add, Edit, Delete
	- Categorize
	- Split transaction

##### Transaction-category
- description: A grouping mechanism to classify transactions for budgeting and reporting purposes (e.g., Groceries, Rent, Salary).
- purpose: Allows users to understand where their money is coming from and going, enabling budget tracking and spending analysis.
- properties:
	- Category-ID (string, primary key)
	- Name (string)
	- Type (string/enum: income, expense)
	- Parent-category-ID (reference, optional for sub-categories)
	- Icon (string/url, optional)
	- Color (string/hex, optional)
- aggregates:
	- 
- connections:
	- Transaction
	- Transaction-source
	- Budget-category
	- Tax-adjustment
- actions:
	- Add, Edit, Delete
	- Merge categories
	- Reassign transactions

##### Transaction-tag
- description: A flexible, user-defined label applied to transactions for ad-hoc organization across different categories (e.g., #vacation2026, #tax-deductible).
- purpose: Provides a secondary dimension of tracking that doesn't fit neatly into the primary category structure.
- properties:
	- Tag-ID (string, primary key)
	- Name (string)
	- Color (string/hex, optional)
- aggregates:
	- 
- connections:
	- Transaction
- actions:
	- Add, Edit, Delete
	- Apply to transaction

##### Transaction-source
- description: The issuer of a transaction. In the case of an expense it's likely a merchant; for income it may be an employer or client.
- purpose: Normalizes and tracks the entities the user transacts with, improving auto-categorization and merchant-level reporting.
- properties:
	- Source-ID (string, primary key)
	- Name (string)
	- Default-category-ID (reference, optional)
	- Logo (string/url, optional)
- aggregates:
	- 
- connections:
	- Transaction
	- Transaction-category
- actions:
	- Add, Edit, Delete
	- Map raw string to Source (ruleset)

##### Asset
- description: A holding of wealth like cash, stocks, crypto, real estate, etc. It can be associated with transactions but can also be edited directly.
- purpose: Represents positive value on the user's balance sheet, tracked over time to measure net worth.
- properties:
	- Asset-ID (string, primary key)
	- Name (string)
	- Type (string/enum: cash, equity, crypto, real-estate)
	- Current-value (number)
	- Account-ID (reference)
	- Ticker-symbol (string, optional)
	- Quantity (number, optional)
- aggregates:
	- 
- connections:
	- Account
	- Portfolio
	- Portfolio-sleeve
	- Tax-adjustment
- actions:
	- Add, Edit, Delete
	- Update valuation
	- Link to transactions (buy/sell)

##### Debt
> **Pending resolution:** The naming plan (§7) folds Debt into Account as an account subtype carrying debt-specific optional columns. It is retained here as a standalone object until that resolution is applied to the object definitions.
- description: A debt position that needs to be repaid, like a credit card, a mortgage, or a student loan.
- purpose: Represents negative value on the user's balance sheet. Tracking debts is critical for net worth calculations and payoff planning.
- properties:
	- Debt-ID (string, primary key)
	- Name (string)
	- Type (string/enum: credit-card, loan, mortgage)
	- Principal-balance (number)
	- Interest-rate (number)
	- Account-ID (reference)
	- Minimum-payment (number, optional)
	- Due-date (date, optional)
- aggregates:
	- 
- connections:
	- Account
- actions:
	- Add, Edit, Delete
	- Record payment (creates Transaction)
	- Update interest rate

### Containers
Containers act as connectors for objects within the app. These objects aggregate and connect lower-level objects. At the same time, they act as components for larger objects.

##### Account-group
- description: Connects multiple accounts into themes or entities like a place of employment or grouping of personal credit cards.
- purpose: The Account-group acts as the primary connecting object in the system. It aggregates lower objects and connects larger ones.
- properties:
	- Group-ID (string, primary key)
	- Name (string)
	- Description (string, optional)
	- Type (string/enum: personal, employment, business)
- aggregates:
	- Account
- connections:
	- Budget
	- Portfolio
- actions:
	- Add, Edit, Delete
	- Link/un-link account

##### Budget
- description: A grouping of account-groups and accounts used to monitor transactions against a predefined spending plan over a specific time period.
- purpose: Helps users constrain spending, plan for future expenses, and evaluate financial habits.
- properties:
	- Budget-ID (string, primary key)
	- Name (string)
	- Timeframe (string/enum: monthly, weekly, annual)
	- Start-date (date)
	- End-date (date, optional)
	- Account-group-IDs (array of references, optional)
	- Account-IDs (array of references, optional)
- aggregates:
	- Budget-category
	- Budget-allocation
- connections:
	- Account-group
	- Account
- actions:
	- Add, Edit, Delete
	- Rollover to next period
	- Compare actuals vs. planned

##### Budget-allocation
- description: A means of organizing monthly transactions as they relate to a goal. Specific funding assigned to a Budget-category for a given timeframe.
- purpose: Sets the target threshold for spending or saving within a specific budget category to guide user behavior.
- properties:
	- Allocation-ID (string, primary key)
	- Budget-category-ID (reference)
	- Amount (number)
	- Rollover-amount (number, optional)
	- Period (string/date)
- aggregates:
	- 
- connections:
	- Budget-category
- actions:
	- Add, Edit, Delete
	- Adjust allocation amount

##### Budget-category
- description: The intersection of a transaction category and a budget, defining the specific rules and thresholds for a group of transactions.
- purpose: Maps the abstract transaction categorization structure to actionable budget limits.
- properties:
	- Budget-category-ID (string, primary key)
	- Budget-ID (reference)
	- Transaction-category-ID (reference)
	- Name (string)
	- Target-amount (number)
	- Target-type (string/enum: spending, savings)
- aggregates:
	- Budget-allocation
- connections:
	- Transaction-category
	- Budget
- actions:
	- Add, Edit, Delete
	- Map to transaction category

##### Portfolio
- description: A high-level container for tracking long-term assets, investments, and savings goals outside of day-to-day transactional budgets.
- purpose: Allows users to group and evaluate assets based on specific financial goals, time horizons, and risk profiles.
- properties:
	- Portfolio-ID (string, primary key)
	- Name (string)
	- Description (string, optional)
	- Goal (string, optional)
	- Timeframe (string, optional)
	- Type (string/enum: retirement, brokerage, crypto, savings)
- aggregates:
	- Portfolio-sleeve
- connections:
	- Asset
	- Account-group
- actions:
	- Add, Edit, Delete
	- Rebalance
	- Calculate performance

##### Portfolio-sleeve
- description: A sub-division within a portfolio, often representing a specific strategy, asset class, or sub-goal.
- purpose: Enables granular tracking and strategy implementation within a larger, unified portfolio.
- properties:
	- Sleeve-ID (string, primary key)
	- Portfolio-ID (reference)
	- Name (string)
	- Goal (string, optional)
	- Target-allocation-percentage (number)
- aggregates:
	- 
- connections:
	- Portfolio
	- Asset
- actions:
	- Add, Edit, Delete
	- Adjust target allocation

### Rulesets
Rulesets are like standard operating procedures for the system. They act as templates for how certain types of transactions or assets should be handled.

##### Tax-adjustment
- description: A rule or modifier that accounts for tax liabilities or benefits related to specific transactions or assets.
- purpose: Ensures the net worth and cash flow calculations accurately reflect tax implications (e.g., pre-tax vs. post-tax).
- properties:
	- Adjustment-ID (string, primary key)
	- Name (string)
	- Rate-percentage (number)
	- Type (string/enum: deduction, liability, credit)
- aggregates:
	- 
- connections:
	- Transaction-category
	- Asset
	- Tax-report
- actions:
	- Add, Edit, Delete
	- Apply adjustment

##### Tax-report
- description: A generated summary that aggregates transactions and adjustments for tax filing purposes.
- purpose: Provides a streamlined, exportable view of taxable events and deductible expenses for a given fiscal year.
- properties:
	- Report-ID (string, primary key)
	- Fiscal-year (number)
	- Generation-date (date)
- aggregates:
	- 
- connections:
	- Transaction
	- Tax-adjustment
- actions:
	- Generate
	- Export (PDF/CSV)
	- Delete

---
## Object connections

### 1. Core Objects Architecture
This diagram focuses on the primary financial entities and how they relate to the ledger.
```mermaid
erDiagram
    Account ||--o{ Transaction : "records"
    Account ||--o{ Asset : "holds"
    Account ||--o{ Debt : "owes"
    Account }o--|| Account-type : "classified as"
    Transaction }o--o| Transaction-category : "categorized by"
    Transaction }o--o| Transaction-source : "issued by"
    Transaction }o--o{ Transaction-tag : "tagged with"
    Transaction-category ||--o{ Transaction-source : "default for"
```

### 2. Containers Architecture
This diagram focuses on how user-defined groups organize core objects for tracking and goals.
```mermaid
erDiagram
    Account-group ||--o{ Account : "aggregates"
    Budget }o--o{ Account-group : "monitors"
    Budget ||--o{ Budget-category : "contains"
    Budget ||--o{ Budget-allocation : "allocates"
    Budget-category ||--o{ Budget-allocation : "funded by"
    Budget-category |o--|| Transaction-category : "maps to"
    Portfolio ||--o{ Portfolio-sleeve : "contains"
    Portfolio }o--o{ Account-group : "tracks via"
    Portfolio ||--o{ Asset : "tracks"
    Portfolio-sleeve ||--o{ Asset : "allocates"
```

### 3. Rulesets Architecture
This diagram focuses on how standard operating procedures interact with raw financial data.
```mermaid
erDiagram
    Tax-report ||--o{ Transaction : "aggregates"
    Tax-report ||--o{ Tax-adjustment : "includes"
    Tax-adjustment }o--o{ Transaction-category : "applies to"
    Tax-adjustment }o--o{ Asset : "applies to"
```

### 4. Overall Architecture
This diagram provides a comprehensive view showing the intersection of Core Objects, Containers, and Rulesets across the full system.
```mermaid
erDiagram
    Account-group ||--o{ Account : "contains"
    Account }o--|| Account-type : "classified as"
    Account ||--o{ Transaction : "records"
    Account ||--o{ Asset : "holds"
    Account ||--o{ Debt : "owes"
    Transaction }o--o| Transaction-category : "categorized by"
    Transaction }o--o| Transaction-source : "issued by"
    Transaction }o--o{ Transaction-tag : "tagged with"
    Transaction-category ||--o{ Transaction-source : "default for"
    Budget }o--o{ Account-group : "monitors"
    Budget ||--o{ Budget-category : "defines limits for"
    Budget ||--o{ Budget-allocation : "allocates"
    Budget-category |o--|| Transaction-category : "maps to"
    Budget-category ||--o{ Budget-allocation : "funded by"
    Portfolio }o--o{ Account-group : "tracks via"
    Portfolio ||--o{ Portfolio-sleeve : "contains"
    Portfolio ||--o{ Asset : "tracks"
    Portfolio-sleeve ||--o{ Asset : "allocates"
    Tax-report ||--o{ Transaction : "analyzes"
    Tax-report ||--o{ Tax-adjustment : "includes"
    Tax-adjustment }o--o{ Transaction-category : "applies to"
    Tax-adjustment }o--o{ Asset : "applies to"
```

### 5. State Machine Diagrams
Lifecycle tracking for volatile objects is crucial for accurate financial reporting and reconciliation.

**Transaction Lifecycle** — aligns with `Transaction.Status` enum: `pending, posted, reconciled, failed, refunded`
```mermaid
stateDiagram-v2
    [*] --> pending : Transaction created
    pending --> posted : Cleared by source
    posted --> reconciled : Verified against ledger
    pending --> failed : Denied / Error
    posted --> refunded : Reversal issued
    reconciled --> [*]
    failed --> [*]
    refunded --> [*]
```

**Account Lifecycle** — aligns with `Account.Status` enum: `draft, active, frozen, closed`
```mermaid
stateDiagram-v2
    [*] --> draft : Account created
    draft --> active : Initial funding / activation
    active --> frozen : Suspicious activity / Lock
    frozen --> active : Unlocked
    active --> closed : Account terminated
    closed --> [*]
```

---
## Architectural Recommendations

As a principal database architect, I recommend the following next steps as we move from this review prototype into formal system design documentation:

1. **Data Flow / Pipeline Diagrams**: Given this is a financial app, we should map how external data is ingested. A sequence diagram showing the flow from an external API (like Plaid) → raw JSON → normalization into `Transaction` → auto-categorization via `Transaction-source` → and updating `Account` balances would be invaluable.
2. **Implement File Organization Proposal**: As this architectural documentation grows, this monolithic `r6-review.md` file will become a bottleneck. We should establish a scalable directory structure under `/docs/architecture/` to house distinct domain concerns:
    - **`/docs/architecture/index.md`**: The executive summary, system vision, and high-level ER diagrams.
    - **`/docs/architecture/core-domain.md`**: Detailed schemas, property constraints, and state machines for primary ledger entities (`Account`, `Transaction`, `Asset`, etc.).
    - **`/docs/architecture/containers-and-budgets.md`**: The logic for aggregation, including `Portfolio` management, `Budget` limits, and `Account-group` rules.
    - **`/docs/architecture/rulesets-and-taxes.md`**: Documentation on standard operating procedures, tax adjustments, and report generation engines.
    - **`/docs/architecture/data-pipelines.md`**: Integration diagrams, external API webhook handling (e.g. Plaid), and data normalization processes.

---
## Flat File Storage Strategy

This section maps the objects defined above to the existing flat file architecture established in `technical-design.md`. The system uses **CSV files as the source of truth** for structured financial data and **Markdown files with YAML frontmatter** for configuration, notes, and generated reports. There is no hidden database — files are the database.

### Storage Format Decision Matrix
Each object is stored as either a **Markdown file** (`.md` with YAML frontmatter) or a **CSV file** (`.csv`), based on these criteria:

| Criteria | Markdown (`.md`) | CSV (`.csv`) |
|---|---|---|
| Best for | Configuration, notes, generated reports | Structured financial records with uniform columns |
| Identity | YAML frontmatter fields or filename | Row-level ID column within the file |
| Relationships | YAML frontmatter arrays (entity_ids, account_ids, etc.) | Column references (foreign keys as string IDs) |
| Git diffing | Human-readable, line-level diffs | Row-level diffs, harder to review at scale |
| Performance | Fine for low-count read-once files | Required for high-volume, frequently-queried data |

### Object-to-File Mapping

The existing architecture uses **unified master CSV registries** rather than folder-per-entity nesting. All accounts live in a single `accounts.csv`; all transactions share monthly-partitioned files distinguished by `account_id` and `entity_id` columns.

| Object | tech-design name | Format | Storage Location | Notes |
|---|---|---|---|---|
| **Account-group** | Entity | `.csv` | `Accounts/entities.csv` | Master registry of all account groups. `entity_id` is the primary key. |
| **Account** | Account | `.csv` | `Accounts/accounts.csv` | **Master registry** — the critical system dependency. All account types in a single file with optional columns for investment metadata. |
| **Account-type** | — | column | `accounts.csv` → `account_type` | Stored as an enum column within the master accounts file, not a separate file. |
| **Transaction** | Transaction | `.csv` | `Accounts/transactions/YYYY-MM.csv` | Monthly-partitioned. Unified ledger for all account types. Business transactions distinguished by `BX-` ID prefix. |
| **Transaction-category** | Category | `.csv` | `Budget/categories.csv` | Shared lookup table. Supports parent-child via a parent ID column. |
| **Transaction-tag** | — | `.csv` | TBD — inline or dedicated file | No tag representation exists in tech-design yet. Tags may be stored as pipe-delimited values within transactions, or as a dedicated lookup. Needs decision. |
| **Transaction-source** | — | column | `YYYY-MM.csv` → `merchant` | No dedicated object in tech-design; the issuer is captured inline as the raw `merchant`/payer string. A dedicated `transaction-sources.csv` lookup may be added for normalization. |
| **Asset** | Holding | `.csv` | `Investments/holdings.csv` | Current positions. Linked to accounts via `account_id`. |
| **Debt** | — | `.csv` | `Accounts/accounts.csv` + metadata | Debt accounts stored in the unified accounts registry. Debt-specific fields (interest rate, minimum payment) as optional columns. |
| **Budget** | Budget | `.csv` | `Budget/budgets.csv` | Budget targets per category per period. |
| **Budget-category** | — | `.csv` | `Budget/categories.csv` | Shared with Transaction-category. Budget targets reference category IDs. |
| **Budget-allocation** | — | rows | `Budget/budgets.csv` | Each row is effectively an allocation (category + period + amount). |
| **Portfolio** | Sleeve group | `.csv` | `Investments/sleeves.csv` | Portfolio-level grouping. |
| **Portfolio-sleeve** | Sleeve | `.csv` | `Investments/sleeves.csv` + `sleeve-targets.csv` | Sleeve definitions and target allocation weights. |
| **Tax-adjustment** | Deduction | `.csv` | `Taxes/deductions.csv` | All deduction types via `deduction_type` enum column. |
| **Tax-report** | Tax report | `.md` | `Taxes/yearly/YYYY-tax-notes.md` | YAML frontmatter for metadata, markdown body for report content. |

### Vault Directory Structure
This tree aligns with the existing domain-based folder organization:
```
Finance/
├── Workspace.md                          # Workspace identity (YAML frontmatter)
├── .finance-meta/                        # App-managed metadata (NOT source of truth)
│   ├── manifest.json                     # File discovery cache, hashes, validation
│   ├── schemas/                          # JSON schema definitions per CSV type
│   ├── backups/                          # Timestamped backups before every write
│   └── logs/                             # repair-log.csv, import-log.csv
│
├── Accounts/
│   ├── accounts.csv                      # MASTER account registry (ALL types)
│   ├── entities.csv                      # Account groups / themes (= Account-group)
│   ├── account-rules.csv                 # Income/expense estimates per account
│   └── transactions/
│       ├── 2026-01.csv                   # Monthly-partitioned unified transaction ledger
│       ├── 2026-02.csv
│       └── ...
│
├── Budget/
│   ├── categories.csv                    # Transaction-category definitions
│   ├── budgets.csv                       # Monthly budget targets per category
│   └── savings-goal-contributions.csv
│
├── Savings/
│   ├── goals.csv                         # Savings goals
│   └── progress.csv                      # Progress snapshots
│
├── Investments/
│   ├── holdings.csv                      # Current positions (= Asset)
│   ├── transactions.csv                  # Trades (buy/sell)
│   ├── prices.csv                        # Price history
│   ├── dividends.csv
│   ├── tax-lots.csv
│   ├── sleeves.csv                       # Portfolio sleeve definitions
│   ├── sleeve-targets.csv                # Target weights per sleeve
│   └── benchmarks/
│       └── sp500.csv
│
├── Taxes/
│   ├── estimated-payments.csv
│   ├── settings.csv                      # Key-value tax settings
│   ├── deductions.csv                    # All deduction types (= Tax-adjustment)
│   ├── archive/                          # Read-only prior-year snapshots
│   └── yearly/
│       ├── 2026-tax-notes.md
│       └── 2026-prep-checklist.md
│
└── Notes/
    ├── monthly/                           # Monthly review notes
    └── strategy/                          # IPS, tax strategy, etc.
```

### Referencing Conventions
This list describes how objects reference each other within the flat file system:

1. **Master registries as single source**: `accounts.csv` is the canonical registry. Every other file references `account_id` from it. `entities.csv` is the canonical registry for account groups; accounts reference `entity_id` from it.
2. **String-based foreign keys in CSV columns**: Cross-object relationships are expressed by ID columns (e.g., `category_id` in a transaction row references a row in `categories.csv`). These are always string-typed for stability.
3. **Monthly partitioning for transactions**: Rather than scoping transactions per-account, all transactions live in unified `YYYY-MM.csv` files. The `account_id` column filters by account; the ID prefix (`BX-`) distinguishes business transactions.
4. **Pipe-delimited arrays for many-to-many**: Tags on transactions are stored as a pipe-delimited list within a single CSV column (e.g., `tag-1|tag-2|tag-3`). This avoids the need for a separate join table.
5. **YAML frontmatter arrays for markdown references**: Markdown files use YAML arrays to express relationships: `entity_ids: [consulting-llc]`, `account_ids: [checking-main]`, `sleeve_ids: [core-growth]`.
6. **Source provenance on every record**: Each transaction carries `source_file` and `source_row` for traceability back to the exact import file and line.
7. **Amount sign convention (locked)**: Negative = debit (money out), positive = credit (money in). A redundant `direction` column is kept for import mapping readability.

### Relationship storage diagram
This flowchart visualizes the cross-file reference conventions above — how a record in one file points to a record in another, whether through a CSV foreign-key column (conventions 1–3), a pipe-delimited array (convention 4), or a YAML frontmatter array (convention 5). The record-level conventions (source provenance and the amount sign convention) apply within individual rows rather than between files, so they are not drawn here.
```mermaid
flowchart TD
    subgraph "Master Registries"
        ACCT["Accounts/accounts.csv"]
        ENT["Accounts/entities.csv"]
        CAT["Budget/categories.csv"]
    end

    subgraph "Transactional Data"
        TX["Accounts/transactions/YYYY-MM.csv"]
        HOLD["Investments/holdings.csv"]
        TRADES["Investments/transactions.csv"]
    end

    subgraph "Budget & Goals"
        BUD["Budget/budgets.csv"]
        GOALS["Savings/goals.csv"]
    end

    subgraph "Investment Structure"
        SLV["Investments/sleeves.csv"]
        SLVT["Investments/sleeve-targets.csv"]
    end

    subgraph "Tax"
        DED["Taxes/deductions.csv"]
    end

    subgraph "Lookups"
        TAGS["tags lookup (inline pipe-delimited; dedicated file TBD)"]
    end

    subgraph "Notes & Reports (Markdown)"
        NOTE["Notes/ and Taxes/yearly/*.md (YAML frontmatter)"]
    end

    ENT -- "entity_id" --> ACCT
    ACCT -- "account_id" --> TX
    ACCT -- "account_id" --> HOLD
    ACCT -- "account_id" --> TRADES
    CAT -- "category_id" --> TX
    CAT -- "category_id" --> BUD
    ACCT -- "account_id" --> DED
    SLV -- "sleeve_id" --> HOLD
    SLV -- "sleeve_id" --> SLVT
    GOALS -- "savings_goal_id" --> TX
    TX -. "tag_ids (pipe-delimited)" .-> TAGS
    NOTE -. "entity_ids[]" .-> ENT
    NOTE -. "account_ids[]" .-> ACCT
    NOTE -. "sleeve_ids[]" .-> SLV
```

---
## Required Additions for Flat File Database System

Beyond the object definitions and storage strategy above, the following system-level concerns must be addressed to build a production-ready flat file database:

### 1. Data Integrity & Validation Layer
- **Schema validation**: The existing architecture specifies JSON schemas in `.finance-meta/schemas/`. These must be kept in sync with the object definitions in this document. Each CSV type carries a `schema_version`; the app validates column presence, data types, and enum values on every read.
- **Referential integrity checks**: On vault load, the app must validate that all cross-file references resolve (e.g., every `category_id` in a transaction exists in `categories.csv`). Deleting an object should trigger a reference check surfacing all inbound references before proceeding.
- **ID uniqueness enforcement**: CSV-based objects need guaranteed unique IDs. The existing design uses prefixed IDs (`BX-` for business transactions). Recommend extending this convention to all object types and enforcing uniqueness at write time.

### 2. Concurrency & File Locking
- **Safe write protocol**: The existing architecture mandates preview → timestamped backup → atomic apply → re-index → re-validate. This must be enforced for all objects.
- **Atomic writes**: CSV and markdown updates should write to a temp file first, then rename to prevent corruption on crash or power loss. Backups are stored in `.finance-meta/backups/`.
- **Operation queue**: If the app supports multiple windows or future sync, a write queue prevents simultaneous mutations to the same file.

### 3. Indexing & Query Performance
- **In-memory index**: On vault load, build an in-memory index of all IDs, slugs, and common query paths (e.g., transactions by date range, by category). The file system is the persistence layer; the in-memory graph is the query layer. The existing `manifest.json` already caches file discovery and hashes.
- **Lazy loading**: Monthly transaction files naturally partition data. The app should only load months within the active view range and page in older months on demand.
- **Derived/computed fields**: `Account.Current-balance` and `Account.Available-balance` should be computed from the transaction ledger on load rather than stored as static values. This prevents drift. The CSV can cache the balance for display speed, but the transaction files are the source of truth.

### 4. Migration & Versioning
- **Schema versioning**: Each file type already carries a `schema_version` per the technical design. Breaking changes (rename, remove, type change, new required column) require incrementing the version and shipping a migration script. Adding optional columns is non-breaking.
- **Migration scripts**: As object schemas evolve, the app needs a migration runner that can transform existing vault files to the new format. Repairs are logged to `.finance-meta/logs/repair-log.csv`.

### 5. Backup & Recovery
- **Timestamped backups**: Already specified — every write creates a backup in `.finance-meta/backups/`.
- **Cloud storage abstraction**: Built around a `CloudStorageProvider` protocol so iCloud (v1) can be swapped for Google Drive, Dropbox, or local folder in v2.
- **Export/import**: Support full vault export as a single `.zip` archive and import from the same format for portability across machines.

### 6. Object Definition Gaps
The following objects are implied by the architecture but not yet formally defined in this review:

- **Settings / Workspace**: Global app configuration (vault path, default currency, date format, theme). Currently `Workspace.md` at vault root.
- **Savings-goal**: A goal-tracking object linked to transactions via `savings_goal_id`. Defined in `Savings/goals.csv` and `progress.csv` but not modeled in this review's object definitions.
- **Account-rule**: Income/expense estimates per account (`Accounts/account-rules.csv`). Used for cash flow projections but not defined here.
- **Currency**: If multi-currency support is planned, a Currency object (code, symbol, exchange rate) and a root-level `currencies.csv` lookup table will be needed.
- **Recurring-transaction**: A template for transactions that repeat on a schedule (e.g., monthly rent, bi-weekly paycheck). Would store frequency, next-due-date, and a reference to the base transaction template.
- **Valuation-history**: For assets, a time-series log of historical values. `Investments/prices.csv` partially covers this for market securities but a generalized history for all asset types is needed.
- **Audit-log**: A system-level append-only log of all mutations. Partially covered by `.finance-meta/logs/` but a formal `audit-log.csv` with structured columns (timestamp, user, action, file, before, after) would strengthen undo support.

### 7. Naming Alignment & Resolution Plan

This review introduces object names that differ from those established in `technical-design.md`, `product-requirements.md`, and the prototype code. Since this file's naming and object structures will be used to update all downstream specification docs, **this section resolves each conflict and establishes the canonical name going forward.**

#### Resolution Principles
1. **Clarity over brevity**: Names should be self-describing to someone reading the docs for the first time, without needing to cross-reference a glossary.
2. **Domain accuracy**: Names should reflect what the object *is* in financial terms, not implementation details.
3. **Consistency with existing schemas**: Where a name is already embedded in CSV column names, filenames, and code identifiers, the cost of renaming must be weighed against the clarity gained.
4. **This file is canonical**: Once resolved, these names propagate to all other docs. The r6-review object definitions become the source of truth for naming.

#### Resolution Decisions

| r6-review name | Existing name | Resolution | Canonical name | Rationale |
|---|---|---|---|---|
| **Account-group** | Entity | **Adopt existing** | **Entity** | `entity_id` is embedded in `entities.csv`, `accounts.csv`, transaction CSVs, `categories.csv`, `deductions.csv`, prototype code (`entityId`), and UI copy. "Entity" also accurately describes the concept — a person, family, or business that owns accounts. Renaming would touch every file in the system. |
| **Asset** | Holding | **Adopt existing** | **Holding** | `holding_id` is embedded in `holdings.csv`, investment transaction CSVs, and prototype code (`holdingId`). "Holding" is the standard financial term for a specific investment position. "Asset" is too broad — it could mean real estate, cash, or a car. Reserve "asset" for informal/umbrella usage (e.g., "asset allocation"). |
| **Transaction-category** | Category | **Adopt existing** | **Category** | `category_id` is embedded in `categories.csv`, transaction CSVs, `budgets.csv`, `account-rules.csv`, and prototype code (`categoryId`). The "Transaction-" prefix is redundant since categories are already scoped to transactions by context. |
| **Tax-adjustment** | Deduction | **Adopt existing** | **Deduction** | `deduction_id` is embedded in `deductions.csv` with an established schema and `deduction_type` enum. "Tax-adjustment" is more abstract and less recognizable. The `deduction_type` enum already covers all adjustment types (standard, itemized, business expense, etc.). |
| **Portfolio** | — (no formal object) | **Adopt r6-review** | **Portfolio** | No `portfolio_id` or `portfolios.csv` exists in the current design. "Portfolio" fills a real gap — sleeves need a parent container. Add `portfolios.csv` with `portfolio_id` as the primary key, and add a `portfolio_id` FK to `sleeves.csv`. "Portfolio" is the universally understood financial term. |
| **Portfolio-sleeve** | Sleeve | **Adopt existing** | **Sleeve** | `sleeve_id` is embedded in `sleeves.csv`, `sleeve-targets.csv`, `holdings.csv`, investment transaction CSVs, and prototype code. The r6-review object already uses `Sleeve-ID` as its primary key; the "Portfolio-" prefix is contextual scoping that the canonical name drops. |
| **Debt** | — (account subtype) | **Keep as account subtype** | **— (not a standalone object)** | The existing design stores debt accounts in the unified `accounts.csv` with optional columns (`interest_rate`, `credit_limit`, `minimum_payment`). This is the correct approach — a mortgage account *is* an account, not a separate entity. Remove Debt as a standalone object from r6-review and instead document the debt-specific optional columns on Account. |

#### Updates Required to r6-review Object Definitions

Based on the resolutions above, the following changes should be applied to the object definitions earlier in this file before propagating to downstream docs:

1. **Rename Account-group → Entity** throughout. Update properties:
    - `Group-ID` → `entity_id` (string, primary key)
    - `Type` enum: keep `personal, employment, business` but align with the existing `entity_type` enum in `entities.csv` (`personal, employment, business, custom`) — add the missing `custom` value
2. **Rename Asset → Holding** throughout. Update properties:
    - `Asset-ID` → `holding_id` (string, primary key)
    - Add `ticker`, `cost_basis`, `asset_class`, `sleeve_id` to match existing `holdings.csv` schema
3. **Rename Transaction-category → Category** throughout. Update properties:
    - `Category-ID` → `category_id` (string, primary key)
    - Add `entity_id` (reference, optional) — categories can be entity-scoped per existing schema
    - Add `sort_order` (number, optional)
4. **Rename Tax-adjustment → Deduction** throughout. Update properties:
    - `Adjustment-ID` → `deduction_id` (string, primary key)
    - Replace `Rate-percentage` and `Type` with the existing `deduction_type` enum
    - Add `entity_id`, `account_id`, `tax_year`, `notes` per existing schema; add a new `receipt_path` field (not in the current schema)
5. **Add Portfolio as a new object** in the Containers section with a formal schema:
    - `portfolio_id` (string, primary key)
    - `name`, `description`, `strategy`, `goal`, `timeframe`
    - Aggregates: Sleeves
    - New file: `Investments/portfolios.csv`
    - Add `portfolio_id` FK to `sleeves.csv`
6. **Remove Debt as standalone object**. Instead, document debt-specific optional columns on Account:
    - `interest_rate` (number, optional — for credit cards, loans, mortgages)
    - `credit_limit` (number, optional — for credit cards)
    - `minimum_payment` (number, optional)
    - `due_date` (date, optional)
7. **Update all ER diagrams and state machines** to use the resolved canonical names.

#### Downstream Document Migration Checklist

Once the r6-review object definitions are updated with the resolved names above, propagate changes to these files:

| Document | What to update |
|---|---|
| `docs/technical-design.md` | Add `portfolios.csv` schema. Verify all 24 CSV schemas align with r6-review property definitions. Add debt-specific optional columns documentation to `accounts.csv` schema if not present. |
| `docs/product-requirements.md` | Update any references to object names that changed. Add Portfolio as a formal feature. Verify Debt is described as an account subtype, not a standalone feature. |
| `docs/product-roadmap.md` | Ensure milestone references use canonical names. Add Portfolio to the appropriate phase. |
| `docs/project-management.md` | Update task/ticket naming to use canonical terms. |
| `prototype/data.js` | Add `portfolioId` to mock sleeve data. Verify all mock data property names match canonical schemas. |
| `prototype/store.js` | Update any object references to use canonical names. |

#### Naming Convention Rules (Going Forward)
To prevent future divergence, all new objects must follow these conventions:

1. **Object names**: Capitalized, hyphenated nouns (e.g., `Budget-allocation`, `Portfolio`). Use the most specific financially-standard term available.
2. **Primary keys**: Lowercase, underscored, suffixed with `_id` (e.g., `entity_id`, `holding_id`). Must match across all docs, schemas, code, and CSV headers.
3. **CSV filenames**: Lowercase, plural, hyphenated (e.g., `holdings.csv`, `sleeve-targets.csv`).
4. **Code identifiers**: camelCase matching the CSV column name (e.g., `entityId`, `holdingId`).
5. **No synonyms**: Each concept gets exactly one name. If "asset" means `Holding`, never use "asset" as a formal object name — only as informal prose.
