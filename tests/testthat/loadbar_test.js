// Checks prototype/www/loadbar.js with a minimal fake DOM and virtual time:
// a fast wait shows nothing; a long wait shows the bar, which stays at least
// MIN_VISIBLE and then hides; real progress moves the bar; overlapping waits
// keep it up. Usage: node loadbar_test.js <path to loadbar.js>. Prints "ok".
const fs = require('fs'), vm = require('vm'), assert = require('assert');
let now = 0, timers = [], seq = 0;
function setT(fn, ms, every) { const t = {id: ++seq, at: now + ms, fn, every}; timers.push(t); return t.id; }
const clear = (id) => { timers = timers.filter((t) => t.id !== id); };
function advance(ms) {
  const end = now + ms;
  for (;;) {
    timers.sort((a, b) => a.at - b.at);
    const t = timers[0];
    if (!t || t.at > end) break;
    now = t.at;
    if (t.every) t.at += t.every; else timers.shift();
    t.fn();
  }
  now = end;
}
function node(tag) {
  const cls = new Set(), attrs = {};
  return {tag, hidden: false, style: {}, children: [], className: '',
    classList: {add: (c) => cls.add(c), remove: (c) => cls.delete(c), has: (c) => cls.has(c)},
    setAttribute: (k, v) => { attrs[k] = v; }, getAttribute: (k) => attrs[k],
    appendChild(c) { this.children.push(c); }};
}
const html = node('html'), body = node('body');
const ctx = {
  window: {}, Date: {now: () => now}, Math, isFinite, Object, String,
  setTimeout: (fn, ms) => setT(fn, ms), clearTimeout: clear,
  setInterval: (fn, ms) => setT(fn, ms, ms), clearInterval: clear,
  document: {readyState: 'complete', body, documentElement: html, createElement: node,
             addEventListener() {}}
};
ctx.window = ctx;
vm.runInNewContext(fs.readFileSync(process.argv[2], 'utf8'), ctx);
const L = ctx.tmLoad, bar = () => body.children[0];
const visible = () => !!bar() && !bar().hidden;

// 1. A fast wait (100 ms) never shows the bar.
let a = L.start(); advance(100); L.done(a); advance(1000);
assert.ok(!visible(), 'fast wait must not show the bar');

// 2. A long wait shows it after 250 ms, with the busy cursor and ARIA.
a = L.start(); advance(249); assert.ok(!visible(), 'not before 250 ms');
advance(2); assert.ok(visible(), 'shown after 250 ms');
assert.ok(html.classList.has('tm-loading'), 'busy cursor');
assert.strictEqual(bar().getAttribute('role'), 'progressbar');
advance(3000);
const w = parseFloat(bar().children[0].style.width);
assert.ok(w > 8 && w <= 90, 'advances but stays below 90% without real progress: ' + w);

// 3. Done right after showing: still visible for the minimum time, then hidden.
L.done(a); advance(10); assert.ok(visible(), 'stays visible right after done (minimum time)');
advance(1000); assert.ok(!visible(), 'hidden after completion');
assert.ok(!html.classList.has('tm-loading'), 'cursor restored');

// 4. Real progress of a download moves the bar to its fraction.
a = L.start(); advance(300); L.progress(a, 0.5); advance(400);
const w2 = parseFloat(bar().children[0].style.width);
assert.ok(w2 >= 45 && w2 <= 60, 'real progress near 50%: ' + w2);

// 5. Overlapping waits keep the bar up until the last one ends.
const b = L.start(); L.done(a); advance(1000); assert.ok(visible(), 'second wait keeps it visible');
L.done(b); advance(1000); assert.ok(!visible(), 'hidden after the last wait');
console.log('ok');
