---
status: implimented
---

## General functionality 

#### App principles
* The value is in the app flexibility. It’s essentially a structured filing system with an application layer for usability.
* Data should be transparent and in full control of the user. Traceability is the primary concern.
* Easy to read overview panels makes complex data easier to read at a glance. They should prioritize core KPIs for managing monthly expenses, planning for financial goals, reviewing business performance and prepping for yearly taxes.
* General all flow should follow the setup process and connect the dots between the UI and file structure.
* Longer term this could be a general configurable dashboard system that works off a configurable file system.

#### App structure 
#### Accounts
Income and expense management for each taxable account. Provide snapshot of current state and tools for managing.
* Accounts overview (aggregate)
	* card overview of each account
	* total monthly cash inflow
	* YTD net income = gross - exp - tax
	* YTD cash inflow vs retained equity
	* Add accounts (type key tax info)
* Individual account (per account)
	* monthly gross income vs expense/tax
	* YTD net income = gross - exp - tax
	* YTD cash inflow vs retained equity
	* Edit account (type key tax info)
	* Import/Add/Edit transactions
	* Add/Edit account rules & estimates
#### Monthly budget ()
monitor: monthly spend vs planned
* Budget planning
	* cash, fixed, spend, save & invest total%
	* Add/edit categories & target amounts 
* Budget history
	* month over month budget tracking
	* spending analysis by merchant/category
#### Savings & investments
* Historical performance
	* Historical performance vs benchmarks
	* holdings overview (cash, invest, assets)
	* accounts overview (amounts, yield)
* Individual account
	* Add/edit goals, weights, timeframes
	* define strategy (weights, sleeves, etc)
	* account holdings (cash, stock, asset)
	* performance: of assets over time
#### Taxes
current tax year
* YTD taxable income
* Taxes paid vs taxes owed
* Taxes owed, paid and rate per account
* Prep checklist
tax archive
* Add/edit expected deductions
* taxable income - deductibles
* estimated payment / return
#### Notes
	* V2 (general )
#### Issues
	* V2 (general )
#### Files
	* V2 (general )

---

## Overview
*General overview section updates:*
* single view with no filtering for MVP
* Goal is to highlight key data points across all the other views

#### General audit notes
* Right panel should be collapsible and closed by default. IF there’s no ongoing functionality consider it being more of a slide over vs slide in interaction.
* Primary navigation needs to be trimmed, there’s way too much there.
* Filters In main panel need to be trimmed a decent amount to make sure the logic and data structure is sound.
* Month over month update functionality needs to be thought through. Without sync functionality month over onto data is a lot of upkeep. 
* In general, the markdown and CSV structure needs to be reviewed more closely.
* I general, there needs to be more of a fall back for when files are missing or if there are extra files.

#### Overview / Dashboard
*Needs several updates to simplify* 
![[Screenshot 2026-05-11 at 6.17.39 PM.png]]
*Overview/Dashboard updates:*
* Top actions: consistent across views
* Filters: none
* Search: none
* Overview Cards: touches on all views
	* Budget: monthly cash flow - income, est. spending.
	* Savings: total savings - monthly contributions, est rate
	* Investments: total investment - monthly contributions, est rate
	* Business: YTD net income - income, expenses.
	* Taxes: Estimated return - gross income, taxes paid.
* Month over month panels: 
	* budget cash flow (transactions needed)
	* Savings & investments (current totals)
* Table view:
	* Issues: move that functionality here

#### Overview / Monthly Snapshots
*Delete view (outside mvp scope)*
![[Screenshot 2026-05-11 at 6.17.48 PM.png]]
#### Overview / Annual Snapshots
*Delete view (outside mvp scope)*
![[Screenshot 2026-05-11 at 6.18.13 PM.png]]

---

## Personal Budget
* this needs a functionality overhaul
* current month can be updated to a more static overview since we won’t have live data
* budget dashboard can be focused on comparing defined budget against transaction history.

#### Personal Budget / Current Month
*Repurpose as an overview dashboard*
![[Screenshot 2026-05-11 at 6.18.36 PM.png]]
* Overview Cards: functional change
	* Replace with pie graph displaying amounts and percentage of fixed expenses, discretionary spend, savings and investments.
	* Pie graph should also display total monthly net income available to spend.
* Tables below can stay the same, but stack an make full panel width. Put in the same table so savings and investment contributions follow same logic as catagories.
* This categories table should show the three month average of last three months recorded.

