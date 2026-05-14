# TASK-108 Evidence 22 — Options Cleanup Audit

Status: EXECUTED.

Timestamp: 2026-05-13 20:45 -0400.

Before screenshots:
- `screenshots/2026-05-13-options-before-cloud-account.jpg`
- `screenshots/2026-05-13-options-before-diagnostics-sprawl.jpg`

Before visible sections:
- Theme.
- Language.
- Cloud synchronization Release card.
- Supabase sync access raw/debug card.
- Developer diagnostics.
- Advanced.
- Manual price history push.
- Outbox sync_events.
- Local Supabase baseline.
- Recent sync events.
- Local preflight check/manual push tools.

Decision matrix:

| Section / control | Decision | Reason |
|-------------------|----------|--------|
| Theme | Keep public | Core user preference. |
| Language | Keep public | Core user preference. |
| Cloud account | Keep public, first cloud row | User needs clear sign-in/sign-out and account state. |
| Cloud sync Release card | Keep public only after signed-in/transitioning | Signed-out users should see Accedi, not "Check not completed" as primary state. |
| Local database status | Add public section | User needs local DB empty/baseline/pending counts without opening debug. |
| Supabase raw access/debug details | Move to Developer diagnostics | Useful for debug, too technical for Release surface. |
| Manual price history push | Move to Developer diagnostics | Manual/debug write tooling, not primary Options content. |
| Outbox sync_events | Move to Developer diagnostics | Technical outbox detail; public surface shows pending count instead. |
| Local Supabase baseline | Move to Developer diagnostics | Public status now summarizes baseline as local database state. |
| Recent sync events | Move to Developer diagnostics | Read-only technical audit trail. |
| Local preflight/manual dry-run/push | Move to Developer diagnostics | Advanced safety tooling, not user-facing Release path. |

After screenshots:
- `screenshots/2026-05-13-options-after-public-cloud-local.jpg`
- `screenshots/2026-05-13-options-after-diagnostics-collapsed.jpg`
- `screenshots/2026-05-13-options-after-dynamic-type-xxl.jpg`

Result:
- Public Options now shows Theme, Language, Cloud account & synchronization, Local database status, and a single collapsed Advanced diagnostics section.
- Signed-out state shows `Accedi` clearly.
- Local database state shows empty counts without exposing baseline/raw sync panels.
- DEBUG tools remain available, but only after expanding Developer diagnostics.

