# TASK-111 — 04 Parity Matrix M1–M28

Legenda: P0/P1/P2; Critical/High/Medium/Low; Ladder L0 planning, L1 observed, L2 implemented/tested locally, L3 regression-guarded, L4 review accepted.

| ID | Stato iOS | Stato Android | Gap | Pri/Sev | File/evidence | Decisione | Slice | Regression guard |
|---|---|---|---|---|---|---|---|---|
| M1 `.xlsx` read | L3 | L3 | Nessun P0 | P1/Medium | `ExcelSessionViewModel.swift:1275`; Task100/105 PASS | Mantieni | S111-A | Task100, Task105 |
| M2 `.xls` legacy | L1 | L2 | Runtime non rieseguito | P2/Medium | `ExcelLegacyReader.m`; build PASS | No patch | S111-A | Build bridge |
| M3 HTML Excel | L3 | L2 | Fixture TASK-111 aggiunta | P1/Medium | `ExcelAnalyzerHTMLParsingTests` 9 PASS; TASK111 HTML PASS | Mantieni | S111-A/G | HTML tests |
| M4 Header canonical alias | L3 | L3 | Core iOS aveva alias meno robusti outside analyzer | P0/High | `ProductImportCore.swift:512` | Implementato local aliases | S111-A | Task111 tests |
| M5 Header duplicate | L2 | L2 | No file-level warning model iOS | P2/Low | `ProductImportCore.swift:493` | Keep first non-empty, no crash | S111-A | Task111/HTML |
| M6 Title/footer/subtotal | L3 | L3 | Nessun P0 | P1/Medium | HTML tests; analyzer filters | Mantieni | S111-A | ExcelAnalyzerHTML |
| M7 Numeric locale/currency | L3 | L2 | iOS core fragile | P0/Critical | `ProductImportCore.swift:33` | Implementato | S111-B | Task111 locale test |
| M8 Percent discount 0–1 | L3 | L2 | iOS missing | P0/High | `ProductImportCore.swift:614` | 0<value<1 => percent | S111-B | Task111 discount |
| M9 discountedPrice precedence | L3 | L3 | iOS missing | P0/High | `ProductImportCore.swift:413` | discountedPrice wins | S111-B | Task111 duplicate |
| M10 quantity vs realQuantity | L3 | L3 | iOS missing | P0/High | `ProductImportCore.swift:591` | realQuantity >0 preferred; duplicate sum | S111-B/C | Task111 duplicate |
| M11 old/current purchase | L3 | L3 | iOS ProductDraft missing old price | P0/High | `ImportAnalysisView.swift:12`; `ProductImportCore.swift:268` | Added old/current history | S111-B/E | Task111 history |
| M12 old/current retail | L3 | L3 | Same | P0/High | same | Added | S111-B/E | Task111 history |
| M13 barcode required | L3 | L3 | Already partial | P0/Critical | `ProductImportCore.swift:75` | Preserved | S111-C | Task111 validation |
| M14 name required | L3 | L3 | iOS missing | P0/High | `ProductImportCore.swift:377` | Added productName/secondName validation | S111-C | Task111 validation |
| M15 purchase non-negative | L3 | L3 | iOS missing | P0/High | `ProductImportCore.swift:417` | Added | S111-C | Task111 validation |
| M16 retail >0 when required | L3 | L3 | iOS missing | P0/High | `ProductImportCore.swift:438` | New product required, update if provided | S111-C | Task111 validation |
| M17 quantity non-negative | L3 | L3 | iOS missing | P0/High | `ProductImportCore.swift:423` | Added | S111-C | Task111 validation |
| M18 discount 0–100 | L3 | L3 | iOS missing | P0/High | `ProductImportCore.swift:410` | Added | S111-C | Task111 validation |
| M19 duplicate barcode policy | L3 | L3 | iOS had warning but lacked total/policy UX | P0/High | `ProductImportCore.swift:115`; `ImportAnalysisView.swift:93` | Warning + last row + qty sum | S111-C/D | Task111 duplicate |
| M20 row errors/warnings export | L3 | L2 | Warnings export missing | P1/Medium | `ImportAnalysisView.swift:863`, `:907` | Added export warnings | S111-C/D | Build + UI smoke |
| M21 CTA valid rows with errors | L3 | L3 | Toolbar only | P1/Medium | `ImportAnalysisView.swift:421` | Sticky CTA enabled by valid rows | S111-D | Build/smoke |
| M22 inline edit native | L3 | L2 | Existing Form, old prices lost on edit | P1/Medium | `ImportAnalysisView.swift:1034` | Preserved old price fields | S111-D/E | Build |
| M23 Supplier/category resolver | L3 | L3 | iOS case-sensitive duplicates | P0/High | `ProductImportCore.swift:828` | Case/diacritic insensitive | S111-E | Task111 resolver |
| M24 side-effect-free preview | L3 | L2 | Needed proof | P0/High | Task111 side-effect-free test | Verified | S111-E | XCTest |
| M25 apply atomic/recovery | L2 | L3 | SwiftData no explicit Room transaction equivalent | P1/Medium | `DatabaseView.swift:577`; context rollback paths | Document recovery; no migration | S111-E | Build/regression |
| M26 performance/MainActor | L3 | L3 | Risk from core parser | P1/High | `DatabaseView.swift:380`, `:577`; Task100 PASS | Kept background/chunking | S111-F | Task100 medium |
| M27 cancel/progress | L2 | L3 | Not newly tested | P2/Medium | `Task.checkCancellation` in analyzer/pipeline | No patch | S111-F | Existing architecture |
| M28 Supabase/sync interplay | L2 | L2 | No live mutation | P2/Medium | `03-supabase-impact-map.md` | No sync reopen | S111-H | No service_role/no mutation |

## Verdict matrix

OBSERVED: P0/Critical gaps in parser/numeric/validation/duplicates/apply history were implemented and covered by XCTest.  
INFERRED: L4 cannot be claimed until REVIEW accepts. Current claim ceiling: L3 for covered local behavior, L2 for `.xls`, cancel, Supabase interplay.
