/* TaxMiner — Panorama with cross-filtering (req_0019, work_0030).
   One source of truth (the state below) and one data model (fund x month
   facts from src/intelligence/panorama_data.R); every component — KPIs,
   composition bar, family panels and the two Top-20 rankings — is computed
   from the same filtered rows on every change, so they never disagree.

   Filter propagation:
     state = {month, families[], admins[], funds[]}
     - Dimensions combine with AND; values inside one dimension with OR.
     - KPIs and the composition use every filter (composition ignores the
       family filter so it can show the other families dimmed).
     - Each chart ignores only its own dimension (classic cross-filtering): the
       administrator ranking ignores the administrator selection, the fund
       ranking ignores the fund selection, the family panels ignore the family
       filter. Selected items are highlighted and stay visible (pinned) even
       when they fall outside a recalculated Top 20.
     - The administrator of a fund is the one reported in the month shown
       (historical link), never the current one retroacted.
   Same file in the local app (data under panorama-data/) and on the published
   page (data/panorama/). The pure part is exported for tests (Node). */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.TMPanorama = api;
})(this, function () {
  'use strict';

  function monthIndex(m) { return parseInt(m.substr(0, 4), 10) * 12 + parseInt(m.substr(5, 2), 10) - 1; }
  function monthOf(i) { var y = Math.floor(i / 12), mo = i % 12 + 1; return y + '-' + (mo < 10 ? '0' : '') + mo; }
  function shiftMonth(m, k) { return monthOf(monthIndex(m) + k); }

  // Months shown per family: the chosen month for all, or each family's last
  // complete month (reference).
  function snapshotMonths(index, month) {
    var out = {};
    index.families.forEach(function (f) { out[f] = month || index.complete[f]; });
    return out;
  }

  // Rows of the snapshot: each family at its month; each CNPJ once across
  // families (first family in the canonical order), as market_snapshot() in R.
  function snapshot(index, monthRows, months) {
    var seen = {}, out = [];
    index.families.forEach(function (fam) {
      var rows = monthRows[months[fam]] || [];
      rows.forEach(function (r) {
        var fund = index.funds[r[0]];
        if (!fund || fund[0] !== fam || seen[fund[3]]) return;
        seen[fund[3]] = true;
        out.push({fund: r[0], admin: r[1], pl: r[2], holders: r[3], carried: r[4] === 1, family: fam,
                  month: months[fam]});
      });
    });
    return out;
  }

  // AND across dimensions, OR inside one; `skip` names dimensions to ignore.
  function filterRows(rows, st, skip) {
    skip = skip || [];
    var fams = skip.indexOf('families') < 0 && st.families.length ? st.families : null;
    var admins = skip.indexOf('admins') < 0 && st.admins.length ? st.admins : null;
    var funds = skip.indexOf('funds') < 0 && st.funds.length ? st.funds : null;
    return rows.filter(function (r) {
      return (!fams || fams.indexOf(r.family) >= 0) && (!admins || admins.indexOf(r.admin) >= 0) &&
             (!funds || funds.indexOf(r.fund) >= 0);
    });
  }

  function sum(rows, key) {
    var s = 0, any = false;
    rows.forEach(function (r) { if (r[key] != null) { s += r[key]; any = true; } });
    return any ? s : null;
  }

  function hhi(values) {
    var v = values.filter(function (x) { return x != null && x > 0; }), t = 0;
    v.forEach(function (x) { t += x; });
    if (!v.length || !(t > 0)) return null;
    var h = 0;
    v.forEach(function (x) { h += Math.pow(100 * x / t, 2); });
    return h;
  }

  // Administrators of the rows (funds without a published administrator are
  // left out, as in the Administradores tab), largest first.
  function adminRanking(rows) {
    var by = {}, total = 0;
    rows.forEach(function (r) {
      if (r.admin < 0) return;
      var a = by[r.admin] || (by[r.admin] = {admin: r.admin, pl: 0, funds: 0, families: {}});
      if (r.pl != null) { a.pl += r.pl; total += r.pl; }
      a.funds += 1; a.families[r.family] = true;
    });
    var list = Object.keys(by).map(function (k) { return by[k]; });
    list.sort(function (x, y) { return y.pl - x.pl || x.admin - y.admin; });
    var cum = 0;
    list.forEach(function (a, i) {
      a.rank = i + 1; a.share = total > 0 ? a.pl / total : null;
      cum += a.pl; a.cumulative = total > 0 ? cum / total : null;
    });
    list.total = total;
    return list;
  }

  function fundRanking(rows) {
    var list = rows.slice();
    list.sort(function (x, y) {
      if (x.pl == null && y.pl == null) return x.fund - y.fund;
      if (x.pl == null) return 1; if (y.pl == null) return -1;
      return y.pl - x.pl || x.fund - y.fund;
    });
    list.forEach(function (r, i) { r.rank = i + 1; });
    return list;
  }

  // The first `top` items plus selected items further down (pinned).
  function topWithPinned(list, key, selected, top) {
    var head = list.slice(0, top), pinned = list.slice(top).filter(function (x) { return selected.indexOf(x[key]) >= 0; });
    return {head: head, pinned: pinned};
  }

  function change(now, before) {
    return now != null && before != null && before > 0 ? (now - before) / before : null;
  }

  // KPIs of the filtered universe (`prev`: same filters, 12 months earlier).
  function kpis(rows, prev) {
    var ranking = adminRanking(rows), pl = sum(rows, 'pl');
    return {
      pl: pl, change: change(pl, sum(prev, 'pl')), funds: rows.length, holders: sum(rows, 'holders'),
      admins: ranking.length, hhi: hhi(ranking.map(function (a) { return a.pl; })),
      top5: ranking.length ? ranking[Math.min(5, ranking.length) - 1].cumulative : null
    };
  }

  // Sum of monthly series [first month, [values], [counts]] aligned by month;
  // a month where every series is missing stays missing (never zero).
  function sumSeries(list) {
    list = list.filter(function (s) { return s && s[1] && s[1].length; });
    if (!list.length) return null;
    var lo = Infinity, hi = -Infinity;
    list.forEach(function (s) {
      var a = monthIndex(s[0]); lo = Math.min(lo, a); hi = Math.max(hi, a + s[1].length - 1);
    });
    var n = hi - lo + 1, pl = new Array(n), cnt = new Array(n);
    for (var i = 0; i < n; i++) { pl[i] = null; cnt[i] = null; }
    list.forEach(function (s) {
      var off = monthIndex(s[0]) - lo;
      s[1].forEach(function (v, i) {
        if (v != null) pl[off + i] = (pl[off + i] || 0) + v;
        var c = s[2] ? s[2][i] : (v != null ? 1 : null);
        if (c != null) cnt[off + i] = (cnt[off + i] || 0) + c;
      });
    });
    return [monthOf(lo), pl, cnt];
  }

  return {monthIndex: monthIndex, shiftMonth: shiftMonth, snapshotMonths: snapshotMonths, snapshot: snapshot,
          filterRows: filterRows, adminRanking: adminRanking, fundRanking: fundRanking, topWithPinned: topWithPinned,
          kpis: kpis, hhi: hhi, sum: sum, change: change, sumSeries: sumSeries};
});

