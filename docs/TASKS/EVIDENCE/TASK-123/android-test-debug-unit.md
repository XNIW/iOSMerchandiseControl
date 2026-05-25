Starting a Gradle Daemon, 1 busy Daemon could not be reused, use --status for details

> Configure project :app
WARNING: The option setting 'android.builtInKotlin=false' is deprecated.
The current default is 'true'.
It will be removed in version 10.0 of the Android Gradle plugin.
WARNING: The option setting 'android.newDsl=false' is deprecated.
The current default is 'true'.
It will be removed in version 10.0 of the Android Gradle plugin.
WARNING: API 'applicationVariants' is obsolete and has been replaced with 'AndroidComponentsExtension'.
It will be removed in version 10.0 of the Android Gradle plugin.
The legacy variant API is disabled by default in AGP 9.0, but can be re-enabled by adding 
    android.newDsl=false
to this project's gradle.properties file.
For more information, see http://developer.android.com/build/r/new-dsl.

To determine what is calling applicationVariants, use -Pandroid.debug.obsoleteApi=true on the command line to display more information.
WARNING: API 'testVariants' is obsolete and has been replaced with 'AndroidComponentsExtension'.
It will be removed in version 10.0 of the Android Gradle plugin.
The legacy variant API is disabled by default in AGP 9.0, but can be re-enabled by adding 
    android.newDsl=false
to this project's gradle.properties file.
For more information, see http://developer.android.com/build/r/new-dsl.

To determine what is calling testVariants, use -Pandroid.debug.obsoleteApi=true on the command line to display more information.
WARNING: API 'unitTestVariants' is obsolete and has been replaced with 'AndroidComponentsExtension'.
It will be removed in version 10.0 of the Android Gradle plugin.
The legacy variant API is disabled by default in AGP 9.0, but can be re-enabled by adding 
    android.newDsl=false
to this project's gradle.properties file.
For more information, see http://developer.android.com/build/r/new-dsl.

To determine what is calling unitTestVariants, use -Pandroid.debug.obsoleteApi=true on the command line to display more information.
WARNING: The property android.dependency.excludeLibraryComponentsFromConstraints improves project import performance for very large projects. It should be enabled to improve performance.
To suppress this warning, add android.generateSyncIssueWhenLibraryConstraintsAreEnabled=false to gradle.properties
WARNING: The property android.dependency.excludeLibraryComponentsFromConstraints improves project import performance for very large projects. It should be enabled to improve performance.
To suppress this warning, add android.generateSyncIssueWhenLibraryConstraintsAreEnabled=false to gradle.properties
WARNING: The property android.dependency.excludeLibraryComponentsFromConstraints improves project import performance for very large projects. It should be enabled to improve performance.
To suppress this warning, add android.generateSyncIssueWhenLibraryConstraintsAreEnabled=false to gradle.properties
WARNING: The property android.dependency.excludeLibraryComponentsFromConstraints improves project import performance for very large projects. It should be enabled to improve performance.
To suppress this warning, add android.generateSyncIssueWhenLibraryConstraintsAreEnabled=false to gradle.properties
w: ⚠️ Deprecated 'org.jetbrains.kotlin.android' plugin usage
The 'org.jetbrains.kotlin.android' plugin in project ':app' is no longer required for Kotlin support since AGP 9.0.
Solution: Remove both `android.builtInKotlin=true` and `android.newDsl=false` from `gradle.properties`, then migrate to built-in Kotlin.
See https://kotl.in/gradle/agp-built-in-kotlin for more details.


