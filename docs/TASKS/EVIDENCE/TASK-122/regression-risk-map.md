# TASK-122 Regression Risk Map

- ProductPrice paging/keyset: mitigated by `ios test sync` and ProductPrice apply tests.
- Manual sync regression: mitigated by `ios test manual-sync-regression`.
- Automatic runtime boundary: mitigated by `ios test automatic-architecture`, `ios test automatic-domain`, `composition-import-boundary`, and `transport-protocol-conformance`.
- Xcode membership/stale references: mitigated by `xcode-membership` PASS and Debug/Release build PASS.
- GitHub canonical mismatch: accepted locally by explicit override; still requires remote alignment after REVIEW.
- Live/account/device coverage: not run; remains acceptance risk before any 100% claim.
