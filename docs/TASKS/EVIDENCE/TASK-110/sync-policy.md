# TASK-110 — Sync Policy

Checkpoint: 2026-05-15 12:15 -0400.

## Policy target

- Supabase è la fonte condivisa.
- Room/SwiftData sono cache offline.
- Identità cloud stabile: `remote_id`/UUID.
- Display name, titolo o timestamp non sono identità.
- Local-only valido: assegnare remote_id stabile e push pending.
- Remote-only: pull locale.
- Dirty local vs clean remote: push locale.
- Clean local vs dirty remote: pull remoto.
- Dirty local vs dirty remote: usare policy esplicita documentata, non skip infinito.
- Delete: tombstone/outbox quando lo schema lo supporta; evitare hard delete cieco.
- ProductPrice: append-only/idempotente con dedupe per owner/product/type/effective_at.
- Checkpoint/event watermark solo dopo batch completato.
- Sync idempotente: tre `Sync now` su dati allineati non devono creare duplicati.

## Sequenza target

1. Auth stable.
2. Pull catalog.
3. Riallinea bridge catalogo.
4. Pull prices incrementale/paginato.
5. Pull history.
6. Push pending/local-only.
7. Pull finale di conferma.

## Stato al checkpoint

- iOS: service History già include pull e push pending, ma delete è local-only e UI status limitato.
- Android: manual full fa bootstrap History e poi push, ma push scarta refs clean/stale e quindi non ripara remote missing.
