/* =========================================================
   Finance Workspace · Prototype
   Static client-side app. No backend.
   ========================================================= */

// ---------- Utilities --------------------------------------------------------

const $ = (sel, root = document) => root.querySelector(sel);

const el = (tag, attrs = {}, children = []) => {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null || v === false) continue;
    if (k === 'class') node.className = v;
    else if (k === 'html') node.innerHTML = v;
    else if (k === 'text') node.textContent = v;
    else if (k.startsWith('on') && typeof v === 'function') {
      node.addEventListener(k.slice(2).toLowerCase(), v);
    } else if (k === 'dataset') {
      for (const [dk, dv] of Object.entries(v)) node.dataset[dk] = dv;
    } else if (k === 'style' && typeof v === 'object') {
      Object.assign(node.style, v);
    } else {
      node.setAttribute(k, v);
    }
  }
  for (const c of [].concat(children)) {
    if (c == null || c === false) continue;
    if (typeof c === 'string' || typeof c === 'number') node.appendChild(document.createTextNode(String(c)));
    else node.appendChild(c);
  }
  return node;
};

const fmtUSD = (n, opts = {}) => {
  const { sign = false, dp = 0 } = opts;
  if (n == null || Number.isNaN(n)) return '—';
  const abs = Math.abs(n);
  const formatted = abs.toLocaleString('en-US', { minimumFractionDigits: dp, maximumFractionDigits: dp });
  if (sign && n > 0) return `+$${formatted}`;
  if (n < 0) return `−$${formatted}`;
  return `$${formatted}`;
};
const fmtUSD2 = (n) => fmtUSD(n, { dp: 2 });
const fmtPct = (n, dp = 1) => {
  if (n == null || Number.isNaN(n)) return '—';
  return `${(n * 100).toFixed(dp)}%`;
};
const fmtPctSigned = (n, dp = 1) => {
  if (n == null || Number.isNaN(n)) return '—';
  const v = (n * 100).toFixed(dp);
  if (n > 0) return `+${v}%`;
  if (n < 0) return `${v}%`;
  return `${v}%`;
};
const fmtNum = (n) => n == null ? '—' : n.toLocaleString('en-US');
const fmtDate = (iso) => {
  if (!iso) return '—';
  const d = new Date(iso + 'T12:00:00');
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
};
const fmtDateLong = (iso) => {
  if (!iso) return '—';
  const d = new Date(iso + 'T12:00:00');
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
};

const cats = () => Object.fromEntries(DATA.categories.map(c => [c.id, c]));
const acctById = () => Object.fromEntries(DATA.investmentAccounts.map(a => [a.id, a]));
const sleeveById = () => Object.fromEntries(DATA.sleeves.map(s => [s.id, s]));
const entityById = () => Object.fromEntries(DATA.entities.map(e => [e.id, e]));
const bizCatById = () => Object.fromEntries(DATA.businessCategories.map(c => [c.id, c]));
const goalById = () => Object.fromEntries(DATA.goals.map(g => [g.id, g]));

// ---------- State ------------------------------------------------------------

const state = {
  view: 'overview-dashboard',
  selection: null, // { kind, id }
  filters: {
    'budget-overview':       { period: '2026-05', account: 'all', category: 'all', search: '' },
    'budget-history':        { },
    'savings-goals':         { search: '' },
    'investments-portfolio': { account: 'all', sleeve: 'all', assetClass: 'all' },
    'investments-holdings':  { account: 'all', sleeve: 'all', search: '' },
    'business-entity':       { entity: 'consulting-llc', period: '2026-05' },
    'taxes-current':         { year: 2026 },
    'accounts-overview':     { },
    'savings-investments':   { },
    'taxes-checklist':       { year: 2026 },
    'overview-dashboard':    { period: '2026-05' },
  },
  overviewKpi: 'budget',
  holdingsMode: 'standard', // 'standard' | 'heatmap' — holdings table view toggle
  navCollapsed: new Set(),
  syncState: 'synced',
  inspectorOpen: false,
  searchQuery: {}, // persists active search query per view across commit() re-renders
};

// ---------- Sidebar ----------------------------------------------------------

const NAV = [
  { id: 'accounts', label: 'Accounts', items: [
    { id: 'accounts-overview', label: 'All Accounts' },
  ]},
  { id: 'budget', label: 'Budget', items: [
    { id: 'budget-overview',    label: 'Overview' },
    { id: 'budget-history',     label: 'Budget History' },
    { id: 'budget-categories',  label: 'Categories' },
  ]},
  { id: 'savings-investments', label: 'Savings & Investments', items: [
    { id: 'savings-goals',            label: 'Goals', badge: String(DATA.goals.length) },
    { id: 'investments-portfolio',    label: 'Portfolio Overview' },
    { id: 'investments-holdings',     label: 'Holdings' },
  ]},
  { id: 'taxes', label: 'Taxes', items: [
    { id: 'taxes-current',    label: 'Current Tax Year' },
    { id: 'taxes-checklist',  label: 'Prep Checklist' },
    { id: 'taxes-archive',    label: 'Tax Archive' },
  ]},
  { id: 'settings', label: 'Settings', items: [
    { id: 'settings-workspace', label: 'Workspace' },
    { id: 'settings-schema',    label: 'Schema' },
  ]},
];

function renderSidebar() {
  const pill = document.getElementById('sync-pill');
  if (pill) {
    pill.dataset.state = state.syncState;
    const labels = { synced: 'Synced', syncing: 'Syncing…', stale: 'Stale', error: 'Sync error' };
    const labelEl = pill.querySelector('.sync-pill-label');
    if (labelEl) labelEl.textContent = labels[state.syncState] || state.syncState;
  }
  const head = document.getElementById('sidebar-head');
  if (head) head.classList.toggle('active', state.view === 'overview-dashboard');
  const root = $('#sidebar-nav');
  root.innerHTML = '';
  for (const group of NAV) {
    const collapsed = state.navCollapsed.has(group.id);
    const groupNode = el('div', { class: 'nav-group' + (collapsed ? ' collapsed' : '') }, [
      el('div', {
        class: 'nav-group-head',
        onclick: () => {
          if (state.navCollapsed.has(group.id)) state.navCollapsed.delete(group.id);
          else state.navCollapsed.add(group.id);
          renderSidebar();
        }
      }, [
        el('span', { text: group.label }),
        el('span', { class: 'nav-group-caret' }),
      ]),
      el('div', { class: 'nav-items' }, (group.id === 'accounts' ? [
        { id: 'accounts-overview', label: 'All Accounts' },
        ...DATA.entities.filter(e => e.active).map(e => ({ id: `accounts-entity-${e.id}`, label: e.display }))
      ] : group.items).map(item => {
        const active = state.view === item.id;
        const badge = item.id === 'savings-goals' ? (DATA.goals.length ? String(DATA.goals.length) : null) : item.badge;
        return el('div', {
          class: 'nav-item' + (active ? ' active' : ''),
          onclick: () => navigate(item.id),
        }, [
          el('span', { text: item.label }),
          badge ? el('span', { class: 'badge', text: badge }) : null,
        ]);
      })),
    ]);
    root.appendChild(groupNode);
  }
}

// ---------- Navigation -------------------------------------------------------

function navigate(viewId) {
  closeInspector();
  state.view = viewId;
  state.selection = null;

  const url = new URL(window.location);
  url.searchParams.set('view', viewId);
  window.history.pushState({}, '', url);

  renderSidebar();
  renderCenter();
}

function openInspector(kind, id) {
  state.selection = { kind, id };
  state.inspectorOpen = true;
  const insp = document.getElementById('inspector');
  if (insp) insp.classList.add('inspector-open');
  const backdrop = document.getElementById('inspector-backdrop');
  if (backdrop) backdrop.style.display = 'block';
  renderCenter();
  renderInspector();
}

function closeInspector() {
  state.selection = null;
  state.inspectorOpen = false;
  const insp = document.getElementById('inspector');
  if (insp) insp.classList.remove('inspector-open');
  const backdrop = document.getElementById('inspector-backdrop');
  if (backdrop) backdrop.style.display = 'none';
}

// ---------- Filter bar -------------------------------------------------------

// The contextual filter bar is removed for MVP (Round 5) and deferred to V2.
// Kept as a no-op so existing per-view calls remain harmless.
function renderFilterBar(_filters) {
  const bar = $('#filter-bar');
  if (bar) { bar.innerHTML = ''; bar.style.display = 'none'; }
}

// ---------- Header helpers ---------------------------------------------------

function setHeader({ title, breadcrumb, actions }) {
  $('#page-title').textContent = title;
  const bc = $('#breadcrumb');
  bc.innerHTML = '';
  breadcrumb.forEach((b, i) => {
    if (i > 0) bc.appendChild(el('span', { class: 'crumb-sep', text: '›' }));
    bc.appendChild(el('span', { class: 'crumb', text: b }));
  });

  const actionsEl = $('#local-actions');
  actionsEl.innerHTML = '';
  for (const a of actions || []) {
    actionsEl.appendChild(el('button', { class: 'btn ' + (a.variant || ''), onclick: a.onClick || (()=>{}) }, [
      a.label,
    ]));
  }
  $('#issue-count').textContent = DATA.issues.length;
}

// ---------- Charts (Chart.js) ------------------------------------------------
// Chart helpers emit a sized <canvas> placeholder and queue a Chart.js config.
// renderCenter() destroys live instances before a re-render and flushes the
// queue after the new DOM is in place (canvases must be attached first).

let __chartSeq = 0;
const __chartQueue = [];
const __chartInstances = [];

const CHART_INK = '#3651d3';
const CHART_MUTE = '#94a3b8';
const CHART_NEG = '#b91c1c';
const CHART_GRID = 'rgba(148,163,184,0.20)';

function destroyCharts() {
  while (__chartInstances.length) { try { __chartInstances.pop().destroy(); } catch (_) {} }
  __chartQueue.length = 0;
}

function flushCharts() {
  if (typeof Chart === 'undefined') return;
  while (__chartQueue.length) {
    const spec = __chartQueue.shift();
    const cv = document.getElementById(spec.id);
    if (!cv) continue;
    try { __chartInstances.push(new Chart(cv.getContext('2d'), spec.config)); }
    catch (e) { console.error('chart render failed', e); }
  }
}

function queueChart(config, { height = 200, width = null } = {}) {
  const id = 'chart-' + (++__chartSeq);
  __chartQueue.push({ id, config });
  const wstyle = width ? `width:${width}px;` : '';
  return `<div class="chart-canvas" style="height:${height}px;${wstyle}"><canvas id="${id}"></canvas></div>`;
}

function shortNum(v) {
  if (Math.abs(v) >= 1000000) return (v / 1000000).toFixed(1) + 'M';
  if (Math.abs(v) >= 1000) return (v / 1000).toFixed(0) + 'k';
  if (Math.abs(v) >= 100) return v.toFixed(0);
  return v.toFixed(1);
}

function baseAxisOptions() {
  return {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { mode: 'index', intersect: false },
    plugins: { legend: { display: false }, tooltip: { enabled: true } },
    scales: {
      x: { grid: { display: false }, ticks: { color: CHART_MUTE, font: { size: 10 } } },
      y: { grid: { color: CHART_GRID, drawBorder: false }, ticks: { color: CHART_MUTE, font: { size: 10 }, callback: v => shortNum(v) } },
    },
  };
}

function lineChart(series, opts = {}) {
  const { labels = [], colors = [CHART_INK], dashed = [], height = 200 } = opts;
  const datasets = series.map((s, i) => ({
    data: s,
    borderColor: colors[i] || CHART_MUTE,
    backgroundColor: 'transparent',
    borderWidth: 1.75,
    borderDash: dashed[i] ? [4, 4] : [],
    pointRadius: 2.2,
    pointBackgroundColor: colors[i] || CHART_MUTE,
    tension: 0.25,
  }));
  const lbls = labels.length ? labels : (series[0] || []).map((_, i) => i + 1);
  return queueChart({ type: 'line', data: { labels: lbls, datasets }, options: baseAxisOptions() }, { height });
}

function barChart(values, opts = {}) {
  const { labels = [], color = CHART_INK, negColor = CHART_NEG, height = 200 } = opts;
  const lbls = labels.length ? labels : values.map((_, i) => i + 1);
  return queueChart({
    type: 'bar',
    data: { labels: lbls, datasets: [{
      data: values,
      backgroundColor: values.map(v => v >= 0 ? color : negColor),
      borderRadius: 2,
      barPercentage: 0.6,
      categoryPercentage: 0.85,
    }] },
    options: baseAxisOptions(),
  }, { height });
}

