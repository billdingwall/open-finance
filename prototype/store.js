/* =========================================================
   Finance Workspace · Prototype persistence layer
   Mirrors the app's "files are the source of truth" model with
   localStorage standing in for the iCloud workspace. The seed in
   data.js is the template; user edits made in the prototype
   (adds, imports, repairs, checklist toggles) are layered on top
   and survive a page refresh until explicitly reset.
   ========================================================= */

const Store = (() => {
  const KEY = 'finance-proto-workspace-v1';

  // Collections a user can mutate through the prototype UI. Everything
  // else (chart series, benchmark math, iCloud state defs) stays seeded.
  const PERSIST_KEYS = [
    'goals', 'transactions', 'categories', 'rules', 'accounts', 'accountGroups',
    'estimatedPayments', 'taxAdjustments', 'taxChecklist', 'issues', 'assets',
    'sleeves', 'sleeveTargets', 'notes', 'businessCategories', 'businessBudgets',
    'liabilities', 'portfolios',
  ];

  function syncDerived() {
    // businessTransactions is a derived projection of the unified ledger:
    // every business-entity transaction carries a BX- id prefix.
    DATA.businessTransactions = DATA.transactions.filter(t => /^BX-/.test(t.id));
  }

  function hydrate() {
    if (typeof DATA === 'undefined') return false;
    let saved = null;
    try { saved = JSON.parse(localStorage.getItem(KEY)); } catch (_) { saved = null; }
    if (saved && typeof saved === 'object') {
      for (const k of PERSIST_KEYS) {
        if (Array.isArray(saved[k])) DATA[k] = saved[k];
      }
    }
    syncDerived();
    return !!saved;
  }

  function save() {
    syncDerived();
    const payload = {};
    for (const k of PERSIST_KEYS) payload[k] = DATA[k];
    try {
      localStorage.setItem(KEY, JSON.stringify(payload));
      return true;
    } catch (_) {
      return false;
    }
  }

  function reset() {
    try { localStorage.removeItem(KEY); } catch (_) {}
    location.reload();
  }

  function isDirty() {
    try { return localStorage.getItem(KEY) != null; } catch (_) { return false; }
  }

  return { hydrate, save, reset, isDirty, syncDerived, KEY };
})();

Store.hydrate();
