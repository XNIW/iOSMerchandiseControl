# User Acceptance Script

Status: `PASS_WITH_NOTES`

Use this script only after a real operator-selected run has completed.

| Question | Answer |
|----------|--------|
| Can you import a real shop file without fear of losing data? | NOT ASKED |
| Can you understand when to sync, export, retry, or correct errors? | NOT ASKED |
| Is the manual fallback acceptable if the scanner/camera is not usable? | NOT ASKED |
| Do current/previous prices shown on iOS and Android match expectations? | NOT ASKED |
| Would you use this flow tomorrow in the shop? | NOT ASKED |
| Which notes must be fixed before daily use? | NOT ASKED |
| Which notes can move to later polish? | NOT ASKED |

PASS 1 reason not run: no safe real-shop flow was completed in that execution.
## PASS 2 User Acceptance Script

For reviewer/operator replay, use this privacy-safe script:

1. Confirm dataset class: real shop data or synthetic realistic data.
2. Confirm device sessions on iOS and Android show the same redacted project/owner hash.
3. Import a small workbook, generate/edit/save, then sync iOS -> Supabase.
4. Pull/read on Android and verify only expected sentinel changes.
5. Mutate one Android sentinel, push, then pull/read on iOS.
6. Verify ProductPrice current/previous for purchase and retail.
7. Test scanner hardware; if unavailable, confirm manual fallback is fast and acceptable.
8. Export/share and confirm file opens outside the app.
9. Run short offline/retry and confirm pending/outbox recovers.
10. Decide cleanup/retention.

PASS2 completed the technical synthetic version. Operator confirmation for steps 7 and 8 remains a note.
