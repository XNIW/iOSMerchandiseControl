-- TASK-110 proposed migration draft.
-- Stato: proposta iniziale, NON applicata.
-- Blocker applicazione: migration history locale/remota divergente; vedi
-- supabase-schema-cache-playbook.md e migration locale Supabase:
-- /Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260515161500_task110_history_tombstone_grants.sql
-- Obiettivi:
-- 1. Abilitare tombstone History su shared_sheet_sessions.
-- 2. Chiudere anon su dati privati History e legacy product_prices.
-- 3. Rendere espliciti i grants minimi authenticated/service_role.
-- 4. Preparare schema reload PostgREST.

begin;

alter table public.shared_sheet_sessions
  add column if not exists deleted_at timestamptz;

create index if not exists shared_sheet_sessions_owner_updated_idx
  on public.shared_sheet_sessions (owner_user_id, updated_at);

create index if not exists shared_sheet_sessions_owner_deleted_idx
  on public.shared_sheet_sessions (owner_user_id, deleted_at)
  where deleted_at is not null;

revoke all on table public.shared_sheet_sessions from anon;
grant select, insert, update, delete on table public.shared_sheet_sessions to authenticated;
grant select, insert, update, delete on table public.shared_sheet_sessions to service_role;

revoke all on table public.product_prices from anon;
revoke all on sequence public.product_prices_id_seq from anon;

-- Default privileges are a safety net only. Every new object still needs
-- explicit object-level grants/RLS/policies in its own migration.
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on functions from anon;

notify pgrst, 'reload schema';

commit;
