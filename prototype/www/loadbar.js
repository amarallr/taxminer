// Loading bar shared by the local app and the published dashboard: a thin
// bar at the top of the page while data loads. It shows only when a wait
// lasts more than SHOW_AFTER ms (fast clicks show nothing) and, once shown,
// stays at least MIN_VISIBLE ms (no flicker). Progress is real when a
// download reports its size (tmLoad.progress); otherwise it advances slowly
// up to 90% and completes when the data arrives. Sources:
//   - every jQuery $.ajax request (Panorama, Cedentes, fund files);
//   - Shiny busy/idle (local app: any recalculation of the server);
//   - tmLoad.start()/done() around other waits (gzip files of the site).
// Accessible: role="progressbar" with a label; static under reduced motion.
(function () {
  'use strict';
  var SHOW_AFTER = 250, MIN_VISIBLE = 300;
  var bar, fill, pending = 0, showTimer = null, trickle = null, shownAt = 0, value = 0, exact = {}, nextId = 1;

  function el() {
    if (bar) return bar;
    bar = document.createElement('div');
    bar.className = 'tm-loadbar';
    bar.setAttribute('role', 'progressbar');
    bar.setAttribute('aria-label', 'Carregando dados');
    bar.setAttribute('aria-valuemin', '0');
    bar.setAttribute('aria-valuemax', '100');
    bar.hidden = true;
    fill = document.createElement('div');
    fill.className = 'tm-loadbar-fill';
    bar.appendChild(fill);
    document.body.appendChild(bar);
    return bar;
  }
  function set(v) {
    value = Math.max(value, Math.min(v, 1));
    fill.style.width = (value * 100).toFixed(1) + '%';
    bar.setAttribute('aria-valuenow', String(Math.round(value * 100)));
  }
  // Real progress of the downloads that report their size, if any.
  function exactValue() {
    var ids = Object.keys(exact), sum = 0;
    if (!ids.length) return null;
    ids.forEach(function (k) { sum += exact[k]; });
    return sum / ids.length;
  }
  function show() {
    showTimer = null;
    if (!pending) return;
    el(); value = 0; fill.style.width = '0'; bar.hidden = false;
    bar.classList.remove('tm-loadbar-done');
    document.documentElement.classList.add('tm-loading');
    shownAt = Date.now();
    set(0.08);
    trickle = setInterval(function () {
      var e = exactValue();
      if (e != null) set(0.05 + e * 0.9);
      else if (value < 0.9) set(value + (0.9 - value) * 0.06);
    }, 200);
  }
  function hide() {
    if (showTimer) { clearTimeout(showTimer); showTimer = null; }
    document.documentElement.classList.remove('tm-loading');
    if (!bar || bar.hidden) return;
    var wait = Math.max(0, MIN_VISIBLE - (Date.now() - shownAt));
    setTimeout(function () {
      if (pending) return;  // a new wait began meanwhile
      clearInterval(trickle); trickle = null;
      set(1);
      bar.classList.add('tm-loadbar-done');
      setTimeout(function () { if (!pending) { bar.hidden = true; bar.classList.remove('tm-loadbar-done'); } }, 250);
    }, wait);
  }
  function start() {
    pending++;
    if (pending === 1 && !trickle && !showTimer) showTimer = setTimeout(show, SHOW_AFTER);
    return nextId++;
  }
  function done(id) {
    if (id != null) delete exact[id];
    pending = Math.max(0, pending - 1);
    if (!pending) hide();
  }
  window.tmLoad = {
    start: start,
    done: done,
    // fraction 0..1 of one download started with start()
    progress: function (id, fraction) { if (id != null && isFinite(fraction)) exact[id] = Math.max(0, Math.min(1, fraction)); }
  };

  function wire() {
    if (window.jQuery) {
      var $ = window.jQuery, ids = [];
      $(document).ajaxSend(function () { ids.push(start()); });
      $(document).ajaxComplete(function () { done(ids.shift()); });
      // Local app: the server is recalculating.
      var busy = null;
      $(document).on('shiny:busy', function () { if (busy == null) busy = start(); });
      $(document).on('shiny:idle', function () { if (busy != null) { done(busy); busy = null; } });
    }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wire); else wire();
})();
