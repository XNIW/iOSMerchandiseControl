with scope(owner_user_id) as (values (null::uuid)),
patterns(label, pat) as (
  values ('TASK%', 'TASK%'), ('TASK115_%', 'TASK115\_%'), ('TASK123_%', 'TASK123\_%'), ('%REALTIME%', '%REALTIME%'), ('%BURST%', '%BURST%'), ('%BATCH_RT%', '%BATCH\_RT%'), ('%IOS_MATRIX%', '%IOS\_MATRIX%'), ('%ANDROID_MATRIX%', '%ANDROID\_MATRIX%')
),
supplier_candidates as (
  select t.id from public.inventory_suppliers t, scope s where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id) and t.deleted_at is null and exists (select 1 from patterns p where t.name ilike p.pat escape '\')
),
category_candidates as (
  select t.id from public.inventory_categories t, scope s where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id) and t.deleted_at is null and exists (select 1 from patterns p where t.name ilike p.pat escape '\')
),
product_candidates as (
  select t.id from public.inventory_products t, scope s where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id) and t.deleted_at is null and exists (select 1 from patterns p where coalesce(t.barcode, '') ilike p.pat escape '\' or coalesce(t.item_number, '') ilike p.pat escape '\' or coalesce(t.product_name, '') ilike p.pat escape '\' or coalesce(t.second_product_name, '') ilike p.pat escape '\')
),
price_candidates as (
  select t.id from public.inventory_product_prices t, scope s where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id) and (t.product_id in (select id from product_candidates) or exists (select 1 from patterns p where coalesce(t.source, '') ilike p.pat escape '\' or coalesce(t.note, '') ilike p.pat escape '\' or coalesce(t.effective_at, '') ilike p.pat escape '\'))
),
session_candidates as (
  select t.remote_id from public.shared_sheet_sessions t, scope s where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id) and t.deleted_at is null and exists (select 1 from patterns p, jsonb_path_query(to_jsonb(t), '$.** ? (@.type() == "string")') as j(value) where (j.value #>> '{}') ilike p.pat escape '\')
),
sync_event_candidates as (
  select t.id from public.sync_events t, scope s where (s.owner_user_id is null or t.owner_user_id = s.owner_user_id) and exists (select 1 from patterns p, jsonb_path_query(to_jsonb(t), '$.** ? (@.type() == "string")') as j(value) where (j.value #>> '{}') ilike p.pat escape '\')
)
select 'inventory_categories' as table_name, count(*)::bigint as candidate_count from category_candidates
union all select 'inventory_product_prices', count(*)::bigint from price_candidates
union all select 'inventory_products', count(*)::bigint from product_candidates
union all select 'inventory_suppliers', count(*)::bigint from supplier_candidates
union all select 'shared_sheet_sessions', count(*)::bigint from session_candidates
union all select 'sync_events', count(*)::bigint from sync_event_candidates
order by table_name;
