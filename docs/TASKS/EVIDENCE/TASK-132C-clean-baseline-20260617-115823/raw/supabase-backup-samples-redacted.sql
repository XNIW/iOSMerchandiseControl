select * from (
  select 'inventory_product_prices' as table_name, left(md5(id::text), 12) as row_hash, left(md5(owner_user_id::text), 12) as owner_hash, left(coalesce(source, '<null>'), 40) as sample_a, left(coalesce(note, '<null>'), 40) as sample_b from public.backup_task132c_inventory_product_prices_20260617_120028 limit 5
) a
union all
select * from (
  select 'inventory_products', left(md5(id::text), 12), left(md5(owner_user_id::text), 12), left(coalesce(product_name, '<null>'), 40), left(coalesce(barcode, '<null>'), 40) from public.backup_task132c_inventory_products_20260617_120028 limit 5
) b
union all
select * from (
  select 'shared_sheet_sessions', left(md5(remote_id::text), 12), left(md5(owner_user_id::text), 12), left(coalesce(display_name, '<null>'), 40), '<payload-redacted>' from public.backup_task132c_shared_sheet_sessions_20260617_120028 limit 5
) c
union all
select * from (
  select 'sync_events', left(md5(id::text), 12), left(md5(owner_user_id::text), 12), left(coalesce(domain, '<null>') || ':' || coalesce(event_type, '<null>'), 40), '<metadata-redacted>' from public.backup_task132c_sync_events_20260617_120028 limit 5
) d;
