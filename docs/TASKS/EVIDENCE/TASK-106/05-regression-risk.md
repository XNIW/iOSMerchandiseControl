# TASK-106 Regression Risk

## Risks addressed
- **R-T106-01 accessibility drift**: row remains `accessibilityElement(children: .contain)` and buttons keep explicit labels through existing localized strings.
- **R-T106-02 Dynamic Type clipping**: long names allow vertical expansion; `ViewThatFits` moves metrics/metadata/actions to vertical layouts when horizontal space is tight.
- **R-T106-03 functional regressions**: edit, price history, scanner fallback, import menu, export menu, search, and clear search were smoke-tested without changing their business logic.
- **R-T106-04 baseline mismatch**: `HEAD` was confirmed equal to `origin/main` before code changes.

## Residual risk
- No pixel-perfect snapshot automation exists for this screen, so visual regressions still depend on manual/simulator review.
- Real-device camera hardware was not revalidated because TASK-106 only changes layout and scanner presentation/fallback was verified in simulator.
- The small-device smoke copied the synthetic SwiftData store between simulators only for privacy-safe visual validation; this does not change app code or production behavior.

## Follow-up candidates
- Add lightweight UI snapshot coverage for Database empty/populated states if the project later adopts UI snapshot testing.
- Consider a dedicated preview fixture for Database rows if future UI work on this screen becomes frequent.
