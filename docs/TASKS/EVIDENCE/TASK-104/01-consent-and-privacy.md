# Consent And Privacy

Status: `PASS_WITH_NOTES`

## Consent Observed

The user explicitly authorized TASK-104 execution, device work, testing, Supabase access for scoped validation, and use of test data where needed.

That authorization was sufficient to perform build/test/device smoke and read-only Supabase metadata checks. It was not sufficient to treat any discovered local Excel file as an operator-selected real shop file, because no file-by-file consent, backup source, sentinel list, or rollback owner was confirmed during this execution.

## Privacy Decisions

- Real Excel candidates detected outside the repository were not opened, copied, parsed, hashed, renamed in evidence, or committed.
- No real product names, barcodes, owner ids, emails, project refs, paths, prices, screenshots, or raw logs were added to evidence.
- Physical device identifiers and Supabase connection details are redacted in this pack.
- PASS 1 Supabase writes were not performed because consent/backup/owner-session gates were not fully satisfied.

## Result

PASS 1 proceeded to review as `PARTIAL`, not `PASS`, because the real-data consent and backup gates remained incomplete.
## PASS 2 Update

- Consent source: user instruction for TASK-104 EXECUTION PASS 2 explicitly authorized privacy-safe realistic synthetic Excel files, scoped Supabase test data, live write/read-back, device/emulator/physical-device testing, and targeted cleanup/retention.
- Data class used: synthetic realistic shop data only. No real shop Excel, real barcode, real product name, real price list, real screenshot, email, owner id, or full project ref was committed to this evidence pack.
- Verdict boundary: PASS2 is realistic shop acceptance, not real user data acceptance.
- Redaction policy used: project and owner shown only as short hashes; device identities redacted; account email redacted; Supabase rows identified only by run prefix and aggregate counts.
