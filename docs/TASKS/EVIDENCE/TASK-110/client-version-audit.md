# TASK-110 — Client Version Audit

Checkpoint: 2026-05-15 12:15 -0400.

## iOS
- Repository remoto verificato: `https://github.com/XNIW/iOSMerchandiseControl`
- `git fetch origin main` eseguito.
- `origin/main` = commit locale base `d4a0f89`.
- Nessuna differenza codice rispetto alla versione GitHub più aggiornata al preflight.
- Branch execution locale: `codex/task-110-sync-consistency`.

## Android
- Repository locale riferimento: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- Worktree clean al preflight.
- Android usato come riferimento funzionale e come sorgente dati diagnostici Room.

## Supabase
- Progetto locale: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Directory non git: snapshot/versionamento migration devono essere tracciati tramite evidence e file SQL.
- CLI: `supabase 2.98.2`.

## Supabase changelog/docs rilevanti
- Changelog Supabase corrente consultato: breaking change 2026-04-28 su tabelle non esposte automaticamente a Data/GraphQL API.
- Docs ufficiali Data API consultate: grants espliciti e RLS sono due layer distinti; grant mancante produce `42501`.
- Implicazione TASK-110: ogni tabella public usata dai client deve avere migration con grants espliciti, RLS owner-scoped e smoke test Data API.
