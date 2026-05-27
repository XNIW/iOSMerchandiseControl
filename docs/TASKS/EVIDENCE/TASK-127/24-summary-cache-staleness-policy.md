# TASK-127 Evidence 24 - Summary Cache Staleness Policy

Provider state now includes:

- `isLoading`
- `isStale`
- `lastRefreshedAt`
- `source`
- `refreshReason`
- `coalescedEvents`

The UI avoids false-green behavior by showing loading while counts refresh and keeping remote drift unknown/failure distinct from aligned.

