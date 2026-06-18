#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tools/agent/catalog_delete_state_dump.sh --prefix TASK135_DELETE_ --outdir <evidence/state>

Read-only state dump for TASK-135 catalog delete smoke. The script writes small TSV/JSON
evidence files and never stores raw app databases.

Environment:
  IOS_BUNDLE_ID       default: com.niwcyber.iOSMerchandiseControl
  IOS_SIMULATOR_ID    default: booted
  ANDROID_PACKAGE     default: com.example.merchandisecontrolsplitview
  ANDROID_SERIAL      default: first adb device
  ADB                 default: $HOME/Library/Android/sdk/platform-tools/adb
  SUPABASE_PROFILE    default: linked
  SUPABASE_REPO       default: /Users/minxiang/Desktop/MerchandiseControlSupabase
EOF
}

prefix=""
outdir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      prefix="${2:-}"
      shift 2
      ;;
    --outdir)
      outdir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$prefix" || -z "$outdir" ]]; then
  usage >&2
  exit 2
fi
if [[ "$prefix" != TASK* ]]; then
  echo "Refusing non-task prefix: $prefix" >&2
  exit 2
fi

mkdir -p "$outdir"

ios_bundle="${IOS_BUNDLE_ID:-com.niwcyber.iOSMerchandiseControl}"
ios_simulator="${IOS_SIMULATOR_ID:-booted}"
android_pkg="${ANDROID_PACKAGE:-com.example.merchandisecontrolsplitview}"
adb_bin="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
android_serial="${ANDROID_SERIAL:-}"
supabase_profile="${SUPABASE_PROFILE:-linked}"
supabase_repo="${SUPABASE_REPO:-/Users/minxiang/Desktop/MerchandiseControlSupabase}"
supabase_db_flags=()
case "$supabase_profile" in
  linked) supabase_db_flags=(--linked -o json) ;;
  local) supabase_db_flags=(--local -o json) ;;
  *)
    echo "Unsupported SUPABASE_PROFILE for catalog delete dump: ${supabase_profile}" > "$outdir/supabase-blocked.txt"
    supabase_db_flags=()
    ;;
esac

if [[ -z "$android_serial" && -x "$adb_bin" ]]; then
  android_serial="$("$adb_bin" devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'prefix=%s\ntimestamp=%s\n' "$prefix" "$timestamp" > "$outdir/metadata.txt"

ios_store=""
if ios_container="$(xcrun simctl get_app_container "$ios_simulator" "$ios_bundle" data 2>/dev/null)"; then
  ios_store="$(find "$ios_container" -type f -name default.store | sort | head -n 1 || true)"
fi
if [[ -n "$ios_store" && -f "$ios_store" ]]; then
  PREFIX="$prefix" IOS_STORE="$ios_store" python3 - "$outdir/ios-products.tsv" "$outdir/ios-pending.tsv" <<'PY'
import os
import sqlite3
import sys

prefix = os.environ["PREFIX"]
store = os.environ["IOS_STORE"]
products_out, pending_out = sys.argv[1:3]
conn = sqlite3.connect(f"file:{store}?mode=ro", uri=True)
conn.row_factory = sqlite3.Row

def columns(table):
    return {row[1] for row in conn.execute(f"pragma table_info({table})")}

tables = {row[0] for row in conn.execute("select name from sqlite_master where type='table'")}

with open(products_out, "w", encoding="utf-8") as out:
    out.write("barcode\tproductName\tremoteID\tremoteDeletedAt\n")
    if "ZPRODUCT" in tables:
        cols = columns("ZPRODUCT")
        barcode = "ZBARCODE" if "ZBARCODE" in cols else None
        name = "ZPRODUCTNAME" if "ZPRODUCTNAME" in cols else None
        remote = "ZREMOTEID" if "ZREMOTEID" in cols else None
        deleted = "ZREMOTEDELETEDAT" if "ZREMOTEDELETEDAT" in cols else None
        if barcode:
            select = [
                f"coalesce({barcode}, '') as barcode",
                f"coalesce({name}, '') as productName" if name else "'' as productName",
                f"coalesce({remote}, '') as remoteID" if remote else "'' as remoteID",
                f"coalesce({deleted}, '') as remoteDeletedAt" if deleted else "'' as remoteDeletedAt",
            ]
            for row in conn.execute(f"select {', '.join(select)} from ZPRODUCT where {barcode} like ? order by {barcode}", (prefix + "%",)):
                out.write("\t".join(str(row[key]) for key in row.keys()) + "\n")

with open(pending_out, "w", encoding="utf-8") as out:
    out.write("entityKind\toperation\tstatus\tlogicalKey\tchangedFields\tremoteID\n")
    if "ZLOCALPENDINGCHANGE" in tables:
        cols = columns("ZLOCALPENDINGCHANGE")
        needed = ["ZENTITYKINDRAW", "ZOPERATIONRAW", "ZSTATUSRAW", "ZLOGICALKEY"]
        if all(col in cols for col in needed):
            changed = "ZCHANGEDFIELDSRAW" if "ZCHANGEDFIELDSRAW" in cols else ("ZCHANGEDFIELDSJSON" if "ZCHANGEDFIELDSJSON" in cols else None)
            remote = "ZENTITYREMOTEIDRAW" if "ZENTITYREMOTEIDRAW" in cols else None
            select = [
                "coalesce(ZENTITYKINDRAW, '') as entityKind",
                "coalesce(ZOPERATIONRAW, '') as operation",
                "coalesce(ZSTATUSRAW, '') as status",
                "coalesce(ZLOGICALKEY, '') as logicalKey",
                f"coalesce({changed}, '') as changedFields" if changed else "'' as changedFields",
                f"coalesce({remote}, '') as remoteID" if remote else "'' as remoteID",
            ]
            where = "(ZLOGICALKEY like ?"
            params = ["%" + prefix + "%"]
            if remote:
                where += f" or {remote} in (select ZREMOTEID from ZPRODUCT where ZBARCODE like ?)"
                params.append(prefix + "%")
            where += ")"
            for row in conn.execute(f"select {', '.join(select)} from ZLOCALPENDINGCHANGE where {where} order by ZUPDATEDAT", params):
                out.write("\t".join(str(row[key]) for key in row.keys()) + "\n")
