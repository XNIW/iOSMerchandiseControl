select 'backup_task132c_inventory_product_prices_20260617_120028' as backup_table, count(*)::bigint as rows from public.backup_task132c_inventory_product_prices_20260617_120028
union all select 'backup_task132c_inventory_products_20260617_120028', count(*)::bigint from public.backup_task132c_inventory_products_20260617_120028
union all select 'backup_task132c_shared_sheet_sessions_20260617_120028', count(*)::bigint from public.backup_task132c_shared_sheet_sessions_20260617_120028
union all select 'backup_task132c_sync_events_20260617_120028', count(*)::bigint from public.backup_task132c_sync_events_20260617_120028
order by backup_table;