> Task :app:checkKotlinGradlePluginConfigurationErrors SKIPPED
> Task :app:preBuild UP-TO-DATE
> Task :app:preDebugBuild UP-TO-DATE
> Task :app:generateDebugBuildConfig UP-TO-DATE
> Task :app:generateDebugResources UP-TO-DATE
> Task :app:packageDebugResources UP-TO-DATE
> Task :app:processDebugNavigationResources UP-TO-DATE
> Task :app:parseDebugLocalResources UP-TO-DATE
> Task :app:generateDebugRFile UP-TO-DATE
> Task :app:kspDebugKotlin UP-TO-DATE
> Task :app:compileDebugKotlin UP-TO-DATE
> Task :app:javaPreCompileDebug UP-TO-DATE
> Task :app:compileDebugJavaWithJavac UP-TO-DATE
> Task :app:checkDebugAarMetadata UP-TO-DATE
> Task :app:mapDebugSourceSetPaths UP-TO-DATE
> Task :app:compileDebugNavigationResources UP-TO-DATE
> Task :app:mergeDebugResources UP-TO-DATE
> Task :app:createDebugCompatibleScreenManifests UP-TO-DATE
> Task :app:extractDeepLinksDebug UP-TO-DATE
> Task :app:processDebugMainManifest UP-TO-DATE
> Task :app:processDebugManifest UP-TO-DATE
> Task :app:processDebugManifestForPackage UP-TO-DATE
> Task :app:processDebugResources UP-TO-DATE
> Task :app:bundleDebugClassesToRuntimeJar UP-TO-DATE
> Task :app:bundleDebugClassesToCompileJar UP-TO-DATE
> Task :app:kspDebugUnitTestKotlin UP-TO-DATE
> Task :app:compileDebugUnitTestKotlin UP-TO-DATE
> Task :app:preDebugUnitTestBuild UP-TO-DATE
> Task :app:javaPreCompileDebugUnitTest UP-TO-DATE
> Task :app:compileDebugUnitTestJavaWithJavac NO-SOURCE
> Task :app:generateDebugAssets UP-TO-DATE
> Task :app:mergeDebugAssets UP-TO-DATE
> Task :app:packageDebugUnitTestForUnitTest UP-TO-DATE
> Task :app:processDebugUnitTestManifest UP-TO-DATE
> Task :app:generateDebugUnitTestConfig UP-TO-DATE
> Task :app:processDebugJavaRes UP-TO-DATE
> Task :app:processDebugUnitTestJavaRes UP-TO-DATE

> Task :app:testDebugUnitTest

DefaultInventoryRepositoryTest > pull product price links bridge when local business key already exists FAILED
    java.lang.AssertionError at DefaultInventoryRepositoryTest.kt:2597

DefaultInventoryRepositoryTest > 032 breakdown surfaces local catalog rows missing remote refs and sync reconciles them FAILED
    java.lang.AssertionError at DefaultInventoryRepositoryTest.kt:3234

DefaultInventoryRepositoryTest > syncCatalogWithRemote reports deferred prices when product has no remote ref FAILED
    java.lang.AssertionError at DefaultInventoryRepositoryTest.kt:2637

DefaultInventoryRepositoryTest > 041 realign skips non-matching rows without creating bridges FAILED
    java.lang.AssertionError at DefaultInventoryRepositoryTest.kt:3566

DefaultInventoryRepositoryTest > 019 inbound tombstone without bridge does not delete local suppliers FAILED
    java.lang.AssertionError at DefaultInventoryRepositoryTest.kt:3107

DefaultInventoryRepositoryTest > product price full pull streams remote prices by page FAILED
    java.lang.AssertionError at DefaultInventoryRepositoryTest.kt:4973

DefaultInventoryRepositoryTest > 042 incremental catalog push evaluates only dirty product candidates FAILED
    java.lang.NullPointerException at DefaultInventoryRepositoryTest.kt:2776

DefaultInventoryRepositoryTest > syncCatalogWithRemote pushes product prices when product_remote_refs exists FAILED
    java.lang.AssertionError at DefaultInventoryRepositoryTest.kt:2568

HistorySessionPushCoordinatorTest > 040 runPushCycle uses precise pending uid set FAILED
    java.lang.ExceptionInInitializerError at HistorySessionPushCoordinatorTest.kt:22
        Caused by: java.lang.IllegalStateException at HistorySessionPushCoordinatorTest.kt:22
            Caused by: java.lang.reflect.InvocationTargetException at HistorySessionPushCoordinatorTest.kt:22
                Caused by: com.sun.tools.attach.AttachNotSupportedException at HistorySessionPushCoordinatorTest.kt:22

HistorySessionPushCoordinatorTest > 110 login fresh tick bootstraps then runs full reconciliation push FAILED
    java.lang.NoClassDefFoundError at HistorySessionPushCoordinatorTest.kt:61
        Caused by: java.lang.ExceptionInInitializerError at HistorySessionPushCoordinatorTest.kt:22

HistorySessionPushCoordinatorTest > 040 failed push cycle logs classification and pending uid sample FAILED
    java.lang.NoClassDefFoundError at HistorySessionPushCoordinatorTest.kt:135
        Caused by: java.lang.ExceptionInInitializerError at HistorySessionPushCoordinatorTest.kt:22

HistorySessionPushCoordinatorTest > 040 signed out push cycle skips without querying repository FAILED
    java.lang.NoClassDefFoundError at HistorySessionPushCoordinatorTest.kt:115
        Caused by: java.lang.ExceptionInInitializerError at HistorySessionPushCoordinatorTest.kt:22

SyncErrorClassifierTest > ktor response exception exposes reliable status FAILED
    java.lang.NoClassDefFoundError at SyncErrorClassifierTest.kt:122
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelUtilsTest > readAndAnalyzeExcel null input stream throws localized empty file error FAILED
    java.lang.ExceptionInInitializerError at ExcelUtilsTest.kt:956
        Caused by: java.lang.IllegalStateException at ExcelUtilsTest.kt:956
            Caused by: java.lang.reflect.InvocationTargetException at ExcelUtilsTest.kt:956
                Caused by: com.sun.tools.attach.AttachNotSupportedException at ExcelUtilsTest.kt:956

