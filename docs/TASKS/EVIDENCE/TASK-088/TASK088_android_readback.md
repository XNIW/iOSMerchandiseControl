# TASK088 Android Read-back

Data: 2026-05-09 13:10 -0400

## Tipo verifica

- `STATIC`: lettura Android reference.
- `TEST`: test Android mirati DAO/repository/export.
- `READ-BACK`: valori Supabase aggregati post push iOS.
- Nessuna patch Android, coerente con regola "Android repo solo riferimento funzionale".

## Android reference

Repo letto: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

File rilevanti:

- `data/ProductPrice.kt`
- `data/ProductPriceSummary.kt`
- `data/ProductPriceDao.kt`
- `data/InventoryRepository.kt`
- `data/ProductPriceRemoteRef.kt`
- `util/DatabaseExportWriter.kt`

Semantica confermata:

- `ProductPriceSummary` ordina per `effectiveAt DESC`.
- `lastPurchase` / `lastRetail` = riga piu' recente per tipo.
- `prevPurchase` / `prevRetail` = riga precedente per tipo.
- Pull Android deduplica per remote id e business key locale `(productId, type, effectiveAt)`.

## Supabase values per Android summary

| Campo Android atteso | Valore Supabase |
|---|---:|
| `lastPurchase` | 122.2 |
| `prevPurchase` | 111.1 |
| `lastRetail` | 244.4 |
| `prevRetail` | 211.1 |

## Test Android mirati

Comando eseguito:

```bash
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest' --tests 'com.example.merchandisecontrolsplitview.data.AppDatabaseMigrationTest' --tests 'com.example.merchandisecontrolsplitview.util.DatabaseExportWriterTest'
```

Esito: **BUILD SUCCESSFUL**.

Warning osservati: deprecazioni Gradle/AGP/Kotlin legacy gia' presenti nel progetto Android; non sono introdotti da TASK-088.

## Esito

**PASS STATIC/TEST/READ-BACK** per coerenza funzionale Android last/prev. Non e' stato eseguito un pull live Android dell'app su `TASK088_*` per non modificare il repo/flusso Android oltre il ruolo di riferimento funzionale previsto dal task.
