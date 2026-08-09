# TASK-141 iOS — re-review 02

- Data: `2026-08-09`
- Ruolo: `CODEX_RE_REVIEWER`
- Verdict: `CHANGES_REQUIRED`
- Baseline: `c1b7b706c5f05cd7e8dda74cea1122f6483df7ec`
- Branch: `agent/mobile-catalog-data-integrity-20260809`

## Finding

`R2-I141-01` — `P1`: `groupedInteger` usa un gruppo `[.,]` ripetibile senza
vincolare lo stesso separatore. Nel ramo `.price` precede i pattern decimal:

- `1.234,567` produce `1234567.0`, atteso `1234.567`;
- `1,234.567` produce `1234567.0`, atteso `1234.567`;
- lo stesso input `.quantity` produce correttamente `1234.567`.

Correzione richiesta: grouped integer solo con separatore coerente e test price
per entrambe le forme mixed grouped-decimal.

## Gate autonomi

- focused unit/localization: `PASS`, 7/7;
- XCUITest no-insert/persistence: `PASS`, 1/1;
- Release seam e hygiene: `PASS`;
- il conteggio fixer `17/17` appartiene al comando combinato parser +
  localizzazione e resta distinto dal rerun reviewer 7/7.

Handoff: `CODEX_REVIEW_CHANGES_REQUIRED_TO_FIX`. Nessun security scan, Client,
release train, Supabase o produzione toccati.