ImportAnalyzerTest > analyze does not add supplier when it is already cached from repository FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyzeStreamingDeferredRelations exposes pending relation maps for missing names FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyzeStreaming processes a basic new product chunk FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze does not create update when price difference stays within tolerance FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze preserves existing category id when equivalent category name accompanies another change FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze truncates product names beyond the maximum length FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze adds update when price difference exceeds tolerance FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze keeps missing supplier and category deferred without preview writes FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze caps duplicate warning samples while preserving total occurrences and winner row FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze treats trim case and blank differences as semantic no-op FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze treats item number comparison as case insensitive FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze treats product name comparison as case insensitive FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze skips supplier changed field when supplier names match ignoring case FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyzeStreaming uses last duplicate row number for post merge validation errors FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyzeStreaming unexpected row error hides technical exception text FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze merges duplicate rows with last row wins and aggregated quantity FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze maps prev purchase and retail aliases into old prices FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze does not add category when find lookup resolves it FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyzeStreaming merges cross chunk duplicates with last row wins and aggregated quantity FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze skips category changed field when category names match ignoring case FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze preserves existing supplier id when equivalent supplier name accompanies another change FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze prefers discounted price over purchase price and discount formula FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze unexpected row error hides technical exception text FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze treats imported blank optional text as unchanged FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ImportAnalyzerTest > analyze uses last duplicate row number for post merge validation errors FAILED
    java.lang.NoClassDefFoundError at ImportAnalyzerTest.kt:594
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 024 manual refresh attempts session bootstrap and push even when catalog fails FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:177
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 036 manual refresh clears session detail inherited from automatic bootstrap FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:233
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 021 fresh signed-in manual refresh bootstraps catalog and then reports synced FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:113
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 061 manual quick sync with events recommends full sync when required FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:1038
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 044B full refresh clears quick-only remote not verifiable line from catalogDetail FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:1371
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 041 manual refresh exposes structured phase and returns tracker to completed FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:891
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 036 catalog failure does not reuse session detail from previous manual refresh FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:292
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 031 catalog ok with session issue keeps session partial success state FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:464
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 040 catalog failure keeps session permission and pending detail visible FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:520
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 026 skipped remote price rows surface in catalogDetail FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:658
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 039 refresh loads pending breakdown for structured log after sync FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:708
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 039 refresh guard paths do not load pending breakdown FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:764
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 061 tracker outcome from another owner is ignored FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:1267
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 061 signed out hides tracker outcome after publish FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:1317
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 021 fresh signed-in state waits for first manual refresh instead of claiming synced FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:78
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 040 options visible surfaces pending history sessions FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:566
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 044B second quick sync while first is in flight is ignored FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:1452
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 061 automatic sync event outcome recommends full sync without quick copy FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:1097
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 043 quick sync uses targeted catalog delta lane without full refresh FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:967
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 061 full refresh clears previous automatic full sync recommendation FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:1196
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 039 pending breakdown failure keeps refresh result unchanged FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:838
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 031 catalog ok with price issue keeps price partial success state FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:410
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 061 automatic sync event outcome shows outbox pending hint FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:1148
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 031 catalog failure with reliable forbidden status uses permissions copy FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:366
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

CatalogSyncViewModelTest > 031 catalog ok with price and session issue prioritizes session partial state FAILED
    java.lang.NoClassDefFoundError at CatalogSyncViewModelTest.kt:604
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > exportDatabase products only with empty dataset writes header only and emits success FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > updateProduct constraint error emits duplicate error FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > consumeUiState resets state to idle FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > updateProduct success stores fresh product details override FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > startImportAnalysis excludes footer rows with false product identity FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > clearImportAnalysis does not cancel an apply already in progress FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > exportDatabase catalog only skips product and price history fetches FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > createCatalogEntry blank name emits localized error FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > importProducts ignores double confirm while apply is already running FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > analyzeGridData records import origin and clear resets it to home FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > addProduct success emits success state FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > importProducts rejects preview with only row errors and no valid rows FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > startImportAnalysis happy path analyzes workbook generated in test FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > startSmartImport single sheet defaults origin to database FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > importProducts applies import without persisting technical history entries FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > startImportAnalysis strict ooxml xlsx succeeds after fallback FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > supplierCatalogSection emits loaded state from repository FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > analyzeGridData success updates analysis result and returns idle FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > clearImportAnalysis clears previous analysis result FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > updateProduct sequential saves leave latest product details override FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > exportDatabase ignores second request while one export is already running FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > deleteProduct success emits success state FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > startImportAnalysis empty workbook emits empty file error state FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > remote applied product ids store fresh product details override without global refresh FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > updateProduct failure does not store product details override FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > importProducts repository failure emits generic error without persisting technical history entries FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > addProduct duplicate barcode emits duplicate error FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > analyzeGridData repository failure emits error state FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > importProducts applies valid updates when analysis also has row errors FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > startImportAnalysis invalid file emits error state FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > deleteProduct success removes product details override FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > startImportAnalysis malformed legacy xls succeeds after fallback FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > updateProduct success emits success state FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > recoverImportPreviewAfterApplyError restores preview and keeps analysis result FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

