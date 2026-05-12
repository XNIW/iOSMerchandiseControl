# 10 - Offline / Retry

## Setup

Run id: `TASK103_REAL_R1778622799_`.

## Steps

1. Create one synthetic local pending catalog product under `TASK103_REAL_R1778622799_`.
2. Mark the selected pending batch sent.
3. Execute push through a TASK-103 test gateway that simulates Supabase unreachable before any write.
4. Mark the same batch retryable.
5. Retry through the real authenticated Supabase client.
6. Read back remote scoped product and run no-op planner.

## Expected

Pending survives failed network attempt, retry is explicit, remote contains one product, no duplicate and no pending batch remains.

## Observed

Device XCTest output:

`TASK103_IOS_OFFLINE_RETRY owner_hash=ad3d747e936c offline_status=failedBeforeWrite retry_status=completed remote_products=1 no_duplicate=true no_op=true`

Scoped SQL canary read-back before cleanup:

- `TASK103_REAL_R1778622799_OFFLINE_0001`
- product name `TASK103_REAL_R1778622799_CANARY_OFFLINE_01`
- purchase `82`, retail `92`
- zero ProductPrice rows expected for this retry-only catalog scenario

## Result

`PASS` for CA-103-13.

## Notes/Redactions

The network interruption was simulated inside the iOS device XCTest through a reversible network-down remote gateway. No backend policy, schema, RLS or infrastructure setting was changed.
