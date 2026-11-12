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
    this.state = {month: null, q: '', type: '', block: '', picked: null};
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
      '<div class="tm-master-detail tm-static-grid">' +
      '<div class="card tm-section tm-pane"><div class="card-header tm-card-head"><span class="tm-ced-count"></span>' +
      '<span class="tm-head-note">ordem: número de FIDCs · clique em um cedente</span></div>' +
      '<div class="card-body tm-scroll tm-ced-list"></div></div>' +
      '<div class="tm-pane-wrap"><div class="card tm-section tm-detail tm-pane tm-ced-detail"><div class="tm-empty">Selecione um cedente.</div></div></div></div>');
    c.el.find('.tm-ced-month').val(c.state.month);
    var timer;
    c.el.on('change', '.tm-ced-month', function () { c.state.month = this.value; c.load(); });
    c.el.on('input', '.tm-ced-q', function () { var v = this.value; clearTimeout(timer); timer = setTimeout(function () { c.state.q = v; c.state.picked = null; c.update(); }, 180); });
    c.el.on('change', '.tm-ced-type', function () { c.state.type = this.value; c.state.picked = null; c.update(); });
    c.el.on('change', '.tm-ced-block', function () { c.state.block = this.value; c.state.picked = null; c.update(); });
    c.el.on('click', '.tm-ced-clear', function () {
      c.state.q = ''; c.state.type = ''; c.state.block = ''; c.state.picked = null;
      c.el.find('.tm-ced-q, .tm-ced-type, .tm-ced-block').val(''); c.update();
    });
    c.el.on('click', '.tm-ced-row', function () { c.state.picked = +$(this).attr('data-ced'); c.update(); });
    c.el.on('click', '.tm-ced-fund', function (e) {
      e.preventDefault();
      var f = c.idx.funds[+$(this).attr('data-fund')];
      $(document).trigger('tm:open-fund', [{family: 'fidc', cnpj: f[0], name: f[2] || f[1]}]);
    });
  };
  Cedentes.prototype.load = function () {
    var c = this, m = c.state.month;
    c.el.find('.tm-ced-list').html('<div class="tm-empty">Carregando ' + monthLabel(m) + '…</div>');
    c.get('months/' + m + '.json').done(function (d) { if (c.state.month === m) { c.rows = d.rows; c.update(); } })
      .fail(function () { c.el.find('.tm-ced-list').html('<div class="tm-empty">Sem dados para ' + monthLabel(m) + '.</div>'); });
  };
  Cedentes.prototype.update = function () {
    var c = this, idx = c.idx, st = c.state;
    if (!c.rows) return;
    var q = fold(st.q), words = q ? q.split(' ') : [], digits = st.q.replace(/\D/g, '');
    function match(key) {
      return (digits.length >= 4 && key.indexOf(digits) >= 0) || (words.length && words.every(function (w) { return key.indexOf(w) >= 0; }));
    }
    var rows = c.rows.filter(function (r) {
      if (st.block !== '' && r[2] !== +st.block) return false;
      if (st.type && idx.cedentes[r[0]][1] !== st.type) return false;
      if (q && !match(idx.cedentes[r[0]].key) && !match(idx.funds[r[1]].key)) return false;
      return true;
    });
    // One line per cedente: distinct FIDCs and the largest share.
    var by = {}, list = [];
    rows.forEach(function (r) {
      var g = by[r[0]];
      if (!g) { g = by[r[0]] = {ced: r[0], funds: {}, n: 0, max: null, rows: []}; list.push(g); }
      if (!g.funds[r[1]]) { g.funds[r[1]] = 1; g.n++; }
      var v = shareNumber(r[4]); if (v != null && (g.max == null || v > g.max)) g.max = v;
      g.rows.push(r);
    });
    list.sort(function (a, b) { return b.n - a.n || (b.max || 0) - (a.max || 0) || (idx.cedentes[a.ced][0] < idx.cedentes[b.ced][0] ? -1 : 1); });
    var funds = {}; rows.forEach(function (r) { funds[r[1]] = 1; });
    var pf = list.filter(function (g) { return idx.cedentes[g.ced][1] === 'PF'; }).length;
    var pj = list.filter(function (g) { return idx.cedentes[g.ced][1] === 'PJ'; }).length;
    function kpi(label, value, note) {
      return '<div class="tm-kpi"><div class="tm-kpi-value">' + value + '</div><div class="tm-kpi-label">' + label + '</div>' +
             (note ? '<div class="tm-kpi-note">' + note + '</div>' : '') + '</div>';
    }
    c.el.find('.tm-ced-kpis').html(
      kpi('Cedentes', int(list.length), monthLabel(st.month)) + kpi('FIDCs com cedentes informados', int(Object.keys(funds).length)) +
      kpi('Pessoas jurídicas', int(pj), 'CNPJ') + kpi('Pessoas físicas', int(pf), 'CPF'));
    c.el.find('.tm-ced-count').text(int(list.length) + (list.length === 1 ? ' cedente' : ' cedentes') +
      (list.length > LIMIT ? ' · mostrando os ' + LIMIT + ' primeiros' : ''));
    var top = list.length ? list[0].n : 1;
    c.el.find('.tm-ced-list').html(list.length ? '<div class="tm-bars">' + list.slice(0, LIMIT).map(function (g, i) {
      var x = idx.cedentes[g.ced], w = Math.max(0.4, 100 * g.n / top);
      return '<div class="tm-bar-row tm-ced-row' + (st.picked === g.ced ? ' tm-selected' : '') + '" data-ced="' + g.ced + '">' +
        '<span class="tm-bar-rank">' + (i + 1) + '</span><div class="tm-bar-label"><div class="tm-bar-name">' + esc(x[0]) +
        ' <span class="tm-tag tm-tag-ced">' + (x[1] === '?' ? 'inválido' : x[1]) + '</span></div><div class="tm-bar-sub"' +
        (x[6] ? ' title="Fonte do nome: ' + esc(x[6]) + '"' : '') + '>' +
        esc(x[2] || 'nome não encontrado no informe nem nos cadastros da CVM') + '</div></div><div class="tm-bar-track"><div class="tm-bar" style="width:' +
        w.toFixed(2) + '%;background:#e8692c"></div></div><div class="tm-bar-value">' + int(g.n) + (g.n === 1 ? ' FIDC' : ' FIDCs') + '</div></div>';
    }).join('') + '</div>' : '<div class="tm-empty">Nenhum cedente com esses filtros.</div>');
    if (st.picked == null || !by[st.picked]) st.picked = list.length ? list[0].ced : null;
    c.el.find('.tm-ced-row[data-ced="' + st.picked + '"]').addClass('tm-selected');
    c.detail(st.picked == null ? null : by[st.picked]);
  };
  Cedentes.prototype.detail = function (g) {
    var c = this, idx = c.idx, box = c.el.find('.tm-ced-detail');
    if (!g) { box.html('<div class="tm-empty">Selecione um cedente.</div>'); return; }
    var x = idx.cedentes[g.ced];
    var rows = g.rows.slice().sort(function (a, b) { return (shareNumber(b[4]) || 0) - (shareNumber(a[4]) || 0); });
    box.html(
      '<div class="card-header tm-detail-head"><div class="tm-eyebrow">' + esc(TYPES[x[1]]) + ' · ' + esc(x[0]) + '</div>' +
      '<h2 class="tm-detail-title">' + esc(x[2] || 'Nome não encontrado no informe nem nos cadastros da CVM') + '</h2>' +
      '<div class="tm-detail-meta"><span><strong>Em ' + monthLabel(c.state.month) + ': </strong>' + int(g.n) + (g.n === 1 ? ' FIDC' : ' FIDCs') + '</span>' +
      (x[6] ? '<span><strong>Fonte do nome: </strong>' + esc(x[6]) + '</span>' : '') + '<span><strong>Informado em: </strong>' + int(x[5]) + (x[5] === 1 ? ' competência' : ' competências') + ' (' + monthLabel(x[3]) + ' a ' + monthLabel(x[4]) + ')</span></div></div>' +
      '<div class="tm-detail-body"><table class="tm-card-table tm-ced-table"><thead><tr><th>FIDC</th><th>Bloco da Tabela I</th>' +
      '<th class="tm-num">Posição</th><th class="tm-num">Participação</th></tr></thead><tbody>' + rows.map(function (r) {
        var f = idx.funds[r[1]];
        return '<tr><td><a href="#" class="tm-ced-fund" data-fund="' + r[1] + '" title="Abrir o fundo na aba FIDC">' + esc(f[2] || f[1]) +
          '</a><div class="tm-mono tm-muted">' + esc(f[1]) + '</div></td><td>' + esc(idx.blocks[r[2]]) + '</td><td class="tm-num">' + r[3] + 'º</td>' +
          (shareNumber(r[4]) > 100
            ? '<td class="tm-num tm-warn" data-tip="Acima de 100%: valor inconsistente no informe da CVM, mostrado como publicado.">' + shareText(r[4]) + ' ⚠</td></tr>'
            : '<td class="tm-num">' + shareText(r[4]) + '</td></tr>');
      }).join('') + '</tbody></table><div class="tm-caption">Participação do cedente no bloco, como publicada pela CVM. Valores acima de 100% (⚠) são inconsistências do próprio informe e não foram corrigidos.' +
      'Clique no FIDC para abrir a ficha na aba FIDC.</div></div>');
  };

  function activate(el) {
    if (el.data('tm-ready')) return;
    el.data('tm-ready', true);
    new Cedentes(el).start();
  }
  // Built the first time the tab is shown.
  $(document).on('shown.bs.tab', function () { $('.tab-pane.active .tm-cedentes').each(function () { activate($(this)); }); });
  $(function () { $('.tab-pane.active .tm-cedentes').each(function () { activate($(this)); }); });
})();
