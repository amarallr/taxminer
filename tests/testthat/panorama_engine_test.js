// Checks of the Panorama filter engine (prototype/www/panorama.js) on a
// synthetic fixture. Run by test_fund_analytics.R: node panorama_engine_test.js <engine>
'use strict';
var assert = require('assert');
var E = require(process.argv[2]);

// Funds: [family, CNPJ formatted, name, CNPJ]. A CNPJ ("E") in two families.
var index = {
  families: ['fii', 'fidc', 'fip', 'fiagro'],
  complete: {fii: '2025-12', fidc: '2025-12', fip: '2025-12', fiagro: '2025-11'},
  funds: [['fii', 'A', 'FUNDO A', 'A'], ['fii', 'E', 'FII E', 'E'], ['fidc', 'D', 'FIDC D', 'D'],
          ['fidc', 'E', 'FIDC E', 'E'], ['fip', 'F', 'FIP F', 'F'], ['fiagro', 'G', 'FIAGRO G', 'G']],
  admins: [['administrator:1', 'ADM UM', '1'], ['administrator:2', 'ADM DOIS', '2']]
};
// Month files: [fund, admin, net assets, quotaholders, carried]. D changes
// administrator between 2024-12 (ADM UM) and 2025-12 (ADM DOIS).
var months = {
  '2025-12': [[0, 0, 100, 10, 0], [1, 0, 7, null, 0], [2, 1, 300, null, 0], [3, 0, 50, null, 0], [4, -1, 40, null, 1]],
  '2025-11': [[5, 1, 20, 3, 0]],
  '2024-12': [[0, 0, 80, 8, 0], [2, 0, 200, null, 0], [3, 0, 50, null, 0], [4, -1, 10, null, 0]],
  '2024-11': [[5, 1, 10, 1, 0]]
};
var ref = E.snapshotMonths(index, null), prevM = {};
Object.keys(ref).forEach(function (f) { prevM[f] = E.shiftMonth(ref[f], -12); });
assert.deepStrictEqual(ref, {fii: '2025-12', fidc: '2025-12', fip: '2025-12', fiagro: '2025-11'});
assert.strictEqual(prevM.fiagro, '2024-11');

var rows = E.snapshot(index, months, ref), prev = E.snapshot(index, months, prevM);
// Each CNPJ once across families: E counts in FII (first in order), not FIDC.
assert.strictEqual(rows.length, 5);
assert.ok(!rows.some(function (r) { return r.family === 'fidc' && r.fund === 3; }));

function st(o) { return Object.assign({month: null, families: [], admins: [], funds: []}, o || {}); }

// No filter: whole market.
var k = E.kpis(E.filterRows(rows, st()), E.filterRows(prev, st()));
assert.strictEqual(k.pl, 100 + 7 + 300 + 40 + 20);
assert.strictEqual(k.funds, 5);
assert.strictEqual(k.admins, 2);
assert.strictEqual(k.holders, 13);

// Administrator selected: KPIs use the same universe as the charts.
var s1 = st({admins: [1]});
var u1 = E.filterRows(rows, s1);
var k1 = E.kpis(u1, E.filterRows(prev, s1));
assert.strictEqual(k1.pl, 320);            // D (300, ADM DOIS in 2025-12) + G (20)
assert.strictEqual(k1.funds, 2);
// Historical link: 12 months earlier D belonged to ADM UM, so ADM DOIS had only G.
assert.strictEqual(E.filterRows(prev, s1).length, 1);
assert.ok(Math.abs(k1.change - (320 - 10) / 10) < 1e-9);
// KPI total equals the sum of the fund ranking under the same filters.
var fr1 = E.fundRanking(E.filterRows(rows, s1, ['funds']));
assert.strictEqual(fr1.reduce(function (s, r) { return s + r.pl; }, 0), k1.pl);
// Fund shares are over the same filtered total and add up to 1.
assert.strictEqual(fr1.total, k1.pl);
assert.ok(Math.abs(fr1.reduce(function (s, r) { return s + r.share; }, 0) - 1) < 1e-9);
assert.ok(Math.abs(fr1[0].share - fr1[0].pl / k1.pl) < 1e-12);
// The administrator ranking ignores its own selection (others stay visible).
var ar1 = E.adminRanking(E.filterRows(rows, s1, ['admins']));
assert.deepStrictEqual(ar1.map(function (a) { return a.admin; }), [1, 0]);

// Fund selected: administrators reduced to the fund's administrator.
var s2 = st({funds: [0]});
assert.deepStrictEqual(E.adminRanking(E.filterRows(rows, s2, ['admins'])).map(function (a) { return a.admin; }), [0]);
assert.strictEqual(E.kpis(E.filterRows(rows, s2), []).pl, 100);

// AND across dimensions: family FIDC and ADM UM -> nothing (D is ADM DOIS now).
var s3 = st({families: ['fidc'], admins: [0]});
assert.strictEqual(E.filterRows(rows, s3).length, 0);
assert.strictEqual(E.kpis([], []).pl, null);  // empty state, not zero
// OR inside one dimension.
assert.strictEqual(E.filterRows(rows, st({families: ['fii', 'fiagro']})).length, 3);

// Top N with a pinned selection outside it.
var t = E.topWithPinned(E.fundRanking(rows), 'fund', [5], 2);
assert.deepStrictEqual(t.head.map(function (r) { return r.fund; }), [2, 0]);
assert.deepStrictEqual(t.pinned.map(function (r) { return r.fund; }), [5]);

// Chosen month: every family at that month; FIAGRO has no row in 2025-12.
var m12 = E.snapshotMonths(index, '2025-12');
assert.strictEqual(E.snapshot(index, months, m12).filter(function (r) { return r.family === 'fiagro'; }).length, 0);

// HHI on shares in percent.
assert.strictEqual(E.hhi([50, 50]), 5000);
assert.strictEqual(E.hhi([]), null);

// Series sum: aligned by month; missing stays missing.
var s = E.sumSeries([['2025-01', [1, null, 3], [1, null, 1]], ['2025-02', [10, 20], [1, 1]]]);
assert.deepStrictEqual(s, ['2025-01', [1, 10, 23], [1, 1, 2]]);
assert.strictEqual(E.sumSeries([]), null);
assert.strictEqual(E.change(110, 100), 0.1);
assert.strictEqual(E.change(110, 0), null);

console.log('all engine checks passed');
