# TASK-010: Localizzazione UI multilingua

## Informazioni generali
- **Task ID**: TASK-010
- **Titolo**: Localizzazione UI multilingua
- **File task**: `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`
- **Stato**: DONE
- **Fase attuale**: — (completata; conferma utente 2026-03-25)
- **Responsabile attuale**: — (nessuna azione aperta)
- **Data creazione**: 2026-03-22
- **Ultimo aggiornamento**: 2026-03-25 (utente conferma regressione localizzazione risolta e verificata; tracking chiuso in DONE)
- **Ultimo agente che ha operato**: CODEX

> Stato finale: localizzazione UI completata. Hotfix su `.strings` malformati verificato, conferma utente ricevuta il 2026-03-25, nessun blocco residuo aperto.

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: nessuno

## Scopo
Rendere effettiva la scelta lingua già presente in OptionsView (`@AppStorage("appLanguage")`) esternalizzando tutte le stringhe utente hardcoded in file `.strings` localizzati per le 4 lingue supportate (italiano, inglese, cinese semplificato, spagnolo), con cambio lingua runtime senza riavvio dell'app.

## Contesto
L'app iOS ha già una schermata Opzioni che permette all'utente di selezionare una lingua tra "Sistema", "中文", "Italiano", "Español", "English". La scelta viene persistita in `@AppStorage("appLanguage")` ma non ha NESSUN effetto sulla UI: tutte le ~300 stringhe utente sono hardcoded in italiano direttamente nel codice Swift. Non esiste alcuna infrastruttura di localizzazione (nessun file `.strings`, `.xcstrings`, directory `.lproj`, né uso di `NSLocalizedString` o `String(localized:)`).

Il cambio tema (chiaro/scuro/sistema) è già funzionante tramite `@AppStorage("appTheme")` + `.preferredColorScheme()` in ContentView.

