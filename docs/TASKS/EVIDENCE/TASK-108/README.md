# TASK-108 — Evidence pack

**Stato:** DONE / Chiusura — `PASS_WITH_NOTES`.

Questa cartella raccoglie evidence privacy-safe per `TASK-108-supabase-sync-unification-ios.md`: screenshot, log redatti, esiti build/test, note Simulator/device e audit cross-repo Android/Supabase.

Non inserire risultati inventati o PASS non verificati.

Ultimo aggiornamento 2026-05-14 22:20 -0400:
- `80-final-professional-codebase-review.md` documenta la review professionale finale richiesta dopo TASK-108: iOS/Supabase riconfermati, fix mirati applicati, regressione iOS `217` test eseguiti / `9` skip / `0` failure, Debug/Release PASS, Supabase finale `57/27/19.695/41.109` con duplicati/orfani/owner mismatch `0`, Android build/unit PASS e live no-op emulatore PASS nel run corrente.
- `79-android-app-auth-live-rerun.md` documenta il rerun Android dopo login su fisico + emulatore: auth preflight PASS, full pull PASS, secondo pull no-op PASS, push incrementale no-op PASS, conteggi locali `19.695/57/27/41.109`, duplicati Android `0`, Supabase finale `41.109` ProductPrice e duplicati remoti `0`.
- `78-final-codebase-review-and-regression.md` documenta la review finale codebase, i fix applicati, la regressione iOS/Supabase/Android build-test e il verdict finale `PASS_WITH_NOTES`.
- iOS app-auth live resta valido da `77-app-auth-ios-live-and-diagnostics-cleanup.md`: pull/no-op/push incrementale/repull PASS, ProductPrice remoto finale `41.109`, duplicati `0`.
- Review finale corrente: source scan e Release binary scan iOS PASS per harness/diagnostiche storiche; `plutil` EN/IT/ES/ZH PASS; Simulator smoke Home/Options/Database/History PASS.
- Android: evidence `79` resta il PASS storico fisico `8ac48ff0` + emulatore `emulator-5554`; nella review `80` l'emulatore e' stato riconfermato PASS, mentre il fisico corrente non e' stato riconfermato dopo timeout pre-fix e retry post-fix in stato app `SignedOut`.
- TASK-108 e' **DONE / Chiusura — PASS_WITH_NOTES** su conferma esplicita utente; la nota residua Android riguarda il mutativo Android prezzo `+1` non rieseguito e il rerun fisico corrente da ripetere solo dopo nuovo login/app-auth disponibile.
