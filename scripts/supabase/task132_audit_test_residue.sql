-- TASK-132 — Supabase forensics audit (read-only)
-- Usage: run in Supabase SQL editor/psql after replacing owner_user_id if needed.
-- Default scope is all owners. Set scope.owner_user_id to one owner UUID for safer review.

begin read only;

with scope(owner_user_id) as (
  values (null::uuid)
)
select
  table_name,
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'inventory_suppliers',
    'inventory_categories',
    'inventory_products',
    'inventory_product_prices',
    'shared_sheet_sessions',
    'sync_events'
  )
order by table_name, ordinal_position;

select
  tc.table_name,
  kcu.column_name,
  ccu.table_name as foreign_table_name,
  ccu.column_name as foreign_column_name,
  rc.delete_rule
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
 and tc.constraint_schema = kcu.constraint_schema
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name = tc.constraint_name
 and ccu.constraint_schema = tc.constraint_schema
left join information_schema.referential_constraints rc
  on rc.constraint_name = tc.constraint_name
 and rc.constraint_schema = tc.constraint_schema
where tc.table_schema = 'public'
  and tc.constraint_type = 'FOREIGN KEY'
  and tc.table_name in (
    'inventory_suppliers',
    'inventory_categories',
    'inventory_products',
    'inventory_product_prices',
    'shared_sheet_sessions',
    'sync_events'
  )
order by tc.table_name, kcu.column_name;

with scope(owner_user_id) as (
  values (null::uuid)
)
select 'inventory_suppliers' as table_name,
       count(*) as total,
       count(*) filter (where deleted_at is null) as active,
       count(*) filter (where deleted_at is not null) as tombstone
from public.inventory_suppliers t, scope s
where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all
select 'inventory_categories',
       count(*),
       count(*) filter (where deleted_at is null),
       count(*) filter (where deleted_at is not null)
from public.inventory_categories t, scope s
where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all
select 'inventory_products',
       count(*),
       count(*) filter (where deleted_at is null),
       count(*) filter (where deleted_at is not null)
from public.inventory_products t, scope s
where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all
select 'inventory_product_prices', count(*), count(*), 0
from public.inventory_product_prices t, scope s
where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all
select 'shared_sheet_sessions',
       count(*),
       count(*) filter (where deleted_at is null),
       count(*) filter (where deleted_at is not null)
from public.shared_sheet_sessions t, scope s
where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all
select 'sync_events', count(*), count(*), 0
from public.sync_events t, scope s
where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
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
select r.table_name, p.label, count(*) as rows_matching
from rows r
cross join patterns p
where exists (
  select 1
  from jsonb_path_query(r.doc, '$.** ? (@.type() == "string")') as s(value)
  where (s.value #>> '{}') ilike p.pat escape '\'
)
group by r.table_name, p.label
order by r.table_name, p.label;

rollback;
