-- TASK-132 — Cleanup apply template for test residue
-- SAFETY DEFAULT: this script ends with ROLLBACK.
-- Review task132_cleanup_test_residue_DRY_RUN.sql first, set owner_user_id when possible,
-- inspect backup counts, then change the final ROLLBACK to COMMIT only for approved cleanup.
-- Before a real apply, replace the backup suffix if these tables already exist.

begin;
set local statement_timeout = '30s';
set local lock_timeout = '5s';

create temp table task132_scope(owner_user_id uuid) on commit drop;
insert into task132_scope(owner_user_id)
values (null::uuid);

create temp table task132_patterns(label text, pat text) on commit drop;
insert into task132_patterns(label, pat)
values
  ('TASK%', 'TASK%'),
  ('TASK115_%', 'TASK115\_%'),
  ('TASK123_%', 'TASK123\_%'),
  ('%REALTIME%', '%REALTIME%'),
  ('%BURST%', '%BURST%'),
  ('%BATCH_RT%', '%BATCH\_RT%'),
  ('%IOS_MATRIX%', '%IOS\_MATRIX%'),
  ('%ANDROID_MATRIX%', '%ANDROID\_MATRIX%');

create temp table task132_candidate_suppliers on commit drop as
select t.*
from public.inventory_suppliers t, task132_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and exists (
    select 1 from task132_patterns p
    where t.name ilike p.pat escape '\'
  );

create temp table task132_candidate_categories on commit drop as
select t.*
from public.inventory_categories t, task132_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and exists (
    select 1 from task132_patterns p
    where t.name ilike p.pat escape '\'
  );

create temp table task132_candidate_products on commit drop as
select t.*
from public.inventory_products t, task132_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and exists (
    select 1
    from task132_patterns p
    where coalesce(t.barcode, '') ilike p.pat escape '\'
       or coalesce(t.item_number, '') ilike p.pat escape '\'
       or coalesce(t.product_name, '') ilike p.pat escape '\'
       or coalesce(t.second_product_name, '') ilike p.pat escape '\'
  );

create temp table task132_candidate_prices on commit drop as
select t.*
from public.inventory_product_prices t, task132_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and (
    t.product_id in (select id from task132_candidate_products)
    or exists (
      select 1
      from task132_patterns p
      where coalesce(t.source, '') ilike p.pat escape '\'
         or coalesce(t.note, '') ilike p.pat escape '\'
         or coalesce(t.effective_at, '') ilike p.pat escape '\'
    )
  );

create temp table task132_candidate_sessions on commit drop as
select t.*
from public.shared_sheet_sessions t, task132_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and exists (
    select 1
    from task132_patterns p,
         jsonb_path_query(to_jsonb(t), '$.** ? (@.type() == "string")') as j(value)
    where (j.value #>> '{}') ilike p.pat escape '\'
  );

create temp table task132_candidate_sync_events on commit drop as
select t.*
from public.sync_events t, task132_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and exists (
    select 1
    from task132_patterns p,
         jsonb_path_query(to_jsonb(t), '$.** ? (@.type() == "string")') as j(value)
    where (j.value #>> '{}') ilike p.pat escape '\'
  );

select 'inventory_product_prices' as table_name, count(*) as candidate_count from task132_candidate_prices
union all select 'inventory_products', count(*) from task132_candidate_products
union all select 'inventory_categories', count(*) from task132_candidate_categories
union all select 'inventory_suppliers', count(*) from task132_candidate_suppliers
union all select 'shared_sheet_sessions', count(*) from task132_candidate_sessions
union all select 'sync_events', count(*) from task132_candidate_sync_events
order by table_name;

create table public.backup_task132_inventory_product_prices_20260617 as
select * from task132_candidate_prices;

create table public.backup_task132_inventory_products_20260617 as
select * from task132_candidate_products;

create table public.backup_task132_inventory_categories_20260617 as
select * from task132_candidate_categories;

create table public.backup_task132_inventory_suppliers_20260617 as
select * from task132_candidate_suppliers;

create table public.backup_task132_shared_sheet_sessions_20260617 as
select * from task132_candidate_sessions;

create table public.backup_task132_sync_events_20260617 as
select * from task132_candidate_sync_events;

select 'backup_task132_inventory_product_prices_20260617' as backup_table, count(*) as backed_up from public.backup_task132_inventory_product_prices_20260617
union all select 'backup_task132_inventory_products_20260617', count(*) from public.backup_task132_inventory_products_20260617
union all select 'backup_task132_inventory_categories_20260617', count(*) from public.backup_task132_inventory_categories_20260617
union all select 'backup_task132_inventory_suppliers_20260617', count(*) from public.backup_task132_inventory_suppliers_20260617
union all select 'backup_task132_shared_sheet_sessions_20260617', count(*) from public.backup_task132_shared_sheet_sessions_20260617
union all select 'backup_task132_sync_events_20260617', count(*) from public.backup_task132_sync_events_20260617
order by backup_table;

delete from public.inventory_product_prices t
using task132_candidate_prices c
where t.id = c.id;

delete from public.inventory_products t
using task132_candidate_products c
where t.id = c.id;

delete from public.inventory_categories t
using task132_candidate_categories c
where t.id = c.id
  and not exists (
    select 1 from public.inventory_products p
    where p.category_id = t.id
  );

delete from public.inventory_suppliers t
using task132_candidate_suppliers c
where t.id = c.id
  and not exists (
    select 1 from public.inventory_products p
    where p.supplier_id = t.id
  );

delete from public.shared_sheet_sessions t
using task132_candidate_sessions c
where t.remote_id = c.remote_id;

delete from public.sync_events t
using task132_candidate_sync_events c
where t.id = c.id;

-- Rollback restore order if a committed cleanup must be reverted manually:
-- 1. inventory_suppliers / inventory_categories
-- 2. inventory_products
-- 3. inventory_product_prices
-- 4. shared_sheet_sessions
-- 5. sync_events with OVERRIDING SYSTEM VALUE for id

rollback;
