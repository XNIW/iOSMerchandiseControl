select backup_name,
       to_regclass('public.' || backup_name) is not null as backup_exists
from (values
  ('backup_task132_inventory_product_prices_20260617'),
  ('backup_task132_inventory_products_20260617'),
  ('backup_task132_inventory_categories_20260617'),
  ('backup_task132_inventory_suppliers_20260617'),
  ('backup_task132_shared_sheet_sessions_20260617'),
  ('backup_task132_sync_events_20260617')
) as v(backup_name)
order by backup_name;
