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
  view: 'accounts-overview',
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
};

// ---------- Sidebar ----------------------------------------------------------

const NAV = [
  { id: 'overview', label: 'Overview', items: [
    { id: 'overview-dashboard', label: 'Dashboard' },
  ]},
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
        return el('div', {
          class: 'nav-item' + (active ? ' active' : ''),
          onclick: () => navigate(item.id),
        }, [
          el('span', { text: item.label }),
          item.badge ? el('span', { class: 'badge', text: item.badge }) : null,
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

function renderFilterBar(filters) {
  const bar = $('#filter-bar');
  bar.innerHTML = '';
  if (!filters || filters.length === 0) {
    bar.style.display = 'none';
    return;
  }
  bar.style.display = 'flex';
  for (const f of filters) {
    if (f.kind === 'search') {
      const wrap = el('div', { class: 'search-filter' }, [
        el('input', { type: 'text', placeholder: f.placeholder || 'Search', value: f.value || '', oninput: e => f.onChange(e.target.value) }),
      ]);
      bar.appendChild(wrap);
    } else if (f.kind === 'spacer') {
      bar.appendChild(el('div', { class: 'filter-spacer' }));
    } else {
      const node = el('button', {
        class: 'filter' + (f.active ? ' is-active' : ''),
        onclick: f.onClick || (() => {}),
      }, [
        el('span', { class: 'filter-label', text: f.label + ':' }),
        el('span', { class: 'filter-value', text: f.value }),
        el('span', { class: 'filter-caret' }),
      ]);
      bar.appendChild(node);
    }
  }
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

// ---------- Charts (SVG) -----------------------------------------------------

function lineChart(series, opts = {}) {
  const { width = 460, height = 200, padding = { t: 16, r: 14, b: 26, l: 36 }, colors = ['#3651d3'], labels = [], dashed = [] } = opts;
  const allValues = series.flat();
  const minV = Math.min(...allValues);
  const maxV = Math.max(...allValues);
  const range = maxV - minV || 1;
  const xPad = padding.l;
  const xMax = width - padding.r;
  const yPad = padding.t;
  const yMax = height - padding.b;
  const innerW = xMax - xPad;
  const innerH = yMax - yPad;

  const xs = (i, n) => xPad + (i / Math.max(n - 1, 1)) * innerW;
  const ys = v => yMax - ((v - minV) / range) * innerH;

  const svg = `
    <svg viewBox="0 0 ${width} ${height}" preserveAspectRatio="none">
      <g class="chart-grid">
        ${[0, 0.25, 0.5, 0.75, 1].map(p => {
          const y = yPad + p * innerH;
          return `<line x1="${xPad}" x2="${xMax}" y1="${y}" y2="${y}"/>`;
        }).join('')}
      </g>
      <g class="chart-axis">
        <line x1="${xPad}" x2="${xMax}" y1="${yMax}" y2="${yMax}"/>
      </g>
      ${series.map((s, idx) => {
        const path = s.map((v, i) => `${i === 0 ? 'M' : 'L'} ${xs(i, s.length).toFixed(1)} ${ys(v).toFixed(1)}`).join(' ');
        const dash = dashed[idx] ? 'stroke-dasharray="4 4"' : '';
        return `<path d="${path}" fill="none" stroke="${colors[idx] || '#94a3b8'}" stroke-width="1.75" ${dash}/>`;
      }).join('')}
      ${series.map((s, idx) => s.map((v, i) =>
          `<circle cx="${xs(i, s.length).toFixed(1)}" cy="${ys(v).toFixed(1)}" r="2.4" fill="${colors[idx] || '#94a3b8'}"/>`
        ).join('')
      ).join('')}
      ${labels.map((label, i) => {
        const x = xs(i, labels.length);
        return `<text class="chart-axis-label" x="${x}" y="${height - 8}" text-anchor="middle">${label}</text>`;
      }).join('')}
      ${[minV, (minV + maxV)/2, maxV].map(v => {
        return `<text class="chart-axis-label" x="${xPad - 6}" y="${ys(v) + 3}" text-anchor="end">${shortNum(v)}</text>`;
      }).join('')}
    </svg>`;
  return svg;
}

function shortNum(v) {
  if (Math.abs(v) >= 1000000) return (v / 1000000).toFixed(1) + 'M';
  if (Math.abs(v) >= 1000) return (v / 1000).toFixed(0) + 'k';
  if (Math.abs(v) >= 100) return v.toFixed(0);
  return v.toFixed(1);
}

function barChart(values, opts = {}) {
  const { width = 460, height = 200, padding = { t: 16, r: 14, b: 26, l: 36 }, color = '#3651d3', labels = [], negColor = '#b91c1c' } = opts;
  const minV = Math.min(0, ...values);
  const maxV = Math.max(0, ...values);
  const range = (maxV - minV) || 1;
  const xPad = padding.l, xMax = width - padding.r, yPad = padding.t, yMax = height - padding.b;
  const innerW = xMax - xPad, innerH = yMax - yPad;
  const slot = innerW / values.length;
  const bw = slot * 0.6;
  const zeroY = yMax - ((0 - minV) / range) * innerH;

  const bars = values.map((v, i) => {
    const x = xPad + slot * i + (slot - bw) / 2;
    const y = yMax - ((v - minV) / range) * innerH;
    const h = Math.abs(y - zeroY);
    const top = v >= 0 ? y : zeroY;
    return `<rect x="${x.toFixed(1)}" y="${top.toFixed(1)}" width="${bw.toFixed(1)}" height="${h.toFixed(1)}" rx="2" fill="${v >= 0 ? color : negColor}"/>`;
  }).join('');

  return `
    <svg viewBox="0 0 ${width} ${height}" preserveAspectRatio="none">
      <g class="chart-grid">
        ${[0, 0.25, 0.5, 0.75, 1].map(p => {
          const y = yPad + p * innerH;
          return `<line x1="${xPad}" x2="${xMax}" y1="${y}" y2="${y}"/>`;
        }).join('')}
      </g>
      <line class="chart-axis" x1="${xPad}" x2="${xMax}" y1="${zeroY}" y2="${zeroY}" stroke="#94a3b8"/>
      ${bars}
      ${labels.map((label, i) => {
        const x = xPad + slot * i + slot / 2;
        return `<text class="chart-axis-label" x="${x}" y="${height - 8}" text-anchor="middle">${label}</text>`;
      }).join('')}
      ${[minV, 0, maxV].filter((v, i, a) => a.indexOf(v) === i).map(v => {
        const y = yMax - ((v - minV) / range) * innerH;
        return `<text class="chart-axis-label" x="${xPad - 6}" y="${y + 3}" text-anchor="end">${shortNum(v)}</text>`;
      }).join('')}
    </svg>`;
}

function donutChart(slices, opts = {}) {
  const { size = 160, thickness = 26 } = opts;
  const r = size / 2;
  const inner = r - thickness;
  const total = slices.reduce((s, x) => s + x.value, 0) || 1;
  let acc = 0;
  const arcs = slices.map(s => {
    const start = acc / total * Math.PI * 2 - Math.PI / 2;
    acc += s.value;
    const end = acc / total * Math.PI * 2 - Math.PI / 2;
    const large = (end - start) > Math.PI ? 1 : 0;
    const x1 = r + Math.cos(start) * r;
    const y1 = r + Math.sin(start) * r;
    const x2 = r + Math.cos(end) * r;
    const y2 = r + Math.sin(end) * r;
    const x3 = r + Math.cos(end) * inner;
    const y3 = r + Math.sin(end) * inner;
    const x4 = r + Math.cos(start) * inner;
    const y4 = r + Math.sin(start) * inner;
    return `<path d="M ${x1.toFixed(2)} ${y1.toFixed(2)} A ${r} ${r} 0 ${large} 1 ${x2.toFixed(2)} ${y2.toFixed(2)} L ${x3.toFixed(2)} ${y3.toFixed(2)} A ${inner} ${inner} 0 ${large} 0 ${x4.toFixed(2)} ${y4.toFixed(2)} Z" fill="${s.color}" />`;
  }).join('');
  return `<svg viewBox="0 0 ${size} ${size}" style="display:block;">${arcs}</svg>`;
}

// =====================================================================
// VIEW RENDERERS
// =====================================================================

function renderCenter() {
  const content = $('#content');
  content.innerHTML = '';
  // route
  const v = state.view;
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
      { label: 'Export', variant: 'btn-ghost' },
      { label: 'Reindex', variant: 'btn-ghost' },
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
      { label: 'Import CSV', variant: '' },
      { label: 'Export', variant: 'btn-ghost' },
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

  c.appendChild(el('div', { class: 'row-2-1' }, [donutPanel, catPanel]));

  // Transaction ledger
  const f = state.filters['budget-overview'];
  let txs = DATA.transactions.filter(t => t.category !== 'income');
  const txPanel = el('div', { class: 'panel' }, [
    el('div', { class: 'panel-head' }, [
      el('h3', { text: 'Transaction Ledger' }),
      el('span', { class: 'panel-sub', text: `${txs.length} transactions` }),
      el('div', { class: 'panel-actions' }, [
        el('span', { class: 'imported-tag', text: 'Imported' }),
        el('button', { class: 'btn btn-ghost', text: 'Open file' }),
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
    actions: [{ label: 'Export', variant: 'btn-ghost' }],
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
    actions: [{ label: 'New category', variant: '' }, { label: 'Export', variant: 'btn-ghost' }],
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
    actions: [{ label: 'New goal', variant: '' }, { label: 'Export', variant: 'btn-ghost' }],
  });
  renderFilterBar([
    { label: 'Target year', value: 'All' },
    { kind: 'spacer' },
    { kind: 'search', placeholder: 'Search goals', onChange: () => {} },
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
      { label: 'Import prices', variant: '' },
      { label: 'Rebalance plan', variant: 'btn-ghost' },
      { label: 'Export', variant: 'btn-ghost' },
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
      { label: 'Import prices', variant: '' },
      { label: 'Export', variant: 'btn-ghost' },
    ],
  });
  renderFilterBar([
    { label: 'Account', value: 'All' },
    { label: 'Sleeve', value: 'All' },
    { label: 'As of', value: 'May 11, 2026', active: true },
    { kind: 'spacer' },
    { kind: 'search', placeholder: 'Search holdings', onChange: () => {} },
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
      { label: 'Import CSV', variant: '' },
      { label: 'New entity', variant: 'btn-ghost' },
      { label: 'Export P&L', variant: 'btn-ghost' },
    ],
  });
  renderFilterBar([
    { label: 'Entity', value: entity.display, active: true },
    { label: 'Period', value: 'May 2026', active: true },
    { label: 'Account', value: 'All' },
    { kind: 'spacer' },
    { kind: 'search', placeholder: 'Search transactions', onChange: () => {} },
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
        el('button', { class: 'btn btn-ghost', text: 'Open file' }),
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
  setHeader({ title: 'Business Categories', breadcrumb: ['Finance', 'Business', 'Categories'], actions: [{ label: 'New', variant: '' }] });
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
      { label: 'Export prep packet', variant: '' },
      { label: 'New payment', variant: 'btn-ghost' },
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
      ]),
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
            ? el('button', { class: 'btn state-action', text: ws.recoveryAction })
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
        const td3 = tr.insertCell(); td3.innerHTML = '<button class="btn btn-ghost" style="font-size:11.5px">Download</button>';
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
        { label: 'Import CSV', variant: '' },
        { label: 'Export P&L', variant: 'btn-ghost' },
      ],
    });
    renderFilterBar([
      { label: 'Entity', value: entity.display, active: true },
      { label: 'Period', value: 'May 2026', active: true },
      { label: 'Account', value: 'All' },
      { kind: 'spacer' },
      { kind: 'search', placeholder: 'Search transactions', onChange: () => {} },
    ]);

    const c = $('#content');

    // Tab bar navigation
    const tabs = [
      { id: 'dashboard', label: 'Dashboard' },
      { id: 'transactions', label: 'Transactions' },
      { id: 'budgets', label: 'Budgets' },
      { id: 'categories', label: 'Categories' }
    ];
    const tabContainer = el('div', { class: 'entity-strip' });
    for (const t of tabs) {
      tabContainer.appendChild(el('div', {
        class: 'entity-pill' + (t.id === activeTab ? ' active' : ''),
        onclick: () => {
          state.entityTabs[entityId] = t.id;
          renderCenter();
        }
      }, [
        el('span', { text: t.label })
      ]));
    }
    c.appendChild(tabContainer);

    const txs = DATA.transactions.filter(t => t.entityId === entityId);

    if (activeTab === 'dashboard') {
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

      // P&L Chart
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
    } else if (activeTab === 'transactions') {
      // Transactions table
      c.appendChild(el('div', { class: 'panel' }, [
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
    } else if (activeTab === 'budgets') {
      // Budgets table
      c.appendChild(el('div', { class: 'panel' }, [
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
    } else if (activeTab === 'categories') {
      // Categories table
      c.appendChild(el('div', { class: 'panel' }, [
        el('div', { class: 'panel-head' }, [
          el('h3', { text: 'Business Categories' }),
          el('div', { class: 'panel-actions' }, [el('span', { class: 'derived-tag', text: 'Derived' })]),
        ]),
        el('div', { class: 'panel-body flush' }, [(() => {
          const table = el('table', { class: 'tbl' });
          table.innerHTML = `<thead><tr><th>Category</th><th>Tax group</th><th>Default behavior</th></tr></thead><tbody></tbody>`;
          const tbody = table.querySelector('tbody');
          for (const cat of DATA.businessCategories) {
            const tr = el('tr');
            tr.appendChild(el('td', { text: cat.name }));
            tr.appendChild(el('td', { class: 'muted', text: cat.taxGroup }));
            tr.appendChild(el('td', { class: 'muted', text: 'Variable' }));
            tbody.appendChild(tr);
          }
          return table;
        })()]),
      ]));
    }
  } else if (entity.type === 'employment') {
    setHeader({
      title: 'Employment · ' + entity.display,
      breadcrumb: ['Finance', 'Accounts', entity.display],
      actions: [
        { label: 'Import Paystub', variant: '' },
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
        { label: 'Add Asset', variant: '' },
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

function viewAccounts() {
  setHeader({
    title: 'Accounts',
    breadcrumb: ['Finance', 'Accounts', 'All Accounts'],
    actions: [{ label: 'Export', variant: 'btn-ghost' }],
  });
  renderFilterBar([]);
  const c = $('#content');

  if (!DATA.accounts || DATA.accounts.length === 0) {
    // T042: empty state
    c.appendChild(el('div', { style: { textAlign: 'center', padding: '48px 24px', color: 'var(--muted)' } }, [
      el('div', { style: { fontSize: '32px', marginBottom: '12px' }, text: '🏦' }),
      el('h3', { style: { color: 'var(--ink-2)', marginBottom: '8px' }, text: 'No accounts added' }),
      el('p', { style: { fontSize: '12px', marginBottom: '16px' }, text: 'Accounts will appear here once you add them to your workspace.' }),
      el('button', { class: 'btn', text: 'Add account (coming soon)' }),
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
    { type: 'personal',   heading: 'Personal Assets' },
    { type: 'employment', heading: 'Place of Employment' },
    { type: 'business',   heading: 'Business Entities' },
  ];

  for (const theme of themes) {
    const themeEntities = DATA.entities.filter(e => e.type === theme.type);
    const themeAccounts = DATA.accounts.filter(a => themeEntities.some(e => e.id === a.entityId));
    if (themeAccounts.length === 0) continue;

    c.appendChild(el('h3', { class: 'accounts-group-title', text: theme.heading }));
    const grid = el('div', { class: 'accounts-grid' });
    for (const a of themeAccounts) {
      grid.appendChild(el('div', {
        class: 'account-card' + (state.selection?.kind === 'account' && state.selection?.id === a.id ? ' selected' : ''),
        onclick: () => openInspector('account', a.id),
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
      ]));
    }
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
    actions: [{ label: 'Export prep packet', variant: '' }],
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
          ul.appendChild(el('li', { onclick: () => select({ kind: 'tax-check', id: ci.id }) }, [
            el('span', { class: 'checkbox' + (ci.done ? ' done' : '') }),
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
          el('button', { class: 'btn btn-primary', text: 'Apply repair' }),
          el('button', { class: 'btn btn-ghost', text: 'Cancel' }),
        ]),
      ]));
    } else {
      body.appendChild(el('div', { class: 'insp-section' }, [
        el('div', { class: 'insp-label', text: 'Manual review required' }),
        el('p', { style: { fontSize: '12px', color: 'var(--ink-3)', lineHeight: '1.5' }, text: 'This issue cannot be repaired automatically. Open the source file and apply the change manually in your editor.' }),
        el('div', { style: { display: 'flex', gap: '6px', marginTop: '10px' } }, [
          el('button', { class: 'btn btn-ghost', text: 'Reveal in Finder' }),
          el('button', { class: 'btn btn-ghost', text: 'Open in editor' }),
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
      el('button', { class: 'btn btn-ghost', text: 'Reveal in Finder' }),
      el('button', { class: 'btn btn-ghost', text: 'Open in editor' }),
    ]),
  ]);
}

// =====================================================================
// Bootstrap
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
  const backdrop = document.getElementById('inspector-backdrop');
  if (backdrop) backdrop.addEventListener('click', closeInspector);

  window.addEventListener('popstate', () => {
    const urlParams = new URLSearchParams(window.location.search);
    const viewId = urlParams.get('view') || 'accounts-overview';
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
