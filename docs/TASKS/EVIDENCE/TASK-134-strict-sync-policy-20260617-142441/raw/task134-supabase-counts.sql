with counts as (
  select 'products_active' metric, count(*)::bigint value from public.inventory_products where deleted_at is null
  union all select 'suppliers_active', count(*)::bigint from public.inventory_suppliers where deleted_at is null
  union all select 'categories_active', count(*)::bigint from public.inventory_categories where deleted_at is null
  union all select 'product_prices', count(*)::bigint from public.inventory_product_prices
  union all select 'history_active', count(*)::bigint from public.shared_sheet_sessions where deleted_at is null
  union all select 'sync_events_total', count(*)::bigint from public.sync_events
  union all select 'sync_events_max_id', coalesce(max(id), 0)::bigint from public.sync_events
  union all select 'task134_products', count(*)::bigint from public.inventory_products where coalesce(barcode,'') like 'TASK134%' or coalesce(product_name,'') like 'TASK134%' or coalesce(item_number,'') like 'TASK134%'
  union all select 'task134_suppliers', count(*)::bigint from public.inventory_suppliers where coalesce(name,'') like 'TASK134%'
  union all select 'task134_categories', count(*)::bigint from public.inventory_categories where coalesce(name,'') like 'TASK134%'
  union all select 'task134_prices', count(*)::bigint from public.inventory_product_prices where coalesce(source,'') like 'TASK134%' or coalesce(note,'') like 'TASK134%'
  union all select 'task134_history', count(*)::bigint from public.shared_sheet_sessions where to_jsonb(shared_sheet_sessions)::text like '%TASK134%'
  union all select 'task134_sync_events', count(*)::bigint from public.sync_events where to_jsonb(sync_events)::text like '%TASK134%'
  union all select 'task133_products', count(*)::bigint from public.inventory_products where coalesce(barcode,'') like 'TASK133%' or coalesce(product_name,'') like 'TASK133%' or coalesce(item_number,'') like 'TASK133%'
  union all select 'task133_prices', count(*)::bigint from public.inventory_product_prices where coalesce(source,'') like 'TASK133%' or coalesce(note,'') like 'TASK133%'
  union all select 'task133_sync_events', count(*)::bigint from public.sync_events where to_jsonb(sync_events)::text like '%TASK133%'
)
select * from counts order by metric;
