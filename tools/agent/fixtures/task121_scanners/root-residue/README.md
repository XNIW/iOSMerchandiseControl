# root-residue TASK-121 fixture

expected RED status: FAIL
expected GREEN status: PASS
expected exit code: RED non-zero, GREEN zero

RED cases:
- `red/fixture.txt` represents `git ls-files` still containing forbidden root service `iOSMerchandiseControl/SupabaseInventoryService.swift`.
- `red/duplicate-root-moved.txt` represents a stale duplicate root+moved pair for one sync file name.
- `red-root-supabase-inventory-service/fixture.txt` represents the canonical RED root mega-service path.
- `red-duplicate-root-and-moved/fixture.txt` represents a stale duplicate root+moved pair.

GREEN case:
- `green/fixture.txt` represents the accepted root shape: allowlisted Supabase auth/config files in root and sync services under `Sync/**`.
- `green-root-clean/fixture.txt` represents root-clean git-tracked Swift files and no legacy `SupabaseInventoryService` symbol.

NEXT_ACTION: fail root-residue on RED cases and keep GREEN as the only accepted root-clean shape.
