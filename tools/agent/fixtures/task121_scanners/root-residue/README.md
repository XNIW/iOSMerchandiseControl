# root-residue TASK-121 fixture

expected RED status: FAIL
expected GREEN status: PASS
expected exit code: RED non-zero, GREEN zero

RED cases:
- `red/fixture.txt` represents `git ls-files` still containing forbidden root service `iOSMerchandiseControl/SupabaseInventoryService.swift`.
- `red/duplicate-root-moved.txt` represents a stale duplicate root+moved pair for one sync file name.

GREEN case:
- `green/fixture.txt` represents the accepted root shape: allowlisted Supabase auth/config files in root and sync services under `Sync/**`.

NEXT_ACTION: fail root-residue on RED cases and keep GREEN as the only accepted root-clean shape.