function donutChart(slices, opts = {}) {
  const { size = 160, thickness = 26 } = opts;
  const cutout = Math.max(0, Math.round(((size / 2 - thickness) / (size / 2)) * 100));
  return queueChart({
    type: 'doughnut',
    data: {
      labels: slices.map(s => s.label || ''),
      datasets: [{ data: slices.map(s => s.value), backgroundColor: slices.map(s => s.color), borderWidth: 0 }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: cutout + '%',
      plugins: { legend: { display: false }, tooltip: { enabled: true } },
    },
  }, { height: size, width: size });
}

// =====================================================================
// INTERACTION INFRASTRUCTURE — modals, toasts, persistence, export
// =====================================================================

// Persist mutations, refresh derived projections, and re-render everything
// that could depend on the changed data. This is the prototype stand-in for
// the technical-design "structured write flow" (build plan → write → re-index
// → refresh projections).
function commit() {
  if (!Store.save()) toast('Could not save to localStorage — changes will not persist after reload', 'warn');
  renderSidebar();
  renderCenter();
  if (state.inspectorOpen) renderInspector();
}

// ---- Toasts ----------------------------------------------------------------
function toast(message, kind = 'info') {
  let host = document.getElementById('toast-host');
  if (!host) {
    host = el('div', { id: 'toast-host', class: 'toast-host' });
    document.body.appendChild(host);
  }
  const node = el('div', { class: 'toast toast-' + kind }, [
    el('span', { class: 'toast-dot' }),
    el('span', { text: message }),
  ]);
  host.appendChild(node);
  requestAnimationFrame(() => node.classList.add('show'));
  setTimeout(() => {
    node.classList.remove('show');
    setTimeout(() => node.remove(), 250);
  }, 2800);
}

// ---- Modal / form builder --------------------------------------------------
// fields: [{ key, label, type, options, value, required, placeholder, step, hint, rows }]
function openModal({ title, subtitle, fields = [], body, submitLabel = 'Save', onSubmit, danger, secondary }) {
  closeModal();
  const overlay = el('div', {
    class: 'modal-overlay',
    id: 'modal-overlay',
    onclick: (e) => { if (e.target === e.currentTarget) closeModal(); },
  });
  const form = el('form', {
    class: 'modal',
    onsubmit: (e) => {
      e.preventDefault();
      const values = {};
      let ok = true;
      for (const f of fields) {
        const input = form.querySelector(`[name="${f.key}"]`);
        if (!input) continue;
        let v = input.value;
        if (f.type === 'number') v = v === '' ? null : Number(v);
        if (typeof v === 'string') v = v.trim();
        if (f.required && (v == null || v === '')) {
          ok = false;
          input.classList.add('field-error');
        } else {
          input.classList.remove('field-error');
        }
        values[f.key] = v;
      }
      if (!ok) { toast('Fill in the required fields', 'warn'); return; }
      const result = onSubmit ? onSubmit(values, form) : true;
      if (result !== false) closeModal();
    },
  });

  form.appendChild(el('div', { class: 'modal-head' }, [
    el('h2', { text: title }),
    subtitle ? el('p', { class: 'modal-sub', text: subtitle }) : null,
  ]));

  const bodyEl = el('div', { class: 'modal-body' });
  if (body) bodyEl.appendChild(body);
  for (const f of fields) {
    const id = 'mf-' + f.key;
    let input;
    if (f.type === 'select') {
      input = el('select', { name: f.key, id });
      for (const o of f.options) {
        const opt = el('option', { value: o.value }, [o.label]);
        if (String(o.value) === String(f.value)) opt.selected = true;
        input.appendChild(opt);
      }
    } else if (f.type === 'textarea') {
      input = el('textarea', { name: f.key, id, rows: f.rows || 3, placeholder: f.placeholder || '' }, [f.value || '']);
    } else {
      input = el('input', {
        name: f.key, id, type: f.type || 'text',
        value: f.value != null ? f.value : '',
        placeholder: f.placeholder || '',
      });
      if (f.step) input.setAttribute('step', f.step);
    }
    bodyEl.appendChild(el('div', { class: 'modal-field' }, [
      el('label', { for: id, text: f.label + (f.required ? ' *' : '') }),
      input,
      f.hint ? el('div', { class: 'modal-hint', text: f.hint }) : null,
    ]));
  }
  form.appendChild(bodyEl);

  form.appendChild(el('div', { class: 'modal-foot' }, [
    // Secondary action (e.g. Delete) sits left, separated from the primary actions.
    secondary ? el('button', {
      type: 'button',
      class: 'btn ' + (secondary.danger ? 'btn-danger' : 'btn-ghost'),
      style: { marginRight: 'auto' },
      onclick: () => { if (secondary.onClick) secondary.onClick(); },
    }, [secondary.label]) : null,
    el('button', { type: 'button', class: 'btn btn-ghost', onclick: closeModal }, ['Cancel']),
    el('button', { type: 'submit', class: 'btn ' + (danger ? 'btn-danger' : 'btn-primary') }, [submitLabel]),
  ]));

  overlay.appendChild(form);
  document.body.appendChild(overlay);
  const first = form.querySelector('input, select, textarea');
  if (first) setTimeout(() => first.focus(), 30);
}

function closeModal() {
  const o = document.getElementById('modal-overlay');
  if (o) o.remove();
}

// ---- Lightweight dropdown menu (for filter bar choices) --------------------
function openMenu(anchorEl, options, onPick) {
  document.querySelectorAll('.proto-menu').forEach(m => m.remove());
  const rect = anchorEl.getBoundingClientRect();
  const menu = el('div', { class: 'proto-menu' });
  for (const o of options) {
    menu.appendChild(el('div', {
      class: 'proto-menu-item' + (o.active ? ' active' : ''),
      onclick: () => { menu.remove(); onPick(o.value); },
    }, [o.label]));
  }
  menu.style.top = (rect.bottom + window.scrollY + 4) + 'px';
  menu.style.left = (rect.left + window.scrollX) + 'px';
  document.body.appendChild(menu);
  setTimeout(() => {
    const close = (e) => { if (!menu.contains(e.target)) { menu.remove(); document.removeEventListener('click', close); } };
    document.addEventListener('click', close);
  }, 0);
}

// ---- Export helpers (real downloads from live mock data) -------------------
function downloadFile(filename, content, mime = 'text/plain') {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = el('a', { href: url, download: filename });
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function toCSV(headers, rows) {
  const esc = (v) => {
    const s = v == null ? '' : String(v);
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  };
  const head = headers.map(h => esc(h.label)).join(',');
  const lines = rows.map(r => headers.map(h => esc(typeof h.value === 'function' ? h.value(r) : r[h.value])).join(','));
  return [head, ...lines].join('\n');
}

function exportCSV(filename, headers, rows) {
  if (!rows.length) { toast('Nothing to export', 'warn'); return; }
  downloadFile(filename, toCSV(headers, rows), 'text/csv');
  toast(filename + ' exported (' + rows.length + ' rows)', 'ok');
}

function exportMarkdown(filename, md) {
  downloadFile(filename, md, 'text/markdown');
  toast(filename + ' exported', 'ok');
}

// Simulated reindex: pulse the sync pill through syncing → synced.
function runReindex() {
  state.syncState = 'syncing';
  renderSidebar();
  toast('Reindexing workspace…', 'info');
  setTimeout(() => {
    state.syncState = 'synced';
    renderSidebar();
    toast('Workspace reindexed · ' + DATA.transactions.length + ' transactions', 'ok');
  }, 1100);
}

// OS-level affordances we can only simulate in a browser prototype.
function osAction(label, target) {
  toast(label + (target ? ' · ' + target : '') + ' (native action in the macOS app)', 'info');
}

// =====================================================================
// CREATE / IMPORT / EDIT FLOWS
// =====================================================================

function addTransaction(v) {
  const business = !!v.business;
  const amount = Number(v.amount);
  const tx = {
    id: (business ? 'BX-' : 'TX-') + Date.now(),
    date: v.date,
    merchant: v.merchant,
    description: v.description || '',
    account: business ? 'Brex Checking' : (v.account || 'Chase Checking'),
    category: v.category,
    amount,
    direction: amount < 0 ? 'debit' : 'credit',
    recurring: false,
    source: (business ? 'Business/transactions/' + (v.entityId || 'entity') + '-' : 'Personal/transactions/') + (v.date ? v.date.slice(0, 7) : '2026-05') + '.csv',
    row: DATA.transactions.length + 2,
    importedFrom: v.importedFrom || 'manual-entry',
    entityId: v.entityId || 'personal',
    deductible: business ? amount < 0 : false,
  };
  if (business) tx.entity = v.entityId;
  DATA.transactions.push(tx);
  return tx;
}

// Parse a simple CSV: date,merchant,description,category,amount (header optional).
function ingestTransactionCSV(text, { entityId, business }) {
  const lines = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
  if (!lines.length) return 0;
  const looksLikeHeader = /date/i.test(lines[0]) && /amount/i.test(lines[0]);
  const rows = looksLikeHeader ? lines.slice(1) : lines;
  let n = 0;
  for (const line of rows) {
    const cells = line.split(',').map(c => c.trim().replace(/^"|"$/g, ''));
    if (cells.length < 2) continue;
    // Always treat the last cell as the amount so 3-, 4-, and 5-column bank
    // exports all parse correctly (date, merchant[, description[, category]], amount).
    const amt = Number(cells[cells.length - 1]);
    if (Number.isNaN(amt)) continue;
    addTransaction({
      date: cells[0] || '2026-05-25',
      merchant: cells[1] || 'Imported',
      description: cells.length >= 5 ? cells[2] : '',
      category: cells.length >= 5 ? (cells[3] || 'groceries') : 'groceries',
      amount: amt,
      entityId, business, importedFrom: 'import.csv',
    });
    n++;
  }
  return n;
}

function importTransactionsFlow({ entityId = 'personal', business = false } = {}) {
  const catSource = business ? DATA.businessCategories : DATA.categories.filter(c => c.id !== 'income');
  const catOptions = [{ value: 'income', label: 'Income' }, ...catSource.map(c => ({ value: c.id, label: c.name }))];
  const fileInput = el('input', { type: 'file', accept: '.csv,text/csv', class: 'modal-file' });
  const filePicker = el('div', { class: 'modal-import-file' }, [
    el('label', { class: 'modal-field-label', text: 'Import a CSV file' }),
    fileInput,
    el('div', { class: 'modal-hint', text: 'Columns: date, merchant, description, category, amount (negative = expense).' }),
    el('div', { class: 'modal-or', text: 'or add one manually' }),
  ]);

  openModal({
    title: business ? 'Import business transactions' : 'Import transactions',
    subtitle: 'Drop in a bank/brokerage CSV export, or enter a single transaction.',
    body: filePicker,
    fields: [
      { key: 'date', label: 'Date', type: 'date', value: '2026-05-25' },
      { key: 'merchant', label: 'Merchant', placeholder: 'e.g. Whole Foods' },
      { key: 'description', label: 'Description', placeholder: 'optional' },
      { key: 'category', label: 'Category', type: 'select', options: catOptions, value: catOptions[1] ? catOptions[1].value : 'income' },
      { key: 'amount', label: 'Amount', type: 'number', step: '0.01', placeholder: '-120.00', hint: 'Negative for an expense, positive for income.' },
    ],
    submitLabel: 'Import',
    onSubmit: (v) => {
      const file = fileInput.files && fileInput.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = () => {
          const n = ingestTransactionCSV(String(reader.result), { entityId, business });
          if (n) { commit(); toast(n + ' transaction' + (n === 1 ? '' : 's') + ' imported from ' + file.name, 'ok'); }
          else toast('No valid rows found in ' + file.name, 'warn');
        };
        reader.onerror = () => toast('Could not read ' + file.name + ' — try again', 'warn');
        reader.readAsText(file);
        return true;
      }
      if (v.merchant && v.amount != null && v.amount !== '') {
        addTransaction({ ...v, entityId, business });
        commit();
        toast('Transaction added to the ledger', 'ok');
        return true;
      }
      toast('Choose a file or enter a merchant and amount', 'warn');
      return false;
    },
  });
}

function addGoalFlow() {
  openModal({
    title: 'New savings goal',
    subtitle: 'Goals link to a source account and a monthly budgeted contribution.',
    fields: [
      { key: 'name', label: 'Goal name', required: true, placeholder: 'e.g. New car' },
      { key: 'target', label: 'Target amount', type: 'number', step: '100', required: true, placeholder: '20000' },
      { key: 'balance', label: 'Starting balance', type: 'number', step: '100', value: 0 },
      { key: 'monthlyTarget', label: 'Monthly contribution', type: 'number', step: '50', value: 0 },
      { key: 'targetDate', label: 'Target date', type: 'date', value: '2027-12-01' },
      { key: 'account', label: 'Source account', value: 'Marcus · New Fund' },
    ],
    submitLabel: 'Create goal',
    onSubmit: (v) => {
      DATA.goals.push({
        id: 'goal-' + Date.now(),
        name: v.name,
        target: Number(v.target),
        balance: Number(v.balance) || 0,
        monthlyTarget: Number(v.monthlyTarget) || 0,
        monthlyActual: 0,
        targetDate: v.targetDate,
        account: v.account || 'Marcus · New Fund',
        note: null,
        contributions: [],
        source: 'Savings/goals.csv',
        row: DATA.goals.length + 2,
      });
      commit();
      toast('Goal “' + v.name + '” created', 'ok');
    },
  });
}

function addCategoryFlow() {
  openModal({
    title: 'New budget category',
    fields: [
      { key: 'name', label: 'Category name', required: true, placeholder: 'e.g. Subscriptions' },
      { key: 'group', label: 'Group', type: 'select', value: 'Discretionary', options: [
        { value: 'Fixed', label: 'Fixed' },
        { value: 'Variable', label: 'Variable' },
        { value: 'Discretionary', label: 'Discretionary' },
        { value: 'Savings', label: 'Savings' },
      ] },
      { key: 'planned', label: 'Monthly budget target', type: 'number', step: '10', value: 0 },
    ],
    submitLabel: 'Create category',
    onSubmit: (v) => {
      const palette = ['#6366f1', '#0ea5e9', '#f59e0b', '#ef4444', '#8b5cf6', '#14b8a6', '#06b6d4', '#22c55e'];
      DATA.categories.push({
        id: v.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'cat-' + Date.now(),
        name: v.name,
        group: v.group,
        planned: Number(v.planned) || 0,
        color: palette[DATA.categories.length % palette.length],
      });
      commit();
      toast('Category “' + v.name + '” added', 'ok');
    },
  });
}

function addEntityFlow() {
  openModal({
    title: 'New group',
    subtitle: 'Groups organize accounts (Personal, Place of Employment, a specific LLC).',
    fields: [
      { key: 'display', label: 'Display name', required: true, placeholder: 'e.g. Rental LLC' },
      { key: 'type', label: 'Type', type: 'select', value: 'business', options: [
        { value: 'personal', label: 'Personal' },
        { value: 'employment', label: 'Place of Employment' },
        { value: 'business', label: 'Business' },
      ] },
      { key: 'taxId', label: 'Tax ID (optional)', placeholder: 'xx-xxxxxxx' },
    ],
    submitLabel: 'Create group',
    onSubmit: (v) => {
      DATA.entities.push({
        id: v.display.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'group-' + Date.now(),
        display: v.display,
        type: v.type,
        taxId: v.taxId || '—',
        active: true,
      });
      commit();
      toast('Group “' + v.display + '” created', 'ok');
    },
  });
}

function addAccountFlow(entityId) {
  const entityOptions = DATA.entities.map(e => ({ value: e.id, label: e.display }));
  openModal({
    title: 'Add account',
    subtitle: 'Accounts register in the master Accounts/accounts.csv registry.',
    fields: [
      { key: 'name', label: 'Account name', required: true, placeholder: 'e.g. Ally Savings' },
      { key: 'institution', label: 'Institution', placeholder: 'e.g. Ally' },
      { key: 'group', label: 'Group', type: 'select', value: 'Everyday Banking', options: [
        { value: 'Everyday Banking', label: 'Everyday Banking' },
        { value: 'Credit Cards', label: 'Credit Cards' },
        { value: 'Investments', label: 'Investments' },
        { value: 'Savings', label: 'Savings' },
        { value: 'Business', label: 'Business' },
        { value: 'Benefits', label: 'Benefits' },
        { value: 'Loans & Debt', label: 'Loans & Debt' },
      ] },
      { key: 'type', label: 'Type', value: 'checking' },
      { key: 'entityId', label: 'Theme / entity', type: 'select', value: entityId || 'personal', options: entityOptions },
      { key: 'monthlyInflow', label: 'Monthly inflow', type: 'number', step: '50', value: 0 },
      { key: 'ytdNetIncome', label: 'YTD net income', type: 'number', step: '100', value: 0 },
    ],
    submitLabel: 'Add account',
    onSubmit: (v) => {
      DATA.accounts.push({
        id: 'acct-' + Date.now(),
        name: v.name,
        institution: v.institution || '—',
        group: v.group,
        type: v.type || 'checking',
        monthlyInflow: Number(v.monthlyInflow) || 0,
        ytdNetIncome: Number(v.ytdNetIncome) || 0,
        entityId: v.entityId,
      });
      commit();
      toast('Account “' + v.name + '” added', 'ok');
    },
  });
}

// =====================================================================
// EDIT / DELETE — universal object management (Round 5 #6)
// Right-panel objects show Edit/Delete at the bottom of the inspector;
// dedicated-screen objects (individual account) edit via local actions
// with Delete offered inside the edit flow.
// =====================================================================

const ACCOUNT_GROUP_OPTS = ['Everyday Banking', 'Credit Cards', 'Investments', 'Savings', 'Business', 'Benefits', 'Loans & Debt']
  .map(g => ({ value: g, label: g }));

const EDITABLE_KINDS = new Set(['account', 'transaction', 'biz-tx', 'goal', 'category', 'deduction', 'holding', 'entity']);
const DELETABLE_KINDS = new Set(['account', 'transaction', 'biz-tx', 'goal', 'category', 'deduction', 'holding', 'entity', 'payment']);

function editSelection(kind, id) {
  switch (kind) {
    case 'account': return editAccountFlow(id);
    case 'transaction': case 'biz-tx': return editTransactionFlow(id);
    case 'goal': return editGoalFlow(id);
    case 'category': return editCategoryFlow(id);
    case 'deduction': return editDeductionFlow(id);
    case 'holding': return editHoldingFlow(id);
    case 'entity': return editEntityFlow(id);
    default: toast('Editing isn’t available for this item', 'info');
  }
}

// Generic delete with a reference check + previewed, backed-up write.
function deleteSelection(kind, id) {
  const map = {
    account:     { coll: 'accounts',  label: 'account',     name: o => o.name,             refs: o => DATA.transactions.filter(t => t.account === o.name).length, refLabel: 'transactions' },
    entity:      { coll: 'entities',  label: 'group',       name: o => o.display,          refs: o => DATA.accounts.filter(a => a.entityId === o.id).length,      refLabel: 'accounts' },
    transaction: { coll: 'transactions', label: 'transaction', name: o => o.merchant },
    'biz-tx':    { coll: 'transactions', label: 'transaction', name: o => o.merchant },
    goal:        { coll: 'goals',     label: 'goal',        name: o => o.name },
    category:    { coll: 'categories', label: 'category',   name: o => o.name,             refs: o => DATA.transactions.filter(t => t.category === o.id).length,   refLabel: 'transactions' },
    deduction:   { coll: 'deductions', label: 'deduction',  name: o => o.name },
    holding:     { coll: 'holdings',  label: 'holding',     name: o => o.name || o.ticker },
    payment:     { coll: 'estimatedPayments', label: 'payment', name: o => o.jurisdiction + ' Q' + o.quarter },
  };
  const cfg = map[kind];
  if (!cfg) { toast('This object can’t be deleted', 'warn'); return; }
  const coll = DATA[cfg.coll];
  const obj = coll.find(o => o.id === id);
  if (!obj) return;
  const refCount = cfg.refs ? cfg.refs(obj) : 0;
  const refMsg = refCount > 0
    ? `${refCount} ${cfg.refLabel} reference this ${cfg.label} — they’ll be kept but left unlinked. `
    : '';
  openModal({
    title: `Delete ${cfg.label}?`,
    subtitle: cfg.name(obj),
    body: el('p', { class: 'modal-sub', style: { margin: '4px 0 0' }, text: `${refMsg}This writes to the source file and saves a timestamped backup.` }),
    submitLabel: 'Delete',
    danger: true,
    onSubmit: () => {
      const idx = coll.findIndex(o => o.id === id);
      if (idx > -1) coll.splice(idx, 1);
      if (state.selection && state.selection.id === id) closeInspector();
      if (kind === 'account' && state.view === 'accounts-account-' + id) state.view = 'accounts-overview';
      if (kind === 'entity' && state.view === 'accounts-entity-' + id) state.view = 'accounts-overview';
      commit();
      toast(`${cfg.label[0].toUpperCase() + cfg.label.slice(1)} deleted · backup saved`, 'ok');
    },
  });
}

function editAccountFlow(accountId) {
  const a = DATA.accounts.find(x => x.id === accountId);
  if (!a) return;
  openModal({
    title: 'Edit account',
    subtitle: a.name,
    fields: [
      { key: 'name', label: 'Account name', required: true, value: a.name },
      { key: 'institution', label: 'Institution', value: a.institution },
      { key: 'group', label: 'Banking group', type: 'select', value: a.group, options: ACCOUNT_GROUP_OPTS },
      { key: 'type', label: 'Type', value: a.type },
      { key: 'entityId', label: 'Account group', type: 'select', value: a.entityId, options: DATA.entities.map(e => ({ value: e.id, label: e.display })) },
      { key: 'monthlyInflow', label: 'Monthly inflow', type: 'number', step: '50', value: a.monthlyInflow },
      { key: 'ytdNetIncome', label: 'YTD net income', type: 'number', step: '100', value: a.ytdNetIncome },
    ],
    submitLabel: 'Save changes',
    secondary: { label: 'Delete account', danger: true, onClick: () => { closeModal(); deleteSelection('account', a.id); } },
    onSubmit: (v) => {
      a.name = v.name; a.institution = v.institution || '—'; a.group = v.group; a.type = v.type || 'checking';
      a.entityId = v.entityId; a.monthlyInflow = Number(v.monthlyInflow) || 0; a.ytdNetIncome = Number(v.ytdNetIncome) || 0;
      commit(); toast('Account updated · backup saved', 'ok');
    },
  });
}

function editTransactionFlow(id) {
  const t = DATA.transactions.find(x => x.id === id);
  if (!t) return;
  const isBiz = /^BX-/.test(t.id);
  const catOpts = [{ value: 'income', label: 'Income' },
    ...(isBiz ? DATA.businessCategories : DATA.categories.filter(c => c.id !== 'income')).map(c => ({ value: c.id, label: c.name }))];
  openModal({
    title: 'Edit transaction',
    subtitle: t.merchant,
    fields: [
      { key: 'date', label: 'Date', type: 'date', value: t.date },
      { key: 'merchant', label: 'Merchant', required: true, value: t.merchant },
      { key: 'description', label: 'Description', value: t.description || '' },
      { key: 'category', label: 'Category', type: 'select', value: t.category, options: catOpts },
      { key: 'amount', label: 'Amount', type: 'number', step: '0.01', value: t.amount },
    ],
    submitLabel: 'Save changes',
    secondary: { label: 'Delete transaction', danger: true, onClick: () => { closeModal(); deleteSelection(isBiz ? 'biz-tx' : 'transaction', t.id); } },
    onSubmit: (v) => {
      t.date = v.date; t.merchant = v.merchant; t.description = v.description; t.category = v.category;
      t.amount = Number(v.amount); t.direction = t.amount < 0 ? 'debit' : 'credit';
      commit(); toast('Transaction updated · backup saved', 'ok');
    },
  });
}

function editGoalFlow(id) {
  const g = DATA.goals.find(x => x.id === id);
  if (!g) return;
  openModal({
    title: 'Edit goal', subtitle: g.name,
    fields: [
      { key: 'name', label: 'Goal name', required: true, value: g.name },
      { key: 'target', label: 'Target amount', type: 'number', step: '100', value: g.target },
      { key: 'balance', label: 'Current balance', type: 'number', step: '100', value: g.balance },
      { key: 'monthlyTarget', label: 'Monthly target', type: 'number', step: '50', value: g.monthlyTarget },
    ],
    submitLabel: 'Save changes',
    secondary: { label: 'Delete goal', danger: true, onClick: () => { closeModal(); deleteSelection('goal', g.id); } },
    onSubmit: (v) => {
      g.name = v.name; g.target = Number(v.target); g.balance = Number(v.balance); g.monthlyTarget = Number(v.monthlyTarget);
      commit(); toast('Goal updated · backup saved', 'ok');
    },
  });
}

function editCategoryFlow(id) {
  const cat = DATA.categories.find(x => x.id === id);
  if (!cat) return;
  openModal({
    title: 'Edit category', subtitle: cat.name,
    fields: [
      { key: 'name', label: 'Name', required: true, value: cat.name },
      { key: 'group', label: 'Group', type: 'select', value: cat.group, options: ['Fixed', 'Variable', 'Discretionary', 'Savings'].map(g => ({ value: g, label: g })) },
      { key: 'planned', label: 'Planned', type: 'number', step: '10', value: cat.planned },
    ],
    submitLabel: 'Save changes',
    secondary: { label: 'Delete category', danger: true, onClick: () => { closeModal(); deleteSelection('category', cat.id); } },
    onSubmit: (v) => {
      cat.name = v.name; cat.group = v.group; cat.planned = Number(v.planned);
      commit(); toast('Category updated · backup saved', 'ok');
    },
  });
}

function editDeductionFlow(id) {
  const d = DATA.deductions.find(x => x.id === id);
  if (!d) return;
  openModal({
    title: 'Edit deduction', subtitle: d.name,
    fields: [
      { key: 'name', label: 'Name', required: true, value: d.name },
      { key: 'estimatedAmount', label: 'Estimated amount', type: 'number', step: '50', value: d.estimatedAmount },
      { key: 'status', label: 'Status', type: 'select', value: d.status, options: ['confirmed', 'estimated', 'missing'].map(s => ({ value: s, label: s })) },
    ],
    submitLabel: 'Save changes',
    secondary: { label: 'Delete deduction', danger: true, onClick: () => { closeModal(); deleteSelection('deduction', d.id); } },
    onSubmit: (v) => {
      d.name = v.name; d.estimatedAmount = Number(v.estimatedAmount); d.status = v.status;
      commit(); toast('Deduction updated · backup saved', 'ok');
    },
  });
}

function editHoldingFlow(id) {
  const h = DATA.holdings.find(x => x.id === id);
  if (!h) return;
  openModal({
    title: 'Edit holding', subtitle: h.name || h.ticker,
    fields: [
      { key: 'name', label: 'Name', value: h.name || '' },
      { key: 'ticker', label: 'Ticker', value: h.ticker || '' },
      { key: 'qty', label: 'Quantity', type: 'number', step: '0.01', value: h.qty },
      { key: 'price', label: 'Price', type: 'number', step: '0.01', value: h.price },
      { key: 'basis', label: 'Cost basis', type: 'number', step: '100', value: h.basis },
    ],
    submitLabel: 'Save changes',
    secondary: { label: 'Delete holding', danger: true, onClick: () => { closeModal(); deleteSelection('holding', h.id); } },
    onSubmit: (v) => {
      h.name = v.name; h.ticker = v.ticker; h.qty = Number(v.qty); h.price = Number(v.price); h.basis = Number(v.basis);
      commit(); toast('Holding updated · backup saved', 'ok');
    },
  });
}

function editEntityFlow(id) {
  const e = DATA.entities.find(x => x.id === id);
  if (!e) return;
  openModal({
    title: 'Edit group', subtitle: e.display,
    fields: [
      { key: 'display', label: 'Display name', required: true, value: e.display },
      { key: 'type', label: 'Type', type: 'select', value: e.type, options: [
        { value: 'personal', label: 'Personal' },
        { value: 'employment', label: 'Place of Employment' },
        { value: 'business', label: 'Business' },
      ] },
      { key: 'taxId', label: 'Tax ID', value: e.taxId || '' },
    ],
    submitLabel: 'Save changes',
    secondary: { label: 'Delete group', danger: true, onClick: () => { closeModal(); deleteSelection('entity', e.id); } },
    onSubmit: (v) => {
      e.display = v.display; e.type = v.type; e.taxId = v.taxId || '—';
      commit(); toast('Group updated · backup saved', 'ok');
    },
  });
}

// Add a transaction scoped to a specific account (individual account screen).
function addAccountTransactionFlow(account, entityId) {
  const catOpts = [{ value: 'income', label: 'Income' },
    ...DATA.categories.filter(c => c.id !== 'income').map(c => ({ value: c.id, label: c.name }))];
  openModal({
    title: 'Add transaction',
    subtitle: 'Adds a row to ' + account,
    fields: [
      { key: 'date', label: 'Date', type: 'date', value: '2026-05-25' },
      { key: 'merchant', label: 'Merchant', required: true, placeholder: 'e.g. Whole Foods' },
      { key: 'description', label: 'Description', placeholder: 'optional' },
      { key: 'category', label: 'Category', type: 'select', value: catOpts[1] ? catOpts[1].value : 'income', options: catOpts },
      { key: 'amount', label: 'Amount', type: 'number', step: '0.01', placeholder: '-120.00' },
    ],
    submitLabel: 'Add',
    onSubmit: (v) => {
      addTransaction({ ...v, account, entityId });
      commit(); toast('Transaction added · backup saved', 'ok');
    },
  });
}

function addPaymentFlow() {
  openModal({
    title: 'New estimated payment',
    fields: [
      { key: 'quarter', label: 'Quarter', type: 'select', value: '2', options: [
        { value: '1', label: 'Q1' }, { value: '2', label: 'Q2' }, { value: '3', label: 'Q3' }, { value: '4', label: 'Q4' },
      ] },
      { key: 'jurisdiction', label: 'Jurisdiction', type: 'select', value: 'Federal', options: [
        { value: 'Federal', label: 'Federal' }, { value: 'Colorado', label: 'Colorado' },
      ] },
      { key: 'due', label: 'Due date', type: 'date', value: '2026-06-15' },
      { key: 'amount', label: 'Amount', type: 'number', step: '50', required: true, value: 4200 },
      { key: 'paid', label: 'Amount paid', type: 'number', step: '50', value: 0 },
    ],
    submitLabel: 'Add payment',
    onSubmit: (v) => {
      const paid = Number(v.paid) || 0;
      DATA.estimatedPayments.push({
        id: 'ep-' + Date.now(),
        year: 2026,
        quarter: Number(v.quarter),
        due: v.due,
        amount: Number(v.amount),
        paid,
        paidDate: paid > 0 ? '2026-06-14' : null,
        jurisdiction: v.jurisdiction,
        status: paid >= Number(v.amount) ? 'paid' : 'upcoming',
      });
      commit();
      toast('Estimated payment added', 'ok');
    },
  });
}

function addPaystubFlow(entityId) {
  openModal({
    title: 'Import paystub',
    subtitle: 'Records a paycheck deposit against this employer.',
    fields: [
      { key: 'date', label: 'Pay date', type: 'date', value: '2026-05-29' },
      { key: 'merchant', label: 'Employer', value: 'Acme Employer' },
      { key: 'description', label: 'Description', value: 'Payroll deposit' },
      { key: 'amount', label: 'Net deposit', type: 'number', step: '0.01', required: true, value: 4825.40 },
    ],
    submitLabel: 'Import',
    onSubmit: (v) => {
      addTransaction({ ...v, amount: Math.abs(Number(v.amount)), category: 'income', entityId, account: 'Chase Checking', importedFrom: 'paystub' });
      commit();
      toast('Paycheck imported', 'ok');
    },
  });
}

function updatePriceFlow() {
  const holdingOptions = DATA.holdings.map(h => ({ value: h.id, label: h.ticker + ' · ' + fmtUSD2(h.price) }));
  openModal({
    title: 'Update prices',
    subtitle: 'Set the latest close for a holding (stands in for a price-file import).',
    fields: [
      { key: 'holding', label: 'Holding', type: 'select', options: holdingOptions, value: holdingOptions[0] && holdingOptions[0].value },
      { key: 'price', label: 'New price', type: 'number', step: '0.01', required: true },
    ],
    submitLabel: 'Update',
    onSubmit: (v) => {
      const h = DATA.holdings.find(x => x.id === v.holding);
      if (h) { h.price = Number(v.price); commit(); toast(h.ticker + ' repriced to ' + fmtUSD2(h.price), 'ok'); }
    },
  });
}

function rebalancePlanFlow() {
  const total = DATA.holdings.reduce((s, h) => s + h.qty * h.price, 0);
  const rows = DATA.sleeveTargets.map(t => {
    const drift = t.actual - t.target;
    const dollar = -drift * total;
    return { ticker: t.ticker, sleeve: sleeveById()[t.sleeve] ? sleeveById()[t.sleeve].name : t.sleeve, drift, dollar };
  }).filter(r => Math.abs(r.drift) > 0.005);

  const table = el('table', { class: 'tbl' });
  table.innerHTML = `<thead><tr><th>Holding</th><th>Sleeve</th><th class="num">Drift</th><th class="num">Suggested trade</th></tr></thead><tbody></tbody>`;
  const tbody = table.querySelector('tbody');
  for (const r of rows) {
    const tr = tbody.insertRow();
    tr.insertCell().textContent = r.ticker;
    const sl = tr.insertCell(); sl.className = 'muted'; sl.textContent = r.sleeve;
    const d = tr.insertCell(); d.className = 'num ' + (r.drift > 0 ? 'neg' : 'pos'); d.textContent = fmtPctSigned(r.drift, 1);
    const a = tr.insertCell(); a.className = 'num'; a.textContent = (r.dollar >= 0 ? 'Buy ' : 'Sell ') + fmtUSD(Math.abs(r.dollar));
  }
  openModal({
    title: 'Rebalance plan',
    subtitle: 'Trades to bring each sleeve back to target weight (drift > 0.5%).',
    body: el('div', { class: 'panel-body flush', style: { margin: '0 -4px' } }, [
      rows.length ? table : el('p', { style: { color: 'var(--muted)', fontSize: '12px' }, text: 'All sleeves are within tolerance — no rebalance needed.' }),
    ]),
    submitLabel: 'Export plan',
    onSubmit: () => {
      exportCSV('rebalance-plan.csv',
        [{ label: 'ticker', value: 'ticker' }, { label: 'sleeve', value: 'sleeve' },
         { label: 'drift', value: r => fmtPctSigned(r.drift, 1) }, { label: 'trade_usd', value: r => Math.round(r.dollar) }],
        rows);
    },
  });
}

function applyRepair(issueId) {
  const idx = DATA.issues.findIndex(i => i.id === issueId);
  if (idx === -1) return;
  const issue = DATA.issues[idx];
  DATA.issues.splice(idx, 1);
  DATA.workspace.issueCount = DATA.issues.length;
  if (state.selection && state.selection.kind === 'issue' && state.selection.id === issueId) {
    closeInspector();
  }
  commit();
  toast('Repaired: ' + issue.title + ' · backup saved', 'ok');
}

function toggleChecklistItem(id) {
  const item = DATA.taxChecklist.find(c => c.id === id);
  if (!item) return;
  item.done = !item.done;
  commit();
}

function exportBusinessPL(entityId) {
  const entity = entityById()[entityId];
  const txs = DATA.transactions.filter(t => t.entityId === entityId);
  const revenue = txs.filter(t => t.amount > 0).reduce((s, t) => s + t.amount, 0);
  const expenses = txs.filter(t => t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0);
  const md = [
    '# ' + (entity ? entity.display : entityId) + ' — P&L (May 2026)',
    '',
    '| Line | Amount |',
    '| --- | --- |',
    '| Revenue | ' + fmtUSD(revenue) + ' |',
    '| Expenses | ' + fmtUSD(expenses) + ' |',
    '| **Net income** | **' + fmtUSD(revenue - expenses) + '** |',
    '',
    '## Transactions',
    '',
    '| Date | Merchant | Category | Amount | Deductible |',
    '| --- | --- | --- | --- | --- |',
    ...txs.map(t => `| ${t.date} | ${t.merchant} | ${t.category} | ${t.amount} | ${t.deductible ? 'yes' : 'no'} |`),
  ].join('\n');
  exportMarkdown((entityId || 'business') + '-pl.md', md);
}

function exportTaxPacket() {
  const md = [
    '# 2026 Tax Prep Packet',
    '',
    '## Prep checklist',
    ...DATA.taxChecklist.map(c => `- [${c.done ? 'x' : ' '}] ${c.label}${c.due ? ' (due ' + c.due + ')' : ''}`),
    '',
    '## Estimated payments',
    '| Quarter | Jurisdiction | Due | Amount | Paid | Status |',
    '| --- | --- | --- | --- | --- | --- |',
    ...DATA.estimatedPayments.map(p => `| Q${p.quarter} ${p.year} | ${p.jurisdiction} | ${p.due} | ${p.amount} | ${p.paid} | ${p.status} |`),
    '',
    '## Deductions',
    '| Deduction | Type | Estimated | Status |',
    '| --- | --- | --- | --- |',
    ...DATA.deductions.map(d => `| ${d.name} | ${d.type} | ${d.estimatedAmount} | ${d.status} |`),
  ].join('\n');
  exportMarkdown('2026-tax-prep-packet.md', md);
}

// =====================================================================
// VIEW RENDERERS
// =====================================================================

function renderCenter() {
  const content = $('#content');
  destroyCharts();
  content.innerHTML = '';
  routeView();
  flushCharts();
}

function routeView() {
  // route
  const v = state.view;
  if (v.startsWith('accounts-account-')) {
    return viewAccount(v.replace('accounts-account-', ''));
  }
  if (v.startsWith('accounts-entity-')) {
    const entityId = v.replace('accounts-entity-', '');
    return viewAccountEntity(entityId);
  }
  if (v === 'overview-dashboard')                                                        return viewOverviewDashboard();
  if (v === 'accounts-overview')                                                         return viewAccounts();
  if (v === 'budget-overview')                                                           return viewBudgetOverview();
  if (v === 'budget-history')                                                            return viewBudgetHistory();
  if (v === 'budget-categories')                                                         return viewBudgetCategories();
  // Legacy deep links from removed screens (Round 4) redirect to their parent view
  if (v === 'savings-goals' || v === 'savings-goals-active' || v === 'savings-goals-archived') return viewSavingsGoals();
  if (v === 'investments-portfolio' || v === 'investments-accounts' || v === 'investments-sleeves' || v === 'savings-accounts') return viewInvestments();
  if (v === 'investments-holdings' || v === 'investments-benchmarks' || v === 'investments-benchmark') return viewInvestmentsHoldings();
  if (v === 'business-entity' || v === 'business-all-entities' || v === 'business-monthly') return viewBusiness();
  if (v === 'business-categories')                                                       return viewBusinessCategories();
  if (v === 'business-budgets')                                                          return viewBusinessBudgets();
  if (v === 'taxes-current' || v === 'taxes-deductions' || v === 'taxes-estimated' || v === 'taxes-gains' || v === 'taxes-estimated-payments' || v === 'taxes-gains-income') return viewTaxesCurrent();
  if (v === 'taxes-checklist')                                                           return viewTaxesChecklist();
  if (v === 'taxes-archive')                                                             return viewTaxesArchive();
  if (v === 'onboarding')                                                                return viewOnboarding();
  if (v === 'indexing-progress')                                                         return viewIndexingProgress();
  if (v === 'settings-workspace')                                                        return viewSettingsWorkspace();
  if (v === 'settings-schema')                                                           return viewSettingsSchema();
  // stub for any unimplemented view
  const c = $('#content');
  c.appendChild(el('p', { style: { color: 'var(--muted)', padding: '24px' }, text: 'Coming in this sprint' }));
}

// ---------- Overview ---------------------------------------------------------

function viewOverviewDashboard() {
  setHeader({
    title: 'Overview',
    breadcrumb: ['Finance', 'Overview', 'Dashboard'],
    actions: [
      { label: 'Apply repairable fixes', variant: '', onClick: () => {
        const repairable = DATA.issues.filter(i => i.repairable);
        if (!repairable.length) { toast('No repairable issues remaining', 'info'); return; }
        repairable.forEach(i => { const idx = DATA.issues.findIndex(x => x.id === i.id); if (idx > -1) DATA.issues.splice(idx, 1); });
        DATA.workspace.issueCount = DATA.issues.length;
        commit();
        toast(repairable.length + ' issues repaired · backups saved', 'ok');
      } },
      { label: 'Export', variant: 'btn-ghost', onClick: () => exportCSV('overview-issues.csv',
        [{ label: 'severity', value: 'severity' }, { label: 'group', value: 'group' }, { label: 'title', value: 'title' }, { label: 'file', value: i => i.filePath || i.file }, { label: 'repairable', value: 'repairable' }],
        DATA.issues) },
      { label: 'Reindex', variant: 'btn-ghost', onClick: runReindex },
    ],
  });
  renderFilterBar([]);

  const c = $('#content');
  const o = DATA.overview;

  // 5 KPI cards (T031): Budget, Savings, Investments, Business, Taxes
  const kpis = [
    { id: 'budget',      label: 'Budget',       value: fmtUSD(o.budgetVariance.value, { sign: true }), delta: 'over plan',  deltaCls: 'neg', foot: 'Travel +$364, Groceries +$78', nav: 'budget-overview' },
    { id: 'savings',     label: 'Savings',       value: fmtPct(o.savingsProgress.value, 0), delta: fmtPctSigned(o.savingsProgress.change), deltaCls: 'pos', foot: '$58,640 of $96,000 plan', nav: 'savings-goals' },
    { id: 'investments', label: 'Investments',   value: fmtUSD(o.portfolioValue.value), delta: fmtPctSigned(o.portfolioValue.change), deltaCls: 'pos', foot: '+$4,640 MoM', nav: 'investments-portfolio' },
    { id: 'business',    label: 'Business NI',   value: fmtUSD(o.businessNetIncome.value, { sign: true }), delta: fmtPctSigned(o.businessNetIncome.change), deltaCls: 'pos', foot: 'Consulting LLC · May', nav: 'accounts-entity-consulting-llc' },
    { id: 'taxes',       label: 'Taxes',         value: o.taxStatus.value, delta: o.taxStatus.subtle, deltaCls: 'flat', foot: '4 estimated payments planned', nav: 'taxes-current' },
  ];

  const kpiGrid = el('div', { class: 'kpi-grid' });
  for (const k of kpis) {
    kpiGrid.appendChild(el('div', {
      class: 'kpi-card' + (state.overviewKpi === k.id ? ' selected' : ''),
      onclick: () => { state.overviewKpi = k.id; navigate(k.nav); },
    }, [
      el('div', { class: 'kpi-label', text: k.label }),
      el('div', { class: 'kpi-value', text: k.value }),
      el('div', { class: 'kpi-delta ' + k.deltaCls, text: k.delta }),
      el('div', { class: 'kpi-foot', text: k.foot }),
    ]));
  }
  c.appendChild(kpiGrid);

  // Charts row
  const cashFlowVals = o.cashFlowSeries.map(x => x.net);
  const cashFlowLabels = o.cashFlowSeries.map(x => x.period);
  const netWorthLabels = ['Jun','Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May'];

  const charts = el('div', { class: 'row2' }, [
    el('div', { class: 'panel' }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Cash Flow Trend' }),
        el('span', { class: 'panel-sub', text: 'Net inflow · trailing 12 months' }),
        el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
      ]),
      el('div', { class: 'panel-body' }, [
        el('div', { class: 'chart-wrap', html: barChart(cashFlowVals, { labels: cashFlowLabels }) }),
        el('div', { class: 'legend' }, [
          el('span', { class: 'legend-item' }, [el('span', { class: 'legend-swatch', style: { background: '#3651d3' } }), 'Net cash flow']),
          el('span', { class: 'legend-item', style: { marginLeft: 'auto' }, text: 'Source · Personal/transactions/*.csv' }),
        ]),
      ]),
    ]),
    el('div', { class: 'panel' }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Net Worth Trend' }),
        el('span', { class: 'panel-sub', text: 'Liquid + investments + cash' }),
        el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
      ]),
      el('div', { class: 'panel-body' }, [
        el('div', { class: 'chart-wrap', html: lineChart([o.netWorth], { labels: netWorthLabels }) }),
        el('div', { class: 'legend' }, [
          el('span', { class: 'legend-item' }, [el('span', { class: 'legend-swatch', style: { background: '#3651d3' } }), 'Net worth']),
          el('span', { class: 'legend-item', style: { marginLeft: 'auto' }, text: 'Computed across all accounts' }),
        ]),
      ]),
    ]),
  ]);
  c.appendChild(charts);

  // Inline Issues table (T032) — grouped by severity
  const issuesByGroup = { error: [], warning: [], info: [] };
  for (const i of DATA.issues) issuesByGroup[i.severity].push(i);

  const issuesPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Validation Issues' }),
      el('span', { class: 'panel-sub', text: DATA.issues.length + ' open' }),
      el('div', { class: 'panel-actions' }, [
        el('span', { class: 'tag tag-err', text: issuesByGroup.error.length + ' errors' }),
        el('span', { class: 'tag tag-warn', text: issuesByGroup.warning.length + ' warnings' }),
        el('span', { class: 'tag tag-info', text: issuesByGroup.info.length + ' info' }),
      ]),
    ]),
    el('div', { class: 'panel-body flush' }, [
      (() => {
        const table = el('table', { class: 'tbl' });
        table.innerHTML = `<thead><tr><th style="width:80px">Severity</th><th>Issue</th><th>File</th><th style="width:90px">Status</th></tr></thead><tbody></tbody>`;
        const tbody = table.querySelector('tbody');
        for (const sev of ['error', 'warning', 'info']) {
          for (const i of issuesByGroup[sev]) {
            const sevCls = sev === 'error' ? 'issue-row--error' : sev === 'warning' ? 'issue-row--warning' : 'issue-row--info';
            const tr = el('tr', {
              class: (state.selection?.kind === 'issue' && state.selection?.id === i.id ? 'selected ' : '') + sevCls,
              onclick: () => openInspector('issue', i.id),
            });
            const sevTag = sev === 'error' ? el('span', { class: 'tag tag-err', text: 'error' }) :
                           sev === 'warning' ? el('span', { class: 'tag tag-warn', text: 'warning' }) :
                           el('span', { class: 'tag tag-info', text: 'info' });
            tr.appendChild(el('td', {}, [sevTag]));
            tr.appendChild(el('td', {}, [
              el('div', { text: i.title }),
              el('div', { style: { fontSize: '11px', color: 'var(--muted)' }, text: i.message }),
            ]));
            tr.appendChild(el('td', {}, [
              el('span', { class: 'path-chip' }, [
                i.filePath || i.file,
                el('span', { class: 'sync-badge sync-badge--available' }),
              ]),
            ]));
            tr.appendChild(el('td', {}, [
              i.repairable ? el('span', { class: 'issue-badge--repairable', text: 'repairable' }) : el('span', { class: 'issue-badge--manual', text: 'manual' }),
            ]));
            tbody.appendChild(tr);
          }
        }
        return table;
      })(),
    ]),
  ]);
  c.appendChild(issuesPanel);
}

