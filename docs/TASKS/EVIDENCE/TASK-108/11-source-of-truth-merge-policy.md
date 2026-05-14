# TASK-108 Evidence 11 — Source of Truth / Merge Policy

Status: EXECUTED (STATIC).

Policy under TASK-108:
- SwiftData remains local-first source of operator work.
- Remote pull applies only after safe preview.
- Local pending blocks unsafe automatic remote overwrite.
- Remote watermark/baseline advances only after successful local apply.

Evidence:
- Auto foreground apply excludes invalid/missing baseline and local pending work.
- Bootstrap preview/apply remains explicit through Options.
- Baseline writer runs only after successful local apply.

FIX/COMPLETION update 2026-05-13:
- History/session merge policy is local-first: pull updates clean entries, restores missing entries, and skips local dirty entries.
- Push ack occurs only after owner-scoped read-back verification.
- Generated and metadata edits mark local history/session dirty before cloud sync, preserving offline-first behavior.
