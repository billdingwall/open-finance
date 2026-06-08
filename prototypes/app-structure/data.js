/* =========================================================
   Mock data for Finance Workspace prototype.
   Represents a believable May 2026 snapshot of a single workspace.
   ========================================================= */

const DATA = (() => {
  const workspace = {
    id: 'finance-main',
    name: 'Finance',
    path: 'iCloud Drive › Finance',
    defaultCurrency: 'USD',
    timezone: 'America/Denver',
    lastIndexed: '2026-05-11 09:14',
    lastSync: '2026-05-11 09:14',
    schemaVersion: 1,
    issueCount: 8,
  };

  // ----- Personal: categories ----------------------------------------------
  const categories = [
    { id: 'housing',     name: 'Housing',      group: 'Fixed',         planned: 2400, color: '#6366f1' },
    { id: 'groceries',   name: 'Groceries',    group: 'Variable',      planned: 750,  color: '#0ea5e9' },
    { id: 'utilities',   name: 'Utilities',    group: 'Fixed',         planned: 320,  color: '#f59e0b' },
    { id: 'dining',      name: 'Dining',       group: 'Discretionary', planned: 360,  color: '#ef4444' },
    { id: 'childcare',   name: 'Childcare',    group: 'Fixed',         planned: 1450, color: '#8b5cf6' },
    { id: 'insurance',   name: 'Insurance',    group: 'Fixed',         planned: 410,  color: '#14b8a6' },
    { id: 'travel',      name: 'Travel',       group: 'Discretionary', planned: 500,  color: '#06b6d4' },
    { id: 'golf',        name: 'Golf',         group: 'Discretionary', planned: 180,  color: '#22c55e' },
    { id: 'investments', name: 'Investments',  group: 'Savings',       planned: 1500, color: '#3651d3' },
    { id: 'savings',     name: 'Savings',      group: 'Savings',       planned: 900,  color: '#0284c7' },
  ];

  // ----- Personal: transactions for 2026-05 --------------------------------
  // amount: negative = outflow, positive = income/credit
  const transactions = [
    { id: 'TX-2605-001', date: '2026-05-01', merchant: 'Acme Property Mgmt',  description: 'May rent',           account: 'Checking · Chase',     category: 'housing',     amount: -2400.00, direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 2,  importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-002', date: '2026-05-01', merchant: 'Coinbase',            description: 'DCA — VTI',          account: 'Brokerage · Fidelity', category: 'investments', amount: -1500.00, direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 3,  importedFrom: 'fidelity-may.csv' },
    { id: 'TX-2605-003', date: '2026-05-02', merchant: 'Whole Foods',         description: 'Weekly groceries',    account: 'Checking · Chase',     category: 'groceries',   amount: -184.22,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 4,  importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-004', date: '2026-05-02', merchant: 'Xcel Energy',         description: 'Apr electric',        account: 'Checking · Chase',     category: 'utilities',   amount: -142.08,  direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 5,  importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-005', date: '2026-05-03', merchant: 'Bright Horizons',     description: 'Daycare May',         account: 'Checking · Chase',     category: 'childcare',   amount: -1450.00, direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 6,  importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-006', date: '2026-05-04', merchant: 'Acme Employer',       description: 'Payroll · 1st half',  account: 'Checking · Chase',     category: 'income',      amount:  4825.40, direction: 'credit', recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 7,  importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-007', date: '2026-05-04', merchant: 'Trader Joe’s',        description: 'Groceries',           account: 'Checking · Chase',     category: 'groceries',   amount:  -96.43,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 8,  importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-008', date: '2026-05-05', merchant: 'Delta Air Lines',     description: 'DEN → SFO Aug',       account: 'Credit · Sapphire',    category: 'travel',      amount: -312.40,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 9,  importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-009', date: '2026-05-06', merchant: 'Sushi Den',           description: 'Dinner w/ Maya',      account: 'Credit · Sapphire',    category: 'dining',      amount: -84.65,   direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 10, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-010', date: '2026-05-07', merchant: 'State Farm',          description: 'Auto + renters',      account: 'Checking · Chase',     category: 'insurance',   amount: -408.20,  direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 11, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-011', date: '2026-05-08', merchant: 'Foothills Golf Club', description: 'Twilight 18',         account: 'Credit · Sapphire',    category: 'golf',        amount: -62.00,   direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 12, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-012', date: '2026-05-09', merchant: 'King Soopers',        description: 'Groceries',           account: 'Checking · Chase',     category: 'groceries',   amount: -132.18,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 13, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-013', date: '2026-05-09', merchant: 'Marigold Café',       description: 'Brunch',              account: 'Credit · Sapphire',    category: 'dining',      amount: -42.75,   direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 14, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-014', date: '2026-05-10', merchant: 'Marcus Savings',      description: 'Transfer · emergency',account: 'Savings · Marcus',     category: 'savings',     amount: -500.00,  direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 15, importedFrom: 'chase-may.csv', goal: 'emergency-fund' },
    { id: 'TX-2605-015', date: '2026-05-10', merchant: 'Marcus House Goal',   description: 'Transfer · house DP', account: 'Savings · Marcus',     category: 'savings',     amount: -400.00,  direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 16, importedFrom: 'chase-may.csv', goal: 'house-down-payment' },
    { id: 'TX-2605-016', date: '2026-05-11', merchant: 'Comcast Xfinity',     description: 'Internet',            account: 'Checking · Chase',     category: 'utilities',   amount:  -89.99,  direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 17, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-017', date: '2026-05-11', merchant: 'Sweetgreen',          description: 'Lunch',               account: 'Credit · Sapphire',    category: 'dining',      amount:  -16.40,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 18, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-018', date: '2026-05-12', merchant: 'King Soopers',        description: 'Groceries',           account: 'Checking · Chase',     category: 'groceries',   amount: -108.75,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 19, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-019', date: '2026-05-13', merchant: 'Foothills Golf Club', description: 'Range bucket',        account: 'Credit · Sapphire',    category: 'golf',        amount:  -28.00,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 20, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-020', date: '2026-05-14', merchant: 'Airbnb',              description: 'Aspen weekend Jul',   account: 'Credit · Sapphire',    category: 'travel',      amount: -284.10,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 21, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-021', date: '2026-05-15', merchant: 'Acme Employer',       description: 'Payroll · 2nd half',  account: 'Checking · Chase',     category: 'income',      amount:  4825.40, direction: 'credit', recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 22, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-022', date: '2026-05-15', merchant: 'Acme Property Mgmt',  description: 'Renters insurance',   account: 'Checking · Chase',     category: 'insurance',   amount:   -0.00,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 23, importedFrom: 'chase-may.csv', flagged: 'zero-amount' },
    { id: 'TX-2605-023', date: '2026-05-16', merchant: 'Whole Foods',         description: 'Groceries',           account: 'Checking · Chase',     category: 'groceries',   amount: -176.81,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 24, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-024', date: '2026-05-16', merchant: 'Marigold Café',       description: 'Dinner',              account: 'Credit · Sapphire',    category: 'dining',      amount: -68.50,   direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 25, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-025', date: '2026-05-17', merchant: 'REI',                 description: 'Hiking pack',         account: 'Credit · Sapphire',    category: 'travel',      amount: -148.00,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 26, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-026', date: '2026-05-18', merchant: 'Foothills Golf Club', description: 'Twilight 18',         account: 'Credit · Sapphire',    category: 'golf',        amount: -62.00,   direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 27, importedFrom: 'chase-may.csv', duplicate: 'TX-2605-011' },
    { id: 'TX-2605-027', date: '2026-05-18', merchant: 'Sweetgreen',          description: 'Lunch',               account: 'Credit · Sapphire',    category: 'dining',      amount:  -18.20,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 28, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-028', date: '2026-05-19', merchant: 'Trader Joe’s',        description: 'Groceries',           account: 'Checking · Chase',     category: 'groceries',   amount:  -88.42,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 29, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-029', date: '2026-05-20', merchant: 'Xfinity Mobile',      description: 'Cell',                account: 'Checking · Chase',     category: 'utilities',   amount:  -85.00,  direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 30, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-030', date: '2026-05-20', merchant: 'Marcus MacBook Goal', description: 'Transfer · MacBook',  account: 'Savings · Marcus',     category: 'savings',     amount: -150.00,  direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 31, importedFrom: 'chase-may.csv', goal: 'new-macbook' },
    { id: 'TX-2605-031', date: '2026-05-21', merchant: 'Foothills Golf Club', description: 'Lesson',              account: 'Credit · Sapphire',    category: 'golf',        amount:  -85.00,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 32, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-032', date: '2026-05-22', merchant: 'Marigold Café',       description: 'Dinner',              account: 'Credit · Sapphire',    category: 'dining',      amount: -54.60,   direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 33, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-033', date: '2026-05-23', merchant: 'Whole Foods',         description: 'Groceries',           account: 'Checking · Chase',     category: 'groceries',   amount: -142.10,  direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 34, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-034', date: '2026-05-23', merchant: 'Hyatt Aspen',         description: 'Hotel deposit',       account: 'Credit · Sapphire',    category: 'travel',      amount:  -120.00, direction: 'debit',  recurring: false, source: 'Personal/transactions/2026-05.csv', row: 35, importedFrom: 'chase-may.csv' },
    { id: 'TX-2605-035', date: '2026-05-24', merchant: 'Marcus Travel Goal',  description: 'Transfer · travel',   account: 'Savings · Marcus',     category: 'savings',     amount: -200.00,  direction: 'debit',  recurring: true,  source: 'Personal/transactions/2026-05.csv', row: 36, importedFrom: 'chase-may.csv', goal: 'family-travel' },
  ];

  // recurring rules
  const rules = [
    { id: 'rule-rent',     pattern: 'Acme Property Mgmt',  category: 'housing',     cadence: 'monthly', day: 1,  amount: -2400.00, lastApplied: '2026-05-01' },
    { id: 'rule-dca',      pattern: 'Coinbase DCA',        category: 'investments', cadence: 'monthly', day: 1,  amount: -1500.00, lastApplied: '2026-05-01' },
    { id: 'rule-daycare',  pattern: 'Bright Horizons',     category: 'childcare',   cadence: 'monthly', day: 3,  amount: -1450.00, lastApplied: '2026-05-03' },
    { id: 'rule-internet', pattern: 'Comcast Xfinity',     category: 'utilities',   cadence: 'monthly', day: 11, amount:  -89.99,  lastApplied: '2026-05-11' },
    { id: 'rule-insurance',pattern: 'State Farm',          category: 'insurance',   cadence: 'monthly', day: 7,  amount: -408.20,  lastApplied: '2026-05-07' },
    { id: 'rule-emerg',    pattern: 'Marcus Savings',      category: 'savings',     cadence: 'monthly', day: 10, amount: -500.00,  lastApplied: '2026-05-10' },
    { id: 'rule-house',    pattern: 'Marcus House Goal',   category: 'savings',     cadence: 'monthly', day: 10, amount: -400.00,  lastApplied: '2026-05-10' },
  ];

  // ----- Savings goals -----------------------------------------------------
  const goals = [
    {
      id: 'house-down-payment',
      name: 'House Down Payment',
      target: 80000,
      balance: 32450,
      monthlyTarget: 1200,
      monthlyActual: 400,
      targetDate: '2028-06-01',
      status: 'active',
      account: 'Marcus · House Fund',
      note: 'note-strategy-house',
      contributions: [
        { period: '2025-12', amount: 1200 }, { period: '2026-01', amount: 1200 },
        { period: '2026-02', amount: 800 },  { period: '2026-03', amount: 1200 },
        { period: '2026-04', amount: 600 },  { period: '2026-05', amount: 400 },
      ],
      source: 'Savings/goals.csv',
      row: 2,
    },
    {
      id: 'emergency-fund',
      name: 'Emergency Fund',
      target: 24000,
      balance: 21500,
      monthlyTarget: 500,
      monthlyActual: 500,
      targetDate: '2026-12-31',
      status: 'active',
      account: 'Marcus · Emergency',
      note: 'note-strategy-ips',
      contributions: [
        { period: '2025-12', amount: 500 }, { period: '2026-01', amount: 500 },
        { period: '2026-02', amount: 500 }, { period: '2026-03', amount: 500 },
        { period: '2026-04', amount: 500 }, { period: '2026-05', amount: 500 },
      ],
      source: 'Savings/goals.csv',
      row: 3,
    },
    {
      id: 'family-travel',
      name: 'Family Travel',
      target: 6000,
      balance: 2840,
      monthlyTarget: 300,
      monthlyActual: 200,
      targetDate: '2026-12-01',
      status: 'active',
      account: 'Marcus · Travel',
      note: null,
      contributions: [
        { period: '2025-12', amount: 300 }, { period: '2026-01', amount: 300 },
        { period: '2026-02', amount: 200 }, { period: '2026-03', amount: 300 },
        { period: '2026-04', amount: 200 }, { period: '2026-05', amount: 200 },
      ],
      source: 'Savings/goals.csv',
      row: 4,
    },
    {
      id: 'new-macbook',
      name: 'New MacBook',
      target: 3200,
      balance: 1850,
      monthlyTarget: 200,
      monthlyActual: 150,
      targetDate: '2026-09-01',
      status: 'active',
      account: 'Marcus · Gear Fund',
      note: null,
      contributions: [
        { period: '2025-12', amount: 200 }, { period: '2026-01', amount: 200 },
        { period: '2026-02', amount: 200 }, { period: '2026-03', amount: 150 },
        { period: '2026-04', amount: 200 }, { period: '2026-05', amount: 150 },
      ],
      source: 'Savings/goals.csv',
      row: 5,
    },
    {
      id: 'wedding-fund',
      name: 'Wedding Anniversary',
      target: 4000,
      balance: 4000,
      monthlyTarget: 0,
      monthlyActual: 0,
      targetDate: '2025-08-15',
      status: 'archived',
      account: 'Marcus · Travel',
      note: null,
      contributions: [],
      source: 'Savings/goals.csv',
      row: 6,
    },
  ];

  // ----- Investments -------------------------------------------------------
  const investmentAccounts = [
    { id: 'brokerage-main', name: 'Brokerage', institution: 'Fidelity',  type: 'taxable', balance: 184250, tax: 'taxable' },
    { id: 'ira-main',       name: 'IRA',       institution: 'Fidelity',  type: 'ira',     balance:  92480, tax: 'tax-deferred' },
    { id: 'roth-main',      name: 'Roth IRA',  institution: 'Fidelity',  type: 'roth',    balance:  31920, tax: 'tax-free' },
    { id: 'hsa-main',       name: 'HSA',       institution: 'Fidelity',  type: 'hsa',     balance:  18420, tax: 'tax-advantaged' },
    { id: 'cash-marcus',    name: 'Cash',      institution: 'Marcus',    type: 'cash',    balance:  62300, tax: 'taxable' },
  ];

  const sleeves = [
    { id: 'core-growth', name: 'Core Growth',  strategy: 'Index core, broad equity tilt', benchmark: 'S&P 500', monthlyTarget: 1200 },
    { id: 'income',      name: 'Income',       strategy: 'Dividend and bond income',      benchmark: 'AGG',     monthlyTarget: 300 },
    { id: 'thematic',    name: 'Thematic',     strategy: 'Concentrated single-name bets', benchmark: 'S&P 500', monthlyTarget: 0 },
    { id: 'cash',        name: 'Cash & Equiv.', strategy: 'Sweep + Marcus savings',       benchmark: '—',       monthlyTarget: 0 },
  ];

  const holdings = [
    { id: 'h-vti',   ticker: 'VTI',    name: 'Vanguard Total Stock Market', account: 'brokerage-main', sleeve: 'core-growth', qty: 380.4,  price: 286.40, basis: 78420, asset: 'US Equity',  sector: 'Broad' },
    { id: 'h-vxus',  ticker: 'VXUS',   name: 'Vanguard Total International', account: 'brokerage-main', sleeve: 'core-growth', qty: 480.2, price:  64.85, basis: 26420, asset: 'Intl Equity', sector: 'Broad' },
    { id: 'h-nvda',  ticker: 'NVDA',   name: 'NVIDIA Corp',                  account: 'brokerage-main', sleeve: 'thematic',    qty:  12.0, price: 1485.20, basis:  8200, asset: 'US Equity',  sector: 'Tech' },
    { id: 'h-msft',  ticker: 'MSFT',   name: 'Microsoft Corp',               account: 'brokerage-main', sleeve: 'thematic',    qty:  44.0, price:  468.40, basis: 14200, asset: 'US Equity',  sector: 'Tech' },
    { id: 'h-xom',   ticker: 'XOM',    name: 'Exxon Mobil',                  account: 'ira-main',       sleeve: 'income',      qty: 220.0, price:  118.40, basis: 19420, asset: 'US Equity',  sector: 'Energy' },
    { id: 'h-schd',  ticker: 'SCHD',   name: 'Schwab US Dividend Equity',    account: 'ira-main',       sleeve: 'income',      qty: 380.0, price:   82.20, basis: 26200, asset: 'US Equity',  sector: 'Div' },
    { id: 'h-cash',  ticker: 'CASH',   name: 'Cash & Sweep',                 account: 'cash-marcus',    sleeve: 'cash',        qty:   1,   price: 62300,    basis: 62300, asset: 'Cash',       sector: '—' },
  ];

  // sleeve target weights (vs actual)
  const sleeveTargets = [
    { sleeve: 'core-growth', ticker: 'VTI',  target: 0.45, actual: 0.435 },
    { sleeve: 'core-growth', ticker: 'VXUS', target: 0.20, actual: 0.174 },
    { sleeve: 'income',      ticker: 'SCHD', target: 0.10, actual: 0.094 },
    { sleeve: 'income',      ticker: 'XOM',  target: 0.05, actual: 0.077 },
    { sleeve: 'thematic',    ticker: 'NVDA', target: 0.04, actual: 0.052 },
    { sleeve: 'thematic',    ticker: 'MSFT', target: 0.04, actual: 0.057 },
    { sleeve: 'cash',        ticker: 'CASH', target: 0.12, actual: 0.111 },
  ];

  // benchmark series (monthly close, indexed to 100)
  const benchSeries = {
    portfolio: [100, 101.4, 103.1, 102.7, 104.6, 106.8, 108.2, 109.1, 111.4, 113.7, 115.2, 117.8],
    sp500:     [100, 101.2, 102.3, 101.8, 103.4, 105.2, 106.1, 107.3, 109.6, 111.2, 112.3, 114.4],
    labels: ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May'],
  };

  // tax lots for NVDA
  const taxLots = [
    { lotId: 'L-NVDA-001', ticker: 'NVDA', acquired: '2024-09-12', qty: 4, basis: 1820, currentValue: 5940.80, gain: 4120.80, term: 'long' },
    { lotId: 'L-NVDA-002', ticker: 'NVDA', acquired: '2025-01-22', qty: 4, basis: 4180, currentValue: 5940.80, gain: 1760.80, term: 'long' },
    { lotId: 'L-NVDA-003', ticker: 'NVDA', acquired: '2025-11-04', qty: 4, basis: 2200, currentValue: 5940.80, gain: 3740.80, term: 'short' },
  ];

  // ----- Business ----------------------------------------------------------
  const entities = [
    { id: 'consulting-llc', display: 'Consulting LLC', legal: 'Dingwall Consulting LLC',  type: 'LLC',  taxId: '8x-xxx-2241', active: true },
    { id: 'freelance',      display: 'Freelance',      legal: 'Sole Proprietor',          type: 'SP',   taxId: '—',           active: true },
    { id: 'rental-llc',     display: 'Rental LLC',     legal: 'Foothills Rental LLC',     type: 'LLC',  taxId: '—',           active: false },
  ];

  const businessCategories = [
    { id: 'b-saas',     name: 'Software & SaaS',    taxGroup: 'Office expense' },
    { id: 'b-prof',     name: 'Professional fees',  taxGroup: 'Legal & professional' },
    { id: 'b-travel',   name: 'Travel',             taxGroup: 'Travel' },
    { id: 'b-meals',    name: 'Meals',              taxGroup: 'Meals (50%)' },
    { id: 'b-supplies', name: 'Office supplies',    taxGroup: 'Office expense' },
    { id: 'b-bank',     name: 'Bank & fees',        taxGroup: 'Other' },
  ];

  const businessTransactions = [
    { id: 'BX-001', entity: 'consulting-llc', date: '2026-05-02', merchant: 'Atlassian',     description: 'Jira annual',       account: 'Biz Checking', category: 'b-saas',     amount: -680.00,  deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 2  },
    { id: 'BX-002', entity: 'consulting-llc', date: '2026-05-03', merchant: 'Northstar Client', description: 'Invoice 2026-09', account: 'Biz Checking', category: 'income',     amount: 12500.00, deductible: false, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 3  },
    { id: 'BX-003', entity: 'consulting-llc', date: '2026-05-05', merchant: 'Hilton SFO',    description: 'Onsite trip',       account: 'Biz Credit',   category: 'b-travel',   amount: -384.20,  deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 4  },
    { id: 'BX-004', entity: 'consulting-llc', date: '2026-05-06', merchant: 'Brex',          description: 'Bank fee',          account: 'Biz Checking', category: 'b-bank',     amount:  -12.00,  deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 5  },
    { id: 'BX-005', entity: 'consulting-llc', date: '2026-05-09', merchant: 'Carbon CPA',    description: 'Quarterly fee',     account: 'Biz Checking', category: 'b-prof',     amount: -425.00,  deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 6  },
    { id: 'BX-006', entity: 'consulting-llc', date: '2026-05-12', merchant: 'Notion',        description: 'Team plan',         account: 'Biz Credit',   category: 'b-saas',     amount:  -80.00,  deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 7  },
    { id: 'BX-007', entity: 'consulting-llc', date: '2026-05-13', merchant: 'Sushi Den',     description: 'Client dinner',     account: 'Biz Credit',   category: 'b-meals',    amount: -142.00,  deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 8  },
    { id: 'BX-008', entity: 'consulting-llc', date: '2026-05-15', merchant: 'Apple',         description: 'Mac mini · office', account: 'Biz Credit',   category: 'b-supplies', amount: -1320.00, deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 9  },
    { id: 'BX-009', entity: 'consulting-llc', date: '2026-05-18', merchant: 'Linear',        description: 'Team plan',         account: 'Biz Credit',   category: 'b-saas',     amount:  -96.00,  deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 10 },
    { id: 'BX-010', entity: 'consulting-llc', date: '2026-05-20', merchant: 'Northstar Client', description: 'Invoice 2026-10', account: 'Biz Checking', category: 'income',    amount:  4800.00, deductible: false, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 11 },
    { id: 'BX-011', entity: 'consulting-llc', date: '2026-05-22', merchant: 'Delta Air Lines', description: 'Client trip',     account: 'Biz Credit',   category: 'b-travel',   amount: -284.40,  deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 12 },
    { id: 'BX-012', entity: 'consulting-llc', date: '2026-05-25', merchant: 'OpenAI',        description: 'API usage',         account: 'Biz Credit',   category: 'b-saas',     amount:  -184.20, deductible: true, source: 'Business/transactions/consulting-llc-2026-05.csv', row: 13 },
  ];

  const businessBudgets = [
    { entity: 'consulting-llc', category: 'b-saas',     planned: 1100 },
    { entity: 'consulting-llc', category: 'b-prof',     planned:  500 },
    { entity: 'consulting-llc', category: 'b-travel',   planned:  800 },
    { entity: 'consulting-llc', category: 'b-meals',    planned:  300 },
    { entity: 'consulting-llc', category: 'b-supplies', planned:  400 },
    { entity: 'consulting-llc', category: 'b-bank',     planned:   25 },
  ];

  // 12-month business net income series
  const bizSeries = {
    labels: ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May'],
    revenue:  [14200, 11800, 13400, 12200, 16800, 11400, 12800, 13200, 15400, 12800, 14200, 17300],
    expenses: [ 2840,  2120,  3120,  2640,  3220,  2410,  2980,  3140,  2860,  3240,  3010,  3607],
  };

  // ----- Taxes -------------------------------------------------------------
  const estimatedPayments = [
    { id: 'ep-2026-q1', year: 2026, quarter: 1, due: '2026-04-15', amount: 4200, paid: 4200, paidDate: '2026-04-12', jurisdiction: 'Federal', status: 'paid' },
    { id: 'ep-2026-q2', year: 2026, quarter: 2, due: '2026-06-15', amount: 4200, paid: 0,    paidDate: null,         jurisdiction: 'Federal', status: 'upcoming' },
    { id: 'ep-2026-q3', year: 2026, quarter: 3, due: '2026-09-15', amount: 4200, paid: 0,    paidDate: null,         jurisdiction: 'Federal', status: 'upcoming' },
    { id: 'ep-2026-q4', year: 2026, quarter: 4, due: '2027-01-15', amount: 4200, paid: 0,    paidDate: null,         jurisdiction: 'Federal', status: 'upcoming' },
    { id: 'ep-2026-co-q1', year: 2026, quarter: 1, due: '2026-04-15', amount: 720, paid: 720, paidDate: '2026-04-12', jurisdiction: 'Colorado', status: 'paid' },
    { id: 'ep-2026-co-q2', year: 2026, quarter: 2, due: '2026-06-15', amount: 720, paid: 0,   paidDate: null,         jurisdiction: 'Colorado', status: 'upcoming' },
  ];

  const realizedGains = [
    { id: 'rg-001', ticker: 'AAPL', closed: '2026-02-18', term: 'long',  proceeds: 8420, basis: 6120, gain: 2300, source: 'Investments/transactions.csv', row: 142 },
    { id: 'rg-002', ticker: 'TSLA', closed: '2026-03-04', term: 'short', proceeds: 4180, basis: 4880, gain: -700, source: 'Investments/transactions.csv', row: 148 },
    { id: 'rg-003', ticker: 'NVDA', closed: '2026-04-22', term: 'long',  proceeds: 6240, basis: 1820, gain: 4420, source: 'Investments/transactions.csv', row: 161 },
  ];

  const incomeSummary = [
    { kind: 'Dividends · qualified',     ytd: 1280, source: 'Investments/dividends.csv' },
    { kind: 'Dividends · ordinary',      ytd:  420, source: 'Investments/dividends.csv' },
    { kind: 'Interest · savings',        ytd:  840, source: 'Personal/transactions/*.csv' },
    { kind: 'Interest · treasury bills', ytd:  610, source: 'Investments/dividends.csv' },
  ];

  const taxChecklist = [
    { id: 'tc-1', label: '1099-DIV from Fidelity',           done: true,  due: 'Jan',  note: 'Verified · matches dividends.csv' },
    { id: 'tc-2', label: '1099-B from Fidelity',             done: true,  due: 'Feb',  note: 'Matches realized-gains projection' },
    { id: 'tc-3', label: 'Consulting LLC P&L summary',       done: false, due: 'Mar',  note: 'Pending May close' },
    { id: 'tc-4', label: 'Q2 federal estimated payment',     done: false, due: 'Jun 15' },
    { id: 'tc-5', label: 'Mileage log · Consulting LLC',     done: false, due: 'Mar' },
    { id: 'tc-6', label: 'Charitable contribution receipts', done: true,  due: 'Mar' },
    { id: 'tc-7', label: 'HSA contribution confirmation',    done: true,  due: 'Apr' },
  ];

  // ----- Notes -------------------------------------------------------------
  const notes = [
    {
      id: 'note-may-2026-review',
      title: 'May Monthly Review',
      type: 'monthly-review',
      period: '2026-05',
      tags: ['monthly-close'],
      path: 'Notes/monthly/2026-05-review.md',
      created: '2026-05-11',
      updated: '2026-05-11',
      frontMatter: {
        type: 'monthly-review',
        note_id: 'note-2026-05-review',
        period: '2026-05',
        entity_ids: ['consulting-llc'],
        account_ids: ['checking-main', 'brokerage-main'],
        goal_ids: ['house-down-payment', 'emergency-fund'],
        tags: ['monthly-close'],
        schema_version: 1,
      },
      body: `# May 2026 Monthly Review

## Cash flow
Net cash flow this month came in at **+$2,140**, slightly above target. Income held steady at $9,651 across two pay cycles, with no out-of-cycle deposits.

## Budget variance
- **Travel** is **+$364** over plan, driven by the Aspen weekend booking and a hiking pack from REI.
- **Groceries** is **+$78** over plan — three weekends of larger trips. Not concerning yet.
- **Dining** came in flat. No changes needed.

## Savings progress
- House Down Payment funded at $400 vs $1,200 target. Family travel pulled extra. Plan to catch up in June.
- Emergency Fund hit its monthly $500 target as usual.

## Investments
DCA into VTI ran cleanly on the 1st. Sleeve drift on \`income\` reached +2.7% — flagging for the next rebalance window.

## Issues this month
> 8 open issues. 5 are repairable (header casing, missing schema markers). 3 need manual review including one duplicate transaction.

## Action items
- Catch up on House Down Payment in June.
- Review tax-lot ID L-NVDA-003 — short term, may want to defer trim.
- Resolve duplicate transaction TX-2605-026 / TX-2605-011.`,
    },
    {
      id: 'note-strategy-ips',
      title: 'Investment Policy Statement',
      type: 'strategy',
      period: null,
      tags: ['investments', 'strategy'],
      path: 'Notes/strategy/ips.md',
      created: '2025-11-04',
      updated: '2026-03-22',
      frontMatter: {
        type: 'strategy',
        note_id: 'note-ips',
        sleeve_ids: ['core-growth', 'income', 'thematic'],
        tags: ['investments', 'strategy'],
        schema_version: 1,
      },
      body: `# Investment Policy Statement

## Objective
Compound household net worth at a long-term real rate of ~5% with moderate volatility tolerance.

## Allocation framework
- **Core Growth** — 65% target. Broad equity index exposure (VTI, VXUS).
- **Income** — 15% target. Dividend equities and short-duration bonds.
- **Thematic** — 8% target. Concentrated single-name conviction (NVDA, MSFT). Capped at 10%.
- **Cash** — 12% target. Emergency fund + opportunistic cash.

## Rebalance rules
- Reset to target weights when any sleeve drifts more than **5 percentage points**.
- Single names capped at **6%** of total portfolio.
- Prefer tax-advantaged rebalancing first.

## Withdrawal posture
No withdrawals planned through 2032. Down-payment goal funded from cash sleeve, not equities.`,
    },
    {
      id: 'note-strategy-tax',
      title: 'Tax Strategy',
      type: 'tax-note',
      period: null,
      tags: ['taxes', 'strategy'],
      path: 'Notes/strategy/tax-strategy.md',
      created: '2026-01-08',
      updated: '2026-04-18',
      frontMatter: {
        type: 'tax-note',
        note_id: 'note-tax-strategy',
        tax_year: 2026,
        tags: ['taxes', 'strategy'],
        schema_version: 1,
      },
      body: `# Tax Strategy 2026

## Estimated payments
Hold the prior-year safe harbor approach: 110% of 2025 federal liability split into 4 equal quarters. Colorado follows federal cadence.

## Asset location
- Dividend-heavy holdings (SCHD, XOM) → IRA.
- Broad index exposure → taxable, for foreign tax credit eligibility (VXUS).
- Single-name concentrated bets → taxable for tax-loss harvest flexibility.

## Realization plan
Target **<$5,000 net realized short-term gains** in 2026. Long-term realizations are fine up to the 15% bracket cap.

## Open questions
- Consulting LLC: confirm S-corp election value vs current pass-through. Decision deadline March 2027.
- Charitable contribution bunching for 2027.`,
    },
    {
      id: 'note-business-strategy',
      title: 'Business Strategy · Consulting LLC',
      type: 'business-review',
      period: null,
      tags: ['business', 'strategy'],
      path: 'Notes/strategy/business-strategy.md',
      created: '2026-02-14',
      updated: '2026-04-30',
      frontMatter: {
        type: 'business-review',
        note_id: 'note-biz-strategy',
        entity_ids: ['consulting-llc'],
        tags: ['business', 'strategy'],
        schema_version: 1,
      },
      body: `# Consulting LLC Strategy

## Engagement mix
Maintain 1 anchor client (Northstar) at ~60% of revenue, with 2-3 smaller engagements filling capacity. Avoid letting any single client exceed 70% of trailing-quarter revenue.

## Pricing
- Hourly floor: **$220/hr**. Discount only for >100hr engagements.
- Fixed-bid projects: require **20% deposit**.

## Cost discipline
Keep SaaS subscriptions under **$1,200/mo** total. Audit quarterly. Today's run-rate (~$960) is healthy.

## Tax posture
- Track meals separately for 50% deductibility.
- Maintain mileage log monthly.
- Quarterly federal+state estimateds on the 15th of Apr/Jun/Sep/Jan.`,
    },
    {
      id: 'note-april-2026-review',
      title: 'April Monthly Review',
      type: 'monthly-review',
      period: '2026-04',
      tags: ['monthly-close'],
      path: 'Notes/monthly/2026-04-review.md',
      created: '2026-04-30',
      updated: '2026-04-30',
      frontMatter: {
        type: 'monthly-review',
        note_id: 'note-2026-04-review',
        period: '2026-04',
        schema_version: 1,
      },
      body: `# April 2026 Monthly Review

## Summary
Quiet month. Q1 estimated tax payment cleared on the 12th. No anomalies in budget categories.

## Notes
- Realized $4,420 long-term gain on NVDA trim.
- Family travel funding slipped — caught it for May plan.`,
    },
  ];

  // ----- Issues ------------------------------------------------------------
  const issues = [
    {
      id: 'iss-001',
      severity: 'error',
      group: 'Schema',
      title: 'Missing required column',
      message: '`subcategory_id` column is missing.',
      file: 'Personal/transactions/2026-03.csv',
      filePath: 'Personal/transactions/2026-03.csv',
      row: null,
      repairable: true,
      kind: 'missing-optional-column',
      preview: { add: '+ subcategory_id', context: 'transaction_id,date,account_id,merchant,description,amount,direction,category_id,subcategory_id,...' },
      repairPreview: {
        before: 'transaction_id,date,account_id,merchant,description,amount,direction,category_id',
        after:  'transaction_id,date,account_id,merchant,description,amount,direction,category_id,subcategory_id',
      },
    },
    {
      id: 'iss-002',
      severity: 'error',
      group: 'References',
      title: 'Duplicate transaction ID',
      message: '`TX-2605-026` collides with `TX-2605-011`.',
      file: 'Personal/transactions/2026-05.csv',
      filePath: 'Personal/transactions/2026-05.csv',
      row: 27,
      repairable: false,
      kind: 'duplicate-id',
      preview: null,
      repairPreview: null,
    },
    {
      id: 'iss-003',
      severity: 'warning',
      group: 'References',
      title: 'Unknown category reference',
      message: '`category_id = food` not found in `Personal/categories.csv`. Did you mean `dining`?',
      file: 'Personal/transactions/2026-04.csv',
      filePath: 'Personal/transactions/2026-04.csv',
      row: 18,
      repairable: false,
      kind: 'unknown-reference',
      preview: null,
      repairPreview: null,
    },
    {
      id: 'iss-004',
      severity: 'warning',
      group: 'Notes',
      title: 'Orphan note link',
      message: 'Note `note-2026-05-review.md` references `goal_id = vacation-2026` which does not exist.',
      file: 'Notes/monthly/2026-05-review.md',
      filePath: 'Notes/monthly/2026-05-review.md',
      row: null,
      repairable: false,
      kind: 'orphan-link',
      preview: null,
      repairPreview: null,
    },
    {
      id: 'iss-005',
      severity: 'info',
      group: 'Schema',
      title: 'Header casing mismatch',
      message: '`Account_ID` should be `account_id`.',
      file: 'Investments/holdings.csv',
      filePath: 'Investments/holdings.csv',
      row: 1,
      repairable: true,
      kind: 'header-casing',
      preview: { del: '- Account_ID', add: '+ account_id' },
      repairPreview: {
        before: 'Account_ID,ticker,name,qty,price,basis,asset,sector',
        after:  'account_id,ticker,name,qty,price,basis,asset,sector',
      },
    },
    {
      id: 'iss-006',
      severity: 'error',
      group: 'Files',
      title: 'Missing benchmark data',
      message: '`Investments/benchmarks/sp500.csv` ends 2026-04-30. May closes are missing.',
      file: 'Investments/benchmarks/sp500.csv',
      filePath: 'Investments/benchmarks/sp500.csv',
      row: null,
      repairable: false,
      kind: 'missing-data',
      preview: null,
      repairPreview: null,
    },
    {
      id: 'iss-007',
      severity: 'warning',
      group: 'Schema',
      title: 'Missing schema version marker',
      message: '`schema_version` is missing from front matter.',
      file: 'Notes/strategy/business-strategy.md',
      filePath: 'Notes/strategy/business-strategy.md',
      row: null,
      repairable: true,
      kind: 'missing-schema-version',
      preview: { add: '+ schema_version: 1' },
      repairPreview: {
        before: 'type: business-review\nnote_id: note-biz-strategy\nentity_ids: [consulting-llc]',
        after:  'type: business-review\nnote_id: note-biz-strategy\nentity_ids: [consulting-llc]\nschema_version: 1',
      },
    },
    {
      id: 'iss-008',
      severity: 'warning',
      group: 'References',
      title: 'Zero-amount transaction',
      message: '`TX-2605-022` has amount = 0.00. Likely placeholder for a future renewal.',
      file: 'Personal/transactions/2026-05.csv',
      filePath: 'Personal/transactions/2026-05.csv',
      row: 23,
      repairable: false,
      kind: 'zero-amount',
      preview: null,
      repairPreview: null,
    },
  ];

  // ----- Accounts (master registry) ----------------------------------------
  const accounts = [
    { id: 'checking-main',   name: 'Chase Checking',     institution: 'Chase',    group: 'Everyday Banking', type: 'checking',  monthlyInflow: 9651,  ytdNetIncome: 52080 },
    { id: 'savings-marcus',  name: 'Marcus Savings',     institution: 'Marcus',   group: 'Everyday Banking', type: 'savings',   monthlyInflow: 200,   ytdNetIncome: 840 },
    { id: 'credit-sapphire', name: 'Chase Sapphire',     institution: 'Chase',    group: 'Credit Cards',     type: 'credit',    monthlyInflow: 0,     ytdNetIncome: 0 },
    { id: 'brokerage-main',  name: 'Fidelity Brokerage', institution: 'Fidelity', group: 'Investments',      type: 'brokerage', monthlyInflow: 1500,  ytdNetIncome: 10420 },
    { id: 'ira-main',        name: 'Fidelity IRA',       institution: 'Fidelity', group: 'Investments',      type: 'ira',       monthlyInflow: 0,     ytdNetIncome: 4820 },
    { id: 'biz-checking',    name: 'Brex Checking',      institution: 'Brex',     group: 'Business',         type: 'checking',  monthlyInflow: 17300, ytdNetIncome: 13693 },
  ];

  // ----- iCloud workspace states -------------------------------------------
  const iCloudStates = [
    { id: 'available',             label: 'Available',             icon: '✅', description: 'iCloud Drive is available and your workspace files are syncing normally.',                   recoveryAction: null },
    { id: 'not-signed-in',         label: 'Not Signed In',         icon: '🔒', description: 'You are not signed into iCloud. Sign in via System Settings to enable workspace sync.',       recoveryAction: 'Open iCloud Settings' },
    { id: 'container-unavailable', label: 'Container Unavailable', icon: '⚠️', description: 'The iCloud container for this app could not be accessed. This may be a temporary service outage.', recoveryAction: 'Retry' },
    { id: 'syncing',               label: 'Syncing',               icon: '🔄', description: 'Workspace files are actively syncing with iCloud Drive. Changes may not be visible yet.',   recoveryAction: null },
    { id: 'local-copy-stale',      label: 'Local Copy Stale',      icon: '🕐', description: 'Your local copy has not been updated recently. iCloud may have newer versions of some files.', recoveryAction: 'Force sync' },
    { id: 'file-missing-locally',  label: 'File Missing Locally',  icon: '☁️', description: 'One or more workspace files exist in iCloud but have not been downloaded to this device.',  recoveryAction: 'Download now' },
    { id: 'conflict-detected',     label: 'Conflict Detected',     icon: '⚡', description: 'A sync conflict was detected. Two versions of a file exist and need to be resolved.',        recoveryAction: 'Resolve conflict' },
    { id: 'workspace-created',     label: 'Workspace Ready',       icon: '🎉', description: 'Your Finance workspace was created successfully. All folder structure is ready to use.',     recoveryAction: 'Start using app' },
  ];

  // ----- Benchmark return data (heat map) ----------------------------------
  const benchmarkPeriods = ['D', 'W', 'M', '3M', '6M', '1Y', '3Y', '5Y'];

  const benchmarkReturns = [
    {
      accountId: 'brokerage-main',
      label: 'Brokerage',
      returns: { D: 0.0042, W: 0.0118, M: 0.0214, '3M': 0.0486, '6M': 0.0823, '1Y': 0.178, '3Y': 0.412, '5Y': 0.724 },
    },
    {
      accountId: 'ira-main',
      label: 'IRA',
      returns: { D: 0.0038, W: 0.0094, M: 0.0180, '3M': 0.0410, '6M': 0.0762, '1Y': 0.156, '3Y': 0.384, '5Y': 0.689 },
    },
    {
      accountId: 'roth-main',
      label: 'Roth IRA',
      returns: { D: 0.0051, W: 0.0142, M: 0.0268, '3M': 0.0612, '6M': 0.0940, '1Y': 0.192, '3Y': null,  '5Y': null },
    },
    {
      accountId: 'hsa-main',
      label: 'HSA',
      returns: { D: -0.0012, W: 0.0038, M: 0.0091, '3M': 0.0220, '6M': 0.0480, '1Y': 0.114, '3Y': null, '5Y': null },
    },
    {
      accountId: 'sp500',
      label: 'S&P 500',
      returns: { D: 0.0031, W: 0.0087, M: 0.0162, '3M': 0.0384, '6M': 0.0714, '1Y': 0.144, '3Y': 0.328, '5Y': 0.618 },
    },
  ];

  // ----- Tax deductions -----------------------------------------------------
  const deductions = [
    { id: 'ded-std-federal',  type: 'standard',   name: 'Federal Standard Deduction',   estimatedAmount: 14600, status: 'confirmed' },
    { id: 'ded-std-colorado', type: 'standard',   name: 'Colorado Standard Deduction',  estimatedAmount: 14600, status: 'confirmed' },
    { id: 'ded-ira',          type: 'above-line', name: 'Traditional IRA Contribution', estimatedAmount: 7000,  status: 'confirmed' },
    { id: 'ded-hsa',          type: 'above-line', name: 'HSA Contribution',             estimatedAmount: 4150,  status: 'confirmed' },
    { id: 'ded-stl',          type: 'above-line', name: 'Student Loan Interest',        estimatedAmount: 0,     status: 'estimated' },
    { id: 'ded-salt',         type: 'schedule-a', name: 'State & Local Taxes (SALT)',   estimatedAmount: 8400,  status: 'estimated' },
    { id: 'ded-charitable',   type: 'schedule-a', name: 'Charitable Contributions',     estimatedAmount: 1200,  status: 'confirmed' },
    { id: 'ded-mortgage',     type: 'schedule-a', name: 'Mortgage Interest',            estimatedAmount: 0,     status: 'missing' },
    { id: 'ded-homeofc',      type: 'schedule-c', name: 'Home Office Deduction',        estimatedAmount: 2640,  status: 'estimated' },
    { id: 'ded-vehicle',      type: 'schedule-c', name: 'Vehicle Mileage (Business)',   estimatedAmount: 1840,  status: 'estimated' },
    { id: 'ded-software',     type: 'schedule-c', name: 'Software & Subscriptions',     estimatedAmount: 1040,  status: 'confirmed' },
    { id: 'ded-meals-biz',    type: 'schedule-c', name: 'Business Meals (50%)',         estimatedAmount: 426,   status: 'estimated' },
  ];

  // ----- Per-account effective tax rates -----------------------------------
  const accountTaxRates = [
    { accountId: 'checking-main',  accountName: 'Chase Checking',      taxableIncome: 96502, taxesPaid: 16800, taxesOwed: 19120, effectiveRate: 0.198 },
    { accountId: 'brokerage-main', accountName: 'Fidelity Brokerage',  taxableIncome: 18240, taxesPaid: 0,     taxesOwed: 2736,  effectiveRate: 0.150 },
    { accountId: 'ira-main',       accountName: 'Fidelity IRA',        taxableIncome: 0,     taxesPaid: 0,     taxesOwed: 0,     effectiveRate: 0.0   },
    { accountId: 'roth-main',      accountName: 'Fidelity Roth IRA',   taxableIncome: 0,     taxesPaid: 0,     taxesOwed: 0,     effectiveRate: 0.0   },
    { accountId: 'biz-checking',   accountName: 'Brex Checking (LLC)', taxableIncome: 52800, taxesPaid: 8400,  taxesOwed: 9840,  effectiveRate: 0.186 },
  ];

  // ----- Overview trend series --------------------------------------------
  const overview = {
    cashFlow: { value: 2140, change: 0.18 },
    budgetVariance: { value: 320, change: 0.04, direction: 'over' },
    savingsProgress: { value: 0.61, change: 0.03 },
    portfolioValue: { value: 389370, change: 0.012 },
    businessNetIncome: { value: 13693, change: 0.07 },
    taxStatus: { value: 'On track', subtle: 'Q2 due Jun 15' },
    issueCount: { value: 8, change: 0 },
    netWorth:    [318000, 322500, 326800, 327400, 332100, 338200, 341600, 346800, 354200, 361800, 366400, 374940],
    cashFlowSeries: [
      { period: 'Jun', net:  1280 }, { period: 'Jul', net:  1420 }, { period: 'Aug', net:  1860 },
      { period: 'Sep', net:   900 }, { period: 'Oct', net:  1500 }, { period: 'Nov', net:  1180 },
      { period: 'Dec', net:  1640 }, { period: 'Jan', net:  2010 }, { period: 'Feb', net:  1800 },
      { period: 'Mar', net:  1320 }, { period: 'Apr', net:  1880 }, { period: 'May', net:  2140 },
    ],
    recentActivity: [
      { item: 'May rent payment posted',                domain: 'Personal',    status: 'Imported',  due: '—',         ref: { kind: 'transaction', id: 'TX-2605-001' } },
      { item: 'Q1 federal estimated payment cleared',   domain: 'Taxes',       status: 'Done',      due: '—',         ref: { kind: 'estimatedPayment', id: 'ep-2026-q1' } },
      { item: 'Duplicate transaction flagged',          domain: 'Issues',      status: 'Open',      due: 'Review',    ref: { kind: 'issue', id: 'iss-002' } },
      { item: 'Sleeve drift on Income > 2.5%',          domain: 'Investments', status: 'Watching',  due: '—',         ref: { kind: 'sleeve', id: 'income' } },
      { item: 'May monthly review note saved',          domain: 'Notes',       status: 'Updated',   due: '—',         ref: { kind: 'note', id: 'note-may-2026-review' } },
      { item: 'Travel category over plan',              domain: 'Personal',    status: 'Over',      due: '—',         ref: { kind: 'category', id: 'travel' } },
      { item: 'Q2 federal estimated payment due',       domain: 'Taxes',       status: 'Upcoming',  due: 'Jun 15',    ref: { kind: 'estimatedPayment', id: 'ep-2026-q2' } },
      { item: 'Header casing fix available',            domain: 'Issues',      status: 'Repairable',due: '—',         ref: { kind: 'issue', id: 'iss-005' } },
    ],
  };

  return {
    workspace,
    categories,
    transactions,
    rules,
    goals,
    investmentAccounts,
    sleeves,
    holdings,
    sleeveTargets,
    benchSeries,
    taxLots,
    entities,
    businessCategories,
    businessTransactions,
    businessBudgets,
    bizSeries,
    estimatedPayments,
    realizedGains,
    incomeSummary,
    taxChecklist,
    notes,
    issues,
    overview,
    accounts,
    iCloudStates,
    benchmarkPeriods,
    benchmarkReturns,
    deductions,
    accountTaxRates,
  };
})();
