# UX / Privacy / Accessibility Notes

## iOS UX Privacy

- Account status and debug details now avoid full owner UUID/email exposure.
- Error diagnostics shown to the user are privacy-sanitized and avoid raw URLs, tokens, UUIDs, long numeric identifiers and emails.
- Loading/error/retry surfaces already exist around Supabase options/manual sync flows; reviewed statically.

## Accessibility Static Notes

- Existing SwiftUI controls use native `Button`, `Label`, `ProgressView`, `LabeledContent`, `DisclosureGroup` and explicit accessibility labels/hints in manual sync/outbox areas.
- TASK-101 did not introduce new custom controls.
- Dynamic Type/VoiceOver was not manually exercised in Simulator in this execution; static SwiftUI structure remains native-friendly.

## Residual

- Full accessibility UI pass remains a release-candidate manual task if product readiness needs a complete screen-by-screen audit.