// ---------- Budget -----------------------------------------------------------

function viewBudgetOverview() {
  setHeader({
    title: 'Budget · May 2026',
    breadcrumb: ['Finance', 'Budget', 'Overview'],
    actions: [
      { label: 'Import CSV', variant: '', onClick: () => importTransactionsFlow({ entityId: 'personal' }) },
      { label: 'Export', variant: 'btn-ghost', onClick: () => exportCSV('transactions-2026-05.csv',
        [{ label: 'date', value: 'date' }, { label: 'merchant', value: 'merchant' }, { label: 'description', value: 'description' }, { label: 'account', value: 'account' }, { label: 'category', value: 'category' }, { label: 'amount', value: 'amount' }],
        DATA.transactions.filter(t => t.category !== 'income' && !/^BX-/.test(t.id))) },
    ],
  });
  renderFilterBar([]);

  const c = $('#content');
  const planned = DATA.categories.reduce((s, x) => s + x.planned, 0);
  const actual = DATA.transactions.reduce((s, x) => {
    if (x.category === 'income') return s;
    return s + Math.abs(x.amount < 0 ? x.amount : 0);
  }, 0);
  const variance = actual - planned;

  const kpis = [
    { id: 'planned',  label: 'Planned',   value: fmtUSD(planned),  delta: '10 categories', deltaCls: 'flat', foot: 'May targets · Personal/budgets.csv' },
    { id: 'actual',   label: 'Actual',    value: fmtUSD(actual),   delta: fmtPctSigned(actual / planned - 1), deltaCls: variance > 0 ? 'neg' : 'pos', foot: 'Through May 24' },
    { id: 'variance', label: 'Variance',  value: fmtUSD(variance, { sign: true }), delta: variance > 0 ? 'over plan' : 'under plan', deltaCls: variance > 0 ? 'neg' : 'pos', foot: 'Travel + Dining are top drivers' },
  ];
  const kpiGrid = el('div', { class: 'kpi-grid' });
  for (const k of kpis) {
    kpiGrid.appendChild(el('div', { class: 'kpi-card', onclick: () => { select({ kind: 'budget-kpi', id: k.id }); } }, [
      el('div', { class: 'kpi-label', text: k.label }),
      el('div', { class: 'kpi-value', text: k.value }),
      el('div', { class: 'kpi-delta ' + k.deltaCls, text: k.delta }),
      el('div', { class: 'kpi-foot', text: k.foot }),
    ]));
  }
  c.appendChild(kpiGrid);

  // Donut chart + category table (T033 / T034)
  const sliceData = [
    { label: 'Fixed',        value: DATA.categories.filter(c => c.group === 'Fixed').reduce((s, c) => s + c.planned, 0),        color: '#6366f1' },
    { label: 'Discretionary',value: DATA.categories.filter(c => c.group === 'Discretionary').reduce((s, c) => s + c.planned, 0), color: '#f59e0b' },
    { label: 'Savings',      value: DATA.categories.filter(c => c.group === 'Savings').reduce((s, c) => s + c.planned, 0),       color: '#0ea5e9' },
    { label: 'Variable',     value: DATA.categories.filter(c => c.group === 'Variable').reduce((s, c) => s + c.planned, 0),      color: '#22c55e' },
  ];
  const allZero = sliceData.every(s => s.value === 0);

  const donutPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Spending Mix · May 2026' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body' }, [
      allZero
        ? el('div', { style: { textAlign: 'center', color: 'var(--muted)', padding: '24px' }, text: 'No transactions this month' })
        : el('div', { style: { display: 'flex', gap: '16px', alignItems: 'center' } }, [
            el('div', { style: { width: '160px', flex: '0 0 160px' }, html: donutChart(sliceData, { size: 160, thickness: 26 }) }),
            el('div', { style: { flex: '1' } }, sliceData.map(s =>
              el('div', { style: { display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px', fontSize: '12.5px' } }, [
                el('span', { style: { display: 'inline-block', width: '8px', height: '8px', borderRadius: '50%', background: s.color, flexShrink: '0' } }),
                el('span', { style: { flex: '1' }, text: s.label }),
                el('span', { style: { fontVariantNumeric: 'tabular-nums', color: 'var(--muted)' }, text: fmtUSD(s.value) }),
              ])
            )),
          ]),
    ]),
  ]);

  // Category variance table with trailing average column (T034)
  const trailingAvg = {
    housing: 2400, groceries: 680, utilities: 310, dining: 290,
    childcare: 1450, insurance: 408, travel: 420, golf: 145, investments: 1500, savings: 1050,
  };
  const categoryTotals = computeCategoryTotals();

  const catPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Category Variance · May 2026' }),
      el('span', { class: 'panel-sub', text: '10 categories' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [
      (() => {
        const table = el('table', { class: 'tbl' });
        table.innerHTML = `<thead><tr><th>Category</th><th class="num">Planned</th><th class="num">Actual</th><th class="num">3M Avg</th><th>Progress</th><th class="num">Variance</th></tr></thead><tbody></tbody>`;
        const tbody = table.querySelector('tbody');
        for (const row of categoryTotals) {
          const tr = el('tr', {
            class: state.selection?.kind === 'category' && state.selection?.id === row.category.id ? 'selected' : '',
            onclick: () => openInspector('category', row.category.id),
          });
          const pct = Math.min(row.actual / Math.max(row.planned, 1), 1.5);
          const overBy = row.actual - row.planned;
          const barCls = overBy > row.planned * 0.05 ? 'err' : overBy > 0 ? 'warn' : 'ok';
          const avg = trailingAvg[row.category.id];
          tr.appendChild(el('td', {}, [
            el('span', { style: { display: 'inline-block', width: '8px', height: '8px', borderRadius: '50%', background: row.category.color, marginRight: '8px' } }),
            row.category.name,
          ]));
          tr.appendChild(el('td', { class: 'num', text: fmtUSD(row.planned) }));
          tr.appendChild(el('td', { class: 'num', text: fmtUSD(row.actual) }));
          tr.appendChild(el('td', { class: 'num muted', text: avg != null ? fmtUSD(avg) : '~' + fmtUSD(row.planned) }));
          tr.appendChild(el('td', {}, [
            el('div', { class: 'bar-inline ' + barCls }, [el('span', { style: { width: (Math.min(pct, 1) * 100) + '%' } })]),
          ]));
          tr.appendChild(el('td', { class: 'num ' + (overBy > 0 ? 'neg' : 'pos'), text: fmtUSD(overBy, { sign: true }) }));
          tbody.appendChild(tr);
        }
        return table;
      })(),
    ]),
  ]);

  c.appendChild(el('div', { class: 'row2' }, [donutPanel, catPanel]));

  // Transaction ledger
  const f = state.filters['budget-overview'];
  let txs = DATA.transactions.filter(t => t.category !== 'income' && !/^BX-/.test(t.id));
  const txPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Transaction Ledger' }),
      el('span', { class: 'panel-sub', text: `${txs.length} transactions` }),
      el('div', { class: 'panel-actions' }, [
        el('span', { class: 'imported-tag', text: 'Imported' }),
        el('button', { class: 'btn btn-ghost', text: 'Open file', onclick: () => osAction('Open file', 'Personal/transactions/2026-05.csv') }),
      ]),
    ]),
    el('div', { class: 'panel-body flush' }, [
      (() => {
        const table = el('table', { class: 'tbl' });
        table.innerHTML = `<thead><tr><th style="width:90px">Date</th><th>Merchant</th><th>Category</th><th>Account</th><th class="num">Amount</th><th></th></tr></thead><tbody></tbody>`;
        const tbody = table.querySelector('tbody');
        const C = cats();
        for (const t of txs) {
          const tr = el('tr', {
            class: state.selection?.kind === 'transaction' && state.selection?.id === t.id ? 'selected' : '',
            onclick: () => openInspector('transaction', t.id),
          });
          tr.appendChild(el('td', { class: 'muted mono', text: fmtDate(t.date) }));
          tr.appendChild(el('td', {}, [
            el('div', {}, [t.merchant]),
            el('div', { style: { color: 'var(--muted)', fontSize: '11px' }, text: t.description }),
          ]));
          tr.appendChild(el('td', {}, [
            el('span', { style: { display: 'inline-block', width: '8px', height: '8px', borderRadius: '50%', background: C[t.category]?.color || '#94a3b8', marginRight: '6px' } }),
            C[t.category]?.name || t.category,
          ]));
          tr.appendChild(el('td', { class: 'muted', text: t.account }));
          tr.appendChild(el('td', { class: 'num ' + (t.amount < 0 ? '' : 'pos'), text: fmtUSD2(t.amount) }));
          const tags = [];
          if (t.recurring) tags.push(el('span', { class: 'tag tag-muted', text: 'recurring' }));
          if (t.duplicate) tags.push(el('span', { class: 'tag tag-err', text: 'duplicate' }));
          if (t.flagged === 'zero-amount') tags.push(el('span', { class: 'tag tag-warn', text: 'zero' }));
          if (t.goal) tags.push(el('span', { class: 'tag tag-accent', text: 'goal' }));
          tr.appendChild(el('td', { style: { width: '1%', whiteSpace: 'nowrap', textAlign: 'right' } }, tags));
          tbody.appendChild(tr);
        }
        return table;
      })(),
    ]),
  ]);
  c.appendChild(txPanel);
}

