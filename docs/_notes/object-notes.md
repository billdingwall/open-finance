
## Notes on system objects
* These are just notes about how objects relate to each other in the system so we’re fully aligned in expectation. 
* These notes are high level and don’t get as deep as specific properties, content or meta data, that level of detail will come in the next review.
* These notes are incomplete and should be audited further as part of the next review.

#### High level object descriptions

Account objects;
- Account-group (connects multiple individual accounts into themes/entities). Account groups act as the primary connecting objects.
- Individual-account (represents a specific account like savings, checking, brokerage, etc. Stores both transactions and assets.)
- Asset (a holding of wealth like cash, stocks, crypto, etc. It can be associated with transactions but can also be edited directly.)
- Transaction (A purchase, a sell or a transfer of money to obtain a service or good.)

Budget objects:
* Budget (A grouping of account-groups / individual-accounts used to monitor transactions.)
* Budget-category (Means for organizing monthly transactions as it relates to a goal.)

Savings & Investment objects:
* Strategy (A grouping of account groups / individual accounts used to monitor assets.)
* Strategy-categories (Means for organizing assets into sleeves within a strategy.)

#### High level object connections

```
--- Account object connections

Transactions → Assets
↓               ↓
Individual-account
↓
Account-group → Account-group

--- Budget object connections

Account-group / Transactions
↓                    ↓
Budget ← Budget-category

--- Savings & Investments:

Account-group / Assets
↓                 ↓
Strategy ← Strategy-category

```