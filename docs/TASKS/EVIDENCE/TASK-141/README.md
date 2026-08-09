# TASK-141 evidence — iOS

- Baseline: `c1b7b706c5f05cd7e8dda74cea1122f6483df7ec`
- Branch: `agent/mobile-catalog-data-integrity-20260809`
- Scope: product numeric input safety e truthful duplicate-barcode import copy.
- Baseline build Simulator Debug: `PASS`, exit `0`.
- Baseline localizations: `1701` chiavi per lingua, differenze `0`.
- Client TASK-033: `NOT_MODIFIED`.
- Production/Supabase/secrets/deploy: `NOT_MODIFIED`.

## Matrice criteri → evidence

| Criterio | Esito | Evidence |
|---|---|---|
| I-141-01 | `PASS` | `Task141NumericInputTests` e XCUITest no-insert/persistence; ogni nonblank invalid/negative blocca la mutazione. |
| I-141-02 | `PASS` | Parser field-aware `.price`/`.quantity`, boundary CL a tre cifre, mixed grouping/decimal e whitespace malformed. |
| I-141-03 | `PASS` | Errori inline localizzati con accessibility identifier; visual QA Simulator stato invalid/negative. |
| I-141-04 | `PASS` | `LocalizationCoverageTests` e copy IT/EN/ES/ZH-Hans allineata a last-row-wins/no-sum. |
| I-141-05 | `PASS` | Nessuna dipendenza/API/schema; seam reset solo `DEBUG`; sync e product-image ownership invariati. |
| I-141-06 | `PASS` | Focused/full test, Debug test build, Release build, Analyze, localizzazioni e visual QA sotto. |
| I-141-07 | `PASS` | Audit repository/worktree: Client TASK-033 e release train non modificati. |

## Gate post-fix

| Tipo | Comando | Risultato |
|---|---|---|
| Focused XCTest | `xcodebuild ... -only-testing:iOSMerchandiseControlTests/Task141NumericInputTests -only-testing:iOSMerchandiseControlTests/LocalizationCoverageTests test` | `PASS`, 17/17, 0 failure/skip. |
| XCUITest persistence | `xcodebuild ... -only-testing:iOSMerchandiseControlUITests/CatalogTextImportUITests/testInvalidSaveDoesNotInsertAndChileQuantityPersistsExactValue test` | Tentativi 1–4 `FAIL` durante hardening locator/reset harness; tentativo finale `PASS`, 1/1. |
| Full XCTest/XCUITest | `xcodebuild -quiet ... -resultBundlePath .../ios-task141-fix-full.xcresult test` | `PASS`, 1323 totali, 1288 pass, 35 skip, 0 failure, iPhone 17 Pro Simulator iOS 26.5. |
| Analyze | `xcodebuild ... -configuration Debug ... analyze` | `PASS`, exit `0`; 2 analyzer issue nel vendorizzato `Vendor 2/libxls`, 0 nei file TASK-141. |
| Release build | `xcodebuild -quiet ... -configuration Release ... build` | `PASS`, exit `0`; warning debug-symbol PCM mancanti non bloccanti. |
| Localizzazioni | `plutil -lint` sulle quattro `Localizable.strings` + conteggio chiavi | `PASS`, 4/4 valide e 1705 chiavi per lingua. |
| Diff hygiene | `git diff --check` | `PASS`, exit `0`. |
| Visual QA | avvio Simulator + screenshot stato invalido | `PASS`, quantità negativa e purchase malformed visibili senza crop/overlap. |

## Limiti

- Physical device, VoiceOver e camera reale: `NOT_RUN`.
- Nessun Deep Security Scan o security scan sostitutivo è stato avviato.
- Nessun artifact `.xcresult`, DerivedData o screenshot è versionato.

## Review indipendente

- `review-01-changes-required.md` — verdict `CHANGES_REQUIRED`, finding
  riproducibili, gate indipendenti e limiti della review.
- `review-02-changes-required.md` — re-review `CHANGES_REQUIRED`: grouped integer
  con separatori misti prevale erroneamente sul grouped decimal nel parser price.
- `review-03-approved.md` — re-review finale `APPROVED`: finding
  `R2-I141-01` risolto, gate autonomi e artifact post-fix verificati.
- Lo snapshot revisionato conservava ancora il placeholder executor sopra; il
  verdict e la transizione `REVIEW -> FIX` sono registrati nel file task senza
  alterare retroattivamente l'evidence executor.

## Fix evidence — 2026-08-09

| Finding | Stato fixer | Evidence |
|---|---|---|
| Ambiguità quantità CL | `FIXED_PENDING_RE_REVIEW` | Parser field-aware e boundary XCTest. |
| Whitespace malformed | `FIXED_PENDING_RE_REVIEW` | Fail-closed su spazio/newline/tab con regressione. |
| Mutation/persistence non provata | `FIXED_PENDING_RE_REVIEW` | XCUITest no-insert + correzione + reopen/persistence. |
| Tracking placeholder | `FIXED_PENDING_RE_REVIEW` | Fix/gate/handoff reali registrati senza riscrivere la Review precedente. |

Handoff re-review: `CODEX_REVIEW_CHANGES_REQUIRED_TO_FIX`.

## Fix evidence R2-I141-01 — 2026-08-09

| Finding | Stato fixer | Evidence |
|---|---|---|
| `R2-I141-01` mixed separator price precedence | `FIXED_PENDING_RE_REVIEW` | Pattern grouped integer separati per `.`/`,`; regressioni mixed grouped-decimal + grouped integer coerente; targeted 17/17, full 1323/0 failure, Analyze/Release/localizzazioni/diff `PASS`. |

Handoff fixer finale: `CODEX_FIX_COMPLETE_TO_RE_REVIEW`.

## Re-review finale — 2026-08-09

- Verdict: `APPROVED`.
- `R2-I141-01`: `VERIFIED_RESOLVED`.
- Rerun autonomo reviewer `Task141NumericInputTests`: `PASS`, 6/6, 0
  failure/skip.
- `git diff --check`: `PASS`; localizzazioni `plutil` 4/4, 1705 chiavi per
  lingua.
- Artifact finali ispezionati: targeted fixer 17/17, precedente reviewer 7/7
  distinto, full 1323 = 1288 pass + 35 skip, XCUITest finale 1/1.
- Analyze/Release post-fix: `PASS`; il log Analyze contiene 27 warning fuori
  dai file TASK-141 e 0 nei file toccati.
- Task invariato `ACTIVE / REVIEW`; handoff
  `CODEX_REVIEW_APPROVED_AWAITING_USER_CONFIRMATION`.
