---
round: 4
date: 2026-06-12
type: prototype-review
summary: Second prototype review — screen-consolidation pass for MVP
status: in progress
---

## Remove for MVP
these can be introduced in V2 or removed completely:

#### 1. Active goals:
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=savings-goals-active
* Change description: this screen can be removed as well as the notion of "active". I only need to master goal list, for MVP user will add and remove goals as needed and will assume any goal listed is active.
* How to address this in the UI: Remove the "Active goals" navigation item.
* How to address this in file structure and logic: remove the active key / value pair from the YAML front matter for each goal.
* How to address in roadmap: move to V2 (general configurable dashboard)

#### 2. Archived goals:
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=savings-goals-archived
* Change description: for MVP this can be removed. There is no need to see old goals at this point in time.
* How to address this in the UI: Remove the "Archived goals" navigation item.
* How to address this in file structure and logic: remove the active key / value pair from the YAML front matter for each goal.
* How to address in roadmap: move to V2 (general configurable dashboard)

#### 3. Dedicated sleeves screen:
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=investments-sleeves
* Change description: The table should just live on the investments portfolio page. 
* How to address this in the UI: Move the table to the bottom of the "Portfolio Overview" screen and remove "Sleeves" as its own navigation item.
* How to address in roadmap: move to V2 (general configurable dashboard)

#### 4. Accounts screen under Savings & Investments:
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=savings-accounts
* Change description: This screen can be removed since there's no difference with "Portfolio Overview" screen. 
* How to address this in the UI: Remove the "Accounts" navigation item under "Savings & Investments". 
* How to address in roadmap: leave off roadmap

#### 5. Benchmark screen
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=investments-benchmark
* Change description: This screen should be removed. No need for it in MVP.
* How to address this in the UI: Remove the "Benchmark" navigation item under "Investments" and move the heatmap table to "Portfolio Overview". 
* How to address in roadmap: leave off roadmap
 
#### 6. Estimated payments screen
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=taxes-estimated-payments
* Change description: This screen should be removed, the functionality here is already covered on the "Current Tax Year" screen.
* How to address this in the UI: Remove the "Estimated payments" navigation item under "Taxes". 
* How to address this in roadmap: leave off roadmap

#### 7. Gains & Income Screen
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=taxes-gains-income
* Change description: This screen should be removed. No need for it in MVP.
* How to address this in the UI: Remove the "Gains & Income" navigation item under "Taxes". 
* How to address this in roadmap: move to V2 (general configurable dashboard)

---------------------------------------------------------------------------

## Functionality updates for MVP
These are changes to the app for MVP:

#### 1. Holdings screen updates to focus on table
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=investments-holdings
* Change description: The holdings table should be the primary focus of this screen, with the other tables supporting it.
* How to address this in the UI: Keep the holdings table as is, but remove the other elements from this screen.
* How to address in roadmap: add to current MVP scope.

#### 2. Holdings screen addition of heatmap table
* URL: * URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=investments-holdings
* Change description: Add a toggle to the holdings table that changes the view between the standard holdings table that exists right now and a heatmap table similar to the benchmark screen.
* How to address this in the UI: Add a toggle to the holdings table that changes the view between the standard holdings table that exists right now and a heatmap table similar to the benchmark screen.
* How to address in roadmap: add to current MVP scope.

#### 3. Prep Checklist screen
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=taxes-checklist
* Change description: make the prep checklist the focal point of this screen and remove other elements.
* How to address this in the UI: Remove the other elements from this screen and keep only the prep checklist. The checklist should be full width of the main panel with additional information to educate the user on taxes.
* How to address in roadmap: add to current MVP scope.

#### 4. Remove prep checklist from current tax year screen
* URL: file:///Users/williamdingwall/Sites/open-finance/prototype/index.html?view=taxes-current
* Change description: Remove the prep checklist from the current tax year screen. Since this functionality lives on it's own screen.
* How to address this in the UI: Remove the prep checklist from the current tax year screen.
* How to address this in roadmap: add to current MVP scope.
