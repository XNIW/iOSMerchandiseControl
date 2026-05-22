# TASK-114 iOS physical runtime loop user report

Date: 2026-05-22 18:28 -0400
Agent: Codex
Source: manual user report from real physical iPhone after installing the new iOS app and logging into cloud.

## Symptoms
- After cloud login on physical iPhone, automatic sync does not complete in a reasonable time.
- Options shows "Automatic update in progress" / "Actualizacion automatica en curso".
- "Sending History sessions" shows a spinner with `0 / 0`, which is incoherent because there is no visible work.
- Local database status remains "Da riconciliare" / "needs a cloud check" or local data remains different.
- Options feels slow/janky, consistent with possible main-thread work or a sync loop.

## Screenshot path
- No local screenshot file path was provided in this prompt. The user report describes the physical iPhone Options screen as evidence.

## Runtime log excerpt
```text
TASK114_RUNTIME_SYNC source=remoteSyncEvent
syncType=EVENT_INCREMENTAL
eventsFetched=50
eventsProcessed=50
targetedProductsFetched=0
targetedPricesFetched=0
targetedHistoryFetched=0
applied=0
requiresFullRecovery=true
fullPull=false
```

The user reports this pattern repeats many times.

## Initial hypotheses
- `EVENT_INCREMENTAL` may be reading a full page of 50 events that contains no applicable target IDs for the current iOS store, then repeatedly deciding `requiresFullRecovery=true` without scheduling or completing a bounded recovery.
- The sync watermark/checkpoint may not advance, or may be unsafe to advance, causing the same event page or same recovery condition to be retried.
- Full recovery may be required but blocked by single-flight, auth/session readiness, backoff state, or a UI/runtime guard.
- Options may be binding to a sync phase that remains "in progress" even when progress is `0 / 0`.
- Options may be triggering repeated counts/reconcile or remote sync work on appear/body refresh.
- Heavy SwiftData fetch/apply/count work may still run on the main actor during Options updates.

## Stop condition
- Do not restore TASK-114 to DONE unless physical iPhone post-login evidence shows sync becomes idle/success or a stable actionable error, no repeated `EVENT_INCREMENTAL applied=0 requiresFullRecovery=true` loop, no spinner for `0 / 0`, Options remains responsive, and required physical/cross-platform gates are documented.
