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
                           values2 = NULL, format_value2 = axis_int, color2 = "#5b6573", pick = FALSE) {
  ok <- !is.na(months)
  months <- months[ok]; values <- values[ok]; if (!is.null(tips)) tips <- tips[ok]
  if (!is.null(values2)) values2 <- values2[ok]
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
    sprintf('<g class="tm-hit"%s data-tip="%s"><rect x="%.1f" y="%.1f" width="%.1f" height="%.1f"/><line class="tm-cross" x1="%.1f" x2="%.1f" y1="%.1f" y2="%.1f"/>%s%s</g>',
            if (pick) sprintf(' data-month="%s"', months[i]) else "", html_attr(tips[i]), edges[i], mt, max(1, edges[i + 1] - edges[i]), ph, px[i], px[i], mt, mt + ph, dot, dot2)
  }, character(1))

  htmltools::HTML(sprintf(
    '<svg class="tm-chart%s" viewBox="0 0 %d %d" role="img" aria-label="%s">%s%s%s%s%s%s%s%s</svg>',
    if (pick) " tm-chart-pick" else "", width, height, html_attr(label), paste(grid, collapse = ""), paste(right, collapse = ""),
    paste(xaxis, collapse = ""), paste(fills, collapse = ""), paste(lines2, collapse = ""),
    paste(lines, collapse = ""), end, paste(hits, collapse = "")))
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
  shiny::tags$script(shiny::HTML("
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
      var w = tip.outerWidth(), x = e.pageX + 14;
      if (x + w > $(window).scrollLeft() + $(window).width() - 8) x = e.pageX - w - 14;
      tip.css({left: x, top: e.pageY + 14});
    })
    .on('mouseleave', '[data-tip]', function() { tip.hide(); })
    .on('click', '.tm-goto[data-tab]', function(e) {
      e.preventDefault();
      var t = $(this).attr('data-tab');
      $('.navbar a[data-bs-toggle=\"tab\"]').filter(function() { return $(this).attr('data-value') === t; }).first().click();
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
});"))
}

# Navbar brand: white emblem (rfb_emblem.png, cropped from the supplied logo), a thin rule,
# the word "Analytics" as text and a bar-chart icon in SVG (sharp at any resolution).
# The same markup is in site/app/index.html.
tm_brand <- function() shiny::HTML('<span class="tm-brand" role="img" aria-label="Analytics"><img src="rfb_emblem.png" alt="" class="tm-brand-emblem"/><span class="tm-brand-rule"></span><span class="tm-brand-name">Analytics</span><svg class="tm-brand-bars" viewBox="0 0 20 18" aria-hidden="true"><rect x="0" y="10" width="5" height="8" rx="1.2"/><rect x="7.5" y="5" width="5" height="13" rx="1.2"/><rect x="15" y="0" width="5" height="18" rx="1.2"/></svg></span>')

# Visual theme of the app and the static export (system fonts only).
tm_theme <- function() {
  bslib::bs_theme(
    version = 5, bg = "#ffffff", fg = "#1c2430", primary = "#0b1f3a", secondary = "#5b6573",
    base_font = bslib::font_collection("Segoe UI", "Helvetica Neue", "Arial", "sans-serif"),
    heading_font = bslib::font_collection("Georgia", "Times New Roman", "serif"),
    "border-radius" = "2px", "font-size-base" = "0.715rem")
}
