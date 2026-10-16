# Review indipendente iOS candidata3

UTC 2026-10-16T03:29:06.436765+00:00. Reviewer `/root/red_fixture_review`; pin13/13 MATCH; patch SHA256 `3dfc956b1603f29a3bfadaf9b6e08b8dde72d53150cec1d0ebf06a4e4ece3184`.

**CHANGES_REQUIRED**, P2 liveness: i nuovi ritorni per authority cambiata non liberano la proprietà foregroundTask A, quindi i trigger successivi possono restare deferred_existing_task. Necessario cleanup invocation-owned e RED di nuova admission/coalescence, senza mutare stato/prova/budget B né liberare task B. Il delta terminale corregge staticamente scope/provenance e preserva lease replacement legittima; nessun altro finding nel subset. Reviewer non ha eseguito build/test.