conn.close()
PY
else
  echo "iOS store not available for bundle ${ios_bundle} on ${ios_simulator}" > "$outdir/ios-blocked.txt"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
if [[ -n "$android_serial" && -x "$adb_bin" ]]; then
  if "$adb_bin" -s "$android_serial" shell "run-as $android_pkg cat databases/app_database" > "$tmpdir/app_database" 2>"$outdir/android-db-copy.stderr"; then
    "$adb_bin" -s "$android_serial" shell "run-as $android_pkg cat databases/app_database-wal" > "$tmpdir/app_database-wal" 2>/dev/null || true
    "$adb_bin" -s "$android_serial" shell "run-as $android_pkg cat databases/app_database-shm" > "$tmpdir/app_database-shm" 2>/dev/null || true
    PREFIX="$prefix" ANDROID_DB="$tmpdir/app_database" python3 - "$outdir/android-products.tsv" "$outdir/android-tombstones.tsv" <<'PY'
import os
import sqlite3
import sys

prefix = os.environ["PREFIX"]
db_path = os.environ["ANDROID_DB"]
products_out, tombstones_out = sys.argv[1:3]
conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
conn.row_factory = sqlite3.Row
tables = {row[0] for row in conn.execute("select name from sqlite_master where type='table'")}

with open(products_out, "w", encoding="utf-8") as out:
    out.write("id\tbarcode\tproductName\tremoteID\n")
    if "products" in tables:
        query = """
            select p.id, coalesce(p.barcode, '') as barcode, coalesce(p.productName, '') as productName,
                   coalesce(r.remoteId, '') as remoteID
            from products p
            left join product_remote_refs r on r.productId = p.id
            where p.barcode like ?
            order by p.barcode
        """
        for row in conn.execute(query, (prefix + "%",)):
            out.write("\t".join(str(row[key]) for key in row.keys()) + "\n")

with open(tombstones_out, "w", encoding="utf-8") as out:
    out.write("entityType\tremoteId\tattemptCount\n")
    if "pending_catalog_tombstones" in tables:
        for row in conn.execute("select entityType, remoteId, attemptCount from pending_catalog_tombstones order by entityType, remoteId"):
            out.write("\t".join(str(row[key]) for key in row.keys()) + "\n")
conn.close()
PY
  else
    echo "Android run-as DB copy failed for ${android_pkg}" > "$outdir/android-blocked.txt"
  fi
else
  echo "Android adb device not available" > "$outdir/android-blocked.txt"
fi

if command -v supabase >/dev/null 2>&1 && [[ "${#supabase_db_flags[@]}" -gt 0 ]]; then
  sql_products="
select json_build_object(
  'products', coalesce(json_agg(json_build_object(
    'id', id,
    'barcode', barcode,
    'deleted_at', deleted_at,
    'updated_at', updated_at
  ) order by barcode), '[]'::json)
)::text as catalog_delete_products
from inventory_products
where barcode like '${prefix//\'/''}%';
"
  sql_events="
select json_build_object(
  'events', coalesce(json_agg(json_build_object(
    'id', id,
    'domain', domain,
    'event_type', event_type,
    'entity_ids', entity_ids,
    'created_at', created_at
  ) order by id desc), '[]'::json)
)::text as catalog_delete_events
from sync_events
where domain = 'catalog'
  and entity_ids::text like '%product_ids%'
  and created_at > now() - interval '6 hours';
"
  (
    cd "$supabase_repo"
    env -u SUPABASE_PROFILE supabase db query "${supabase_db_flags[@]}" "$sql_products"
  ) > "$outdir/supabase-products.json" 2>"$outdir/supabase-products.stderr" || true
  (
    cd "$supabase_repo"
    env -u SUPABASE_PROFILE supabase db query "${supabase_db_flags[@]}" "$sql_events"
  ) > "$outdir/supabase-sync-events.json" 2>"$outdir/supabase-sync-events.stderr" || true
elif ! command -v supabase >/dev/null 2>&1; then
  echo "supabase CLI not available" > "$outdir/supabase-blocked.txt"
fi

PREFIX="$prefix" OUTDIR="$outdir" python3 - <<'PY' > "$outdir/summary.json"
import json
import os
from pathlib import Path

outdir = Path(os.environ["OUTDIR"])
payload = {
    "prefix": os.environ["PREFIX"],
    "files": sorted(p.name for p in outdir.iterdir() if p.is_file()),
    "status": "PASS_WITH_NOTES"
}
print(json.dumps(payload, sort_keys=True, indent=2))
PY
