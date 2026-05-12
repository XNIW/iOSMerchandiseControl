# 08 - Conflict / Stale / Recovery

## Setup

Run id: `TASK103_REAL_R1778622799_`.

## Steps

1. Create CONFLICT_G1 catalog canary under the run prefix.
2. Prepare iOS update apply plan, then mutate local product before apply.
3. Verify apply fails stale and remote catalog remains unchanged.
4. Create CONFLICT_G2 ProductPrice canary and remote price history.
5. Prepare conflicting local ProductPrice with same `(product, type, effectiveAt)` but different price.
6. Verify ProductPrice push dry-run is fail-closed.
7. Verify recovery CTA precedence with existing sync plan resolver.

## Expected

No silent overwrite. Catalog stale is explicit/recoverable. ProductPrice conflict does not push. Auth has higher precedence than permission/stale; stale recovery uses recheck.

## Observed

Device XCTest output:

`TASK103_IOS_CONFLICT_RECOVERY owner_hash=ad3d747e936c catalog_stale=previewStale product_price_conflicts=1 price_ready=0 recovery_auth_action=signInAgain recovery_stale_action=recheck remote_unchanged=true`

Scoped SQL canary read-back before cleanup:

- `TASK103_REAL_R1778622799_CONFLICT_0002`
- product name `TASK103_REAL_R1778622799_CANARY_CONFLICT_G2`
- purchase `62`, retail `72`
- four ProductPrice rows
- effectiveAt range `2026-05-12 16:00:00` to `2026-05-12 16:15:00`

## Result

`PASS` for CA-103-11.

## Notes/Redactions

The conflict path used only synthetic run-prefixed records. No backend policy or schema was altered to force the conflict.
