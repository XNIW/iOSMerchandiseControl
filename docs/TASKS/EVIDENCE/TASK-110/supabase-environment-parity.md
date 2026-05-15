# TASK-110 — Supabase Environment Parity

Checkpoint: 2026-05-15 12:15 -0400.

## Configurazione client

| Check | iOS | Android | Esito |
|---|---:|---:|---|
| Project URL/ref | `https://<project-ref>.supabase.co` | `https://<project-ref>.supabase.co` | stesso project ref |
| Project ref hash | `1dabff35f7b7`, last4 `kyvm` | `1dabff35f7b7`, last4 `kyvm` | match |
| Key kind | `sb_publishable` | JWT-like anon legacy | mismatch tipo key, non mismatch progetto |
| Key fingerprint | `9daa7202119e` | `780b5d8093d1` | diverso perché key kind diversa |

## Owner/account

Owner remoto osservato sulle tabelle inventory/shared sessions:
- owner hash: `bf727712...257e`

Stato verifica live client:
- iOS local SwiftData allineato ai counts remoti per owner osservato.
- Android local Room contiene dati dello stesso dominio ma con divergenze History/catalog.
- JWT `sub` runtime dai client non ancora estratto al checkpoint 12:15.

## Conclusione pre-patch

Non risulta un mismatch di progetto Supabase: iOS e Android puntano allo stesso project ref. Rimane da verificare il `sub` JWT runtime nei client durante login attivo, ma i counts indicano che iOS è già allineato al dataset remoto e Android ha drift locale/sync.
