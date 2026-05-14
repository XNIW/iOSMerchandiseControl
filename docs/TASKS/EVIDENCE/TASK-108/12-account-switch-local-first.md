# TASK-108 Evidence 12 — Account Switch / Local First

Status: EXECUTED (STATIC + UNIT).

Expected behavior:
- Sign-out does not wipe local data.
- Sign-in with another account must not silently apply/push previous-owner pending changes.
- Options must distinguish OAuth signed-in from remote access/baseline state.

Evidence:
- Signed-in remote auth failures now map to account check / Check cloud instead of disabled Sign in.
- Existing access-change tests still PASS.
- Runtime account switch with live Supabase NOT RUN.

FIX/COMPLETION update 2026-05-13:
- History/session push/pull fail closed when the authenticated owner is missing or mismatched.
- Pending History/session changes remain local until a valid account can send them.
- Full account-switch live matrix remains NOT RUN because no authenticated app session was available.
