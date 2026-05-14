# TASK-108 Evidence 37 — iOS / Android Sync Performance Comparison

Date: 2026-05-14 00:38 -0400

Scope:
- Compare iOS and Android realistically for the same sync phases without claiming “faster” where live app-auth was not available on both platforms.
- Record what was measured, what was only statically verified, and what remains blocked.

Devices / sessions:
- iOS simulator: iPhone 17 Pro simulator used for current Debug/Release build and live app-auth partial run.
- Android device: OnePlus IN2013 (`8ac48ff0`) used for install/launch/Options smoke.
- iOS app-auth: signed-in session available in the simulator for one live `Sync now` attempt.
- Android app-auth: not available; Android device was signed out.

| Scenario | iOS evidence | Android evidence | Comparison |
|----------|--------------|------------------|------------|
| Cloud count / check | Live app-auth reached remote preview/check; earlier authenticated preview saw about 19,888 products / 101 suppliers / 64 categories and ProductPrice sample 1,000. Current run showed progress in Options/root. | Static path verified; Android logs `sync_start`, `sync_stage`, `sync_finish`, but no signed-in live run was executed. | No winner. Android has better structured timing logs; iOS currently has UI progress and limited log evidence. |
| Catalog pull/apply | Live current run populated local simulator DB to 19,886 products, 81 suppliers, 49 categories. Build/test passed. | Static path uses repository work on `Dispatchers.IO`; no live signed-in apply timed in this pass. | iOS proved local apply in this environment; Android architecture is stronger for background dispatcher separation. |
| ProductPrice paged apply | iOS local DB reached 15,386 ProductPrice rows in the current run, and previous large pass reached 53,022 rows after removing the fixed cap. | Android ProductPrice path is paged/chunked in repository/data source. No live signed-in timing. | Both are paged. No speed claim without same live dataset and signed-in accounts. |
| History/session pull/push | iOS global flow attempts History/session sync, but the two dirty local entries stayed dirty and no remote id/fingerprint was written. | Android full refresh includes History/session refresh; no signed-in live run in this pass. | iOS live result is blocked/failed for History; Android remains functional reference by code, not by live evidence here. |
| Local pending push | iOS Options now counts dirty History/session pending work and review says device-to-cloud work exists. Actual push/read-back was not verified. | Android repository has staged push phases and structured logs; live signed-in push not executed. | No winner. Both require a live app-auth push/read-back run for a real efficiency claim. |
| UI responsiveness | iOS simulator scroll remained responsive during cloud count/progress smoke; SwiftData work is batched/yielding but still uses the current context actor. | Android repository runs heavy sync on `Dispatchers.IO`; Options card rendered without blocking UI in signed-out smoke. | Android has a cleaner dispatcher story. iOS has mitigation, not a full background-context refactor. |

iOS current local counts after live partial run:
- Products: 19,886.
- Suppliers: 81.
- Categories: 49.
- ProductPrice rows: 15,386.
- History entries: 2.
- Dirty History entries: 2.
- Baseline records: 0.

Timing quality:
- The iOS observations are UI/log/manual timing quality, not profiler-grade signpost measurements.
- Android has structured `sync_start` / `sync_stage` / `sync_finish` instrumentation, but this pass did not have a signed-in Android session to collect comparable live durations.

Takeaways:
- Do not claim iOS or Android is globally faster from this pass.
- Android’s stage logging should be ported more explicitly to iOS if TASK-108 continues into performance hardening.
- iOS’s compact Options `Local database status` card was useful enough to port to Android.
- iOS still needs either background SwiftData context work or stronger signpost logging before a serious large-sync performance verdict.

Verdict:
- Performance comparison status: PARTIAL / NO SPEED CLAIM.
- Cross-platform live performance E2E remains blocked by missing Android app-auth and incomplete iOS History/session live sync.