## Non incluso
- **Intestazioni colonne nei file XLSX esportati** (column headers in `InventoryXLSXExporter`, `DatabaseView.makeFullDatabaseXLSX()`): localizzarle romperebbe la compatibilità di round-trip import/export. Restano in italiano.
- **Messaggi di errore persistiti nei dati** (sync errors scritti in `HistoryEntry.data` da `InventorySyncService`): sono dati persistiti, non UI dinamica. Localizzarli creerebbe dati in lingue miste nel DB.
- **Stringhe di debug** (`debugPrint`, `print`): non sono visibili all'utente.
- **Commenti nel codice**: restano come sono.
- **Nuove funzionalità o refactor**: nessun cambio di logica applicativa, layout, o struttura dei file.
- **Validazione professionale delle traduzioni**: le traduzioni sono prodotte in-code; l'utente può revisionarle successivamente.
- **Localizzazione di `ExcelSessionViewModel.swift`**: questo file (~2260 righe) contiene quasi esclusivamente logica di parsing e analisi, non stringhe UI visibili all'utente. Le poche stringhe UI che contiene (es. progress messages) sono usate da altre view che le localizzeranno al punto di consumo. Modificarlo per localizzazione aggiungerebbe rischio senza beneficio proporzionato.
- **`NSCameraUsageDescription` e altre chiavi `Info.plist`**: la stringa di permesso camera è mostrata da iOS in un dialog di sistema. La localizzazione di chiavi Info.plist richiede file `InfoPlist.strings` separati in ogni `.lproj`, un meccanismo distinto da `Localizable.strings`. Il rischio/complessità non è proporzionato al beneficio per questo task. La stringa resta in italiano. Fuori scope esplicito (Decisione #8).

## File potenzialmente coinvolti

**Nuovi file:**
- `iOSMerchandiseControl/LocalizationManager.swift` — helper `L()` + `Bundle.forLanguage()`
- `iOSMerchandiseControl/it.lproj/Localizable.strings` — traduzioni italiane
- `iOSMerchandiseControl/en.lproj/Localizable.strings` — traduzioni inglesi
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` — traduzioni cinesi (semplificato)
- `iOSMerchandiseControl/es.lproj/Localizable.strings` — traduzioni spagnole

**File modificati (sostituzione stringhe):**
- `iOSMerchandiseControl/ContentView.swift` — tab labels + `@AppStorage("appLanguage")` + `.environment(\.locale, ...)`
- `iOSMerchandiseControl/OptionsView.swift` — tutte le stringhe opzioni/descrizioni
- `iOSMerchandiseControl/InventoryHomeView.swift` — bottoni, messaggi, errori
- `iOSMerchandiseControl/HistoryView.swift` — filtri, label, alert, placeholder
- `iOSMerchandiseControl/DatabaseView.swift` — dialog, label, errori, import/export UI
- `iOSMerchandiseControl/PreGenerateView.swift` — sezioni, bottoni, istruzioni
- `iOSMerchandiseControl/GeneratedView.swift` — dialog, bottoni, label, messaggi (~115 stringhe)
- `iOSMerchandiseControl/ImportAnalysisView.swift` — sezioni, label, dialog
- `iOSMerchandiseControl/EditProductView.swift` — form label, placeholder, bottoni
- `iOSMerchandiseControl/ProductPriceHistoryView.swift` — header, label, source display
- `iOSMerchandiseControl/BarcodeScannerView.swift` — istruzioni
- `iOSMerchandiseControl/EntryInfoEditor.swift` — form label, bottoni, sezioni

**Potenzialmente modificato:**
- `iOSMerchandiseControl.xcodeproj/project.pbxproj` — aggiunta `knownRegions` (it, zh-Hans, es)

**NON modificati:**
- `iOSMerchandiseControlApp.swift` — nessuna stringa UI
- `Models.swift` — nessuna stringa UI
- `InventorySyncService.swift` — stringhe errore persistite (fuori scope)
- `ExcelSessionViewModel.swift` — logica parsing, non UI (fuori scope)
- `ProductImportViewModel.swift` — logica analisi, stringhe consumate da ImportAnalysisView
- `InventoryXLSXExporter.swift` — header export (fuori scope)
- `ShareSheet.swift` — wrapper UIActivityViewController, nessuna stringa
- `HistoryEntry.swift` — model, nessuna stringa UI
- `PriceHistoryBackfillService.swift` — logica dati, nessuna stringa UI

## Criteri di accettazione
- [ ] CA-1: **Infrastruttura**: esiste `LocalizationManager.swift` con funzione helper `L(_:...)` per risoluzione stringhe e estensione `Bundle.forLanguage(_:)`. File `Localizable.strings` presenti in directory `.lproj` per le 4 lingue (it, en, zh-Hans, es). Nessuna nuova dipendenza esterna.
- [ ] CA-2: **Cambio lingua effettivo**: selezionando una lingua in OptionsView, tutte le stringhe utente delle schermate in scope si aggiornano alla lingua scelta senza riavvio dell'app.
- [ ] CA-3: **Persistenza lingua**: all'avvio dell'app, la lingua precedentemente selezionata viene riapplicata automaticamente (la UI mostra la lingua corretta fin dal primo frame).
- [ ] CA-4: **Lingua "Sistema" — fallback italiano garantito nel codice**: quando selezionata, `Bundle.forLanguage("system")` scorre `Locale.preferredLanguages` (le preferenze lingua reali dell'utente nel dispositivo, indipendenti dal bundle app) e normalizza ogni codice BCP-47 verso una lingua supportata (it, en, zh-Hans, es) — es. `"it-IT"` → `"it"`, `"zh-Hans-CN"` → `"zh-Hans"`. Se nessuna corrisponde, carica esplicitamente `it.lproj` come fallback garantito — deterministico, codificato in `LocalizationManager.swift`, non dipendente da `developmentRegion` né dalle localizzazioni registrate nel bundle. Verificabile staticamente e tramite VM-10.
- [ ] CA-5: **Copertura stringhe**: tutte le stringhe utente hardcoded nelle schermate in scope (CA-9) sono esternalizzate con chiavi semantiche e traduzioni nelle 4 lingue. Nessuna stringa utente visibile rimane hardcoded nei file in scope. **Evidenza obbligatoria**: Codex esegue l'audit grep definito al Passo 6 per ogni file in scope e documenta nell'handoff il risultato (output grep + eventuali eccezioni dalla whitelist con giustificazione).
- [ ] CA-6: **Nessuna regressione tema**: il cambio tema (system/light/dark) continua a funzionare esattamente come prima.
- [ ] CA-7: **Build verde**: il progetto compila senza errori e senza warning nuovi.
- [ ] CA-8: **Nessun refactor**: la logica applicativa, il layout, e la struttura dei file rimangono invariati salvo le modifiche strettamente necessarie alla localizzazione.
- [ ] CA-9: **Schermate in scope — tutte obbligatorie, nessuna partial completion ammessa**: ContentView, OptionsView, InventoryHomeView, HistoryView, DatabaseView, PreGenerateView, **GeneratedView** (obbligatoria — non è consentito consegnare senza copertura completa), ImportAnalysisView, EditProductView, ProductPriceHistoryView, BarcodeScannerView, EntryInfoEditor, e tutti i componenti/subview definiti nei rispettivi file (SectionHeader, OptionRow, HistoryRow, SyncStatusIcon, HistorySummaryChip, NamePickerSheet, InlineSuggestionsBox, etc.). Se Codex non può completare un file (errori di compilazione, complessità imprevista), si ferma, ripristina il file allo stato originale, documenta il blocco nell'handoff e torna a REVIEW — non consegna uno stato parziale.
- [ ] CA-10: **Formattazione locale**: il `.environment(\.locale, ...)` è applicato su ContentView tramite `localeOverride(for: appLanguage)` per adeguare la formattazione di date e numeri alla lingua selezionata. La risoluzione usa `Bundle.resolvedLanguageCode(for:)` — la stessa funzione di `Bundle.forLanguage()` — garantendo coerenza con i testi. Caso `appLanguage = "system"` + lingua dispositivo non supportata: il locale applicato è `Locale(identifier: "it")` (stesso fallback dei testi, non la lingua del device). Verificabile staticamente e tramite VM-11.
- [ ] CA-11: **Schermate fuori scope esplicitate**: ExcelSessionViewModel, InventorySyncService (stringhe errore persistite), InventoryXLSXExporter (header export) sono esplicitamente elencati nella sezione "Non incluso" come fuori scope. Eventuali altri file con stringhe non coperti emersi durante execution vengono documentati nell'handoff come follow-up candidate.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | File `.strings` in directory `.lproj` + risoluzione bundle custom | (a) String Catalog `.xcstrings`; (b) Dizionario Swift embedded | (a) Richiede interazione con Xcode UI per gestione; (b) Non standard, meno manutenibile. I file `.strings` sono il formato classico Apple, modificabili programmaticamente, ben supportati da `NSLocalizedString` e `Bundle(path:)`. | attiva |
| 2 | Funzione globale `L(_:...)` come punto unico di risoluzione | (a) `@EnvironmentObject` con manager; (b) `.environment(\.locale)` per lookup stringhe; (c) `Text(key, bundle:)` diretto | (a) Richiede injection in ogni view; (b) `.environment(\.locale)` NON controlla il lookup delle stringhe localizzate — controlla solo la formattazione date/numeri; (c) Verbose e inconsistente tra `Text`, `Label`, `Button`, `.navigationTitle`. `L()` è uniforme, funziona in contesti View e non-View, e la re-render è garantita da `@AppStorage("appLanguage")` nel root view. | attiva |
| 3 | Un solo `Localizable.strings` per lingua (nessun split per schermata) | File `.strings` separati per view/modulo | ~300 stringhe è una dimensione gestibile in un singolo file. Splitting aggiunge complessità di naming/discovery senza beneficio a questa scala. | attiva |
| 4 | Chiavi semantiche con dot-notation (es. `tab.inventory`, `options.theme.auto.title`) | (a) Stringhe italiane come chiavi; (b) Chiavi flat senza gerarchia | (a) Fragile: se il testo italiano cambia, tutte le traduzioni si rompono; (b) Non scalabile, naming collision. Dot-notation è leggibile, raggruppata per contesto, e standard industry. | attiva |
| 5 | Italiano come lingua fallback — esplicito nel codice via `Locale.preferredLanguages`, non dipendente da `developmentRegion` né dal bundle app | Cambiare `developmentRegion` in pbxproj a `it`; usare `Bundle.main.preferredLocalizations` | `developmentRegion = en` non viene modificato. Per "system", `Bundle.forLanguage()` usa `Locale.preferredLanguages` (preferenze lingua reali dell'utente) anziché `Bundle.main.preferredLocalizations` (che dipende dal bundle e dalle sue localizzazioni disponibili — potenzialmente vuoto prima che le `.lproj` siano correttamente integrate). I codici BCP-47 vengono normalizzati (es. `"en-US"` → `"en"`, `"zh-Hans-CN"` → `"zh-Hans"`) e mappati alle lingue supportate. Se nessuna corrisponde, fallback esplicito a `it.lproj`. Per lingue esplicite non trovate, stesso fallback. **Varianti cinesi (scelta intenzionale di prodotto)**: qualsiasi codice BCP-47 che inizia con `zh` — inclusi `zh-Hant` (tradizionale), `zh-TW`, `zh-HK` — viene mappato a `zh-Hans`. Non perché zh-Hant e zh-Hans siano equivalenti (non lo sono), ma perché l'unica localizzazione cinese supportata in questo task è `zh-Hans`. Un utente con dispositivo in cinese tradizionale vedrà l'interfaccia in cinese semplificato anziché ricevere il fallback italiano — preferibile come comportamento UX per questo task. | attiva |
| 6 | `.environment(\.locale, ...)` su ContentView per formattazione date/numeri | Non impostare locale | La formattazione di date (`formatted(date:time:)`) e numeri (`NumberFormatter`) dovrebbe seguire la lingua selezionata, non solo la lingua di sistema. | attiva |
| 7 | Solo i 4 nomi nativi delle lingue restano hardcoded: "English", "Italiano", "Español", "中文" — tutti gli altri testi, incluso "Sistema", vanno localizzati | Lasciare tutti i titoli delle opzioni lingua hardcoded | I 4 nomi nativi non vanno tradotti: sono già nella propria lingua per definizione. "Sistema" invece è testo UI dell'app (concetto di impostazione, non nome di lingua): in inglese → "System", in cinese → "系统", in spagnolo → "Sistema". Le 4 eccezioni sono tassative — nessun'altra stringa può usare questa giustificazione. | attiva |
| 8 | `NSCameraUsageDescription` (e altre chiavi Info.plist) dichiarata fuori scope | Localizzare con `InfoPlist.strings` in ogni `.lproj` | La localizzazione delle chiavi Info.plist richiede file `InfoPlist.strings` separati per ogni `.lproj`, distinti da `Localizable.strings` e con meccanismo di lookup diverso. È una stringa di sistema, non UI app. Il costo/complessità non è proporzionato al beneficio per questo task. Resta in italiano. | attiva |
| 9 | `Bundle.resolvedLanguageCode(for:)` come fonte unica di risoluzione lingua — usata sia da `Bundle.forLanguage()` che da `View.localeOverride()` | Logica di risoluzione duplicata nelle due funzioni | Con due implementazioni separate, il caso `appLanguage = "system"` + lingua dispositivo non supportata (es. francese) produceva un risultato incoerente: testi in italiano (via `Locale.preferredLanguages` in `Bundle.forLanguage()`) ma formattazione date/numeri nella lingua del device (perché `localeOverride()` non applicava alcun locale per "system"). La funzione condivisa `resolvedLanguageCode(for:)` garantisce coerenza: se la risoluzione porta a italiano (es. fallback da lingua non supportata), sia i testi che la formattazione usano italiano. **Comportamento scelto (opzione a)**: la formattazione locale segue la stessa risoluzione dei testi — non la lingua del device. **Fallback totale**: il fallback a "it" si applica a QUALSIASI valore non riconosciuto in `appLanguage` — non solo al caso `"system"` senza match. Se `appLanguage` contiene un valore inatteso (es. "fr", "pt", stringa vuota, dato corrotto in UserDefaults), la funzione restituisce "it". Questo garantisce che `Bundle.forLanguage()` e `localeOverride()` non ricevano mai un codice non valido. | attiva |

---

## Planning (Claude)

### Analisi

**Stato corrente dell'infrastruttura di localizzazione iOS:**

- **Zero**: nessun file `.strings`, `.xcstrings`, directory `.lproj`, `NSLocalizedString`, o `String(localized:)` in tutto il progetto
- `project.pbxproj` ha `knownRegions = (en, Base)` e `developmentRegion = en`
- **~300 stringhe utente hardcoded** distribuite in 12 file Swift (verificato con audit completo del codice — vedi tabella sotto)

**Audit stringhe per file:**

| File | Stringhe stimate | Complessità | Note |
|------|------------------|-------------|------|
| ContentView.swift | ~4 | BASSA | Tab labels |
| OptionsView.swift | ~25 | MEDIA | Opzioni tema/lingua + descrizioni + componenti condivisi (SectionHeader, OptionRow) |
| InventoryHomeView.swift | ~12 | MEDIA | Bottoni, messaggi, errori, progress |
| HistoryView.swift | ~30 | MEDIA-ALTA | Filtri data (enum DateFilter.title), toggle, alert, placeholder, componenti (HistoryRow, SyncStatusIcon, HistorySummaryChip) |
| DatabaseView.swift | ~35 | ALTA | Dialog, menu, search, errori, import/export UI (~1000 righe totali) |
| PreGenerateView.swift | ~45 | ALTA | Sezioni, istruzioni, bottoni, validazione, tooltip |
| GeneratedView.swift | ~115 | MOLTO ALTA | Dialog, bottoni condizionali, label interporlate, grid, scanner UI, sync, export (~3200 righe totali) |
| ImportAnalysisView.swift | ~20 | MEDIA-ALTA | Sezioni riepilogo, label, dialog import |
| EditProductView.swift | ~15 | BASSA | Form sections, placeholder, bottoni |
| ProductPriceHistoryView.swift | ~8 | BASSA | Header, picker, source display |
| BarcodeScannerView.swift | ~2 | BASSA | Istruzioni |
| EntryInfoEditor.swift | ~15 | MEDIA | Form label, bottoni, sheet (include NamePickerSheet, InlineSuggestionsBox) |

**Meccanismo di cambio lingua — perché `L()` e non `.environment(\.locale)`:**

Un punto tecnico critico: in SwiftUI, `.environment(\.locale, Locale(...))` controlla la formattazione di date e numeri ma **NON** il lookup delle stringhe localizzate. Per il lookup, SwiftUI usa le `preferredLocalizations` del bundle dell'app, che dipendono dalle impostazioni di sistema, non dall'environment locale.

Per il cambio lingua in-app (senza richiedere il riavvio), serve un meccanismo esplicito: caricare il bundle `.lproj` della lingua selezionata e usarlo per `NSLocalizedString`. La funzione `L()` incapsula questa logica in un unico punto.

La re-render delle view quando la lingua cambia è garantita dalla catena:
1. Utente cambia lingua in OptionsView → `@AppStorage("appLanguage")` scrive in UserDefaults
2. ContentView ha `@AppStorage("appLanguage")` → SwiftUI rileva il cambio → re-render di ContentView
3. ContentView re-render causa re-render di tutti i figli (TabView + NavigationStack + view interne)
4. Durante il re-render, ogni chiamata `L("key")` legge il nuovo `appLanguage` da UserDefaults → restituisce la traduzione aggiornata

**Nessun app restart necessario**: il cambio è immediato e completo.

### Approccio proposto

#### Passo 1: Creare `LocalizationManager.swift` (~30 righe)

```swift
import Foundation

/// Risolve una stringa localizzata nella lingua corrente dell'app.
/// Uso: L("key") oppure L("key.with.args", arg1, arg2)
func L(_ key: String, _ args: CVarArg...) -> String {
    let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    let bundle = Bundle.forLanguage(lang)
    // Lookup primario nel bundle risolto.
    // - value: key → se la chiave manca, restituisce la key stessa come sentinel
    // - table: nil → cerca in Localizable.strings (nome di default)
    var format = bundle.localizedString(forKey: key, value: key, table: nil)
    // Fallback per-chiave a italiano: se il bundle risolto non ha la chiave
    // (la chiave è mancante se il valore restituito è uguale alla chiave stessa),
    // effettua un secondo lookup in it.lproj.
    // Evita il doppio lookup se il bundle risolto è già quello italiano.
    if format == key {
        let itBundle = Bundle.forLanguage("it")
        format = itBundle.localizedString(forKey: key, value: key, table: nil)
        // Se manca anche in italiano: format == key → sentinel finale visibile in UI
    }
    if args.isEmpty {
        return format
    }
    // Usa il locale risolto anche per la formattazione degli argomenti:
    // String(format:locale:arguments:) garantisce che i format specifier numerici float
    // (es. %.2f) usino il separatore decimale della lingua selezionata (virgola in italiano,
    // punto in inglese/cinese/spagnolo) — coerente con resolvedLanguageCode(for:).
    // Per %d (interi) e %@ (stringhe già formate) il comportamento è invariato.
    let resolved = Bundle.resolvedLanguageCode(for: lang)
    return String(format: format, locale: Locale(identifier: resolved), arguments: args)
}

extension Bundle {
    /// Fonte unica di risoluzione lingua (Decisione #9).
    /// Mappa il codice raw da @AppStorage ("system", "zh", "it", "en", "es")
    /// al codice Apple canonico ("it", "en", "zh-Hans", "es"), con fallback esplicito a "it".
    /// Usata sia da forLanguage() che da View.localeOverride() — garantisce coerenza tra
    /// lookup stringhe e formattazione date/numeri in tutti i casi, incluso "system" con
    /// lingua dispositivo non supportata (es. francese → "it").
    static func resolvedLanguageCode(for code: String) -> String {
        let supported = ["it", "en", "zh-Hans", "es"]
        if code == "system" {
            // Usa le preferenze lingua reali dell'utente nel dispositivo (BCP-47, indipendenti dal bundle)
            for lang in Locale.preferredLanguages {
                let canonical: String
                if lang.hasPrefix("zh") {
                    canonical = "zh-Hans"          // zh-Hans, zh-Hant, zh-TW, zh-HK → tutti mappati a zh-Hans
                                                   // (scelta intenzionale: unica localizzazione cinese supportata è zh-Hans)
                } else {
                    canonical = String(lang.prefix(2))  // "en-US" → "en", "it-IT" → "it"
                }
                if supported.contains(canonical) {
                    return canonical
                }
            }
            return "it"  // fallback esplicito: nessuna lingua dispositivo corrisponde → italiano
        }
        // Lingue esplicite: normalizza "zh" → "zh-Hans", poi verifica che il codice
        // risultante sia effettivamente supportato. Qualsiasi valore non riconosciuto
        // (es. "fr", "pt", "de", stringa vuota, valore corrotto) fa fallback a "it".
        let appleCode = code == "zh" ? "zh-Hans" : code
        return supported.contains(appleCode) ? appleCode : "it"
    }

    /// Restituisce il bundle .lproj per il codice lingua specificato.
    /// Usa resolvedLanguageCode(for:) come fonte unica di risoluzione.
    /// Fallback di sicurezza a .main se it.lproj non è nel bundle (non dovrebbe accadere).
    static func forLanguage(_ code: String) -> Bundle {
        let resolved = Bundle.resolvedLanguageCode(for: code)
        if let path = Bundle.main.path(forResource: resolved, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        // Lingua risolta non trovata → fallback esplicito a italiano
        if let path = Bundle.main.path(forResource: "it", ofType: "lproj"),
           let bundle = Bundle(path: path) { return bundle }
        return .main
    }
}

extension View {
    /// Applica .environment(\.locale, ...) usando la stessa risoluzione di Bundle.forLanguage().
    /// A differenza della versione precedente, applica SEMPRE un locale — anche per "system".
    /// Questo garantisce che, se "system" fa fallback a italiano (lingua dispositivo non supportata),
    /// anche la formattazione date/numeri usi italiano, non la lingua del device (CA-10, Decisione #9).
    func localeOverride(for languageCode: String) -> some View {
        let resolved = Bundle.resolvedLanguageCode(for: languageCode)
        return self.environment(\.locale, Locale(identifier: resolved))
    }
}
```

**Nota su `L()` e formattazione numerica locale-sensitive**: `L()` con argomenti usa `String(format:locale:arguments:)` con il locale derivato da `Bundle.resolvedLanguageCode(for:)` — la stessa fonte di `localeOverride()`. Questo significa che i format specifier numerici float (es. `%.2f`) usano il separatore decimale della lingua selezionata (`"1,50"` in italiano, `"1.50"` in inglese/cinese/spagnolo). Per `%d` (interi) e `%@` (stringhe già formate) il comportamento è invariato. **Raccomandazione invariata**: per valori decimali (prezzi, quantità) preferire costrutti SwiftUI nativi (es. `Text(value, format: .number)`, `Text(date, style: .date)`) che rispettano già il `.environment(\.locale, ...)` — non sostituire questi con `L()`. Dove esistono interpolazioni `"Prezzo: \(price)"` con `price` già stringa formattata, usare `L("key.format", priceString)` con `%@`. Usare `%.2f` in `L()` solo quando il separatore locale è necessario e il valore non transita per un costruttore SwiftUI nativo.

**Nota su `localeOverride()` e "system"**: `localeOverride()` ora applica SEMPRE un locale — anche quando `appLanguage == "system"`. Il locale applicato è `Locale(identifier: Bundle.resolvedLanguageCode(for: "system"))`. Questo significa che se il dispositivo è impostato in una lingua non supportata (es. francese), il locale applicato è `Locale(identifier: "it")` — coerente con il fallback dei testi. Non è un comportamento predefinito di iOS: è una scelta esplicita del planning (Decisione #9, opzione a).

#### Passo 2: Creare le directory `.lproj` e i file `Localizable.strings`

4 file, uno per lingua. Ogni file contiene tutte le ~300 chiavi con le traduzioni appropriate.

Struttura:
```
iOSMerchandiseControl/
  it.lproj/Localizable.strings
  en.lproj/Localizable.strings
  zh-Hans.lproj/Localizable.strings
  es.lproj/Localizable.strings
```

Formato di ogni file:
```
/* Tab bar */
"tab.inventory" = "Inventario";
"tab.database" = "Database";
"tab.history" = "Cronologia";
"tab.options" = "Opzioni";

/* Options - Theme */
"options.theme.header" = "Tema";
"options.theme.auto.title" = "Automatico";
"options.theme.auto.subtitle" = "Usa lo stesso tema (chiaro/scuro) impostato in iOS.";
// ... etc.
```

Convenzione chiavi: `{schermata}.{sezione}.{elemento}` in dot-notation inglese.

**Verifica parità chiavi — obbligatoria dopo la creazione dei `.strings` (evidenza nell'handoff):**

Prima di procedere al Passo 3, Codex deve verificare che i 4 file `Localizable.strings` abbiano lo stesso identico set di chiavi e che nessun file contenga chiavi duplicate. I comandi da eseguire dalla directory `iOSMerchandiseControl/`:

```bash
# Estrai le chiavi ordinate da ciascun file (una per riga):
grep -E '^"[^"]+"\s*=' it.lproj/Localizable.strings  | sed 's/^\("[^"]*"\).*/\1/' | sort > /tmp/keys_it.txt
grep -E '^"[^"]+"\s*=' en.lproj/Localizable.strings  | sed 's/^\("[^"]*"\).*/\1/' | sort > /tmp/keys_en.txt
grep -E '^"[^"]+"\s*=' zh-Hans.lproj/Localizable.strings | sed 's/^\("[^"]*"\).*/\1/' | sort > /tmp/keys_zh.txt
grep -E '^"[^"]+"\s*=' es.lproj/Localizable.strings  | sed 's/^\("[^"]*"\).*/\1/' | sort > /tmp/keys_es.txt

# Confronto parità it ↔ en (output vuoto = identico):
diff /tmp/keys_it.txt /tmp/keys_en.txt

# Confronto parità it ↔ zh-Hans:
diff /tmp/keys_it.txt /tmp/keys_zh.txt

# Confronto parità it ↔ es:
diff /tmp/keys_it.txt /tmp/keys_es.txt

# Verifica duplicati in ciascun file (output vuoto = nessun duplicato):
sort /tmp/keys_it.txt | uniq -d
sort /tmp/keys_en.txt | uniq -d
sort /tmp/keys_zh.txt | uniq -d
sort /tmp/keys_es.txt | uniq -d
```

Ogni `diff` deve produrre output vuoto. Ogni `uniq -d` deve produrre output vuoto. Se ci sono differenze o duplicati, Codex li corregge prima di procedere.

**Documentazione obbligatoria nell'handoff**: riportare il risultato di ogni comando (output vuoto = OK, oppure elenco delle chiavi discordanti con correzione applicata). Un handoff senza questo risultato è incompleto.

#### Passo 3: Aggiornare `project.pbxproj`

Aggiungere `it`, `zh-Hans`, `es` a `knownRegions`:
```
knownRegions = (
    en,
    Base,
    it,
    "zh-Hans",
    es,
);
```

Questo permette a Xcode di riconoscere le nuove localizzazioni. Con `PBXFileSystemSynchronizedRootGroup` i file `.lproj` dovrebbero essere auto-inclusi nel build.

**Verifica necessaria**: Codex deve verificare dopo la modifica del pbxproj che il build trovi i bundle `.lproj` correttamente. Se `PBXFileSystemSynchronizedRootGroup` non gestisce automaticamente le directory `.lproj`, Codex esegue **un solo tentativo di fix minimo** (aggiunta entry di risorsa esplicite nel pbxproj — file references + build phase resource) e rifà il build una sola volta. Se il build passa: proseguire. Se fallisce ancora: documentare il problema nell'handoff e tornare a REVIEW. Questa è la stessa regola del Guardrail #11 — non riprovare più di una volta, non inventare soluzioni non descritte nel planning.

#### Passo 4: Modificare `ContentView.swift`

Aggiungere `@AppStorage("appLanguage")` (trigger per re-render globale) e `.localeOverride(for:)` sul TabView per la formattazione date/numeri:

```swift
@AppStorage("appLanguage") private var appLanguage: String = "system"

// Nel body, sostituire le label dei tab:
Label(L("tab.inventory"), systemImage: "doc.on.doc")
// ... etc.

// Sul TabView, aggiungere:
.localeOverride(for: appLanguage)
```

#### Passo 5: Sostituire le stringhe in tutti i file in scope

Pattern di sostituzione uniforme per tutti i componenti SwiftUI:

```swift
// Text
Text("Inventario")          →  Text(L("tab.inventory"))

// Label
Label("Inventario", systemImage: "doc.on.doc")
                             →  Label(L("tab.inventory"), systemImage: "doc.on.doc")

// Button
Button("Annulla") { ... }   →  Button(L("common.cancel")) { ... }

// .navigationTitle
.navigationTitle("Opzioni")  →  .navigationTitle(L("options.title"))

// Alert/Dialog title (String)
"Errore durante il caricamento"  →  L("error.loading.title")

// Stringhe interpolate
Text("File: \(count) righe") →  Text(L("inventory.file.loaded", count))
// .strings: "inventory.file.loaded" = "File: %d righe";

// TextField placeholder
TextField("Barcode", ...)    →  TextField(L("product.barcode"), ...)

// Section header
Section("Dati principali")   →  Section(L("product.section.main"))

// Enum computed properties (es. DateFilter.title)
case .all: return "Tutto"    →  case .all: return L("history.filter.all")
```

**Ordine di esecuzione** (dal più semplice al più complesso — permette di verificare che l'infrastruttura funzioni prima di affrontare i file grandi):

1. ContentView.swift (4 stringhe) — verifica infrastruttura
2. BarcodeScannerView.swift (2 stringhe)
3. ProductPriceHistoryView.swift (8 stringhe)
4. EditProductView.swift (15 stringhe)
5. EntryInfoEditor.swift (15 stringhe)
6. OptionsView.swift (25 stringhe) — include SectionHeader, OptionRow
7. InventoryHomeView.swift (12 stringhe)
8. HistoryView.swift (30 stringhe) — include DateFilter enum, componenti riga
9. ImportAnalysisView.swift (20 stringhe)
10. DatabaseView.swift (35 stringhe)
11. PreGenerateView.swift (45 stringhe)
12. GeneratedView.swift (115 stringhe) — il più grande, da fare per ultimo

**Nota su OptionsView**: solo i 4 nomi nativi delle lingue ("English", "中文", "Español", "Italiano") restano hardcoded (Decisione #7). **"Sistema" deve essere localizzato**: è testo UI, non un nome di lingua — in inglese "System", in cinese "系统", in spagnolo "Sistema". Tutti i `subtitle`, i footer, i section header e il titolo "Sistema" dell'opzione lingua vengono localizzati normalmente.

**Nota su stringhe condivise**: stringhe comuni come "Annulla", "Salva", "Fine", "OK", "Elimina" usano chiavi con prefisso `common.` (es. `common.cancel`, `common.save`) per evitare duplicazione nelle `.strings` files.

**Nota su placeholder posizionali per stringhe multi-argomento**: per stringhe localizzate con **2 o più argomenti**, usare placeholder posizionali (`%1$@`, `%2$d`, `%3$.2f`) invece dei non-posizionali (`%@`, `%d`). L'ordine delle parole varia tra le lingue: una stringa italiana `"Trovati %d prodotti in %@ categorie"` potrebbe avere ordine inverso in cinese o spagnolo. Con placeholder posizionali, ogni lingua riordina come necessario senza toccare il codice Swift. Per stringhe con **un solo argomento** (`%@`, `%d`) i placeholder non-posizionali restano invariati — non è necessario convertirli. Esempio:
```
// .strings it: "inventory.found" = "Trovati %1$d prodotti in %2$@ categorie";
// .strings en: "inventory.found" = "Found %1$d products in %2$@ categories";
// .strings zh: "inventory.found" = "在%2$@个类别中找到%1$d个产品";  // ordine invertito
// Codice Swift: L("inventory.found", count, categoryName)
```

**Nota su copy OptionsView — aggiornamento semantico obbligatorio (Guardrail #13)**: il footer della sezione Lingua in OptionsView (riga ~106) recita attualmente:
> `"Le modifiche alla lingua potrebbero richiedere il riavvio dell'app."`

Questo testo è **semanticamente falso** dopo questo task: il cambio lingua è runtime e immediato. Il testo deve essere aggiornato a:
> `"Le modifiche alla lingua si applicano immediatamente."`

(o equivalente nella rispettiva lingua per ogni file `.strings`). Questo è l'unico caso in cui una stringa non viene solo trasferita in `L()` ma anche corretta nel contenuto. È una modifica obbligatoria, non opzionale.

#### Passo 6: Audit grep residuale (evidenza obbligatoria per CA-5)

Prima della build finale, per ogni file in scope eseguire i seguenti audit in sequenza:

**Audit 1 — grep mirato ai costrutti SwiftUI user-facing (prioritario, basso rumore):**
```bash
grep -nE '(Text|Label|Button|Picker|Toggle|Menu|navigationTitle|TextField|Section|alert|confirmationDialog)\("[A-Za-zÀ-ÿ]|prompt:\s*"[A-Za-zÀ-ÿ]' NOMEFILE.swift | grep -v 'L("'
```
Copertura: `Text`, `Label`, `Button`, `Picker` (selezione), `Toggle` (label), `Menu` (label), `navigationTitle`, `TextField` (placeholder), `Section` (header), `alert`/`confirmationDialog` (titoli), e qualsiasi argomento `prompt:` (usato da `.searchable(text:prompt:)` e altri modificatori con named parameter). Ogni match di questo grep è quasi certamente una stringa utente residua — investigare e correggere.

**Audit 2 — grep broad per copertura residua (più rumore, richiede revisione contro whitelist):**
```bash
grep -n '"[A-Za-zÀ-ÿ][^"]*"' NOMEFILE.swift | grep -v 'L("' | grep -v '//'
```
I risultati dell'Audit 2 vanno filtrati manualmente contro la whitelist.

**Audit 3 — verifica literal con caratteri non latini (unicode-safe):**

Audit 1 e Audit 2 usano `[A-Za-zÀ-ÿ]`, che copre ASCII + Latin Extended (U+00C0–U+00FF). Non intercettano caratteri CJK o altri script non latini (es. cinese, arabo, cirillico). Nel contesto di questo progetto, l'unico literal non latino atteso nel codice Swift è `"中文"` (solo in `OptionsView.swift`), che è in whitelist per Decisione #7. Per verificare che non siano stati introdotti altri literal non latini non wrappati in `L()`, eseguire su ogni file in scope:

```bash
# Con rg (ripgrep — preferito su macOS):
rg -n '"[^"]*[^\x00-\xFF][^"]*"' NOMEFILE.swift | grep -v 'L("' | grep -v '//'

# Alternativa con grep BSD (macOS nativo, meno affidabile per multibyte):
grep -Pn '"[^"]*[^\x00-\xFF][^"]*"' NOMEFILE.swift | grep -v 'L("' | grep -v '//'
# Nota: grep -P non è disponibile su macOS nativo (BSD grep). Se non funziona, usare rg.
```

Ogni match di Audit 3 che non è `"中文"` è un literal non latino non previsto — investigare e correggere o giustificare nella whitelist.

**Whitelist — eccezioni ammesse che NON richiedono `L()`:**
- Nomi nativi delle 4 lingue (solo questi): `"中文"`, `"Italiano"`, `"Español"`, `"English"` (Decisione #7) — `"Sistema"` **NON** è in questa lista, deve essere localizzato
- Chiavi `@AppStorage`: `"appLanguage"`, `"appTheme"`
- Nomi SF Symbols (parametro `systemImage:`): es. `"doc.on.doc"`, `"gearshape"`, `"checkmark.circle.fill"`
- Identificatori interni non visibili all'utente: `"barcode"`, `"productName"`, `"IMPORT_EXCEL"`, ecc.
- Stringhe in commenti del codice (già escluse dal `grep -v '//'`)

**Documentazione obbligatoria nell'handoff**: per ogni file in scope riportare l'output di tutti e 3 gli audit (righe trovate con numero di riga e testo, oppure "0 stringhe residue"). Ogni eccezione alla whitelist deve essere nominata e giustificata esplicitamente. Un handoff senza questa documentazione è incompleto.

#### Passo 7: Build finale e smoke test

- Build completa senza errori (`** BUILD SUCCEEDED **`)
- Nessun warning nuovo introdotto
- Smoke test: cambio lingua in OptionsView → verificare aggiornamento UI immediato

### File da modificare

| File | Tipo modifica | Stringhe stimate | Motivazione |
|------|--------------|------------------|-------------|
| **Nuovo: `LocalizationManager.swift`** | Creazione | — | Helper `L()`, `Bundle.forLanguage()`, `View.localeOverride()` |
| **Nuovo: `it.lproj/Localizable.strings`** | Creazione | ~300 | Traduzioni italiane (tutte le stringhe correnti) |
| **Nuovo: `en.lproj/Localizable.strings`** | Creazione | ~300 | Traduzioni inglesi |
| **Nuovo: `zh-Hans.lproj/Localizable.strings`** | Creazione | ~300 | Traduzioni cinesi (semplificato) |
| **Nuovo: `es.lproj/Localizable.strings`** | Creazione | ~300 | Traduzioni spagnole |
| `ContentView.swift` | Modifica | 4 | Tab labels + `@AppStorage` + `.localeOverride()` |
| `OptionsView.swift` | Modifica | ~25 | Opzioni, descrizioni, componenti |
| `InventoryHomeView.swift` | Modifica | ~12 | Bottoni, messaggi, errori |
| `HistoryView.swift` | Modifica | ~30 | Filtri, label, alert, componenti |
| `DatabaseView.swift` | Modifica | ~35 | Dialog, label, errori, import/export UI |
| `PreGenerateView.swift` | Modifica | ~45 | Sezioni, istruzioni, bottoni |
| `GeneratedView.swift` | Modifica | ~115 | Dialog, bottoni, label, messaggi |
| `ImportAnalysisView.swift` | Modifica | ~20 | Sezioni, label, dialog |
| `EditProductView.swift` | Modifica | ~15 | Form, placeholder, bottoni |
| `ProductPriceHistoryView.swift` | Modifica | ~8 | Header, picker, source |
| `BarcodeScannerView.swift` | Modifica | ~2 | Istruzioni |
| `EntryInfoEditor.swift` | Modifica | ~15 | Form, bottoni, sheet |
| `project.pbxproj` | Modifica | — | `knownRegions` + eventuali entry `.lproj` |

### Rischi identificati

| Rischio | Impatto | Mitigazione |
|---------|---------|-------------|
| **GeneratedView.swift (3200 righe, ~115 stringhe)**: file molto grande con stringhe interporlate e logica condizionale complessa | ALTO — errori di sostituzione potrebbero rompere il flusso di editing inventario (funzionalità core dell'app) | Eseguire per ultimo, dopo aver verificato l'infrastruttura sui file piccoli. Ogni stringa va sostituita singolarmente, mai con replace-all globale. Build intermedia dopo GeneratedView consigliata. |
| **DatabaseView.swift (~1000 righe, ~35 stringhe)**: file grande con logica import/export | MEDIO | Sostituire solo stringhe UI, non toccare logica import/export. Verificare che alert e dialog funzionino. |
| **Stringhe interpolate con `%d`/`%@`**: la conversione da Swift string interpolation a `String(format:)` richiede attenzione al tipo e all'ordine degli argomenti | MEDIO | Per ogni stringa interpolata, verificare che i format specifiers (`%d`, `%@`, `%.2f`) corrispondano esattamente al tipo degli argomenti passati a `L()`. Errore di tipo = crash runtime. |
| **project.pbxproj + PBXFileSystemSynchronizedRootGroup**: le directory `.lproj` devono essere riconosciute da Xcode; il meccanismo auto-sync potrebbe non gestire correttamente le variant groups | MEDIO | Codex verifica con un build dopo la creazione dei file `.lproj`. Se il build non trova i bundle, aggiunge entry esplicite nel pbxproj e documenta. |
| **Fallback lingua "Sistema" su dispositivo con lingua non supportata** (es. francese): era un rischio con meccanismo bundle implicito | RISOLTO | `Bundle.forLanguage("system")` ora usa `Locale.preferredLanguages` (BCP-47 reali del dispositivo, indipendenti dal bundle) con normalizzazione codice base (es. `"fr-FR"` → `"fr"`, non in supported). Se nessuna lingua corrisponde a una supportata (it, en, zh-Hans, es), carica esplicitamente `it.lproj` (Decisione #5 aggiornata). Non dipende da `developmentRegion`. Verificabile staticamente e tramite VM-10. |
| **Qualità traduzioni automatiche**: le traduzioni en/zh/es sono generate da Codex, non da traduttori professionisti | BASSO — il task è funzionale, non di qualità linguistica | Le traduzioni possono essere riviste dall'utente in un secondo momento modificando i file `.strings`. Nessuna dipendenza critica dalla qualità delle traduzioni. |
| **Re-render completa dell'albero View**: cambio lingua causa re-render di TUTTE le view figlie di ContentView | BASSO — su tutti i device moderni il re-render è impercettibile | SwiftUI è ottimizzato per re-render differenziale. Il costo è trascurabile. |

### Verifica manuale

| # | Scenario | Verifica attesa |
|---|----------|-----------------|
| VM-1 | Avvio app con lingua precedentemente impostata su "English" | L'app si apre con tutti i testi in inglese (tab bar, navigation titles, bottoni) |
| VM-2 | Cambio lingua da Italiano a English in OptionsView | Tutti i testi visibili si aggiornano immediatamente a inglese senza riavvio |
| VM-3 | Cambio lingua a "中文" | Tutti i testi visibili si aggiornano a cinese semplificato |
| VM-4 | Cambio lingua a "Sistema" con dispositivo in italiano | Tutti i testi tornano in italiano |
| VM-5 | Cambio lingua a "Sistema" con dispositivo in inglese | Tutti i testi mostrano inglese |
| VM-6 | Cambio tema chiaro/scuro dopo cambio lingua | Il tema si applica correttamente, la lingua resta invariata |
| VM-7 | Navigazione completa: Inventario → PreGenerate → GeneratedView dopo cambio lingua | Tutte le schermate mostrano la lingua selezionata |
| VM-8 | Apertura storico prezzi prodotto dopo cambio lingua | Label, source ("Prezzo iniziale" → "Initial price"), picker ("Acquisto"/"Vendita") localizzati |
| VM-9 | Build completa del progetto dopo tutte le modifiche | `** BUILD SUCCEEDED **`, nessun warning nuovo |
| VM-10 | Dispositivo con lingua impostata in una lingua non supportata (es. francese o portoghese), `appLanguage = "system"` | L'app mostra i testi in italiano — fallback esplicito da `Locale.preferredLanguages` senza match → `it.lproj` (CA-4) |
| VM-11 | Cambio `appLanguage` da "Italiano" a "English" → aprire la schermata Cronologia o Storico prezzi di un prodotto con date visibili | Le date usano formato anglosassone (es. "Mar 22, 2026") anziché italiano ("22 mar 2026"); eventuali separatori decimali in prezzi/quantità formattati con costrutti SwiftUI nativi usano il punto anziché la virgola (CA-10) |

### Matrice criteri di accettazione → tipo verifica → evidenza attesa

| CA | Tipo verifica | Chi verifica | Evidenza attesa |
|----|--------------|--------------|-----------------|
| CA-1 | STATIC + BUILD | Codex / Claude | File `LocalizationManager.swift` e 4 `Localizable.strings` esistono; build verde; nessuna dipendenza esterna |
| CA-2 | MANUAL (VM-2, VM-3) | Utente / Simulator | UI si aggiorna immediatamente al cambio lingua; tutte le schermate in scope |
| CA-3 | MANUAL (VM-1) | Utente / Simulator | Avvio app con lingua già salvata → testi nella lingua corretta fin dal primo frame |
| CA-4 | STATIC + MANUAL (VM-4, VM-5, VM-10) | Codex / Utente | `Bundle.forLanguage("system")` usa `Locale.preferredLanguages` con normalizzazione BCP-47 e fallback esplicito a `it.lproj`; verificabile staticamente nel codice; VM-4/VM-5 per lingue supportate, VM-10 per lingua dispositivo non supportata |
| CA-5 | STATIC (grep audit Passo 6) | Codex | Output audit grep documentato nell'handoff: 0 stringhe residue o eccezioni whitelist giustificate per ogni file in scope |
| CA-6 | MANUAL (VM-6) | Utente | Cambio tema dopo cambio lingua → tema si applica correttamente, lingua invariata |
| CA-7 | BUILD | Codex | `** BUILD SUCCEEDED **`, 0 warning nuovi |
| CA-8 | STATIC (code review) | Claude | Nessun cambio a logica applicativa, layout, struttura file oltre la sostituzione stringhe |
| CA-9 | STATIC (code review) + grep audit | Claude / Codex | Tutti i 12 file in scope modificati; GeneratedView inclusa; nessun file mancante; nessuna partial completion |
| CA-10 | STATIC + MANUAL (VM-11) | Codex / Claude | `localeOverride(for: appLanguage)` su TabView in ContentView; usa `Bundle.resolvedLanguageCode(for:)` — stessa risoluzione dei testi; per "system" + lingua non supportata applica `Locale("it")` non la lingua del device; date e numeri cambiano formato al cambio lingua (VM-11) |
| CA-11 | STATIC (doc review) | Claude | Sezione "Non incluso" aggiornata; eventuali file aggiuntivi fuori scope documentati come follow-up candidate nell'handoff |

### Execution guardrails (istruzioni rigide per Codex)

1. **NON modificare la logica applicativa** — nessun cambio di comportamento, flusso, o layout. Solo sostituzione di stringhe hardcoded con chiamate `L()`.
2. **NON toccare ExcelSessionViewModel.swift** — fuori scope, troppo grande, rischio non giustificato.
3. **NON toccare InventorySyncService.swift** — le stringhe errore sono persistite nei dati.
4. **NON toccare InventoryXLSXExporter.swift** — le intestazioni export restano in italiano.
5. **NON fare refactor** — nessun rename, estrazione, riorganizzazione di codice esistente.
6. **NON aggiungere dipendenze** — nessun nuovo package, framework, o file di supporto oltre a quelli previsti.
7. **Ordine di esecuzione**: seguire l'ordine specificato nel Passo 5 dell'approccio (dal più semplice al più complesso). Eseguire un build intermedio dopo i primi 5-6 file per validare l'infrastruttura.
8. **Stringhe interpolate**: per ogni stringa con variabili, verificare che i format specifiers nel `.strings` file corrispondano esattamente ai tipi degli argomenti in `L()`. Errori di tipo causano crash.
9. **Nomi nativi lingue — solo 4 eccezioni hardcoded**: i `title` "English", "中文", "Español", "Italiano" restano hardcoded (Decisione #7). Il `title` "Sistema" dell'opzione `id: "system"` va invece localizzato — è testo UI, non un nome di lingua. Nessun'altra stringa può usare questa giustificazione.
10. **Chiavi condivise**: usare il prefisso `common.` per stringhe ripetute in più schermate (es. `common.cancel`, `common.save`, `common.done`, `common.delete`, `common.ok`).
11. **Se le directory `.lproj` non vengono riconosciute automaticamente dopo la modifica del pbxproj**: Codex può eseguire **un solo tentativo di fix minimo** coerente col planning — aggiungere le entry di risorsa esplicite nel pbxproj (file references + build phase resource) se `PBXFileSystemSynchronizedRootGroup` non le include automaticamente. Poi rifà il build una volta sola. Se il build passa: proseguire. Se fallisce ancora: documentare il problema nell'handoff e tornare a REVIEW. Non eseguire più di un ciclo fix/build, non inventare soluzioni non descritte nel planning.
12. **GeneratedView è obbligatoria — nessuna partial completion** (CA-9): se GeneratedView causa errori di compilazione o complessità imprevista, Codex si ferma, ripristina il file allo stato originale, documenta il blocco nell'handoff e torna a REVIEW. Non è consentito consegnare le altre 11 schermate come "fatto" lasciando GeneratedView intatta.
13. **Copy OptionsView footer lingua — aggiornamento semantico obbligatorio**: la stringa `"Le modifiche alla lingua potrebbero richiedere il riavvio dell'app."` (OptionsView riga ~106) va aggiornata semanticamente a `"Le modifiche alla lingua si applicano immediatamente."` (o equivalente per ogni lingua). Questo vale per tutte e 4 i file `.strings`. Non è sufficiente localizzare il testo originale — quel testo è sbagliato dopo questo task.
14. **`resolvedLanguageCode(for:)` è la fonte unica di risoluzione lingua** (Decisione #9): NON replicare la logica di risoluzione in altre funzioni o view. La funzione restituisce SEMPRE uno dei 4 codici supportati ("it", "en", "zh-Hans", "es") — qualsiasi input non riconosciuto (inclusi codici lingua non supportati, stringhe vuote, dati corrotti in UserDefaults) produce "it". `Bundle.forLanguage()` e `View.localeOverride()` chiamano entrambe questa funzione. Qualsiasi modifica alla logica di risoluzione va fatta solo in `resolvedLanguageCode(for:)`. Se Codex ha bisogno di determinare la lingua corrente in altri punti del codice, deve chiamare `Bundle.resolvedLanguageCode(for: lang)` — non reimplementare la stessa logica inline.
15. **Placeholder posizionali per stringhe con 2+ argomenti**: nelle chiavi `.strings` con 2 o più argomenti usare `%1$@`, `%2$d`, ecc. invece di `%@`, `%d` (nota: le stringhe con un solo argomento non richiedono placeholder posizionale). Il codice Swift rimane identico — `L("key", arg1, arg2)` — ma i file `.strings` di ogni lingua possono riordinare i placeholder liberamente. Violazioni: usare `%@` e `%d` in una chiave con 2+ argomenti è un bug latente che emerge solo nelle traduzioni che invertono l'ordine delle parole.

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Contratto non negoziabile**:
  - Tutti gli 11 CA sono obbligatori — nessuna partial completion ammessa
  - GeneratedView è in scope obbligatorio (CA-9, Guardrail #12)
  - `LocalizationManager.swift` deve contenere `Bundle.resolvedLanguageCode(for:)` come fonte unica di risoluzione lingua (Decisione #9, Guardrail #14): usata sia da `Bundle.forLanguage()` che da `View.localeOverride()` — NON duplicare la logica altrove
  - `resolvedLanguageCode(for:)` usa `Locale.preferredLanguages` con normalizzazione BCP-47 per "system", fallback esplicito a "it" se nessuna lingua corrisponde (CA-4, Decisione #5)
  - `localeOverride()` applica SEMPRE un locale — anche per "system" — usando `resolvedLanguageCode()`: se lingua dispositivo non supportata → `Locale("it")`, non lingua del device (CA-10, Decisione #9)
  - "Sistema" va localizzato — è testo UI, NON è nella whitelist hardcoded (Decisione #7, Guardrail #9)
  - L'audit grep del Passo 6 (**Audit 1 + Audit 2 + Audit 3**) deve essere eseguito e documentato per ogni file (CA-5)
  - La **verifica parità chiavi** tra i 4 `.strings` (Passo 2) deve essere eseguita e documentata nell'handoff (diff vuoti + nessun duplicato)
  - Il copy OptionsView footer lingua deve essere aggiornato semanticamente, non solo tradotto (Guardrail #13)
  - Un solo tentativo di fix minimo consentito se `.lproj` non vengono riconosciuti automaticamente (Guardrail #11)
  - Stringhe con 2+ argomenti: usare placeholder posizionali (`%1$@`, `%2$d`) (Guardrail #15)
- **Azione consigliata**:
  1. Leggere questo planning completo, inclusi guardrail 1–15 e matrice CA → verifica
  2. Creare `LocalizationManager.swift` con la signature esatta del Passo 1 (struttura rev7): `resolvedLanguageCode(for:)` (fallback totale a "it") + `forLanguage(_:)` + `localeOverride(for:)`. `L()` con doppio lookup (bundle risolto → it.lproj) usando `bundle.localizedString(forKey: key, value: key, table: nil)` — NON la macro `NSLocalizedString`
  3. Creare le 4 directory `.lproj` con `Localizable.strings` completi (inclusa stringa footer lingua corretta; placeholder posizionali per chiavi con 2+ argomenti)
  4. Eseguire la verifica parità chiavi tra i 4 `.strings` (Passo 2) — documentare output nell'handoff
  5. Aggiornare `project.pbxproj` (`knownRegions`)
  6. Build intermedia: verificare che i bundle `.lproj` siano riconosciuti dal runtime
  7. Procedere con la sostituzione stringhe nell'ordine del Passo 5 (dal più semplice al più complesso)
  8. Eseguire audit grep **Audit 1 + Audit 2 + Audit 3** (Passo 6) su ogni file in scope — documentare output nell'handoff
  9. Build finale: `** BUILD SUCCEEDED **`, 0 warning nuovi (Passo 7)
  10. Rispettare rigorosamente tutti i **Guardrail 1–15** sopra

---

## Execution (Codex)
<!-- solo Codex aggiorna questa sezione -->

### Obiettivo compreso
- USER OVERRIDE eseguito: riallineare prima il tracking minimo tra `docs/MASTER-PLAN.md` e file task, poi completare l'execution di TASK-010 senza riaprire il planning.
- Rendere effettiva la localizzazione UI multilingua iOS con persistenza di `appLanguage`, applicazione runtime senza riavvio, 4 lingue (`it`, `en`, `zh-Hans`, `es`), fallback `system` coerente con il planning, copertura completa delle 12 schermate in scope con `GeneratedView.swift` obbligatoria.
- Mantenere invariati logica applicativa, layout, API pubbliche, dipendenze e file dichiarati fuori scope (`ExcelSessionViewModel.swift`, `InventorySyncService.swift`, `InventoryXLSXExporter.swift`, `NSCameraUsageDescription`).

### File controllati
- Tracking: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`.
- Infrastruttura localizzazione: `iOSMerchandiseControl/LocalizationManager.swift`, `iOSMerchandiseControl.xcodeproj/project.pbxproj`, `iOSMerchandiseControl/it.lproj/Localizable.strings`, `iOSMerchandiseControl/en.lproj/Localizable.strings`, `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`, `iOSMerchandiseControl/es.lproj/Localizable.strings`.
- View in scope lette e aggiornate: `iOSMerchandiseControl/ContentView.swift`, `iOSMerchandiseControl/OptionsView.swift`, `iOSMerchandiseControl/InventoryHomeView.swift`, `iOSMerchandiseControl/HistoryView.swift`, `iOSMerchandiseControl/DatabaseView.swift`, `iOSMerchandiseControl/PreGenerateView.swift`, `iOSMerchandiseControl/GeneratedView.swift`, `iOSMerchandiseControl/ImportAnalysisView.swift`, `iOSMerchandiseControl/EditProductView.swift`, `iOSMerchandiseControl/ProductPriceHistoryView.swift`, `iOSMerchandiseControl/BarcodeScannerView.swift`, `iOSMerchandiseControl/EntryInfoEditor.swift`.
- File di supporto letto per validare consumo UI indiretto in scope: `iOSMerchandiseControl/ExcelSessionViewModel.swift`.

### Piano minimo
- Riallineare tracking incoerente al task attivo: `MASTER-PLAN` da stato incoerente a TASK-010 attivo, poi fase `PLANNING -> EXECUTION` nel file task, senza toccare backlog/priorita`/sezioni Claude.
- Creare infrastruttura di localizzazione (`LocalizationManager.swift`, `.lproj`, `.strings`, `knownRegions`) e verificare parita` chiavi/duplicati prima di toccare la UI.
- Aggiornare i 12 file Swift in scope seguendo il planning, eseguire audit `Audit 1 + Audit 2 + Audit 3`, fare build intermedia/finale, documentare l'esito e passare a `REVIEW`.

### Modifiche fatte
- Tracking riallineato come da override utente: `docs/MASTER-PLAN.md` aggiornato da task inattivo incoerente a TASK-010 attivo; file task portato prima a `EXECUTION` per lavorazione e ora a `REVIEW` per handoff verso Claude.
- Creata l'infrastruttura di localizzazione in `iOSMerchandiseControl/LocalizationManager.swift` con `currentAppLanguageSelection()`, `appLocale()`, `L(_:...)`, `Bundle.resolvedLanguageCode(for:)`, `Bundle.forLanguage(_:)` e `View.localeOverride(for:)` secondo Decisioni #2, #5, #6 e #9 del planning.
- Creati `Localizable.strings` in `it.lproj`, `en.lproj`, `zh-Hans.lproj`, `es.lproj`; aggiunte tutte le chiavi richieste dalle view in scope, incluse chiavi emerse durante execution (`database.progress.completed_title`, `database.error.save_sheet`, `database.error.file_not_utf8`, `pregenerate.add_file`, `pregenerate.reload_file`, `generated.row_edit.field.quantity_from_file`, ruoli colonna `pregenerate.role.*`, preview demo `generated.preview.*`).
- Chiarimento `project.pbxproj`: caso **(a)** confermato. `iOSMerchandiseControl.xcodeproj/project.pbxproj` e` stato davvero modificato in modo persistente; `git diff` mostra l'aggiunta di `es`, `it` e `"zh-Hans"` a `knownRegions`, mentre `developmentRegion = en` e` rimasto invariato come richiesto dal planning. Il file va quindi considerato a tutti gli effetti tra i file toccati del task.
- `ContentView.swift`: aggiunti `@AppStorage("appLanguage")`, tab labels localizzate e `.localeOverride(for: appLanguage)` per propagare locale e rerender runtime.
- `OptionsView.swift`: localizzati titoli, descrizioni e footer delle opzioni; mantenute hardcoded solo le 4 eccezioni native approvate dal planning (`English`, `Italiano`, `Español`, `中文`).
- `InventoryHomeView.swift`, `HistoryView.swift`, `DatabaseView.swift`, `PreGenerateView.swift`, `GeneratedView.swift`, `ImportAnalysisView.swift`, `EditProductView.swift`, `ProductPriceHistoryView.swift`, `BarcodeScannerView.swift`, `EntryInfoEditor.swift`: sostituite le stringhe utente con `L(...)`; `GeneratedView.swift` incluso integralmente come richiesto.
- Corrette anche le formattazioni manuali di date/numeri che non ereditavano automaticamente il locale SwiftUI: `HistoryView.swift`, `DatabaseView.swift`, `ImportAnalysisView.swift`, `PreGenerateView.swift`, `GeneratedView.swift`, `ProductPriceHistoryView.swift` ora usano `appLocale()` o `Date.FormatStyle(...).locale(appLocale())` nei punti di stringificazione manuale.
- `PreGenerateView.swift`: localizzati nel punto di consumo i ruoli colonna provenienti da `ExcelSessionViewModel.titleForRole(...)`, senza modificare il view model fuori scope.
- `GeneratedView.swift`: localizzati anche i dati demo della `#Preview` per ridurre residui di audit nel file obbligatorio.

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build compila: ✅ ESEGUITO — build finale eseguita con `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → `** BUILD SUCCEEDED **`.
- [x] Nessun warning nuovo: ⚠️ NON ESEGUIBILE — manca baseline warning pre-task per dimostrare formalmente lo stato "nuovo/non nuovo"; nella build finale non risultano warning Swift nei file toccati, ma compare 1 warning toolchain non legato al codice modificato: `appintentsmetadataprocessor warning: Metadata extraction skipped. No AppIntents.framework dependency found.`
- [x] Modifiche coerenti con planning: ✅ ESEGUITO — nessuna nuova dipendenza, nessuna modifica API pubblica, nessun refactor fuori scope, `GeneratedView.swift` coperta, file fuori scope non toccati salvo lettura di supporto `ExcelSessionViewModel.swift`.
- [x] Criteri di accettazione verificati: ⚠️ NON ESEGUIBILE — verificati staticamente/build CA-1, CA-4, CA-5, CA-7, CA-8, CA-9, CA-10, CA-11; CA-2, CA-3 e CA-6 restano da validare manualmente tramite VM del task (`VM-1`, `VM-2`, `VM-3`, `VM-6`, `VM-10`, `VM-11`).
- Riallineamento tracking pre-execution: ✅ ESEGUITO — `MASTER-PLAN` allineato al file task prima dell'implementazione; nessun backlog/priorita` alterato.
- Parita` chiavi `.strings`: ✅ ESEGUITO — `diff /tmp/keys_it.txt /tmp/keys_en.txt`, `diff /tmp/keys_it.txt /tmp/keys_zh.txt`, `diff /tmp/keys_it.txt /tmp/keys_es.txt` senza output; duplicati `uniq -d` = 0; confronto tra chiavi usate da `L("...")` nei 12 file in scope e chiavi presenti nei 4 `.strings`: `missing=0`, `dupes=0` per tutte le lingue.
- Wiring runtime localizzazioni: ✅ ESEGUITO (evidenza statica) — `ContentView.swift` usa `@AppStorage("appLanguage")` e `.localeOverride(for: appLanguage)`; `L(...)` legge la lingua corrente da `UserDefaults` e risolve il bundle tramite `Bundle.forLanguage(...)`. Con questo wiring, il cambio lingua in `OptionsView` forza rerender del root e nuovo lookup delle stringhe senza riavvio; la validazione manuale visuale resta comunque pendente nei VM del task.
- `.lproj` incluse nel prodotto buildato: ✅ ESEGUITO — evidenza concreta usata: ispezione del bundle generato in `DerivedData` dopo la build finale con `find .../iOSMerchandiseControl.app -maxdepth 2 -type d` ha restituito esplicitamente le 4 directory `en.lproj`, `es.lproj`, `it.lproj`, `zh-Hans.lproj`; questo conferma inclusione reale nel prodotto buildato, non solo presenza nel repo.
- Build intermedia: ✅ ESEGUITO — lanciata durante execution come smoke check dopo il primo batch di modifiche; nessun errore emerso sui file compilati nel passaggio osservato. Gate conclusivo affidato comunque alla build finale completa.
- Build finale: ✅ ESEGUITO — `** BUILD SUCCEEDED **`.
- Stato CA (sintesi):
- CA-1 ✅ verificato staticamente/build.
- CA-2 ⚠️ wiring implementato (`@AppStorage("appLanguage")` + `L()` + rerender root), validazione manuale runtime pendente.
- CA-3 ⚠️ persistenza implementata via `@AppStorage`, validazione manuale al riavvio pendente.
- CA-4 ✅ verificato staticamente in `LocalizationManager.swift` con fallback esplicito a `it`.
- CA-5 ✅ audit grep completato con whitelist giustificata.
- CA-6 ⚠️ nessuna modifica al tema e `preferredColorScheme` preservato, ma verifica manuale tema/lingua combinata pendente.
- CA-7 ⚠️ build verde verificata; stato "0 warning nuovi" non dimostrabile formalmente per assenza di baseline, vedi nota warning sopra.
- CA-8 ✅ verificato staticamente: nessun refactor/logica extra.
- CA-9 ✅ tutti i 12 file in scope aggiornati; `GeneratedView.swift` inclusa.
- CA-10 ✅ verificato staticamente: `ContentView` applica `.localeOverride(for: appLanguage)` e i formatter manuali in scope usano `appLocale()`.
- CA-11 ✅ verificato staticamente: sezione `Non incluso` gia` coerente, nessun nuovo fuori scope richiesto.
- Categorie residue ammesse negli Audit 2 / Audit 3:
- chiavi tecniche `@AppStorage`, id interni opzioni e valori enum non user-facing;
- `systemImage` / SF Symbols e altri identificatori puramente UI-tecnici;
- nomi tecnici di export/header/sheet/column/source code necessari alla compatibilita` dati (`Products`, `PriceHistory`, `barcode`, `RetailPrice`, `IMPORT_EXCEL`, ecc.);
- `print` / `debugPrint` / `fatalError` / error domains / formatter tecnici POSIX-UTC;
- eccezioni approvate dal planning per i nomi nativi lingua in `OptionsView` (`English`, `Italiano`, `Español`, `中文`);
- simboli non linguistici e placeholder (`—`, `•`, `·`, `÷`, `×`, `−`, `⌫`);
- dati preview/demo o sample non user-facing residui nel codice di preview.
- Audit grep Passo 6 per file:
- `ContentView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo chiavi `@AppStorage("appTheme"/"appLanguage")` e valori interni enum `light`/`dark`; Audit 3 `NO_MATCH`.
- `OptionsView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo `@AppStorage`, id interni opzioni (`system`, `light`, `dark`, `zh`, `it`, `es`, `en`), `systemImage`, e i 4 nomi nativi lingua; Audit 3 solo whitelist Decisione #7 (`"中文"`, `"Español"`).
- `InventoryHomeView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo estensioni file consentite e `systemImage`; Audit 3 `NO_MATCH`.
- `HistoryView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo `systemImage`, `print(...)` debug, chiave tecnica `SyncError`, simboli interni di stato; Audit 3 `NO_MATCH`.
- `DatabaseView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo `systemImage`, `print/debugPrint`, nomi file/sheet/header/export (`Products`, `Suppliers`, `Categories`, `PriceHistory`, colonne tecniche), domini errore, source codes e formatter tecnici POSIX/UTC; Audit 3 solo simbolo separatore `"·"`.
- `PreGenerateView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo `systemImage`, chiavi tecniche colonna/ruolo (`barcode`, `rowNumber`, `RetailPrice`, ecc.) e switch interni su role key; Audit 3 `NO_MATCH`.
- `GeneratedView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo `systemImage`, row ids tecnici, chiavi colonna/header (`barcode`, `productName`, `SyncError`, `RetailPrice`, ecc.), `fatalError` di guardia interna, simboli/calcolatrice e header demo preview; Audit 3 solo placeholder/separatori/simboli non linguistici (`"—"`, `"•"`, `"÷"`, `"×"`, `"−"`, `"⌫"`).
- `ImportAnalysisView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo `systemImage`, lookup tecnico `productName`, path/filename export (`exports`, `errori_import_...xlsx`) e formatter `en_US_POSIX`; Audit 3 solo simboli non linguistici (`"·"`, `"—"`).
- `EditProductView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo source code tecnico `"EDIT_PRODUCT"`; Audit 3 `NO_MATCH`.
- `ProductPriceHistoryView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo source codes tecnici (`BACKFILL`, `IMPORT_EXCEL`, `INVENTORY_SYNC`, `EDIT_PRODUCT`, `IMPORT_DB_FULL`); Audit 3 `NO_MATCH`.
- `BarcodeScannerView.swift` — Audit 1 `NO_MATCH`; Audit 2 solo `systemImage`; Audit 3 `NO_MATCH`.
- `EntryInfoEditor.swift` — Audit 1 `NO_MATCH`; Audit 2 solo `systemImage`; Audit 3 `NO_MATCH`.

### Rischi rimasti
- Le verifiche manuali/simulator previste dalla matrice del task non sono state eseguite in questo run: restano da confermare runtime update lingua, persistenza al riavvio, fallback `system` su lingua device non supportata e non-regressione tema (`VM-1`, `VM-2`, `VM-3`, `VM-6`, `VM-10`, `VM-11`).
- La build finale contiene 1 warning toolchain (`Metadata extraction skipped. No AppIntents.framework dependency found.`); non emergono warning Swift nei file modificati, ma non ho baseline precedente per dimostrare formalmente che non sia "nuovo".
- Gli audit broad/unicode-safe lasciano solo whitelist tecniche o simboliche nelle categorie sintetizzate sopra; non risultano stringhe UI residue non giustificate nei file in scope.

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare staticamente l'allineamento al planning e ai CA (in particolare `LocalizationManager.swift`, coerenza `localeOverride/appLocale`, copertura completa di `GeneratedView.swift`, whitelist degli audit 2/3) e decidere se richiedere o meno le VM manuali residue per CA-2/CA-3/CA-6/VM-10/VM-11 prima della chiusura utente.

---

## Review (Claude)
<!-- solo Claude aggiorna questa sezione -->

### Review 1 — 2026-03-22

#### Problemi critici
Nessuno.

#### Problemi medi
- **Guardrail #15 — placeholder posizionali**: la chiave `database.error.save_sheet` usava `%@: %@` (2 argomenti non posizionali) in tutti e 4 i `.strings`. Richiesto fix a `%1$@: %2$@`.

#### Miglioramenti opzionali
- GeneratedView linee 2623-2630: chiavi colonna raw ("barcode", "productName", ecc.) usate in messaggio errore `missingColumns`. Follow-up candidate, non bloccante.

#### Fix richiesti
1. `database.error.save_sheet` → `%1$@: %2$@` in it/en/zh-Hans/es `.strings`

#### Esito
CHANGES_REQUIRED

#### Handoff → Fix
- Prossima fase: FIX
- Prossimo agente: CODEX
- Azione: sostituire `%@: %@` con `%1$@: %2$@` nella chiave `database.error.save_sheet` nei 4 file `Localizable.strings`. Nessun altro cambio.

---

### Review 2 (post-fix) — 2026-03-22

#### Verifica fix richiesto
- `database.error.save_sheet` — **CHIUSO**: tutti e 4 i `.strings` ora usano `%1$@: %2$@`:
  - it: `"Impossibile salvare il foglio %1$@: %2$@"` ✅
  - en: `"Unable to save sheet %1$@: %2$@"` ✅
  - zh-Hans: `"无法保存工作表 %1$@：%2$@"` ✅
  - es: `"No se puede guardar la hoja %1$@: %2$@"` ✅

#### Scope check
- Commit `b1e1973`: 5 file toccati (4 `.strings` + task doc). Nessun file fuori scope modificato. ✅

#### Build
- `xcodebuild` → **BUILD SUCCEEDED**. Nessun warning Swift introdotto. ✅

#### Stato CA aggiornato
| CA | Descrizione | Stato |
|----|-------------|-------|
| CA-1 | Infrastruttura `L()`, bundle, fallback italiano | PASS |
| CA-2 | Cambio lingua runtime senza riavvio | PENDING MANUAL |
| CA-3 | Modalità "Sistema" segue lingua device | PENDING MANUAL |
| CA-4 | 4 file `.strings` con chiavi identiche | PASS |
| CA-5 | View in scope: 0 stringhe hardcoded | PASS |
| CA-6 | Formattazione numerica locale-aware | PENDING MANUAL |
| CA-7 | Nessuna regressione tema chiaro/scuro | PASS |
| CA-8 | Build verde senza warning Swift nuovi | PASS |
| CA-9 | Nessun file fuori scope modificato | PASS |
| CA-10 | Guardrail #15 placeholder posizionali | PASS |
| CA-11 | Key parity 423 chiavi, 0 duplicati | PASS |

#### Problemi critici
Nessuno.

#### Problemi medi
Nessuno (fix precedente chiuso).

#### Follow-up candidate (non bloccante)
- GeneratedView linee 2623-2630: chiavi colonna raw in messaggio errore.

#### Esito
**APPROVED** — approvato per test manuali.

CA-2, CA-3, CA-6 restano PENDING MANUAL: richiedono validazione su device/Simulator da parte dell'utente prima della chiusura definitiva a DONE.

### Handoff → Test manuali utente
- **Prossima fase**: conferma utente (test manuali)
- **Prossimo agente**: UTENTE
- **Azione consigliata**: validare su Simulator o device i 3 CA residui:
  - CA-2: cambiare lingua in Opzioni, verificare aggiornamento immediato UI
  - CA-3: impostare "Sistema", cambiare lingua device, verificare che l'app segua
  - CA-6: con lingua en/es, verificare che i prezzi usino il separatore decimale corretto (punto vs virgola)

---

## Review finale (Codex — user override)

### Review 3 — 2026-03-22

#### Contesto
User override esplicito: review finale eseguita da CODEX al posto di Claude, con facolta` di chiudere direttamente `DONE` solo in caso di esito realmente `APPROVED`.

#### Verifiche eseguite
- Coerenza tracking/documentazione: verificati `docs/MASTER-PLAN.md` e questo task file; la regola monetaria finale valida e` CLP app-wide. La precedente narrativa transitoria su `EUR` in **Fix 3** e` stata marcata esplicitamente come superseduta da **Fix 4** per evitare ambiguita`.
- Review codice finale su file chiave: `PriceFormatting.swift`, `ContentView.swift`, `InventoryHomeView.swift`, `HistoryView.swift`, `DatabaseView.swift`, `GeneratedView.swift`, `ImportAnalysisView.swift`, `ProductPriceHistoryView.swift`.
- Audit monetario finale: unico `numberStyle = .currency` residuo in `PriceFormatting.swift`; nessun residuo `EUR`, `XXX`, `¤` nei file Swift dell'app.
- Build finale: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` -> `** BUILD SUCCEEDED **`.

#### Problemi critici
Nessuno.

#### Problemi medi
- **CA-2 non chiuso app-wide: reattivita` lingua ancora non garantita nelle altre schermate principali che usano `L(...)`.** Dopo i fix mirati su `InventoryHomeView` e `HistoryView`, restano schermate root con lo stesso pattern che aveva gia` causato bug reali: uso esteso di `L(...)` senza una dipendenza reattiva esplicita da `appLanguage`. In particolare:
  - `iOSMerchandiseControl/DatabaseView.swift` definisce `DatabaseView` a riga 119 e usa `L(...)` in tutta la `body` (`195-319`) senza `@AppStorage("appLanguage")` o identity refresh per lingua.
  - `iOSMerchandiseControl/GeneratedView.swift` definisce `GeneratedView` a riga 27 e usa `L(...)` in tutta la schermata senza osservare `appLanguage`.
  - `iOSMerchandiseControl/ImportAnalysisView.swift` definisce `ImportAnalysisView` a riga 105 e usa `L(...)` nella `body`/toolbar senza osservare `appLanguage`.
  - `iOSMerchandiseControl/ProductPriceHistoryView.swift` definisce `ProductPriceHistoryView` a riga 5 e usa `L(...)`/`formatDate(...)` nella lista senza osservare `appLanguage`.

#### Note minori non bloccanti
- Build finale verde confermata; nel log resta il warning toolchain gia` noto `Metadata extraction skipped. No AppIntents.framework dependency found.`. Non lo tratto come blocker.
- La review non ha eseguito test UI interattivi Simulator/device; il blocker sopra deriva da evidenza statica concreta e dal precedente bug gia` confermato sullo stesso pattern in Inventario/Cronologia.

#### Esito
CHANGES_REQUIRED

`TASK-010` non e` pronta per `DONE`: la localizzazione runtime non e` ancora verificabile/affidabile app-wide per `CA-2`, quindi la chiusura finale sarebbe prematura.

### Handoff → Fix
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: applicare il fix minimo di reattivita` lingua alle schermate ancora esposte allo stesso pattern (`DatabaseView`, `GeneratedView`, `ImportAnalysisView`, `ProductPriceHistoryView`), rieseguire build e poi riportare il task in `REVIEW`.

---

## Fix (Codex)
<!-- solo Codex aggiorna questa sezione -->

### Fix applicati
- Fix mirato applicato per Guardrail #15: aggiornata la chiave `database.error.save_sheet` nei 4 file `Localizable.strings` in modo che usi placeholder posizionali a 2 argomenti invece di placeholder non posizionali.
- File toccati dal fix:
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- Nessun cambio applicato a `DatabaseView.swift`: la chiamata `L("database.error.save_sheet", entityLabel, error.localizedDescription)` era gia` corretta e non richiedeva modifiche.

### Check post-fix
- Verifica chiave nei 4 `.strings`: ✅ ESEGUITO — confermata con `rg -n 'database\\.error\\.save_sheet' ...` la presenza delle 4 varianti corrette:
- `it`: `"Impossibile salvare il foglio %1$@: %2$@"`
- `en`: `"Unable to save sheet %1$@: %2$@"`
- `zh-Hans`: `"无法保存工作表 %1$@：%2$@"`
- `es`: `"No se puede guardar la hoja %1$@: %2$@"`
- Build rapida finale: ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` -> `** BUILD SUCCEEDED **`.
- Warning: ⚠️ invariato rispetto al run precedente — presente il warning toolchain `Metadata extraction skipped. No AppIntents.framework dependency found.`; nessun warning Swift introdotto dal fix.
- Scope: ✅ ESEGUITO — fix limitato ai soli 4 `.strings`; nessun refactor, nessun allargamento di scope, nessun file fuori scope toccato.

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare che il finding su Guardrail #15 sia chiuso e che il task possa rientrare nel normale flusso di review senza ulteriori cambi lato codice Swift.

### Fix 2 — Refresh runtime `InventoryHomeView` (2026-03-22)

#### Obiettivo compreso
Correggere il bug di refresh lingua della schermata principale Inventario senza riaprire il task di localizzazione in modo ampio: al cambio lingua ripetuto, `InventoryHomeView` doveva tornare a rivalutare i testi `L(...)` a ogni aggiornamento senza richiedere riavvio app.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/InventoryHomeView.swift`

#### Piano minimo
- Verificare la causa root in `InventoryHomeView.swift`.
- Introdurre una dipendenza reattiva esplicita da `appLanguage` nel solo `InventoryHomeView`.
- Evitare `.id(...)` o altri workaround piu` invasivi se il binding diretto a `@AppStorage` basta.
- Eseguire build rapida finale e riportare il task in `REVIEW` per Claude.

#### Modifiche fatte
- Causa root confermata: `InventoryHomeView` usava `L(...)`, che legge `appLanguage` da `UserDefaults`, ma la view non osservava direttamente `appLanguage`; di conseguenza SwiftUI non aveva una dipendenza reattiva esplicita per invalidare sempre la root view Inventario ai cambi lingua successivi.
- In `iOSMerchandiseControl/InventoryHomeView.swift` ho aggiunto `@AppStorage("appLanguage") private var appLanguage: String = "system"`.
- Ho reso esplicita la dipendenza della `body` da `appLanguage` con un read minimale (`let _ = appLanguage`) prima del `VStack`, cosi` i testi `L(...)` vengono rivalutati a ogni update lingua.
- Non ho introdotto `.id(Bundle.resolvedLanguageCode(for: appLanguage))`: non e` stato necessario un reset forzato della root view.
- Nessuna modifica a import/navigation/theme e nessun tocco ad altre schermate che gia` si aggiornano correttamente.

#### Check eseguiti
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` -> `** BUILD SUCCEEDED **`.
- ⚠️ NON ESEGUIBILE — Cambio lingua `A -> B -> C` senza riavvio: non ho eseguito un test manuale/Simulator interattivo in questo run; evidenza statica del fix = `InventoryHomeView` ora osserva `@AppStorage("appLanguage")` e legge `appLanguage` nella `body`, quindi la root view viene invalidata quando cambia la lingua selezionata.
- ⚠️ NON ESEGUIBILE — Verifica manuale che le altre schermate non regrediscano: nessuna sessione UI interattiva eseguita in questo run; evidenza statica = il fix tocca solo `InventoryHomeView.swift`, quindi non altera le altre schermate gia` funzionanti.
- ⚠️ NON ESEGUIBILE — Verifica manuale `appTheme`: nessun test interattivo eseguito in questo run; evidenza statica = nessun file o codice relativo al tema e` stato modificato.
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: nel log build resta il warning toolchain gia` noto `Metadata extraction skipped. No AppIntents.framework dependency found.`; non emergono warning Swift dal file modificato, ma non ho una baseline strumentale separata per provare formalmente l'assenza assoluta di warning nuovi.
- ✅ ESEGUITO — Modifiche coerenti con il planning: fix minimale e mirato, limitato alla sola reattivita` di `InventoryHomeView` + riallineamento tracking verso `REVIEW`.

#### Rischi rimasti
- La validazione runtime del caso utente riportato (`A -> B -> C` senza riavvio) resta da confermare in review/test manuale, anche se il wiring reattivo mancante e` stato corretto.
- Se il refresh non risultasse ancora sufficiente in Simulator/device, il prossimo fix minimo previsto dal vincolo utente sarebbe forzare la ricreazione della root con `.id(Bundle.resolvedLanguageCode(for: appLanguage))`; non applicato ora per evitare un workaround piu` invasivo senza evidenza di necessita`.

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare il bugfix mirato su `InventoryHomeView` con focus sul wiring reattivo (`@AppStorage("appLanguage")` + read nella `body`) e confermare se e` sufficiente a chiudere il refresh lingua senza introdurre il fallback `.id(...)`.

### Fix 3 — Refresh runtime `HistoryView` + formatter soldi (2026-03-22)

#### Obiettivo compreso
Correggere in modo minimale i bug runtime della schermata Cronologia: righe che restavano in lingua precedente o mischiavano lingue diverse dopo il cambio lingua, e valori monetari che in alcuni casi mostravano `XXX`/`¤`. User override esplicito: fix applicato direttamente dal contesto `REVIEW`, senza riaprire planning e senza allargare il task.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`
- `iOSMerchandiseControl/HistoryView.swift`
- `iOSMerchandiseControl/LocalizationManager.swift`

#### Piano minimo
- Verificare la causa root in `HistoryView` / `HistoryRow`.
- Introdurre una dipendenza reattiva esplicita dalla lingua selezionata per la schermata Cronologia e per le sue righe.
- Applicare il refresh minimo necessario della `List` solo al cambio lingua.
- Correggere `dateString` e `formatMoney` con una locale regionale esplicita derivata da `appLanguage`, mantenendo `entry.supplier` e `entry.category` come dati raw non localizzati.
- Eseguire build finale e lasciare il task in `REVIEW` per Claude.

#### Modifiche fatte
- Causa root bug lingua confermata: `HistoryView` / `HistoryRow` usavano `L(...)` e `appLocale()` che leggono indirettamente da `UserDefaults`, ma la `List` e le righe non avevano una dipendenza reattiva esplicita dal cambio lingua; con il riuso/caching delle righe SwiftUI alcune celle potevano restare nella lingua precedente, producendo liste miste.
- In `iOSMerchandiseControl/HistoryView.swift` ho aggiunto `@AppStorage("appLanguage") private var appLanguage: String = "system"` a `HistoryView`.
- Ho reso esplicito il wiring reattivo passando `appLanguage` a `HistoryRow` e forzando il refresh minimo della `List` con `.id(resolvedLanguageCode)` al cambio lingua. Questo evita il riuso sporco delle righe tra lingue diverse senza toccare altre schermate.
- `customDateText` in `HistoryView` e `dateString` in `HistoryRow` ora usano una locale regionale esplicita derivata da `appLanguage` (`it_IT`, `en_US`, `zh_CN`, `es_ES`) invece della sola lingua nuda.
- Causa root bug soldi confermata: `NumberFormatter.numberStyle = .currency` con locale solo-lingua (`"en"`, `"es"`, `"zh-Hans"`) puo` non avere regione/currency valida, quindi produce `XXX`, `¤` o simboli incompleti.
- Nota storica: in questo passaggio intermedio il sintomo `XXX`/`¤` era stato ridotto rendendo esplicito un formatter monetario solo per Cronologia. Quella scelta e` stata poi completamente **superata da Fix 4**: la regola finale valida del task e` `CLP` app-wide (`$`, zero decimali, separatore migliaia attivo, indipendente da `appLanguage`).
- `entry.supplier` e `entry.category` sono rimasti volutamente raw e non localizzati in questo fix, come richiesto.

#### Check eseguiti
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` -> `** BUILD SUCCEEDED **`.
- ⚠️ NON ESEGUIBILE — Cambio lingua `A -> B -> C` senza riavvio su Cronologia: nessun test manuale/Simulator interattivo eseguito in questo run; evidenza statica del fix = `HistoryView` osserva `@AppStorage("appLanguage")`, la `List` si ricrea con `.id(resolvedLanguageCode)` e `HistoryRow` riceve esplicitamente `appLanguage`.
- ⚠️ NON ESEGUIBILE — Verifica manuale assenza di righe miste nella stessa lista: non eseguita interattivamente; evidenza statica = il refresh della `List` e il passaggio esplicito di `appLanguage` eliminano il path precedente basato su lookup indiretto e riuso celle.
- ⚠️ NON ESEGUIBILE — Verifica manuale valori monetari senza `XXX`/`¤`: non eseguita su UI in questo run; evidenza statica del passaggio storico = il formatter non usava piu` `.currency` con locale solo-lingua. La regola monetaria finale del task e` stata poi riallineata definitivamente in **Fix 4** a `CLP` app-wide.
- ✅ ESEGUITO — Scope: fix confinato a `iOSMerchandiseControl/HistoryView.swift` + documentazione task; nessuna modifica a `InventoryHomeView` o altre schermate.
- ✅ ESEGUITO — Coerenza con vincoli: `entry.supplier` e `entry.category` lasciati raw; nessun refactor architetturale, nessun cambio modello dati, nessuna dipendenza nuova.
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: nel log build resta il warning toolchain gia` noto `Metadata extraction skipped. No AppIntents.framework dependency found.`; non emergono errori/warning Swift attribuibili al fix, ma non ho una baseline separata per certificare formalmente l'assenza assoluta di warning nuovi.

#### Rischi rimasti
- La validazione manuale dei casi runtime richiesti in quel run (`A -> B -> C`, assenza di righe miste, assenza di `XXX`/`¤` nella UI) restava da confermare in review/test manuale.
- La parte monetaria documentata in questo passaggio e` solo storica: per la review finale vale esclusivamente la regola `CLP` app-wide formalizzata in **Fix 4**.
- Nessuna evidenza in questo run di regressioni su Inventario o altre schermate; staticamente non risultano toccate, ma la verifica interattiva cross-screen resta manuale.

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare il bugfix di `HistoryView` con focus su due punti: (1) refresh lingua della `List` e delle righe tramite `@AppStorage("appLanguage")` + `.id(resolvedLanguageCode)`, (2) mantenimento raw di `supplier/category`. La parte monetaria di questo passaggio e` stata poi superata da **Fix 4** e non e` piu` il riferimento finale del task.

### Fix 4 — Regola CLP app-wide per prezzi e somme (2026-03-22)

#### Obiettivo compreso
Correggere in modo centralizzato la formattazione monetaria dell'app: la currency era stata legata erroneamente alla lingua UI (`appLanguage`), ma il comportamento reale richiesto e` diverso. Regola di business/UX unica per tutta l'app: valuta CLP, simbolo `$`, nessun decimale, separatore migliaia attivo, indipendentemente dalla lingua selezionata.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`
- `iOSMerchandiseControl/PriceFormatting.swift`
- `iOSMerchandiseControl/HistoryView.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ProductPriceHistoryView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`

#### Piano minimo
- Introdurre un formatter centrale condiviso per CLP.
- Rimuovere i formatter soldi locali/sparsi che dipendevano da `appLocale()`.
- Riallineare almeno Cronologia, Database e storico prezzi prodotto; includere gli altri punti user-facing trovati durante il grep.
- Lasciare invariata la logica delle date e non toccare quantita`/stock non monetari.
- Eseguire build finale e riportare il task in `REVIEW`.

#### Modifiche fatte
- Causa root confermata: i prezzi e le somme erano formattati in piu` punti con `NumberFormatter.numberStyle = .currency` usando `appLocale()` o locale derivata dalla lingua UI. Questo rendeva la currency dipendente dalla lingua invece che dalla regola business dell'app, oltre a produrre `EUR`, `XXX` o `¤` in configurazioni non coerenti.
- Ho introdotto il formatter centrale in `iOSMerchandiseControl/PriceFormatting.swift` con API condivisa `formatCLPMoney(_ value: Double) -> String`.
- Regola CLP app-wide resa esplicita nel codice:
  - `locale = es_CL`
  - `currencyCode = CLP`
  - `currencySymbol = "$"`
  - `minimumFractionDigits = 0`
  - `maximumFractionDigits = 0`
  - `usesGroupingSeparator = true`
- Ho sostituito i formatter money locali in:
  - `HistoryView.swift`
  - `DatabaseView.swift`
  - `ProductPriceHistoryView.swift`
- Ho riallineato anche altri punti monetari user-facing emersi dal grep:
  - `GeneratedView.swift` (`summary.initial_order_total` e `displayPrice` della sezione dati DB)
  - `ImportAnalysisView.swift` (`purchase` / `retail` nel riepilogo modifiche)
- Ho lasciato invariata la logica delle date: la dipendenza da `appLanguage` resta solo per i formatter temporali.
- Non ho toccato quantita`, stock, parsing/modello dati o conversioni valuta: i valori numerici restano quelli persistiti, cambia solo la loro resa testuale.

#### Check eseguiti
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` -> `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — Formatter centrale introdotto: unico `numberStyle = .currency` rimasto nel repo sotto `iOSMerchandiseControl/` e` in `PriceFormatting.swift`.
- ✅ ESEGUITO — Nessun residuo `EUR`, `XXX`, `¤` o `historyCurrencyCode` nei file Swift dell'app: `rg -n "EUR|XXX|¤|historyCurrencyCode" iOSMerchandiseControl/*.swift iOSMerchandiseControl/**/*.swift -S` -> nessun risultato.
- ✅ ESEGUITO — Call site monetari allineati alla utility centrale: `rg -n "formatCLPMoney\\(" iOSMerchandiseControl -S` mostra usi in `HistoryView`, `DatabaseView`, `ProductPriceHistoryView`, `GeneratedView`, `ImportAnalysisView` e definizione in `PriceFormatting.swift`.
- ✅ ESEGUITO — Coerenza con i vincoli: nessuna data modificata, nessuna quantita`/stock non monetaria toccata, nessun cambio modello dati, nessuna conversione valuta.
- ⚠️ NON ESEGUIBILE — Verifica manuale UI completa dell'output visivo (`$1.000`, `$1.274.980`) in tutti i punti schermata: non eseguita interattivamente in questo run; evidenza statica = formatter CLP unico con `es_CL`, `CLP`, 0 decimali e grouping attivo.
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: nel log build resta il warning toolchain gia` noto `Metadata extraction skipped. No AppIntents.framework dependency found.`; non emergono errori/warning Swift attribuibili al fix, ma non ho una baseline separata per certificare formalmente l'assenza assoluta di warning nuovi.

#### Rischi rimasti
- La verifica manuale cross-screen della resa finale (`$` + migliaia + zero decimali) resta da confermare in review/test manuale, anche se il wiring statico e` ora unificato.
- I campi di editing/pre-parsing restano volontariamente raw numerici e non monetizzati; e` coerente col perimetro del fix ma va tenuto presente in review per evitare aspettative di formattazione dentro i `TextField`.
- Nessuna evidenza in questo run di regressioni funzionali fuori dall'ambito monetario; staticamente non sono state modificate date o logica dati.

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare la nuova regola CLP app-wide con focus su cinque punti: (1) `PriceFormatting.swift` come unica fonte di verita`, (2) assenza di formatter currency locali residui, (3) resa coerente tra Cronologia, Database, storico prezzi prodotto, Generated e ImportAnalysis, (4) nessun legame della currency con `appLanguage`, (5) date ancora dipendenti solo dalla lingua UI.

### Fix 5 — Reattivita` lingua finale nelle schermate residue (2026-03-22)

#### Obiettivo compreso
Chiudere il blocker finale emerso in review: alcune schermate principali usavano `L(...)` in modo esteso ma senza una dipendenza reattiva esplicita da `appLanguage`, replicando lo stesso pattern che aveva gia` causato bug runtime reali in `InventoryHomeView` e `HistoryView`.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/ProductPriceHistoryView.swift`

#### Piano minimo
- Introdurre una dipendenza reattiva esplicita da `appLanguage` nelle 4 schermate residue indicate dalla review.
- Usare lo stesso criterio minimo gia` applicato nei fix runtime precedenti.
- Dove la schermata usa `List` e il riuso celle puo` lasciare testo misto, legare solo la `List` alla lingua risolta.
- Evitare reset inutili di stato locale nelle schermate piu` complesse.

#### Modifiche fatte
- Root cause comune confermata: `L(...)` legge la lingua corrente da `UserDefaults`, ma senza osservare direttamente `@AppStorage("appLanguage")` le root view possono non invalidarsi in modo affidabile a ogni cambio lingua; nelle schermate con `List` il riuso/caching delle celle puo` lasciare label nella lingua precedente.
- `DatabaseView.swift`: aggiunto `@AppStorage("appLanguage") private var appLanguage: String = "system"` e introdotto `resolvedLanguageCode` nella `body`; la `List` prodotti ora usa `.id("database-list-\(resolvedLanguageCode)")` per riallineare celle e label al cambio lingua senza toccare filtro, import/export o logica dati.
- `GeneratedView.swift`: aggiunto `@AppStorage("appLanguage") private var appLanguage: String = "system"` e read minimale `let _ = appLanguage` nella `body`; scelto volutamente di NON usare `.id(...)` per non resettare stato locale dell'editor, scroll, dettaglio riga o flussi di salvataggio.
- `ImportAnalysisView.swift`: aggiunto `@AppStorage("appLanguage") private var appLanguage: String = "system"`, introdotto `resolvedLanguageCode` e applicato `.id("import-analysis-list-\(resolvedLanguageCode)")` alla `List` per evitare riuso sporco delle righe dell'analisi.
- `ProductPriceHistoryView.swift`: aggiunto `@AppStorage("appLanguage") private var appLanguage: String = "system"`, introdotto `resolvedLanguageCode` e applicato `.id("product-price-history-list-\(resolvedLanguageCode)")` alla `List` per riallineare sempre titolo sezione, source display e date formattate.
- Nessuna modifica a logica dati, layout, regola CLP, parsing, persistenza o tema. Nessun file fuori scope toccato oltre tracking/task.

#### Check eseguiti
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` -> `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — Scope: fix limitato ai 4 file richiesti (`DatabaseView.swift`, `GeneratedView.swift`, `ImportAnalysisView.swift`, `ProductPriceHistoryView.swift`) + tracking/task.
- ✅ ESEGUITO — Strategia minimale coerente con i fix runtime precedenti: `@AppStorage("appLanguage")` in tutte e 4 le schermate; `.id(...)` usato solo dove la `List` rende plausibile riuso/caching sporco.
- ⚠️ NON ESEGUIBILE — Verifica manuale runtime `A -> B -> C` sulle 4 schermate: nessuna sessione UI interattiva eseguita in questo run; evidenza statica = le root view osservano ora `appLanguage` in modo esplicito e, nei casi `List`, la lista e` legata alla lingua risolta.
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: la build finale riporta solo il warning toolchain gia` noto `Metadata extraction skipped. No AppIntents.framework dependency found.`; non emergono warning Swift attribuibili al fix, ma non ho una baseline separata per certificare formalmente l'assenza assoluta di warning nuovi.

#### Rischi rimasti
- La validazione interattiva finale resta da confermare in review/test manuale, ma il gap strutturale segnalato dalla review (`L(...)` senza dipendenza reattiva esplicita) risulta chiuso nelle 4 schermate residue.
- In `GeneratedView` ho evitato intenzionalmente `.id(...)` per non resettare lo stato dell'editor durante il cambio lingua; se in review emergesse ancora testo stale in sottoview persistenti, il prossimo passo minimo sarebbe valutare un identity refresh piu` mirato solo sulla porzione che mostra testo localizzato.

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare il fix finale di reattivita` lingua su `DatabaseView`, `GeneratedView`, `ImportAnalysisView` e `ProductPriceHistoryView`, con focus sul fatto che il pattern strutturale segnalato dalla review (`L(...)` senza osservazione esplicita di `appLanguage`) e` ora chiuso senza allargare scope o toccare la logica applicativa.

### Fix 6 — Hotfix regressione `.strings` malformati (2026-03-25)

#### Obiettivo compreso
Correggere con patch minima la regressione in cui varie schermate mostravano chiavi raw (`database.title`, `database.search_placeholder`, `history.summary.items`, `generated.detail.title`, `generated.detail.close`) pur avendo le traduzioni presenti nel repo e nel bundle buildato.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-021-historyentry-warning-dati-corrotti-deserializzazione.md`
- `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`
- `iOSMerchandiseControl/LocalizationManager.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/HistoryView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj`

#### Piano minimo
- Verificare se la regressione dipende da bundle/progetto Xcode oppure dal contenuto dei `.strings`.
- Correggere solo la causa reale, senza workaround in `L(...)` o fix sparsi nelle view.
- Rieseguire build e probe statico sul bundle per confermare la risoluzione delle chiavi osservate.

#### Modifiche fatte
- Root cause confermata: in `it.lproj`, `es.lproj` e `zh-Hans.lproj` la riga `history.exported` era scritta con virgolette tipografiche Unicode (`“ ”`) invece delle virgolette ASCII richieste dal formato Apple `.strings`.
- Effetto osservato: il bundle localizzato esisteva davvero, ma il parser `.strings` non riusciva a leggere correttamente le entry successive; di conseguenza `Bundle.localizedString(forKey:value:table:)` restituiva la chiave raw per molte stringhe dopo quella riga malformata.
- Hotfix applicato: sostituite solo le tre righe malformate con sintassi `.strings` valida ASCII:
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- Nessuna modifica a `LocalizationManager.swift`, alle view o al `project.pbxproj`: bundle e wiring runtime risultano corretti, il bug era nel contenuto dei file localizzati.
- User override operativo: fix eseguito fuori dal task attivo di `MASTER-PLAN` per risolvere una regressione localizzata senza riaprire planning o alterare il tracking globale di `TASK-021`.

#### Check eseguiti
- ✅ ESEGUITO — Inclusione risorse nel bundle: build iOS eseguita; il prodotto contiene `en.lproj`, `es.lproj`, `it.lproj`, `zh-Hans.lproj` e i rispettivi `Localizable.strings`.
- ✅ ESEGUITO — Verifica `project.pbxproj`: nessuna regressione trovata nei riferimenti localizzazione; `knownRegions` contiene `en`, `Base`, `es`, `it`, `zh-Hans`; il bug non dipende da target membership o copy resources mancanti.
- ✅ ESEGUITO — Probe runtime sul bundle buildato: prima del fix le chiavi `history.summary.items`, `database.title`, `database.search_placeholder`, `generated.detail.title`, `generated.detail.close` tornavano raw in `it/es/zh-Hans`; dopo il fix la risoluzione dal bundle restituisce di nuovo i valori tradotti.
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build` -> `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — Nessun warning nuovo introdotto nei file toccati: il build mantiene solo warning gia` noti di toolchain (`multiple matching destinations`, `Metadata extraction skipped. No AppIntents.framework dependency found.`).
- ✅ ESEGUITO — Coerenza con planning: fix minimo, nessun refactor, nessuna dipendenza nuova, nessun cambio API o workaround nel codice Swift.
- ⚠️ NON ESEGUIBILE — Verifica manuale UI/Simulator del cambio lingua da `OptionsView`: non eseguita in questo run; evidenza statica invariata = `OptionsView` continua a scrivere `@AppStorage("appLanguage")` e `ContentView` continua ad applicare `.localeOverride(for: appLanguage)`.

#### Rischi rimasti
- Non ho eseguito una sessione UI interattiva su Simulator/device in questo turno; la conferma visuale finale del cambio lingua resta manuale.
- La repository mantiene ancora virgolette tipografiche come semplice contenuto testuale dentro alcune traduzioni (`Use “%@”`, testi cinesi con parole quotate). Non sono un bug perche' sono interne al valore ASCII-quoted, ma futuri edit manuali dei `.strings` dovrebbero evitare editor che trasformano anche i delimitatori della sintassi.

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare il hotfix puntuale sui tre `Localizable.strings` non inglesi, con focus sulla root cause sintattica (`“ ”` come delimitatori invalidi) e sul fatto che bundle/pbxproj/wiring `L(...)` non richiedono ulteriori modifiche.

---

## Chiusura

### Conferma utente
- [x] Utente ha confermato il completamento

### Follow-up candidate
- Nessuno.

### Riepilogo finale
- Problema riscontrato: in varie schermate (`Database`, `History`, `Generated`) comparivano chiavi raw invece dei testi localizzati.
- Root cause trovata: tre file `Localizable.strings` non inglesi avevano una riga malformata con virgolette tipografiche Unicode come delimitatori della sintassi `.strings`, rompendo il parsing delle entry successive.
- Fix applicato: sostituite solo le tre righe malformate con delimitatori ASCII validi, senza modificare `LocalizationManager`, view Swift o `project.pbxproj`.
- Verifica eseguita: lint `.strings` OK, build `xcodebuild` riuscita, probe del bundle buildato positivo sulle chiavi osservate; l'utente conferma inoltre che la regressione e` risolta e verificata.
- Esito finale: `TASK-010` chiusa in `DONE`; nessun task figlio aperto, nessun debito residuo collegato a questa anomalia.

### Data completamento
- 2026-03-25
