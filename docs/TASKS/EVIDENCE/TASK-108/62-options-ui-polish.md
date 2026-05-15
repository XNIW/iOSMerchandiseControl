# TASK-108 — Options UI polish

Date: 2026-05-14 14:24 -0400  
Executor: Codex

## Before

- Riferimenti before esistenti:
  - `docs/TASKS/EVIDENCE/TASK-108/screenshots/2026-05-13-options-before-cloud-account.jpg`
  - `docs/TASKS/EVIDENCE/TASK-108/screenshots/22-options-before-card-still-rough.jpg`

## After

- Screenshot after:
  - `docs/TASKS/EVIDENCE/TASK-108/screenshots/2026-05-14-options-account-polish-after.jpg`

## Fix UI applicati

- Card signed-out:
  - icona cambiata da `person.crop.circle.badge.xmark` grigia a `person.crop.circle.badge.plus`;
  - icona inserita in box 36x36 con tinta blu soft;
  - colore signed-out passato a blu, non error/disabled;
  - CTA `Accedi` mantiene icon+text con spacing stabile.
- Bottone `Riprova` / azioni Release:
  - label ora e' `HStack` centrato con icona opzionale e testo `multilineTextAlignment(.center)`;
  - contenuto full-width centrato nella button label.
- Card running:
  - nessun cambio invasivo; il progress model continua a esporre `allowsLocalWork`, e gli update sono ora throttled per evitare flicker/invalidazioni eccessive.
- Local database status:
  - mantenuto invariato; lo smoke mostra conteggi e card non coperti dalla tab bar.
- Developer diagnostics:
  - resta collassata.

## Localizzazioni / Dynamic Type

- Nessuna nuova chiave di localizzazione introdotta.
- `plutil -lint` EN/IT/ES/ZH: PASS.
- Dynamic Type esteso non rieseguito in questo pass; layout statico usa `ViewThatFits`, `fixedSize(vertical:)` e label multiline centered.

## Smoke visivo

- Simulator iPhone 17 Pro iOS 26.5, lingua IT.
- Options scroll smoke: PASS.
- Signed-out state: PASS visivo; non e' stata completata auth live.

