# TASK-111 — 00 Preflight / Tracking

Data: 2026-05-17 12:20 -0400  
Agente: CURSOR / Executor  
Fase: ACTIVE / EXECUTION (user override end-to-end)

## OBSERVED — Letture iniziali obbligatorie

- Letto `docs/MASTER-PLAN.md` iOS.
- Letto `docs/TASKS/TASK-111-excel-analysis-parity-ios.md`.
- Letto `docs/TASKS/EVIDENCE/TASK-111/README.md`.
- Letto `AGENTS.md` iOS e `docs/CODEX-EXECUTION-PROTOCOL.md`.
- Letto `docs/MASTER-PLAN.md` Android come contesto iniziale; il file TASK-111 non esiste nel repo Android ed e' presente nel repo iOS.

## OBSERVED — Stato tracking

- `TASK-111`: ACTIVE / EXECUTION per override utente 2026-05-17.
- Responsabile: CURSOR / Executor.
- `TASK-109`: BLOCKED / SOSPESO, non ripreso e non marcato DONE.
- `TASK-110`: DONE / Chiusura — FINAL CROSS-PLATFORM ACCEPTANCE PASS, non riaperto.
- Esito finale ammesso per questo pass: ACTIVE / REVIEW oppure ACTIVE / FIX; non DONE.

## OBSERVED — Git preflight

### iOS target

- Path: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Branch corrente: `main`
- HEAD: `b710595`
- Remote: `origin https://github.com/XNIW/iOSMerchandiseControl.git`
- Worktree iniziale dirty:
  - `M docs/MASTER-PLAN.md`
  - `?? docs/TASKS/EVIDENCE/TASK-111/`
  - `?? docs/TASKS/TASK-111-excel-analysis-parity-ios.md`
- Classificazione dirty state: modifiche documentali/governance TASK-111 preesistenti all'execution corrente; trattate come baseline corrente, senza revert.

### Android riferimento funzionale

- Path: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- Branch corrente: `main`
- HEAD: `ca3104b`
- Remote: `origin https://github.com/XNIW/MerchandiseControlSplitView.git`
- Worktree iniziale: clean secondo `git status --short`.

### Supabase locale

- Path indicato: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- OBSERVED: directory presente, ma senza `.git` nel root; contiene `supabase/`, `sql/`, `docs/`, `TASKS/` e materiali locali.
- Classificazione: riferimento locale/documentale disponibile; non usato per mutation in preflight.

## OBSERVED — Stato MASTER-PLAN

- Prima dell'override, MASTER-PLAN iOS indicava TASK-111 ACTIVE / PLANNING-REFINEMENT e vietava execution senza prompt esplicito.
- Il prompt utente corrente e' il prompt esplicito di override per EXECUTION end-to-end.
- MASTER-PLAN aggiornato a TASK-111 ACTIVE / EXECUTION, mantenendo TASK-109 BLOCKED / SOSPESO e TASK-110 DONE.

## ASSUMED — Vincoli operativi recepiti

- iOS e' il target da modificare.
- Android e' riferimento funzionale, non layout da copiare.
- Nessun porting Kotlin -> Swift 1:1.
- SwiftUI/SwiftData nativi, UX Apple-native.
- No service_role nel client.
- No token/JWT/email/dati sensibili in log/evidence.
- Prima di delete/reset ampi Supabase: snapshot/evidence e scope test/owner/dev verificato.
- Prefisso dati test eventuale: `TASK111_*`.
- Supabase non va riaperto come TASK-109 implicito; sync solo se indispensabile e sicura.
- Non marcare DONE.

## ASSUMED — Classificazione dati Supabase

- Dati test/dev utilizzabili: solo se necessari a validazioni realistiche, con prefisso `TASK111_*` o owner/dev verificato.
- Dati reali/commerciali: non usati e non stampati.
- Operazioni destructive: NOT_RUN in preflight; richiedono evidence/safety gate dedicato.
- In questo preflight: nessuna mutation Supabase.

## ASSUMED — Piano onde execution

1. Wave 0: tracking/preflight/evidence bootstrap.
2. Wave 1: audit iOS/Android/Supabase e compilazione evidence `01`-`10`, matrice M1-M28 e priorita'.
3. Wave 2: implementazione micro-slice P0/Critical su parser/header/numeri/prezzi/duplicati/apply/performance.
4. Wave 3: UX/UI iOS-native ImportAnalysis/PreGenerate/Generated e polish accessibilita'.
5. Wave 4: fixture sintetiche, XCTest mirati, regressione, build e smoke simulator dove possibile.
6. Wave 5: performance/stabilita', privacy scan, handoff finale a REVIEW o FIX.

## NOT_RUN / BLOCKED

- Supabase read/write/delete: NOT_RUN in preflight; non necessario prima dell'audit.
- Build/test runtime: NOT_RUN in preflight; verranno eseguiti dopo audit/implementation.
- Simulator smoke: NOT_RUN in preflight; previsto dopo build/test se ambiente disponibile.

