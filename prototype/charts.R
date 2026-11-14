# Hand-made SVG and HTML charts for the local app (no chart package, works
# offline). Rules: one y-axis per chart, zero-based magnitude axes, 2px lines,
# recessive grid, text in ink colours, identity colour only on marks, and a
# hover layer (crosshair + tooltip) on every chart. Tooltips read the
# `data-tip` attribute (see the script in prototype/app.R).

# Categorical order of the families (fixed, never cycled).
fund_family_colors <- c(fii = "#2a78d6", fidc = "#eb6834", fip = "#1baf7a", fiagro = "#eda100")
fund_family_names <- c(fii = "Imobiliários", fidc = "Direitos creditórios",
                       fip = "Participações", fiagro = "Agronegócio")

html_attr <- function(x) htmltools::htmlEscape(as.character(x), attribute = TRUE)

# Axis label for a value in reais: no decimals when the tick is whole.
axis_brl <- function(v) sub(",0 ", " ", format_brl(v, digits = 1), fixed = TRUE)
axis_int <- function(v) {
  vapply(v, function(x) {
    if (x >= 1e6) paste0(formatC(x / 1e6, format = "f", digits = 1, decimal.mark = ","), " mi")
    else if (x >= 1e4) paste0(formatC(x / 1e3, format = "f", digits = 0), " mil")
    else formatC(x, format = "d", big.mark = ".", decimal.mark = ",")
  }, character(1))
}

month_date <- function(month) as.Date(paste0(month, "-01"))

# Smallest "nice" step (1, 2, 2.5, 5 x 10^n) not below x.
nice_step <- function(x) {
  if (!is.finite(x) || x <= 0) return(1)
  p <- 10^floor(log10(x))
  for (m in c(1, 2, 2.5, 5, 10)) if (m * p >= x) return(m * p)
}

# SVG path segments (split at NA) for points px/py; `close_at` closes an area.
svg_segments <- function(px, py, template, close_at = NULL) {
  seg <- cumsum(is.na(py))
  out <- character()
  for (s in unique(seg[!is.na(py)])) {
    i <- which(seg == s & !is.na(py))
    pts <- paste(sprintf("%.1f,%.1f", px[i], py[i]), collapse = " L")
    if (is.null(close_at)) out <- c(out, sprintf(template, pts))
    else if (length(i) > 1) out <- c(out, sprintf(template, px[i[1]], close_at, pts, px[i[length(i)]], close_at))
  }
  out
}

