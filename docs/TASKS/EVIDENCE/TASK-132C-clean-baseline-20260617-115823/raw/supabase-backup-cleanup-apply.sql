begin;
set local statement_timeout = '60s';
set local lock_timeout = '10s';

create temp table task132c_scope(owner_user_id uuid) on commit drop;
insert into task132c_scope(owner_user_id) values (null::uuid);

create temp table task132c_patterns(label text, pat text) on commit drop;
insert into task132c_patterns(label, pat) values
  ('TASK%', 'TASK%'),
  ('TASK115_%', 'TASK115\_%'),
  ('TASK123_%', 'TASK123\_%'),
  ('%REALTIME%', '%REALTIME%'),
  ('%BURST%', '%BURST%'),
  ('%BATCH_RT%', '%BATCH\_RT%'),
  ('%IOS_MATRIX%', '%IOS\_MATRIX%'),
  ('%ANDROID_MATRIX%', '%ANDROID\_MATRIX%');

create temp table task132c_candidate_products on commit drop as
select t.*
from public.inventory_products t, task132c_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and t.deleted_at is null
  and exists (
    select 1 from task132c_patterns p
    where coalesce(t.barcode, '') ilike p.pat escape '\'
       or coalesce(t.item_number, '') ilike p.pat escape '\'
       or coalesce(t.product_name, '') ilike p.pat escape '\'
       or coalesce(t.second_product_name, '') ilike p.pat escape '\'
  );

create temp table task132c_candidate_prices on commit drop as
select t.*
from public.inventory_product_prices t, task132c_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and (
    t.product_id in (select id from task132c_candidate_products)
    or exists (
      select 1 from task132c_patterns p
      where coalesce(t.source, '') ilike p.pat escape '\'
         or coalesce(t.note, '') ilike p.pat escape '\'
         or coalesce(t.effective_at, '') ilike p.pat escape '\'
    )
  );

create temp table task132c_candidate_sessions on commit drop as
select t.*
from public.shared_sheet_sessions t, task132c_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and t.deleted_at is null
  and exists (
    select 1
    from task132c_patterns p,
         jsonb_path_query(to_jsonb(t), '$.** ? (@.type() == "string")') as j(value)
    where (j.value #>> '{}') ilike p.pat escape '\'
  );

create temp table task132c_candidate_sync_events on commit drop as
select t.*
from public.sync_events t, task132c_scope s
where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id)
  and exists (
    select 1
    from task132c_patterns p,
         jsonb_path_query(to_jsonb(t), '$.** ? (@.type() == "string")') as j(value)
    where (j.value #>> '{}') ilike p.pat escape '\'
  );

create table public.backup_task132c_inventory_product_prices_20260617_120028 as
select * from task132c_candidate_prices;

create table public.backup_task132c_inventory_products_20260617_120028 as
select * from task132c_candidate_products;

create table public.backup_task132c_shared_sheet_sessions_20260617_120028 as
select * from task132c_candidate_sessions;

create table public.backup_task132c_sync_events_20260617_120028 as
select * from task132c_candidate_sync_events;

delete from public.inventory_product_prices t
using task132c_candidate_prices c
where t.id = c.id;

update public.inventory_products t
set deleted_at = coalesce(t.deleted_at, now()),
    updated_at = now()
from task132c_candidate_products c
where t.id = c.id
  and t.deleted_at is null;

update public.shared_sheet_sessions t
set deleted_at = coalesce(t.deleted_at, now()),
    updated_at = now()
from task132c_candidate_sessions c
where t.remote_id = c.remote_id
  and t.deleted_at is null;

delete from public.sync_events t
using task132c_candidate_sync_events c
where t.id = c.id;

commit;