function computeCategoryTotals() {
  const totals = {};
  for (const c of DATA.categories) totals[c.id] = { category: c, planned: c.planned, actual: 0 };
  for (const t of DATA.transactions) {
    if (!totals[t.category]) continue;
    totals[t.category].actual += Math.abs(t.amount);
  }
  return Object.values(totals);
}

function viewBudgetHistory() {
  setHeader({
    title: 'Budget History',
    breadcrumb: ['Finance', 'Budget', 'Budget History'],
    actions: [{ label: 'Export', variant: 'btn-ghost', onClick: () => {
      const labels = ['Jun','Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May'];
      const actualSeries = [8420, 8910, 9120, 8590, 9650, 8820, 9350, 9120, 8480, 8240, 9080, 9090];
      exportCSV('budget-history.csv',
        [{ label: 'month', value: 'm' }, { label: 'planned', value: 'planned' }, { label: 'actual', value: 'actual' }, { label: 'variance', value: r => r.actual - r.planned }],
        labels.map((m, i) => ({ m, planned: 8770, actual: actualSeries[i] })));
    } }],
  });
  renderFilterBar([
    { label: 'Period', value: 'Trailing 12 months', active: true },
    { label: 'View', value: 'Variance' },
  ]);
  const c = $('#content');
  const labels = ['Jun','Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar','Apr','May'];
  const plannedSeries = labels.map(_ => 8770);
  const actualSeries  = [8420, 8910, 9120, 8590, 9650, 8820, 9350, 9120, 8480, 8240, 9080, 9090];

  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Planned vs Actual · Trailing 12 months' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body' }, [
      el('div', { class: 'chart-wrap', html: lineChart([plannedSeries, actualSeries], { labels, colors: ['#94a3b8', '#3651d3'], dashed: [true, false] }) }),
      el('div', { class: 'legend' }, [
        el('span', { class: 'legend-item' }, [el('span', { class: 'legend-swatch', style: { background: '#94a3b8' } }), 'Planned']),
        el('span', { class: 'legend-item' }, [el('span', { class: 'legend-swatch', style: { background: '#3651d3' } }), 'Actual']),
      ]),
    ]),
  ]));

  const monthlyTable = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Monthly Variance' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Month</th><th class="num">Planned</th><th class="num">Actual</th><th class="num">Variance</th><th>Top driver</th><th>Note</th></tr></thead><tbody></tbody>`;
      const drivers = ['Travel','Dining','Groceries','Travel','Childcare','Utilities','Travel','Dining','Childcare','Insurance','Travel','Travel'];
      const tbody = table.querySelector('tbody');
      labels.forEach((m, i) => {
        const v = actualSeries[i] - plannedSeries[i];
        const tr = el('tr');
        tr.appendChild(el('td', { text: m + ' 2026'.replace('2026', i < 7 ? '2025' : '2026') }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(plannedSeries[i]) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(actualSeries[i]) }));
        tr.appendChild(el('td', { class: 'num ' + (v > 0 ? 'neg' : 'pos'), text: fmtUSD(v, { sign: true }) }));
        tr.appendChild(el('td', { text: drivers[i] }));
        tr.appendChild(el('td', { class: 'muted', text: i === 11 ? 'Linked to May review note' : '' }));
        tbody.appendChild(tr);
      });
      return table;
    })()]),
  ]);
  c.appendChild(monthlyTable);
}

function viewBudgetCategories() {
  setHeader({
    title: 'Categories',
    breadcrumb: ['Finance', 'Budget', 'Categories'],
    actions: [
      { label: 'New category', variant: '', onClick: addCategoryFlow },
      { label: 'Export', variant: 'btn-ghost', onClick: () => exportCSV('categories.csv',
        [{ label: 'id', value: 'id' }, { label: 'name', value: 'name' }, { label: 'group', value: 'group' }, { label: 'planned', value: 'planned' }],
        DATA.categories) },
    ],
  });
  renderFilterBar([{ label: 'Group', value: 'All' }, { label: 'Status', value: 'Active' }]);
  const c = $('#content');
  const totals = computeCategoryTotals();
  const panel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Categories · Personal/categories.csv' }),
      el('span', { class: 'panel-sub', text: `${totals.length} active` }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'imported-tag', text: 'Imported' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Category</th><th>Group</th><th>Behavior</th><th class="num">Planned (May)</th><th class="num">Actual</th><th>Status</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      for (const t of totals) {
        const tr = el('tr', {
          class: state.selection?.kind === 'category' && state.selection?.id === t.category.id ? 'selected' : '',
          onclick: () => openInspector('category', t.category.id),
        });
        tr.appendChild(el('td', {}, [
          el('span', { style: { display: 'inline-block', width: '8px', height: '8px', borderRadius: '50%', background: t.category.color, marginRight: '8px' } }),
          t.category.name,
        ]));
        tr.appendChild(el('td', { class: 'muted', text: t.category.group }));
        tr.appendChild(el('td', { class: 'muted', text: t.category.group === 'Fixed' ? 'Fixed monthly' : t.category.group === 'Savings' ? 'Auto-transfer' : 'Discretionary' }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(t.planned) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(t.actual) }));
        const overBy = t.actual - t.planned;
        const tag = overBy > t.planned * 0.05 ? el('span', { class: 'tag tag-err', text: 'over plan' }) : overBy > 0 ? el('span', { class: 'tag tag-warn', text: 'slight over' }) : el('span', { class: 'tag tag-ok', text: 'on plan' });
        tr.appendChild(el('td', {}, [tag]));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]);
  c.appendChild(panel);
}

function viewBudgetRules() {
  setHeader({
    title: 'Recurring Rules',
    breadcrumb: ['Finance', 'Personal Budget', 'Rules'],
    actions: [{ label: 'New rule', variant: '' }, { label: 'Export', variant: 'btn-ghost' }],
  });
  renderFilterBar([{ label: 'Status', value: 'Active' }]);
  const c = $('#content');
  const panel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Rules · Personal/rules.csv' }),
      el('span', { class: 'panel-sub', text: `${DATA.rules.length} rules` }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'imported-tag', text: 'Imported' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Pattern</th><th>Category</th><th>Cadence</th><th class="num">Amount</th><th>Last applied</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      const C = cats();
      for (const r of DATA.rules) {
        const tr = el('tr', {
          class: state.selection?.kind === 'rule' && state.selection?.id === r.id ? 'selected' : '',
          onclick: () => openInspector('rule', r.id),
        });
        tr.appendChild(el('td', { class: 'mono', text: r.pattern }));
        tr.appendChild(el('td', { text: C[r.category]?.name || r.category }));
        tr.appendChild(el('td', { text: r.cadence + ' · day ' + r.day }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD2(r.amount) }));
        tr.appendChild(el('td', { class: 'muted', text: fmtDate(r.lastApplied) }));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]);
  c.appendChild(panel);
}

// ---------- Savings & Investments (Goals) ------------------------------------

function viewSavingsGoals() {
  // One flat goal list — no active/archived states in v1; every listed goal is active
  const goals = DATA.goals;

  setHeader({
    title: 'Savings Goals',
    breadcrumb: ['Finance', 'Savings & Investments', 'Goals'],
    actions: [
      { label: 'New goal', variant: '', onClick: addGoalFlow },
      { label: 'Export', variant: 'btn-ghost', onClick: () => exportCSV('savings-goals.csv',
        [{ label: 'name', value: 'name' }, { label: 'target', value: 'target' }, { label: 'balance', value: 'balance' }, { label: 'monthly_target', value: 'monthlyTarget' }, { label: 'target_date', value: 'targetDate' }],
        DATA.goals) },
    ],
  });
  renderFilterBar([
    { label: 'Target year', value: 'All' },
    { kind: 'spacer' },
    { kind: 'search', placeholder: 'Search goals', onChange: (q) => {
      const ql = q.trim().toLowerCase();
      document.querySelectorAll('#content .goal-card').forEach(card => {
        card.style.display = !ql || card.textContent.toLowerCase().includes(ql) ? '' : 'none';
      });
    } },
  ]);

  const c = $('#content');

  // KPIs
  const totalTarget = goals.reduce((s, g) => s + g.target, 0);
  const totalBalance = goals.reduce((s, g) => s + g.balance, 0);
  const monthlyPlan = goals.reduce((s, g) => s + g.monthlyTarget, 0);
  const monthlyActual = goals.reduce((s, g) => s + g.monthlyActual, 0);
  const kpis = [
    { id: 'total',   label: 'Total saved',     value: fmtUSD(totalBalance), foot: 'of ' + fmtUSD(totalTarget) + ' targeted' },
    { id: 'pct',     label: 'Progress',        value: fmtPct(totalBalance / totalTarget, 0), foot: 'Across ' + goals.length + ' goals' },
    { id: 'mfunded', label: 'Funded in May',   value: fmtUSD(monthlyActual), foot: 'of ' + fmtUSD(monthlyPlan) + ' planned' },
    { id: 'gap',     label: 'Funding gap',     value: fmtUSD(monthlyPlan - monthlyActual, { sign: true }), foot: 'Below plan this month' },
  ];
  const kpiGrid = el('div', { class: 'kpi-grid' });
  for (const k of kpis) {
    kpiGrid.appendChild(el('div', { class: 'kpi-card', onclick: () => { select({ kind: 'savings-kpi', id: k.id }); } }, [
      el('div', { class: 'kpi-label', text: k.label }),
      el('div', { class: 'kpi-value', text: k.value }),
      el('div', { class: 'kpi-foot', text: k.foot }),
    ]));
  }
  c.appendChild(kpiGrid);

  // Goal cards
  const grid = el('div', { class: 'goal-grid' });
  for (const g of goals) {
    const pct = g.balance / g.target;
    const card = el('div', {
      class: 'goal-card' + (state.selection?.kind === 'goal' && state.selection?.id === g.id ? ' selected' : ''),
      onclick: () => openInspector('goal', g.id),
    }, [
      el('div', { class: 'goal-name' }, [g.name]),
      el('div', { class: 'goal-meta', text: 'Target by ' + fmtDateLong(g.targetDate) + ' · ' + g.account }),
      el('div', { class: 'goal-target' }, [
        el('span', { class: 'balance', text: fmtUSD(g.balance) }),
        el('span', { class: 'of', text: '/ ' + fmtUSD(g.target) }),
      ]),
      el('div', { class: 'goal-progress' }, [el('span', { style: { width: Math.min(pct, 1) * 100 + '%' } })]),
      el('div', { class: 'goal-foot' }, [
        el('span', { class: 'pct', text: fmtPct(pct, 0) + ' complete' }),
        el('span', { text: 'May: ' + fmtUSD(g.monthlyActual) + ' / ' + fmtUSD(g.monthlyTarget) }),
      ]),
    ]);
    grid.appendChild(card);
  }
  c.appendChild(grid);

  // Funding history table
  const fundingPanel = el('div', { class: 'panel', style: { marginTop: '16px' } }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Monthly Funding · Last 6 months' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const periods = ['2025-12','2026-01','2026-02','2026-03','2026-04','2026-05'];
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Goal</th>${periods.map(p => `<th class="num">${p.slice(2)}</th>`).join('')}<th class="num">Total</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      for (const g of goals) {
        const tr = el('tr', { onclick: () => openInspector('goal', g.id) });
        tr.appendChild(el('td', { text: g.name }));
        let total = 0;
        for (const p of periods) {
          const c = g.contributions.find(x => x.period === p);
          total += c?.amount || 0;
          tr.appendChild(el('td', { class: 'num' + (c && c.amount < g.monthlyTarget ? ' muted' : ''), text: fmtUSD(c?.amount || 0) }));
        }
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(total) }));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]);
  c.appendChild(fundingPanel);
}

// ---------- Investments ------------------------------------------------------

function viewInvestments() {
  setHeader({
    title: 'Portfolio Overview',
    breadcrumb: ['Finance', 'Savings & Investments', 'Portfolio Overview'],
    actions: [
      { label: 'Import prices', variant: '', onClick: updatePriceFlow },
      { label: 'Rebalance plan', variant: 'btn-ghost', onClick: rebalancePlanFlow },
      { label: 'Export', variant: 'btn-ghost', onClick: () => exportCSV('holdings.csv',
        [{ label: 'ticker', value: 'ticker' }, { label: 'name', value: 'name' }, { label: 'account', value: 'account' }, { label: 'sleeve', value: 'sleeve' }, { label: 'qty', value: 'qty' }, { label: 'price', value: 'price' }, { label: 'basis', value: 'basis' }, { label: 'market_value', value: h => Math.round(h.qty * h.price) }],
        DATA.holdings) },
    ],
  });
  renderFilterBar([
    { label: 'Account', value: 'All' },
    { label: 'Sleeve', value: 'All' },
    { label: 'As of', value: 'May 11, 2026', active: true },
  ]);

  const c = $('#content');

  const total = DATA.holdings.reduce((s, h) => s + h.qty * h.price, 0);
  const totalBasis = DATA.holdings.reduce((s, h) => s + h.basis, 0);
  const unrealized = total - totalBasis;
  const daily = total * 0.0042;
  const dividendYtd = 1700;
  // simple drift = max abs delta among sleeve targets
  const maxDrift = Math.max(...DATA.sleeveTargets.map(t => Math.abs(t.actual - t.target)));

  const kpis = [
    { id: 'pv',    label: 'Portfolio value', value: fmtUSD(total), delta: fmtPctSigned(unrealized / totalBasis), deltaCls: unrealized >= 0 ? 'pos' : 'neg', foot: 'Across ' + DATA.investmentAccounts.length + ' accounts' },
    { id: 'day',   label: 'Daily change',    value: fmtUSD(daily, { sign: true }),  delta: '+0.42%', deltaCls: 'pos', foot: 'Today · price file 05-11' },
    { id: 'drift', label: 'Allocation drift',value: fmtPctSigned(maxDrift, 1), delta: 'vs sleeve targets', deltaCls: maxDrift > 0.05 ? 'neg' : 'flat', foot: 'Income sleeve · over target' },
    { id: 'div',   label: 'Dividend income', value: fmtUSD(dividendYtd) + ' YTD', delta: '+$240 vs prior YTD', deltaCls: 'pos', foot: 'Qualified + ordinary' },
  ];

  const kpiGrid = el('div', { class: 'kpi-grid' });
  for (const k of kpis) {
    kpiGrid.appendChild(el('div', { class: 'kpi-card', onclick: () => select({ kind: 'inv-kpi', id: k.id }) }, [
      el('div', { class: 'kpi-label', text: k.label }),
      el('div', { class: 'kpi-value', text: k.value }),
      el('div', { class: 'kpi-delta ' + k.deltaCls, text: k.delta }),
      el('div', { class: 'kpi-foot', text: k.foot }),
    ]));
  }
  c.appendChild(kpiGrid);

  // Donut + benchmark chart
  const sleeveTotals = {};
  for (const h of DATA.holdings) {
    const sid = h.sleeve;
    sleeveTotals[sid] = (sleeveTotals[sid] || 0) + h.qty * h.price;
  }
  const sleeveColors = { 'core-growth': '#3651d3', 'income': '#0ea5e9', 'thematic': '#a855f7', 'cash': '#94a3b8' };
  const slices = Object.entries(sleeveTotals).map(([sid, v]) => ({ value: v, color: sleeveColors[sid] || '#94a3b8', label: sleeveById()[sid].name }));

  const allocPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Sleeve Allocation' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body' }, [
      el('div', { style: { display: 'flex', gap: '14px', alignItems: 'center' } }, [
        el('div', { style: { width: '140px', flex: '0 0 140px' }, html: donutChart(slices, { size: 140, thickness: 22 }) }),
        el('div', { style: { flex: '1', minWidth: 0 } }, [(() => {
          const list = el('div', { class: 'alloc-list' });
          for (const s of DATA.sleeves) {
            const value = sleeveTotals[s.id] || 0;
            const pct = value / total;
            list.appendChild(el('div', { class: 'alloc-row', onclick: () => select({ kind: 'sleeve', id: s.id }) }, [
              el('div', { class: 'alloc-name' }, [
                el('span', { style: { display: 'inline-block', width: '8px', height: '8px', borderRadius: '50%', background: sleeveColors[s.id], marginRight: '6px' } }),
                s.name,
              ]),
              el('div', { class: 'alloc-bar' }, [
                el('div', { class: 'actual', style: { width: pct * 100 + '%' } }),
              ]),
              el('div', { class: 'alloc-num', text: fmtPct(pct, 1) }),
              el('div', { class: 'alloc-num muted', text: fmtUSD(value) }),
            ]));
          }
          return list;
        })()]),
      ]),
    ]),
  ]);

  const benchPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Portfolio vs S&P 500' }),
      el('span', { class: 'panel-sub', text: 'Trailing 12 months · indexed to 100' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body' }, [
      el('div', { class: 'chart-wrap', html: lineChart([DATA.benchSeries.portfolio, DATA.benchSeries.sp500], { labels: DATA.benchSeries.labels, colors: ['#3651d3', '#94a3b8'] }) }),
      el('div', { class: 'legend' }, [
        el('span', { class: 'legend-item' }, [el('span', { class: 'legend-swatch', style: { background: '#3651d3' } }), 'Portfolio · +17.8%']),
        el('span', { class: 'legend-item' }, [el('span', { class: 'legend-swatch', style: { background: '#94a3b8' } }), 'S&P 500 · +14.4%']),
      ]),
    ]),
  ]);

  c.appendChild(el('div', { class: 'row2' }, [allocPanel, benchPanel]));

  // Holdings table
  const holdingsPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Holdings' }),
      el('span', { class: 'panel-sub', text: DATA.holdings.length + ' positions' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'imported-tag', text: 'Imported' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Ticker</th><th>Name</th><th>Account</th><th>Sleeve</th><th class="num">Qty</th><th class="num">Price</th><th class="num">Market value</th><th class="num">Unrealized</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      const AB = acctById();
      const SB = sleeveById();
      for (const h of DATA.holdings) {
        const mv = h.qty * h.price;
        const ug = mv - h.basis;
        const tr = el('tr', {
          class: state.selection?.kind === 'holding' && state.selection?.id === h.id ? 'selected' : '',
          onclick: () => openInspector('holding', h.id),
        });
        tr.appendChild(el('td', {}, [el('span', { class: 'tag tag-accent', text: h.ticker })]));
        tr.appendChild(el('td', { class: 'truncate', text: h.name }));
        tr.appendChild(el('td', { class: 'muted', text: AB[h.account]?.name || h.account }));
        tr.appendChild(el('td', { class: 'muted', text: SB[h.sleeve]?.name || h.sleeve }));
        tr.appendChild(el('td', { class: 'num', text: fmtNum(h.qty) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD2(h.price) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(mv) }));
        tr.appendChild(el('td', { class: 'num ' + (ug >= 0 ? 'pos' : 'neg'), text: fmtUSD(ug, { sign: true }) }));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]);
  c.appendChild(holdingsPanel);

  // Sleeve table at the bottom of the Portfolio overview (no dedicated sleeves screen in v1)
  c.appendChild(sleeveTargetsPanel());
}

