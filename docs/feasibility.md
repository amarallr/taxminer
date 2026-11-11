# Collection feasibility (Collect P01)

> Phase numbers follow `decision_0025`: consultation decisions are Phase 1.1 and financial notes Phase 1.2.

Based on the probe run of 2026-11-10 (`docs/source_inventory.md`). Status:
proposed; the developer must approve the strategy before Collect P02.

**Suspended on 2026-11-10** by the developer (`decision_0020`): Phase 1.2 goes
first. The decisions below stay open; nothing here is withdrawn.

## Feasibility matrix

| Source / content | Access | Volume (reported) | Format | Feasible for MVP Phase 1.1? |
|---|---|---|---|---|
| Normas search: metadata + ementa of SC, SCI, SD | Works with small rate-limited requests; undocumented internal API; no robots.txt | SC 15,880; SCI 259; SD 374 | JSON + HTML ementa | **Yes**, for a bounded sample, subject to the developer's approval of using an undocumented endpoint |
| Act viewer: full text | Automated access refused (HTTP 403) | unknown | unknown | **No** by automation. Needs an authorized channel |
| RFB open data | No dataset found | — | — | No |
| CVM DFP/ITR open data (Phase 1.2) | Open, ODbL, crawl delay 10 s | 17 yearly ZIPs per form | ZIP/CSV | Yes for structured statements; notes to be checked in Collect P04 |

## Coverage and denominators

The Normas search reports totals per type and publication year, which gives
the denominator for discovery accounting (`docs/requirements.md`: 100% of
discovered entries with a terminal outcome). These totals are the source's own
numbers; TaxMiner will compare them with what it actually retrieves and
report differences. Historical completeness before the earliest year present
in the index is unknown.

## Full-text strategy

The architecture already separates ementa-only records from full-text
documents, so Phase 1.1 can proceed on ementa + metadata. Options for full text:

1. **Request authorized access** (recommended, in parallel): ask the RFB
   (Cosit / Normas team, or a request under the access-to-information law via
   Fala.BR) whether automated reading of `consulta-externa` or a bulk export of
   public Soluções de Consulta is permitted. TaxMiner does not send the request
   itself; the developer decides and files it.
2. **Manual retrieval for a small subset**: the developer opens selected acts
   in the browser and saves them as public fixtures, recording URL and date.
   Legal and within terms; does not scale.
3. **Ementa-only MVP**: search and citations over ementas, with each result
   linking to the official viewer for the full text. Full text marked as
   `not_acquired` with the reason.

## Proposed Phase 1.1 sample (up to 100 acts)

Ementa + metadata from the Normas search API, stratified by publication year
and issuing unit, using only the reported totals as the sampling frame:

| Stratum | Acts |
|---|---:|
| Solução de Consulta, 2024–2025, Cosit | 25 |
| Solução de Consulta, 2024–2025, Disit (regional units) | 25 |
| Solução de Consulta, 2015, mixed units | 20 |
| Solução de Consulta, 2005–2010, mixed units | 15 |
| Solução de Divergência, any year | 10 |
| Solução de Consulta Interna, any year | 5 |

Selection: first pages ordered by the source, page size ≤ 20, at least 5 s
between requests (about 6 requests in total). Each act gets a manifest entry
with `idAto`, source URL, retrieval time, response SHA-256 and outcome. Full
text: option 3 by default; options 1 and 2 if the developer chooses.

## Risks and limits

- The search API is undocumented and may change without notice; the probe
  script records the JavaScript-observed contract so changes are detectable.
- Using an undocumented endpoint is an access-policy decision for the
  developer, even though it serves the same public data as the portal.
- A 403 means stop. The pipeline must not retry with browser-like headers.

## Decisions needed before Collect P02

1. Approve (or reject) using the Normas search API for the ementa sample.
2. Choose the full-text option: 1, 2, 3 or a combination.
3. Approve the sample above or adjust the strata.
