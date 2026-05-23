# TASK-117 - Final Acceptance Matrix

Date: 2026-05-23 18:19:39 -0400

| CA | Status | Evidence |
|---|---:|---|
| CA-117-01 | PASS | root-host-clean `p54521`; no-legacy `p36744` |
| CA-117-02 | PASS | root-host-clean `p54521`; no-legacy `p36744` |
| CA-117-03 | PASS | options-observer-only `p54523`; no-legacy `p36744` |
| CA-117-04 | PASS | duplicate-sync-owner `p55793` |
| CA-117-05 | PASS | duplicate-sync-owner `p55793`; Debug/Release `p38477`/`p39085` |
| CA-117-06 | PASS | automatic-contracts-clean `p54522` |
| CA-117-07 | PASS | automatic-contracts-clean `p54522` |
| CA-117-08 | PASS | no-legacy `p36744`; manual boundary evidence 18 |
| CA-117-09 | PASS | adapter deleted; Debug/Release PASS |
| CA-117-10 | PASS | incremental-apply-contract `p55792` |
| CA-117-11 | PASS | incremental-apply-contract `p55792` |
| CA-117-12 | PASS | iOS sync tests `p40121` |
| CA-117-13 | PASS | duplicate-sync-owner `p55793`; sync tests `p40121` |
| CA-117-14 | PASS | no-full-pull-normal-path `p36815` |
| CA-117-15 | PASS | duplicate-sync-owner `p55793` |
| CA-117-16 | BLOCKED_EXTERNAL | l10n PASS `p37624`; simulator smoke PASS `p61133`; Options smoke BLOCKED `p48482` |
| CA-117-17 | PASS | deleted adapter/debug card; no-legacy `p36744`; builds PASS |
| CA-117-18 | PASS | Debug `p38477`; Release `p39085` |
| CA-117-19 | PASS | iOS sync tests `p40121` |
| CA-117-20 | PASS | no-legacy `p36744` |
| CA-117-21 | PASS | no-full-pull-normal-path `p36815` |
| CA-117-22 | BLOCKED_EXTERNAL | physical/live/account gates blocked by session/device/Supabase linked readiness; performance budget PASS |

## Verdict
Local architecture cleanup is implemented and verified. TASK-117 cannot move to REVIEW/DONE because CA-117-16 Options smoke and CA-117-22 live/device/account matrix have external blockers.

## Review addendum 2026-05-23 18:19:39 -0400

See `28-review-3174652.md`. Review fixes renamed automatic legacy l10n/runtime keys, added UserDefaults watermark migration fallback, removed the pre-existing `SyncEventIncrementalDomainApplyService`/`WatermarkStore` actor-isolation warning cluster, and reran required gates. Residual caveat: automatic push adapters are still shared with manual-boundary concrete types and should be split in a future architecture cleanup before claiming the architecture is perfect.
