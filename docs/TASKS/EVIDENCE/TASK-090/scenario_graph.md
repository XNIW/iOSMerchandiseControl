# TASK-090 scenario graph

Timestamp locale: 2026-05-09 17:03 -0400

## A -> S -> I

Android -> Supabase -> iOS acceptance path:

1. Android writes or updates sandbox catalog row(s) under a task prefix.
2. Supabase RLS/read-back confirms only owner-scoped sandbox rows.
3. iOS pull preview reads remote catalog and ProductPrice rows.
4. iOS review sheet separates cloud-to-device changes from device-to-cloud changes.
5. iOS local apply runs only after confirmation and rechecks stale/session guards.
6. Evidence records aggregate counts and zero logical duplicates.

TASK-090 status: `PARTIAL`, using TASK-087 runtime scoped evidence as reference. New `TASK090_*` runtime was not forced because owner/session/collision live gate was not verified in this execution slice.

## I -> S -> A

iOS -> Supabase -> Android acceptance path:

1. iOS prepares local catalog/ProductPrice push plans after a completed preview.
2. iOS review sheet shows what will be sent.
3. User confirms send; catalog push verifies read-back and baseline; ProductPrice push verifies exact row match.
4. ProductPrice local `remoteID` links only after verified success.
5. Android reads/pulls sandbox rows as functional reference.
6. Evidence records aggregate counts, current/previous price coherence, and zero duplicate logical keys.

TASK-090 status: `PARTIAL`, using TASK-087/TASK-088 evidence as reference. No new write live was executed.

## Import/export runtime

iOS app -> XLSX file -> iOS app acceptance path:

1. Export products or full DB from synthetic local dataset.
2. Record file size and row counts.
3. Re-import using the matching import path.
4. Confirm inserted/updated/already-present/unresolved counts.
5. Confirm zero logical duplicates for barcode/ProductPrice keys.

TASK-090 status: `PARTIAL` until a dedicated app-file-app runtime run or a scoped XCTest/harness validates the round-trip in this task.