#### Personal Budget / Budget History
*Keep as a month over month / variance* 
![[Screenshot 2026-05-11 at 6.18.48 PM.png]]
* 

#### Personal Budget / Categories
*Expand to full budget view (CSP focused)*
![[Screenshot 2026-05-11 at 6.18.56 PM.png]]
* need ability to manually create categories and subcategories 
#### Personal Budget / Rules
![[Screenshot 2026-05-11 at 6.19.04 PM.png]]
Delete (post MVP)

## Savings Goals

#### Savings Goals / All Goals

![[Screenshot 2026-05-11 at 6.19.22 PM.png]]

#### Savings Goals / Active Goals

![[Screenshot 2026-05-11 at 6.19.35 PM.png]]

#### Savings Goals / Archived Goals

![[Screenshot 2026-05-11 at 6.19.46 PM.png]]

#### Savings Goals / House Down Payment

![[Screenshot 2026-05-11 at 6.19.57 PM.png]]

#### Savings Goals / Emergency Fund

![[Screenshot 2026-05-11 at 6.20.05 PM.png]]

#### Investments

#### Investments / Portfolio Overview

![[Screenshot 2026-05-11 at 6.20.26 PM.png]]

#### Investments / Accounts

![[Screenshot 2026-05-11 at 6.20.40 PM.png]]

#### Investments / Brokerage

![[Screenshot 2026-05-11 at 6.20.50 PM.png]]

#### Investments / IRA

![[Screenshot 2026-05-11 at 6.21.03 PM.png]]

#### Investments / Sleeves

![[Screenshot 2026-05-11 at 6.21.13 PM.png]]

#### Investments / Core Growth

![[Screenshot 2026-05-11 at 6.24.01 PM.png]]

#### Investments / Income

![[Screenshot 2026-05-11 at 6.24.10 PM.png]]

#### Investments / Holdings

![[Screenshot 2026-05-11 at 6.24.27 PM.png]]

#### Investments / Benchmarks

![[Screenshot 2026-05-11 at 6.24.47 PM.png]]

* Totals compared to S&P (% growth)
	* Brokerage
	* Savings
	* IRA
* Performance (d, w, m, 3m, 6m, 1y, 3y, 5y)
	* table / heat map format
* Sector performance
	* Weighted against S&P
## Business

#### Business / All Entities

![[Screenshot 2026-05-11 at 6.25.16 PM.png]]

#### Business / Monthly Performance

![[Screenshot 2026-05-11 at 6.25.36 PM.png]]

#### Business / Categories

![[Screenshot 2026-05-11 at 6.25.49 PM.png]]

#### Business / Budgets

![[Screenshot 2026-05-11 at 6.26.04 PM.png]]

#### Business / Consulting LLC

![[Screenshot 2026-05-11 at 6.26.18 PM.png]]

## Taxes

#### Taxes / Current Tax Year

![[Screenshot 2026-05-11 at 6.26.29 PM.png]]

#### Taxes / Estimated Payments

![[Screenshot 2026-05-11 at 6.26.41 PM.png]]

#### Taxes / Gains & Income

![[Screenshot 2026-05-11 at 6.27.03 PM.png]]

#### Taxes / Prep Checklist

![[Screenshot 2026-05-11 at 6.27.18 PM.png]]

## Notes

#### Notes / Monthly Reviews

![[Screenshot 2026-05-11 at 6.27.39 PM.png]]

#### Notes / Strategy Notes

![[Screenshot 2026-05-11 at 6.27.47 PM.png]]

#### Notes / Business Notes

![[Screenshot 2026-05-11 at 6.27.58 PM.png]]

#### Notes / Tax Notes

![[Screenshot 2026-05-11 at 6.28.16 PM.png]]

## Issues

#### Issues / All issues

![[Screenshot 2026-05-11 at 6.28.28 PM.png]]

#### Issues / Repairable

![[Screenshot 2026-05-11 at 6.28.52 PM.png]]

#### Issues / Manual Review

![[Screenshot 2026-05-11 at 6.29.09 PM.png]]

## Settings

#### Settings / Workspace

![[Screenshot 2026-05-11 at 6.29.23 PM.png]]

#### Settings / Schema

![[Screenshot 2026-05-11 at 6.29.36 PM.png]]