/* ---- Screen (browser only) ------------------------------------------------ */
(function () {
  'use strict';
  if (typeof window === 'undefined' || !window.jQuery) return;
  var $ = window.jQuery, E = window.TMPanorama, TOP = 20;
  var MONTHS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

  function num(v, d) { return v.toLocaleString('pt-BR', {minimumFractionDigits: d, maximumFractionDigits: d}); }
  function fmtInt(v) { return v == null || isNaN(v) ? '—' : num(Math.round(v), 0); }
  function fmtBRL(v, d) {
    if (v == null || isNaN(v)) return '—';
    d = d == null ? 1 : d;
    var a = Math.abs(v), u = [1, ''];
    if (a >= 1e12) u = [1e12, 'tri']; else if (a >= 1e9) u = [1e9, 'bi'];
    else if (a >= 1e6) u = [1e6, 'mi']; else if (a >= 1e3) u = [1e3, 'mil'];
    return ('R$ ' + num(v / u[0], u[1] ? d : 0) + ' ' + u[1]).trim();
  }
  function axisBRL(v) { return fmtBRL(v, 1).replace(',0 ', ' '); }
  function axisInt(v) {
    if (v == null) return '—';
    if (Math.abs(v) >= 1e6) return num(v / 1e6, 1).replace(',0', '') + ' mi';
    if (Math.abs(v) >= 1e3) return num(v / 1e3, 1).replace(',0', '') + ' mil';
    return fmtInt(v);
  }
  function fmtPct(v, d, sign) {
    if (v == null || isNaN(v)) return '—';
    var s = num(100 * v, d == null ? 1 : d) + '%';
    return sign !== false && v > 0 ? '+' + s : s;
  }
  function monthLabel(m) { return m ? MONTHS[parseInt(m.substr(5, 2), 10) - 1] + '/' + m.substr(0, 4) : '—'; }
  function esc(s) {
    return s == null ? '' : String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function hhiLabel(h) {
    return h == null ? 'sem dados' : h < 1500 ? 'baixa concentração' : h <= 2500 ? 'concentração moderada' : 'alta concentração';
  }
  function changeBadge(x) {
    if (x == null) return '<span class="tm-change">sem base de comparação</span>';
    var cls = x > 0.0005 ? 'tm-up' : x < -0.0005 ? 'tm-down' : 'tm-flat', arrow = cls === 'tm-up' ? '▲' : cls === 'tm-down' ? '▼' : '■';
    return '<span class="tm-change ' + cls + '">' + arrow + ' ' + fmtPct(x) + '<span class="tm-change-sub">em 12 meses</span></span>';
  }
  function kpi(label, value, note) {
    return '<div class="tm-kpi"><div class="tm-kpi-value">' + value + '</div><div class="tm-kpi-label">' + label +
           '</div>' + (note ? '<div class="tm-kpi-note">' + note + '</div>' : '') + '</div>';
  }

  // Line chart with optional right axis (port of svg_line_chart, charts.R).
  function nice(max) {
    if (!(max > 0)) return 1;
    var raw = max / 4, p = Math.pow(10, Math.floor(Math.log10(raw))), f = raw / p;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * p;
  }
  function chart(start, values, values2, o) {
    var n = values ? values.length : 0;
    if (!n || !values.some(function (v) { return v != null; })) return '<div class="tm-chart-empty">Sem dados para a seleção.</div>';
    var W = o.width || 360, H = o.height || 128, dual = values2 && values2.some(function (v) { return v != null; });
    var ml = 54, mr = dual ? 40 : 10, mt = 8, mb = 20, pw = W - ml - mr, ph = H - mt - mb;
    var i0 = E.monthIndex(start), months = values.map(function (_, i) { return E.shiftMonth(start, i); });
    var x = function (i) { return ml + (n > 1 ? i / (n - 1) : 0.5) * pw; };
    var vmax = Math.max.apply(null, values.filter(function (v) { return v != null; }).concat([0]));
    var step = nice(vmax), ymax = Math.max(step, Math.ceil(vmax / step) * step), k = Math.round(ymax / step);
    var y = function (v) { return mt + ph - v / ymax * ph; };
    var out = [];
    for (var t = 0; t <= k; t++) {
      var v = t * step;
      out.push('<line class="tm-grid" x1="' + ml + '" x2="' + (W - mr) + '" y1="' + y(v).toFixed(1) + '" y2="' + y(v).toFixed(1) +
               '"/><text class="tm-axis" x="' + (ml - 6) + '" y="' + (y(v) + 4).toFixed(1) + '" text-anchor="end">' + esc(axisBRL(v)) + '</text>');
    }
    var y2 = null;
    if (dual) {
      var m2 = Math.max.apply(null, values2.filter(function (v) { return v != null; }).concat([0]));
      // Right axis: k steps like the left one (nice_step(max / k) * k in R).
      var raw = Math.max(m2, 1) / (k || 1), p10 = Math.pow(10, Math.floor(Math.log10(raw))), fr = raw / p10;
      var top2 = (fr <= 1 ? 1 : fr <= 2 ? 2 : fr <= 2.5 ? 2.5 : fr <= 5 ? 5 : 10) * p10 * (k || 1);
      y2 = function (v) { return mt + ph - v / top2 * ph; };
      for (var t2 = 0; t2 <= k; t2++) {
        out.push('<text class="tm-axis tm-axis-2" x="' + (W - mr + 5) + '" y="' + (mt + ph - t2 / k * ph + 4).toFixed(1) +
                 '" text-anchor="start">' + esc(axisInt(top2 * t2 / k)) + '</text>');
      }
    }
    var y0 = Math.floor(i0 / 12), y1 = Math.floor((i0 + n - 1) / 12), ys = Math.max(1, Math.ceil((y1 - y0 + 1) / 5));
    for (var yr = y0; yr <= y1; yr += ys) {
      var idx = yr * 12 - i0; if (idx < 0 || idx > n - 1) continue;
      out.push('<line class="tm-tick" x1="' + x(idx).toFixed(1) + '" x2="' + x(idx).toFixed(1) + '" y1="' + (mt + ph) + '" y2="' + (mt + ph + 3) +
               '"/><text class="tm-axis" x="' + x(idx).toFixed(1) + '" y="' + (H - 5) + '" text-anchor="middle">' + yr + '</text>');
    }
    function path(vals, fy, cls, color, area) {
      var segs = [], cur = [];
      vals.forEach(function (v, i) { if (v == null) { if (cur.length) segs.push(cur); cur = []; } else cur.push(i); });
      if (cur.length) segs.push(cur);
      segs.forEach(function (s) {
        var d = s.map(function (i) { return x(i).toFixed(1) + ',' + fy(vals[i]).toFixed(1); }).join(' L');
        if (area) out.push('<path class="tm-area" d="M' + x(s[0]).toFixed(1) + ',' + fy(0).toFixed(1) + ' L' + d + ' L' +
                           x(s[s.length - 1]).toFixed(1) + ',' + fy(0).toFixed(1) + ' Z" fill="' + color + '"/>');
        out.push('<path class="' + cls + '" d="M' + d + '" stroke="' + color + '"/>');
      });
    }
    path(values, y, 'tm-line', o.color, true);
    if (dual) path(values2, y2, 'tm-line tm-line-2', '#5b6573', false);
    months.forEach(function (m, i) {
      var a = i ? (x(i - 1) + x(i)) / 2 : ml, b = i < n - 1 ? (x(i) + x(i + 1)) / 2 : W - mr;
      var tip = monthLabel(m) + '\nPL ' + fmtBRL(values[i]) + (dual ? '\n' + fmtInt(values2[i]) + ' fundos' : '') +
                '\nClique para ver esta competência';
      out.push('<g class="tm-hit' + (m === o.selected ? ' tm-hit-on' : '') + '" data-month="' + m + '" data-tip="' + esc(tip) +
               '"><rect x="' + a.toFixed(1) + '" y="' + mt + '" width="' + Math.max(1, b - a).toFixed(1) + '" height="' + ph +
               '"/><line class="tm-cross" x1="' + x(i).toFixed(1) + '" x2="' + x(i).toFixed(1) + '" y1="' + mt + '" y2="' + (mt + ph) + '"/>' +
               (values[i] == null ? '' : '<circle class="tm-dot" cx="' + x(i).toFixed(1) + '" cy="' + y(values[i]).toFixed(1) + '" r="4" fill="' + o.color + '"/>') +
               '</g>');
    });
    return '<svg class="tm-chart tm-chart-pick" viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="' + esc(o.label) + '">' + out.join('') + '</svg>';
  }

  function bars(items, o) {
    var top = Math.max.apply(null, items.map(function (r) { return r.value || 0; }).concat([0]));
    return items.map(function (r) {
      var w = top > 0 && r.value != null ? Math.max(0.4, 100 * r.value / top) : 0;
      return '<div class="tm-bar-row tm-pick' + (r.selected ? ' tm-selected' : '') + '" role="button" tabindex="0" data-' + o.kind +
             '="' + r.key + '" data-tip="' + esc(r.tip) + '"><span class="tm-bar-rank">' + r.rank + '</span><div class="tm-bar-label">' +
             '<div class="tm-bar-name">' + esc(r.label) + '</div><div class="tm-bar-sub">' + esc(r.sub) + '</div></div>' +
             '<div class="tm-bar-track"><div class="tm-bar" style="width:' + w.toFixed(2) + '%;background:' + r.color + '"></div></div>' +
             '<div class="tm-bar-value">' + esc(r.text) + '</div></div>';
    }).join('');
  }

  function Panorama(el) {
    this.el = el;
    this.base = el.attr('data-base') || 'panorama-data/';
    this.cache = {};
    this.state = {month: null, families: [], admins: [], funds: []};
  }
  Panorama.prototype.get = function (file) {
    if (!this.cache[file]) this.cache[file] = $.ajax({url: this.base + file, dataType: 'json', cache: true});
    return this.cache[file];
  };
  Panorama.prototype.start = function () {
    var p = this;
    p.get('index.json').done(function (index) {
      p.index = index;
      p.layout();
      p.update();
    }).fail(function () { p.el.html('<div class="tm-empty">Não foi possível carregar os dados do Panorama.</div>'); });
  };
  Panorama.prototype.layout = function () {
    var p = this, ix = p.index;
    var opts = '<option value="">Último mês completo de cada tipo</option>' + ix.months.slice().reverse().map(function (m) {
      return '<option value="' + m + '">' + monthLabel(m) + '</option>';
    }).join('');
    p.el.html(
      '<div class="tm-dash-head"><div><span class="tm-eyebrow">Panorama · Fase 1.3</span><h1>Fundos estruturados no Brasil</h1></div>' +
      '<div class="tm-dash-tools"><label class="tm-period">Competência <select class="form-select form-select-sm tm-month">' + opts +
      '</select></label><a href="#" class="tm-link tm-goto" data-tab="Sobre">Metodologia e fontes</a></div></div>' +
      '<div class="tm-dash-filters" aria-live="polite"></div>' +
      '<div class="tm-dash-kpis"></div>' +
      '<div class="tm-dash-share"><div class="tm-dash-label">Composição do patrimônio</div><div class="tm-share-box"></div></div>' +
      '<div class="tm-dash-families">' + ix.families.map(function (f) {
        return '<div class="tm-family" data-family="' + f + '" role="button" tabindex="0"></div>';
      }).join('') + '</div>' +
      '<div class="tm-dash-rank"><div class="tm-dash-card"><div class="tm-dash-card-head">' + TOP + ' maiores administradores' +
      '<span class="tm-head-note">clique filtra o painel · Ctrl+clique soma</span></div><div class="tm-rank-list tm-admin-list"></div></div>' +
      '<div class="tm-dash-card"><div class="tm-dash-card-head">' + TOP + ' maiores fundos<span class="tm-head-note">cor = tipo · clique filtra · Ctrl+clique soma</span></div>' +
      '<div class="tm-rank-list tm-fund-list"></div></div></div>');
    var toggle = function (list, v, add) {
      var i = list.indexOf(v);
      if (add) { if (i >= 0) list.splice(i, 1); else list.push(v); return list; }
      return list.length === 1 && i === 0 ? [] : [v];
    };
    p.el.on('change', '.tm-month', function () { p.state.month = this.value || null; p.update(); });
    p.el.on('click', '.tm-family .tm-hit[data-month]', function (e) {
      e.stopPropagation();
      var m = $(this).attr('data-month');
      p.state.month = p.state.month === m ? null : m;
      p.update();
    });
    p.el.on('click keydown', '.tm-family', function (e) {
      if (e.type === 'keydown' && e.key !== 'Enter' && e.key !== ' ') return;
      e.preventDefault();
      p.state.families = toggle(p.state.families, $(this).attr('data-family'), e.ctrlKey || e.metaKey);
      p.update();
    });
    p.el.on('click keydown', '[data-admin]', function (e) {
      if (e.type === 'keydown' && e.key !== 'Enter' && e.key !== ' ') return;
      e.preventDefault();
      p.state.admins = toggle(p.state.admins, +$(this).attr('data-admin'), e.ctrlKey || e.metaKey);
      p.update();
    });
    p.el.on('click keydown', '[data-fund]', function (e) {
      if (e.type === 'keydown' && e.key !== 'Enter' && e.key !== ' ') return;
      e.preventDefault();
      p.state.funds = toggle(p.state.funds, +$(this).attr('data-fund'), e.ctrlKey || e.metaKey);
      p.update();
    });
    p.el.on('click', '.tm-chip-x', function (e) {
      e.preventDefault();
      var dim = $(this).attr('data-dim'), v = $(this).attr('data-value');
      if (dim === 'month') p.state.month = null;
      else p.state[dim] = p.state[dim].filter(function (x) { return String(x) !== v; });
      p.update();
    });
    p.el.on('click', '.tm-clear-selection', function (e) { e.preventDefault(); p.state.admins = []; p.state.funds = []; p.update(); });
    p.el.on('click', '.tm-clear-all', function (e) {
      e.preventDefault(); p.state = {month: null, families: [], admins: [], funds: []}; p.update();
    });
  };

  // Loads what the state needs, then renders every component from one set of rows.
  Panorama.prototype.update = function () {
    var p = this, ix = p.index, st = p.state, token = (p.token = (p.token || 0) + 1);
    var months = E.snapshotMonths(ix, st.month), before = {};
    Object.keys(months).forEach(function (f) { before[f] = E.shiftMonth(months[f], -12); });
    var need = {}, reqs = [];
    Object.keys(months).forEach(function (f) { need[months[f]] = true; need[before[f]] = true; });
    var files = Object.keys(need).filter(function (m) { return ix.available.indexOf(m) >= 0; });
    var loaded = {};
    files.forEach(function (m) { reqs.push(p.get('months/' + m + '.json').done(function (d) { loaded[m] = d.rows; })); });
    // Series of the family panels: selected funds, else selected administrators, else totals.
    var series = null;
    if (st.funds.length) {
      var chunks = {};
      st.funds.forEach(function (fi) { var f = ix.funds[fi]; chunks[f[0] + '_' + f[3].charAt(0).toLowerCase()] = true; });
      var got = {};
      Object.keys(chunks).forEach(function (c) { reqs.push(p.get('series/' + c + '.json').done(function (d) { got[c] = d; })); });
      series = function () {
        var out = {};
        ix.families.forEach(function (fam) {
          out[fam] = E.sumSeries(st.funds.filter(function (fi) { return ix.funds[fi][0] === fam; }).map(function (fi) {
            var f = ix.funds[fi], s = (got[f[0] + '_' + f[3].charAt(0).toLowerCase()] || {})[f[3]];
            return s ? [s[0], s[1], s[1].map(function (v) { return v == null ? null : 1; })] : null;
          }));
        });
        return out;
      };
    } else if (st.admins.length) {
      var sa = null;
      reqs.push(p.get('series_admin.json').done(function (d) { sa = d; }));
      series = function () {
        var out = {};
        ix.families.forEach(function (fam) {
          out[fam] = E.sumSeries(st.admins.map(function (a) { return (sa[a] || {})[fam]; }));
        });
        return out;
      };
    } else {
      var sf = null;
      reqs.push(p.get('series_family.json').done(function (d) { sf = d; }));
      series = function () { return sf; };
    }
    p.el.addClass('tm-loading');
    $.when.apply($, reqs).done(function () {
      if (token !== p.token) return;  // a newer state is being loaded
      p.el.removeClass('tm-loading');
      var rows = E.snapshot(ix, loaded, months), prev = E.snapshot(ix, loaded, before);
      p.render(rows, prev, months, series());
    }).fail(function () {
      p.el.removeClass('tm-loading');
      p.el.find('.tm-dash-filters').html('<span class="tm-empty">Não foi possível carregar os dados desta seleção.</span>');
    });
  };

  // Family charts take the size of their box (the panel height left after the
  // figures), so the panel has no empty space below the chart.
  Panorama.prototype.drawCharts = function () {
    var p = this;
    Object.keys(p.charts || {}).forEach(function (f) {
      var c = p.charts[f], box = p.el.find('.tm-family[data-family="' + f + '"] .tm-chart-box');
      if (!c || !box.length) return;
      var w = Math.max(200, Math.floor(box.width())), h = Math.max(60, Math.floor(box.height()));
      box.html(chart(c.start, c.values, c.counts, {color: c.color, selected: c.selected, label: c.label, width: w, height: h}));
    });
  };

  Panorama.prototype.render = function (rows, prev, months, series) {
    var p = this, ix = p.index, st = p.state;
    p.charts = {};
    var all = E.filterRows(rows, st), allPrev = E.filterRows(prev, st), k = E.kpis(all, allPrev);
    var adminName = function (a) { return a >= 0 ? ix.admins[a][1] : '(sem administrador)'; };
    var monthText = st.month ? monthLabel(st.month) : ix.families.map(function (f) {
      return f.toUpperCase() + ' ' + monthLabel(months[f]);
    }).join(' · ');
    var incomplete = st.month ? ix.families.filter(function (f) { return st.month > ix.complete[f]; }) : [];

    // Active filters (single source of truth: p.state).
    var chips = [];
    if (st.month) chips.push(['month', '', 'Competência: ' + monthLabel(st.month)]);
    st.families.forEach(function (f) { chips.push(['families', f, 'Tipo: ' + f.toUpperCase()]); });
    st.admins.forEach(function (a) { chips.push(['admins', a, 'Administrador: ' + adminName(a)]); });
    st.funds.forEach(function (fi) { chips.push(['funds', fi, 'Fundo: ' + ix.funds[fi][2]]); });
    p.el.find('.tm-dash-filters').html(
      '<span class="tm-filters-label">Filtros</span>' +
      (chips.length ? chips.map(function (c) {
        return '<span class="tm-chip" title="' + esc(c[2]) + '"><span class="tm-chip-text">' + esc(c[2]) + '</span><a href="#" class="tm-chip-x" data-dim="' + c[0] + '" data-value="' + esc(c[1]) +
               '" aria-label="Remover filtro" title="Remover este filtro">×</a></span>';
      }).join('') : '<span class="tm-muted-sm">nenhum: todo o mercado</span>') +
      (st.admins.length || st.funds.length ? '<a href="#" class="tm-link tm-clear-selection">limpar seleções</a>' : '') +
      (chips.length ? '<a href="#" class="tm-link tm-clear-all">limpar tudo</a>' : '') +
      '<span class="tm-filters-universe">' + esc(monthText) + (incomplete.length ? ' · ' + incomplete.map(function (f) {
        return f.toUpperCase(); }).join(', ') + ' ainda em entrega' : '') + ' · cada CNPJ uma vez por mês</span>');
    p.el.find('.tm-month').val(st.month || '');

    // KPIs: every filter.
    var empty = !all.length;
    p.el.find('.tm-dash-kpis').html(
      kpi('Patrimônio líquido', fmtBRL(k.pl), changeBadge(k.change)) +
      kpi('Fundos', fmtInt(k.funds), empty ? 'nenhum fundo atende a todos os filtros' : 'com informe na competência') +
      kpi('Cotistas', axisInt(k.holders), 'posições; FIP não publica') +
      kpi('Administradores', fmtInt(k.admins), 'FII, FIDC e FIAGRO') +
      kpi('Concentração (HHI)', k.hhi == null ? '—' : fmtInt(Math.round(k.hhi)),
          k.hhi == null ? 'sem administradores' : k.admins === 1 ? 'um só administrador na seleção' :
            hhiLabel(k.hhi) + ' · 5 maiores: ' + fmtPct(k.top5, 1, false)));

    // Composition: every filter except the family one.
    var noFam = E.filterRows(rows, st, ['families']), total = E.sum(noFam, 'pl') || 0;
    var byFam = ix.families.map(function (f) {
      return {f: f, pl: E.sum(noFam.filter(function (r) { return r.family === f; }), 'pl') || 0};
    }).filter(function (x) { return x.pl > 0; });
    p.el.find('.tm-share-box').html(total > 0 ?
      '<div class="tm-share"><div class="tm-share-track">' + byFam.map(function (x) {
        var dim = st.families.length && st.families.indexOf(x.f) < 0;
        return '<div class="tm-share-seg' + (dim ? ' tm-dim' : '') + '" data-tip="' + esc(x.f.toUpperCase() + ' · ' + ix.names[x.f] + '\n' +
               fmtBRL(x.pl) + ' · ' + fmtPct(x.pl / total, 1, false)) + '" style="flex-basis:' + (100 * x.pl / total).toFixed(3) +
               '%;background:' + ix.colors[x.f] + '"></div>';
      }).join('') + '</div><div class="tm-legend">' + byFam.map(function (x) {
        return '<div class="tm-legend-item"><span class="tm-swatch" style="background:' + ix.colors[x.f] + '"></span><span class="tm-legend-name">' +
               x.f.toUpperCase() + ' · ' + esc(ix.names[x.f]) + '</span><span class="tm-legend-value">' + fmtPct(x.pl / total, 1, false) +
               '</span><span class="tm-legend-sub">' + fmtBRL(x.pl) + '</span></div>';
      }).join('') + '</div></div>' : '<div class="tm-empty">Sem patrimônio na seleção.</div>');

    // Family panels: every filter except the family one; series of the selection.
    var noFamPrev = E.filterRows(prev, st, ['families']);
    ix.families.forEach(function (f) {
      var r = noFam.filter(function (x) { return x.family === f; }), rp = noFamPrev.filter(function (x) { return x.family === f; });
      var pl = E.sum(r, 'pl'), holders = E.sum(r, 'holders'), s = series ? series[f] : null;
      var active = st.families.indexOf(f) >= 0, dim = st.families.length && !active;
      var pending = !st.month && ix.latest[f] > ix.complete[f];
      var sel = st.month || months[f];
      var cut = s ? E.monthIndex(ix.complete[f]) - E.monthIndex(s[0]) + 1 : 0;
      var vals = s ? s[1].slice(0, Math.max(0, cut)) : null, cnt = s ? s[2].slice(0, Math.max(0, cut)) : null;
      p.el.find('.tm-family[data-family="' + f + '"]').toggleClass('tm-active', active).toggleClass('tm-dim', !!dim)
        .attr('title', 'Clique para filtrar por ' + f.toUpperCase() + ' (Ctrl+clique soma tipos); clique no gráfico para escolher a competência')
        .html('<div class="tm-family-head"><span class="tm-swatch" style="background:' + ix.colors[f] + '"></span><span class="tm-family-code">' +
              f.toUpperCase() + '</span><span class="tm-family-name">' + esc(ix.names[f]) + '</span><span class="tm-family-month"' +
              (pending ? ' data-tip="Último mês completo.\n' + monthLabel(ix.latest[f]) + ' ainda em entrega (não exibido)."' : '') + '>' +
              monthLabel(months[f]) + (pending ? ' ⓘ' : '') + '</span></div>' +
              '<div class="tm-family-figures"><div><div class="tm-big">' + fmtBRL(pl) + '</div>' + changeBadge(E.change(pl, E.sum(rp, 'pl'))) +
              '</div><div class="tm-family-side"><div><strong>' + fmtInt(r.length) + '</strong> fundos</div><div>' +
              (holders == null ? '<span class="tm-muted-sm">cotistas não publicados</span>' : '<strong>' + axisInt(holders) + '</strong> cotistas') +
              '</div></div></div>' +
              '<div class="tm-chart-key"><span class="tm-key-line" style="border-top-color:' + ix.colors[f] + '"></span>Patrimônio líquido (eixo esq.)' +
              '<span class="tm-key-line tm-key-dash" style="border-top-color:#5b6573"></span>Fundos (eixo dir.)</div>' +
              '<div class="tm-chart-box">' + (s ? '' :
                '<div class="tm-chart-empty">Sem dados para a seleção.</div>') + '</div>');
      p.charts[f] = s ? {start: s[0], values: vals, counts: cnt, color: ix.colors[f], selected: sel,
                         label: 'Patrimônio líquido e número de fundos ' + f.toUpperCase() + ' por mês'} : null;
    });
    p.drawCharts();

    // Administrators: every filter except the administrator one.
    var ar = E.adminRanking(E.filterRows(rows, st, ['admins'])), at = E.topWithPinned(ar, 'admin', st.admins, TOP);
    var missingAdmins = st.admins.filter(function (a) { return !ar.some(function (x) { return x.admin === a; }); });
    var adminItem = function (a) {
      var fams = ix.families.filter(function (f) { return a.families[f]; }).map(function (f) { return f.toUpperCase(); }).join(' · ');
      return {key: a.admin, rank: a.rank, label: adminName(a.admin), value: a.pl, color: '#0b1f3a',
              text: fmtBRL(a.pl) + ' · ' + fmtPct(a.share, 1, false), sub: fmtInt(a.funds) + ' fundos · ' + fams,
              selected: st.admins.indexOf(a.admin) >= 0,
              tip: adminName(a.admin) + '\n' + ix.admins[a.admin][2] + '\n' + fmtInt(a.funds) + ' fundos · ' + fams +
                   '\nParticipação ' + fmtPct(a.share, 1, false) + ' · acumulada ' + fmtPct(a.cumulative, 1, false) +
                   '\nClique para filtrar; Ctrl+clique para somar'};
    };
    p.el.find('.tm-admin-list').html(
      (ar.length ? '<div class="tm-bars">' + bars(at.head.map(adminItem), {kind: 'admin'}) + '</div>' :
        '<div class="tm-empty">' + (st.families.length && st.families.every(function (f) { return ix.admin_families.indexOf(f) < 0; }) ?
          'O FIP não publica administrador no informe.' : 'Nenhum administrador na seleção.') + '</div>') +
      (at.pinned.length || missingAdmins.length ? '<div class="tm-pinned-label">Selecionados fora dos ' + TOP + ' maiores</div><div class="tm-bars">' +
        bars(at.pinned.map(adminItem).concat(missingAdmins.map(function (a) {
          return {key: a, rank: '–', label: adminName(a), value: 0, color: '#0b1f3a', text: 'sem fundos aqui', sub: 'fora da seleção atual',
                  selected: true, tip: adminName(a) + '\nSem fundos que atendam aos demais filtros.\nClique para remover a seleção'};
        })), {kind: 'admin'}) + '</div>' : ''));

    // Funds: every filter except the fund one.
    var fr = E.fundRanking(E.filterRows(rows, st, ['funds'])), ft = E.topWithPinned(fr, 'fund', st.funds, TOP);
    var missingFunds = st.funds.filter(function (fi) { return !fr.some(function (x) { return x.fund === fi; }); });
    var fundItem = function (r) {
      var f = ix.funds[r.fund];
      return {key: r.fund, rank: r.rank, label: f[2], value: r.pl, color: ix.colors[r.family], text: fmtBRL(r.pl),
              sub: r.family.toUpperCase() + ' · ' + f[1], selected: st.funds.indexOf(r.fund) >= 0,
              tip: f[2] + '\n' + r.family.toUpperCase() + ' · ' + f[1] + '\nAdministrador em ' + monthLabel(r.month) + ': ' + adminName(r.admin) +
                   '\nPL ' + fmtBRL(r.pl) + (r.carried ? ' (último informe trimestral)' : '') + '\nClique para filtrar; Ctrl+clique para somar'};
    };
    p.el.find('.tm-fund-list').html(
      (fr.length ? '<div class="tm-bars">' + bars(ft.head.map(fundItem), {kind: 'fund'}) + '</div>' :
        '<div class="tm-empty">Nenhum fundo atende aos filtros.</div>') +
      (ft.pinned.length || missingFunds.length ? '<div class="tm-pinned-label">Selecionados fora dos ' + TOP + ' maiores</div><div class="tm-bars">' +
        bars(ft.pinned.map(fundItem).concat(missingFunds.map(function (fi) {
          var f = ix.funds[fi];
          return {key: fi, rank: '–', label: f[2], value: 0, color: ix.colors[f[0]], text: 'sem informe aqui',
                  sub: f[0].toUpperCase() + ' · ' + f[1], selected: true,
                  tip: f[2] + '\nSem informe que atenda aos demais filtros.\nClique para remover a seleção'};
        })), {kind: 'fund'}) + '</div>' : ''));
  };

  $(function () {
    $('.tm-dash[data-base]').each(function () {
      var p = new Panorama($(this)), timer;
      p.start();
      // Redraw at the new size when the window changes or the tab becomes visible.
      $(window).on('resize', function () { clearTimeout(timer); timer = setTimeout(function () { p.drawCharts(); }, 150); });
      $(document).on('shown.bs.tab', function () { p.drawCharts(); });
    });
  });
})();
