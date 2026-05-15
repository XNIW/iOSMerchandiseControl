# TASK-109 — 107 Review Code Quality Fixes

Review pass: 2026-05-15 02:25 -0400

## Fix 1 — defer History sync until prepared apply completes

File:

- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`

Motivo:

- Durante review e' emerso un edge case nel direct/root sync: se il dry-run prepara un apply catalog/prezzi, History non deve sincronizzarsi prima del commit locale principale.

Impatto:

- Evita doppio lavoro e ordine fragile.
- Mantiene History sync nel path post-apply quando c'e' staged apply.
- Mantiene History sync immediato per no-op/catalog-price clean direct sync.

Test:

- `SupabaseManualSyncViewModelTests.testDirectSyncDefersHistoryUntilPreparedApplyCompletes`

## Fix 2 — copy Release meno tecnica

File:

- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

Motivo:

- `Fetching cloud counts...` esponeva un dettaglio tecnico/contabile nella UI pubblica.

Impatto:

- Copy piu' coerente: `Checking cloud updates...`.
- Localizzazioni mantenute in EN/IT/ES/ZH.

## Scan qualita'

- Nessun nuovo file debug/release harness trovato nel path Release.
- `git diff --check`: PASS.
- `plutil -lint` localizzazioni: PASS.
- Scan `service_role`/secret: solo guard/test sanitization gia' esistenti; nessun secret client nuovo.

## Note

- Non sono stati introdotti refactor strutturali o dipendenze.
- `SupabaseManualSyncReleaseHistorySessionAdapter` era gia' su background `ModelContext`; nessuna patch necessaria li'.