svg_content = """<svg width="600" height="400" viewBox="0 0 600 400" xmlns="http://www.w3.org/2000/svg">
    <defs>
        <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#1e1e2f" />
            <stop offset="100%" stop-color="#12121a" />
        </linearGradient>
        
        <linearGradient id="incomeBar" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#34d399" />
            <stop offset="100%" stop-color="#10b981" />
        </linearGradient>
        
        <linearGradient id="equityBar" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#60a5fa" />
            <stop offset="100%" stop-color="#3b82f6" />
        </linearGradient>

        <linearGradient id="sparklineGrad" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#a78bfa" />
            <stop offset="100%" stop-color="#c084fc" />
        </linearGradient>

        <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">
            <feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#000000" flood-opacity="0.4"/>
        </filter>
    </defs>

    <rect width="540" height="340" x="30" y="30" rx="20" fill="url(#bgGradient)" filter="url(#shadow)" />

    <text x="60" y="80" fill="#9ca3af" font-family="Arial, sans-serif" font-size="12" font-weight="600" letter-spacing="1.5">FINANCIAL SUMMARY</text>
    <text x="60" y="115" fill="#f8fafc" font-family="Arial, sans-serif" font-size="26" font-weight="bold">Primary Account</text>
    
    <rect x="420" y="65" width="120" height="26" rx="6" fill="#2d2d3f" />
    <text x="480" y="82" fill="#9ca3af" font-family="monospace, sans-serif" font-size="12" font-weight="600" text-anchor="middle">•••• •••• 9241</text>

    <line x1="60" y1="140" x2="540" y2="140" stroke="#334155" stroke-width="1" />

    <text x="60" y="175" fill="#e2e8f0" font-family="Arial, sans-serif" font-size="14" font-weight="600">Income vs. Retained Equity</text>

    <text x="60" y="210" fill="#94a3b8" font-family="Arial, sans-serif" font-size="12">Total Income</text>
    <text x="155" y="210" fill="#10b981" font-family="Arial, sans-serif" font-size="14" font-weight="bold">$325,400</text>
    <rect x="230" y="199" width="310" height="12" rx="6" fill="#334155" />
    <rect x="230" y="199" width="310" height="12" rx="6" fill="url(#incomeBar)" />

    <text x="60" y="240" fill="#94a3b8" font-family="Arial, sans-serif" font-size="12">Retained Equity</text>
    <text x="155" y="240" fill="#3b82f6" font-family="Arial, sans-serif" font-size="14" font-weight="bold">$210,800</text>
    <rect x="230" y="229" width="310" height="12" rx="6" fill="#334155" />
    <rect x="230" y="229" width="200" height="12" rx="6" fill="url(#equityBar)" />

    <line x1="60" y1="275" x2="540" y2="275" stroke="#334155" stroke-width="1" />

    <text x="60" y="310" fill="#94a3b8" font-family="Arial, sans-serif" font-size="12">Avg Monthly Cash Flow</text>
    <text x="60" y="335" fill="#f8fafc" font-family="Arial, sans-serif" font-size="22" font-weight="bold">+$27,116</text>
    
    <text x="240" y="310" fill="#94a3b8" font-family="Arial, sans-serif" font-size="12">Yearly Cash Flow</text>
    <text x="240" y="335" fill="#f8fafc" font-family="Arial, sans-serif" font-size="22" font-weight="bold">+$325,400</text>

    <g transform="translate(420, 290)">
        <path d="M 0 45 C 15 45, 25 25, 40 30 C 55 35, 65 10, 80 20 C 95 30, 105 0, 120 5" 
              fill="none" stroke="url(#sparklineGrad)" stroke-width="3" stroke-linecap="round" />
        
        <circle cx="0" cy="45" r="3" fill="#a78bfa" />
        <circle cx="40" cy="30" r="3" fill="#a78bfa" />
        <circle cx="80" cy="20" r="3" fill="#a78bfa" />
        <circle cx="120" cy="5" r="4" fill="#ffffff" stroke="#c084fc" stroke-width="2" />
        
        <text x="120" y="-8" fill="#c084fc" font-family="Arial, sans-serif" font-size="10" font-weight="bold" text-anchor="end">YTD Trend</text>
    </g>

</svg>
"""

with open('financial_account_card.svg', 'w') as f:
    f.write(svg_content)

print("SVG successfully generated.")

