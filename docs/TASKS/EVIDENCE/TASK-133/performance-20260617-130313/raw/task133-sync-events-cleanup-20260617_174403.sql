begin;
create table public.backup_task133_sync_events_20260617_174403 as
select *
from public.sync_events
where id > 3035 and id <= 3065;

select 'backup_count' as metric, count(*)::bigint as value
from public.backup_task133_sync_events_20260617_174403;

delete from public.sync_events e
using public.backup_task133_sync_events_20260617_174403 b
where e.id = b.id;

select 'remaining_events_3036_3065' as metric, count(*)::bigint as value
from public.sync_events
where id > 3035 and id <= 3065;

commit;
