# TASK-096 UX Acceptance

Status: READY FOR REVIEW.

UX gates to verify:

- one primary CTA on Release sync surfaces;
- maximum one secondary CTA;
- no automatic modal for foreground check or lifecycle interruption;
- no user-facing technical terms such as idempotenza, RunGate, lifecycle, stale baseline;
- no success message when remote write is uncertain or not verified;
- no interruption of import/export/scanner/editing/review flows by automatic sync UI.

Evidence target:

- `SupabaseManualSyncReleaseUITests`;
- static review of `ContentView.swift` root foreground host;
- static review of `OptionsView.swift` Release manual sync card.

## Result

PASS.

- `SupabaseManualSyncReleaseUITests` passed 24/0 and covers Release copy/localization, no forbidden jargon, presentation-only card, confirmation dialogs for mutative/discard actions, root foreground localization, shared ViewModel and busy gating.
- `ContentView.swift` root foreground host is non-modal and uses `ForegroundCloudWorkflowActivityCenter` busy tokens to avoid disturbing import/export/share/scanner/editing/review/dialog/progress flows.
- `OptionsView.swift` Release card renders state from the shared ViewModel; review and mutative operations remain user-initiated; background interruption routes through lifecycle cancellation instead of a success claim.
- No localization strings were changed in TASK-096; `LocalizationCoverageTests` and `plutil -lint` still pass.