function sleeveTargetsPanel() {
  return el('div', { class: 'panel', style: { marginTop: '16px' } }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Sleeve Targets · Investments/sleeve-targets.csv' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'imported-tag', text: 'Imported' })]),
    ]),
    el('div', { class: 'panel-body' }, [(() => {
      const list = el('div', { class: 'alloc-list' });
      for (const t of DATA.sleeveTargets) {
        const drift = t.actual - t.target;
        list.appendChild(el('div', { class: 'alloc-row', onclick: () => select({ kind: 'sleeve', id: t.sleeve }) }, [
          el('div', { class: 'alloc-name' }, [
            el('span', { class: 'tag tag-accent', text: t.ticker }),
            el('span', { style: { marginLeft: '8px', color: 'var(--muted)' }, text: sleeveById()[t.sleeve]?.name }),
          ]),
          el('div', { class: 'alloc-bar' }, [
            el('div', { class: 'actual', style: { width: t.actual * 100 * 4 + '%', maxWidth: '100%' } }),
            el('div', { class: 'target', style: { left: Math.min(t.target * 100 * 4, 100) + '%' } }),
          ]),
          el('div', { class: 'alloc-num ' + (Math.abs(drift) > 0.02 ? 'warn' : ''), text: fmtPct(t.actual, 1) }),
          el('div', { class: 'alloc-num muted', text: 'tgt ' + fmtPct(t.target, 1) }),
        ]));
      }
      return list;
    })()]),
  ]);
}

function viewInvestmentsHoldings() {
  // Holdings table is the focal point; toggle switches between the standard
  // table and the benchmark-style heat map (no dedicated benchmark screen in v1)
  const mode = state.holdingsMode || 'standard';

  setHeader({
    title: 'Holdings',
    breadcrumb: ['Finance', 'Savings & Investments', 'Holdings'],
    actions: [
      { label: 'Import prices', variant: '', onClick: updatePriceFlow },
      { label: 'Export', variant: 'btn-ghost', onClick: () => exportCSV('holdings.csv',
        [{ label: 'ticker', value: 'ticker' }, { label: 'name', value: 'name' }, { label: 'account', value: 'account' }, { label: 'sleeve', value: 'sleeve' }, { label: 'qty', value: 'qty' }, { label: 'price', value: 'price' }, { label: 'basis', value: 'basis' }],
        DATA.holdings) },
    ],
  });
  renderFilterBar([
    { label: 'Account', value: 'All' },
    { label: 'Sleeve', value: 'All' },
    { label: 'As of', value: 'May 11, 2026', active: true },
    { kind: 'spacer' },
    { kind: 'search', placeholder: 'Search holdings', onChange: (q) => {
      const ql = q.trim().toLowerCase();
      document.querySelectorAll('#content table tbody tr').forEach(tr => {
        tr.style.display = !ql || tr.textContent.toLowerCase().includes(ql) ? '' : 'none';
      });
    } },
  ]);

  const c = $('#content');

  const toggle = el('div', { class: 'view-toggle', role: 'tablist' }, [
    el('button', {
      class: 'view-toggle-btn' + (mode === 'standard' ? ' active' : ''),
      text: 'Holdings table',
      onclick: () => { state.holdingsMode = 'standard'; renderCenter(); },
    }),
    el('button', {
      class: 'view-toggle-btn' + (mode === 'heatmap' ? ' active' : ''),
      text: 'Performance heat map',
      onclick: () => { state.holdingsMode = 'heatmap'; renderCenter(); },
    }),
  ]);

  if (mode === 'heatmap') {
    c.appendChild(el('div', { class: 'panel' }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Period Returns · Investments/benchmarks/' }),
        el('div', { class: 'panel-actions' }, [
          toggle,
          el('span', { class: 'imported-tag', text: 'Imported' }),
          el('span', { class: 'tag tag-warn', text: 'Missing May data' }),
        ]),
      ]),
      el('div', { class: 'panel-body flush' }, [
        heatMapTable(DATA.benchmarkReturns, DATA.benchmarkPeriods),
      ]),
    ]));
    return;
  }

  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Holdings' }),
      el('span', { class: 'panel-sub', text: DATA.holdings.length + ' positions' }),
      el('div', { class: 'panel-actions' }, [
        toggle,
        el('span', { class: 'imported-tag', text: 'Imported' }),
      ]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Ticker</th><th>Name</th><th>Account</th><th>Sleeve</th><th class="num">Qty</th><th class="num">Price</th><th class="num">Market value</th><th class="num">Unrealized</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      const AB = acctById();
      const SB = sleeveById();
      for (const h of DATA.holdings) {
        const mv = h.qty * h.price;
        const ug = mv - h.basis;
        const tr = el('tr', {
          class: state.selection?.kind === 'holding' && state.selection?.id === h.id ? 'selected' : '',
          onclick: () => openInspector('holding', h.id),
        });
        tr.appendChild(el('td', {}, [el('span', { class: 'tag tag-accent', text: h.ticker })]));
        tr.appendChild(el('td', { class: 'truncate', text: h.name }));
        tr.appendChild(el('td', { class: 'muted', text: AB[h.account]?.name || h.account }));
        tr.appendChild(el('td', { class: 'muted', text: SB[h.sleeve]?.name || h.sleeve }));
        tr.appendChild(el('td', { class: 'num', text: fmtNum(h.qty) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD2(h.price) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(mv) }));
        tr.appendChild(el('td', { class: 'num ' + (ug >= 0 ? 'pos' : 'neg'), text: fmtUSD(ug, { sign: true }) }));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]));
}

function heatMapTable(rows, periods) {
  const table = document.createElement('table');
  table.className = 'heat-map-table';
  const thead = table.createTHead();
  const headerRow = thead.insertRow();
  const th0 = document.createElement('th');
  th0.textContent = 'Account';
  headerRow.appendChild(th0);
  for (const p of periods) {
    const th = document.createElement('th');
    th.textContent = p;
    headerRow.appendChild(th);
  }
  const tbody = table.createTBody();
  for (const row of rows) {
    const tr = tbody.insertRow();
    const isSp500 = row.accountId === 'sp500';
    if (isSp500) tr.className = 'sp500-row';
    const tdName = tr.insertCell();
    tdName.textContent = row.label;
    for (const p of periods) {
      const td = tr.insertCell();
      const v = row.returns[p];
      if (v == null) {
        td.textContent = '—';
      } else {
        td.textContent = (v >= 0 ? '+' : '') + (v * 100).toFixed(1) + '%';
        td.className = v > 0 ? 'pos' : v < 0 ? 'neg' : '';
      }
    }
  }
  return table;
}

// ---------- Business --------------------------------------------------------

function viewBusiness() {
  const entityId = state.filters['business-entity'].entity;
  const entity = entityById()[entityId];
  setHeader({
    title: 'Business · ' + entity.display,
    breadcrumb: ['Finance', 'Business', entity.display],
    actions: [
      { label: 'Import CSV', variant: '', onClick: () => importTransactionsFlow({ entityId, business: true }) },
      { label: 'New group', variant: 'btn-ghost', onClick: addEntityFlow },
      { label: 'Export P&L', variant: 'btn-ghost', onClick: () => exportBusinessPL(entityId) },
    ],
  });
  renderFilterBar([
    { label: 'Entity', value: entity.display, active: true },
    { label: 'Period', value: 'May 2026', active: true },
    { label: 'Account', value: 'All' },
    { kind: 'spacer' },
    { kind: 'search', placeholder: 'Search transactions', onChange: (q) => {
      const ql = q.trim().toLowerCase();
      document.querySelectorAll('#content table tbody tr').forEach(tr => {
        tr.style.display = !ql || tr.textContent.toLowerCase().includes(ql) ? '' : 'none';
      });
    } },
  ]);

  const c = $('#content');

  // Entity strip
  const strip = el('div', { class: 'entity-strip' });
  for (const e of DATA.entities) {
    strip.appendChild(el('div', {
      class: 'entity-pill' + (e.id === entityId ? ' active' : ''),
      onclick: () => { state.filters['business-entity'].entity = e.id; renderCenter(); },
    }, [
      el('span', { class: 'dot ' + (e.active ? 'dot-ok' : 'dot-muted') }),
      el('span', { text: e.display }),
      el('span', { style: { color: 'var(--muted)', marginLeft: '6px' }, text: e.type }),
    ]));
  }
  c.appendChild(strip);

  // KPIs
  const txs = DATA.businessTransactions.filter(t => t.entity === entityId);
  const revenue = txs.filter(t => t.amount > 0).reduce((s, t) => s + t.amount, 0);
  const expenses = txs.filter(t => t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0);
  const ni = revenue - expenses;
  const deductible = txs.filter(t => t.amount < 0 && t.deductible).reduce((s, t) => s + Math.abs(t.amount), 0);

  const kpis = [
    { id: 'rev',  label: 'Revenue · May', value: fmtUSD(revenue), delta: '+22% MoM', deltaCls: 'pos', foot: '2 invoices billed' },
    { id: 'exp',  label: 'Expenses',      value: fmtUSD(expenses), delta: 'Within plan', deltaCls: 'flat', foot: '12 transactions' },
    { id: 'ni',   label: 'Net income',    value: fmtUSD(ni, { sign: true }), delta: fmtPctSigned(ni / Math.max(revenue,1)), deltaCls: 'pos', foot: 'Margin ' + fmtPct(ni / Math.max(revenue,1), 0) },
    { id: 'ded',  label: 'Deductible',    value: fmtUSD(deductible), delta: fmtPct(deductible / Math.max(expenses,1), 0) + ' of expenses', deltaCls: 'flat', foot: 'Feeds Taxes › Prep' },
  ];
  const kpiGrid = el('div', { class: 'kpi-grid' });
  for (const k of kpis) {
    kpiGrid.appendChild(el('div', { class: 'kpi-card', onclick: () => select({ kind: 'biz-kpi', id: k.id }) }, [
      el('div', { class: 'kpi-label', text: k.label }),
      el('div', { class: 'kpi-value', text: k.value }),
      el('div', { class: 'kpi-delta ' + k.deltaCls, text: k.delta }),
      el('div', { class: 'kpi-foot', text: k.foot }),
    ]));
  }
  c.appendChild(kpiGrid);

  // 12-month P&L chart + category variance
  const labels = DATA.bizSeries.labels;
  const niSeries = labels.map((_, i) => DATA.bizSeries.revenue[i] - DATA.bizSeries.expenses[i]);

  c.appendChild(el('div', { class: 'row-2-1' }, [
    el('div', { class: 'panel' }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Monthly Net Income · Trailing 12 months' }),
        el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
      ]),
      el('div', { class: 'panel-body' }, [
        el('div', { class: 'chart-wrap', html: barChart(niSeries, { labels }) }),
      ]),
    ]),
    el('div', { class: 'panel' }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Category Budget · May' }),
        el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
      ]),
      el('div', { class: 'panel-body' }, [(() => {
        const BC = bizCatById();
        const wrap = el('div', { style: { display: 'flex', flexDirection: 'column', gap: '8px' } });
        for (const b of DATA.businessBudgets) {
          const spend = txs.filter(t => t.category === b.category && t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0);
          const pct = spend / Math.max(b.planned, 1);
          wrap.appendChild(el('div', { onclick: () => select({ kind: 'biz-cat', id: b.category }), style: { cursor: 'pointer' } }, [
            el('div', { style: { display: 'flex', justifyContent: 'space-between', fontSize: '12px', marginBottom: '4px' } }, [
              el('span', { text: BC[b.category]?.name }),
              el('span', { style: { color: 'var(--muted)' }, text: fmtUSD(spend) + ' / ' + fmtUSD(b.planned) }),
            ]),
            el('div', { class: 'bar-inline ' + (pct > 1.05 ? 'err' : pct > 0.95 ? 'warn' : 'ok') }, [
              el('span', { style: { width: Math.min(pct, 1) * 100 + '%' } }),
            ]),
          ]));
        }
        return wrap;
      })()]),
    ]),
  ]));

  // Transactions
  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Transaction Ledger · ' + entity.display }),
      el('span', { class: 'panel-sub', text: txs.length + ' transactions' }),
      el('div', { class: 'panel-actions' }, [
        el('span', { class: 'imported-tag', text: 'Imported' }),
        el('button', { class: 'btn btn-ghost', text: 'Open file', onclick: () => osAction('Open file', 'Business/transactions/' + entityId + '-2026-05.csv') }),
      ]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const BC = bizCatById();
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th style="width:90px">Date</th><th>Merchant</th><th>Description</th><th>Category</th><th class="num">Amount</th><th>Tax</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      for (const t of txs) {
        const tr = el('tr', {
          class: state.selection?.kind === 'biz-tx' && state.selection?.id === t.id ? 'selected' : '',
          onclick: () => openInspector('biz-tx', t.id),
        });
        tr.appendChild(el('td', { class: 'muted mono', text: fmtDate(t.date) }));
        tr.appendChild(el('td', { text: t.merchant }));
        tr.appendChild(el('td', { class: 'muted', text: t.description }));
        tr.appendChild(el('td', { text: t.category === 'income' ? 'Income' : (BC[t.category]?.name || t.category) }));
        tr.appendChild(el('td', { class: 'num ' + (t.amount < 0 ? '' : 'pos'), text: fmtUSD2(t.amount) }));
        tr.appendChild(el('td', {}, [
          t.deductible ? el('span', { class: 'tag tag-info', text: 'deductible' }) : el('span', { class: 'tag tag-muted', text: '—' }),
        ]));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]));
}

function viewBusinessCategories() {
  setHeader({ title: 'Business Categories', breadcrumb: ['Finance', 'Business', 'Categories'], actions: [{ label: 'New', variant: '', onClick: () => openModal({
    title: 'New business category',
    fields: [
      { key: 'name', label: 'Category name', required: true },
      { key: 'taxGroup', label: 'Tax group', value: 'Other' },
    ],
    submitLabel: 'Create',
    onSubmit: (v) => {
      DATA.businessCategories.push({ id: 'b-' + Date.now(), name: v.name, taxGroup: v.taxGroup || 'Other' });
      commit();
      toast('Business category added', 'ok');
    },
  }) }] });
  renderFilterBar([{ label: 'Tax group', value: 'All' }]);
  const c = $('#content');
  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [el('h3', { text: 'Business/categories.csv' })]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Category</th><th>Tax group</th><th>Default behavior</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      for (const c of DATA.businessCategories) {
        const tr = el('tr');
        tr.appendChild(el('td', { text: c.name }));
        tr.appendChild(el('td', { class: 'muted', text: c.taxGroup }));
        tr.appendChild(el('td', { class: 'muted', text: 'Variable' }));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]));
}

function viewBusinessBudgets() {
  setHeader({ title: 'Business Budgets', breadcrumb: ['Finance', 'Business', 'Budgets'] });
  renderFilterBar([{ label: 'Entity', value: 'Consulting LLC' }, { label: 'Period', value: 'May 2026' }]);
  viewBusiness();
}

// ---------- Taxes -----------------------------------------------------------

function viewTaxes() {
  setHeader({
    title: 'Taxes · 2026',
    breadcrumb: ['Finance', 'Taxes', 'Current Tax Year'],
    actions: [
      { label: 'Export prep packet', variant: '', onClick: exportTaxPacket },
      { label: 'New payment', variant: 'btn-ghost', onClick: addPaymentFlow },
    ],
  });
  renderFilterBar([
    { label: 'Tax year', value: '2026', active: true },
    { label: 'Jurisdiction', value: 'All' },
  ]);

  const c = $('#content');
  const fedPaid = DATA.estimatedPayments.filter(e => e.jurisdiction === 'Federal').reduce((s, e) => s + e.paid, 0);
  const fedDue = DATA.estimatedPayments.filter(e => e.jurisdiction === 'Federal').reduce((s, e) => s + e.amount, 0);
  const realized = DATA.realizedGains.reduce((s, r) => s + r.gain, 0);
  const incomeTotal = DATA.incomeSummary.reduce((s, r) => s + r.ytd, 0);
  const missing = 1; // benchmark data missing

  const kpis = [
    { id: 'pay',  label: 'Estimated paid',  value: fmtUSD(fedPaid), foot: fmtUSD(fedDue - fedPaid) + ' remaining for 2026', delta: 'Q1 paid · Q2 due Jun 15', deltaCls: 'flat' },
    { id: 'gain', label: 'Realized gains', value: fmtUSD(realized, { sign: true }), foot: '2 long, 1 short term', delta: '+$6,020 long term', deltaCls: realized >= 0 ? 'pos' : 'neg' },
    { id: 'inc',  label: 'Income · taxable',value: fmtUSD(incomeTotal), foot: 'Dividends + interest YTD', delta: '+$240 vs prior YTD', deltaCls: 'pos' },
    { id: 'miss', label: 'Open prep items', value: String(DATA.taxChecklist.filter(c => !c.done).length), foot: 'On checklist', delta: missing ? '1 missing input' : '0 missing', deltaCls: 'warn' },
  ];
  const kpiGrid = el('div', { class: 'kpi-grid' });
  for (const k of kpis) {
    kpiGrid.appendChild(el('div', { class: 'kpi-card', onclick: () => select({ kind: 'tax-kpi', id: k.id }) }, [
      el('div', { class: 'kpi-label', text: k.label }),
      el('div', { class: 'kpi-value', text: k.value }),
      el('div', { class: 'kpi-delta ' + k.deltaCls, text: k.delta }),
      el('div', { class: 'kpi-foot', text: k.foot }),
    ]));
  }
  c.appendChild(kpiGrid);

  // Estimated payments (inline — no dedicated screen; the prep checklist lives on its own screen)
  const paymentsPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Estimated Payment Schedule · 2026' }),
      el('span', { class: 'panel-sub', text: 'Taxes/estimated-payments.csv' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'imported-tag', text: 'Imported' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Quarter</th><th>Jurisdiction</th><th>Due</th><th class="num">Amount</th><th class="num">Paid</th><th>Status</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      for (const p of DATA.estimatedPayments) {
        const tr = el('tr', {
          class: state.selection?.kind === 'estimatedPayment' && state.selection?.id === p.id ? 'selected' : '',
          onclick: () => openInspector('estimatedPayment', p.id),
        });
        tr.appendChild(el('td', { text: 'Q' + p.quarter + ' ' + p.year }));
        tr.appendChild(el('td', { class: 'muted', text: p.jurisdiction }));
        tr.appendChild(el('td', { text: fmtDateLong(p.due) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(p.amount) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(p.paid) }));
        const tag = p.status === 'paid' ? el('span', { class: 'tag tag-ok', text: 'paid' }) : el('span', { class: 'tag tag-warn', text: 'upcoming' });
        tr.appendChild(el('td', {}, [tag]));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]);

  c.appendChild(paymentsPanel);

  // Realized gains + Income summary
  const gainsPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Realized Gains & Losses · YTD' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Ticker</th><th>Closed</th><th>Term</th><th class="num">Proceeds</th><th class="num">Basis</th><th class="num">Gain</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      for (const r of DATA.realizedGains) {
        const tr = el('tr', {
          class: state.selection?.kind === 'realized' && state.selection?.id === r.id ? 'selected' : '',
          onclick: () => openInspector('realized', r.id),
        });
        tr.appendChild(el('td', {}, [el('span', { class: 'tag tag-accent', text: r.ticker })]));
        tr.appendChild(el('td', { class: 'muted', text: fmtDateLong(r.closed) }));
        tr.appendChild(el('td', {}, [el('span', { class: 'tag tag-muted', text: r.term })]));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(r.proceeds) }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(r.basis) }));
        tr.appendChild(el('td', { class: 'num ' + (r.gain >= 0 ? 'pos' : 'neg'), text: fmtUSD(r.gain, { sign: true }) }));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]);

  const incomePanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Dividend & Interest Income · YTD' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Kind</th><th class="num">YTD</th><th>Source</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      for (const r of DATA.incomeSummary) {
        const tr = el('tr');
        tr.appendChild(el('td', { text: r.kind }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(r.ytd) }));
        tr.appendChild(el('td', {}, [el('span', { class: 'path-chip', text: r.source })]));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]);

  c.appendChild(el('div', { class: 'row2' }, [gainsPanel, incomePanel]));

  // Business tax-prep summary
  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Business Tax-Prep Summary · Consulting LLC' }),
      el('span', { class: 'panel-sub', text: 'YTD' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const BC = bizCatById();
      const groups = {};
      for (const t of DATA.businessTransactions.filter(t => t.amount < 0)) {
        const cat = BC[t.category];
        if (!cat) continue;
        groups[cat.taxGroup] = (groups[cat.taxGroup] || 0) + Math.abs(t.amount);
      }
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Tax group</th><th class="num">YTD spend</th><th>Note</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      for (const [g, amt] of Object.entries(groups)) {
        const tr = el('tr');
        tr.appendChild(el('td', { text: g }));
        tr.appendChild(el('td', { class: 'num', text: fmtUSD(amt) }));
        tr.appendChild(el('td', { class: 'muted', text: g === 'Meals (50%)' ? '50% deductibility applied' : 'Fully deductible' }));
        tbody.appendChild(tr);
      }
      return table;
    })()]),
  ]));
}

// ---------- Notes ------------------------------------------------------------