DatabaseViewModelTest > exportDatabase full selection maps out of memory failures to error state FAILED
    java.lang.NoClassDefFoundError at DatabaseViewModelTest.kt:1094
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > appendFromMultipleUris all empty files keeps grid unchanged and shows append error FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadHistoryEntry by uid restores state and invokes callback FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > generated navigation context is stored and reset with view state FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadHistoryEntry restores viewmodel state from entry FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > exportToUri writes workbook and clears exporting indicators FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > getPreGenerateDataQualitySummary ignores blank barcodes and missing purchase price column FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateHistoryEntry writes edited state and summary to repository FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > renameHistoryEntry failure emits localized feedback FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > appendFromMultipleUris appends valid rows and skips empty files in same batch FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > 042 generated local save does not reload full sheet from self observer emission FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > addManualRow appends row updates history entry and tracks last category FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > addManualRow does not emit success feedback when history entry is missing FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris handles shopping hogar printable offsets with grouped totals FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris strict ooxml xlsx loads preview rows FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateHistoryEntry discountedPrice branch takes precedence over discount percent FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > generateFilteredWithOldPrices initial CL grouped decimal orderTotal EXPECTED_CORRECTION FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris handles printable split header workbook FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > appendFromMultipleUris without base grid shows main file needed and keeps state FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > generateFilteredWithOldPrices initial CL grouped orderTotal EXPECTED_CORRECTION FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateManualRow does not emit success feedback when history entry is missing FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > renameHistoryEntry updates id supplier and category FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > generateFilteredWithOldPrices persists entry and updates generated state FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > historyDisplayEntries attaches derived totalQuantity without changing totalItems FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > initialTotalQuantity returns null for old history shape without quantity header FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > appendFromMultipleUris keeps footer rows excluded for compatible appended files FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateHistoryEntry discount column uses parseUserNumericInput for CL comma decimal FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris empty first workbook uses first file empty message FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris invalid workbook uses generic localized error FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > renameHistoryEntry by uid fetches full entry before update FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris merges no-header files after structural cleanup without spurious rows or columns FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > appendFromMultipleUris incompatible header keeps grid unchanged FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > defaultIsColumnIncluded keeps all recognized import columns on and unknown columns off FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > initialTotalQuantity sums quantity while progress row count remains separate FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateHistoryEntry invalid numeric input falls back to zero without changing completed-row missing semantics FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateHistoryEntry CL grouped purchasePrice EXPECTED_CORRECTION uses thousand grouping not decimal dot FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateHistoryEntry editable CL comma quantity keeps final summary deterministic FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris excludes footer rows with false product identity from preview FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > toggleColumnSelection keeps essential column selected FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateHistoryEntry discountedPrice branch takes precedence with CL grouped discountedPrice EXPECTED_CORRECTION FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > markCurrentEntryAsSyncedSuccessfully fetches full entry before update FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > deleteManualRow does not emit success feedback when history entry is missing FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > toggleColumnSelection toggles non essential column FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > updateManualRow updates row history entry and emits localized feedback FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > createManualEntry persists manual history entry and loads it into state FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > toggleSelectAll deselects only non essential columns when all are selected FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > deleteHistoryEntry delegates delete to repository FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > getPreGenerateDataQualitySummary keeps duplicate feedback compact and counts missing purchase prices FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris malformed legacy xls loads preview rows FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > loadFromMultipleUris defaults unrecognized columns off while keeping recognized columns on FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > markCurrentEntryAsExported fetches full entry before update FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > toggleSelectAll selects non essential columns and keeps essentials enabled FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

ExcelViewModelTest > deleteManualRow removes row state persists history entry and emits localized feedback FAILED
    java.lang.NoClassDefFoundError at ExcelViewModelTest.kt:1625
        Caused by: java.lang.ExceptionInInitializerError at ByteBuddyAgent.java:619

> Task :app:testDebugUnitTest FAILED

[Incubating] Problems report is available at: file:///Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/build/reports/problems/problems-report.html
32 actionable tasks: 1 executed, 31 up-to-date

EXIT_CODE 1