# Line chart of one measure over months. `months` are "YYYY-MM"; NA values
# break the line. `tips` overrides the tooltip text per point.
# `values2` (optional) adds a second measure as a dashed neutral line on its
# own right-hand axis, whose ticks sit on the left gridlines; the caller
# labels both lines (see chart_key()).
svg_line_chart <- function(months, values, color = "#2a78d6", format_value = axis_brl,
                           format_tip = format_brl, tips = NULL, label = "",
                           width = 560, height = 190, area = TRUE,
                           values2 = NULL, format_value2 = axis_int, color2 = "#5b6573", pick = FALSE,
                           part = NULL, part_color = "#e07b39") {
  # part: values of a part of the series (e.g. one fund of an administrator), on
  # the same axis, drawn as a second line with its own area.
  ok <- !is.na(months)
  months <- months[ok]; values <- values[ok]; if (!is.null(tips)) tips <- tips[ok]
  if (!is.null(values2)) values2 <- values2[ok]
  if (!is.null(part)) part <- part[ok]
  if (!length(values) || all(is.na(values))) {
    return(htmltools::HTML('<div class="tm-chart-empty">Sem dados para o gráfico.</div>'))
  }
  dual <- !is.null(values2) && any(!is.na(values2))
  ml <- 62; mr <- if (dual) 46 else 14; mt <- 10; mb <- 24
  pw <- width - ml - mr; ph <- height - mt - mb
  d <- as.numeric(month_date(months))
  x0 <- min(d); x1 <- max(d); if (x1 == x0) x1 <- x0 + 31
  ticks <- pretty(c(0, max(values, na.rm = TRUE)), n = 4)
  ymax <- max(ticks)
  sx <- function(v) ml + (v - x0) / (x1 - x0) * pw
  sy <- function(v) mt + ph - v / ymax * ph
  px <- sx(d); py <- ifelse(is.na(values), NA, sy(values))

  grid <- vapply(ticks, function(t) sprintf(
    '<line class="tm-grid" x1="%.1f" x2="%.1f" y1="%.1f" y2="%.1f"/><text class="tm-axis" x="%.1f" y="%.1f" text-anchor="end">%s</text>',
    ml, width - mr, sy(t), sy(t), ml - 8, sy(t) + 4, html_attr(format_value(t))), character(1))

  right <- character(); lines2 <- character(); py2 <- rep(NA_real_, length(px))
  if (dual) {
    k <- length(ticks) - 1L
    ymax2 <- nice_step(max(values2, na.rm = TRUE) / k) * k
    sy2 <- function(v) mt + ph - v / ymax2 * ph
    py2 <- ifelse(is.na(values2), NA, sy2(values2))
    right <- vapply(seq(0, ymax2, length.out = k + 1L), function(t) sprintf(
      '<text class="tm-axis tm-axis-2" x="%.1f" y="%.1f" text-anchor="start">%s</text>',
      width - mr + 6, sy2(t) + 4, html_attr(format_value2(t))), character(1))
    lines2 <- svg_segments(px, py2, sprintf('<path class="tm-line tm-line-2" d="M%%s" stroke="%s"/>', color2))
  }

  years <- as.integer(format(as.Date(x0, origin = "1970-01-01"), "%Y")):as.integer(format(as.Date(x1, origin = "1970-01-01"), "%Y"))
  step <- max(1L, ceiling(length(years) / 6))
  years <- years[seq(1, length(years), by = step)]
  year_d <- as.numeric(as.Date(sprintf("%d-01-01", years)))
  keep <- year_d >= x0 & year_d <= x1
  if (!any(keep)) { year_d <- x0; years <- format(as.Date(x0, origin = "1970-01-01"), "%Y"); keep <- TRUE }
  xaxis <- vapply(which(keep), function(i) sprintf(
    '<line class="tm-tick" x1="%.1f" x2="%.1f" y1="%.1f" y2="%.1f"/><text class="tm-axis" x="%.1f" y="%.1f" text-anchor="middle">%s</text>',
    sx(year_d[i]), sx(year_d[i]), mt + ph, mt + ph + 4, sx(year_d[i]), height - 6, years[i]), character(1))

  lines <- svg_segments(px, py, sprintf('<path class="tm-line" d="M%%s" stroke="%s"/>', color))
  pyp <- if (is.null(part)) rep(NA_real_, length(px)) else ifelse(is.na(part), NA, sy(pmax(part, 0)))
  part_svg <- if (is.null(part) || all(is.na(pyp))) character() else c(
    svg_segments(px, pyp, sprintf('<path class="tm-area tm-area-part" d="M%%.1f,%%.1f L%%s L%%.1f,%%.1f Z" fill="%s"/>', part_color),
                 close_at = sy(0)),
    svg_segments(px, pyp, sprintf('<path class="tm-line tm-line-part" d="M%%s" stroke="%s"/>', part_color)))
  fills <- if (area) svg_segments(px, py, sprintf('<path class="tm-area" d="M%%.1f,%%.1f L%%s L%%.1f,%%.1f Z" fill="%s"/>', color),
                                  close_at = sy(0)) else character()
  last <- max(which(!is.na(py)))
  end <- sprintf('<circle class="tm-end" cx="%.1f" cy="%.1f" r="4" fill="%s"/>', px[last], py[last], color)

  # Hover bands: each covers half the gap to its neighbours.
  edges <- c(ml, (px[-1] + px[-length(px)]) / 2, width - mr)
  if (is.null(tips)) tips <- paste0(month_label(months), "\n", format_tip(values))
  hits <- vapply(seq_along(px), function(i) {
    dot <- if (is.na(py[i])) "" else sprintf('<circle class="tm-dot" cx="%.1f" cy="%.1f" r="5" fill="%s"/>',
                                             px[i], py[i], color)
    dot2 <- if (is.na(py2[i])) "" else sprintf('<circle class="tm-dot" cx="%.1f" cy="%.1f" r="4" fill="%s"/>',
                                               px[i], py2[i], color2)
    if (!is.na(pyp[i])) dot2 <- paste0(dot2, sprintf('<circle class="tm-dot" cx="%.1f" cy="%.1f" r="4" fill="%s"/>',
                                                     px[i], pyp[i], part_color))
    sprintf('<g class="tm-hit"%s data-tip="%s"><rect x="%.1f" y="%.1f" width="%.1f" height="%.1f"/><line class="tm-cross" x1="%.1f" x2="%.1f" y1="%.1f" y2="%.1f"/>%s%s</g>',
            if (pick) sprintf(' data-month="%s"', months[i]) else "", html_attr(tips[i]), edges[i], mt, max(1, edges[i + 1] - edges[i]), ph, px[i], px[i], mt, mt + ph, dot, dot2)
  }, character(1))

  htmltools::HTML(sprintf(
    '<svg class="tm-chart%s" viewBox="0 0 %d %d" role="img" aria-label="%s"%s>%s%s%s%s%s%s%s%s</svg>',
    if (pick) " tm-chart-pick" else "", width, height, html_attr(label),
    # Geometry of the axes, for a series drawn in the browser (admin chart of the site).
    if (pick) sprintf(' data-geom="%s"', paste(c(x0, x1, ml, pw, mt, ph, ymax), collapse = ",")) else "",
    paste(grid, collapse = ""), paste(right, collapse = ""),
    paste(xaxis, collapse = ""), paste(fills, collapse = ""), paste(lines2, collapse = ""),
    paste(c(lines, part_svg), collapse = ""), end, paste(hits, collapse = "")))
}

