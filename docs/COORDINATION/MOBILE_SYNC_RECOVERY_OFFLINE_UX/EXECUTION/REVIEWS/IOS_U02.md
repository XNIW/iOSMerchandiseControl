# IOS-U02 — review indipendente del delta locale

Reviewer: `/root/red_fixture_review`, distinto dal writer/executor. Esito ricevuto: **APPROVED_LOCAL_DELTA**, nessun finding.

La query esclude soltanto `sent` e `localOnly`; pending/sending/retryable/blocked/dead e raw sconosciuti conservano la semantica di attenzione. Nessuna mutazione delle proof, nessun cambiamento di schema/auth/layout.

RED eseguito:6≠0 e7≠1 nel caso richiesto, altri5PASS. GREEN stessa classe/config/simulatore:6PASS/0FAIL/0SKIP. Originali e scope in [registro](../EXECUTION_LOG.md). Snapshot test verifica righe/payload/status, non ogni metadato come confronto byte-identico universale.

Hash del delta revisionato:

- `iOSMerchandiseControlTests/OptionsSyncSummaryProviderTests.swift`: `607e32c7c1062c4e9c0f61eebd88ebfa4cdc035a5f3fc6254efb1050df9e02bf`
- `iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift`: `208a237c01ca48f2a0c175836f6fe85fd8a079ef7105cb28e419aa6ba1787b39`

Approvazione limitata a U02 locale. UI app installata, recovery, CI finale, packaging e acceptance TEST restano gate distinti; nessun APPROVED globale o DONE.
