with scope(owner_user_id) as (values (null::uuid))
select 'inventory_suppliers' as table_name, count(*)::bigint as total, count(*) filter (where deleted_at is null)::bigint as active, count(*) filter (where deleted_at is not null)::bigint as tombstone from public.inventory_suppliers t, scope s where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all select 'inventory_categories', count(*)::bigint, count(*) filter (where deleted_at is null)::bigint, count(*) filter (where deleted_at is not null)::bigint from public.inventory_categories t, scope s where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all select 'inventory_products', count(*)::bigint, count(*) filter (where deleted_at is null)::bigint, count(*) filter (where deleted_at is not null)::bigint from public.inventory_products t, scope s where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all select 'inventory_product_prices', count(*)::bigint, count(*)::bigint, 0::bigint from public.inventory_product_prices t, scope s where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all select 'shared_sheet_sessions', count(*)::bigint, count(*) filter (where deleted_at is null)::bigint, count(*) filter (where deleted_at is not null)::bigint from public.shared_sheet_sessions t, scope s where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
union all select 'sync_events', count(*)::bigint, count(*)::bigint, 0::bigint from public.sync_events t, scope s where s.owner_user_id is null or t.owner_user_id = s.owner_user_id
order by table_name;
