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
  // A fund picked in the list is drawn on the administrator's chart (same axis,
  // family colour), from its values in the administrator's month file
  // (admin_chart_ui in the app).
  $(document).on('click', '.tm-admin-body .tm-fund-pick[data-fund-key]', function () {
    var body = $(this).closest('.tm-admin-body'), file = body.attr('data-admin-file'), key = $(this).attr('data-fund-key');
    var svg = body.find('svg.tm-chart-pick').get(0);
    if (!file || !svg || !svg.getAttribute('data-geom')) return;
    getJSON(file).done(function (a) {
      var g = svg.getAttribute('data-geom').split(',').map(Number), x0 = g[0], x1 = g[1], ml = g[2], pw = g[3], mt = g[4], ph = g[5], ymax = g[6];
      var fi = -1;
      a.funds.forEach(function (f, i) { if (fi < 0 && f[1] + '|' + String(f[2]).replace(/\D/g, '') === key) fi = i; });
      $(svg).find('.tm-part').remove();
      body.find('.tm-part-key').remove();
      if (fi < 0) return;
      var color = ((window.TM_FUNDS_META || {}).colors || FAMILY_COLORS)[a.funds[fi][1]] || '#e07b39';
      var pts = [], segs = [], cur = [];
      a.months.forEach(function (m, i) {
        var r = (a.rows[i] || []).filter(function (z) { return z[0] === fi; })[0];
        var d = Date.UTC(+m.slice(0, 4), +m.slice(5, 7) - 1, 1) / 864e5;
        if (!r || r[1] == null) { if (cur.length) segs.push(cur); cur = []; return; }
        var p = [ml + (d - x0) / (x1 - x0) * pw, mt + ph - Math.max(r[1], 0) / ymax * ph];
        cur.push(p); pts.push(p);
      });
      if (cur.length) segs.push(cur);
      if (!pts.length) return;
      var ns = 'http://www.w3.org/2000/svg', base = mt + ph, hit = $(svg).find('.tm-hit').first().get(0);
      segs.forEach(function (s) {
        var line = s.map(function (p) { return p[0].toFixed(1) + ',' + p[1].toFixed(1); }).join(' L');
        var area = document.createElementNS(ns, 'path');
        area.setAttribute('class', 'tm-area tm-area-part tm-part'); area.setAttribute('fill', color);
        area.setAttribute('d', 'M' + s[0][0].toFixed(1) + ',' + base + ' L' + line + ' L' + s[s.length - 1][0].toFixed(1) + ',' + base + ' Z');
        var path = document.createElementNS(ns, 'path');
        path.setAttribute('class', 'tm-line tm-line-part tm-part'); path.setAttribute('stroke', color); path.setAttribute('d', 'M' + line);
        svg.insertBefore(area, hit); svg.insertBefore(path, hit);
      });
      body.find('.tm-admin-chart .tm-subhead').first().append('<span class="tm-chart-key tm-part-key"><span class="tm-key-line" style="border-top-color:#0b1f3a"></span>Administrador' +
        '<span class="tm-key-line" style="border-top-color:' + color + '"></span>' + esc(a.funds[fi][0]) + '</span>');
    });
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

  // ---- Characteristics (meta.traits, written by static_traits_meta in
  // prototype/static_funds.R; same rules as src/intelligence/search_fund_reports.R) ----
  function famHas(m, a, fam) { return !!(m.columns[fam] || {})[a]; }
  // Shown in the Ficha and the filters: the core fields always, the others
  // when a family in scope publishes them (fund_display_attributes).
  function displayAttrs(m, fams) {
    return m.order.filter(function (a) { return m.core.indexOf(a) >= 0 || fams.some(function (f) { return famHas(m, a, f); }); });
  }
  // List columns: fields published by a family in scope (fund_scope_attributes).
  function scopeAttrs(m, fams) {
    return m.order.filter(function (a) { return fams.some(function (f) { return famHas(m, a, f); }); });
  }
  function traitOf(m, f, a) { var v = (f[F.traits] || [])[m.order.indexOf(a)]; return v || null; }
  function valueParts(v) { return String(v).split(' / '); }
  function traitText(m, a, v) {
    var seen = {}, out = [];
    valueParts(v).forEach(function (p) { var t = ((m.values[a] || {})[p] || [null, p])[1]; if (!seen[t]) { seen[t] = 1; out.push(t); } });
    return out.join(' / ');
  }
  function valueKeys(m, a, v) { return valueParts(v).map(function (p) { return ((m.values[a] || {})[p] || [fold(p)])[0]; }); }
  function isAlert(m, a, v) { return !!m.alert[a] && v != null && valueParts(v).indexOf(m.alert[a]) >= 0; }
  function isNumeric(m, a) { return m.numeric.indexOf(a) >= 0; }
  function numberParts(v) { return valueParts(v).map(Number).filter(function (n) { return !isNaN(n); }); }
  // Filter options of one field for the families in scope: published values
  // (most frequent first), "Não informado" and "Não consta do informe".
  function attrOptions(d, m, a, fams) {
    var count = {}, text = {};
    d.funds.forEach(function (f) {
      if (fams.indexOf(f[F.family]) < 0) return;
      var v = traitOf(m, f, a); if (!v) return;
      valueParts(v[0]).forEach(function (p) {
        var x = (m.values[a] || {})[p] || [fold(p), p, p];
        count[x[0]] = (count[x[0]] || 0) + 1; text[x[0]] = x[2];
      });
    });
    var keys = Object.keys(count).sort(function (x, y) { return count[y] - count[x] || (x < y ? -1 : 1); });
    var some = fams.some(function (f) { return famHas(m, a, f); }), all = fams.every(function (f) { return famHas(m, a, f); });
    return '<option value="">Todos</option>' + keys.map(function (k) { return '<option value="' + esc(k) + '">' + esc(text[k]) + '</option>'; }).join('') +
      (some ? '<option value="NA">Não informado</option>' : '') + (all ? '' : '<option value="NC">Não consta do informe</option>');
  }
  function attrTip(m, a, fams) {
    var cols = fams.filter(function (f) { return famHas(m, a, f); }).map(function (f) { return f.toUpperCase() + ' ' + m.columns[f][a]; });
    if (!cols.length) return m.labels[a] + ': o informe da CVM de ' + fams.join(', ').toUpperCase() + ' não tem este campo.';
    var first = fams.filter(function (f) { return famHas(m, a, f); })[0];
    return m.labels[a] + ' (' + cols.join('; ') + '), último informe que o preencheu. Com um valor escolhido, ficam só os fundos das ' +
      'famílias cujo informe tem o campo; "Não consta do informe" seleciona os das demais famílias.' + noteText(m.columns[first][a]);
  }
  // Hint of a characteristic (window.TM_INFO, fund_hint_tip_text in R) as text
  // appended to its hover tooltip, like the note of Entidade de investimento.
  function hintText(a) {
    var h = window.TM_INFO && window.TM_INFO[a], l = [];
    if (!h || !h.sections) return '';
    h.sections.forEach(function (s) { s[1].forEach(function (p, i) { l.push(i ? p : s[0] + ': ' + p); }); });
    return '\n\n' + h.title + '\n' + l.join('\n');
  }
  // Informative notice when one class has both special rights (fund_joint_ui in R).
  function jointHtml(j) {
    var h = window.TM_INFO && window.TM_INFO.joint;
    if (!h || !j) return '';
    var n = +j[0];
    return '<div class="tm-joint" role="note"><div class="tm-joint-title">' + esc(h.title) + '</div><p>' + esc(h.text) + '</p>' +
      '<p class="tm-joint-src">Fonte: informe FIP de ' + esc(j[1]) + ', ' + (n === 1 ? '1 linha' : fmtInt(n) + ' linhas') +
      ' com DIREITO_POLIT_CLASSE = S e DIREITO_ECON_CLASSE = S na mesma linha (mesma classe e competência). ' +
      'Aviso informativo: não altera destaques nem a classificação de entidade de investimento.</p></div>';
  }
  // Collapsible panel (same markup as fund_attribute_filters_ui in the app).
  function attrPanel(d, fams) {
    var m = d.meta.traits;
    function field(label, tip, inner, info) {
      return '<div class="tm-cf" data-tip="' + esc(tip) + '"><label class="tm-cf-label">' + esc(label) + (info || '') + '</label>' + inner + '</div>';
    }
    function range(id, label, tip, step, unit) {
      return field(label, tip, '<div class="tm-cf-range"><input type="number" min="0" step="' + step + '" class="form-control tm-cf-num" data-range="' +
        id + '" data-bound="min"><span class="tm-cf-sep">a</span><input type="number" min="0" step="' + step +
        '" class="form-control tm-cf-num" data-range="' + id + '" data-bound="max">' + (unit ? '<span class="tm-cf-sep">' + unit + '</span>' : '') + '</div>');
    }
    var sel = displayAttrs(m, fams).filter(function (a) { return !isNumeric(m, a); }).map(function (a) {
      return field(m.medium[a], attrTip(m, a, fams) + hintText(a), '<select class="form-select tm-cf-attr" data-attr="' + a + '">' + attrOptions(d, m, a, fams) + '</select>');
    }).join('');
    return '<details class="tm-cf-panel"><summary class="tm-cf-summary"><span class="tm-cf-title">Características</span>' +
      '<span class="tm-cf-active"></span><span class="tm-cf-hint">cotistas, condomínio, público-alvo, direitos e outras; clique para abrir</span></summary>' +
      '<div class="tm-cf-grid">' + range('holders', 'Cotistas', 'Quantidade de cotistas no último informe que a publicou (mínimo e máximo).', 1) + sel +
      (scopeAttrs(m, fams).indexOf('subscribed_pct') >= 0 ? range('subscribed', 'Cotas subscritas',
        'Percentual total das cotas subscritas (FIP, PR_TOTAL_COTA_SUBSCR), mínimo e máximo; com várias classes, basta uma no intervalo.', 0.01, '%') : '') +
      '<div class="tm-cf-actions"><a href="#" class="tm-link tm-cf-clear">Limpar características</a></div></div></details>';
  }
  // Active characteristic filters of a tab: {attr: key}, {holders: [min, max]}, ...
  function attrFilters(el) {
    var out = {attrs: {}, ranges: {}, n: 0};
    el.find('.tm-cf-attr').each(function () { var v = $(this).val(); if (v) { out.attrs[$(this).attr('data-attr')] = v; out.n++; } });
    el.find('.tm-cf-num').each(function () {
      var v = this.value === '' ? null : Number(this.value), id = $(this).attr('data-range');
      if (v == null || isNaN(v)) return;
      var r = out.ranges[id] = out.ranges[id] || [null, null];
      r[$(this).attr('data-bound') === 'min' ? 0 : 1] = v;
    });
    out.n += Object.keys(out.ranges).length;
    return out;
  }
  function attrPass(m, f, flt) {
    for (var a in flt.attrs) {
      var want = flt.attrs[a], has = famHas(m, a, f[F.family]), v = traitOf(m, f, a);
      if (want === 'NC') { if (has) return false; continue; }
      if (!has) return false;
      if (want === 'NA') { if (v) return false; continue; }
      if (!v || valueKeys(m, a, v[0]).indexOf(want) < 0) return false;
    }
    var h = flt.ranges.holders;
    if (h && (f[F.holdersLast] == null || (h[0] != null && f[F.holdersLast] < h[0]) || (h[1] != null && f[F.holdersLast] > h[1]))) return false;
    var s = flt.ranges.subscribed;
    if (s) {
      if (!famHas(m, 'subscribed_pct', f[F.family])) return false;
      var sv = traitOf(m, f, 'subscribed_pct');
      if (!sv || !numberParts(sv[0]).some(function (n) { return (s[0] == null || n >= s[0]) && (s[1] == null || n <= s[1]); })) return false;
    }
    return true;
  }

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
      '<button type="button" class="btn btn-link btn-sm tm-filter-clear">Limpar</button></div>' + attrPanel(d, t.families) +
      '<div class="tm-master-detail tm-static-grid">' +
      '<div class="card tm-section tm-pane"><div class="card-header tm-card-head"><span class="tm-count"></span>' +
      '<span class="tm-head-note">clique em um fundo</span></div><div class="card-body tm-scroll tm-list"></div>' +
      '<div class="tm-pager"></div></div>' +
      '<div class="tm-pane-wrap"><div class="card tm-section tm-detail tm-pane tm-static-detail"><div class="tm-empty">Selecione um fundo na lista.</div></div></div></div>');
    var timer;
    t.el.on('input', '.tm-q, .tm-qa', function () { clearTimeout(timer); timer = setTimeout(function () { t.reset(); }, 180); });
    t.el.on('change', '.tm-filter-family input, .tm-cf-attr', function () { t.reset(); });
    t.el.on('input', '.tm-cf-num', function () { clearTimeout(timer); timer = setTimeout(function () { t.reset(); }, 300); });
    t.el.on('click', '.tm-cf-clear', function (e) { e.preventDefault(); t.el.find('.tm-cf-attr, .tm-cf-num').val(''); t.reset(); });
    t.el.on('click', '.tm-filter-clear', function () {
      t.el.find('.tm-q, .tm-qa, .tm-cf-attr, .tm-cf-num').val(''); t.el.find('.tm-filter-family input').prop('checked', true); t.reset();
    });
    t.el.on('click', 'th[data-sort]', function (e) {
      if ($(e.target).closest('.tm-info').length) return;
      var by = $(this).attr('data-sort'), s = (t.columns || SORTS).filter(function (x) { return x.by === by; })[0];
      if (!s) return;
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
    var m = d.meta.traits, flt = attrFilters(t.el);
    t.el.find('.tm-cf-active').html(flt.n ? '<span class="tm-cf-count">' + flt.n + (flt.n === 1 ? ' filtro ativo' : ' filtros ativos') + '</span>' : '');
    // List columns: the fixed ones, Cotistas and the characteristics of the checked families.
    var attrs = scopeAttrs(m, fams);
    t.columns = SORTS.concat([{by: 'holders', label: 'Cotistas', dec: true, num: true,
                               tip: 'Quantidade de cotistas no último informe que a publicou'}]).concat(attrs.map(function (a) {
      return {by: 'attr_' + a, attr: a, label: m.short[a], dec: isNumeric(m, a), num: isNumeric(m, a),
              tip: m.labels[a] + ', último informe que o preencheu. Em branco: o informe da família não tem o campo; —: não preenchido'};
    }));
    var key = [fams.join(','), q, qd, qa, qad, JSON.stringify(flt), s.by, s.dec].join('|');
    var rows = t.rowsKey === key ? t.rows : null;
    if (!rows) {
      rows = d.funds.filter(function (f) {
        if (fams.indexOf(f[F.family]) < 0) return false;
        if (flt.n && !attrPass(m, f, flt)) return false;
        if (words.length && !(qd.length >= 4 && f[F.key].indexOf(qd) === 0) &&
            !words.every(function (w) { return f.search.indexOf(w) >= 0; })) return false;
        if (awords.length && !(qad.length >= 4 && f.adminDigits.indexOf(qad) === 0) &&
            !awords.every(function (w) { return f.adminKey.indexOf(w) >= 0; })) return false;
        return true;
      });
      var col = s.by === 'name' ? 'nameKey' : s.by === 'period' ? F.last : s.by === 'count' ? F.count : s.by === 'share' ? F.share :
                s.by === 'holders' ? F.holdersLast : F.pl;
      // Characteristic columns: the number (percent) or the key of the first part; empty last.
      var sa = s.by.indexOf('attr_') === 0 ? s.by.slice(5) : null;
      function sortValue(f) {
        if (!sa) return f[col];
        var v = traitOf(m, f, sa); if (!v) return null;
        return isNumeric(m, sa) ? numberParts(v[0])[0] : valueKeys(m, sa, v[0])[0];
      }
      rows.sort(function (a, b) {
        var x = sortValue(a), y = sortValue(b);
        if (x == null && y == null) return 0; if (x == null) return 1; if (y == null) return -1;
        return (x < y ? -1 : x > y ? 1 : 0) * dir;
      });
      t.rows = rows; t.rowsKey = key;
    }
    var pages = Math.max(1, Math.ceil(rows.length / PAGE)); t.page = Math.min(Math.max(0, t.page), pages - 1);
    var slice = rows.slice(t.page * PAGE, (t.page + 1) * PAGE);
    var head = t.columns.map(function (c) {
      var on = s.by === c.by;
      return '<th class="tm-sortable' + (on ? ' tm-sorted' : '') + (c.num ? ' tm-num' : '') + '" data-sort="' + c.by +
             '" title="' + esc((c.tip || 'Clique para ordenar; de novo para inverter') + (c.attr ? hintText(c.attr) : '')) + '">' + c.label + (on ? (s.dec ? ' ▼' : ' ▲') : '') + '</th>';
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
             fmtShare(f[F.share]) + '</td><td class="tm-num" data-tip="' + (f[F.holdersMonth] ? 'Cotistas em ' + monthLabel(f[F.holdersMonth]) : '') + '">' +
             fmtInt(f[F.holdersLast]) + '</td>' + attrs.map(function (a) {
               if (!famHas(m, a, f[F.family])) return '<td class="tm-attr tm-muted" data-tip="O informe de ' + f[F.family].toUpperCase() + ' não tem este campo."></td>';
               var v = traitOf(m, f, a);
               if (!v) return '<td class="tm-attr tm-muted' + (isNumeric(m, a) ? ' tm-num' : '') + '">—</td>';
               return '<td class="tm-attr' + (isNumeric(m, a) ? ' tm-num' : '') + (isAlert(m, a, v[0]) ? ' tm-attr-alert' : '') +
                      '" data-tip="Informe de ' + esc(v[1]) + '">' + esc(traitText(m, a, v[0])) + '</td>';
             }).join('') + '</tr>';
    }).join('');
    t.el.find('.tm-list').html(rows.length ? '<table class="tm-results tm-results-wide"><thead><tr>' + head + '</tr></thead><tbody>' + body + '</tbody></table>'
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
      '<div class="card-header tm-detail-head"><div class="tm-detail-top"><div class="tm-detail-id"><div class="tm-eyebrow">' + f[F.family].toUpperCase() + ' · ' + esc(f[F.cnpj]) + '</div>' +
      '<h2 class="tm-detail-title">' + esc(f[F.name]) + '</h2><div class="tm-detail-meta"><span><strong>Administrador: </strong>' +
      esc(f[F.admin] || 'não publicado') + (f[F.adminCnpj] ? ' · ' + esc(f[F.adminCnpj]) : '') + '</span><span><strong>Informes: </strong>' +
      fmtInt(f[F.count]) + ' (' + esc(f[F.first]) + ' a ' + esc(f[F.last]) + ')</span>' +
      '</div>' + traitsHtml(f, d.meta.traits) + '</div><div class="tm-ret-slot"></div></div></div>' +
      '<div class="tm-detail-body"><div class="tm-static-tools"><select class="form-select form-select-sm tm-ficha-table" disabled>' +
      '<option>Carregando informes…</option></select><select class="form-select form-select-sm tm-ficha-period" disabled></select></div>' +
      '<div class="tm-caption tm-ficha-summary"></div>' +
      '<ul class="nav nav-underline"><li class="nav-item"><a class="nav-link active" href="#" data-pane="perfil">Perfil</a></li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="ficha">Ficha</a></li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="serie">Série completa</a></li>' +
      '<li class="nav-item tm-dist-tab"><a class="nav-link" href="#" data-pane="dist">Distribuições</a>' + modeBar('rel') + '</li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="nomes">Denominações (' + names.length + ')</a></li></ul>' +
      '<div class="tab-content"><div data-pane-body="perfil"><div class="tm-perfil-main"><div class="tm-empty">Carregando série…</div></div></div>' +
      '<div data-pane-body="ficha" hidden><div class="tm-empty">Carregando ficha…</div></div>' +
      '<div data-pane-body="serie" class="tm-table-wrap" hidden><div class="tm-empty">Carregando série completa…</div></div>' +
      '<div data-pane-body="dist" class="tm-table-wrap" hidden><div class="tm-empty">Carregando distribuições…</div></div>' +
      '<div data-pane-body="nomes" hidden>' + namesTable(names) + '</div></div></div>');
    var key = f[F.key];
    loadFicha(f).done(function (fd, urls) {
      if (t.selected !== f) return;
      t.ficha = {data: fd, urls: urls};
      // Monthly return on a normal curve (fund_return_ui, rendered at export).
      if (fd && fd.r) box.find('.tm-ret-slot').html(fd.r);
      if (fd && fd.j) box.find('.tm-joint-slot').html(jointHtml(fd.j));
      var sel = box.find('.tm-ficha-table');
      if (!fd || !fd.t.length) {
        sel.html('<option>Sem informes nas tabelas publicadas</option>');
        box.find('[data-pane-body="ficha"], [data-pane-body="serie"], [data-pane-body="dist"]').html(
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
      box.find('[data-pane-body="perfil"] .tm-perfil-main').html(profile(f, s[key], color));
    }).fail(function () {
      box.find('[data-pane-body="perfil"] .tm-perfil-main').html('<div class="tm-empty">Não foi possível carregar a série deste fundo.</div>');
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
    box.find('[data-pane-body="ficha"], [data-pane-body="serie"], [data-pane-body="dist"]').html('<div class="tm-empty">Carregando ' + esc(tableLabel(x.n)) + '…</div>');
    getGz('data/fichas_x/' + f[F.family] + '/' + f[F.key] + '.json.gz').done(function (xd) {
      if (t.selected !== f || !t.ficha || t.ficha.data !== data) return;
      data.t.forEach(function (y, i) {
        if (!y.lazy) return;
        var z = (xd.t || []).filter(function (w) { return w.n === y.n; })[0];
        if (z) data.t[i] = z;
      });
      if (t.fichaIndex !== k) return;
      if (data.t[k].lazy) {
        box.find('[data-pane-body="ficha"], [data-pane-body="serie"], [data-pane-body="dist"]').html('<div class="tm-empty">' + esc(x.n) + ' não está no arquivo publicado deste fundo.</div>');
        return;
      }
      t.fichaTable(k);
    }).fail(function () {
      if (t.selected !== f || t.fichaIndex !== k) return;
      box.find('.tm-ficha-summary').text('');
      box.find('[data-pane-body="ficha"], [data-pane-body="serie"], [data-pane-body="dist"]').html('<div class="tm-empty">Não foi possível carregar ' + esc(x.n) +
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
    t.distPeriod(p);
  };
  // ---- Distribuições: one normal curve per numeric field of the table (same
  // rules as fund_field_distributions and fund_distribution_svg in R) ----
  var MIN_VALUES = 6;
  function parseShown(s) {
    if (s == null || s === '') return null;
    var n = Number(String(s).replace(/\./g, '').replace(',', '.'));
    return isNaN(n) ? null : n;
  }
  function compact(v) {
    if (v == null || isNaN(v)) return '—';
    var a = Math.abs(v), s = v < 0 ? '-' : '';
    if (a >= 1e9) return s + num(a / 1e9, 1) + ' bi';
    if (a >= 1e6) return s + num(a / 1e6, 1) + ' mi';
    if (a >= 1e4) return s + num(a / 1e3, 1) + ' mil';
    if (a >= 100) return s + num(a, 0);
    return s + num(a, a >= 1 || a === 0 ? 2 : 4);
  }
  function distribution(values, periods) {
    var n = values.length;
    if (n < MIN_VALUES) return null;
    var mean = values.reduce(function (s, v) { return s + v; }, 0) / n;
    var sd = Math.sqrt(values.reduce(function (s, v) { return s + (v - mean) * (v - mean); }, 0) / (n - 1));
    var min = Math.min.apply(null, values), max = Math.max.apply(null, values);
    var lo = Math.max(min, mean - 4 * sd), hi = Math.min(max, mean + 4 * sd);
    if (!isFinite(sd) || sd === 0 || hi <= lo) { lo = mean - 1; hi = mean + 1; }
    var bins = Math.min(16, Math.max(6, Math.ceil(Math.sqrt(n)))), bw = (hi - lo) / bins, counts = [], outside = 0, i;
    for (i = 0; i < bins; i++) counts.push(0);
    values.forEach(function (v) {
      if (v < lo || v > hi) { outside++; return; }
      counts[Math.min(bins - 1, Math.max(0, Math.ceil((v - lo) / bw) - 1))]++;
    });
    var last = 0, first = periods[0];
    periods.forEach(function (p, k) { if (p > periods[last]) last = k; if (p < first) first = p; });
    return {n: n, mean: mean, sd: isFinite(sd) ? sd : 0, min: min, max: max, lo: lo, hi: hi, counts: counts, outside: outside,
            last: values[last], lastPeriod: periods[last], firstPeriod: first};
  }
  // Display scale (fund_display_scale in R): null = linear; c = asinh(v / c).
  function scaleFwd(v, c) { return c == null ? v : Math.asinh(v / c); }
  function scaleInv(t, c) { return c == null ? t : Math.sinh(t) * c; }
  function scaleNote(c, centre, fmt) {
    return c == null ? '' : '\nEscala logarítmica (asinh) só para exibição, para comparar valores de ordens de grandeza diferentes: o eixo e este ' +
      'texto mostram valores originais; o tracejado marca o centro da curva nessa escala (' + (fmt || compact)(centre) + '), que não é a média.';
  }
  // lo, hi, counts, dmean and dsd are on the display scale (d.scale); the
  // marked value and the axis labels are original values.
  // Secondary axis of robust z (fund_z_ticks in R): z is linear on the display
  // scale; ticks every 1, 2, 5, 10... z, at least 16 px apart.
  function zTicks(lo, hi, zmed, rs, pw) {
    if (rs == null || zmed == null || !(rs > 0) || !(hi > lo)) return null;
    var px = pw * rs / (hi - lo), step = 0, m, k, ks = [1, 2, 5], z = [];
    for (m = 1; m <= 1e8 && !step; m *= 10) for (k = 0; k < 3; k++) if (ks[k] * m * px >= 16) { step = ks[k] * m; break; }
    if (!step) return null;
    for (var i = Math.ceil((lo - zmed) / rs / step); i <= Math.floor((hi - zmed) / rs / step); i++) z.push(i * step);
    return z.length ? z.map(function (v) { return [v, zmed + v * rs]; }) : null;
  }
  // How the robust z is computed (fund_z_explain in R).
  var Z_EXPLAIN = 'Régua superior: z robusto (0 = mediana dos fundos). Cálculo: z = (valor do fundo − mediana dos fundos) ÷ desvio robusto, ' +
    'ambos na escala do gráfico (asinh quando a escala é log) e sobre os valores originais, sem winsorização. Desvio robusto = MAD ' +
    'escalonado (1,4826 × mediana dos desvios absolutos em relação à mediana); se o MAD for zero (maioria dos fundos com o mesmo valor), ' +
    '1,2533 × desvio absoluto médio; se ainda for zero, o desvio-padrão. Nas participações, o desvio robusto mínimo é de 1 ponto ' +
    'percentual. |z| de 2 a 3,5 = atípico; 3,5 ou mais = extremo (Iglewicz e Hoaglin, 1993).';
  function zLabel(z) { return z > 0 ? '+' + fmtInt(z) : z < 0 ? '\u2212' + fmtInt(-z) : '0'; }
  function distSvg(d, w, h, label, fmt) {
    var zt = zTicks(d.lo, d.hi, d.zmed, d.rs, w - 8);
    var ml = 4, mr = 4, mt = zt ? 13 : 6, mb = 16, pw = w - ml - mr, ph = h - mt - mb, k = d.counts.length, bw = (d.hi - d.lo) / k;
    var sc = d.scale == null ? null : d.scale, dm = d.dmean == null ? d.mean : d.dmean, ds = d.dsd == null ? d.sd : d.dsd;
    function sx(v) { return ml + (v - d.lo) / (d.hi - d.lo) * pw; }
    function dens(v) { return ds > 0 ? Math.exp(-0.5 * Math.pow((v - dm) / ds, 2)) / (ds * Math.sqrt(2 * Math.PI)) * d.n * bw : 0; }
    var xs = [], i; for (i = 0; i < 60; i++) xs.push(d.lo + (d.hi - d.lo) * i / 59);
    var top = Math.max.apply(null, d.counts.concat(xs.map(dens)).concat([1]));
    function sy(v) { return mt + ph - v / top * ph; }
    function f(v) { return v.toFixed(1); }
    var bars = d.counts.map(function (c, j) {
      if (!c) return '';
      var x0 = sx(d.lo + j * bw) + 0.6, x1 = sx(d.lo + (j + 1) * bw) - 0.6;
      return '<rect class="tm-rd-bar" x="' + f(x0) + '" y="' + f(sy(c)) + '" width="' + f(Math.max(0.8, x1 - x0)) + '" height="' + f(mt + ph - sy(c)) + '" rx="1.5"/>';
    }).join('');
    var curve = ds > 0 ? '<path class="tm-rd-curve" d="M' + xs.map(function (v) { return f(sx(v)) + ',' + f(sy(dens(v))); }).join(' L') + '"/>' : '';
    // A marked value outside the scale shows as a dot on the nearest edge.
    var lt = d.last == null ? null : scaleFwd(d.last, sc);
    var mx = f(sx(dm)), last = lt == null ? '' : lt >= d.lo && lt <= d.hi ? '<line class="tm-rd-last" x1="' + f(sx(lt)) + '" x2="' + f(sx(lt)) +
      '" y1="' + mt + '" y2="' + (mt + ph) + '"/><circle class="tm-rd-dot" cx="' + f(sx(lt)) + '" cy="' + (mt + 3) + '" r="3"/>' :
      '<circle class="tm-rd-dot" cx="' + f(lt < d.lo ? ml + 3 : w - mr - 3) + '" cy="' + (mt + ph - 3) + '" r="3"/>';
    // The mean label is dropped when it would run into the edge labels.
    var room = Math.min(sx(dm) - ml, w - mr - sx(dm)) >= 0.22 * pw;
    var ticks = [[ml, d.lo, 'start']].concat(room ? [[mx, dm, 'middle']] : []).concat([[w - mr, d.hi, 'end']]).map(function (t) {
      return '<text class="tm-rd-tick" x="' + t[0] + '" y="' + (h - 4) + '" text-anchor="' + t[2] + '">' + esc((fmt || compact)(scaleInv(t[1], sc))) + '</text>';
    }).join('') + (sc == null ? '' : '<text class="tm-rd-tick tm-rd-log" x="' + (w - mr) + '" y="' + (mt + 6) + '" text-anchor="end">escala log</text>');
    // Secondary axis on top: robust z of the peers (0 = median of the funds).
    if (zt) ticks += '<g class="tm-rd-z"><line class="tm-rd-zaxis" x1="' + ml + '" x2="' + (w - mr) + '" y1="' + (mt - 2) + '" y2="' + (mt - 2) + '"/>' +
      zt.map(function (t) {
        var x = sx(t[1]), a = x - ml < 6 ? 'start' : w - mr - x < 6 ? 'end' : 'middle';
        return '<line class="tm-rd-ztick' + (t[0] === 0 ? ' tm-rd-z0' : '') + '" x1="' + f(x) + '" x2="' + f(x) + '" y1="' + (mt - 4) + '" y2="' + mt + '"/>' +
          '<text class="tm-rd-zlab" x="' + f(x) + '" y="' + (mt - 5) + '" text-anchor="' + a + '">' + zLabel(t[0]) + '</text>';
      }).join('') + '</g>';
    return '<svg class="tm-rd-svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" role="img" aria-label="' + esc(label) + '">' +
      '<line class="tm-rd-axis" x1="' + ml + '" x2="' + (w - mr) + '" y1="' + (mt + ph) + '" y2="' + (mt + ph) + '"/>' + bars + curve +
      '<line class="tm-rd-mean" x1="' + mx + '" x2="' + mx + '" y1="' + mt + '" y2="' + (mt + ph) + '"/>' + last + ticks + '</svg>';
  }
  // Position of the fund among the funds of its family at the chosen
  // competência (same rules as fund_distribution_matrix_ui and
  // fund_peer_percentile in R); data/peers/{family}/{table}/{period}.json.gz
  // comes from write_static_peers: field -> [n, mean, sd, lo, hi, outside,
  // [counts], [101 percentiles]].
  var PEER_MIN = 6;
  function median(v) {
    var s = v.slice().sort(function (a, b) { return a - b; }), m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
  }
  function peerPercentile(q, v) {
    var i, lo = -1, hi = -1;
    for (i = 0; i < q.length; i++) if (q[i] === v) { if (lo < 0) lo = i; hi = i; }
    if (v < q[0]) return 0;
    if (v > q[100]) return 100;
    if (lo === 0 && v === q[0]) return hi / 2;
    if (hi === 100 && v === q[100]) return (lo + 100) / 2;
    if (lo >= 0) return (lo + hi) / 2;
    for (i = 0; i < 100; i++) if (q[i] < v && v < q[i + 1]) return i + (v - q[i]) / (q[i + 1] - q[i]);
    return null;
  }
  // Robust position statistics (fund_peer_robust in R): robust z = distance to
  // the median in scaled MADs on the display scale; |z| >= 2 atypical, >= 3.5
  // extreme (Iglewicz and Hoaglin, 1993); Tukey's fences on the same scale.
  var Z_ATP = 2, Z_EXT = 3.5;
  function peerSummary(a) {
    return a ? {n: a[0], mean: a[1], sd: a[2], lo: a[3], hi: a[4], outside: a[5], counts: a[6], q: a[7],
                scale: a[8] == null ? null : a[8], dmean: a[9], dsd: a[10], rs: a[11] == null ? null : a[11], excluded: a[12] || 0} : null;
  }
  function robust(s, v) {
    var out = {z: null, level: '—', tukey: false};
    if (!s || v == null || s.rs == null) return out;
    var f = function (u) { return scaleFwd(u, s.scale); }, q1 = f(s.q[25]), q3 = f(s.q[75]), iqr = q3 - q1;
    out.z = (f(v) - f(s.q[50])) / s.rs;
    out.level = Math.abs(out.z) >= Z_EXT ? 'extremo' : Math.abs(out.z) >= Z_ATP ? 'atípico' : 'típico';
    out.tukey = f(v) < q1 - 1.5 * iqr || f(v) > q3 + 1.5 * iqr;
    return out;
  }
  function zText(z) { return z == null ? '—' : (z > 0 ? '+' : '') + num(z, 1); }
  function ownValue(x, y, p) {
    var own = [];
    x.c.forEach(function (c, i) { if (c[0] !== p || y[3].charAt(i) !== '1') return; var v = parseShown(y[4][i]); if (v != null) own.push(v); });
    return own.length ? median(own) : null;
  }
  // ---- Relative metrics (mode Relativo; src/intelligence/fund_ratios.R, rules in
  // config/metric_ratio_rules.csv as window.TM_RATIOS): the same plan, the same
  // per-fund ratio (median of the numerator rows over the median of the
  // denominator rows at the same competência) and the same keys as the peer files.
  var RATIO_RULES = (window.TM_RATIOS || []).map(function (r) {
    return {tables: String(r[0]).split('|'), re: new RegExp(r[1]), dt: r[2], den: r[3], kind: r[4], label: r[5]};
  });
  function ratioPlan(tn, fields) {
    var mine = RATIO_RULES.filter(function (r) { return r.tables.indexOf(tn) >= 0; }), out = [], seen = {};
    fields.forEach(function (f) {
      var hit = mine.filter(function (r) { return r.re.test(f.split('|')[0]); });  // "<field>|<type>" follows its field
      if (!hit.length) return;
      function add(key, r) {
        if (seen[key]) return;
        seen[key] = 1;
        out.push({key: key, field: f, kind: r.kind, label: r.label, dt: r.dt === 'same_row' ? tn : r.dt, den: r.den});
      }
      var base = hit.filter(function (r) { return r.kind !== 'analytic'; });
      if (base.length && base[0].kind !== 'keep') add('r:' + f, base[0]);
      hit.filter(function (r) { return r.kind === 'analytic'; }).forEach(function (r) { add('a:' + f + '/' + r.den, r); });
    });
    return out;
  }
  function ratioTerms(den) { return den ? den.split('+') : []; }
  function termFields(term, fields) {
    if (term.indexOf('sum(') !== 0) return [term];
    var re = new RegExp(term.slice(4, -1));
    return fields.filter(function (f) { return re.test(f); });
  }
  function tableByName(tabs, n) { return tabs.filter(function (z) { return z.n === n && !z.lazy; })[0] || null; }
  function fieldRow(x, f) { return x ? x.f.filter(function (y) { return y[1] === f; })[0] || null : null; }
  function denFields(tabs, r) {
    var x = tableByName(tabs, r.dt), codes = x ? x.f.map(function (y) { return y[1]; }) : [], out = [];
    ratioTerms(r.den).forEach(function (t) { termFields(t, codes).forEach(function (f) { var y = fieldRow(x, f); if (y) out.push(y); }); });
    return {x: x, rows: out};
  }
  // Denominator of the fund at period p: sum of its published terms; null when none.
  function ownDenominator(tabs, r, p) {
    var d = denFields(tabs, r), sum = 0, any = false;
    d.rows.forEach(function (y) { var v = ownValue(d.x, y, p); if (v != null) { sum += v; any = true; } });
    return any ? sum : null;
  }
  function ratioPct(v) {
    if (v == null || isNaN(v)) return '—';
    var q = 100 * v, a = Math.abs(q);
    return num(q, a >= 100 ? 0 : a >= 1 ? 1 : 2) + '%';
  }
  function ratioLabel(label, item) { return label.split('{item}').join(item); }
  function modeBar(mode) {
    return '<div class="tm-dist-mode" role="group" aria-label="Valores das distribuições">' +
      [['rel', 'Relativo', 'Cada item dividido pelo total da sua tabela, os totais pelo PL e razões analíticas'],
       ['abs', 'Absoluto', 'Valores como publicados pela CVM']].map(function (m) {
        return '<button type="button" data-mode="' + m[0] + '" aria-pressed="' + (mode === m[0]) + '" class="tm-dist-mode-btn' +
          (mode === m[0] ? ' active' : '') + '" title="' + esc(m[2]) + '">' + m[1] + '</button>';
      }).join('') + '</div>';
  }
  // Tables with one row per kind of value (FIDC X.4: TAB_X_TP_OPER, window.TM_SPLIT;
  // fund_peer_split in R): each numeric field becomes one virtual field per type,
  // "<field>|<type>", keeping only the rows of that type.
  function splitTable(x) {
    var sp = (window.TM_SPLIT || []), ys = x.f.filter(function (y) { return sp.indexOf(y[1]) >= 0; })[0];
    if (!ys) return x;
    var op = ys[4].map(function (t) { t = t == null ? '' : String(t).trim(); return t || null; });
    var ops = op.filter(function (o, i) { return o != null && op.indexOf(o) === i; }).sort();
    var f = [];
    x.f.forEach(function (y) {
      if (y === ys || y[3].indexOf('1') < 0) { f.push(y); return; }
      ops.forEach(function (o) {
        var m = '';
        for (var i = 0; i < y[3].length; i++) m += y[3].charAt(i) === '1' && op[i] === o ? '1' : '0';
        f.push([y[0] + ' · ' + o, y[1] + '|' + o, y[2], m, y[4]].concat(y.slice(5)));
      });
    });
    var out = {}; for (var k in x) out[k] = x[k];
    out.f = f;
    return out;
  }
  function peerMatrix(x, p, pd, fam, prev, pp, mode, tabs) {
    x = splitTable(x);
    var FAM = fam.toUpperCase(), idx = [], stats = [], noPeer = 0;
    x.c.forEach(function (c, i) { if (c[0] === p) idx.push(i); });
    var plan = mode === 'rel' ? ratioPlan(x.n, x.f.map(function (y) { return y[1]; })) : [], byKey = {};
    plan.forEach(function (r) { byKey[r.key] = r; });
    function push(key, y, v, pv, ratio, label) {
      var s = peerSummary(pd.f[key]);
      if (!s) { noPeer++; return; }
      var pc = peerPercentile(s.q, v), rb = robust(s, v), before = null;
      if (prev && prev.f[key] && pv != null) {
        var ps = peerSummary(prev.f[key]);
        before = {p: peerPercentile(ps.q, pv), z: robust(ps, pv).z};
      }
      stats.push({y: y, key: key, label: label || y[0], s: s, v: v, pc: pc, rb: rb, prev: before, ratio: ratio || null,
                  fmt: ratio ? ratioPct : compact});
    }
    function ratioOf(r, y, per) {
      var nv = ownValue(x, y, per), dv = ownDenominator(tabs, r, per);
      return nv == null || dv == null || !(dv > 0) ? null : {v: nv / dv, num: nv, den: dv};
    }
    function ratioInfo(r, y, o) {
      var labs = denFields(tabs, r).rows.map(function (z) { return z[0]; });
      return {num: o.num, den: o.den, numLabel: y[0], denLabel: labs.length ? labs.join(' + ') : r.den, dt: r.dt === x.n ? '' : r.dt};
    }
    function addRatio(r, y) {
      var o = ratioOf(r, y, p);
      if (!o) return;
      var po = pp ? ratioOf(r, y, pp) : null;
      push(r.key, y, o.v, po ? po.v : null, ratioInfo(r, y, o), ratioLabel(r.label, y[0]));
    }
    x.f.forEach(function (y) {
      var v = ownValue(x, y, p);
      if (v == null) return;
      var r = byKey['r:' + y[1]];
      if (r) addRatio(r, y); else push(y[1], y, v, pp ? ownValue(x, y, pp) : null);
    });
    plan.forEach(function (r) {
      if (r.kind !== 'analytic') return;
      var y = fieldRow(x, r.field);
      if (y) addRatio(r, y);
    });
    if (!stats.length) return '<div class="tm-empty">Nenhum campo numérico do fundo em ' + esc(p) + ' tem ao menos ' + PEER_MIN +
      ' fundos ' + FAM + ' com valores distintos para comparar.</div>';
    stats.sort(function (a, b) { return (b.rb.z == null ? -1 : Math.abs(b.rb.z)) - (a.rb.z == null ? -1 : Math.abs(a.rb.z)); });
    function pct(v) { return v == null ? '—' : String(Math.round(v)); }
    var cells = stats.map(function (o) {
      var y = o.y, s = o.s, v = o.v, pr = pct(o.pc), rb = o.rb, fm = o.fmt, ra = o.ratio;
      var hist = null;
      if (!ra) {
        var vals = [], per = [];
        y[4].forEach(function (t, i) { if (y[3].charAt(i) !== '1') return; var w = parseShown(t); if (w != null) { vals.push(w); per.push(x.c[i][0]); } });
        hist = vals.length >= MIN_VALUES ? distribution(vals, per) : null;
      }
      var head = ra ? o.label + '\nValor relativo: ' + ra.numLabel + ', campo CVM ' + y[1].replace('|', ' · ') + ' (fundo: ' + compact(ra.num) + '), dividido por ' +
          ra.denLabel + (ra.dt ? ', em ' + tableLabel(ra.dt) : '') + ' (fundo: ' + compact(ra.den) + ').'
        : y[0] + '\nCampo CVM: ' + y[1].replace('|', ' · ');
      var tip = head +
        '\nPosição do fundo entre os ' + fmtInt(s.n) + ' fundos ' + FAM + ' com este campo publicado na competência ' + p + ': percentil ' + pr +
        ' (o valor do fundo, ' + fm(v) + ', é maior que o de ' + pr + '% deles).' +
        (rb.z != null ? '\nZ robusto ' + zText(rb.z) + ': ' + rb.level + ' (|z| < 2 típico; 2 a 3,5 atípico; 3,5 ou mais extremo). ' +
          'Mede a distância à mediana em desvios robustos (MAD; desvio absoluto médio quando a maioria dos fundos tem o mesmo valor) na escala do gráfico' +
          (rb.tukey ? '; fora das cercas de Tukey (seria um ponto isolado num boxplot)' : '') + '.' : '') +
        (o.prev ? '\nNa competência anterior (' + pp + '): percentil ' + pct(o.prev.p) + ', z ' + zText(o.prev.z) +
          '; variação de ' + zText(o.pc - o.prev.p) + ' pontos percentuais.' : '') +
        (s.scale == null ? '\nBarras = quantidade de fundos por faixa de valor; curva = normal com a mesma média e desvio-padrão dos fundos; tracejado = média dos fundos; laranja = este fundo.'
          : '\nBarras = quantidade de fundos por faixa de valor; curva = normal ajustada na escala exibida; tracejado = centro da curva; laranja = este fundo.') +
        (s.rs != null ? '\n' + Z_EXPLAIN : '') +
        '\nFundos ' + FAM + ': P25 ' + fm(s.q[25]) + ' · mediana ' + fm(s.q[50]) + ' · P75 ' + fm(s.q[75]) + ' (metade dos fundos fica entre P25 e P75).' +
        '\nMédia ' + fm(s.mean) + ' · desvio-padrão ' + fm(s.sd) + ' · mínimo ' + fm(s.q[0]) + ' · máximo ' + fm(s.q[100]) + '.' +
        (ra && s.excluded > 0 ? '\n' + fmtInt(s.excluded) + ' fundos com o campo ficaram fora desta comparação: denominador ausente, zero ou negativo (ex.: PL ≤ 0).' : '') +
        (ra && s.scale == null ? '\nParticipação desenhada em escala linear (de 0 a 100%).' : '') +
        '\nGráfico winsorizado a 2,5% de cada lado: valores abaixo de P2,5 (' + fm(scaleInv(s.lo, s.scale)) + ') ou acima de P97,5 (' +
        fm(scaleInv(s.hi, s.scale)) + ') aparecem nesses limites' + (s.outside ? ' (' + fmtInt(s.outside) + ' fundos)' : '') +
        '; média, desvio, percentis e posição usam os valores originais.' +
        (v < scaleInv(s.lo, s.scale) || v > scaleInv(s.hi, s.scale) ? '\nO fundo está entre os valores winsorizados: o ponto laranja fica na borda.' : '') +
        scaleNote(s.scale, scaleInv(s.dmean, s.scale), fm) +
        (ra ? '\nUm valor por fundo: mediana das linhas do numerador sobre a mediana das linhas do denominador na mesma competência.'
          : '\nUm valor por fundo: quando há várias linhas na data (classes, séries ou versões do informe), vale a mediana delas.') +
        (idx.length > 1 ? '\nEste fundo tem ' + fmtInt(idx.length) + ' linhas nesta data.' : '') +
        (hist ? '\nHistórico do próprio fundo: média ' + compact(hist.mean) + ' · desvio-padrão ' + compact(hist.sd) + ' · ' + fmtInt(hist.n) +
                ' valores (' + hist.firstPeriod + ' a ' + hist.lastPeriod + ').' : '') + noteText(y[1].split('|')[0]);
      var d = {n: s.n, mean: s.mean, sd: s.sd, lo: s.lo, hi: s.hi, counts: s.counts, last: v, scale: s.scale, dmean: s.dmean, dsd: s.dsd,
               rs: s.rs, zmed: scaleFwd(s.q[50], s.scale)};
      var lv = {'típico': ' tm-z-typ', 'atípico': ' tm-z-atp', 'extremo': ' tm-z-ext'}[rb.level] || '';
      var delta = o.prev && o.prev.p != null ? Math.round(o.pc - o.prev.p) : null;
      return '<div class="tm-dist' + lv + '" data-tip="' + esc(tip) + '"><div class="tm-dist-label' + (y[2] || ra ? ' tm-derived' : '') + '">' + esc(o.label) + '</div>' +
        distSvg(d, 200, 64, o.label, fm) + '<div class="tm-dist-cap"><b class="tm-dist-pos">percentil ' + pr + '</b>' +
        (rb.z != null ? '<span class="tm-z-badge">z ' + zText(rb.z) + '</span>' : '') +
        (delta != null ? '<span class="tm-z-delta ' + (delta >= 0 ? 'tm-up' : 'tm-down') + '">' + (delta >= 0 ? '▲' : '▼') + Math.abs(delta) + '</span>' : '') +
        ' · fundo ' + fm(v) + ' · ' + fmtInt(s.n) + ' fundos</div></div>';
    });
    var off = stats.filter(function (o) { return o.rb.level === 'atípico' || o.rb.level === 'extremo'; });
    var nExt = off.filter(function (o) { return o.rb.level === 'extremo'; }).length;
    var panelTip = 'Z robusto: distância do fundo à mediana dos fundos da família na mesma competência, em desvios robustos ' +
      '(MAD escalonado, na escala log). |z| de 2 a 3,5 = atípico; 3,5 ou mais = extremo (Iglewicz e Hoaglin, 1993). ' +
      'Resistente aos valores extremos, que distorcem a média e o desvio-padrão. Descritivo: posição entre os pares, ' +
      'não um juízo sobre o fundo. ▲▼ = variação do percentil desde a competência anterior do fundo.';
    var panel = '<div class="tm-z-panel" data-tip="' + esc(panelTip) + '"><div class="tm-z-head"><span class="tm-z-title">Destaques estatísticos</span>' +
      fmtInt(off.length) + ' de ' + fmtInt(stats.length) + ' campos fora do típico: ' + fmtInt(nExt) + ' extremos, ' + fmtInt(off.length - nExt) +
      ' atípicos' + (prev ? ' · comparação com ' + esc(pp) : '') + '.</div>' +
      (off.length ? '<ol class="tm-z-list">' + off.slice(0, 6).map(function (o) {
        return '<li class="' + (o.rb.level === 'extremo' ? 'tm-z-ext' : 'tm-z-atp') + '"><span class="tm-z-name">' + esc(o.label) + '</span> ' +
          (o.rb.z > 0 ? 'acima' : 'abaixo') + ' da mediana · fundo ' + o.fmt(o.v) + ', mediana ' + o.fmt(o.s.q[50]) + ' · percentil ' + pct(o.pc) +
          ' · z ' + zText(o.rb.z) + (o.prev ? ' · antes percentil ' + pct(o.prev.p) : '') + '</li>';
      }).join('') + '</ol>' : '<div class="tm-z-none">Todos os campos estão na faixa típica da família (|z| &lt; 2).</div>') + '</div>';
    var tip = 'Cada gráfico compara o fundo com os demais fundos ' + FAM + ' que publicaram o campo na mesma competência. ' +
      'O percentil diz quantos por cento desses fundos têm valor menor que o do fundo (percentil 90 = maior que 90% deles). ' +
      'Os gráficos vêm do mais atípico para o mais típico (|z robusto|). Troque a competência no seletor de período da Ficha. ' +
      'Passe o mouse em um gráfico para ver P25, mediana, P75, média, extremos e o histórico do próprio fundo.';
    var hasPlan = ratioPlan(x.n, x.f.map(function (y) { return y[1]; })).length > 0;
    return '<div class="tm-caption" data-tip="' + esc(tip) + '">Posição do fundo entre os ' + fmtInt(pd.funds) + ' fundos ' + FAM +
      ' na competência ' + esc(p) + ', campo a campo (' + (stats.length === 1 ? '1 campo numérico' : fmtInt(stats.length) + ' campos numéricos') +
      ', do mais ao menos atípico): barras = fundos por faixa de valor; curva = normal ajustada; tracejado = centro; laranja = este fundo. ' +
      'Passe o mouse para a explicação.' +
      (mode === 'rel' && plan.length ? ' Valores relativos: cada item dividido pelo total da sua tabela, os totais pelo PL e razões analíticas ' +
        '(ex.: inadimplência sobre os direitos creditórios); campos sem regra aparecem como publicados.'
        : hasPlan ? ' Valores absolutos, como publicados pela CVM.' : '') +
      (noPeer ? ' Fora da matriz: ' + (noPeer === 1 ? '1 campo' : fmtInt(noPeer) + ' campos') + ' sem ao menos ' + PEER_MIN + ' fundos com valores distintos.' : '') +
      '</div>' + panel + '<div class="tm-dist-grid">' + cells.join('') + '</div>';
  }
  FundTab.prototype.distPeriod = function (p) {
    var t = this, f = t.selected, data = t.ficha.data, x = data.t[t.fichaIndex], fam = f[F.family], token = {};
    var pane = t.el.find('.tm-static-detail [data-pane-body="dist"]');
    t.distToken = token;
    if (!t.distMode) t.distMode = 'rel';
    t.el.find('.tm-dist-mode-btn').each(function () {
      var on = $(this).attr('data-mode') === t.distMode;
      $(this).toggleClass('active', on).attr('aria-pressed', String(on));
    });
    pane.html('<div class="tm-empty">Carregando os demais fundos ' + fam.toUpperCase() + ' em ' + esc(p) + '…</div>');
    // Previous competência of the fund (trajectory); optional.
    var periods = [];
    x.c.forEach(function (c) { if (periods.indexOf(c[0]) < 0 && c[0] < p) periods.push(c[0]); });
    periods.sort();
    var pp = periods.length ? periods[periods.length - 1] : null, base = 'data/peers/' + fam + '/' + x.n + '/';
    var prevReq = pp ? getGz(base + pp + '.json.gz').then(function (d) { return d; }, function () { return $.Deferred().resolve(null).promise(); })
                     : $.Deferred().resolve(null).promise();
    // Denominator tables still to be read (e.g. FIDC Tabela IV for Ativo / PL):
    // read the fund's file of other tables first, as loadExtraTable does.
    var lazy = ratioPlan(x.n, x.f.map(function (y) { return y[1]; })).some(function (r) {
      return data.t.some(function (z) { return z.n === r.dt && z.lazy; });
    });
    var extras = lazy ? getGz('data/fichas_x/' + fam + '/' + f[F.key] + '.json.gz').then(function (xd) {
      data.t.forEach(function (y, i) {
        if (!y.lazy) return;
        var z = (xd.t || []).filter(function (w) { return w.n === y.n; })[0];
        if (z) data.t[i] = z;
      });
      return true;
    }, function () { return $.Deferred().resolve(false).promise(); }) : $.Deferred().resolve(true).promise();
    t.distRender = function () {
      var d = t.distData;
      if (d) pane.html(peerMatrix(d.x, d.p, d.pd, d.fam, d.prev, d.pp, t.distMode, data.t));
    };
    t.el.off('click.tmmode').on('click.tmmode', '.tm-dist-mode-btn', function (e) {
      e.preventDefault();
      t.distMode = $(this).attr('data-mode');
      t.el.find('.tm-dist-mode-btn').each(function () {
        var on = $(this).attr('data-mode') === t.distMode;
        $(this).toggleClass('active', on).attr('aria-pressed', String(on));
      });
      var link = t.el.find('.tm-static-detail a[data-pane="dist"]');
      // The choice also opens the tab Distribuições (native click: the tab handler).
      if (!link.hasClass('active') && link.length) link.get(0).click(); else t.distRender();
    });
    getGz(base + p + '.json.gz').done(function (pd) {
      prevReq.always(function (prev) {
        extras.always(function () {
          if (t.distToken !== token) return;
          t.distData = {x: x, p: p, pd: pd, fam: fam, prev: prev || null, pp: prev ? pp : null};
          t.distRender();
        });
      });
    }).fail(function () {
      if (t.distToken !== token) return;
      pane.html('<div class="tm-empty">' + (typeof DecompressionStream === 'undefined'
        ? 'Este navegador não descomprime arquivos gzip; atualize o navegador ou use o app local.'
        : 'Nenhum campo de ' + esc(tableLabel(x.n)) + ' tem ao menos ' + PEER_MIN + ' fundos ' + fam.toUpperCase() +
          ' com valores distintos em ' + esc(p) + '.') + '</div>');
    });
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
  // prototype/fund_search_module.R): a grid of label over value with cotistas and
  // the fields of this family's report; the core fields it lacks in one line.
  function traitsHtml(f, meta) {
    if (!meta) return '';
    var fam = f[F.family], cols = meta.columns[fam] || {};
    function item(label, text, tip, alert, info) {
      return '<div class="tm-tr' + (alert ? ' tm-tr-alert' : '') + '" data-tip="' + esc(tip) + '"><div class="tm-tr-label">' + esc(label) + (info || '') + '</div>' +
             '<div class="tm-tr-value' + (text === 'não informado' ? ' tm-muted' : '') + '">' + esc(text) + '</div></div>';
    }
    var shown = displayAttrs(meta, [fam]), hinted = meta.order.filter(function (a) {
      return window.TM_INFO && window.TM_INFO[a] && shown.indexOf(a) < 0; });
    // Hinted characteristics (FIP special rights) are named with their hover hint too.
    var absent = shown.concat(hinted).filter(function (a) { return !cols[a]; });
    var out = [item('Cotistas', f[F.holdersLast] == null ? 'não informado' : fmtInt(f[F.holdersLast]),
                    f[F.holdersLast] == null ? 'Quantidade de cotistas não publicada nos informes.'
                      : 'Quantidade de cotistas · informe de ' + monthLabel(f[F.holdersMonth]))];
    shown.forEach(function (a) {
      if (!cols[a]) return;
      var v = traitOf(meta, f, a), label = meta.labels[a], text, tip;
      if (!v) { text = 'não informado'; tip = label + ' (' + cols[a] + ') · não preenchido nos informes'; }
      else { text = traitText(meta, a, v[0]); tip = label + ' (' + cols[a] + ') · informe de ' + v[1]; }
      out.push(item(meta.medium[a], text, tip + noteText(cols[a]) + hintText(a), v && isAlert(meta, a, v[0])));
    });
    var miss = absent.length ? '<div class="tm-traits-absent" data-tip="Campos que o informe da CVM desta família não tem (não é falta de preenchimento).">' +
      'Não constam do informe de ' + fam.toUpperCase() + ': ' + absent.map(function (a) {
        var name = esc(meta.medium[a].toLowerCase()), h = hintText(a);
        return h ? '<span class="tm-hint-name" data-tip="' + esc(meta.labels[a] + h) + '">' + name + '</span>' : name; }).join(', ') + '.</div>' : '';
    // The explanatory notes of the fields (Entidade de investimento) are in the
    // hover tooltips only (noteText), not as a block below.
    return '<div class="tm-traits-grid">' + out.join('') + '</div>' + miss + '<div class="tm-joint-slot"></div>';
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
      lineChart(months, s[1], {color: color, height: 180, width: 760,
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
  RecordTab.prototype.distPeriod = FundTab.prototype.distPeriod;
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
    var names = t.d.byEntity[f[F.entity]] || [];
    t.el.find('.tm-rq').val(f[F.cnpj] + ' — ' + f[F.name]);
    t.el.find('.tm-ficha-table').html('<option>Carregando informes…</option>').prop('disabled', true);
    t.el.find('.tm-ficha-period').html('').prop('disabled', true);
    box.html(
      '<div class="card-header tm-detail-head"><div class="tm-eyebrow">' + f[F.family].toUpperCase() + ' · ' + esc(f[F.cnpj]) + '</div>' +
      '<h2 class="tm-detail-title">' + esc(f[F.name]) + '</h2></div>' +
      '<div class="tm-detail-body"><div class="tm-caption tm-ficha-summary"></div>' +
      '<ul class="nav nav-underline"><li class="nav-item"><a class="nav-link active" href="#" data-pane="perfil">Perfil</a></li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="ficha">Ficha</a></li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="serie">Série completa</a></li>' +
      '<li class="nav-item tm-dist-tab"><a class="nav-link" href="#" data-pane="dist">Distribuições</a>' + modeBar('rel') + '</li>' +
      '<li class="nav-item"><a class="nav-link" href="#" data-pane="nomes">Denominações (' + names.length + ')</a></li></ul>' +
      '<div class="tab-content"><div data-pane-body="perfil"><div class="tm-perfil-main"><div class="tm-empty">Carregando série…</div></div></div>' +
      '<div data-pane-body="ficha" hidden><div class="tm-empty">Carregando ficha…</div></div>' +
      '<div data-pane-body="serie" class="tm-table-wrap" hidden><div class="tm-empty">Carregando série completa…</div></div>' +
      '<div data-pane-body="dist" class="tm-table-wrap" hidden><div class="tm-empty">Carregando distribuições…</div></div>' +
      '<div data-pane-body="nomes" hidden>' + namesTable(names) + '</div></div></div>');
    // Perfil: the same series file and panel as the fund tabs.
    var key = f[F.key], color = t.d.meta.colors[f[F.family]] || '#2a78d6';
    getJSON('data/panorama/series/' + f[F.family] + '_' + key.charAt(0).toLowerCase() + '.json').done(function (s) {
      if (t.selected !== f) return;
      box.find('[data-pane-body="perfil"] .tm-perfil-main').html(profile(f, s[key], color));
    }).fail(function () {
      box.find('[data-pane-body="perfil"] .tm-perfil-main').html('<div class="tm-empty">Não foi possível carregar a série deste fundo.</div>');
    });
    loadFicha(f).done(function (fd, urls) {
      if (t.selected !== f) return;
      var sel = t.el.find('.tm-ficha-table');
      if (!fd || !fd.t.length) {
        sel.html('<option>Sem informes nas tabelas publicadas</option>');
        box.find('[data-pane-body="ficha"], [data-pane-body="serie"], [data-pane-body="dist"]').html(
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
