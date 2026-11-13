/* TaxMiner — published (static) dashboard: fund tabs and the administrator
   month picker. Data files written by prototype/static_funds.R:
     data/funds.json            fund list, profile figures, denominations
     data/panorama/series/{fam}_{c}.json monthly series (src/intelligence/panorama_data.R)
     data/admins/{i}.json       funds of an administrator per month
   No server: everything runs in the browser. */
(function ($) {
  'use strict';

  // ---- formatting (same rules as the R helpers, pt-BR) ----
  var MONTHS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  function num(v, d) {
    return v.toLocaleString('pt-BR', {minimumFractionDigits: d, maximumFractionDigits: d});
  }
  function fmtInt(v) { return v == null || isNaN(v) ? '—' : num(Math.round(v), 0); }
  // Compact right-axis label for counts (as axis_int in prototype/charts.R).
  function axisInt(v) { return v >= 1e6 ? num(v / 1e6, 1) + ' mi' : v >= 1e4 ? num(Math.round(v / 1e3), 0) + ' mil' : fmtInt(v); }
  function fmtBRL(v, d) {
    if (v == null || isNaN(v)) return '—';
    d = d == null ? 1 : d;
    var a = Math.abs(v), u = [1, ''];
    if (a >= 1e12) u = [1e12, 'tri']; else if (a >= 1e9) u = [1e9, 'bi'];
    else if (a >= 1e6) u = [1e6, 'mi']; else if (a >= 1e3) u = [1e3, 'mil'];
    return ('R$ ' + num(v / u[0], u[1] ? d : 0) + ' ' + u[1]).trim();
  }
  function axisBRL(v) { return fmtBRL(v, 1).replace(',0 ', ' '); }
  function fmtPct(v, d, sign) {
    if (v == null || isNaN(v)) return '—';
    var s = num(100 * v, d == null ? 1 : d) + '%';
    return sign !== false && v > 0 ? '+' + s : s;
  }
  function fmtShare(v) {
    return v == null || isNaN(v) ? '—' : v > 0 && v < 0.00005 ? '< 0,01%' : fmtPct(v, 2, false);
  }
  function monthLabel(m) { return m ? MONTHS[parseInt(m.substr(5, 2), 10) - 1] + '/' + m.substr(0, 4) : '—'; }
  function esc(s) {
    return s == null ? '' : String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function fold(s) {
    return (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase()
      .replace(/[^A-Z0-9]+/g, ' ').trim();
  }
  function addMonths(m, k) {
    var y = parseInt(m.substr(0, 4), 10), n = parseInt(m.substr(5, 2), 10) - 1 + k;
    y += Math.floor(n / 12); n = ((n % 12) + 12) % 12;
    return y + '-' + (n < 9 ? '0' : '') + (n + 1);
  }

  // ---- SVG line chart (port of svg_line_chart in prototype/charts.R) ----
  function niceTicks(max) {
    if (!(max > 0)) return [0, 1];
    var raw = max / 4, p = Math.pow(10, Math.floor(Math.log10(raw))), f = raw / p;
    var step = (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * p, t = [];
    for (var v = 0; v < max + step * 0.999; v += step) t.push(v);
    return t;
  }
  function lineChart(months, values, o) {
    // o.values2 (optional): second measure, dashed neutral line on its own
    // right-hand axis whose ticks sit on the left gridlines (as svg_line_chart).
    o = $.extend({color: '#2a78d6', width: 560, height: 190, area: true, fmt: axisBRL, tip: fmtBRL, label: '',
                  values2: null, fmt2: axisInt, color2: '#5b6573', tips: null}, o);
    var ok = values.some(function (v) { return v != null; });
    if (!months.length || !ok) return '<div class="tm-chart-empty">Sem dados para o gráfico.</div>';
    var dual = !!o.values2 && o.values2.some(function (v) { return v != null; });
    var ml = 62, mr = dual ? 46 : 14, mt = 10, mb = 24, W = o.width, H = o.height, pw = W - ml - mr, ph = H - mt - mb;
    var d = months.map(function (m) { return Date.UTC(+m.substr(0, 4), +m.substr(5, 2) - 1, 1); });
    var x0 = d[0], x1 = d[d.length - 1]; if (x1 === x0) x1 = x0 + 31 * 864e5;
    var vmax = Math.max.apply(null, values.filter(function (v) { return v != null; }));
    var ticks = niceTicks(vmax), ymax = ticks[ticks.length - 1] || 1;
    function sx(v) { return ml + (v - x0) / (x1 - x0) * pw; }
    function sy(v) { return mt + ph - v / ymax * ph; }
    var px = d.map(sx), py = values.map(function (v) { return v == null ? null : sy(v); });
    var out = [];
    ticks.forEach(function (t) {
      out.push('<line class="tm-grid" x1="' + ml + '" x2="' + (W - mr) + '" y1="' + sy(t).toFixed(1) + '" y2="' + sy(t).toFixed(1) +
               '"/><text class="tm-axis" x="' + (ml - 8) + '" y="' + (sy(t) + 4).toFixed(1) + '" text-anchor="end">' + esc(o.fmt(t)) + '</text>');
    });
    var py2 = px.map(function () { return null; }), lines2 = [];
    if (dual) {
      var k = ticks.length - 1, raw2 = Math.max.apply(null, o.values2.filter(function (v) { return v != null; })) / k;
      var p2 = Math.pow(10, Math.floor(Math.log10(raw2 || 1))), f2 = raw2 / p2;
      var ymax2 = (raw2 > 0 ? (f2 <= 1 ? 1 : f2 <= 2 ? 2 : f2 <= 2.5 ? 2.5 : f2 <= 5 ? 5 : 10) * p2 : 1) * k;
      var sy2 = function (v) { return mt + ph - v / ymax2 * ph; };
      py2 = o.values2.map(function (v) { return v == null ? null : sy2(v); });
      for (var j = 0; j <= k; j++) {
        var t2 = ymax2 * j / k;
        out.push('<text class="tm-axis tm-axis-2" x="' + (W - mr + 6) + '" y="' + (sy2(t2) + 4).toFixed(1) + '" text-anchor="start">' +
                 esc(o.fmt2(t2)) + '</text>');
      }
      var seg2 = [], c2 = [];
      py2.forEach(function (v, i) { if (v == null) { if (c2.length) seg2.push(c2); c2 = []; } else c2.push(i); });
      if (c2.length) seg2.push(c2);
      seg2.forEach(function (sg) {
        lines2.push('<path class="tm-line tm-line-2" d="M' + sg.map(function (i) { return px[i].toFixed(1) + ',' + py2[i].toFixed(1); }).join(' L') +
                    '" stroke="' + o.color2 + '"/>');
      });
    }
    var y0 = new Date(x0).getUTCFullYear(), y1 = new Date(x1).getUTCFullYear(), step = Math.max(1, Math.ceil((y1 - y0 + 1) / 6));
    for (var y = y0; y <= y1; y += step) {
      var yd = Date.UTC(y, 0, 1); if (yd < x0 || yd > x1) continue;
      out.push('<line class="tm-tick" x1="' + sx(yd).toFixed(1) + '" x2="' + sx(yd).toFixed(1) + '" y1="' + (mt + ph) + '" y2="' + (mt + ph + 4) +
               '"/><text class="tm-axis" x="' + sx(yd).toFixed(1) + '" y="' + (H - 6) + '" text-anchor="middle">' + y + '</text>');
    }
    // Lines are broken where a month has no report.
    var segs = [], cur = [];
    py.forEach(function (v, i) { if (v == null) { if (cur.length) segs.push(cur); cur = []; } else cur.push(i); });
    if (cur.length) segs.push(cur);
    out.push(lines2.join(''));
    segs.forEach(function (s) {
      var path = s.map(function (i) { return px[i].toFixed(1) + ',' + py[i].toFixed(1); }).join(' L');
      if (o.area) out.push('<path class="tm-area" d="M' + px[s[0]].toFixed(1) + ',' + sy(0).toFixed(1) + ' L' + path + ' L' +
                           px[s[s.length - 1]].toFixed(1) + ',' + sy(0).toFixed(1) + ' Z" fill="' + o.color + '"/>');
      out.push('<path class="tm-line" d="M' + path + '" stroke="' + o.color + '"/>');
    });
    var last = -1; py.forEach(function (v, i) { if (v != null) last = i; });
    out.push('<circle class="tm-end" cx="' + px[last].toFixed(1) + '" cy="' + py[last].toFixed(1) + '" r="4" fill="' + o.color + '"/>');
    px.forEach(function (x, i) {
      var a = i ? (px[i - 1] + x) / 2 : ml, b = i < px.length - 1 ? (x + px[i + 1]) / 2 : W - mr;
      var tip = o.tips ? o.tips[i] : monthLabel(months[i]) + '\n' + (values[i] == null ? 'sem informe' : o.tip(values[i]));
      out.push('<g class="tm-hit" data-tip="' + esc(tip) + '"><rect x="' + a.toFixed(1) + '" y="' + mt + '" width="' + Math.max(1, b - a).toFixed(1) +
               '" height="' + ph + '"/><line class="tm-cross" x1="' + x.toFixed(1) + '" x2="' + x.toFixed(1) + '" y1="' + mt + '" y2="' + (mt + ph) + '"/>' +
               (py[i] == null ? '' : '<circle class="tm-dot" cx="' + x.toFixed(1) + '" cy="' + py[i].toFixed(1) + '" r="5" fill="' + o.color + '"/>') +
               (py2[i] == null ? '' : '<circle class="tm-dot" cx="' + x.toFixed(1) + '" cy="' + py2[i].toFixed(1) + '" r="4" fill="' + o.color2 + '"/>') + '</g>');
    });
    return '<svg class="tm-chart" viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="' + esc(o.label) + '">' + out.join('') + '</svg>';
  }

  // Horizontal bars (same markup as bar_list in prototype/charts.R).
  function barList(rows) {
    var top = Math.max.apply(null, rows.map(function (r) { return r.value || 0; }).concat([0]));
    return '<div class="tm-bars">' + rows.map(function (r) {
      var w = top > 0 && r.value != null ? Math.max(0.4, 100 * r.value / top) : 0;
      return '<div class="tm-bar-row' + (r.key ? ' tm-fund-pick" data-fund-key="' + esc(r.key) : '') + '" data-tip="' + esc(r.tip) + '"><div class="tm-bar-label"><div class="tm-bar-name">' + esc(r.label) +
             '</div><div class="tm-bar-sub">' + esc(r.sub) + '</div></div><div class="tm-bar-track"><div class="tm-bar" style="width:' +
             w.toFixed(2) + '%;background:' + r.color + '"></div></div><div class="tm-bar-value">' + esc(r.text) + '</div></div>';
    }).join('') + '</div>';
  }

  // Same as fund_family_colors (prototype/charts.R); funds.json carries them too.
  var FAMILY_COLORS = {fii: '#2a78d6', fidc: '#eb6834', fip: '#1baf7a', fiagro: '#eda100'};
  var cache = {};
  function getJSON(url) {
    if (!cache[url]) cache[url] = $.ajax({url: url, dataType: 'json', cache: true});
    return cache[url];
  }

  // ---- Administradores: a month clicked on the chart lists its funds ----
  $(document).on('tm:month', '.tm-admin-body', function (e, month) {
    var box = $(this), file = box.attr('data-admin-file'), list = box.find('.tm-admin-funds');
    if (!file) return;
    getJSON(file).done(function (a) {
      var i = a.months.indexOf(month), rows = i < 0 ? [] : a.rows[i];
      var total = rows.reduce(function (s, r) { return s + (r[1] || 0); }, 0), carried = rows.some(function (r) { return r[2]; });
      var colors = (window.TM_FUNDS_META || {}).colors || FAMILY_COLORS;
      var head = '<div class="tm-subhead tm-funds-head"><span>Fundos em ' + monthLabel(month) + ' (' + fmtInt(rows.length) + ') · ' +
                 fmtBRL(total) + '</span>' + (carried ? '<span class="tm-head-note">* valor repetido do último informe</span>' : '') +
                 '<a href="#" class="tm-month-reset">voltar ao mês de referência</a></div>';
      if (!list.data('reference')) list.data('reference', list.html());
      list.html(head + (rows.length ? barList(rows.map(function (r) {
        var f = a.funds[r[0]];
        return {label: f[0] + (r[2] ? ' *' : ''), value: r[1], text: fmtBRL(r[1]) + ' · ' + fmtPct(total ? r[1] / total : null, 1, false), color: colors[f[1]] || '#2a78d6',
                sub: f[1].toUpperCase() + ' · ' + f[2], key: f[1] + '|' + String(f[2]).replace(/\D/g, ''), tip: f[0] + '\n' + fmtPct(total ? r[1] / total : null, 1, false) + ' do total'};
      })) : '<div class="tm-empty">Sem fundos neste mês.</div>'));
      list.scrollTop(0);
    }).fail(function () { list.html('<div class="tm-empty">Não foi possível carregar os fundos deste mês.</div>'); });
  });
  $(document).on('click', '.tm-admin-body .tm-month-reset', function (e) {
    e.preventDefault();
    var body = $(this).closest('.tm-admin-body'), list = body.find('.tm-admin-funds');
    if (list.data('reference')) list.html(list.data('reference'));
    body.find('.tm-hit-on').removeClass('tm-hit-on');
  });

  // ---- Fund tabs (Fundos, FIDC, FII, FIP, FIAGRO) ----
  var F = {family: 0, entity: 1, cnpj: 2, key: 3, name: 4, names: 5, admin: 6, adminEntity: 7, adminCnpj: 8,
           first: 9, last: 10, count: 11, pl: 12, plMonth: 13, change: 14, rank: 15, peers: 16, pct: 17, holders: 18, share: 19, entInv: 20, traits: 21,
           holdersLast: 22, holdersMonth: 23};
  var PAGE = 25, data = null;

  function loadFunds() {
    if (!data) {
      data = getJSON('data/funds.json').then(function (d) {
        TABLE_LABELS = d.meta.tables || {};
        var byEntity = {};
        d.names.forEach(function (n) { (byEntity[n[0]] = byEntity[n[0]] || []).push(n); });
        d.funds.forEach(function (f) {
          var ns = byEntity[f[F.entity]] || [];
          f.search = fold([f[F.name], f[F.admin]].concat(ns.map(function (n) { return n[2]; })).join(' ')) + ' ' +
                     f[F.key] + ' ' + (f[F.adminCnpj] || '').replace(/\D/g, '');
          // Folded once here, not on every filter, sort or page change.
          f.nameKey = fold(f[F.name]); f.adminKey = fold(f[F.admin]);
          f.adminDigits = (f[F.adminCnpj] || '').replace(/\D/g, '');
        });
        d.byEntity = byEntity;
        window.TM_FUNDS_META = d.meta;
        return d;
      });
    }
    return data;
  }

  var SORTS = [
    {by: 'name', label: 'Fundo', dec: false},
    {by: 'period', label: 'Período', dec: true},
    {by: 'count', label: 'Informes', dec: true, num: true},
    {by: 'pl', label: 'PL', dec: true, num: true,
     tip: 'Patrimônio líquido no mês de referência do tipo (último mês completo; para fundos fora dele, o último informe)'},
    {by: 'share', label: '%', dec: true, num: true,
     tip: 'Participação do fundo no patrimônio total do seu tipo no mês de referência (mesma base do Panorama)'}
  ];

  function FundTab(el) {
    this.el = el; this.family = el.attr('data-family') || '';
    this.families = this.family ? [this.family] : ['fidc', 'fii', 'fip', 'fiagro'];
    this.sort = {by: 'pl', dec: true}; this.page = 0; this.selected = null;
    // New filters: largest funds first, and the first result is shown.
    this.reset = function () { this.sort = {by: 'pl', dec: true}; this.page = 0; this.selected = null; this.update(); };
    el.data('tm-tab', this);
  }
  FundTab.prototype.render = function (d) {
    var t = this, fam = t.family, meta = d.meta;
    var title = fam ? fam.toUpperCase() + ' · ' + (meta.family_names[fam] || '') : 'Fundos';
    var chips = fam ? '' : '<div class="tm-filter-family"><div class="shiny-options-group">' + t.families.map(function (f) {
      return '<label><input type="checkbox" value="' + f + '" checked> ' + f.toUpperCase() + '</label>';
    }).join('') + '</div></div>';
    t.el.html(
      '<div class="tm-dash-head"><div><span class="tm-eyebrow">Fase 1.3 · Informes de fundos</span><h1>' + esc(title) + '</h1></div>' +
      '<div class="tm-dash-meta tm-strip"></div></div>' +
      '<div class="tm-filterbar">' + chips +
      '<div class="tm-filter-wide"><input type="search" class="form-control form-control-sm tm-q" placeholder="Fundo: nome atual ou anterior, ou CNPJ (com ou sem máscara)"></div>' +
      '<div class="tm-filter-wide"><input type="search" class="form-control form-control-sm tm-qa" placeholder="Administrador: nome ou CNPJ"></div>' +
      (fam === 'fip' ? '<div data-tip="' + esc('Indica se o fundo é entidade de investimento (ENTID_INVEST, último informe que o publicou)' +
        noteText('ENTID_INVEST')) + '">' +
        '<select class="form-select form-select-sm tm-qe"><option value="">Entidade de investimento: todos</option>' +
        '<option value="S">Entidade de investimento: sim</option><option value="N">Entidade de investimento: não</option>' +
        '<option value="NA">Entidade de investimento: não informado</option></select></div>' : '') +
      '<button type="button" class="btn btn-link btn-sm tm-filter-clear">Limpar</button></div>' +
      '<div class="tm-master-detail tm-static-grid">' +
      '<div class="card tm-section tm-pane"><div class="card-header tm-card-head"><span class="tm-count"></span>' +
      '<span class="tm-head-note">clique em um fundo</span></div><div class="card-body tm-scroll tm-list"></div>' +
      '<div class="tm-pager"></div></div>' +
      '<div class="tm-pane-wrap"><div class="card tm-section tm-detail tm-pane tm-static-detail"><div class="tm-empty">Selecione um fundo na lista.</div></div></div></div>');
    var timer;
    t.el.on('input', '.tm-q, .tm-qa', function () { clearTimeout(timer); timer = setTimeout(function () { t.reset(); }, 180); });
    t.el.on('change', '.tm-filter-family input, .tm-qe', function () { t.reset(); });
    t.el.on('click', '.tm-filter-clear', function () {
      t.el.find('.tm-q, .tm-qa, .tm-qe').val(''); t.el.find('.tm-filter-family input').prop('checked', true); t.reset();
    });
    t.el.on('click', 'th[data-sort]', function () {
      var by = $(this).attr('data-sort'), s = SORTS.filter(function (x) { return x.by === by; })[0];
      t.sort = t.sort.by === by ? {by: by, dec: !t.sort.dec} : {by: by, dec: s.dec}; t.page = 0; t.update();
    });
    t.el.on('click', '.tm-pager a', function (e) { e.preventDefault(); t.page += +$(this).attr('data-step'); t.update(); });
    t.el.on('click', 'tr[data-row]', function () {
      $(this).addClass('tm-selected').siblings('.tm-selected').removeClass('tm-selected');
      t.selected = t.rows[+$(this).attr('data-row')]; t.detail(t.selected);
      setCurrent(t.selected);
    });
    t.el.on('change', '.tm-ficha-table', function () { if (t.ficha) t.fichaTable(+this.value); });
    t.el.on('change', '.tm-ficha-period', function () { if (t.ficha) t.fichaPeriod(this.value); });
    t.el.on('click', '.tm-static-detail .nav-link', function (e) {
      e.preventDefault();
      var k = $(this).attr('data-pane'), box = $(this).closest('.tm-static-detail');
      box.find('.nav-link').removeClass('active'); $(this).addClass('active');
      box.find('[data-pane-body]').attr('hidden', true).filter('[data-pane-body="' + k + '"]').removeAttr('hidden');
    });
    t.d = d; t.update();
    if (t.el.data('tm-open')) t.open(t.el.data('tm-open'));
    t.follow(window.tmCurrent);
  };
  // Shows the app's current fund when it belongs to this tab.
  FundTab.prototype.follow = function (key) {
    var t = this, g = t.d && findFund(t.d, key);
    if (!g || (t.family && g[F.family] !== t.family) || t.selected === g) return;
    t.selected = g; t.update(); t.detail(g);
  };
  // Show one fund: its CNPJ in the fund search, no administrator filter.
  FundTab.prototype.open = function (cnpj) {
    this.el.removeData('tm-open');
    this.el.find('.tm-q').val(cnpj); this.el.find('.tm-qa').val('');
    this.reset();
  };
  FundTab.prototype.update = function () {
    var t = this, d = t.d, q = fold(t.el.find('.tm-q').val()), qa = fold(t.el.find('.tm-qa').val());
    var qd = (t.el.find('.tm-q').val() || '').replace(/\D/g, ''), qad = (t.el.find('.tm-qa').val() || '').replace(/\D/g, '');
    var fams = t.family ? [t.family] : t.el.find('.tm-filter-family input:checked').map(function () { return this.value; }).get();
    var words = q ? q.split(' ') : [], awords = qa ? qa.split(' ') : [];
    var s = t.sort, dir = s.dec ? -1 : 1;
    // A page change reuses the filtered, sorted list; only the slice is redrawn.
    var qe = t.el.find('.tm-qe').val() || '';
    var key = [fams.join(','), q, qd, qa, qad, qe, s.by, s.dec].join('|');
    var rows = t.rowsKey === key ? t.rows : null;
    if (!rows) {
      rows = d.funds.filter(function (f) {
        if (fams.indexOf(f[F.family]) < 0) return false;
        // FIP "entidade de investimento": latest published value (S/N) or not published.
        if (qe && f[F.family] === 'fip' && (qe === 'NA' ? f[F.entInv] != null : f[F.entInv] !== qe)) return false;
        if (words.length && !(qd.length >= 4 && f[F.key].indexOf(qd) === 0) &&
            !words.every(function (w) { return f.search.indexOf(w) >= 0; })) return false;
        if (awords.length && !(qad.length >= 4 && f.adminDigits.indexOf(qad) === 0) &&
            !awords.every(function (w) { return f.adminKey.indexOf(w) >= 0; })) return false;
        return true;
      });
      var col = s.by === 'name' ? 'nameKey' : s.by === 'period' ? F.last : s.by === 'count' ? F.count : s.by === 'share' ? F.share : F.pl;
      rows.sort(function (a, b) {
        var x = a[col], y = b[col];
        if (x == null && y == null) return 0; if (x == null) return 1; if (y == null) return -1;
        return (x < y ? -1 : x > y ? 1 : 0) * dir;
      });
      t.rows = rows; t.rowsKey = key;
    }
    var pages = Math.max(1, Math.ceil(rows.length / PAGE)); t.page = Math.min(Math.max(0, t.page), pages - 1);
    var slice = rows.slice(t.page * PAGE, (t.page + 1) * PAGE);
    var head = SORTS.map(function (c) {
      var on = s.by === c.by;
      return '<th class="tm-sortable' + (on ? ' tm-sorted' : '') + (c.num ? ' tm-num' : '') + '" data-sort="' + c.by +
             '" title="' + esc(c.tip || 'Clique para ordenar; de novo para inverter') + '">' + c.label + (on ? (s.dec ? ' ▼' : ' ▲') : '') + '</th>';
    }).join('');
    var body = slice.map(function (f, i) {
      var n = t.page * PAGE + i, sel = t.selected === f ? ' class="tm-selected"' : '';
      return '<tr data-row="' + n + '"' + sel + '><td><div class="tm-id"><span class="tm-tag tm-tag-' + f[F.family] + '">' +
             f[F.family].toUpperCase() + '</span><span class="tm-mono">' + esc(f[F.cnpj]) + '</span>' +
             (f[F.names] > 1 ? '<span class="tm-names-badge" data-tip="Denominações diferentes ao longo do tempo; veja a aba Denominações.">' +
              f[F.names] + ' nomes</span>' : '') + '</div><div class="tm-fund">' + esc(f[F.name]) + '</div><div class="tm-admin">' +
             esc(f[F.admin] || 'administrador não publicado') + '</div></td><td class="tm-mono">' + esc(f[F.first]) + '<br>' + esc(f[F.last]) +
             '</td><td class="tm-num">' + fmtInt(f[F.count]) + '</td><td class="tm-num" data-tip="' +
             (f[F.plMonth] ? 'PL em ' + monthLabel(f[F.plMonth]) : '') + '">' + fmtBRL(f[F.pl]) + '</td><td class="tm-num">' +
             fmtShare(f[F.share]) + '</td></tr>';
    }).join('');
    t.el.find('.tm-list').html(rows.length ? '<table class="tm-results"><thead><tr>' + head + '</tr></thead><tbody>' + body + '</tbody></table>'
                                           : '<div class="tm-empty">Nenhum fundo encontrado.</div>').scrollTop(0);
    t.el.find('.tm-count').text(fmtInt(rows.length) + (rows.length === 1 ? ' fundo' : ' fundos'));
    t.el.find('.tm-pager').html(pages > 1 ? (t.page ? '<a href="#" data-step="-1">‹ anterior</a>' : '<span></span>') +
      '<span>página ' + fmtInt(t.page + 1) + ' de ' + fmtInt(pages) + '</span>' +
      (t.page < pages - 1 ? '<a href="#" data-step="1">próxima ›</a>' : '<span></span>') : '');
    t.el.find('.tm-strip').html('Dados gerados em ' + esc(d.meta.generated) + ' · Ficha e Série completa: todas as tabelas do FIDC e as principais dos demais tipos (as outras no app local)');
    if (!t.selected && rows.length) { t.selected = rows[0]; t.detail(rows[0]); t.el.find('tr[data-row="0"]').addClass('tm-selected'); }
  };
  FundTab.prototype.detail = function (f) {
    var t = this, d = t.d, box = t.el.find('.tm-static-detail');
    var color = d.meta.colors[f[F.family]] || '#2a78d6', names = d.byEntity[f[F.entity]] || [];
    box.html(
      '<div class="card-header tm-detail-head"><div class="tm-eyebrow">' + f[F.family].toUpperCase() + ' · ' + esc(f[F.cnpj]) + '</div>' +
      '<h2 class="tm-detail-title">' + esc(f[F.name]) + '</h2><div class="tm-detail-meta"><span><strong>Administrador: </strong>' +
      esc(f[F.admin] || 'não publicado') + (f[F.adminCnpj] ? ' · ' + esc(f[F.adminCnpj]) : '') + '</span><span><strong>Informes: </strong>' +
      fmtInt(f[F.count]) + ' (' + esc(f[F.first]) + ' a ' + esc(f[F.last]) + ')</span>' +
      '</div>' + traitsHtml(f, d.meta.traits) + '</div>' +
      '<div class="tm-detail-body"><div class="tm-static-tools"><select class="form-select form-select-sm tm-ficha-table" disabled>' +
      '<option>Carregando informes…</option></select><select class="form-select form-select-sm tm-ficha-period" disabled></select></div>' +
      '<div class="tm-caption tm-ficha-summary"></div>' +
      '<ul class="nav nav-underline"><li class="nav-item"><a class="nav-link active" href="#" data-pane="perfil">Perfil</a></li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="ficha">Ficha</a></li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="serie">Série completa</a></li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="nomes">Denominações (' + names.length + ')</a></li></ul>' +
      '<div class="tab-content"><div data-pane-body="perfil"><div class="tm-empty">Carregando série…</div></div>' +
      '<div data-pane-body="ficha" hidden><div class="tm-empty">Carregando ficha…</div></div>' +
      '<div data-pane-body="serie" class="tm-table-wrap" hidden><div class="tm-empty">Carregando série completa…</div></div>' +
      '<div data-pane-body="nomes" hidden>' + namesTable(names) + '</div></div></div>');
    var key = f[F.key];
    loadFicha(f).done(function (fd, urls) {
      if (t.selected !== f) return;
      t.ficha = {data: fd, urls: urls};
      var sel = box.find('.tm-ficha-table');
      if (!fd || !fd.t.length) {
        sel.html('<option>Sem informes nas tabelas publicadas</option>');
        box.find('[data-pane-body="ficha"], [data-pane-body="serie"]').html(
          '<div class="tm-empty">Sem linhas nas tabelas principais para este fundo. As demais tabelas estão no app local.</div>');
        return;
      }
      // The file lists the main table of the family first, then the other
      // FIDC tables (read when chosen).
      sel.html(tableOptions(fd)).prop('disabled', false);
      var best = latestTable(fd); sel.val(String(best)); t.fichaTable(best);
    });
    getJSON('data/panorama/series/' + f[F.family] + '_' + key.charAt(0).toLowerCase() + '.json').done(function (s) {
      if (t.selected !== f) return;
      box.find('[data-pane-body="perfil"]').html(profile(f, s[key], color));
    }).fail(function () {
      box.find('[data-pane-body="perfil"]').html('<div class="tm-empty">Não foi possível carregar a série deste fundo.</div>');
    });
  };
  // ---- Ficha and Série completa (data/fichas/{family}/{CNPJ}.json, written by
  // write_static_fichas in prototype/static_funds.R). Values arrive formatted
  // with the rules of the app; the markup is the one of report_card and
  // wide_table in prototype/fund_search_module.R. ----
  var CARD_COLUMNS = 6;
  // Table opened first: the one with the most recent report (e.g. the
  // four-monthly FIP report after 2023), the first listed on a tie.
  // Tables still to be read (other FIDC tables) are skipped.
  function latestTable(fd) {
    var best = -1;
    fd.t.forEach(function (x, i) { if (!x.lazy && (best < 0 || x.c[0][0] > fd.t[best].c[0][0])) best = i; });
    return best < 0 ? 0 : best;
  }
  // Picker text: the report section (fund_table_labels in
  // src/intelligence/search_fund_reports.R, sent in funds.json meta.tables);
  // the CVM file name stays in the tooltip and in each citation.
  var TABLE_LABELS = {};
  function tableLabel(n) { return TABLE_LABELS[n] || n; }
  function tableOptions(fd) {
    return fd.t.map(function (x, i) {
      var first = x.lazy ? x.first : x.c[x.c.length - 1][0], last = x.lazy ? x.last : x.c[0][0];
      return '<option value="' + i + '" title="' + esc(x.n) + '">' + esc(tableLabel(x.n)) + '  (' + esc(first) + '–' + esc(last) + ')</option>';
    }).join('');
  }
  // Other FIDC tables (data/fichas_x/{family}/, gzip, written by
  // write_static_ficha_extras): index.json.gz lists them per fund and
  // {CNPJ}.json.gz holds all of them for one fund, read only when one is
  // chosen. GitHub Pages serves .gz as is, so the browser decompresses it.
  var EXTRA_FAMILIES = {fidc: true}, gzCache = {};
  function getGz(url, keep) {
    if (gzCache[url]) return gzCache[url];
    var done = $.Deferred();
    if (keep) gzCache[url] = done.promise();
    // Loading bar (prototype/www/loadbar.js): real progress when the server
    // sends the size of the file.
    var load = window.tmLoad ? window.tmLoad.start() : null;
    function finish() { if (load != null) { window.tmLoad.done(load); load = null; } }
    done.always(finish);
    fetch(url).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      var total = +r.headers.get('Content-Length');
      if (!r.body || !r.body.getReader || !total || load == null) return r.arrayBuffer();
      var reader = r.body.getReader(), chunks = [], got = 0;
      return (function pump() {
        return reader.read().then(function (x) {
          if (x.done) {
            var all = new Uint8Array(got), at = 0;
            chunks.forEach(function (c) { all.set(c, at); at += c.length; });
            return all.buffer;
          }
          chunks.push(x.value); got += x.value.length;
          window.tmLoad.progress(load, got / total);
          return pump();
        });
      })();
    })
      .then(function (buf) {
        var b = new Uint8Array(buf);
        if (b.length > 1 && b[0] === 0x1f && b[1] === 0x8b) {
          if (typeof DecompressionStream === 'undefined') throw new Error('gzip');
          return new Response(new Blob([b]).stream().pipeThrough(new DecompressionStream('gzip'))).text();
        }
        return new TextDecoder('utf-8').decode(b);
      })
      .then(function (s) { done.resolve(JSON.parse(s)); })
      .catch(function (e) { delete gzCache[url]; done.reject(e); });
    return done.promise();
  }
  function withExtras(fd, f, ix) {
    var list = ix && ix.funds && ix.funds[f[F.key]];
    if (!list) return fd;
    var t = (fd ? fd.t : []).slice();
    list.forEach(function (e) { t.push({n: ix.tables[e[0]], lazy: true, first: e[1], last: e[2], rows: e[3]}); });
    return {t: t};
  }
  function loadFicha(f) {
    var done = $.Deferred(), fam = f[F.family], index = $.Deferred();
    if (EXTRA_FAMILIES[fam]) getGz('data/fichas_x/' + fam + '/index.json.gz', true)
      .done(function (ix) { index.resolve(ix); }).fail(function () { index.resolve(null); });
    else index.resolve(null);
    $.when(getJSON('data/fichas/urls.json'), getJSON('data/fichas/' + fam + '/' + f[F.key] + '.json'))
      .done(function (u, d) { index.done(function (ix) { done.resolve(withExtras(d[0], f, ix), u[0]); }); })
      .fail(function () {
        getJSON('data/fichas/urls.json').always(function (u) {
          index.done(function (ix) { done.resolve(withExtras(null, f, ix), $.isArray(u) ? u : []); });
        });
      });
    return done.promise();
  }
  // A table still to be read: read the fund's file of other tables, replace
  // every stub by its table and show the chosen one.
  function loadExtraTable(t, k) {
    var f = t.selected, data = t.ficha.data, x = data.t[k], box = t.el.find('.tm-static-detail');
    t.el.find('.tm-ficha-period').html('').prop('disabled', true);
    box.find('.tm-ficha-summary').text(fmtInt(x.rows) + ' linhas · carregando ' + tableLabel(x.n) + '…');
    box.find('[data-pane-body="ficha"], [data-pane-body="serie"]').html('<div class="tm-empty">Carregando ' + esc(tableLabel(x.n)) + '…</div>');
    getGz('data/fichas_x/' + f[F.family] + '/' + f[F.key] + '.json.gz').done(function (xd) {
      if (t.selected !== f || !t.ficha || t.ficha.data !== data) return;
      data.t.forEach(function (y, i) {
        if (!y.lazy) return;
        var z = (xd.t || []).filter(function (w) { return w.n === y.n; })[0];
        if (z) data.t[i] = z;
      });
      if (t.fichaIndex !== k) return;
      if (data.t[k].lazy) {
        box.find('[data-pane-body="ficha"], [data-pane-body="serie"]').html('<div class="tm-empty">' + esc(x.n) + ' não está no arquivo publicado deste fundo.</div>');
        return;
      }
      t.fichaTable(k);
    }).fail(function () {
      if (t.selected !== f || t.fichaIndex !== k) return;
      box.find('.tm-ficha-summary').text('');
      box.find('[data-pane-body="ficha"], [data-pane-body="serie"]').html('<div class="tm-empty">Não foi possível carregar ' + esc(x.n) +
        (typeof DecompressionStream === 'undefined' ? ': este navegador não descomprime arquivos gzip; atualize o navegador ou use o app local.' : '.') + '</div>');
    });
  }
  function citeText(c) { return 'CVM ' + c[1] + ', ' + c[2] + ', linha ' + c[3] + ', arquivo SHA-256 ' + c[4]; }
  // Explanatory note of a CVM field (fund_field_notes, meta.traits.notes): lines or null.
  function fieldNote(field) {
    var m = window.TM_FUNDS_META, n = m && m.traits && m.traits.notes;
    return n && n[field] ? n[field] : null;
  }
  function noteText(field) { var n = fieldNote(field); return n ? '\n\n' + n.join('\n') : ''; }
  function noteHtml(field, label) {
    var n = fieldNote(field);
    if (!n) return '';
    // Each paragraph opens with its period ("Até 2023 (ICVM 578/579):") in bold.
    return '<details class="tm-note"><summary>' + esc(n[0]) + '</summary><div class="tm-note-body">' +
      n.slice(1).map(function (l) {
        var m = /^([^:]{3,80}):\s+(.*)$/.exec(l);
        return m ? '<p><span class="tm-note-lead">' + esc(m[1]) + ':</span> ' + esc(m[2]) + '</p>' : '<p>' + esc(l) + '</p>';
      }).join('') + '</div></details>';
  }
  function fieldTip(x) { return x[0] + '\nCampo CVM: ' + x[1] + (x[2] ? ' (sem descrição no dicionário)' : '') + noteText(x[1]); }
  function fieldHead(x, tag, cls) {
    return '<' + tag + ' class="' + cls + (x[2] ? ' tm-derived' : '') + '" data-tip="' + esc(fieldTip(x)) + '">' + esc(x[0]) + '</' + tag + '>';
  }
  function valueText(v) { return v === '' || v == null ? '—' : v; }
  function plural(n, one, many) { return n === 1 ? one : fmtInt(n) + ' ' + many; }
  FundTab.prototype.fichaTable = function (k) {
    var t = this, box = t.el.find('.tm-static-detail'), x = t.ficha.data.t[k];
    t.fichaIndex = k;
    if (x.lazy) { loadExtraTable(t, k); return; }
    var periods = [];
    x.c.forEach(function (c) { if (periods.indexOf(c[0]) < 0) periods.push(c[0]); });
    t.el.find('.tm-ficha-period').html(periods.map(function (p) { return '<option>' + esc(p) + '</option>'; }).join(''))
      .prop('disabled', false);
    box.find('.tm-ficha-summary').text(fmtInt(x.c.length) + ' linhas em ' + fmtInt(periods.length) +
      ' períodos · valores originais da CVM, cada coluna cita o arquivo de origem');
    box.find('[data-pane-body="serie"]').html(seriesTable(x, t.ficha.urls));
    t.fichaPeriod(periods[0]);
  };
  FundTab.prototype.fichaPeriod = function (p) {
    var t = this, x = t.ficha.data.t[t.fichaIndex], urls = t.ficha.urls;
    var idx = [];
    x.c.forEach(function (c, i) { if (c[0] === p) idx.push(i); });
    var all = idx.length;
    idx = idx.slice(0, CARD_COLUMNS);
    var fields = x.f.filter(function (y) { return idx.some(function (i) { return y[4][i] !== ''; }); });
    var hidden = x.f.length - fields.length, html;
    function link(c) {
      var u = c[5] == null ? null : urls[c[5]];
      return u ? '<a href="' + esc(u) + '" target="_blank" rel="noopener">' + esc(citeText(c)) + '</a>' : esc(citeText(c));
    }
    if (idx.length === 1) {
      var i = idx[0];
      html = '<div class="tm-ficha-cite">Fonte: ' + link(x.c[i]) + '</div><div class="tm-ficha">' + fields.map(function (y) {
        return '<div class="tm-ficha-item">' + fieldHead(y, 'div', 'tm-ficha-label') + '<div class="tm-ficha-value' +
               (y[3].charAt(i) === '1' ? ' tm-num' : '') + '">' + esc(valueText(y[4][i])) + '</div></div>';
      }).join('') + '</div>';
    } else {
      html = '<table class="tm-card-table"><thead><tr><th class="tm-field">Campo</th>' +
        idx.map(function (i) { return '<th>' + link(x.c[i]) + '</th>'; }).join('') + '</tr></thead><tbody>' +
        fields.map(function (y) {
          return '<tr>' + fieldHead(y, 'th', 'tm-field') + idx.map(function (i) {
            return '<td' + (y[3].charAt(i) === '1' ? ' class="tm-num"' : '') + '>' + esc(valueText(y[4][i])) + '</td>';
          }).join('') + '</tr>';
        }).join('') + '</tbody></table>';
    }
    // Hidden = fields of the fund empty in this period (the file already
    // leaves out fields empty in every period, as the app does per period).
    var notes = [];
    if (all > CARD_COLUMNS) notes.push('Mostrando ' + CARD_COLUMNS + ' de ' + all + ' linhas deste período; veja todas em Série completa.');
    if (hidden > 0) notes.push(hidden === 1 ? '1 campo vazio neste período oculto.' : plural(hidden, '', 'campos vazios neste período ocultos.'));
    t.el.find('.tm-static-detail [data-pane-body="ficha"]').html(
      (notes.length ? '<div class="tm-caption">' + notes.join(' ') + '</div>' : '') + '<div class="tm-table-wrap">' + html + '</div>');
  };
  function seriesTable(x, urls) {
    var head = x.c.map(function (c) {
      var u = c[5] == null ? null : urls[c[5]], cite = esc(citeText(c));
      return '<th class="tm-col-period" title="' + cite + '">' +
             (u ? '<a href="' + esc(u) + '" target="_blank" rel="noopener">' + esc(c[0]) + '</a>' : esc(c[0])) + '</th>';
    }).join('');
    var body = x.f.map(function (y) {
      var cells = '';
      for (var i = 0; i < y[4].length; i++) {
        cells += '<td' + (y[3].charAt(i) === '1' ? ' class="tm-num"' : '') + '>' + esc(valueText(y[4][i])) + '</td>';
      }
      return '<tr>' + fieldHead(y, 'th', 'tm-field') + cells + '</tr>';
    }).join('');
    return '<div class="tm-caption">Períodos do mais recente ao mais antigo; passe o mouse no período para ver a citação da fonte.</div>' +
      '<table class="tm-wide tm-series"><thead><tr><th class="tm-field">Campo</th>' + head + '</tr></thead><tbody>' + body + '</tbody></table>';
  }
  // Characteristics under the detail title (same as fund_traits_ui in
  // prototype/fund_search_module.R): cotistas plus the fields of meta.traits.
  function traitsHtml(f, meta) {
    if (!meta) return '';
    var fam = f[F.family], cols = meta.columns[fam] || {}, tr = f[F.traits] || [];
    function item(label, text, tip, alert) {
      var muted = text === 'não informado' || text === 'não consta do informe';
      return '<span class="tm-trait' + (alert ? ' tm-trait-alert' : '') + '" data-tip="' + esc(tip) + '"><span class="tm-trait-label">' + esc(label) + '</span>' +
             '<span class="tm-trait-value' + (muted ? ' tm-muted' : '') + '">' + esc(text) + '</span></span>';
    }
    var out = [item('Cotistas', f[F.holdersLast] == null ? 'não informado' : fmtInt(f[F.holdersLast]),
                    f[F.holdersLast] == null ? 'Quantidade de cotistas não publicada nos informes.'
                      : 'Quantidade de cotistas · informe de ' + monthLabel(f[F.holdersMonth]))];
    meta.order.forEach(function (a, i) {
      if (a === 'family_link' && !cols[a]) return;
      var label = meta.labels[a], v = tr[i], text, tip;
      if (!cols[a]) { text = 'não consta do informe'; tip = 'O informe da CVM de ' + fam.toUpperCase() + ' não tem este campo.'; }
      else if (!v) { text = 'não informado'; tip = label + ' (' + cols[a] + ') · não preenchido nos informes'; }
      else { text = v[0] === 'S' ? 'sim' : v[0] === 'N' ? 'não' : String(v[0]).toLowerCase(); tip = label + ' (' + cols[a] + ') · informe de ' + v[1]; }
      if (cols[a]) tip += noteText(cols[a]);
      out.push(item(label, text, tip, a === 'investment_entity' && text === 'não'));
    });
    // Explanatory notes of the fields this family publishes.
    var notes = meta.order.map(function (a) { return cols[a] ? noteHtml(cols[a], meta.labels[a]) : ''; }).join('');
    return '<div class="tm-traits">' + out.join('') + '</div>' + notes;
  }
  function profile(f, s, color) {
    if (!s || f[F.pl] == null) return '<div class="tm-empty">Sem patrimônio publicado para este fundo.</div>';
    var months = s[1].map(function (_, i) { return addMonths(s[0], i); });
    var rank = f[F.rank] == null ? '—' : '#' + fmtInt(f[F.rank]) + ' de ' + fmtInt(f[F.peers]);
    var holders = s[2].some(function (v) { return v != null; });
    function kpi(label, value, note) {
      return '<div class="tm-kpi"><div class="tm-kpi-value">' + value + '</div><div class="tm-kpi-label">' + label + '</div>' +
             (note ? '<div class="tm-kpi-note">' + note + '</div>' : '') + '</div>';
    }
    return '<div class="tm-kpi-row tm-kpis-sm">' +
      kpi('Patrimônio líquido', fmtBRL(f[F.pl]), monthLabel(f[F.plMonth])) +
      kpi('Variação 12 meses', fmtPct(f[F.change]), 'mesmo mês, ano anterior') +
      kpi('Cotistas', fmtInt(f[F.holders])) +
      kpi('Posição entre ' + f[F.family].toUpperCase(), rank, f[F.pct] == null ? '' : 'maior que ' + fmtPct(f[F.pct], 0, false) + ' dos fundos') +
      // One chart: net assets on the left axis, quotaholders (dashed) on the right.
      '</div><div class="tm-profile-charts tm-one"><div><div class="tm-subhead tm-subhead-key"><span>' +
      (holders ? 'Patrimônio líquido e cotistas' : 'Patrimônio líquido') + '</span>' +
      (holders ? '<div class="tm-chart-key"><span class="tm-key-line" style="border-top-color:' + color + '"></span>Patrimônio líquido (eixo esquerdo)' +
        '<span class="tm-key-line tm-key-dash" style="border-top-color:#5b6573"></span>Cotistas (eixo direito)</div>' : '') + '</div>' +
      lineChart(months, s[1], {color: color, height: 240, width: 760,
        label: holders ? 'Patrimônio líquido (eixo esquerdo) e número de cotistas (eixo direito) do fundo' : 'Patrimônio líquido do fundo',
        values2: holders ? s[2] : null,
        tips: months.map(function (m, i) {
          return monthLabel(m) + '\n' + (s[1][i] == null ? 'sem informe' : 'PL ' + fmtBRL(s[1][i])) +
                 (s[2][i] == null ? '' : '\nCotistas ' + fmtInt(s[2][i]));
        })}) + '</div>' +
      '</div><div class="tm-caption">Valores do informe de cada período (versão mais recente). Meses sem informe ficam em branco.</div>';
  }
  function namesTable(names) {
    if (!names.length) return '<div class="tm-empty">Sem denominações no catálogo.</div>';
    return '<table class="tm-card-table tm-names-table"><thead><tr><th>Denominação publicada</th><th>Fonte</th><th>Primeira</th>' +
      '<th>Última</th><th class="tm-num">Informes</th></tr></thead><tbody>' + names.map(function (n) {
        return '<tr><td>' + esc(n[2]) + (n[7] ? ' <span class="tm-review" data-tip="Parecida com outra denominação; aguarda revisão humana.">revisão</span>' : '') +
               '</td><td>' + esc((n[3] || '').toUpperCase()) + '</td><td class="tm-mono">' + esc(n[4]) + '</td><td class="tm-mono">' + esc(n[5]) +
               '</td><td class="tm-num">' + fmtInt(n[6]) + '</td></tr>';
      }).join('') + '</tbody></table><div class="tm-caption">Datas de observação nos informes, não datas jurídicas da denominação.</div>';
  }

  // Build a tab the first time it is shown (the data file is loaded once).
  // ---- FICHA tab: Ficha and Série completa of any fund on the whole width
  // (same files and rendering as the fund detail; port of fund_record_ui). ----
  function RecordTab(el) { this.el = el; }
  RecordTab.prototype.fichaTable = FundTab.prototype.fichaTable;
  RecordTab.prototype.fichaPeriod = FundTab.prototype.fichaPeriod;
  RecordTab.prototype.render = function (d) {
    var t = this;
    t.d = d;
    t.funds = d.funds.slice().sort(function (a, b) { return (b[F.pl] || -1) - (a[F.pl] || -1); });
    t.el.html(
      '<div class="tm-dash-head"><div><span class="tm-eyebrow">Fase 1.3 · Ficha do fundo</span><h1>Ficha e série completa</h1></div>' +
      '<div class="tm-dash-meta">Valores originais dos informes da CVM; cada coluna cita o arquivo de origem · todas as tabelas do FIDC, as principais dos demais tipos</div></div>' +
      '<div class="tm-filterbar tm-record-filters"><div class="tm-record-search">' +
      '<input type="search" class="form-control form-control-sm tm-rq" placeholder="Fundo: CNPJ (com ou sem máscara) ou nome, de qualquer tipo">' +
      '<div class="tm-record-options" hidden></div></div>' +
      '<select class="form-select form-select-sm tm-ficha-table" disabled></select>' +
      '<select class="form-select form-select-sm tm-ficha-period" disabled></select></div>' +
      '<div class="card tm-section tm-detail tm-pane tm-record tm-static-detail"><div class="tm-empty">Escolha um fundo.</div></div>');
    var timer, opts = t.el.find('.tm-record-options');
    t.el.on('input focus', '.tm-rq', function () {
      var v = this.value; clearTimeout(timer);
      timer = setTimeout(function () { t.suggest(v); }, 120);
    });
    t.el.on('mousedown', '.tm-record-option', function (e) {
      e.preventDefault(); var g = t.funds[+$(this).attr('data-i')]; t.show(g); setCurrent(g); opts.attr('hidden', true);
    });
    t.el.on('blur', '.tm-rq', function () { setTimeout(function () { opts.attr('hidden', true); }, 150); });
    t.el.on('change', '.tm-ficha-table', function () { if (t.ficha) t.fichaTable(+this.value); });
    t.el.on('change', '.tm-ficha-period', function () { if (t.ficha) t.fichaPeriod(this.value); });
    t.el.on('click', '.tm-static-detail .nav-link', function (e) {
      e.preventDefault();
      var k = $(this).attr('data-pane'), box = $(this).closest('.tm-static-detail');
      box.find('.nav-link').removeClass('active'); $(this).addClass('active');
      box.find('[data-pane-body]').attr('hidden', true).filter('[data-pane-body="' + k + '"]').removeAttr('hidden');
    });
    t.el.data('tm-record', t);
    // Opens on the app's current fund, else the largest fund.
    t.show(findFund(d, window.tmCurrent) || t.funds[0]);
  };
  RecordTab.prototype.follow = function (key) {
    var t = this, g = t.d && findFund(t.d, key);
    if (g && t.selected !== g) t.show(g);
  };
  // Largest funds first; CNPJ digits match from the start, words anywhere.
  RecordTab.prototype.suggest = function (v) {
    var t = this, q = fold(v), words = q ? q.split(' ') : [], digits = (v || '').replace(/\D/g, ''), out = [];
    for (var i = 0; i < t.funds.length && out.length < 50; i++) {
      var f = t.funds[i];
      if (!words.length || (digits.length >= 4 && f[F.key].indexOf(digits) === 0) ||
          words.every(function (w) { return f.search.indexOf(w) >= 0; })) out.push(i);
    }
    t.el.find('.tm-record-options').html(out.length ? out.map(function (i) {
      var f = t.funds[i];
      return '<div class="tm-record-option" data-i="' + i + '"><span class="tm-tag tm-tag-' + f[F.family] + '">' + f[F.family].toUpperCase() +
             '</span> <span class="tm-mono">' + esc(f[F.cnpj]) + '</span> ' + esc(f[F.name]) + '<span class="tm-muted"> · ' + fmtBRL(f[F.pl]) + '</span></div>';
    }).join('') : '<div class="tm-empty">Nenhum fundo encontrado.</div>').removeAttr('hidden');
  };
  RecordTab.prototype.show = function (f) {
    var t = this, box = t.el.find('.tm-static-detail');
    if (!f) return;
    t.selected = f; t.ficha = null;
    t.el.find('.tm-rq').val(f[F.cnpj] + ' — ' + f[F.name]);
    t.el.find('.tm-ficha-table').html('<option>Carregando informes…</option>').prop('disabled', true);
    t.el.find('.tm-ficha-period').html('').prop('disabled', true);
    box.html(
      '<div class="card-header tm-detail-head"><div class="tm-eyebrow">' + f[F.family].toUpperCase() + ' · ' + esc(f[F.cnpj]) + '</div>' +
      '<h2 class="tm-detail-title">' + esc(f[F.name]) + '</h2></div>' +
      '<div class="tm-detail-body"><div class="tm-caption tm-ficha-summary"></div>' +
      '<ul class="nav nav-underline"><li class="nav-item"><a class="nav-link active" href="#" data-pane="ficha">Ficha</a></li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="serie">Série completa</a></li></ul>' +
      '<div class="tab-content"><div data-pane-body="ficha"><div class="tm-empty">Carregando ficha…</div></div>' +
      '<div data-pane-body="serie" class="tm-table-wrap" hidden><div class="tm-empty">Carregando série completa…</div></div></div></div>');
    loadFicha(f).done(function (fd, urls) {
      if (t.selected !== f) return;
      var sel = t.el.find('.tm-ficha-table');
      if (!fd || !fd.t.length) {
        sel.html('<option>Sem informes nas tabelas publicadas</option>');
        box.find('[data-pane-body="ficha"], [data-pane-body="serie"]').html(
          '<div class="tm-empty">Sem linhas nas tabelas principais para este fundo. As demais tabelas estão no app local.</div>');
        return;
      }
      t.ficha = {data: fd, urls: urls};
      sel.html(tableOptions(fd)).prop('disabled', false);
      var best = latestTable(fd); sel.val(String(best)); t.fichaTable(best);
    });
  };

  function activate(el) {
    if (el.data('tm-ready')) return;
    el.data('tm-ready', true);
    var record = el.hasClass('tm-static-record');
    loadFunds().done(function (d) { if (record) new RecordTab(el).render(d); else new FundTab(el).render(d); })
      .fail(function () { el.html('<div class="tm-empty">Não foi possível carregar a lista de fundos.</div>'); });
  }
  // Current fund ("family|CNPJ digits", prototype/charts.R): the last fund the
  // user selected in any tab; every tab shows it when opened.
  function fundKey(g) { return g[F.family] + '|' + g[F.key]; }
  function findFund(d, key) {
    if (!key) return null;
    var k = String(key).split('|');
    for (var i = 0; i < d.funds.length; i++) if (d.funds[i][F.family] === k[0] && d.funds[i][F.key] === k[1]) return d.funds[i];
    return null;
  }
  function setCurrent(g) { if (g && window.tmSetCurrent) window.tmSetCurrent(fundKey(g)); }
  function followAdmin(pane, key) {
    if (!key) return;
    var row = pane.find('[data-detail] .tm-fund-pick').filter(function () { return $(this).attr('data-fund-key') === key; }).first();
    if (!row.length) return;
    var panel = row.closest('[data-detail]').attr('data-detail');
    var pick = pane.find('.tm-pick[data-key]').filter(function () { return $(this).attr('data-key') === panel; }).first();
    if (pick.length && !pick.hasClass('tm-selected')) pick.trigger('click');
    if (pick[0]) pick[0].scrollIntoView({block: 'nearest'});
    row.closest('.tm-bars').find('.tm-selected').removeClass('tm-selected');
    row.addClass('tm-selected');
  }
  function paneOf(link) { return link ? $($(link).attr('data-bs-target') || $(link).attr('href')) : $(); }
  $(document).on('shown.bs.tab', function (e) {
    var pane = paneOf(e.target), key = window.tmCurrent;
    pane.find('.tm-static-funds, .tm-static-record').filter(function () { return window.tmPaneVisible(this); }).each(function () {
      var el = $(this), t = el.data('tm-tab') || el.data('tm-record');
      if (t) t.follow(key); else activate(el);
    });
    followAdmin(pane, key);
  });
  $(function () { $('.tm-static-funds, .tm-static-record').filter(function () { return window.tmPaneVisible(this); }).each(function () { activate($(this)); }); });
  // Double click on a fund in the Panorama: open its family tab filtered by
  // its CNPJ (applied when the tab is built, if it is not built yet).
  $(document).on('tm:open-fund', function (e, f) {
    var fam = String(f.family).toLowerCase(), el = $('.tm-static-funds[data-family="' + fam + '"]');
    var link = window.tmFamilyTab(fam);
    if (!el.length) return;
    var tab = el.data('tm-tab');
    if (tab && tab.d) tab.open(f.cnpj); else el.data('tm-open', f.cnpj);
    window.tmShowTab(link);
  });
})(jQuery);
