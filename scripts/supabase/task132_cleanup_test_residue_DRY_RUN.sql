-- TASK-132 — Cleanup dry-run for test residue
-- Read-only candidate report. This script does not mutate data.
-- Replace scope.owner_user_id with a concrete UUID when possible.

begin read only;

with scope(owner_user_id) as (
  values (null::uuid)
),
patterns(label, pat) as (
  values
    ('TASK%', 'TASK%'),
    ('TASK115_%', 'TASK115\_%'),
    ('TASK123_%', 'TASK123\_%'),
    ('%REALTIME%', '%REALTIME%'),
    ('%BURST%', '%BURST%'),
    ('%BATCH_RT%', '%BATCH\_RT%'),
    ('%IOS_MATRIX%', '%IOS\_MATRIX%'),
    ('%ANDROID_MATRIX%', '%ANDROID\_MATRIX%')
),
supplier_candidates as (
  select t.id, t.owner_user_id, t.name, t.updated_at, t.deleted_at
  from public.inventory_suppliers t, scope s
  where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
    and exists (
      select 1 from patterns p
      where t.name ilike p.pat escape '\'
    )
),
category_candidates as (
  select t.id, t.owner_user_id, t.name, t.updated_at, t.deleted_at
  from public.inventory_categories t, scope s
  where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
    and exists (
      select 1 from patterns p
      where t.name ilike p.pat escape '\'
    )
),
product_candidates as (
  select t.id, t.owner_user_id, t.barcode, t.product_name, t.updated_at, t.deleted_at
  from public.inventory_products t, scope s
  where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
    and exists (
      select 1
      from patterns p
      where coalesce(t.barcode, '') ilike p.pat escape '\'
         or coalesce(t.item_number, '') ilike p.pat escape '\'
         or coalesce(t.product_name, '') ilike p.pat escape '\'
         or coalesce(t.second_product_name, '') ilike p.pat escape '\'
    )
),
price_candidates as (
  select t.id, t.owner_user_id, t.product_id, t.type, t.effective_at, t.created_at
  from public.inventory_product_prices t, scope s
  where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
    and (
      t.product_id in (select id from product_candidates)
      or exists (
        select 1
        from patterns p
        where coalesce(t.source, '') ilike p.pat escape '\'
           or coalesce(t.note, '') ilike p.pat escape '\'
           or coalesce(t.effective_at, '') ilike p.pat escape '\'
      )
    )
),
session_candidates as (
  select t.remote_id, t.owner_user_id, t.display_name, t.updated_at, t.deleted_at
  from public.shared_sheet_sessions t, scope s
  where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
    and exists (
      select 1
      from patterns p,
           jsonb_path_query(to_jsonb(t), '$.** ? (@.type() == "string")') as j(value)
      where (j.value #>> '{}') ilike p.pat escape '\'
    )
),
sync_event_candidates as (
  select t.id, t.owner_user_id, t.domain, t.event_type, t.source, t.client_event_id, t.created_at
  from public.sync_events t, scope s
  where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
    and exists (
      select 1
      from patterns p,
           jsonb_path_query(to_jsonb(t), '$.** ? (@.type() == "string")') as j(value)
      where (j.value #>> '{}') ilike p.pat escape '\'
    )
)
select 'inventory_product_prices' as table_name, count(*) as candidate_count from price_candidates
union all select 'inventory_products', count(*) from product_candidates
union all select 'inventory_categories', count(*) from category_candidates
union all select 'inventory_suppliers', count(*) from supplier_candidates
union all select 'shared_sheet_sessions', count(*) from session_candidates
union all select 'sync_events', count(*) from sync_event_candidates
order by table_name;

with scope(owner_user_id) as (
  values (null::uuid)
),
patterns(label, pat) as (
  values
    ('TASK%', 'TASK%'),
    ('TASK115_%', 'TASK115\_%'),
    ('TASK123_%', 'TASK123\_%'),
    ('%REALTIME%', '%REALTIME%'),
    ('%BURST%', '%BURST%'),
    ('%BATCH_RT%', '%BATCH\_RT%'),
    ('%IOS_MATRIX%', '%IOS\_MATRIX%'),
    ('%ANDROID_MATRIX%', '%ANDROID\_MATRIX%')
),
rows as (
  select 'inventory_suppliers' as table_name, t.owner_user_id, t.id::text as row_id, to_jsonb(t) as doc
  from public.inventory_suppliers t, scope s
  where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
  union all
  select 'inventory_categories', t.owner_user_id, t.id::text, to_jsonb(t)
  from public.inventory_categories t, scope s
  where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
  union all
  select 'inventory_products', t.owner_user_id, t.id::text, to_jsonb(t)
  from public.inventory_products t, scope s
  where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
  union all
  select 'inventory_product_prices', t.owner_user_id, t.id::text, to_jsonb(t)
  from public.inventory_product_prices t, scope s
  where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
  union all
  select 'shared_sheet_sessions', t.owner_user_id, t.remote_id, to_jsonb(t)
  from public.shared_sheet_sessions t, scope s
  where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
  union all
  select 'sync_events', t.owner_user_id, t.id::text, to_jsonb(t)
  from public.sync_events t, scope s
  where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
)
select r.table_name, p.label, r.owner_user_id, r.row_id
from rows r
cross join patterns p
where exists (
  select 1
  from jsonb_path_query(r.doc, '$.** ? (@.type() == "string")') as s(value)
  where (s.value #>> '{}') ilike p.pat escape '\'
)
order by r.table_name, p.label, r.row_id
limit 500;

rollback;
