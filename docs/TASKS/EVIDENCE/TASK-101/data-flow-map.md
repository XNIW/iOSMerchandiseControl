# Data-flow Map

## Main iOS Flows

1. Local import/read:
   - Excel/XLS/XLSX/HTML input -> `ExcelAnalyzer` / import pipeline -> SwiftData local entities (`Product`, `Category`, `Supplier`, `ProductPrice`, `HistoryEntry`).
   - Sensitive local data includes product names, barcode/item identifiers, prices, stock quantities and history payloads.

2. Auth/session:
   - User taps Google sign-in -> `SupabaseAuthService.signInWithGoogle()` -> Supabase SDK OAuth session -> `SupabaseAuthViewModel`.
   - App code stores only `SupabaseAuthSessionInfo` in memory; token storage is handled by Supabase SDK.

3. Pull preview/apply:
   - Authenticated Supabase client -> inventory tables -> preview DTOs -> local apply plan -> SwiftData updates.
   - TASK-101 added explicit `owner_user_id == session.user.id` filters on preview pages in addition to RLS.

4. Manual push:
   - SwiftData snapshot -> preflight/dry-run -> authenticated Supabase insert/update -> read-back verification -> baseline.
   - TASK-101 added explicit owner filters to update and read-back by id.

5. Sync events:
   - Local sync event/outbox DTO -> `record_sync_event` RPC -> `sync_events`.
   - RPC derives owner from `auth.uid()` and validates domain/event/metadata/entity ID budgets.

## Trust Boundaries

- Device local storage boundary: SwiftData and Supabase SDK session cache.
- Network boundary: Supabase PostgREST/RPC/Auth over HTTPS with publishable key and user JWT.
- DB boundary: RLS policies and function grants.
- Evidence boundary: only hashes, aggregates, synthetic examples and redacted identifiers.