function viewNotes() {
  let label = 'Monthly Reviews';
  let notes = DATA.notes;
  if (state.view === 'notes-strategy') { label = 'Strategy Notes'; notes = notes.filter(n => n.type === 'strategy'); }
  if (state.view === 'notes-business') { label = 'Business Notes'; notes = notes.filter(n => n.type === 'business-review'); }
  if (state.view === 'notes-tax')      { label = 'Tax Notes';      notes = notes.filter(n => n.type === 'tax-note'); }
  if (state.view === 'notes-monthly')  { label = 'Monthly Reviews';notes = notes.filter(n => n.type === 'monthly-review'); }

  setHeader({
    title: 'Notes',
    breadcrumb: ['Finance', 'Notes', label],
    actions: [
      { label: 'New note', variant: '' },
      { label: 'Open folder', variant: 'btn-ghost' },
    ],
  });
  renderFilterBar([
    { label: 'Type', value: state.view === 'notes-strategy' ? 'Strategy' : state.view === 'notes-business' ? 'Business' : state.view === 'notes-tax' ? 'Tax' : 'Monthly review', active: true },
    { label: 'Period', value: 'All' },
    { kind: 'spacer' },
    { kind: 'search', placeholder: 'Search notes', onChange: () => {} },
  ]);

  const c = $('#content');
  const selectedId = (state.selection?.kind === 'note' ? state.selection.id : null) || notes[0]?.id;
  const note = notes.find(n => n.id === selectedId) || notes[0];

  const grid = el('div', { class: 'row-1-2' });

  const listWrap = el('div', { class: 'note-list' });
  for (const n of notes) {
    const row = el('div', {
      class: 'note-row' + (note && note.id === n.id ? ' selected' : ''),
      onclick: () => { select({ kind: 'note', id: n.id }); renderCenter(); },
    }, [
      el('div', { class: 'note-title', text: n.title }),
      el('div', { class: 'note-meta' }, [
        el('span', { class: 'tag tag-muted', text: n.type }),
        n.period ? el('span', { text: n.period }) : null,
        el('span', { text: 'Updated ' + fmtDateLong(n.updated) }),
      ]),
    ]);
    listWrap.appendChild(row);
  }
  grid.appendChild(listWrap);

  // Preview
  if (note) {
    const preview = el('div', { class: 'md-preview' });
    // Build front matter block
    const fmText = '---\n' + Object.entries(note.frontMatter).map(([k, v]) => {
      const vv = Array.isArray(v) ? '[' + v.join(', ') + ']' : v;
      return `${k}: ${vv}`;
    }).join('\n') + '\n---';
    preview.appendChild(el('pre', { class: 'frontmatter-block', text: fmText }));
    preview.innerHTML += renderMarkdown(note.body);
    grid.appendChild(preview);
  } else {
    grid.appendChild(el('div', { class: 'md-preview', text: 'No notes in this group.' }));
  }
  c.appendChild(grid);
}

function renderMarkdown(src) {
  if (!src) return '';
  const escape = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const inline = s => escape(s)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\*([^*]+)\*/g, '<em>$1</em>');
  const lines = src.split('\n');
  let html = '';
  let inList = false;
  let inOL = false;
  let inBQ = false;
  const closeList = () => { if (inList) { html += '</ul>'; inList = false; } if (inOL) { html += '</ol>'; inOL = false; } };
  const closeBQ = () => { if (inBQ) { html += '</blockquote>'; inBQ = false; } };
  for (let line of lines) {
    if (line.startsWith('# ')) { closeList(); closeBQ(); html += `<h1>${inline(line.slice(2))}</h1>`; continue; }
    if (line.startsWith('## ')) { closeList(); closeBQ(); html += `<h2>${inline(line.slice(3))}</h2>`; continue; }
    if (line.startsWith('### ')) { closeList(); closeBQ(); html += `<h3>${inline(line.slice(4))}</h3>`; continue; }
    if (line.startsWith('> ')) {
      closeList();
      if (!inBQ) { html += '<blockquote>'; inBQ = true; }
      html += inline(line.slice(2)) + '<br>';
      continue;
    } else { closeBQ(); }
    if (line.startsWith('- ')) {
      if (inOL) { html += '</ol>'; inOL = false; }
      if (!inList) { html += '<ul>'; inList = true; }
      html += `<li>${inline(line.slice(2))}</li>`;
      continue;
    }
    if (/^\d+\.\s/.test(line)) {
      if (inList) { html += '</ul>'; inList = false; }
      if (!inOL) { html += '<ol>'; inOL = true; }
      html += `<li>${inline(line.replace(/^\d+\.\s/, ''))}</li>`;
      continue;
    }
    closeList();
    if (line.trim() === '') { html += ''; continue; }
    html += `<p>${inline(line)}</p>`;
  }
  closeList();
  closeBQ();
  return html;
}

// ---------- Issues -----------------------------------------------------------

function viewIssues() {
  let label = 'All Issues';
  let issues = DATA.issues;
  if (state.view === 'issues-repairable') { label = 'Repairable'; issues = issues.filter(i => i.repairable); }
  if (state.view === 'issues-manual')     { label = 'Manual Review'; issues = issues.filter(i => !i.repairable); }

  setHeader({
    title: 'Issues',
    breadcrumb: ['Finance', 'Issues', label],
    actions: [
      { label: 'Apply repairable fixes', variant: 'btn-primary' },
      { label: 'Export issue list', variant: 'btn-ghost' },
      { label: 'Reindex', variant: 'btn-ghost' },
    ],
  });
  renderFilterBar([
    { label: 'Severity', value: 'All' },
    { label: 'Domain', value: 'All' },
    { label: 'Sort', value: 'Severity', active: true },
    { kind: 'spacer' },
    { kind: 'search', placeholder: 'Search issues', onChange: () => {} },
  ]);

  const c = $('#content');

  // KPI strip
  const errs = issues.filter(i => i.severity === 'error').length;
  const warns = issues.filter(i => i.severity === 'warning').length;
  const infos = issues.filter(i => i.severity === 'info').length;
  const repair = issues.filter(i => i.repairable).length;

  const kpiGrid = el('div', { class: 'kpi-grid' });
  for (const k of [
    { label: 'Errors',    value: String(errs), foot: 'Blocking', deltaCls: 'neg', delta: 'Must resolve' },
    { label: 'Warnings',  value: String(warns), foot: 'Review recommended', deltaCls: 'flat', delta: 'Not blocking' },
    { label: 'Info',      value: String(infos), foot: 'Cosmetic / cleanup', deltaCls: 'flat', delta: 'Optional' },
    { label: 'Repairable',value: String(repair), foot: 'Auto-fixable with preview', deltaCls: 'flat', delta: 'Single click' },
  ]) {
    kpiGrid.appendChild(el('div', { class: 'kpi-card' }, [
      el('div', { class: 'kpi-label', text: k.label }),
      el('div', { class: 'kpi-value', text: k.value }),
      el('div', { class: 'kpi-delta ' + k.deltaCls, text: k.delta }),
      el('div', { class: 'kpi-foot', text: k.foot }),
    ]));
  }
  c.appendChild(kpiGrid);

  // Groups
  const groups = {};
  for (const i of issues) {
    groups[i.group] = groups[i.group] || [];
    groups[i.group].push(i);
  }

  for (const [groupName, items] of Object.entries(groups)) {
    const groupEl = el('div', { class: 'issue-group' }, [
      el('div', { class: 'issue-group-head' }, [
        el('span', { text: groupName }),
        el('span', { class: 'count', text: String(items.length) }),
      ]),
    ]);
    for (const i of items) {
      const sevRowCls = i.severity === 'error' ? 'issue-row--error' : i.severity === 'warning' ? 'issue-row--warning' : 'issue-row--info';
      const sevDotCls = i.severity === 'error' ? 'sev-err' : i.severity === 'warning' ? 'sev-warn' : 'sev-info';
      const row = el('div', {
        class: 'issue-row ' + sevRowCls + (state.selection?.kind === 'issue' && state.selection?.id === i.id ? ' selected' : ''),
        onclick: () => openInspector('issue', i.id),
      }, [
        el('span', { class: 'sev-dot ' + sevDotCls }),
        el('div', { style: { flex: '1', minWidth: 0 } }, [
          el('div', { class: 'issue-title', text: i.title }),
          el('div', { class: 'issue-msg', text: i.message }),
        ]),
        el('span', { class: 'path-chip' }, [
          i.filePath || i.file + (i.row ? ':' + i.row : ''),
          el('span', { class: 'sync-badge sync-badge--available' }),
        ]),
        i.repairable ? el('span', { class: 'issue-badge--repairable', text: 'repairable' }) : el('span', { class: 'issue-badge--manual', text: 'manual' }),
      ]);
      groupEl.appendChild(row);
    }
    c.appendChild(groupEl);
  }
}

// ---------- Settings ---------------------------------------------------------

function viewSettingsWorkspace() {
  setHeader({ title: 'Settings · Workspace', breadcrumb: ['Finance', 'Settings', 'Workspace'], actions: [] });
  renderFilterBar([]);
  const c = $('#content');
  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [el('h3', { text: 'Workspace' })]),
    el('div', { class: 'panel-body' }, [
      el('div', { class: 'insp-row' }, [el('span', { class: 'k', text: 'Workspace path' }), el('span', { class: 'v' }, [el('span', { class: 'path-chip' }, ['iCloud Drive › Finance', el('span', { class: 'sync-badge sync-badge--available' })])])]),
      el('div', { class: 'insp-row' }, [el('span', { class: 'k', text: 'Workspace ID' }), el('span', { class: 'v mono', text: DATA.workspace.id })]),
      el('div', { class: 'insp-row' }, [el('span', { class: 'k', text: 'Default currency' }), el('span', { class: 'v', text: 'USD' })]),
      el('div', { class: 'insp-row' }, [el('span', { class: 'k', text: 'Timezone' }), el('span', { class: 'v', text: 'America/Denver' })]),
      el('div', { class: 'insp-row' }, [el('span', { class: 'k', text: 'Last indexed' }), el('span', { class: 'v', text: DATA.workspace.lastIndexed })]),
      el('div', { class: 'insp-row' }, [el('span', { class: 'k', text: 'iCloud sync' }), el('span', { class: 'v' }, [
        el('span', { class: 'sync-pill', id: 'ws-sync-pill', dataset: { state: state.syncState } }, [
          el('span', { class: 'sync-pill-icon' }),
          el('span', { class: 'sync-pill-label', text: state.syncState }),
        ]),
      ])]),
    ]),
  ]));

  // Reviewer controls
  c.appendChild(el('div', { class: 'panel', style: { marginTop: '12px' } }, [
    el('div', { class: 'panel-head' }, [el('h3', { text: 'Prototype Review Controls' })]),
    el('div', { class: 'panel-body' }, [
      el('p', { style: { fontSize: '12px', color: 'var(--muted)', marginBottom: '12px' }, text: 'These buttons control prototype state for design review. They do not represent real app functionality.' }),
      el('div', { style: { display: 'flex', gap: '8px', flexWrap: 'wrap' } }, [
        // T019: Show onboarding flow button
        el('button', { class: 'btn', onclick: () => navigate('onboarding') }, ['Show onboarding flow']),
        // T023: Cycle sync state button (appended, does not replace T019)
        el('button', { class: 'btn btn-ghost', onclick: () => {
          const states = ['synced', 'syncing', 'stale', 'error'];
          const idx = states.indexOf(state.syncState);
          state.syncState = states[(idx + 1) % states.length];
          renderSidebar();
          renderCenter();
        } }, ['Cycle sync state']),
        // T025: Show indexing state button (appended, does not replace T019 or T023)
        el('button', { class: 'btn btn-ghost', onclick: () => navigate('indexing-progress') }, ['Show indexing state']),
        // r5: reset persisted prototype edits back to the seed dataset
        el('button', { class: 'btn btn-danger', onclick: () => openModal({
          title: 'Reset prototype data?',
          subtitle: 'Discards every add, import, repair, and checklist change you made and reloads the seed dataset.',
          submitLabel: 'Reset workspace',
          danger: true,
          onSubmit: () => Store.reset(),
        }) }, ['Reset prototype data']),
      ]),
      el('p', { style: { fontSize: '11.5px', color: 'var(--muted)', marginTop: '12px' }, text: Store.isDirty()
        ? 'Local edits are saved to this browser (localStorage). They persist across refreshes until reset.'
        : 'No local edits yet — showing the seed dataset. Adds, imports, and repairs will be saved to this browser.' }),
    ]),
  ]));
}

function viewSettingsSchema() {
  setHeader({ title: 'Settings · Schema', breadcrumb: ['Finance', 'Settings', 'Schema'], actions: [] });
  renderFilterBar([]);
  const c = $('#content');
  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [el('h3', { text: 'Schema Registry' })]),
    el('div', { class: 'panel-body' }, [
      el('p', { style: { color: 'var(--muted)', fontSize: '12px' }, text: 'Schema version ' + DATA.workspace.schemaVersion + ' · 24 file types defined' }),
    ]),
  ]));
}

// ---------- Onboarding (T018) ------------------------------------------------

function viewOnboarding() {
  setHeader({
    title: 'First-Launch Onboarding',
    breadcrumb: ['Finance', 'Settings', 'Workspace', 'Onboarding'],
    actions: [{ label: '← Back to Workspace', variant: 'btn-ghost', onClick: () => navigate('settings-workspace') }],
  });
  renderFilterBar([]);
  const c = $('#content');

  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'iCloud Workspace States' }),
      el('span', { class: 'panel-sub', text: '7 states + success' }),
    ]),
    el('div', { class: 'panel-body' }, [
      el('div', { class: 'onboarding-grid' }, DATA.iCloudStates.map(ws => {
        const severity = ['available', 'workspace-created'].includes(ws.id) ? 'ok' :
                         ['not-signed-in', 'container-unavailable', 'conflict-detected', 'file-missing-locally'].includes(ws.id) ? 'err' :
                         ws.id === 'syncing' ? 'neutral' : 'warn';
        return el('div', { class: 'onboarding-card onboarding-card--' + severity }, [
          el('span', { class: 'state-icon', text: ws.icon }),
          el('div', { class: 'state-label', text: ws.label }),
          el('div', { class: 'state-desc', text: ws.description }),
          ws.recoveryAction
            ? el('button', { class: 'btn state-action', text: ws.recoveryAction, onclick: () => {
                if (ws.id === 'workspace-created') { navigate('accounts-overview'); return; }
                toast(ws.recoveryAction + ' — ' + ws.label, 'info');
              } })
            : null,
          ws.id === 'workspace-created'
            ? el('div', { style: { marginTop: '8px', fontSize: '11.5px', color: 'var(--muted)' } }, [
                el('div', { text: 'Path: ' + DATA.workspace.path }),
                el('div', { text: 'ID: ' + DATA.workspace.id }),
              ])
            : null,
        ]);
      })),
    ]),
  ]));
}

// ---------- Indexing Progress (T025) ------------------------------------------

function viewIndexingProgress() {
  setHeader({
    title: 'Workspace Indexing',
    breadcrumb: ['Finance', 'Settings', 'Workspace', 'Indexing'],
    actions: [{ label: '← Back to Workspace', variant: 'btn-ghost', onClick: () => navigate('settings-workspace') }],
  });
  renderFilterBar([]);
  const c = $('#content');
  c.appendChild(el('div', { class: 'indexing-view' }, [
    el('h2', { text: 'Indexing workspace…' }),
    el('p', { style: { color: 'var(--muted)', fontSize: '12px' }, text: '47 of 83 files scanned' }),
    el('div', { class: 'indexing-progress-bar' }, [
      el('div', { class: 'indexing-progress-bar-fill', style: { width: '57%' } }),
    ]),
    el('p', { style: { color: 'var(--muted)', fontSize: '11.5px', marginTop: '6px' }, text: 'Estimated: ~12 seconds remaining' }),
  ]));
  c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px', maxWidth: '640px', margin: '16px auto 0' } }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Classification Warnings' }),
      el('span', { class: 'panel-sub', text: '1 item needs attention' }),
    ]),
    el('div', { class: 'panel-body flush' }, [
      (() => {
        const table = el('table', { class: 'tbl' });
        table.innerHTML = `<thead><tr><th>File</th><th>Issue</th><th>Action</th></tr></thead><tbody></tbody>`;
        const tbody = table.querySelector('tbody');
        const tr = tbody.insertRow();
        const td1 = tr.insertCell(); td1.innerHTML = '<span class="path-chip">Investments/benchmarks/sp500.csv<span class="sync-badge sync-badge--missing"></span></span>';
        const td2 = tr.insertCell(); td2.textContent = 'File exists in iCloud but not downloaded locally';
        const td3 = tr.insertCell();
        td3.appendChild(el('button', { class: 'btn btn-ghost', style: { fontSize: '11.5px' }, text: 'Download', onclick: () => osAction('Download from iCloud', 'Investments/benchmarks/sp500.csv') }));
        return table;
      })(),
    ]),
  ]));
}

// ---------- Account Entities (Dynamic Themes) ---------------------------------

