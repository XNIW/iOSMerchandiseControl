# TASK-010: Localizzazione UI multilingua

## Informazioni generali
- **Task ID**: TASK-010
- **Titolo**: Localizzazione UI multilingua
- **File task**: `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-22
- **Ultimo aggiornamento**: 2026-03-22
- **Ultimo agente che ha operato**: CODEX

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

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate

### Riepilogo finale

### Data completamento
