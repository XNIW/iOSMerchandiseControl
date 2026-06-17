select json_build_object(
  'source', 'supabase.TASK133-scoped-counts',
  'prefix', 'TASK133_%',
  'counts', json_build_object(
    'products', (select count(*) from public.inventory_products where barcode like 'TASK133_%' or product_name like 'TASK133_%' or item_number like 'TASK133_%'),
    'suppliers', (select count(*) from public.inventory_suppliers where name like 'TASK133_%'),
    'categories', (select count(*) from public.inventory_categories where name like 'TASK133_%'),
    'product_prices', (
      select count(*) from public.inventory_product_prices p
      left join public.inventory_products pr on pr.id = p.product_id
      where p.source like 'TASK133_%' or pr.barcode like 'TASK133_%' or pr.product_name like 'TASK133_%' or pr.item_number like 'TASK133_%'
    ),
    'sync_events', (
      select count(*) from public.sync_events
      where client_event_id like 'TASK133_%'
         or source_device_id like 'TASK133_%'
         or metadata::text like '%TASK133_%'
         or entity_ids::text like '%TASK133_%'
    )
  ),
  'watermark', (select coalesce(max(id), 0) from public.sync_events)
) as scoped_counts;
