# TASK-127 ADR - Options Summary Semantics

Decision date: 2026-05-27

The Options local summary and drift/reconciliation summary continue to count:

- active products, suppliers, and categories where `remoteDeletedAt == nil`;
- ProductPrice rows linked to a product whose `remoteDeletedAt == nil`;
- history rows where `remoteDeletedAt == nil`.

ProductPrice count must not full-fetch all rows and fault product relationships on the MainActor. The implementation uses `fetchCount` with a relationship predicate so the UI and drift semantics stay aligned with the pre-existing active-product definition.

The UI may show loading/stale state while summary refresh is in flight. It must not show a false green status while counts are unknown or remote drift verification is unavailable.

TASK-126 is preserved because owner/store pending count remains scoped, drift count semantics stay active-product aware, and remote mutation behavior is unchanged.