function viewAccountEntity(entityId) {
  const entity = DATA.entities.find(e => e.id === entityId);
  if (!entity) return;

  state.entityTabs = state.entityTabs || {};
  const activeTab = state.entityTabs[entityId] || 'dashboard';

  if (entity.type === 'business') {
    setHeader({
      title: 'Business · ' + entity.display,
      breadcrumb: ['Finance', 'Accounts', entity.display],
      actions: [
        { label: 'Import CSV', variant: '', onClick: () => importTransactionsFlow({ entityId, business: true }) },
        { label: 'New group', variant: 'btn-ghost', onClick: addEntityFlow },
        { label: 'Export P&L', variant: 'btn-ghost', onClick: () => exportBusinessPL(entityId) },
      ],
    });
    renderFilterBar([]);

    const c = $('#content');

    const txs = DATA.transactions.filter(t => t.entityId === entityId);

    // KPIs
    const revenue = txs.filter(t => t.amount > 0).reduce((s, t) => s + t.amount, 0);
    const expenses = txs.filter(t => t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0);
    const ni = revenue - expenses;
    const deductible = txs.filter(t => t.amount < 0 && t.deductible).reduce((s, t) => s + Math.abs(t.amount), 0);

    const kpis = [
      { id: 'rev',  label: 'Revenue · May', value: fmtUSD(revenue), delta: '+22% MoM', deltaCls: 'pos', foot: '2 invoices billed' },
      { id: 'exp',  label: 'Expenses',      value: fmtUSD(expenses), delta: 'Within plan', deltaCls: 'flat', foot: txs.filter(t => t.amount < 0).length + ' transactions' },
      { id: 'ni',   label: 'Net income',    value: fmtUSD(ni, { sign: true }), delta: fmtPctSigned(ni / Math.max(revenue,1)), deltaCls: 'pos', foot: 'Margin ' + fmtPct(ni / Math.max(revenue,1), 0) },
      { id: 'ded',  label: 'Deductible',    value: fmtUSD(deductible), delta: fmtPct(deductible / Math.max(expenses,1), 0) + ' of expenses', deltaCls: 'flat', foot: 'Feeds Taxes › Prep' },
    ];
    const kpiGrid = el('div', { class: 'kpi-grid' });
    for (const k of kpis) {
      kpiGrid.appendChild(el('div', { class: 'kpi-card', onclick: () => select({ kind: 'biz-kpi', id: k.id }) }, [
        el('div', { class: 'kpi-label', text: k.label }),
        el('div', { class: 'kpi-value', text: k.value }),
        el('div', { class: 'kpi-delta ' + k.deltaCls, text: k.delta }),
        el('div', { class: 'kpi-foot', text: k.foot }),
      ]));
    }
    c.appendChild(kpiGrid);

    // Monthly net income chart
    const labels = DATA.bizSeries.labels;
    const niSeries = labels.map((_, i) => DATA.bizSeries.revenue[i] - DATA.bizSeries.expenses[i]);
    c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px' } }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Monthly Net Income · Trailing 12 months' }),
        el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
      ]),
      el('div', { class: 'panel-body' }, [
        el('div', { class: 'chart-wrap', html: barChart(niSeries, { labels }) }),
      ]),
    ]));

    // Individual accounts in this group (Round 5 #4)
    const acctSection = accountsCardSection(entityId, 'Accounts');
    if (acctSection) c.appendChild(acctSection);

    // Transaction ledger — inline below the net-income chart (Round 5 #2)
    c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px' } }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Transaction Ledger · ' + entity.display }),
        el('span', { class: 'panel-sub', text: txs.length + ' transactions' }),
        el('div', { class: 'panel-actions' }, [
          el('span', { class: 'imported-tag', text: 'Imported' }),
        ]),
      ]),
      el('div', { class: 'panel-body flush' }, [(() => {
        const BC = bizCatById();
        const table = el('table', { class: 'tbl' });
        table.innerHTML = `<thead><tr><th style="width:90px">Date</th><th>Merchant</th><th>Description</th><th>Category</th><th class="num">Amount</th><th>Tax</th></tr></thead><tbody></tbody>`;
        const tbody = table.querySelector('tbody');
        for (const t of txs) {
          const tr = el('tr', {
            class: state.selection?.kind === 'biz-tx' && state.selection?.id === t.id ? 'selected' : '',
            onclick: () => openInspector('biz-tx', t.id),
          });
          tr.appendChild(el('td', { class: 'muted mono', text: fmtDate(t.date) }));
          tr.appendChild(el('td', { text: t.merchant }));
          tr.appendChild(el('td', { class: 'muted', text: t.description }));
          tr.appendChild(el('td', { text: t.category === 'income' ? 'Income' : (BC[t.category]?.name || t.category) }));
          tr.appendChild(el('td', { class: 'num ' + (t.amount < 0 ? '' : 'pos'), text: fmtUSD2(t.amount) }));
          tr.appendChild(el('td', {}, [
            t.deductible ? el('span', { class: 'tag tag-info', text: 'deductible' }) : el('span', { class: 'tag tag-muted', text: '—' }),
          ]));
          tbody.appendChild(tr);
        }
        return table;
      })()]),
    ]));

    // Category budgets
    c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px' } }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Category Budget · ' + entity.display }),
        el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
      ]),
      el('div', { class: 'panel-body' }, [(() => {
        const BC = bizCatById();
        const wrap = el('div', { style: { display: 'flex', flexDirection: 'column', gap: '12px' } });
        for (const b of DATA.businessBudgets) {
          const spend = txs.filter(t => t.category === b.category && t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0);
          const pct = spend / Math.max(b.planned, 1);
          wrap.appendChild(el('div', { onclick: () => select({ kind: 'biz-cat', id: b.category }), style: { cursor: 'pointer' } }, [
            el('div', { style: { display: 'flex', justifyContent: 'space-between', fontSize: '12px', marginBottom: '4px' } }, [
              el('span', { text: BC[b.category]?.name }),
              el('span', { style: { color: 'var(--muted)' }, text: fmtUSD(spend) + ' / ' + fmtUSD(b.planned) }),
            ]),
            el('div', { class: 'bar-inline ' + (pct > 1.05 ? 'err' : pct > 0.95 ? 'warn' : 'ok') }, [
              el('span', { style: { width: Math.min(pct, 1) * 100 + '%' } }),
            ]),
          ]));
        }
        return wrap;
      })()]),
    ]));
  } else if (entity.type === 'employment') {
    setHeader({
      title: 'Employment · ' + entity.display,
      breadcrumb: ['Finance', 'Accounts', entity.display],
      actions: [
        { label: 'Import Paystub', variant: '', onClick: () => addPaystubFlow(entityId) },
      ],
    });
    renderFilterBar([
      { label: 'Period', value: 'May 2026', active: true },
    ]);

    const c = $('#content');
    
    // Group of accounts for Employment
    const empAccounts = DATA.accounts.filter(a => a.entityId === entityId);
    
    // Calculate metrics
    const payrollAccount = empAccounts.find(a => a.type === 'payroll');
    const hsaAccount = empAccounts.find(a => a.type === 'hsa');
    
    const ytdGross = payrollAccount ? payrollAccount.ytdNetIncome : 38604;
    const monthlyInflow = payrollAccount ? payrollAccount.monthlyInflow : 9651;
    const hsaBal = hsaAccount ? hsaAccount.ytdNetIncome : 1380;
    
    const kpis = [
      { label: 'Gross Pay (Monthly)', value: fmtUSD(monthlyInflow), foot: 'Base Salary' },
      { label: 'YTD Gross Pay', value: fmtUSD(ytdGross), foot: 'Tax Year 2026' },
      { label: 'HSA Balance YTD', value: fmtUSD(hsaBal), foot: 'Fidelity HSA' },
      { label: 'Employer stock vests', value: '$8,450', foot: 'Next vest Jun 15' },
    ];
    const kpiGrid = el('div', { class: 'kpi-grid' });
    for (const k of kpis) {
      kpiGrid.appendChild(el('div', { class: 'kpi-card' }, [
        el('div', { class: 'kpi-label', text: k.label }),
        el('div', { class: 'kpi-value', text: k.value }),
        el('div', { class: 'kpi-foot', text: k.foot }),
      ]));
    }
    c.appendChild(kpiGrid);

    // Individual accounts in this group (Round 5 #4)
    const empAcctSection = accountsCardSection(entityId, 'Accounts');
    if (empAcctSection) c.appendChild(empAcctSection);

    // Paycheck deposits ledger
    const txs = DATA.transactions.filter(t => t.entityId === entityId);
    c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px' } }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Paycheck Deposits & Benefits' }),
        el('span', { class: 'panel-sub', text: txs.length + ' transactions' }),
      ]),
      el('div', { class: 'panel-body flush' }, [(() => {
        const table = el('table', { class: 'tbl' });
        table.innerHTML = `<thead><tr><th style="width:90px">Date</th><th>Employer</th><th>Description</th><th>Account</th><th class="num">Amount</th></tr></thead><tbody></tbody>`;
        const tbody = table.querySelector('tbody');
        for (const t of txs) {
          const tr = el('tr', {
            class: state.selection?.kind === 'transaction' && state.selection?.id === t.id ? 'selected' : '',
            onclick: () => openInspector('transaction', t.id),
          });
          tr.appendChild(el('td', { class: 'muted mono', text: fmtDate(t.date) }));
          tr.appendChild(el('td', { text: t.merchant }));
          tr.appendChild(el('td', { class: 'muted', text: t.description }));
          tr.appendChild(el('td', { text: t.account }));
          tr.appendChild(el('td', { class: 'num pos', text: fmtUSD2(t.amount) }));
          tbody.appendChild(tr);
        }
        return table;
      })()]),
    ]));
  } else if (entity.type === 'personal') {
    setHeader({
      title: 'Personal · ' + entity.display,
      breadcrumb: ['Finance', 'Accounts', entity.display],
      actions: [
        { label: 'Add Account', variant: '', onClick: () => addAccountFlow(entityId) },
      ],
    });
    renderFilterBar([
      { label: 'Period', value: 'May 2026', active: true },
    ]);

    const c = $('#content');
    
    // Accounts and metrics
    const persAccounts = DATA.accounts.filter(a => a.entityId === entityId);
    const totalInflow = persAccounts.reduce((s, a) => s + a.monthlyInflow, 0);
    const totalYtd = persAccounts.reduce((s, a) => s + a.ytdNetIncome, 0);

    const kpis = [
      { label: 'Net Worth', value: fmtUSD(DATA.overview.netWorth[DATA.overview.netWorth.length - 1]), foot: '+$8,540 MoM' },
      { label: 'Monthly Inflow', value: fmtUSD(totalInflow), foot: 'Everyday Banking' },
      { label: 'YTD Net Income', value: fmtUSD(totalYtd), foot: 'Savings & Investments' },
    ];
    const kpiGrid = el('div', { class: 'kpi-grid' });
    for (const k of kpis) {
      kpiGrid.appendChild(el('div', { class: 'kpi-card' }, [
        el('div', { class: 'kpi-label', text: k.label }),
        el('div', { class: 'kpi-value', text: k.value }),
        el('div', { class: 'kpi-foot', text: k.foot }),
      ]));
    }
    c.appendChild(kpiGrid);

    // Cash flow trend chart
    const labels = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May'];
    const netWorthSeries = DATA.overview.netWorth;

    c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px' } }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Net Worth Trend' }),
        el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
      ]),
      el('div', { class: 'panel-body' }, [
        el('div', { class: 'chart-wrap', html: lineChart([netWorthSeries], { labels, colors: ['#3651d3'] }) }),
      ]),
    ]));

    // Individual accounts in this group (Round 5 #4)
    const persAcctSection = accountsCardSection(entityId, 'Accounts');
    if (persAcctSection) c.appendChild(persAcctSection);

    // Personal transactions ledger
    const txs = DATA.transactions.filter(t => t.entityId === entityId);
    c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px' } }, [
      el('div', { class: 'panel-head' }, [
        el('h3', { text: 'Recent Personal Ledger' }),
        el('span', { class: 'panel-sub', text: txs.length + ' transactions' }),
      ]),
      el('div', { class: 'panel-body flush' }, [(() => {
        const table = el('table', { class: 'tbl' });
        table.innerHTML = `<thead><tr><th style="width:90px">Date</th><th>Merchant</th><th>Description</th><th>Account</th><th class="num">Amount</th></tr></thead><tbody></tbody>`;
        const tbody = table.querySelector('tbody');
        for (const t of txs) {
          const tr = el('tr', {
            class: state.selection?.kind === 'transaction' && state.selection?.id === t.id ? 'selected' : '',
            onclick: () => openInspector('transaction', t.id),
          });
          tr.appendChild(el('td', { class: 'muted mono', text: fmtDate(t.date) }));
          tr.appendChild(el('td', { text: t.merchant }));
          tr.appendChild(el('td', { class: 'muted', text: t.description }));
          tr.appendChild(el('td', { text: t.account }));
          tr.appendChild(el('td', { class: 'num ' + (t.amount < 0 ? '' : 'pos'), text: fmtUSD2(t.amount) }));
          tbody.appendChild(tr);
        }
        return table;
      })()]),
    ]));
  }
}

// ---------- Accounts (T041) --------------------------------------------------

// Reusable account card. Cards link to the dedicated individual-account screen
// (Round 5 #5); used on the all-accounts overview and on group screens (#4).
function accountCard(a) {
  return el('div', {
    class: 'account-card' + (state.view === 'accounts-account-' + a.id ? ' selected' : ''),
    onclick: () => navigate('accounts-account-' + a.id),
  }, [
    el('div', { class: 'ac-name', text: a.name }),
    el('div', { class: 'ac-inst', text: a.institution }),
    el('div', { class: 'ac-group', text: a.group }),
    el('div', { class: 'ac-metrics' }, [
      el('div', {}, [
        el('div', { class: 'ac-metric-label', text: 'Monthly inflow' }),
        el('div', { class: 'ac-metric-value', text: fmtUSD(a.monthlyInflow) }),
      ]),
      el('div', { style: { textAlign: 'right' } }, [
        el('div', { class: 'ac-metric-label', text: 'YTD net' }),
        el('div', { class: 'ac-metric-value', text: fmtUSD(a.ytdNetIncome) }),
      ]),
    ]),
  ]);
}

// Individual-account card section for a group screen (Round 5 #4).
function accountsCardSection(entityId, heading = 'Accounts') {
  const accts = DATA.accounts.filter(a => a.entityId === entityId);
  if (!accts.length) return null;
  const wrap = el('div', { style: { marginTop: '16px' } });
  wrap.appendChild(el('h3', { class: 'accounts-group-title', text: heading }));
  const grid = el('div', { class: 'accounts-grid' });
  for (const a of accts) grid.appendChild(accountCard(a));
  wrap.appendChild(grid);
  return wrap;
}

// Reusable transaction ledger table for an account's transactions.
function accountLedgerTable(txs) {
  const C = cats();
  const table = el('table', { class: 'tbl' });
  table.innerHTML = `<thead><tr><th style="width:90px">Date</th><th>Merchant</th><th>Description</th><th>Category</th><th class="num">Amount</th></tr></thead><tbody></tbody>`;
  const tbody = table.querySelector('tbody');
  for (const t of txs) {
    const tr = el('tr', {
      class: state.selection?.kind === 'transaction' && state.selection?.id === t.id ? 'selected' : '',
      onclick: () => openInspector('transaction', t.id),
    });
    tr.appendChild(el('td', { class: 'muted mono', text: fmtDate(t.date) }));
    tr.appendChild(el('td', { text: t.merchant }));
    tr.appendChild(el('td', { class: 'muted', text: t.description }));
    tr.appendChild(el('td', { text: C[t.category]?.name || t.category }));
    tr.appendChild(el('td', { class: 'num ' + (t.amount < 0 ? '' : 'pos'), text: fmtUSD2(t.amount) }));
    tbody.appendChild(tr);
  }
  return table;
}

// Individual account screen (Round 5 #5). Edit lives in the local actions;
// delete is offered inside the edit flow.
function viewAccount(accountId) {
  const a = DATA.accounts.find(x => x.id === accountId);
  if (!a) {
    setHeader({ title: 'Account', breadcrumb: ['Finance', 'Accounts'], actions: [] });
    $('#content').appendChild(el('p', { style: { color: 'var(--muted)', padding: '24px' }, text: 'Account not found.' }));
    return;
  }
  const entity = DATA.entities.find(e => e.id === a.entityId);
  setHeader({
    title: a.name,
    breadcrumb: ['Finance', 'Accounts', entity ? entity.display : 'Account', a.name],
    actions: [
      { label: 'Edit', variant: '', onClick: () => editAccountFlow(a.id) },
    ],
  });
  renderFilterBar([]);
  const c = $('#content');

  // Aggregate header for the account
  c.appendChild(el('div', { class: 'accounts-aggregate' }, [
    el('div', { class: 'agg-item' }, [
      el('div', { class: 'agg-label', text: 'Monthly inflow' }),
      el('div', { class: 'agg-value', text: fmtUSD(a.monthlyInflow) }),
    ]),
    el('div', { class: 'agg-item' }, [
      el('div', { class: 'agg-label', text: 'YTD net income' }),
      el('div', { class: 'agg-value', text: fmtUSD(a.ytdNetIncome) }),
    ]),
    el('div', { class: 'agg-item' }, [
      el('div', { class: 'agg-label', text: 'Type' }),
      el('div', { class: 'agg-value', text: a.group + ' · ' + a.type }),
    ]),
  ]));

  const txs = DATA.transactions.filter(t => t.account === a.name);
  c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px' } }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Transactions · ' + a.name }),
      el('span', { class: 'panel-sub', text: txs.length + ' transactions' }),
      el('div', { class: 'panel-actions' }, [
        el('button', { class: 'btn btn-ghost', text: 'Add transaction', onclick: () => addAccountTransactionFlow(a.name, a.entityId) }),
      ]),
    ]),
    el('div', { class: 'panel-body flush' }, [
      txs.length
        ? accountLedgerTable(txs)
        : el('div', { style: { textAlign: 'center', color: 'var(--muted)', padding: '24px' }, text: 'No transactions reference this account yet.' }),
    ]),
  ]));
}

function viewAccounts() {
  setHeader({
    title: 'Accounts',
    breadcrumb: ['Finance', 'Accounts', 'All Accounts'],
    actions: [
      { label: 'New account', variant: '', onClick: () => addAccountFlow() },
      { label: 'New group', variant: 'btn-ghost', onClick: addEntityFlow },
      { label: 'Export', variant: 'btn-ghost', onClick: () => exportCSV('accounts.csv',
        [{ label: 'name', value: 'name' }, { label: 'institution', value: 'institution' }, { label: 'group', value: 'group' }, { label: 'type', value: 'type' }, { label: 'entity', value: 'entityId' }, { label: 'monthly_inflow', value: 'monthlyInflow' }, { label: 'ytd_net_income', value: 'ytdNetIncome' }],
        DATA.accounts) },
    ],
  });
  renderFilterBar([]);
  const c = $('#content');

  if (!DATA.accounts || DATA.accounts.length === 0) {
    // T042: empty state
    c.appendChild(el('div', { style: { textAlign: 'center', padding: '48px 24px', color: 'var(--muted)' } }, [
      el('div', { style: { fontSize: '32px', marginBottom: '12px' }, text: '🏦' }),
      el('h3', { style: { color: 'var(--ink-2)', marginBottom: '8px' }, text: 'No accounts added' }),
      el('p', { style: { fontSize: '12px', marginBottom: '16px' }, text: 'Accounts will appear here once you add them to your workspace.' }),
      el('button', { class: 'btn', text: 'Add account', onclick: () => addAccountFlow() }),
    ]));
    return;
  }

  const totalInflow = DATA.accounts.reduce((s, a) => s + a.monthlyInflow, 0);
  const totalNI = DATA.accounts.reduce((s, a) => s + a.ytdNetIncome, 0);

  c.appendChild(el('div', { class: 'accounts-aggregate' }, [
    el('div', { class: 'agg-item' }, [
      el('div', { class: 'agg-label', text: 'Monthly Inflow' }),
      el('div', { class: 'agg-value', text: fmtUSD(totalInflow) }),
    ]),
    el('div', { class: 'agg-item' }, [
      el('div', { class: 'agg-label', text: 'YTD Net Income' }),
      el('div', { class: 'agg-value', text: fmtUSD(totalNI) }),
    ]),
    el('div', { class: 'agg-item' }, [
      el('div', { class: 'agg-label', text: 'Accounts' }),
      el('div', { class: 'agg-value', text: String(DATA.accounts.length) }),
    ]),
  ]));

  const themes = [
    { type: 'personal',   heading: 'Personal Accounts' },
    { type: 'employment', heading: 'Place of Employment' },
    { type: 'business',   heading: 'Business Groups' },
  ];

  for (const theme of themes) {
    const themeEntities = DATA.entities.filter(e => e.type === theme.type);
    const themeAccounts = DATA.accounts.filter(a => themeEntities.some(e => e.id === a.entityId));
    if (themeAccounts.length === 0) continue;

    c.appendChild(el('h3', { class: 'accounts-group-title', text: theme.heading }));
    const grid = el('div', { class: 'accounts-grid' });
    for (const a of themeAccounts) grid.appendChild(accountCard(a));
    c.appendChild(grid);
  }
}

// ---------- Taxes: Deductions (T039) -----------------------------------------

// Deductions render inline within Current Tax Year — no dedicated screen in v1
function appendDeductionGroups(c) {
  const groups = [
    { key: 'standard',   label: 'Standard Deduction' },
    { key: 'above-line', label: 'Above-the-Line Deductions' },
    { key: 'schedule-a', label: 'Schedule A — Itemized Deductions' },
    { key: 'schedule-c', label: 'Schedule C — Self-Employment Deductions' },
  ];

  for (const group of groups) {
    const items = DATA.deductions.filter(d => d.type === group.key);
    const total = items.reduce((s, d) => s + d.estimatedAmount, 0);

    const groupEl = el('div', { class: 'deduction-group' });
    groupEl.appendChild(el('div', { class: 'deduction-group-head' }, [
      el('span', { class: 'dg-title', text: group.label }),
      el('span', { class: 'dg-total', text: fmtUSD(total) }),
    ]));

    const table = el('table', { class: 'tbl' });
    table.innerHTML = `<thead><tr><th>Deduction</th><th class="num">Estimated Amount</th><th>Status</th></tr></thead><tbody></tbody>`;
    const tbody = table.querySelector('tbody');
    for (const d of items) {
      const tr = tbody.insertRow();
      tr.insertCell().textContent = d.name;
      const tdAmt = tr.insertCell(); tdAmt.className = 'num'; tdAmt.textContent = d.estimatedAmount > 0 ? fmtUSD(d.estimatedAmount) : '—';
      const tdSt = tr.insertCell();
      const tag = d.status === 'confirmed' ? el('span', { class: 'tag tag-ok', text: 'confirmed' }) :
                  d.status === 'estimated' ? el('span', { class: 'tag tag-warn', text: 'estimated' }) :
                  el('span', { class: 'tag tag-err', text: 'missing' });
      tdSt.appendChild(tag);
    }
    const totalRow = tbody.insertRow();
    totalRow.style.fontWeight = '600';
    totalRow.insertCell().textContent = 'Total';
    const tdTotal = totalRow.insertCell(); tdTotal.className = 'num'; tdTotal.textContent = fmtUSD(total);
    totalRow.insertCell();

    groupEl.appendChild(el('div', { class: 'panel', style: { margin: '0' } }, [
      el('div', { class: 'panel-body flush' }, [table]),
    ]));
    c.appendChild(groupEl);
  }
}

// ---------- Taxes: Current Year with per-account rate table (T040) -----------

function viewTaxesCurrent() {
  viewTaxes();

  // Append per-account effective rate table and deduction groups (Round 4:
  // deductions, payments, and gains/income all live on this consolidated screen)
  const c = $('#content');
  c.appendChild(el('div', { class: 'panel', style: { marginTop: '16px' } }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Effective Tax Rate by Account · 2026 YTD' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [
      (() => {
        const table = el('table', { class: 'tbl' });
        table.innerHTML = `<thead><tr><th>Account</th><th class="num">Taxable Income</th><th class="num">Taxes Paid</th><th class="num">Taxes Owed</th><th class="num">Effective Rate</th></tr></thead><tbody></tbody>`;
        const tbody = table.querySelector('tbody');
        for (const r of DATA.accountTaxRates) {
          const tr = tbody.insertRow();
          tr.insertCell().textContent = r.accountName;
          const tdInc = tr.insertCell(); tdInc.className = 'num'; tdInc.textContent = r.taxableIncome > 0 ? fmtUSD(r.taxableIncome) : '—';
          const tdPaid = tr.insertCell(); tdPaid.className = 'num'; tdPaid.textContent = r.taxesPaid > 0 ? fmtUSD(r.taxesPaid) : '—';
          const tdOwed = tr.insertCell(); tdOwed.className = 'num'; tdOwed.textContent = r.taxesOwed > 0 ? fmtUSD(r.taxesOwed) : '—';
          const tdRate = tr.insertCell(); tdRate.className = 'num'; tdRate.textContent = r.effectiveRate > 0 ? fmtPct(r.effectiveRate) : '—';
        }
        return table;
      })(),
    ]),
  ]));

  appendDeductionGroups(c);
}

// ---------- Taxes: Prep Checklist (full-width focal screen) ------------------

function viewTaxesChecklist() {
  setHeader({
    title: 'Prep Checklist · 2026',
    breadcrumb: ['Finance', 'Taxes', 'Prep Checklist'],
    actions: [{ label: 'Export prep packet', variant: '', onClick: exportTaxPacket }],
  });
  renderFilterBar([
    { label: 'Tax year', value: '2026', active: true },
  ]);

  const c = $('#content');
  const open = DATA.taxChecklist.filter(ci => !ci.done).length;

  c.appendChild(el('div', { class: 'panel checklist-page' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Prep Checklist' }),
      el('span', { class: 'panel-sub', text: 'Taxes/yearly/2026-prep-checklist.md' }),
      el('div', { class: 'panel-actions' }, [
        el('span', { class: 'tag ' + (open ? 'tag-warn' : 'tag-ok'), text: open + ' open' }),
      ]),
    ]),
    el('div', { class: 'panel-body' }, [
      el('p', { class: 'checklist-intro', text: 'Everything needed to file the 2026 return, in one place. Each item explains what the document is, why it matters, and where it comes from — work through them in order and the filing packet builds itself.' }),
      (() => {
        const ul = el('ul', { class: 'checklist checklist-edu' });
        for (const ci of DATA.taxChecklist) {
          ul.appendChild(el('li', {}, [
            el('span', { class: 'checkbox' + (ci.done ? ' done' : ''), title: 'Toggle done', onclick: (e) => { e.stopPropagation(); toggleChecklistItem(ci.id); } }),
            el('div', { class: 'ci-body' }, [
              el('div', { class: 'ci-label', text: ci.label }),
              ci.note ? el('div', { class: 'ci-note', text: ci.note }) : null,
              ci.edu ? el('div', { class: 'ci-edu', text: ci.edu }) : null,
            ]),
            el('span', { class: 'ci-meta', text: ci.due }),
          ]));
        }
        return ul;
      })(),
    ]),
  ]));
}

// ---------- Taxes: Archive (prior closed years) -------------------------------

function viewTaxesArchive() {
  setHeader({
    title: 'Tax Archive',
    breadcrumb: ['Finance', 'Taxes', 'Tax Archive'],
    actions: [],
  });
  renderFilterBar([]);

  const c = $('#content');
  c.appendChild(el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Closed Tax Years · Taxes/archive/' }),
      el('div', { class: 'panel-actions' }, [el('span', { class: 'imported-tag', text: 'Read-only' })]),
    ]),
    el('div', { class: 'panel-body flush' }, [(() => {
      const table = el('table', { class: 'tbl' });
      table.innerHTML = `<thead><tr><th>Tax year</th><th>Closed</th><th class="num">Deductions</th><th class="num">Estimated payments</th><th>Files</th></tr></thead><tbody></tbody>`;
      const tbody = table.querySelector('tbody');
      const tr = el('tr');
      tr.appendChild(el('td', { text: '2025' }));
      tr.appendChild(el('td', { class: 'muted', text: 'Apr 14, 2026' }));
      tr.appendChild(el('td', { class: 'num', text: fmtUSD(31350) }));
      tr.appendChild(el('td', { class: 'num', text: fmtUSD(16800) }));
      tr.appendChild(el('td', {}, [el('span', { class: 'path-chip', text: 'archive/2025-deductions.csv' })]));
      tbody.appendChild(tr);
      return table;
    })()]),
  ]));
}