# Key for a dual chart: solid colour line = left axis, dashed = right axis.
chart_key <- function(color, left, right, color2 = "#5b6573") {
  shiny::div(class = "tm-chart-key",
             shiny::span(class = "tm-key-line", style = sprintf("border-top-color:%s", color)), left,
             shiny::span(class = "tm-key-line tm-key-dash", style = sprintf("border-top-color:%s", color2)), right)
}

# Horizontal bars as HTML rows (label, bar, value). `keys` + `input` make rows
# clickable (they send the key to that Shiny input).
bar_list <- function(labels, values, value_text, colors = "#2a78d6", sub = NULL, keys = NULL,
                     input = NULL, selected = NULL, rank = NULL, tips = NULL, fund_keys = NULL,
                     fund_selected = NULL) {
  top <- max(values, 0, na.rm = TRUE)
  colors <- rep_len(colors, length(values))
  # A missing key leaves that row not clickable.
  pick <- if (is.null(keys)) rep(FALSE, length(values)) else !is.na(keys)
  n <- length(values)
  if (!n) return(shiny::div(class = "tm-bars"))
  # Built as text in one pass (hundreds of rows for a large administrator; a
  # tag object per row took about a second). Same markup as the tag version.
  esc <- function(x) htmltools::htmlEscape(as.character(x), attribute = TRUE)
  w <- ifelse(top > 0 & !is.na(values), pmax(0.4, 100 * values / top), 0)
  sel <- if (is.null(selected) || is.null(keys)) rep(FALSE, n) else !is.na(keys) & keys == selected
  # `fund_keys` ("family|CNPJ"): a click selects the fund for the FICHA tab.
  fpick <- if (is.null(fund_keys)) rep(FALSE, n) else !is.na(fund_keys)
  if (!is.null(fund_selected) && !is.null(fund_keys)) sel <- sel | (fpick & fund_keys == fund_selected)
  cls <- paste0("tm-bar-row", ifelse(pick, " tm-pick", ""), ifelse(fpick, " tm-fund-pick", ""), ifelse(sel, " tm-selected", ""))
  attrs <- paste0(' class="', cls, '"',
                  ifelse(fpick, paste0(' data-fund-key="', esc(fund_keys), '"'), ""),
                  ifelse(pick, paste0(' data-key="', esc(keys), '"'), ""),
                  if (!is.null(input)) ifelse(pick, paste0(' data-input="', esc(input), '"'), "") else "",
                  if (!is.null(tips)) paste0(' data-tip="', esc(tips), '"') else "")
  html <- paste0(
    "<div", attrs, ">",
    if (!is.null(rank)) paste0('<span class="tm-bar-rank">', esc(rank), "</span>") else "",
    '<div class="tm-bar-label"><div class="tm-bar-name">', esc(labels), "</div>",
    if (!is.null(sub)) paste0('<div class="tm-bar-sub">', esc(sub), "</div>") else "", "</div>",
    '<div class="tm-bar-track"><div class="tm-bar" style="', sprintf("width:%.2f%%;background:%s", w, esc(colors)),
    '"></div></div><div class="tm-bar-value">', esc(value_text), "</div></div>", collapse = "")
  shiny::div(class = "tm-bars", htmltools::HTML(html))
}

