import XCTest

final class SupabaseManualSyncReleaseUITests: XCTestCase {
    private let supportedLanguages = ["it", "en", "es", "zh-Hans"]

    func testTask067ManualSyncReleaseLocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "options.supabase.manualSync.header",
            "options.supabase.manualSync.footer",
            "options.supabase.manualSync.state.idle.title",
            "options.supabase.manualSync.state.idle.subtitle",
            "options.supabase.manualSync.state.running.title",
            "options.supabase.manualSync.state.running.subtitle",
            "options.supabase.manualSync.state.running.inline",
            "options.supabase.manualSync.state.success.title",
            "options.supabase.manualSync.state.success.subtitle",
            "options.supabase.manualSync.state.partial.title",
            "options.supabase.manualSync.state.partial.subtitle",
            "options.supabase.manualSync.state.auth.title",
            "options.supabase.manualSync.state.auth.subtitle",
            "options.supabase.manualSync.state.realign.title",
            "options.supabase.manualSync.state.realign.subtitle",
            "options.supabase.manualSync.state.connectivity.title",
            "options.supabase.manualSync.state.connectivity.subtitle",
            "options.supabase.manualSync.state.cancelled.title",
            "options.supabase.manualSync.state.cancelled.subtitle",
            "options.supabase.manualSync.state.technical.title",
            "options.supabase.manualSync.state.technical.subtitle",
            "options.supabase.manualSync.state.busy.title",
            "options.supabase.manualSync.state.busy.subtitle",
            "options.supabase.manualSync.state.unavailable.title",
            "options.supabase.manualSync.state.unavailable.subtitle",
            "options.supabase.manualSync.state.applied.title",
            "options.supabase.manualSync.state.applied.subtitle",
            "options.supabase.manualSync.state.applyFailed.title",
            "options.supabase.manualSync.state.applyFailed.subtitle",
            "options.supabase.manualSync.lifecycle.interrupted.title",
            "options.supabase.manualSync.lifecycle.interrupted.subtitle",
            "options.supabase.manualSync.lifecycle.blocked.title",
            "options.supabase.manualSync.lifecycle.blocked.subtitle",
            "options.supabase.manualSync.state.suggested.title",
            "options.supabase.manualSync.state.suggested.subtitle",
            "options.supabase.manualSync.semiAuto.suggested",
            "options.supabase.manualSync.semiAuto.checking",
            "options.supabase.manualSync.lastCheck",
            "options.supabase.manualSync.summary.cloudCheck.completed.ok",
            "options.supabase.manualSync.summary.cloudCheck.completed.noAction",
            "options.supabase.manualSync.summary.cloudCheck.differences",
            "options.supabase.manualSync.summary.local.noPending",
            "options.supabase.manualSync.summary.cloudCheck.incomplete",
            "options.supabase.manualSync.summary.network",
            "options.supabase.manualSync.summary.session",
            "options.supabase.manualSync.summary.permission",
            "options.supabase.manualSync.summary.generic",
            "options.supabase.manualSync.summary.cancelled",
            "options.supabase.manualSync.plan.summary.permission.title",
            "options.supabase.manualSync.plan.summary.permission.message",
            "options.supabase.manualSync.plan.attention.permission",
            "options.supabase.manualSync.summary.localApply.completed",
            "options.supabase.manualSync.summary.localApply.completedWithCounts",
            "options.supabase.manualSync.summary.localApply.productsAdded",
            "options.supabase.manualSync.summary.localApply.productsUpdated",
            "options.supabase.manualSync.summary.localApply.suppliersCreated",
            "options.supabase.manualSync.summary.localApply.categoriesCreated",
            "options.supabase.manualSync.summary.localApply.failed",
            "options.supabase.manualSync.action.checkCloud",
            "options.supabase.manualSync.action.review",
            "options.supabase.manualSync.action.syncNow",
            "options.supabase.manualSync.action.signIn",
            "options.supabase.manualSync.action.realign",
            "options.supabase.manualSync.action.sendToCloud",
            "options.supabase.manualSync.action.retry",
            "options.supabase.manualSync.action.cancel",
            "options.supabase.manualSync.root.checking.title",
            "options.supabase.manualSync.root.checking.detail",
            "options.supabase.manualSync.root.changes.title",
            "options.supabase.manualSync.root.changes.detail",
            "options.supabase.manualSync.root.auth.title",
            "options.supabase.manualSync.root.auth.detail",
            "options.supabase.manualSync.root.error.title",
            "options.supabase.manualSync.root.error.detail",
            "options.supabase.manualSync.root.interrupted.title",
            "options.supabase.manualSync.root.interrupted.detail",
            "options.supabase.manualSync.root.action.review",
            "options.supabase.manualSync.root.action.signIn",
            "options.supabase.manualSync.root.action.retry",
            "options.supabase.manualSync.review.title",
            "options.supabase.manualSync.review.subtitle",
            "options.supabase.manualSync.review.cloudToDevice.title",
            "options.supabase.manualSync.review.cloudToDevice.needsReview",
            "options.supabase.manualSync.review.cloudToDevice.noChanges",
            "options.supabase.manualSync.review.deviceToCloud.title",
            "options.supabase.manualSync.review.deviceToCloud.localChanges",
            "options.supabase.manualSync.review.deviceToCloud.noChanges",
            "options.supabase.manualSync.review.prices.title",
            "options.supabase.manualSync.review.prices.needsDedicatedStep",
            "options.supabase.manualSync.review.prices.needsUpdate",
            "options.supabase.manualSync.review.prices.noAction",
            "options.supabase.manualSync.review.prices.newFound",
            "options.supabase.manualSync.review.prices.applied",
            "options.supabase.manualSync.review.prices.readyToSend",
            "options.supabase.manualSync.review.prices.sent",
            "options.supabase.manualSync.review.prices.alreadyPresent",
            "options.supabase.manualSync.review.prices.needsCheck",
            "options.supabase.manualSync.review.prices.notUpdated",
            "options.supabase.manualSync.review.attention.title",
            "options.supabase.manualSync.review.attention.message",
            "options.supabase.manualSync.review.footer.readyToUpdateDevice",
            "options.supabase.manualSync.review.footer.updatingDevice",
            "options.supabase.manualSync.review.action.updateDevice",
            "options.supabase.manualSync.review.action.updatingDevice",
            "options.supabase.manualSync.review.action.cancel",
            "options.supabase.manualSync.confirm.updateDevice.title",
            "options.supabase.manualSync.confirm.updateDevice.message",
            "options.supabase.manualSync.confirm.updateDevice.cancel",
            "options.supabase.manualSync.confirm.updateDevice.update",
            "options.supabase.manualSync.apply.blocked.refreshRequired",
            "options.supabase.manualSync.apply.blocked.incompleteCheck",
            "options.supabase.manualSync.apply.blocked.needsAttention",
            "options.supabase.manualSync.apply.blocked.invalidData",
            "options.supabase.manualSync.apply.blocked.stale",
            "options.supabase.manualSync.apply.blocked.noChanges",
            "options.supabase.manualSync.apply.blocked.session",
            "options.supabase.manualSync.apply.blocked.saveFailed",
            "options.supabase.manualSync.badge.manual",
            "options.supabase.manualSync.badge.running",
            "options.supabase.manualSync.badge.needsAccess",
            "options.supabase.manualSync.badge.needsAction",
            "options.supabase.manualSync.badge.localChanges",
            "options.supabase.manualSync.badge.noChanges",
            "options.supabase.manualSync.badge.retry",
            "options.supabase.manualSync.badge.cancelled",
            "options.supabase.manualSync.badge.unavailable",
            "options.supabase.manualSync.badge.localUpdated",
            "options.supabase.manualSync.badge.readyToSend",
            "options.supabase.manualSync.badge.sent",
            "options.supabase.manualSync.badge.needsFix",
            "options.supabase.manualSync.badge.suggested",
            "options.supabase.manualSync.push.state.checking.title",
            "options.supabase.manualSync.push.state.checking.subtitle",
            "options.supabase.manualSync.push.state.ready.title",
            "options.supabase.manualSync.push.state.ready.subtitle",
            "options.supabase.manualSync.push.state.noChanges.title",
            "options.supabase.manualSync.push.state.noChanges.subtitle",
            "options.supabase.manualSync.push.state.blocked.title",
            "options.supabase.manualSync.push.state.blocked.subtitle",
            "options.supabase.manualSync.push.state.failed.title",
            "options.supabase.manualSync.push.state.failed.subtitle",
            "options.supabase.manualSync.push.state.stale.title",
            "options.supabase.manualSync.push.state.stale.subtitle",
            "options.supabase.manualSync.push.state.sending.title",
            "options.supabase.manualSync.push.state.sending.subtitle",
            "options.supabase.manualSync.push.state.succeeded.title",
            "options.supabase.manualSync.push.state.succeeded.subtitle",
            "options.supabase.manualSync.push.state.partial.title",
            "options.supabase.manualSync.push.state.partial.subtitle",
            "options.supabase.manualSync.push.summary.noChanges",
            "options.supabase.manualSync.push.summary.succeeded",
            "options.supabase.manualSync.push.summary.succeededNeedsCheck",
            "options.supabase.manualSync.push.summary.partial",
            "options.supabase.manualSync.push.summary.blocked",
            "options.supabase.manualSync.push.summary.failedBeforeWrite",
            "options.supabase.manualSync.push.summary.interrupted",
            "options.supabase.manualSync.push.summary.stale",
            "options.supabase.manualSync.push.blocked.session",
            "options.supabase.manualSync.push.review.title",
            "options.supabase.manualSync.push.review.subtitle",
            "options.supabase.manualSync.push.review.subtitle.final",
            "options.supabase.manualSync.push.review.subtitle.sending",
            "options.supabase.manualSync.push.review.subtitle.blocked",
            "options.supabase.manualSync.push.review.ready.title",
            "options.supabase.manualSync.push.review.ready.message",
            "options.supabase.manualSync.push.review.attention.title",
            "options.supabase.manualSync.push.review.attention.message",
            "options.supabase.manualSync.push.review.blocked.title",
            "options.supabase.manualSync.push.review.blocked.message",
            "options.supabase.manualSync.push.review.final.title",
            "options.supabase.manualSync.push.review.footer.ready",
            "options.supabase.manualSync.push.review.footer.updateFirst",
            "options.supabase.manualSync.push.review.footer.blocked",
            "options.supabase.manualSync.push.review.footer.sending",
            "options.supabase.manualSync.push.review.footer.final",
            "options.supabase.manualSync.push.review.action.send",
            "options.supabase.manualSync.push.review.action.sending",
            "options.supabase.manualSync.confirm.send.title",
            "options.supabase.manualSync.confirm.send.message",
            "options.supabase.manualSync.confirm.send.cancel",
            "options.supabase.manualSync.confirm.send.send",
            "options.supabase.manualSync.activity.state.ready.title",
            "options.supabase.manualSync.activity.state.ready.subtitle",
            "options.supabase.manualSync.activity.state.success.title",
            "options.supabase.manualSync.activity.state.success.subtitle",
            "options.supabase.manualSync.activity.state.empty.title",
            "options.supabase.manualSync.activity.state.empty.subtitle",
            "options.supabase.manualSync.activity.state.partial.title",
            "options.supabase.manualSync.activity.state.partial.subtitle",
            "options.supabase.manualSync.activity.state.auth.title",
            "options.supabase.manualSync.activity.state.auth.subtitle",
            "options.supabase.manualSync.activity.state.failed.title",
            "options.supabase.manualSync.activity.state.failed.subtitle",
            "options.supabase.manualSync.activity.state.blocked.title",
            "options.supabase.manualSync.activity.state.blocked.subtitle",
            "options.supabase.manualSync.activity.state.cancelled.title",
            "options.supabase.manualSync.activity.state.cancelled.subtitle",
            "options.supabase.manualSync.activity.review.title",
            "options.supabase.manualSync.activity.review.subtitle",
            "options.supabase.manualSync.activity.review.section.title",
            "options.supabase.manualSync.activity.review.ready",
            "options.supabase.manualSync.activity.review.registering",
            "options.supabase.manualSync.activity.review.footer.ready",
            "options.supabase.manualSync.activity.review.footer.registering",
            "options.supabase.manualSync.activity.review.footer.retry",
            "options.supabase.manualSync.activity.review.footer.final",
            "options.supabase.manualSync.activity.review.action.register",
            "options.supabase.manualSync.activity.review.action.registering",
            "options.supabase.manualSync.activity.summary.success",
            "options.supabase.manualSync.activity.summary.empty",
            "options.supabase.manualSync.activity.summary.partialRetryable",
            "options.supabase.manualSync.activity.summary.authRequired",
            "options.supabase.manualSync.activity.summary.retryableFailure",
            "options.supabase.manualSync.activity.summary.blocked",
            "options.supabase.manualSync.activity.summary.cancelled",
            "options.supabase.manualSync.activity.summary.registered",
            "options.supabase.manualSync.activity.summary.waiting",
            "options.supabase.manualSync.activity.summary.notRegisterable",
            "options.supabase.manualSync.confirm.activity.title",
            "options.supabase.manualSync.confirm.activity.message",
            "options.supabase.manualSync.confirm.activity.cancel",
            "options.supabase.manualSync.confirm.activity.register",
            "options.supabase.manualSync.confirm.discard.title",
            "options.supabase.manualSync.confirm.discard.message",
            "options.supabase.manualSync.confirm.discard.cancel",
            "options.supabase.manualSync.confirm.discard.discard",
            "options.supabase.manualSync.disabled.authChanging",
            "options.supabase.manualSync.disabled.accessUnavailable"
        ]

        for language in supportedLanguages {
            let strings = try loadStrings(language: language)
            for key in keys {
                XCTAssertNotNil(strings[key], "\(key) missing in \(language)")
                XCTAssertFalse(strings[key]?.isEmpty ?? true, "\(key) empty in \(language)")
            }
        }
    }

    func testTask081ManualSyncReleaseCopyAvoidsIdentifiersAndRawDataShapes() throws {
        let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#

        for language in supportedLanguages {
            let strings = try loadStrings(language: language)
            let releaseValues = strings
                .filter { $0.key.hasPrefix("options.supabase.manualSync.") }
                .map(\.value)

            for value in releaseValues {
                XCTAssertNil(
                    value.range(of: uuidPattern, options: .regularExpression),
                    "\(language) Release copy contains UUID-like data: \(value)"
                )
                XCTAssertFalse(value.contains("{"), "\(language) Release copy looks like raw JSON: \(value)")
                XCTAssertFalse(value.contains("}"), "\(language) Release copy looks like raw JSON: \(value)")
            }
        }
    }

    func testTask067ManualSyncReleaseCopyAvoidsForbiddenJargon() throws {
        let forbiddenTerms = [
            "outbox",
            "drain",
            "sync_events",
            "dto",
            "syncpreview",
            "rpc",
            "baseline",
            "payload",
            "owneruserid",
            "owner_user_id",
            "jwt",
            "rls",
            "retryable",
            "uuid",
            "barcode",
            "json",
            "record_sync_event",
        ]

        for language in supportedLanguages {
            let strings = try loadStrings(language: language)
            let releaseValues = strings
                .filter { $0.key.hasPrefix("options.supabase.manualSync.") }
                .map(\.value)

            XCTAssertFalse(releaseValues.isEmpty, "No manual sync release values for \(language)")

            for value in releaseValues {
                let normalized = value.lowercased()
                for term in forbiddenTerms {
                    XCTAssertFalse(
                        normalized.contains(term),
                        "\(language) Release copy contains forbidden term \(term): \(value)"
                    )
                }
            }
        }
    }

    func testTask072ManualSyncReleaseCopyDoesNotClaimCloudUpdatedWithoutPreview() throws {
        let forbiddenClaims = [
            "cloud aggiornato",
            "tutto aggiornato",
            "everything is up to date",
            "todo actualizado",
            "全部已更新",
            "fully synced",
            "todo sincronizado",
            "tutto sincronizzato",
            "全部同步",
        ]

        for language in supportedLanguages {
            let strings = try loadStrings(language: language)
            let releaseValues = strings
                .filter { $0.key.hasPrefix("options.supabase.manualSync.") }
                .map(\.value)

            for value in releaseValues {
                let normalized = value.lowercased()
                for claim in forbiddenClaims {
                    XCTAssertFalse(
                        normalized.contains(claim),
                        "\(language) Release copy makes an unverified cloud-updated claim: \(value)"
                    )
                }
            }
        }
    }

    func testTask072ManualSyncLocalizationKeysHaveNoDuplicates() throws {
        for language in supportedLanguages {
            let source = try readSource("iOSMerchandiseControl/\(language).lproj/Localizable.strings")
            let keys = extractLocalizationKeys(from: source)
                .filter { $0.hasPrefix("options.supabase.manualSync.") }
            XCTAssertEqual(keys.count, Set(keys).count, "Duplicate manual sync localization key in \(language)")
        }
    }

    func testTask067OptionsViewDoesNotUseSupabaseClientDirectly() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertFalse(source.contains("SupabaseClient"))
        XCTAssertFalse(source.contains(".rpc"))
    }

    func testTask067ManualSyncReleaseSourcesAvoidForbiddenScope() throws {
        let optionsViewSource = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: optionsViewSource)
        let factorySource = try readSource("iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift")
        let viewModelSource = try readSource("iOSMerchandiseControl/SupabaseManualSyncViewModel.swift")
        let combined = [releaseCardSource, factorySource, viewModelSource].joined(separator: "\n")

        for forbidden in ["BGTask", "Timer", "Realtime", "worker", "polling", ".channel", "SupabaseClient", ".rpc", ".from", ".upsert", "TASK-068"] {
            XCTAssertFalse(combined.contains(forbidden), "Forbidden release scope term found: \(forbidden)")
        }
    }

    func testTask072ReleaseCardRendersPresentationStateOnly() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: source)

        XCTAssertTrue(releaseCardSource.contains("viewModel.presentationState"))
        XCTAssertTrue(releaseCardSource.contains("presentation.statusDetailText"))
        XCTAssertTrue(releaseCardSource.contains("presentation.userFacingSummary"))
        XCTAssertTrue(releaseCardSource.contains("viewModel.presentationState.reviewSheet"))
        XCTAssertTrue(releaseCardSource.contains("presentation.primaryAction"))
        XCTAssertTrue(releaseCardSource.contains("presentation.secondaryAction"))
        XCTAssertTrue(releaseCardSource.contains("ProgressView()"))
        XCTAssertTrue(releaseCardSource.contains(".buttonStyle(.borderedProminent)"))
        XCTAssertTrue(releaseCardSource.contains(".buttonStyle(.bordered)"))
        XCTAssertFalse(releaseCardSource.contains("stateKey"))
        XCTAssertFalse(releaseCardSource.contains("actionKey"))
    }

    func testTask077ReleaseCardRendersReviewSheetFromPreparedPresentationOnly() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: source)

        XCTAssertTrue(releaseCardSource.contains(".sheet("))
        XCTAssertTrue(releaseCardSource.contains("isPresented: $isReviewSheetPresented"))
        XCTAssertTrue(releaseCardSource.contains("viewModel.presentationState.reviewSheet"))
        XCTAssertTrue(releaseCardSource.contains("SupabaseManualSyncReviewSheet("))
        XCTAssertTrue(releaseCardSource.contains("review: review"))
        XCTAssertTrue(releaseCardSource.contains("primaryAction:"))
        XCTAssertTrue(releaseCardSource.contains("review.sections"))
        XCTAssertTrue(releaseCardSource.contains(".disabled(!review.primaryActionIsEnabled)"))
        XCTAssertTrue(releaseCardSource.contains("review.primaryActionIsLoading"))
        XCTAssertTrue(releaseCardSource.contains(".controlSize(.small)"))
        XCTAssertFalse(releaseCardSource.contains("SupabaseManualSyncRunSummary"))
        XCTAssertFalse(releaseCardSource.contains("SupabaseManualSyncRemotePreviewSummary"))
        XCTAssertFalse(releaseCardSource.contains("SyncPreview"))
        XCTAssertFalse(releaseCardSource.contains("SupabasePullApplyService"))
        XCTAssertFalse(releaseCardSource.contains("SyncEventOutboxDrainService"))
    }

    func testTask074ReleaseCardRendersPreparedSummaryOnly() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: source)

        XCTAssertTrue(releaseCardSource.contains("presentation.userFacingSummary"))
        XCTAssertTrue(releaseCardSource.contains("summary.message"))
        XCTAssertFalse(releaseCardSource.contains("SupabaseManualSyncRunSummary"))
        XCTAssertFalse(releaseCardSource.contains("SupabaseManualSyncRemotePreviewSummary"))
        XCTAssertFalse(releaseCardSource.contains("SyncPreview"))
        XCTAssertFalse(releaseCardSource.contains("recommendedUserMessageKey"))
        XCTAssertFalse(releaseCardSource.contains("failureCategory"))
    }

    func testTask074SummaryIsNotPersistedByReleaseSurface() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: source)
        let viewModelSource = try readSource("iOSMerchandiseControl/SupabaseManualSyncViewModel.swift")
        let combined = [releaseCardSource, viewModelSource].joined(separator: "\n")

        for forbidden in ["UserDefaults", "AppStorage", "FileManager", ".write(", "@Model"] {
            XCTAssertFalse(combined.contains(forbidden), "Summary surface must remain volatile; found \(forbidden)")
        }
    }

    func testTask072ReleaseCardDeclaresProminentActionStylesForCardAndSheet() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: source)

        XCTAssertEqual(countOccurrences(of: ".buttonStyle(.borderedProminent)", in: releaseCardSource), 2)
        XCTAssertEqual(countOccurrences(of: ".buttonStyle(.bordered)", in: releaseCardSource), 2)
    }

    func testTask073ReleaseFactoryBuildsReadOnlyRemotePreviewProvider() throws {
        let factorySource = try readSource("iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift")

        XCTAssertTrue(factorySource.contains("pullPreviewService: SupabasePullPreviewService? = nil"))
        XCTAssertTrue(factorySource.contains("manualPushService: SupabaseManualPushService? = nil"))
        XCTAssertTrue(factorySource.contains("remotePreviewAdapter = pullPreviewService.map"))
        XCTAssertTrue(factorySource.contains("SupabaseManualSyncPullPreviewAdapter(service: $0, context: context)"))
        XCTAssertTrue(factorySource.contains("SupabaseManualSyncReleasePushAdapter"))
        XCTAssertTrue(factorySource.contains("remotePreviewProvider: remotePreviewProvider"))
        XCTAssertTrue(factorySource.contains("catalogPushProvider: catalogPushProvider"))
        XCTAssertTrue(factorySource.contains("remotePreviewStaging: remotePreviewAdapter"))
        XCTAssertTrue(factorySource.contains("localApplyService: SupabasePullApplyService()"))
        XCTAssertTrue(factorySource.contains("localApplyContext: context"))
        XCTAssertTrue(factorySource.contains("activityRecorder: (any SyncEventRecording)? = nil"))
        XCTAssertTrue(factorySource.contains("activityRegistrationProvider"))
        XCTAssertTrue(factorySource.contains("SupabaseManualSyncReleaseActivityRegistrationAdapter"))
        XCTAssertFalse(factorySource.contains("supportsGuidedManualSync: true"))
        XCTAssertFalse(factorySource.contains("SyncEventOutboxDrainService"))
    }

    func testTask081ActivityRegistrationDrainIsAdapterOwned() throws {
        let optionsViewSource = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: optionsViewSource)
        let factorySource = try readSource("iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift")
        let viewModelSource = try readSource("iOSMerchandiseControl/SupabaseManualSyncViewModel.swift")
        let adapterSource = try readSource("iOSMerchandiseControl/SupabaseManualSyncReleaseActivityRegistrationAdapter.swift")

        XCTAssertTrue(adapterSource.contains("SyncEventOutboxDrainService"))
        XCTAssertTrue(adapterSource.contains("drainOnce"))
        XCTAssertFalse(releaseCardSource.contains("SyncEventOutboxDrainService"))
        XCTAssertFalse(releaseCardSource.contains("drainOnce"))
        XCTAssertFalse(factorySource.contains("SyncEventOutboxDrainService"))
        XCTAssertFalse(factorySource.contains("drainOnce"))
        XCTAssertFalse(viewModelSource.contains("SyncEventOutboxDrainService"))
        XCTAssertFalse(viewModelSource.contains("drainOnce"))
        XCTAssertFalse(factorySource.contains("supportsGuidedManualSync: true"))
    }

    func testTask069ReleaseFactoryUsesLocalPendingSnapshotProvider() throws {
        let factorySource = try readSource("iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift")

        XCTAssertTrue(factorySource.contains("SupabaseManualSyncLocalPendingSnapshotProvider"))
        XCTAssertTrue(factorySource.contains("SupabaseManualSyncCatalogPendingAdapter"))
        XCTAssertTrue(factorySource.contains("SupabaseManualSyncOutboxPendingAdapter"))
        XCTAssertFalse(factorySource.contains("SupabaseManualSyncReleasePendingSnapshotProvider"))
    }

    func testTask069ReadOnlyReleaseSourcesAvoidForbiddenLiveCalls() throws {
        let optionsViewSource = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: optionsViewSource)
        let paths = [
            "iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift",
            "iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift",
            "iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift",
            "iOSMerchandiseControl/SupabaseManualSyncViewModel.swift",
        ]
        let combined = try ([releaseCardSource] + paths.map(readSource))
            .joined(separator: "\n")

        for forbidden in [
            "SupabaseClient",
            ".rpc",
            ".from",
            ".upsert",
            "record_sync_event",
            "drainOnce",
            "SyncEventOutboxDrainService",
            "SyncEventOutboxEnqueueService",
            "BGTask",
            "Timer",
            "Realtime",
            "worker",
        ] {
            XCTAssertFalse(combined.contains(forbidden), "Forbidden TASK-069 source term found: \(forbidden)")
        }
    }

    func testTask091ReleaseCardUsesConfirmationDialogsForMutationsAndDiscard() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: source)

        XCTAssertEqual(countOccurrences(of: ".confirmationDialog(", in: releaseCardSource), 4)
        XCTAssertTrue(releaseCardSource.contains("options.supabase.manualSync.confirm.updateDevice.title"))
        XCTAssertTrue(releaseCardSource.contains("options.supabase.manualSync.confirm.send.title"))
        XCTAssertTrue(releaseCardSource.contains("options.supabase.manualSync.confirm.activity.title"))
        XCTAssertTrue(releaseCardSource.contains("options.supabase.manualSync.confirm.discard.title"))
        XCTAssertFalse(releaseCardSource.contains(".alert("))
    }

    func testTask091AppWiresBoundedReleasePreview() throws {
        let source = try readSource("iOSMerchandiseControl/iOSMerchandiseControlApp.swift")

        XCTAssertTrue(source.contains("SupabasePullPreviewService("))
        XCTAssertTrue(source.contains("catalogRowBudget: 5_000"))
        XCTAssertTrue(source.contains("productPriceRowBudget: 5_000"))
    }

    func testTask092RootForegroundHostUsesPresenterSharedViewModelAndBusyGating() throws {
        let contentSource = try readSource("iOSMerchandiseControl/ContentView.swift")
        let hostSource = try extractRootForegroundHostSource(from: contentSource)
        let optionsSource = try readSource("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertTrue(contentSource.contains("manualSyncViewModel: manualSyncViewModel"))
        XCTAssertTrue(contentSource.contains("manualSyncCancelHandler: cancelForegroundCheck"))
        XCTAssertTrue(optionsSource.contains("viewModel: manualSyncViewModel"))
        XCTAssertTrue(optionsSource.contains("cancelHandler?()"))
        XCTAssertTrue(hostSource.contains("viewModel.rootPresentationState"))
        XCTAssertTrue(hostSource.contains("Task.yield()"))
        XCTAssertTrue(hostSource.contains("startForegroundSemiAutomaticCheckIfAllowed(source: .rootForeground)"))
        XCTAssertTrue(hostSource.contains("safeAreaInset(edge: .top"))
        XCTAssertTrue(hostSource.contains("activityCenter.isBusy"))
        XCTAssertTrue(hostSource.contains("markForegroundCheckSkippedBecauseBusy()"))
        XCTAssertTrue(hostSource.contains("state.primaryActionID != nil"))
        XCTAssertTrue(hostSource.contains("selectedTab != 3"))

        for forbidden in ["SyncPreview", "ProductPrice", "baseline", "outbox", "SupabaseClient", ".rpc", ".from", ".upsert"] {
            XCTAssertFalse(hostSource.localizedCaseInsensitiveContains(forbidden), "Root host should stay presenter-only; found \(forbidden)")
        }
    }

    func testTask092WorkflowBusyGatingIsDeclaredOnInteractiveSurfaces() throws {
        let sources = try [
            "iOSMerchandiseControl/InventoryHomeView.swift",
            "iOSMerchandiseControl/DatabaseView.swift",
            "iOSMerchandiseControl/PreGenerateView.swift",
            "iOSMerchandiseControl/GeneratedView.swift",
            "iOSMerchandiseControl/OptionsView.swift",
        ].map(readSource).joined(separator: "\n")

        for marker in [
            ".foregroundCloudWorkflowActivity(.importExcel",
            ".foregroundCloudWorkflowActivity(.exportShare",
            ".foregroundCloudWorkflowActivity(.scanner",
            ".foregroundCloudWorkflowActivity(.editing",
            ".foregroundCloudWorkflowActivity(.manualSyncSheet",
            ".foregroundCloudWorkflowActivity(.confirmationDialog",
            ".foregroundCloudWorkflowActivity(.localProgress",
        ] {
            XCTAssertTrue(sources.contains(marker), "Missing TASK-092 busy marker \(marker)")
        }
    }

    func testTask092RootForegroundSourcesAvoidForbiddenAutomationScope() throws {
        let contentSource = try extractRootForegroundHostSource(from: readSource("iOSMerchandiseControl/ContentView.swift"))
        let policySource = try readSource("iOSMerchandiseControl/SupabaseManualSyncSemiAutomaticPolicy.swift")
        let viewModelSource = try readSource("iOSMerchandiseControl/SupabaseManualSyncViewModel.swift")
        let combined = [contentSource, policySource, viewModelSource].joined(separator: "\n")

        for forbidden in ["BGTaskScheduler", "Timer", "Realtime", "polling", ".channel", "SupabaseClient", ".rpc", ".from", ".upsert"] {
            XCTAssertFalse(combined.contains(forbidden), "Forbidden TASK-092 foreground source term found: \(forbidden)")
        }
        XCTAssertFalse(combined.localizedCaseInsensitiveContains("automatic apply"))
        XCTAssertFalse(combined.localizedCaseInsensitiveContains("automatic push"))
        XCTAssertFalse(combined.localizedCaseInsensitiveContains("automatic drain"))
    }

    func testTask092RootForegroundCopyIsLocalizedNotHardcodedInSwift() throws {
        let swiftSources = try [
            "iOSMerchandiseControl/ContentView.swift",
            "iOSMerchandiseControl/SupabaseManualSyncViewModel.swift",
        ].map(readSource).joined(separator: "\n")

        XCTAssertTrue(swiftSources.contains("options.supabase.manualSync.root.changes.title"))
        for literal in [
            "Cloud updates are ready",
            "Controllo cloud non riuscito",
            "Hay actualizaciones",
            "正在检查更新",
        ] {
            XCTAssertFalse(swiftSources.contains(literal), "TASK-092 user copy must stay in Localizable.strings")
        }
    }

    func testTask067ReleaseCardSourceAvoidsDeveloperJargon() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: source)

        for forbidden in ["DTO", "SyncPreview", "outbox", "drain", "sync_events", "RPC", "payload", "retryable", "UUID", "JSON", "record_sync_event", "barcode"] {
            XCTAssertFalse(releaseCardSource.localizedCaseInsensitiveContains(forbidden))
        }
    }

    func testTask067DebugOutboxCardRemainsDebugOnlyAndSeparateFromReleaseCard() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardRange = try XCTUnwrap(source.range(of: "private struct SupabaseManualSyncReleaseCard"))
        let debugCardRange = try XCTUnwrap(source.range(of: "#if DEBUG\nprivate struct SyncEventOutboxDrainDebugCard"))

        XCTAssertLessThan(releaseCardRange.lowerBound, debugCardRange.lowerBound)
    }

    private func extractReleaseCardSource(from source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: "private struct SupabaseManualSyncReleaseCard"))
        let end = try XCTUnwrap(source.range(of: "// MARK: - Header di sezione"))
        XCTAssertLessThan(start.lowerBound, end.lowerBound)
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private func extractRootForegroundHostSource(from source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: "private struct SupabaseManualSyncForegroundRootHost"))
        let end = try XCTUnwrap(source.range(of: "#Preview"))
        XCTAssertLessThan(start.lowerBound, end.lowerBound)
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private func readSource(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func loadStrings(language: String) throws -> [String: String] {
        let url = repoRoot()
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent("\(language).lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try XCTUnwrap(plist as? [String: String])
    }

    private func extractLocalizationKeys(from source: String) -> [String] {
        let pattern = #"\"([^\"]+)\"\s*="#
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        return regex.matches(in: source, range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[range])
        }
    }

    private func countOccurrences(of needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
