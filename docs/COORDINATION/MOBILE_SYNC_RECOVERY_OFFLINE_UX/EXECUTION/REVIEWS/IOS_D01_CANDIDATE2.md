# Review indipendente iOS D01 candidata2

UTC 2026-10-16T04:25:41Z. Reviewer `/root/red_fixture_review`, distinto dal writer e dal runner root. **APPROVED_LOCAL_DELTA**: nessun rilievo residuo concreto nel delta congelato esaminato. Questo documento registra la review già consegnata e gli esiti successivi del runner; non approva il lavoro successivo sugli errori A→B.

## Pin esatto esaminato

- [Manifest candidato2](../20261015-01/ios-d01-candidate2-input.json), UTC `2026-10-16T04:16:30.685900+00:00`, SHA256 `d38745e920c14fc7b0fa1c5242f011dd9b26e0f6566c90416422f17db3f3cfcf`.
- [Patch candidato2](../20261015-01/ios-d01-candidate2.patch), SHA256 `9a6d90d0428955fdc2d60d7a5073410dc770a24f53f73d45b3b332a9e60853d8`.
- **16/16 SHA256 MATCH** verificati dal reviewer. Rispetto al manifest del RED shape, i 13 file comuni non interessati dal fix sono invariati: cambiano solo `SyncStateStore.swift` e `SyncOrchestrator.swift`, con l'aggiunta del piccolo helper in `LocalStoreIdentity.swift`. I test qualificati non sono stati modificati tra RED e questa candidata.

## Risultato della review

La provenienza della finalizzazione resta quella originaria: manifest restituita da `markRecoveryFinalized` dopo fsync/readback, propagata attraverso Atomic summary, engine e risultato. Non viene ricostruita dal binding selezionato alla consegna della callback. Il record v2 mantiene la prima data accettata per la stessa prova; letture, riapertura e avanzamento incrementale ordinario non la rinnovano.

Il DTO locale obbligatorio verifica i sei campi dell'identità nested prima del decoder legacy. Identità scalari, campi mancanti, `null` e tipi incompatibili sono rifiutati senza ricostruzione dai default o fallback alla prova v1. Il record resta bounded a 4096 byte e richiede versione, data e codici di provenienza validi. I bytes legacy/corrotti non vengono modificati dalla lettura.

`hasSameProvenance` confronta esplicitamente raw/default/local ID, schema, protocollo ed epoch. Il predicato D01 applica il confronto a binding, selezione, manifest, replay e readback. Il gate della callback terminale lo applica anche all'entità catturata: una variazione dell'epoch con raw ID, owner, shop e device uguali ritira quella callback, mentre una sostituzione legittima della lease nella stessa identità completa resta ammessa. Uguaglianza e decoder legacy globali sono invariati.

Gli assert originali A→B/reopen, i negativi full-epoch/shape e il positivo della lease sostituita restano attivi. Il positivo con pending creato attraverso il writer locale qualificato mantiene T0. Le dieci fixture positive Task118/Task119 attraversano recovery atomica qualificata; i precedenti cinque aggiornamenti di data a `nil` riguardano corpo non qualificato o identità/generazione non pertinente, con verifica dei bytes preservati. Nessun rilassamento del budget busy o degli assert retry individuato.

## Evidenza di esecuzione distinta

Runner root, cinque classi complete: **261 PASS / 0 FAIL / 0 SKIP**, exit **0**; `sourcePinsMatch=true`, nessun mismatch dei 16 pin.

- [Summary](../20261015-01/ios-d01-candidate2-summary.json), SHA256 `abff711997766440a2836d20758c95fe54c21145226e37c31fbfc2368f7a60e4`.
- [Output e verifica pin](../20261015-01/ios-d01-candidate2-output.json), UTC `2026-10-16T04:20:36.058575+00:00`, SHA256 `e8918258b08e035ab572329d6a8a36bc00079db4c46bb933a1079d0c5c64858e`.

Ambiente: Simulator sintetico `MOBILE145-20261015-01`, UUID `0674B959-5A88-49CA-AD70-33075F40CE9D`, iPhone 15 Pro Max, iOS26.1/23B86, arm64. Il summary conserva un runtime warning di inversione QoS tra thread user-interactive e utility; questa review non lo attribuisce al delta e non dichiara assenza di warning.

Il [RED shape originale](../20261015-01/ios-d01-shape-red-summary.json) conserva tre failure qualificate su quattro metodi: epoch reale con callback held, origine storeEpoch e nested identity legacy/incompleta; la fixture CTA corretta era già PASS. Il precedente RED A→B/reopen resta conservato separatamente. Gli esiti del runner qualificano queste regressioni locali, non una causa storica runtime.

## Limiti

Il reviewer non ha eseguito build, SDK, test o device e non ha modificato sorgenti; ha letto il pin congelato e gli artifact del runner, poi scritto soltanto questo documento su delega del root. I casi `null`/tipo incompatibile sono verificati staticamente dal DTO nonoptional; non vengono presentati come nuovi casi eseguiti oltre al contenuto della suite dichiarata.

La review vale esclusivamente per il manifest candidato2. Gli eventuali cambiamenti successivi nel working tree, incluso il RED test-only sugli errori A→B, sono esclusi. La contaminazione degli errori A→B resta aperta e non approvata qui. CI della candidata, Release/analyze, installazioni correnti, UI/live, cross-platform, performance e accettazione globale restano gate distinti. Nessun DONE, deploy o chiusura della causa storica A è inferito.
