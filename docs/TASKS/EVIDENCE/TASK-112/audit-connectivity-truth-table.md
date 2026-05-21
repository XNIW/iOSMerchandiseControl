# TASK-112 - Audit Connectivity Truth Table

Timestamp: 2026-05-20 20:34 -0400

| State | iOS | Android | Status |
|---|---|---|---|
| noNetwork | mancante | parziale via NetworkCallback lost/unavailable | parziale |
| networkNoInternet | mancante | coperto by missing VALIDATED capability | parziale |
| backendUnreachable | parziale generic error | parziale error classifier after job | parziale |
| noAuth | parziale auth presentation | coperto skip no_auth | parziale |
| authExpired | parziale sign in again copy | parziale classifier | parziale |
| RLS/42501 | parziale classifier/copy | parziale classifier | parziale |
| schemaMismatch | parziale/generic | parziale/generic | parziale |
| onlineReady | parziale foreground auth | parziale validated+auth+configured | parziale |

## Verdict

**PARTIAL**: Android has stronger network truth; iOS lacks network abstraction and both platforms need explicit backend/schema/action-needed classification tests.