// =====================================================================
// INSPECTOR
// =====================================================================

function select(sel) {
  state.selection = sel;
  renderInspector();
}

function renderInspector() {
  renderInspectorBody();
  appendInspectorActions();
}

// Edit/Delete actions pinned to the bottom of the inspector (Round 5 #6).
function appendInspectorActions() {
  if (!state.inspectorOpen || !state.selection) return;
  const { kind, id } = state.selection;
  const canEdit = EDITABLE_KINDS.has(kind);
  const canDelete = DELETABLE_KINDS.has(kind);
  if (!canEdit && !canDelete) return;
  const body = $('#inspector-body');
  if (!body) return;
  body.appendChild(el('div', { class: 'insp-actions' }, [
    canEdit ? el('button', { class: 'btn', text: 'Edit', onclick: () => editSelection(kind, id) }) : null,
    canDelete ? el('button', { class: 'btn btn-danger', text: 'Delete', onclick: () => deleteSelection(kind, id) }) : null,
  ]));
}

function renderInspectorBody() {
  if (!state.inspectorOpen) return;

  const head = $('#inspector-title');
  const sub = $('#inspector-sub');
  const body = $('#inspector-body');

  if (!state.selection) {
    head.textContent = 'Inspector';
    sub.textContent = 'Nothing selected';
    body.innerHTML = '';
    body.appendChild(el('div', { class: 'empty-inspector' }, [
      el('div', { class: 'empty-glyph' }),
      el('p', { text: 'Select a card, row, or item in the center panel to see source file lineage, metadata, and validation here.' }),
    ]));
    return;
  }

  const sel = state.selection;
  const k = sel.kind;

  body.innerHTML = '';

  if (k === 'transaction') {
    const t = DATA.transactions.find(x => x.id === sel.id);
    if (!t) return setEmpty();
    head.textContent = t.merchant;
    sub.textContent = t.description;
    body.appendChild(insBlockKVs([
      ['Amount', el('span', { class: 'insp-value big ' + (t.amount < 0 ? 'value-neg' : 'value-pos'), text: fmtUSD2(t.amount) })],
    ], { stacked: true }));
    body.appendChild(insSection('Details', [
      ['Date', fmtDateLong(t.date)],
      ['Account', t.account],
      ['Category', cats()[t.category]?.name || t.category],
      ['Direction', t.direction],
      ['Recurring', t.recurring ? 'Yes' : 'No'],
      ['Linked goal', t.goal ? goalById()[t.goal]?.name || t.goal : '—'],
    ]));
    body.appendChild(insSourceBlock({
      file: t.source, row: t.row, importedFrom: t.importedFrom,
    }));
    body.appendChild(insSection('Validation', [
      ['Schema', t.flagged === 'zero-amount' || t.duplicate ? 'Warnings' : 'OK'],
      ['Note',   t.duplicate ? 'Duplicate of ' + t.duplicate : t.flagged === 'zero-amount' ? 'Amount is 0.00 — placeholder?' : 'No issues'],
    ], { tag: t.duplicate || t.flagged ? 'warn' : 'ok' }));
    return;
  }

  if (k === 'category') {
    const c = cats()[sel.id];
    const totals = computeCategoryTotals().find(x => x.category.id === sel.id);
    if (!c) return setEmpty();
    head.textContent = c.name;
    sub.textContent = c.group + ' · ' + (c.tax_relevant ? 'Tax relevant' : 'Personal');
    body.appendChild(insBlockKVs([
      ['Actual / Planned', el('span', { class: 'insp-value big', text: fmtUSD(totals.actual) + ' / ' + fmtUSD(totals.planned) })],
    ], { stacked: true }));
    body.appendChild(insSection('Variance · May 2026', [
      ['Variance', fmtUSD(totals.actual - totals.planned, { sign: true })],
      ['Transactions', String(DATA.transactions.filter(t => t.category === c.id).length)],
      ['Pacing', fmtPct(totals.actual / totals.planned, 0) + ' of plan'],
    ]));
    body.appendChild(insSourceBlock({ file: 'Personal/categories.csv', row: null, importedFrom: 'categories template' }));
    return;
  }

  if (k === 'rule') {
    const r = DATA.rules.find(x => x.id === sel.id);
    head.textContent = r.pattern;
    sub.textContent = 'Recurring rule';
    body.appendChild(insSection('Rule', [
      ['Category', cats()[r.category]?.name || r.category],
      ['Cadence', r.cadence + ' · day ' + r.day],
      ['Amount', fmtUSD2(r.amount)],
      ['Last applied', fmtDateLong(r.lastApplied)],
    ]));
    body.appendChild(insSourceBlock({ file: 'Personal/rules.csv', row: null }));
    return;
  }

  if (k === 'goal') {
    const g = DATA.goals.find(x => x.id === sel.id);
    if (!g) return setEmpty();
    head.textContent = g.name;
    sub.textContent = 'Savings goal';
    const pct = g.balance / g.target;
    body.appendChild(insBlockKVs([
      ['Balance', el('span', { class: 'insp-value big', text: fmtUSD(g.balance) })],
    ], { stacked: true }));
    body.appendChild(el('div', { class: 'insp-section' }, [
      el('div', { class: 'insp-label', text: 'Progress' }),
      el('div', { class: 'bar-inline', style: { height: '10px', marginBottom: '6px' } }, [el('span', { style: { width: pct * 100 + '%' } })]),
      el('div', { style: { display: 'flex', justifyContent: 'space-between', fontSize: '11.5px', color: 'var(--muted)' } }, [
        el('span', { text: fmtPct(pct, 0) + ' of ' + fmtUSD(g.target) }),
        el('span', { text: 'Target ' + fmtDateLong(g.targetDate) }),
      ]),
    ]));
    body.appendChild(insSection('Funding', [
      ['Monthly target', fmtUSD(g.monthlyTarget)],
      ['May funded', fmtUSD(g.monthlyActual)],
      ['Source account', g.account],
      ['Linked note', g.note ? DATA.notes.find(n => n.id === g.note)?.title || g.note : '—'],
    ]));
    body.appendChild(insSourceBlock({ file: g.source, row: g.row, importedFrom: null }));
    return;
  }

  if (k === 'holding') {
    const h = DATA.holdings.find(x => x.id === sel.id);
    if (!h) return setEmpty();
    const mv = h.qty * h.price;
    const ug = mv - h.basis;
    head.textContent = h.ticker;
    sub.textContent = h.name;
    body.appendChild(insBlockKVs([
      ['Market value', el('span', { class: 'insp-value big', text: fmtUSD(mv) })],
    ], { stacked: true }));
    body.appendChild(insSection('Position', [
      ['Account', acctById()[h.account]?.name],
      ['Sleeve', sleeveById()[h.sleeve]?.name],
      ['Qty', fmtNum(h.qty)],
      ['Price', fmtUSD2(h.price)],
      ['Cost basis', fmtUSD(h.basis)],
      ['Unrealized', fmtUSD(ug, { sign: true })],
      ['Asset class', h.asset],
      ['Sector', h.sector],
    ]));
    if (h.ticker === 'NVDA') {
      const taxBlock = el('div', { class: 'insp-section' }, [
        el('div', { class: 'insp-label', text: 'Tax lots' }),
        ...DATA.taxLots.map(l => el('div', { class: 'insp-block' }, [
          el('div', { style: { display: 'flex', justifyContent: 'space-between', marginBottom: '4px' } }, [
            el('span', { class: 'mono', text: l.lotId }),
            el('span', { class: 'tag ' + (l.term === 'short' ? 'tag-warn' : 'tag-ok'), text: l.term }),
          ]),
          el('div', { style: { display: 'flex', justifyContent: 'space-between', fontSize: '11.5px', color: 'var(--muted)' } }, [
            el('span', { text: fmtDateLong(l.acquired) + ' · ' + l.qty + ' sh' }),
            el('span', { text: fmtUSD(l.gain, { sign: true }) }),
          ]),
        ])),
      ]);
      body.appendChild(taxBlock);
    }
    body.appendChild(insSourceBlock({ file: 'Investments/holdings.csv', row: DATA.holdings.indexOf(h) + 2, importedFrom: 'fidelity-holdings.csv' }));
    return;
  }

  if (k === 'sleeve') {
    const s = sleeveById()[sel.id];
    if (!s) return setEmpty();
    head.textContent = s.name;
    sub.textContent = 'Sleeve · ' + s.strategy;
    body.appendChild(insSection('Targets', [
      ['Benchmark', s.benchmark],
      ['Monthly contribution', fmtUSD(s.monthlyTarget)],
      ['Drift policy', '> 5 pts triggers rebalance'],
    ]));
    body.appendChild(insSourceBlock({ file: 'Investments/sleeves.csv', row: null }));
    return;
  }

  if (k === 'biz-tx') {
    const t = DATA.businessTransactions.find(x => x.id === sel.id);
    if (!t) return setEmpty();
    head.textContent = t.merchant;
    sub.textContent = t.description;
    const BC = bizCatById();
    body.appendChild(insBlockKVs([
      ['Amount', el('span', { class: 'insp-value big ' + (t.amount < 0 ? 'value-neg' : 'value-pos'), text: fmtUSD2(t.amount) })],
    ], { stacked: true }));
    body.appendChild(insSection('Details', [
      ['Date', fmtDateLong(t.date)],
      ['Entity', entityById()[t.entity]?.display],
      ['Category', t.category === 'income' ? 'Income' : BC[t.category]?.name],
      ['Tax group', t.category === 'income' ? '—' : BC[t.category]?.taxGroup],
      ['Deductible', t.deductible ? 'Yes' : 'No'],
    ]));
    body.appendChild(insSourceBlock({ file: t.source, row: t.row, importedFrom: 'brex-may.csv' }));
    return;
  }

  if (k === 'issue') {
    const i = DATA.issues.find(x => x.id === sel.id);
    if (!i) return setEmpty();
    head.textContent = i.title;
    sub.textContent = i.message;
    body.appendChild(insSection('Issue', [
      ['Severity', i.severity],
      ['Group', i.group],
      ['File', el('span', { class: 'path-chip' }, [
        i.filePath || i.file + (i.row ? ':' + i.row : ''),
        el('span', { class: 'sync-badge sync-badge--available' }),
      ])],
      ['Row', i.row != null ? String(i.row) : '—'],
      ['Repairable', i.repairable ? 'Yes' : 'No (manual)'],
    ], { tag: i.severity === 'error' ? 'err' : i.severity === 'warning' ? 'warn' : 'info' }));

    if (i.repairable && i.repairPreview) {
      body.appendChild(el('div', { class: 'insp-section' }, [
        el('div', { class: 'insp-label', text: 'Repair preview' }),
        el('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px', marginBottom: '10px' } }, [
          el('div', {}, [
            el('div', { style: { fontSize: '10px', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '0.06em', color: 'var(--err)', marginBottom: '4px' }, text: 'Before' }),
            el('pre', { class: 'insp-pre', style: { background: '#fee2e2', fontSize: '10.5px' }, text: i.repairPreview.before }),
          ]),
          el('div', {}, [
            el('div', { style: { fontSize: '10px', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '0.06em', color: 'var(--ok)', marginBottom: '4px' }, text: 'After' }),
            el('pre', { class: 'insp-pre', style: { background: '#dcfce7', fontSize: '10.5px' }, text: i.repairPreview.after }),
          ]),
        ]),
        el('div', { style: { marginBottom: '8px', fontSize: '11px', color: 'var(--muted)', background: 'var(--surface-sunken)', padding: '6px 10px', borderRadius: '6px' }, text: '🔒 A timestamped backup will be created before applying this change.' }),
        el('div', { style: { display: 'flex', gap: '6px' } }, [
          el('button', { class: 'btn btn-primary', text: 'Apply repair', onclick: () => applyRepair(i.id) }),
          el('button', { class: 'btn btn-ghost', text: 'Cancel', onclick: closeInspector }),
        ]),
      ]));
    } else {
      body.appendChild(el('div', { class: 'insp-section' }, [
        el('div', { class: 'insp-label', text: 'Manual review required' }),
        el('p', { style: { fontSize: '12px', color: 'var(--ink-3)', lineHeight: '1.5' }, text: 'This issue cannot be repaired automatically. Open the source file and apply the change manually in your editor.' }),
        el('div', { style: { display: 'flex', gap: '6px', marginTop: '10px' } }, [
          el('button', { class: 'btn btn-ghost', text: 'Reveal in Finder', onclick: () => osAction('Reveal in Finder', i.filePath || i.file) }),
          el('button', { class: 'btn btn-ghost', text: 'Open in editor', onclick: () => osAction('Open in editor', i.filePath || i.file) }),
        ]),
      ]));
    }
    return;
  }

  if (k === 'note') {
    const n = DATA.notes.find(x => x.id === sel.id);
    if (!n) return setEmpty();
    head.textContent = n.title;
    sub.textContent = n.type + (n.period ? ' · ' + n.period : '');
    body.appendChild(insSection('Front matter', Object.entries(n.frontMatter).map(([k, v]) => [k, Array.isArray(v) ? v.join(', ') : String(v)])));
    body.appendChild(insSourceBlock({ file: n.path, row: null, importedFrom: null }));
    body.appendChild(insSection('Linked entities', [
      ['Period', n.frontMatter.period || '—'],
      ['Goals', (n.frontMatter.goal_ids || []).join(', ') || '—'],
      ['Accounts', (n.frontMatter.account_ids || []).join(', ') || '—'],
      ['Entities', (n.frontMatter.entity_ids || []).join(', ') || '—'],
    ]));
    return;
  }

  if (k === 'overview-kpi') {
    const labelMap = {
      cashFlow: 'Cash flow', budgetVariance: 'Budget variance', savingsProgress: 'Savings progress',
      portfolioValue: 'Portfolio value', businessNetIncome: 'Business net income', taxStatus: 'Tax status', issueCount: 'Open issues'
    };
    head.textContent = labelMap[sel.id] || 'KPI';
    sub.textContent = 'Derived projection';
    const formulas = {
      cashFlow:        'sum(personal income) − sum(personal outflow) for period',
      budgetVariance:  'sum(actual) − sum(planned) across all categories',
      savingsProgress: 'sum(goal.balance) / sum(goal.target)',
      portfolioValue:  'Σ holding.qty × price.close (latest)',
      businessNetIncome: 'Σ revenue − Σ expenses across active entities',
      taxStatus:       'derived from estimated-payments + checklist',
      issueCount:      'count(ValidationIssue where status = open)',
    };
    body.appendChild(insSection('Calculation', [
      ['Formula', el('span', { class: 'mono', text: formulas[sel.id] || '—' })],
      ['Window', 'May 2026'],
      ['Last computed', DATA.workspace.lastIndexed],
    ], { tag: 'info' }));
    body.appendChild(insSection('Source files', [
      ['Files', el('div', { style: { display: 'flex', flexDirection: 'column', gap: '4px' } }, [
        el('span', { class: 'path-chip', text: 'Personal/transactions/2026-05.csv' }),
        el('span', { class: 'path-chip', text: 'Personal/categories.csv' }),
        sel.id === 'portfolioValue' ? el('span', { class: 'path-chip', text: 'Investments/holdings.csv' }) : null,
        sel.id === 'savingsProgress' ? el('span', { class: 'path-chip', text: 'Savings/goals.csv' }) : null,
      ].filter(Boolean))],
    ]));
    return;
  }

  if (k === 'estimatedPayment') {
    const p = DATA.estimatedPayments.find(x => x.id === sel.id);
    if (!p) return setEmpty();
    head.textContent = 'Q' + p.quarter + ' ' + p.year + ' · ' + p.jurisdiction;
    sub.textContent = 'Estimated payment';
    body.appendChild(insSection('Payment', [
      ['Due', fmtDateLong(p.due)],
      ['Amount', fmtUSD(p.amount)],
      ['Paid', fmtUSD(p.paid)],
      ['Paid date', p.paidDate ? fmtDateLong(p.paidDate) : '—'],
      ['Status', p.status],
    ], { tag: p.status === 'paid' ? 'ok' : 'warn' }));
    body.appendChild(insSourceBlock({ file: 'Taxes/estimated-payments.csv', row: DATA.estimatedPayments.indexOf(p) + 2 }));
    return;
  }

  if (k === 'realized') {
    const r = DATA.realizedGains.find(x => x.id === sel.id);
    head.textContent = r.ticker;
    sub.textContent = 'Realized · ' + r.term + ' term';
    body.appendChild(insSection('Lot', [
      ['Closed', fmtDateLong(r.closed)],
      ['Proceeds', fmtUSD(r.proceeds)],
      ['Basis', fmtUSD(r.basis)],
      ['Gain', fmtUSD(r.gain, { sign: true })],
    ]));
    body.appendChild(insSourceBlock({ file: r.source, row: r.row }));
    return;
  }

  if (k === 'account') {
    const a = DATA.accounts.find(x => x.id === sel.id);
    if (!a) return setEmpty();
    head.textContent = a.name;
    sub.textContent = a.group + ' · ' + a.institution;
    body.appendChild(insBlockKVs([
      ['Monthly Inflow', el('span', { class: 'insp-value big', text: fmtUSD(a.monthlyInflow) })],
    ], { stacked: true }));
    body.appendChild(insSection('Account details', [
      ['Institution', a.institution],
      ['Type', a.type],
      ['Group', a.group],
      ['YTD net income', fmtUSD(a.ytdNetIncome)],
    ]));
    body.appendChild(insSourceBlock({ file: 'Accounts/accounts.csv', row: null, importedFrom: null }));
    return;
  }

  // generic fallback
  head.textContent = 'Inspector';
  sub.textContent = '(' + k + ')';
  body.innerHTML = '<div class="empty-inspector"><p>No detail panel for this selection yet.</p></div>';

  function setEmpty() {
    body.innerHTML = '<div class="empty-inspector"><p>Selection not found.</p></div>';
  }
}

function insSection(label, rows, opts = {}) {
  const sec = el('div', { class: 'insp-section' });
  const header = el('div', { class: 'insp-label', style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } }, [
    el('span', { text: label }),
    opts.tag ? el('span', { class: 'tag tag-' + opts.tag, text: opts.tag === 'ok' ? 'valid' : opts.tag }) : null,
  ]);
  sec.appendChild(header);
  const block = el('div', { class: 'insp-block' });
  for (const [k, v] of rows) {
    const row = el('div', { class: 'insp-row' }, [
      el('span', { class: 'k', text: k }),
      el('span', { class: 'v' }, [typeof v === 'string' || typeof v === 'number' ? document.createTextNode(String(v)) : v]),
    ]);
    block.appendChild(row);
  }
  sec.appendChild(block);
  return sec;
}

function insBlockKVs(rows, opts = {}) {
  if (opts.stacked) {
    const wrap = el('div', { class: 'insp-section' });
    for (const [k, v] of rows) {
      wrap.appendChild(el('div', {}, [
        el('div', { class: 'insp-label', text: k }),
        typeof v === 'string' ? el('div', { class: 'insp-value big', text: v }) : v,
      ]));
    }
    return wrap;
  }
  return insSection('', rows);
}

function insSourceBlock({ file, row, importedFrom }) {
  return el('div', { class: 'insp-section' }, [
    el('div', { class: 'insp-label', style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } }, [
      el('span', { text: 'Source' }),
      el('span', { class: 'imported-tag', text: 'imported' }),
    ]),
    el('div', { class: 'insp-block' }, [
      el('div', { class: 'insp-row' }, [
        el('span', { class: 'k', text: 'File' }),
        el('span', { class: 'v' }, [
          el('span', { class: 'path-chip' }, [
            file,
            el('span', { class: 'sync-badge sync-badge--available' }),
          ]),
        ]),
      ]),
      row != null ? el('div', { class: 'insp-row' }, [
        el('span', { class: 'k', text: 'Row' }),
        el('span', { class: 'v mono', text: '#' + row }),
      ]) : null,
      importedFrom ? el('div', { class: 'insp-row' }, [
        el('span', { class: 'k', text: 'Imported from' }),
        el('span', { class: 'v mono', text: importedFrom }),
      ]) : null,
      el('div', { class: 'insp-row' }, [
        el('span', { class: 'k', text: 'Schema' }),
        el('span', { class: 'v', text: 'v' + DATA.workspace.schemaVersion }),
      ]),
    ]),
    el('div', { style: { marginTop: '8px', display: 'flex', gap: '6px' } }, [
      el('button', { class: 'btn btn-ghost', text: 'Reveal in Finder', onclick: () => osAction('Reveal in Finder', file) }),
      el('button', { class: 'btn btn-ghost', text: 'Open in editor', onclick: () => osAction('Open in editor', file) }),
    ]),
  ]);
}

// =====================================================================
// Bootstrap
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
  const backdrop = document.getElementById('inspector-backdrop');
  if (backdrop) backdrop.addEventListener('click', closeInspector);

  // The sidebar header is the entry point to the default dashboard (Round 5).
  const head = document.getElementById('sidebar-head');
  if (head) {
    head.style.cursor = 'pointer';
    head.addEventListener('click', () => navigate('overview-dashboard'));
  }

  window.addEventListener('popstate', () => {
    const urlParams = new URLSearchParams(window.location.search);
    const viewId = urlParams.get('view') || 'overview-dashboard';
    state.view = viewId;
    closeInspector();
    renderSidebar();
    renderCenter();
  });
});

const urlParams = new URLSearchParams(window.location.search);
const initialView = urlParams.get('view');
if (initialView) {
  state.view = initialView;
}

renderSidebar();
renderCenter();
renderInspector();
