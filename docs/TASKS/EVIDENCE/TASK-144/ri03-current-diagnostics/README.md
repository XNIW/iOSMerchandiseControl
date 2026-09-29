# R-I03 — current diagnostics versus historical debug state

Fresh authenticated Retry on signed R-I02 Release returned the bounded checkpoint refusal correctly. The Options diagnostics instead displayed an older `keyNotFound(catalog)` stored by a prior DEBUG build, combined with the new progress time. Its owner/anonymous label came from lexical sorting of historical watermark keys. The current raw orchestrator result was first `deviceNotActive`, then `checkpoint_resource_exceeded`; no new recovery decoder bug was established.

Changes are presentation-only in OptionsView. The snapshot reads the canonical orchestrator error/block code, pairs it with lastRunCompletedAt rather than any later progress timestamp, and does not resurrect DEBUG/background strings. Current authenticated owner plus active-account/resolved selectable shop fences replace the watermark heuristic. This only displays the verified selection and does not claim write permission. Diagnostics do not capture a mutation lease, generate a device identity, alter defaults, clear tokens, or mutate stores/journals.

The snapshot is internal for runtime tests; no public API is added. An existing source-test section delimiter was updated to the equivalent struct name, preserving all assertions. Six deterministic tests reproduce precedence, block/success, timestamp association, missing timestamp, effective resolved shop, and signed-out/account-change/unresolved boundaries. The read-only case verifies defaults are unchanged.

Red: 0 PASS / 6 FAIL / 0 SKIP. Green: 123 PASS / 0 FAIL / 0 SKIP across Task118, release UI source contracts, atomic recovery and Storefront. An initial green compile attempt used a String initializer for an already-UUID session identifier; corrected one line before green, with the failed build evidence preserved. No exclusions or weakened tests. Review and final canonical gate are recorded separately after completion.

## Adjacent public card feedback

Live UI and resolver source confirmed generic failed phase/outcome/count checks were labeled a permission problem despite valid authentication. The new generic reason reuses existing localized Cloud check failed title/detail in IT/EN/ES/ZH. Real auth, device, network and historical aligned-outcome precedence remain unchanged, as does automatic retry policy. Intentional UI copy correction only; no existing assertion removed or weakened. Card red:12PASS/1FAIL; integrated green:136PASS/0FAIL/0SKIP.

## Preserved picker precondition failure

First R-I03 full:1371PASS/1FAIL/36SKIP. The picker did appear; its remembered location was Browse > On My iPhone from the executor normal Files exploration. The exported video proves English UI and Recents as a bottom button, not the expected current title. Normal UI restored Recents, and the unchanged test passed1/1. No reset, preference edit, test change, or exclusion. Raw frame and restoration results are indexed in picker-precondition-diagnosis.json. The full result remains failed historical evidence and is superseded only by the separate final run.

Final canonical full: **1374 PASS / 0 FAIL / 36 SKIP**, total1410; 1366 unit/integration +8XCUITest. Release and analyze PASS, no new diagnostics. No retry, exclusions or actor override. All325source/resource files match the signed candidate and approved source. Details and exact private raw paths: [final gate manifest](final-gate-manifest.json), [source fingerprint](final-source-manifest.json). Final exact-SHA CI remains external; no DONE declaration.