# One 100% bar split by category, with a legend that carries the numbers.
share_bar <- function(values, colors, names, value_text) {
  total <- sum(values, na.rm = TRUE)
  share <- if (total > 0) values / total else 0 * values
  segments <- lapply(seq_along(values), function(i) {
    shiny::div(class = "tm-share-seg", `data-tip` = sprintf("%s\n%s · %s", names[i], value_text[i],
                                                            format_pct(share[i], sign = FALSE)),
               style = sprintf("flex-basis:%.3f%%;background:%s", 100 * share[i], colors[i]))
  })
  legend <- lapply(seq_along(values), function(i) {
    shiny::div(class = "tm-legend-item",
               shiny::span(class = "tm-swatch", style = sprintf("background:%s", colors[i])),
               shiny::span(class = "tm-legend-name", names[i]),
               shiny::span(class = "tm-legend-value", format_pct(share[i], sign = FALSE)),
               shiny::span(class = "tm-legend-sub", value_text[i]))
  })
  shiny::div(class = "tm-share", shiny::div(class = "tm-share-track", segments),
             shiny::div(class = "tm-legend", legend))
}

# Direction of a change as text (never colour alone).
change_badge <- function(x, suffix = "em 12 meses") {
  if (is.na(x)) return(shiny::span(class = "tm-change", "sem base de comparação"))
  cls <- if (x > 0.0005) "tm-up" else if (x < -0.0005) "tm-down" else "tm-flat"
  arrow <- if (cls == "tm-up") "▲" else if (cls == "tm-down") "▼" else "■"
  shiny::span(class = paste("tm-change", cls), paste(arrow, format_pct(x)), shiny::span(class = "tm-change-sub", suffix))
}

