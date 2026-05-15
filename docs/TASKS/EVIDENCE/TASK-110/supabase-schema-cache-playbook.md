# TASK-110 — Supabase Schema Cache Playbook

Checkpoint: 2026-05-15 12:15 -0400.

## Quando usarlo
- Dopo migration che aggiunge colonne usate dalla Data API.
- Dopo grants/RLS/policy changes quando il client riceve risposte incoerenti.

## Comandi

```sql
notify pgrst, 'reload schema';
```

## Smoke test post-reload
1. Authenticated select su tabella owner-scoped.
2. Authenticated insert/update owner-scoped dove previsto.
3. Anon negative test su dati privati.
4. Verifica `42501` classificato come permission issue nei client.

## Stato
- Nessuna migration applicata; playbook preparato.
- `supabase migration list --linked` ha evidenziato divergenza locale/remota:
  - locali non presenti nel ledger remoto: `20260417`, `20260424021936`, `20260509120000`, `20260511030000`, più la nuova TASK-110;
  - remoti non presenti localmente: `20260424145010`, `20260514213110`.
- Prima di `db push` serve riconciliare/repair del ledger migration o importare i file mancanti.
