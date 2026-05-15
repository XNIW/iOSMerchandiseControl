# TASK-109 — 103 Review UX/UI/Accessibility

Review pass: 2026-05-15 02:25 -0400

## Runtime verificato

Simulator: iPhone 15 Pro Max iOS 26.1, app build Debug installata con XcodeBuildMCP.

Screenshot review:

- `screenshots/109-review-runtime-inventory-launch.jpg`
- `screenshots/109-review-options-signed-out-history-zero-after-seed.jpg`

## UX verificata

- Inventory launch resta navigabile.
- Options e' raggiungibile durante stato non autenticato.
- Signed-out/account issue state e' chiaro: `Account needs attention`, CTA `Sign in`.
- Local database status espone conteggi locali e include `History sessions, 0`.
- La UI signed-out non apre Review stale/no-op e non mostra doppio Cancel.

## Miglioramento applicato

Copy pubblica:

- Prima: `Fetching cloud counts...`
- Dopo: `Checking cloud updates...`

File localizzati:

- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

Motivo: evitare copy tecnico/contabile nella UI Release.

## Accessibility/static audit

- `snapshot_ui` mostra labels leggibili per Options, Sign in, local database status e conteggi.
- `plutil -lint` PASS su EN/IT/ES/ZH.
- Dynamic Type XXXL resta coperto da evidence execution esistente (`42-accessibility-localization.md`, `final-dynamic-type-xxxl-*`), non rieseguito come full VoiceOver session.

## Limite bloccante

La UI History non-empty non e' stata verificata runtime perche' il simulator corrente e' signed-out dopo rebuild/install; senza app-auth non puo' pullare la riga Supabase test.
