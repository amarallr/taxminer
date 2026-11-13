// CEDENTES tab (app and published dashboard): the cedentes of the FIDCs as
// published in the monthly report, table I (9 largest per block, CPF or CNPJ
// and share). Data package written by write_cedente_data
// (src/intelligence/cedente_data.R): index.json and months/{yyyy-mm}.json.
(function () {
  'use strict';
  var MONTHS = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  var LIMIT = 300;
  function esc(s) {
    return s == null ? '' : String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function fold(s) {
    return (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/[^A-Z0-9]+/g, ' ').trim();
  }
  function int(n) { return Number(n).toLocaleString('pt-BR'); }
  function monthLabel(m) { return m ? MONTHS[parseInt(m.substr(5, 2), 10) - 1] + '/' + m.substr(0, 4) : '—'; }
  // Share as published (93.53 or 93,53) shown the Brazilian way.
  function shareNumber(s) {
    if (s == null) return null;
    var v = s.indexOf(',') >= 0 ? s.replace(/\./g, '').replace(',', '.') : s;
    v = parseFloat(v); return isNaN(v) ? null : v;
  }
  function shareText(s) {
    var v = shareNumber(s);
    if (v == null) return s == null ? '—' : esc(s);
    var dec = (s.split(/[.,]/)[1] || '').length;
    return v.toLocaleString('pt-BR', {minimumFractionDigits: dec, maximumFractionDigits: dec}) + '%';
  }
  var TYPES = {PJ: 'Pessoa jurídica', PF: 'Pessoa física', '?': 'CPF/CNPJ inválido no informe'};

  function Cedentes(el) {
    this.el = el; this.src = el.attr('data-src') || 'data/cedentes/'; this.cache = {};
    this.state = {month: null, q: '', type: '', block: '', ced: null, fund: null};
  }
  Cedentes.prototype.get = function (path) {
    if (!this.cache[path]) this.cache[path] = $.ajax({url: this.src + path, dataType: 'json', cache: true});
    return this.cache[path];
  };
  Cedentes.prototype.start = function () {
    var c = this;
    c.get('index.json').done(function (idx) {
      c.idx = idx;
      idx.cedentes.forEach(function (x) { x.key = fold(x[0] + ' ' + (x[2] || '')) + ' ' + x[0].replace(/\D/g, ''); });
      idx.funds.forEach(function (f) { f.key = fold(f[2] || '') + ' ' + f[0]; });
      c.state.month = idx.reference;
      c.render(); c.load();
    }).fail(function () { c.el.html('<div class="tm-empty">Não foi possível carregar os cedentes.</div>'); });
  };
  Cedentes.prototype.render = function () {
    var c = this, idx = c.idx;
    c.el.html(
      '<div class="tm-dash-head"><div><span class="tm-eyebrow">Fase 1.3 · Cedentes de FIDC</span><h1>Cedentes dos FIDC</h1></div>' +
      '<div class="tm-dash-meta">Informe mensal, Tabela I: os 9 maiores cedentes de cada bloco, com CPF ou CNPJ e participação como publicados</div></div>' +
      '<div class="tm-filterbar tm-ced-filters">' +
      '<select class="form-select form-select-sm tm-ced-month">' + idx.months.map(function (m) {
        return '<option value="' + m + '">' + monthLabel(m) + (m === idx.reference ? ' (mês de referência)' : '') + '</option>';
      }).join('') + '</select>' +
      '<input type="search" class="form-control form-control-sm tm-ced-q" placeholder="Cedente (CPF, CNPJ ou nome) ou FIDC (CNPJ ou nome)">' +
      '<select class="form-select form-select-sm tm-ced-type"><option value="">Pessoa física e jurídica</option>' +
      '<option value="PJ">Pessoa jurídica (CNPJ)</option><option value="PF">Pessoa física (CPF)</option><option value="?">CPF/CNPJ inválido</option></select>' +
      '<select class="form-select form-select-sm tm-ced-block"><option value="">Todos os blocos</option>' +
      idx.blocks.map(function (b, i) { return '<option value="' + i + '">' + esc(b) + '</option>'; }).join('') + '</select>' +
      '<button type="button" class="btn btn-link btn-sm tm-ced-clear">Limpar</button></div>' +
      '<div class="tm-kpi-row tm-kpis-sm tm-ced-kpis"></div>' +
      '<div class="tm-master-detail tm-static-grid tm-ced-grid">' +
      '<div class="card tm-section tm-pane"><div class="card-header tm-card-head"><span class="tm-ced-count"></span>' +
      '<span class="tm-head-note tm-ced-note-c"></span></div>' +
      '<div class="card-body tm-scroll tm-ced-list"></div></div>' +
      '<div class="card tm-section tm-pane"><div class="card-header tm-card-head"><span class="tm-ced-fcount"></span>' +
      '<span class="tm-head-note tm-ced-note-f"></span></div>' +
      '<div class="card-body tm-scroll tm-ced-funds"></div></div></div>' +
      '<div class="tm-caption tm-ced-caption">Clique em um cedente para filtrar os FIDCs e em um FIDC para filtrar os cedentes; clique de novo para desfazer. ' +
      'Clique duas vezes em um FIDC para abri-lo na aba FIDC. Participação do cedente no bloco, como publicada pela CVM; valores acima de 100% (⚠) ' +
      'são inconsistências do próprio informe e não foram corrigidos.</div>');
    c.el.find('.tm-ced-month').val(c.state.month);
    var timer;
    function reset() { c.state.ced = null; c.state.fund = null; c.missing = null; }
    c.el.on('change', '.tm-ced-month', function () { c.state.month = this.value; c.load(); });
    c.el.on('input', '.tm-ced-q', function () { var v = this.value; clearTimeout(timer); timer = setTimeout(function () { c.state.q = v; reset(); c.update(); }, 180); });
    c.el.on('change', '.tm-ced-type', function () { c.state.type = this.value; reset(); c.update(); });
    c.el.on('change', '.tm-ced-block', function () { c.state.block = this.value; reset(); c.update(); });
    c.el.on('click', '.tm-ced-clear', function () {
      c.state.q = ''; c.state.type = ''; c.state.block = ''; reset();
      c.el.find('.tm-ced-q, .tm-ced-type, .tm-ced-block').val(''); c.update();
    });
    c.el.on('click', '.tm-ced-unpick', function (e) { e.preventDefault(); c.state[$(this).attr('data-dim')] = null; c.update(); });
    // A click selects (or, on the selected one, clears) and filters the other list.
    c.el.on('click', '.tm-ced-row', function () { c.missing = null; });
    c.el.on('click', '.tm-ced-row', function () {
      var k = +$(this).attr('data-ced'); c.state.ced = c.state.ced === k ? null : k; c.update();
    });
    // FIDC: a click filters the cedentes; a double click opens the fund in the
    // FIDC tab (detected on the click itself because each click redraws the list).
    c.el.on('click', '.tm-ced-fundrow', function (e) {
      var k = +$(this).attr('data-fund');
      if (e.detail === 2) {
        c.state.fund = k; c.update();
        var f = c.idx.funds[k];
        $(document).trigger('tm:open-fund', [{family: 'fidc', cnpj: f[0], name: f[2] || f[1]}]);
        return;
      }
      c.state.fund = c.state.fund === k ? null : k; c.update();
    });
  };
  // The app's current fund (prototype/charts.R, tmSetCurrent).
  Cedentes.prototype.focus = function (f) {
    if (window.tmSetCurrent && f) window.tmSetCurrent('fidc|' + String(f[0]).replace(/\D/g, ''));
  };
  // Opened with a current FIDC chosen in another tab: it is selected (the
  // cedente stays selected only if it is a cedente of that FIDC).
  Cedentes.prototype.follow = function (key) {
    var c = this, k = String(key || '').split('|');
    if (k[0] !== 'fidc') return;
    if (!c.rows) { c.want = key; return; }
    c.want = null;
    var i = -1;
    for (var j = 0; j < c.idx.funds.length && i < 0; j++) if (String(c.idx.funds[j][0]).replace(/\D/g, '') === k[1]) i = j;
    c.missing = null;
    if (i < 0 || !c.rows.some(function (r) { return r[1] === i; })) {
      // Not in this month: kept as a notice, the lists stay as they are.
      c.missing = {key: k[1], i: i}; c.update(); return;
    }
    if (c.state.fund === i) return;
    c.state.fund = i;
    if (c.state.ced != null && !c.rows.some(function (r) { return r[0] === c.state.ced && r[1] === i; })) c.state.ced = null;
    c.update();
  };
  Cedentes.prototype.load = function () {
    var c = this, m = c.state.month;
    c.el.find('.tm-ced-list, .tm-ced-funds').html('<div class="tm-empty">Carregando ' + monthLabel(m) + '…</div>');
    c.get('months/' + m + '.json').done(function (d) { if (c.state.month === m) { c.rows = d.rows; if (c.want) c.follow(c.want); c.update(); } })
      .fail(function () { c.el.find('.tm-ced-list, .tm-ced-funds').html('<div class="tm-empty">Sem dados para ' + monthLabel(m) + '.</div>'); });
  };
  // Rows grouped by column k (0 cedente, 1 FIDC): distinct counterparts and the largest share.
  function group(rows, k) {
    var by = {}, list = [];
    rows.forEach(function (r) {
      var g = by[r[k]];
      if (!g) { g = by[r[k]] = {id: r[k], other: {}, n: 0, max: null, rows: []}; list.push(g); }
      if (!g.other[r[1 - k]]) { g.other[r[1 - k]] = 1; g.n++; }
      var v = shareNumber(r[4]); if (v != null && (g.max == null || v > g.max)) g.max = v;
      g.rows.push(r);
    });
    return list;
  }
  Cedentes.prototype.update = function () {
    var c = this, idx = c.idx, st = c.state;
    if (!c.rows) return;
    var q = fold(st.q), words = q ? q.split(' ') : [], digits = st.q.replace(/\D/g, '');
    function match(key) {
      return (digits.length >= 4 && key.indexOf(digits) >= 0) || (words.length && words.every(function (w) { return key.indexOf(w) >= 0; }));
    }
    var base = c.rows.filter(function (r) {
      if (st.block !== '' && r[2] !== +st.block) return false;
      if (st.type && idx.cedentes[r[0]][1] !== st.type) return false;
      if (q && !match(idx.cedentes[r[0]].key) && !match(idx.funds[r[1]].key)) return false;
      return true;
    });
    // A selection that the filters no longer show is dropped.
    if (st.ced != null && !base.some(function (r) { return r[0] === st.ced; })) st.ced = null;
    if (st.fund != null && !base.some(function (r) { return r[1] === st.fund; })) st.fund = null;
    var cs = st.fund != null, fs = st.ced != null;
    // Each list is filtered by the selection of the other one.
    var cl = group(cs ? base.filter(function (r) { return r[1] === st.fund; }) : base, 0);
    var fl = group(fs ? base.filter(function (r) { return r[0] === st.ced; }) : base, 1);
    cl.sort(function (a, b) {
      return (cs ? (b.max || 0) - (a.max || 0) : 0) || b.n - a.n || (b.max || 0) - (a.max || 0) ||
             (idx.cedentes[a.id][0] < idx.cedentes[b.id][0] ? -1 : 1);
    });
    fl.sort(function (a, b) { return (fs ? (b.max || 0) - (a.max || 0) : 0) || b.n - a.n || (b.max || 0) - (a.max || 0) || a.id - b.id; });
    // KPIs of the current selection.
    var kc = {}, kf = {}, pf = 0, pj = 0;
    base.forEach(function (r) { if ((!fs || r[0] === st.ced) && (!cs || r[1] === st.fund)) { kc[r[0]] = 1; kf[r[1]] = 1; } });
    Object.keys(kc).forEach(function (k) { var t = idx.cedentes[k][1]; if (t === 'PF') pf++; else if (t === 'PJ') pj++; });
    function kpi(label, value, note) {
      return '<div class="tm-kpi"><div class="tm-kpi-value">' + value + '</div><div class="tm-kpi-label">' + label + '</div>' +
             (note ? '<div class="tm-kpi-note">' + note + '</div>' : '') + '</div>';
    }
    c.el.find('.tm-ced-kpis').html(
      kpi('Cedentes', int(Object.keys(kc).length), monthLabel(st.month)) + kpi('FIDCs com cedentes informados', int(Object.keys(kf).length)) +
      kpi('Pessoas jurídicas', int(pj), 'CNPJ') + kpi('Pessoas físicas', int(pf), 'CPF'));
    function fundName(i) { var f = idx.funds[i]; return f[2] || f[1]; }
    function cedName(i) { var x = idx.cedentes[i]; return x[2] ? x[2] + ' · ' + x[0] : x[0]; }
    function unpick(dim, label) {
      return '<a href="#" class="tm-ced-unpick" data-dim="' + dim + '" title="Desfazer a seleção">' + esc(label) + ' ×</a>';
    }
    // One cedente in one FIDC: block, position and share of each published line.
    function pair(g) {
      return g.rows.map(function (r) { return idx.blocks[r[2]] + ' · ' + r[3] + 'º · ' + shareText(r[4]); }).join('\n');
    }
    function shareValue(g) {
      if (g.max == null) return '—';
      return g.max.toLocaleString('pt-BR', {maximumFractionDigits: 2}) + '%' + (g.max > 100 ? ' ⚠' : '');
    }
    function bar(g, top, byShare, color) {
      var w = byShare ? (g.max == null ? 0 : Math.max(0.4, Math.min(100, g.max))) : Math.max(0.4, 100 * g.n / top);
      return '<div class="tm-bar-track"><div class="tm-bar" style="width:' + w.toFixed(2) + '%;background:' + color + '"></div></div>';
    }
    function more(n) { return n > LIMIT ? ' · mostrando os ' + LIMIT + ' primeiros' : ''; }

    var ctop = cl.length ? cl[0].n : 1;
    c.el.find('.tm-ced-count').html(int(cl.length) + (cl.length === 1 ? ' cedente' : ' cedentes') +
      (cs ? ' do FIDC ' + unpick('fund', fundName(st.fund)) : '') + more(cl.length));
    c.el.find('.tm-ced-note-c').text(cs ? 'ordem: participação no FIDC' : 'ordem: número de FIDCs');
    c.el.find('.tm-ced-list').html(cl.length ? '<div class="tm-bars">' + cl.slice(0, LIMIT).map(function (g, i) {
      var x = idx.cedentes[g.id];
      return '<div class="tm-bar-row tm-ced-row' + (st.ced === g.id ? ' tm-selected' : '') + '" data-ced="' + g.id + '"' +
        (cs ? ' data-tip="' + esc(cedName(g.id) + '\n' + pair(g)) + '"' : '') + '>' +
        '<span class="tm-bar-rank">' + (i + 1) + '</span><div class="tm-bar-label"><div class="tm-bar-name">' + esc(x[0]) +
        ' <span class="tm-tag tm-tag-ced">' + (x[1] === '?' ? 'inválido' : x[1]) + '</span></div><div class="tm-bar-sub"' +
        (x[6] ? ' title="Fonte do nome: ' + esc(x[6]) + '"' : '') + '>' +
        esc(x[2] || 'nome não encontrado no informe nem nas bases da CVM e da Receita Federal') + '</div></div>' +
        bar(g, ctop, cs, '#e8692c') + '<div class="tm-bar-value">' +
        (cs ? shareValue(g) : int(g.n) + (g.n === 1 ? ' FIDC' : ' FIDCs')) + '</div></div>';
    }).join('') + '</div>' : '<div class="tm-empty">Nenhum cedente com esses filtros.</div>');

    var ftop = fl.length ? fl[0].n : 1;
    c.el.find('.tm-ced-fcount').html(int(fl.length) + (fl.length === 1 ? ' FIDC' : ' FIDCs') +
      (fs ? ' do cedente ' + unpick('ced', cedName(st.ced)) : '') + more(fl.length));
    var miss = c.missing && !cs && !fs ? c.missing : null;
    c.el.find('.tm-ced-fcount').append(miss ? ' <span class="tm-head-note tm-ced-missing">· ' +
      esc(miss.i >= 0 ? fundName(miss.i) : 'FIDC ' + miss.key.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/, '$1.$2.$3/$4-$5')) +
      ' não informou cedentes em ' + monthLabel(st.month) + '</span>' : '');
    c.el.find('.tm-ced-note-f').text((fs ? 'ordem: participação do cedente' : 'ordem: número de cedentes') + ' · duplo clique abre na aba FIDC');
    c.el.find('.tm-ced-funds').html(fl.length ? '<div class="tm-bars">' + fl.slice(0, LIMIT).map(function (g, i) {
      var f = idx.funds[g.id];
      return '<div class="tm-bar-row tm-ced-row tm-ced-fundrow' + (st.fund === g.id ? ' tm-selected' : '') + '" data-fund="' + g.id + '"' +
        (fs ? ' data-tip="' + esc(fundName(g.id) + '\n' + pair(g)) + '"' : '') + '>' +
        '<span class="tm-bar-rank">' + (i + 1) + '</span><div class="tm-bar-label"><div class="tm-bar-name">' + esc(fundName(g.id)) +
        '</div><div class="tm-bar-sub tm-mono">' + esc(f[1]) + '</div></div>' +
        bar(g, ftop, fs, '#eb6834') + '<div class="tm-bar-value">' +
        (fs ? shareValue(g) : int(g.n) + (g.n === 1 ? ' cedente' : ' cedentes')) + '</div></div>';
    }).join('') + '</div>' : '<div class="tm-empty">Nenhum FIDC com esses filtros.</div>');
    // FICHA opens on the FIDC selected or, with only a cedente selected, its first FIDC.
    c.focus(cs ? idx.funds[st.fund] : (fs && fl.length ? idx.funds[fl[0].id] : null));
  };

  function activate(el) {
    if (el.data('tm-ready')) return;
    el.data('tm-ready', true);
    var c = new Cedentes(el);
    el.data('tm-cedentes', c);
    c.start();
  }
  // Built the first time the tab is shown; then shows the app's current FIDC.
  $(document).on('shown.bs.tab', function () {
    $('.tm-cedentes').filter(function () { return window.tmPaneVisible(this); }).each(function () { activate($(this)); $(this).data('tm-cedentes').follow(window.tmCurrent); });
  });
  $(function () { $('.tm-cedentes').filter(function () { return window.tmPaneVisible(this); }).each(function () { activate($(this)); }); });
})();
