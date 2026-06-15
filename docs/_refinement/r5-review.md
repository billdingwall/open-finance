---
round: 5
date: 2026-06-15
type: prototype-review
summary: Third prototype review — functional details for MVP
status: applied 2026-06-15 (docs); prototype pending
---

## Remove for MVP
these can be introduced in V2 or removed completely:

#### 1. Filter Bar:
* URLs:
    - /prototype/index.html?view=accounts-overview
    - /prototype/index.html?view=accounts-{ALL_ENTITIES}
    - /prototype/index.html?view=budget-history
    - /prototype/index.html?view=budget-categories
    - /prototype/index.html?view=savings-goals
    - /prototype/index.html?view=investments-portfolio
    - /prototype/index.html?view=investments-holdings
    - /prototype/index.html?view=taxes-current
    - /prototype/index.html?view=taxes-checklist
    - /prototype/index.html?view=taxes-archive
* Change description: The filter bar is not needed for MVP and requires more thought around functionality details.
* How to address this in the UI: Remove the filter bar from each screen.
* How to address in roadmap: address in V2

---------------------------------------------------------------------------

## Functionality updates for MVP
These are changes to the app for MVP:

#### 1. Dashboard is default screens
* URL: /prototype/index.html?view=overview-dashboard
* Change description: The overview dashboard should be the default screen that users see when they log in. Currently it's set up as a nav item. 
* How to address this in the UI:
    - When app loads for first time, the dashboard loads
    - Remove the "Overview" section and "Dashboard" link and from the left hand navigation. 
    - The "sidebar-head" links to the dashboard screen.
    - The "ws-name" reads "Finance Dashboard"
* How to address in roadmap: add to current MVP scope.

#### 2. Business entity sub tabs
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=accounts-entity-consulting-llc
* Change description: The sub tabs for business entities that currently toggles between dashboard, transactions, budgets and transactions can be removed. Transactions is added to the main screen below the monthly net income chart.
* How to address this in the UI: Remove the sub tabs from the business entity screens. Move the transactions table to the main screen, below the monthly net income chart. 
* How to address in roadmap: add to current MVP scope.

#### 3. Use real charts instead of SVGs
* URLs:
    - /prototype/index.html?view=overview-dashboard
    - /prototype/index.html?view=accounts-entity-personal
    - /prototype/index.html?view=accounts-entity-consulting-llc
    - /prototype/index.html?view=accounts-entity-freelance
    - /prototype/index.html?view=investments-portfolio
* Change description: The SVGs used for charts and visualizations are not functional and should be replaced with real charts. The text should be actual text and the chart should use proper charting methods for the data and environment (prototype vs MacOS app).

#### 4. Add individual accounts
* URLs:
    - /prototype/index.html?view=accounts-entity-personal
    - /prototype/index.html?view=accounts-entity-employment
    - /prototype/index.html?view=accounts-entity-consulting-llc
    - /prototype/index.html?view=accounts-entity-freelance
* Change description: On account entity views add the individual accounts that make up that group.
* How to address this in the UI: Above the transcations table, add a section displaying individual accounts. The same account cards in all accounts should be used here too. 
* How to address in roadmap: add to current MVP scope.

#### 5. Individual account screens
* URLs /prototype/index.html?view=accounts-overview
* Change description: Individual account cards should link to a new "Individual account" screen.
* How to address this in the UI: From the all accounts screen and entity screens, the individual account cards should be clickable and link to a new screen with data unique to that account. Each individual account can be simple with a transactions table.
* How to address in roadmap: add to current MVP scope.

#### 6. Ability to remove and edit objects
* URLs: across the full app
* Change description: In addition to adding Account entities, individual accounts, transactions, categories, asset holdings and so on, there should also be the ability to delete those objects. Any object that can be added, should also be removable and editable within the app.
* How to address in the UI: for objects that can be added with the UI, either manually or by import, as the user clicks on that object to open the right panel, the option to edit or delete is as the bottom of the panel. If clicking the object does not open the right panel because they have their own dedicated screen with main panel (like the individual account proposed treatment), the edit option shows in the local navigation and delete is an option within edit.

-------------------------

## Minor text and styling updates
These are minor text and styling updates that should be made to the app:

#### 1. Change "Personal Assets" to "Personal Accounts" in personal acccount entity
* URL: /prototype/index.html?view=accounts-{ALL_ENTITIES}
* Change description: The text across all account and entity screents for personal accounts and personal entity to read "Account" instead of "Asset". 
* How to address this in the UI: elements like the "Add Asset" button change to "Add Account".
* Mock data in the prototype is also updated to reflect this change.
* How to address in roadmap: add to current MVP scope.

#### 2. Spend Mix / Spending variance panel resizing
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=budget-overview
* Change description: The spend mix takes up too much space while spending variance is cut off. The panels should both take up equal space.
* How to address this in the UI: set both panels to 50/50 split.
* How to address in roadmap: add to current MVP scope.
    
#### 3. Issues count chip moves to the top header
* URL: all screens
* Change description: The issues count chip is currently in the top nav bar. It should be in the top header space next to the sync status chip.
* How to address this in the UI: move issues chip to the top right of the screen left of the sync chip.
* How to address in roadmap: add to current MVP scope.
    
#### 4. Local actions moves to same level as page title
* URL: all screens
* Change description: The local-actions row is currently below the page-title and takes up too much vertical space on some screens. It should be on the same level as the page title and be right aligned. No change o page title or breadcrumbs.
* How to address this in the UI: move local actions to the same level as the page title and right aligned within the main column.
* How to address in roadmap: add to current MVP scope.

#### 5. Account entity terminology changes to account groups
* URL: account screens
* Change description: The term “entity” should be removed from the UI as it relates to accounts in favor of “group”.
* How to address this in the UI: update account terminology across screens in elements like the “New entity” local nav item, which should read “New group”.
* How to address in roadmap: add to current MVP scope.

