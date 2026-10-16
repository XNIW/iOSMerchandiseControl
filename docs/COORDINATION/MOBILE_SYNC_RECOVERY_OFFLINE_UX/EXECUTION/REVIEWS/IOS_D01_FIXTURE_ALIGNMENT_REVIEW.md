# Review indipendente delle fixture D01 finali

UTC 2026-10-16T05:30:32Z. Reviewer `/root/red_fixture_review`, distinto dal writer e dal runner root, con subreview read-only Task118 di `/root/red_fixture_review/transport_static`. **APPROVED_FIXTURE_DELTA_STATIC** sui tre artifact sotto dichiarati. Il perimetro è soltanto l'allineamento delle fixture già fallite; nessun nuovo audit o variante.

## Artifact esaminati

- [Held same-entity source time](../20261015-01/ios-d01-held-same-entity-source-time-test-proposal.patch), SHA256 `4790cee6db80676d399f1e91d0a64901b77f4b1f639d84d876b514a00e18ef6a`.
- [Task118 source time e legacy](../20261015-01/ios-task118-source-time-fixture-proposal.patch), SHA256 `b4992de2798a1eb57bff1e5ea4b436eea4999b3b607cee4166c2cd3858199629`.
- [Task119 owned completion](../20261015-01/ios-d01-immediate-retry-owned-completion-test-proposal.patch), SHA256 `e40102ace3c6fd91e463e7cd07341c3cf29da1c0cde04319e0409fec509100ff`.

Hash dei tre artifact verificati. **3/3 basi e 3/3 testi proposti MATCH**, ricostruiti soltanto in memoria prima dell'applicazione root. Nessun delta produzione: `SyncStateStore.swift` resta `1c4c6b028d3b6108fb6365599e83f9d81738ea154bbfee72c535f4800ba4f156`.

## Risultato statico e attribuzione

I casi di data qualificano l'osservazione originale prima della pubblicazione e ritardano esplicitamente la callback: gli expected restano T0. Un ritorno al timestamp della callback continuerebbe a fallire. Provenienza, lease, body, proof, bytes e negativi di corruzione restano verificati. I due casi legacy raw success/idle, senza journal o osservazione corrente, richiedono idle con outcome/data nil e bytes invariati; non fabbricano un latch recoveryRequired.

Task119 conserva chiamate, azioni, decisioni e assert finali. Attende separatamente il completamento della nuova recovery Engine/Atomic e la pubblicazione idle/succeeded, usando il timeout2s già adottato. Il Task MainActor eredita i TaskLocal; il runtime possiede, cancella e attende il proprio task fresh. Il primo risultato cancellato e il secondo risultato reale non vengono sostituiti con un successo sintetico. L'eventuale failure del servizio resta visibile negli assert del helper e nell'assenza della pubblicazione attesa.

La [failure attribution 10/10](../20261015-01/ios-d01-final-regression-01-failure-attribution.json), SHA256 `2954806ceba45400318845cc798009ec34bbd39638b2bf1fa48b2dcf87e3005b`, è coerente con i dieci ID e il log originale: sei expected temporali obsoleti (Atomic1 e Task1185), due expected legacy non più conformi e ImmediateRetry terminato senza attendere il lavoro reale. Il decimo ID, OuterCancellation, riceve soltanto gli assert tardivi del helper Atomic9463–65: il suo unico caller `freshResult` Task119 è il precedente ImmediateRetry. Questo qualifica l'attribuzione al lavoro fuori dal ciclo di vita del test; il motivo interno per cui quel servizio ha restituito failed non viene inferito. Gli artifact FAIL originali sono conservati e il solo giudizio statico non li chiudeva.

## Runner root distinto

Dopo la review, root ha applicato i tre artifact con i tre hash di base e i tre expected verificati. La regressione ordinata completa delle cinque classi è archiviata **271 PASS / 0 FAIL / 0 SKIP**, exit0, con **19/19 pin invariati**; root conferma tutti i dieci precedenti ID PASS.

- [Manifest regression02](../20261015-01/ios-d01-final-regression-02-input.json), SHA256 `bcf445ce8176ebdb4bdcceeca68223a281a628406281a164d915b7cad8f57e9c`.
- [Summary regression02](../20261015-01/ios-d01-final-regression-02-summary.json), SHA256 `b271a28cec80f4b19d0e9bdb1991c7e806272040d8c23bb579ea654676fb345f`.
- [Output e pin](../20261015-01/ios-d01-final-regression-02-output.json), SHA256 `0b4322b4c7da71abc3cdb6134e16081433d7f252b3c5877a1bbf01d74ba046b4`.

Il reviewer ha letto gli artifact e il conteggio del summary; non ha eseguito SDK, build, test o device, né modificato sorgenti/test live. Questo GREEN qualifica la regressione locale dichiarata e il ciclo di vita corretto delle fixture; non prova retroattivamente una causa SDK del fallimento tardivo. Il successivo delta per i compiler warning, il nuovo full canonical, CI, installazioni e UI/live restano esclusi e non chiusi. **HOLD** dopo la scrittura del solo presente report.