# Client behaviour shared by the Shiny app and the static export: hover
# tooltips for every element with `data-tip`; clickable rows (`.tm-pick`) send
# their `data-key` to the Shiny input `data-input` or, without Shiny (static
# page), show the pre-rendered panel `[data-detail=key]`.
tm_app_script <- function() {
  shiny::tagList(shiny::tags$script(shiny::HTML("
// Nested tabs (tm_fund_tabs): show a tab by its value anywhere on the page,
// opening its parent tabs first; a pane is visible only when every enclosing
// tab pane is active.
window.tmShowTab = function(value) {
  var links = $('a[data-bs-toggle=\"tab\"], a[data-toggle=\"tab\"]');
  var a = links.filter(function() { return $(this).attr('data-value') === value; }).first();
  if (!a.length) return false;
  var chain = [a], pane = a.closest('.tab-pane');
  while (pane.length) {
    var id = '#' + pane.attr('id');
    var up = links.filter(function() { return ($(this).attr('data-bs-target') || $(this).attr('href')) === id; }).first();
    if (!up.length) break;
    chain.unshift(up);
    pane = up.closest('.tab-pane');
  }
  chain.forEach(function(l) { l.tab('show'); });
  return true;
};
window.tmPaneVisible = function(el) { return $(el).parents('.tab-pane').not('.active').length === 0; };
// Tab value of a family's fund list (FIDC has its list and Cedentes inside).
window.tmFamilyTab = function(family) {
  family = String(family).toLowerCase();
  return family === 'fidc' ? 'Fundos FIDC' : family.toUpperCase();
};
$(function() {
  var tip = $('<div>').addClass('tm-tooltip').attr('role', 'tooltip').appendTo('body');
  // A blank line in a tip starts an explanatory note (fund_field_note_text):
  // title in bold, justified paragraphs, period labels in bold, wider box.
  function fill(t) {
    var i = t.indexOf('\\n\\n');
    tip.empty().toggleClass('tm-tooltip-wide', i >= 0);
    if (i < 0) { tip.text(t); return; }
    var lines = t.slice(i + 2).split('\\n'), box = $('<div>').addClass('tm-tip-note');
    tip.append($('<div>').text(t.slice(0, i)));
    box.append($('<div>').addClass('tm-tip-note-title').text(lines[0]));
    lines.slice(1).forEach(function(l) {
      var m = /^([^:]{3,80}):\\s+(.*)$/.exec(l), p = $('<p>');
      if (m) p.append($('<b>').text(m[1] + ':'), document.createTextNode(' ' + m[2])); else p.text(l);
      box.append(p);
    });
    tip.append(box);
  }
  $(document).on('mouseenter', '[data-tip]', function() { fill($(this).attr('data-tip')); tip.show(); })
    .on('mousemove', '[data-tip]', function(e) {
      var w = tip.outerWidth(), x = e.pageX + 14, h = tip.outerHeight(), y = e.pageY + 14, top = $(window).scrollTop();
      if (x + w > $(window).scrollLeft() + $(window).width() - 8) x = e.pageX - w - 14;
      // Long tips (hints, notes) stay inside the window.
      if (y + h > top + $(window).height() - 8) y = Math.max(top + 8, top + $(window).height() - h - 8);
      tip.css({left: x, top: y});
    })
    // Leaving a tipped element inside another one shows the outer tip again.
    .on('mouseleave', '[data-tip]', function(e) {
      var up = $(e.relatedTarget).closest('[data-tip]');
      if (up.length && $.contains(up.get(0), this)) fill(up.attr('data-tip')); else tip.hide();
    })
    .on('click', '.tm-goto[data-tab]', function(e) {
      e.preventDefault();
      window.tmShowTab($(this).attr('data-tab'));
    })
    .on('click', '.tm-chart-pick .tm-hit[data-month]', function() {
      // A month on a clickable chart: the enclosing [data-month-input] gets
      // it (Shiny input, or the event tm:month on the static page).
      var box = $(this).closest('[data-month-input]'), month = $(this).attr('data-month');
      $(this).closest('svg').find('.tm-hit-on').removeClass('tm-hit-on');
      $(this).addClass('tm-hit-on');
      if (window.Shiny && Shiny.setInputValue) {
        Shiny.setInputValue(box.attr('data-month-input'), month, {priority: 'event'});
      } else {
        box.trigger('tm:month', [month]);
      }
    })
    .on('click', '.tm-pick[data-key]', function() {
      if ($(this).closest('.tm-dash').length) return;
      var key = $(this).attr('data-key');
      $(this).siblings('.tm-selected').removeClass('tm-selected');
      $(this).addClass('tm-selected');
      if (window.Shiny && Shiny.setInputValue) {
        Shiny.setInputValue($(this).attr('data-input'), key, {priority: 'event'});
      } else {
        $('[data-detail]').attr('hidden', true);
        $('[data-detail]').filter(function() { return $(this).attr('data-detail') === key; }).removeAttr('hidden');
      }
    });
  // Negative values always in red: every value cell or figure whose text
  // starts with a minus sign (-1.234,56; -3,2%; R$ -1,2 bi) gets tm-neg, also
  // when Shiny or the published page redraws it.
  var NEG = /^\\s*(R\\$\\s*)?[-\\u2212]\\s*\\d/;
  var VALUES = 'td, .tm-num, .tm-kpi-value, .tm-kpi-note, .tm-bar-value, .tm-ficha-value, .tm-big, .tm-legend-value';
  function markNegative(root) {
    var list = root.querySelectorAll ? root.querySelectorAll(VALUES) : [];
    for (var i = 0; i < list.length; i++) list[i].classList.toggle('tm-neg', NEG.test(list[i].textContent));
    if (root.matches && root.matches(VALUES)) root.classList.toggle('tm-neg', NEG.test(root.textContent));
  }
  markNegative(document.body);
  // Current fund (\"family|CNPJ digits\"): the last fund the user selected in
  // any tab. Every tab shows it when opened (each tab script follows
  // window.tmCurrent; in the app the server keeps it too, input current_fund
  // and message tm-current).
  window.tmCurrent = window.tmCurrent || null;
  window.tmSetCurrent = function(key) {
    if (!key || key === window.tmCurrent) return;
    window.tmCurrent = key;
    if (window.Shiny && Shiny.setInputValue) Shiny.setInputValue('current_fund', key, {priority: 'event'});
  };
  window.tmFocusFund = function(el, key) { window.tmSetCurrent(key); };
  if (window.Shiny && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler('tm-current', function(key) { window.tmCurrent = key; });
    Shiny.addCustomMessageHandler('tm-pick-row', function(m) {
      var row = $('.tm-pick[data-key]').filter(function() { return $(this).attr('data-input') === m.input && $(this).attr('data-key') === m.key; });
      row.siblings('.tm-selected').removeClass('tm-selected'); row.addClass('tm-selected');
      if (row[0]) row[0].scrollIntoView({block: 'nearest'});
    });
  }
  $(document).on('click', '.tm-fund-pick[data-fund-key]', function() {
    $(this).closest('.tm-bars').find('.tm-selected').removeClass('tm-selected');
    $(this).addClass('tm-selected');
    window.tmSetCurrent($(this).attr('data-fund-key'));
  });
  var pending = [], queued = false;
  new MutationObserver(function(records) {
    for (var i = 0; i < records.length; i++) {
      var n = records[i].target;
      pending.push(n.nodeType === 1 ? n : n.parentElement);
    }
    if (queued) return;
    queued = true;
    requestAnimationFrame(function() {
      var seen = pending; pending = []; queued = false;
      for (var j = 0; j < seen.length; j++) if (seen[j]) markNegative(seen[j].closest(VALUES) || seen[j]);
    });
  }).observe(document.body, {childList: true, subtree: true, characterData: true});
});")), tm_info_script())
}

# Explanatory popovers of a button .tm-info[data-info] (no characteristic uses
# one now: their hints are hover tooltips, fund_hint_tip_text). The texts come
# from one place (fund_hint_json) as window.TM_INFO, in the app and in the
# published panel, where hintText builds the tooltips from them.

tm_info_script <- function() {
  json <- if (exists("fund_hint_json", mode = "function")) fund_hint_json() else "{}"
  # Relative metrics rules (config/metric_ratio_rules.csv) for the published panel.
  ratios <- if (exists("fund_ratio_rules_json", mode = "function")) fund_ratio_rules_json() else "[]"
  split <- if (exists("fund_peer_split_columns")) jsonlite::toJSON(fund_peer_split_columns) else "[]"
  shiny::tags$script(shiny::HTML(paste0("window.TM_INFO = ", json, ";\nwindow.TM_RATIOS = ", ratios,
                                        ";\nwindow.TM_SPLIT = ", split, ";\n", r"---(
$(function() {
  var pop = null, owner = null;
  function close(back) {
    if (!pop) return;
    pop.remove(); pop = null;
    if (owner) { owner.attr('aria-expanded', 'false'); if (back) owner.trigger('focus'); }
    owner = null;
  }
  function para(t) {
    var m = /^([^:]{2,40}):\s+(.*)$/.exec(t), p = $('<p>');
    if (m) p.append($('<b>').text(m[1] + ':'), document.createTextNode(' ' + m[2])); else p.text(t);
    return p;
  }
  function open(btn) {
    var h = (window.TM_INFO || {})[btn.attr('data-info')];
    if (!h) return;
    close(false);
    owner = btn.attr('aria-expanded', 'true');
    var id = 'tm-info-' + Date.now();
    pop = $('<div>').addClass('tm-info-pop').attr({role: 'dialog', 'aria-labelledby': id, tabindex: '-1'});
    pop.append($('<div>').addClass('tm-info-head').append(
      $('<div>').addClass('tm-info-title').attr('id', id).text(h.title),
      $('<button type="button">').addClass('tm-info-close').attr('aria-label', 'Fechar').text('×')));
    (h.sections || []).forEach(function(s) {
      var sec = $('<section>').append($('<h4>').text(s[0]));
      s[1].forEach(function(t) { sec.append(para(t)); });
      pop.append(sec);
    });
    pop.appendTo('body');
    // Below the button when it fits, else above; inside the window on phones.
    var r = btn[0].getBoundingClientRect(), w = pop.outerWidth(), vw = $(window).width(), vh = $(window).height();
    var left = Math.max(8, Math.min(r.left, vw - w - 8)), top = r.bottom + 6;
    if (top + pop.outerHeight() > vh - 8 && r.top - pop.outerHeight() - 6 > 8) top = r.top - pop.outerHeight() - 6;
    pop.css({left: left, top: Math.max(8, top)});
    pop.trigger('focus');
  }
  $(document).on('click', '.tm-info', function(e) {
    e.preventDefault(); e.stopPropagation();
    var b = $(this);
    if (owner && owner[0] === this) close(true); else open(b);
  }).on('click', '.tm-info-close', function(e) { e.stopPropagation(); close(true); })
    .on('mousedown touchstart', function(e) {
      if (pop && !$(e.target).closest('.tm-info-pop, .tm-info').length) close(false);
    }).on('keydown', function(e) { if (e.key === 'Escape' && pop) close(true); })
    // A button inside a sortable header or a summary must not sort or toggle.
    .on('keydown', '.tm-info', function(e) { if (e.key === 'Enter' || e.key === ' ') e.stopPropagation(); });
  $(window).on('resize scroll', function() { close(false); });
  // FICHA tab, Distribuições: every chart on one screen, no scrollbar. The grid
  // takes the number of columns that gives the largest chart (viewBox 200 x 64)
  // in the room left below the caption and the highlights; recomputed when the
  // matrix is drawn, the tab is shown and the window is resized (app and site).
  function scrollBox(el) {
    for (var p = el.parentElement; p && p !== document.body; p = p.parentElement) {
      var o = getComputedStyle(p).overflowY;
      if (o === 'auto' || o === 'scroll' || p.classList.contains('tm-dist-fit-box')) return p;
    }
    return null;
  }
  var FIT_MAX = 54;
  function fitDist(grid) {
    // One cell size for any number of charts: the grid is laid out for FIT_MAX
    // charts; more than that scroll vertically, with the same size.
    var box = scrollBox(grid), n = grid.children.length, N = FIT_MAX;
    if (!box || !n || !box.offsetHeight || !grid.offsetParent) return;
    box.classList.add('tm-dist-fit-box'); grid.classList.add('tm-dist-fit');
    box.classList.toggle('tm-dist-fit-scroll', n > N);
    box.scrollTop = 0;
    var gap = 6, chrome = 26, W = grid.clientWidth,
        H = box.getBoundingClientRect().bottom - grid.getBoundingClientRect().top - 4, best = null;
    for (var c = 1; c <= 24; c++) {
      var rows = Math.ceil(N / c), w = (W - gap * (c - 1)) / c, h = (H - gap * (rows - 1)) / rows;
      var k = Math.min((w - 10) / 200, (h - chrome) / 64);
      if (!best || k > best.k) best = {k: k, c: c, h: h};
    }
    grid.style.gridTemplateColumns = 'repeat(' + best.c + ', minmax(0, 1fr))';
    grid.style.gridAutoRows = Math.max(chrome + 12, Math.floor(best.h)) + 'px';
    grid.style.gap = gap + 'px';
  }
  var fitQueued = false;
  function fitAll() {
    if (fitQueued) return;
    fitQueued = true;
    setTimeout(function() {
      fitQueued = false;
      document.querySelectorAll('.tm-dist-fit-box').forEach(function(b) { var g = b.querySelector('.tm-dist-grid'); if (!g || !g.offsetParent) b.classList.remove('tm-dist-fit-box'); });
      document.querySelectorAll('.tm-record .tm-dist-grid, .tm-static-record .tm-dist-grid').forEach(fitDist);
    }, 60);
  }
  window.tmFitDist = fitAll;
  new MutationObserver(function() {
    if (document.querySelector('.tm-record .tm-dist-grid, .tm-static-record .tm-dist-grid')) fitAll();
  }).observe(document.body, {childList: true, subtree: true});
  $(window).on('resize', fitAll);
  $(document).on('shown.bs.tab click', '.tm-record .nav-link, .tm-static-record .nav-link, .tm-record a, .tm-static-record a', fitAll);
  // Relativo / Absoluto beside the tab Distribuições: choosing either one also
  // selects and shows that tab (native click on its link, the bslib handler).
  $(document).on('click', '.tm-dist-mode .radio-inline, .tm-dist-mode input[type=radio]', function() {
    var a = $(this).closest('.nav').find('a[data-value="Distribuições"]');
    if (a.length && !a.hasClass('active')) a.get(0).click();
  });
});
)---")))
}

# Navbar brand: white emblem (rfb_emblem.png, cropped from the supplied logo), a thin rule,
# the word "Analytics" as text and a bar-chart icon in SVG (sharp at any resolution).
# The same markup is in site/app/index.html.
# Fundos area: "Todos" (all funds), then one sub tab per fund type; FIDC holds
# its fund list and Cedentes. Tab values: "Todos", "FIDC", "Fundos FIDC",
# "Cedentes", "FII", "FIP", "FIAGRO" (window.tmShowTab, tmFamilyTab).
# all_ui: the all-funds tab; family_ui: named list (fidc, fii, ...); cedentes: the
# Cedentes area.
tm_fund_tabs <- function(all_ui, family_ui, cedentes) {
  # Nested navsets do not fill on their own: the tabbable, its tab-content and
  # its own panes (not the tabs inside the content) become fill containers, so
  # the fund lists keep their inner scroll.
  fill <- function(nav) {
    tq <- htmltools::tagQuery(nav)
    content <- tq$children(".tab-content")
    content$children(".tab-pane")$addClass("html-fill-item html-fill-container")
    content$addClass("html-fill-item html-fill-container")
    htmltools::bindFillRole(tq$allTags(), container = TRUE, item = TRUE)
  }
  panels <- lapply(names(family_ui), function(f) {
    body <- if (f == "fidc") {
      fill(bslib::navset_underline(
        id = "fidc_nav",
        bslib::nav_panel("Fundos FIDC", family_ui[[f]]),
        bslib::nav_panel("Cedentes", cedentes)))
    } else family_ui[[f]]
    bslib::nav_panel(toupper(f), body)
  })
  fill(do.call(bslib::navset_underline, c(list(id = "fund_nav", bslib::nav_panel("Todos", all_ui)), panels)))
}

tm_brand <- function() shiny::HTML('<span class="tm-brand" role="img" aria-label="Analytics"><img src="rfb_emblem.png" alt="" class="tm-brand-emblem"/><span class="tm-brand-rule"></span><span class="tm-brand-name">Analytics</span><svg class="tm-brand-bars" viewBox="0 0 20 18" aria-hidden="true"><rect x="0" y="10" width="5" height="8" rx="1.2"/><rect x="7.5" y="5" width="5" height="13" rx="1.2"/><rect x="15" y="0" width="5" height="18" rx="1.2"/></svg></span>')

# Visual theme of the app and the static export (system fonts only).
tm_theme <- function() {
  bslib::bs_theme(
    version = 5, bg = "#ffffff", fg = "#1c2430", primary = "#0b1f3a", secondary = "#5b6573",
    base_font = bslib::font_collection("Segoe UI", "Helvetica Neue", "Arial", "sans-serif"),
    heading_font = bslib::font_collection("Georgia", "Times New Roman", "serif"),
    "border-radius" = "2px", "font-size-base" = "0.715rem")
}
