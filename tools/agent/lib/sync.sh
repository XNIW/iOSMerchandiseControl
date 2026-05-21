#!/usr/bin/env bash

mc_sync_counts_sql() {
  cat <<'SQL'
SELECT json_build_object(
  'products', json_build_object(
    'active', (SELECT count(*) FROM inventory_products WHERE deleted_at IS NULL),
    'deleted', (SELECT count(*) FROM inventory_products WHERE deleted_at IS NOT NULL),
    'all', (SELECT count(*) FROM inventory_products),
    'dirty', 0,
    'pending', 0,
    'localOnly', 0,
    'userVisible', NULL
  ),
  'suppliers', json_build_object(
    'active', (SELECT count(*) FROM inventory_suppliers WHERE deleted_at IS NULL),
    'deleted', (SELECT count(*) FROM inventory_suppliers WHERE deleted_at IS NOT NULL),
    'all', (SELECT count(*) FROM inventory_suppliers),
    'dirty', 0,
    'pending', 0,
    'localOnly', 0,
    'userVisible', NULL
  ),
  'categories', json_build_object(
    'active', (SELECT count(*) FROM inventory_categories WHERE deleted_at IS NULL),
    'deleted', (SELECT count(*) FROM inventory_categories WHERE deleted_at IS NOT NULL),
    'all', (SELECT count(*) FROM inventory_categories),
    'dirty', 0,
    'pending', 0,
    'localOnly', 0,
    'userVisible', NULL
  ),
  'product_prices', json_build_object(
    'active', (
      SELECT count(*)
      FROM inventory_product_prices ipp
      JOIN inventory_products p ON p.id = ipp.product_id
      WHERE p.deleted_at IS NULL
    ),
    'deleted', 0,
    'all', (SELECT count(*) FROM inventory_product_prices),
    'dirty', 0,
    'pending', 0,
    'localOnly', 0,
    'userVisible', NULL
  ),
  'history_entries', json_build_object(
    'active', (SELECT count(*) FROM shared_sheet_sessions WHERE deleted_at IS NULL),
    'deleted', (SELECT count(*) FROM shared_sheet_sessions WHERE deleted_at IS NOT NULL),
    'all', (SELECT count(*) FROM shared_sheet_sessions),
    'dirty', 0,
    'pending', 0,
    'localOnly', 0,
    'userVisible', (SELECT count(*) FROM shared_sheet_sessions WHERE deleted_at IS NULL)
  )
)::text AS task114_counts_json;
SQL
}

mc_sync_make_blocked_json() {
  local task_id="$1"
  local source="$2"
  local reason="$3"
  TASK_ID="$task_id" SOURCE="$source" REASON="$reason" python3 - <<'PY'
import json, os
from datetime import datetime, timezone

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
tables = ["products", "suppliers", "categories", "product_prices", "history_entries"]
empty = {name: {"active": None, "deleted": None, "all": None, "dirty": None, "pending": None, "localOnly": None, "userVisible": None} for name in tables}
payload = {
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": now,
    "completedAt": now,
    "source": os.environ["SOURCE"],
    "account": {"state": "redacted"},
    "session": {"state": "redacted"},
    "counts": empty,
    "checkpoint": {"local": None, "remote": None},
    "lastPush": None,
    "lastPull": None,
    "lastFullReconciliation": None,
    "inserted": 0,
    "updated": 0,
    "deleted": 0,
    "pruned": {
        "wouldPrune": 0,
        "didPrune": 0,
        "skippedDirty": 0,
        "skippedLocalOnly": 0,
        "skippedPendingTombstone": 0,
        "skippedScopedSnapshot": 0,
        "isCompleteSnapshot": None
    },
    "skipped": 0,
    "drift": {},
    "samples": {
        "androidLocalProductsMissingRemote": [],
        "iosMissingSupplierCategory": [],
        "remotePriceHistoryWithoutLocalProduct": [],
        "historySessionActiveAllTombstone": [],
        "localOnlyNotPrunable": []
    },
    "status": "BLOCKED",
    "blocker": os.environ["REASON"]
}
print(json.dumps(payload, sort_keys=True))
PY
}

mc_sync_summarize_detail() {
  python3 - "$1" <<'PY'
import json, sys
payload = json.loads(sys.argv[1])
counts = payload.get("counts", {})
lines = [
    f"- schemaVersion: {payload.get('schemaVersion')}",
    f"- taskId: {payload.get('taskId')}",
    f"- source: {payload.get('source')}",
    f"- status: {payload.get('status', 'PASS')}",
]
for table in ["products", "suppliers", "categories", "product_prices", "history_entries"]:
    c = counts.get(table, {})
    lines.append(
        f"- {table}: active={c.get('active')} deleted={c.get('deleted')} all={c.get('all')} "
        f"dirty={c.get('dirty')} pending={c.get('pending')} localOnly={c.get('localOnly')} "
        f"userVisible={c.get('userVisible')}"
    )
if payload.get("source") == "live.reconcile-counts":
    lines.append("- source counts:")
    for source_name in ["supabase", "android", "ios"]:
        source_counts = counts.get(source_name, {})
        compact = []
        for table in ["products", "suppliers", "categories", "product_prices", "history_entries"]:
            c = source_counts.get(table, {})
            compact.append(
                f"{table}=active:{c.get('active')}/deleted:{c.get('deleted')}/all:{c.get('all')}/"
                f"pending:{c.get('pending')}/localOnly:{c.get('localOnly')}/userVisible:{c.get('userVisible')}"
            )
        lines.append(f"  - {source_name}: " + "; ".join(compact))
    drift = payload.get("drift", {})
    if drift:
        lines.append("- drift:")
        for table, fields in drift.items():
            for field, values in fields.items():
                lines.append(f"  - {table}.{field}: {values}")
    else:
        lines.append("- drift: none")
pruned = payload.get("pruned", {})
lines.append(
    "- prune: wouldPrune={wouldPrune} didPrune={didPrune} skippedDirty={skippedDirty} "
    "skippedLocalOnly={skippedLocalOnly} skippedPendingTombstone={skippedPendingTombstone} "
    "skippedScopedSnapshot={skippedScopedSnapshot} isCompleteSnapshot={isCompleteSnapshot}".format(**{
        "wouldPrune": pruned.get("wouldPrune", 0),
        "didPrune": pruned.get("didPrune", 0),
        "skippedDirty": pruned.get("skippedDirty", 0),
        "skippedLocalOnly": pruned.get("skippedLocalOnly", 0),
        "skippedPendingTombstone": pruned.get("skippedPendingTombstone", 0),
        "skippedScopedSnapshot": pruned.get("skippedScopedSnapshot", 0),
        "isCompleteSnapshot": pruned.get("isCompleteSnapshot", None),
    })
)
print("\n".join(lines))
PY
}

mc_sync_set_detail() {
  MC_RECONCILIATION_JSON="$1"
  MC_RECONCILIATION_MD="$(mc_sync_summarize_detail "$MC_RECONCILIATION_JSON")"
  export MC_RECONCILIATION_JSON MC_RECONCILIATION_MD
  mc_report_log "$MC_RECONCILIATION_JSON"
}

mc_sync_counts_supabase() {
  local task_id="$1"
  local profile="$2"
  local started raw parsed code
  started="$(mc_now_iso)"
  raw="$(mc_supabase_query_profile "$profile" "$(mc_sync_counts_sql)" 2>&1)"
  code=$?
  if [[ "$code" -ne 0 ]]; then
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "supabase" "Supabase count query failed for profile ${profile}.")"
    return "$MC_EXIT_BLOCKED"
  fi
  RAW_SUPABASE="$raw" TASK_ID="$task_id" STARTED_AT="$started" PROFILE="$profile" python3 - >/dev/null <<'PY'
import json, os, re, sys
from datetime import datetime, timezone

raw = os.environ["RAW_SUPABASE"]
match = re.search(r"\{.*\}", raw, re.S)
if not match:
    print(json.dumps({"error": "no_json_in_supabase_output", "rawSample": raw[-400:]}))
    sys.exit(2)
outer = json.loads(match.group(0))
if isinstance(outer, dict) and "rows" in outer:
    counts = json.loads(outer["rows"][0]["task114_counts_json"])
else:
    counts = outer
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
payload = {
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["STARTED_AT"],
    "completedAt": now,
    "source": "supabase",
    "account": {"state": "redacted", "profile": os.environ["PROFILE"]},
    "session": {"state": "server-side-redacted"},
    "counts": counts,
    "checkpoint": {"local": None, "remote": "linked-read"},
    "lastPush": None,
    "lastPull": None,
    "lastFullReconciliation": None,
    "inserted": 0,
    "updated": 0,
    "deleted": 0,
    "pruned": {
        "wouldPrune": 0,
        "didPrune": 0,
        "skippedDirty": 0,
        "skippedLocalOnly": 0,
        "skippedPendingTombstone": 0,
        "skippedScopedSnapshot": 0,
        "isCompleteSnapshot": True
    },
    "skipped": 0,
    "drift": {},
    "samples": {
        "androidLocalProductsMissingRemote": [],
        "iosMissingSupplierCategory": [],
        "remotePriceHistoryWithoutLocalProduct": [],
        "historySessionActiveAllTombstone": [{
            "active": counts["history_entries"]["active"],
            "all": counts["history_entries"]["all"],
            "tombstone": counts["history_entries"]["deleted"]
        }],
        "localOnlyNotPrunable": []
    },
    "status": "PASS"
}
print(json.dumps(payload, sort_keys=True))
PY
  code=$?
  if [[ "$code" -ne 0 ]]; then
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "supabase" "Supabase output did not contain parseable JSON.")"
    return "$MC_EXIT_BLOCKED"
  fi
  parsed="$(RAW_SUPABASE="$raw" TASK_ID="$task_id" STARTED_AT="$started" PROFILE="$profile" python3 - <<'PY'
import json, os, re
from datetime import datetime, timezone
outer = json.loads(re.search(r"\{.*\}", os.environ["RAW_SUPABASE"], re.S).group(0))
if isinstance(outer, dict) and "rows" in outer:
    counts = json.loads(outer["rows"][0]["task114_counts_json"])
else:
    counts = outer
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(json.dumps({
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["STARTED_AT"],
    "completedAt": now,
    "source": "supabase",
    "account": {"state": "redacted", "profile": os.environ["PROFILE"]},
    "session": {"state": "server-side-redacted"},
    "counts": counts,
    "checkpoint": {"local": None, "remote": "linked-read"},
    "lastPush": None,
    "lastPull": None,
    "lastFullReconciliation": None,
    "inserted": 0,
    "updated": 0,
    "deleted": 0,
    "pruned": {
        "wouldPrune": 0,
        "didPrune": 0,
        "skippedDirty": 0,
        "skippedLocalOnly": 0,
        "skippedPendingTombstone": 0,
        "skippedScopedSnapshot": 0,
        "isCompleteSnapshot": True
    },
    "skipped": 0,
    "drift": {},
    "samples": {
        "androidLocalProductsMissingRemote": [],
        "iosMissingSupplierCategory": [],
        "remotePriceHistoryWithoutLocalProduct": [],
        "historySessionActiveAllTombstone": [{
            "active": counts["history_entries"]["active"],
            "all": counts["history_entries"]["all"],
            "tombstone": counts["history_entries"]["deleted"]
        }],
        "localOnlyNotPrunable": []
    },
    "status": "PASS"
}, sort_keys=True))
PY
)"
  MC_SYNC_JSON_RESULT="$parsed"
  return "$MC_EXIT_PASS"
}

mc_sync_copy_android_db() {
  local serial="$1"
  local dest="$2"
  local package_name="${MC_ANDROID_PACKAGE:-com.example.merchandisecontrolsplitview}"
  if ! adb -s "$serial" exec-out run-as "$package_name" cat databases/app_database > "$dest" 2>/dev/null; then
    return "$MC_EXIT_BLOCKED"
  fi
  adb -s "$serial" exec-out run-as "$package_name" cat databases/app_database-wal > "${dest}-wal" 2>/dev/null || true
  adb -s "$serial" exec-out run-as "$package_name" cat databases/app_database-shm > "${dest}-shm" 2>/dev/null || true
  [[ -s "$dest" ]] || return "$MC_EXIT_BLOCKED"
  return "$MC_EXIT_PASS"
}

mc_sync_counts_android() {
  local task_id="$1"
  local started serial tmp code
  started="$(mc_now_iso)"
  serial="$(mc_android_serial)" || {
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "android" "${MC_SUMMARY:-No Android device available.}")"
    return "$MC_EXIT_BLOCKED"
  }
  mc_android_require_unlocked "$serial" || {
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "android" "${MC_SUMMARY:-Android device locked.}")"
    return "$MC_EXIT_BLOCKED"
  }
  tmp="$(mktemp -d)"
  mc_sync_copy_android_db "$serial" "$tmp/app_database" || {
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "android" "Unable to copy Room database with run-as from the connected debug device.")"
    rm -rf "$tmp"
    return "$MC_EXIT_BLOCKED"
  }
  DB_PATH="$tmp/app_database" TASK_ID="$task_id" STARTED_AT="$started" python3 - > "$tmp/counts.json" <<'PY'
import hashlib, json, os, sqlite3
from datetime import datetime, timezone

db = os.environ["DB_PATH"]
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
con.row_factory = sqlite3.Row

def q(sql):
    try:
        return int(con.execute(sql).fetchone()[0] or 0)
    except Exception:
        return None

def sample(sql):
    try:
        out = []
        for row in con.execute(sql).fetchmany(5):
            raw = "|".join("" if v is None else str(v) for v in row)
            out.append(hashlib.sha256(raw.encode()).hexdigest()[:16])
        return out
    except Exception:
        return []

history_user_visible = """
SELECT count(*) FROM history_entries
WHERE id NOT LIKE 'APPLY_IMPORT_%'
  AND id NOT LIKE 'FULL_IMPORT_%'
  AND (deletedAt IS NULL OR syncStatus = 'NOT_ATTEMPTED')
"""
history_user_visible_pending = """
SELECT count(*) FROM history_entries h
LEFT JOIN history_entry_remote_refs r ON r.historyEntryUid = h.uid
WHERE h.id NOT LIKE 'APPLY_IMPORT_%'
  AND h.id NOT LIKE 'FULL_IMPORT_%'
  AND (
    r.historyEntryUid IS NULL
    OR r.localChangeRevision > r.lastSyncedLocalRevision
  )
"""
history_user_visible_local_only = """
SELECT count(*) FROM history_entries h
LEFT JOIN history_entry_remote_refs r ON r.historyEntryUid = h.uid
WHERE h.id NOT LIKE 'APPLY_IMPORT_%'
  AND h.id NOT LIKE 'FULL_IMPORT_%'
  AND r.remoteId IS NULL
"""
history_technical_local_only = """
SELECT count(*) FROM history_entries h
LEFT JOIN history_entry_remote_refs r ON r.historyEntryUid = h.uid
WHERE (h.id LIKE 'APPLY_IMPORT_%' OR h.id LIKE 'FULL_IMPORT_%')
  AND r.remoteId IS NULL
"""
pending_refs = """
SELECT
  (SELECT count(*) FROM supplier_remote_refs WHERE localChangeRevision > lastSyncedLocalRevision) +
  (SELECT count(*) FROM category_remote_refs WHERE localChangeRevision > lastSyncedLocalRevision) +
  (SELECT count(*) FROM product_remote_refs WHERE localChangeRevision > lastSyncedLocalRevision) +
  (SELECT count(*) FROM history_entry_remote_refs WHERE localChangeRevision > lastSyncedLocalRevision) +
  (SELECT count(*) FROM pending_catalog_tombstones)
"""
counts = {
    "products": {
        "active": q("SELECT count(*) FROM products"),
        "deleted": 0,
        "all": q("SELECT count(*) FROM products"),
        "dirty": q("SELECT count(*) FROM product_remote_refs WHERE localChangeRevision > lastSyncedLocalRevision"),
        "pending": q("SELECT count(*) FROM pending_catalog_tombstones WHERE entityType = 'product'"),
        "localOnly": q("SELECT count(*) FROM products p LEFT JOIN product_remote_refs r ON r.productId = p.id WHERE r.remoteId IS NULL"),
        "userVisible": None,
    },
    "suppliers": {
        "active": q("SELECT count(*) FROM suppliers"),
        "deleted": 0,
        "all": q("SELECT count(*) FROM suppliers"),
        "dirty": q("SELECT count(*) FROM supplier_remote_refs WHERE localChangeRevision > lastSyncedLocalRevision"),
        "pending": q("SELECT count(*) FROM pending_catalog_tombstones WHERE entityType = 'supplier'"),
        "localOnly": q("SELECT count(*) FROM suppliers s LEFT JOIN supplier_remote_refs r ON r.supplierId = s.id WHERE r.remoteId IS NULL"),
        "userVisible": None,
    },
    "categories": {
        "active": q("SELECT count(*) FROM categories"),
        "deleted": 0,
        "all": q("SELECT count(*) FROM categories"),
        "dirty": q("SELECT count(*) FROM category_remote_refs WHERE localChangeRevision > lastSyncedLocalRevision"),
        "pending": q("SELECT count(*) FROM pending_catalog_tombstones WHERE entityType = 'category'"),
        "localOnly": q("SELECT count(*) FROM categories c LEFT JOIN category_remote_refs r ON r.categoryId = c.id WHERE r.remoteId IS NULL"),
        "userVisible": None,
    },
    "product_prices": {
        "active": q("SELECT count(*) FROM product_prices pp JOIN products p ON p.id = pp.productId"),
        "deleted": 0,
        "all": q("SELECT count(*) FROM product_prices"),
        "dirty": 0,
        "pending": 0,
        "localOnly": q("SELECT count(*) FROM product_prices pp LEFT JOIN product_price_remote_refs r ON r.productPriceId = pp.id WHERE r.remoteId IS NULL"),
        "userVisible": None,
    },
    "history_entries": {
        "active": q("SELECT count(*) FROM history_entries WHERE deletedAt IS NULL"),
        "deleted": q("SELECT count(*) FROM history_entries WHERE deletedAt IS NOT NULL"),
        "all": q("SELECT count(*) FROM history_entries"),
        "dirty": q("SELECT count(*) FROM history_entry_remote_refs WHERE localChangeRevision > lastSyncedLocalRevision"),
        "pending": q(history_user_visible_pending),
        "localOnly": q(history_user_visible_local_only),
        "userVisible": q(history_user_visible),
    },
}
pending = q(pending_refs)
technical_history_local_only = q(history_technical_local_only) or 0
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
payload = {
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["STARTED_AT"],
    "completedAt": now,
    "source": "android",
    "account": {"state": "redacted"},
    "session": {"state": "device-local-redacted"},
    "counts": counts,
    "checkpoint": {"local": {"pendingAggregate": pending}, "remote": None},
    "lastPush": None,
    "lastPull": None,
    "lastFullReconciliation": None,
    "inserted": 0,
    "updated": 0,
    "deleted": counts["history_entries"]["deleted"] or 0,
    "pruned": {
        "wouldPrune": 0,
        "didPrune": 0,
        "skippedDirty": (counts["products"]["dirty"] or 0) + (counts["suppliers"]["dirty"] or 0) + (counts["categories"]["dirty"] or 0),
        "skippedLocalOnly": (counts["products"]["localOnly"] or 0) + (counts["suppliers"]["localOnly"] or 0) + (counts["categories"]["localOnly"] or 0) + technical_history_local_only,
        "skippedPendingTombstone": q("SELECT count(*) FROM pending_catalog_tombstones") or 0,
        "skippedScopedSnapshot": 0,
        "isCompleteSnapshot": None,
    },
    "skipped": 0,
    "drift": {},
    "samples": {
        "androidLocalProductsMissingRemote": sample("SELECT p.id, p.barcode FROM products p LEFT JOIN product_remote_refs r ON r.productId = p.id WHERE r.remoteId IS NULL ORDER BY p.id LIMIT 5"),
        "iosMissingSupplierCategory": [],
        "remotePriceHistoryWithoutLocalProduct": sample("SELECT pp.id, pp.productId FROM product_prices pp LEFT JOIN products p ON p.id = pp.productId WHERE p.id IS NULL ORDER BY pp.id LIMIT 5"),
        "historySessionActiveAllTombstone": [{"active": counts["history_entries"]["active"], "all": counts["history_entries"]["all"], "tombstone": counts["history_entries"]["deleted"]}],
        "localOnlyNotPrunable": (
            sample("SELECT 'product', p.id FROM products p LEFT JOIN product_remote_refs r ON r.productId = p.id WHERE r.remoteId IS NULL LIMIT 5") +
            sample("SELECT 'history_technical', h.id FROM history_entries h LEFT JOIN history_entry_remote_refs r ON r.historyEntryUid = h.uid WHERE (h.id LIKE 'APPLY_IMPORT_%' OR h.id LIKE 'FULL_IMPORT_%') AND r.remoteId IS NULL LIMIT 5")
        ),
    },
    "status": "PASS"
}
print(json.dumps(payload, sort_keys=True))
PY
  code=$?
  if [[ "$code" -ne 0 ]]; then
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "android" "Room database was copied but local count queries failed.")"
    rm -rf "$tmp"
    return "$MC_EXIT_BLOCKED"
  fi
  MC_SYNC_JSON_RESULT="$(cat "$tmp/counts.json")"
  rm -rf "$tmp"
  return "$MC_EXIT_PASS"
}

mc_sync_ios_container() {
  local bundle="${MC_IOS_BUNDLE_ID:-com.niwcyber.iOSMerchandiseControl}"
  xcrun simctl get_app_container booted "$bundle" data 2>/dev/null
}

mc_sync_ios_store_path() {
  local container="$1"
  local store
  store="$(find "$container" -type f -name 'default.store' 2>/dev/null | sort | head -1)"
  if [[ -z "$store" ]]; then
    store="$(find "$container" -type f \( -name '*.store' -o -name '*.sqlite' -o -name '*.db' \) 2>/dev/null | sort | head -1)"
  fi
  [[ -n "$store" ]] || return "$MC_EXIT_BLOCKED"
  printf '%s\n' "$store"
}

mc_sync_counts_ios() {
  local task_id="$1"
  local started container store code
  started="$(mc_now_iso)"
  container="$(mc_sync_ios_container)" || {
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "ios" "Booted simulator app container is unavailable; install/launch the iOS app first.")"
    return "$MC_EXIT_BLOCKED"
  }
  store="$(mc_sync_ios_store_path "$container" 2>/dev/null || true)"
  if [[ -z "$store" ]]; then
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "ios" "No SwiftData SQLite store was found in the booted simulator app container.")"
    return "$MC_EXIT_BLOCKED"
  fi
  DB_PATH="$store" TASK_ID="$task_id" STARTED_AT="$started" python3 - > /tmp/mc-agent-ios-counts.$$.json <<'PY'
import hashlib, json, os, sqlite3
from datetime import datetime, timezone

db = os.environ["DB_PATH"]
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
con.row_factory = sqlite3.Row
tables = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")]

def find_table(kind):
    wanted = {
        "products": ["ZPRODUCT"],
        "suppliers": ["ZSUPPLIER"],
        "categories": ["ZPRODUCTCATEGORY"],
        "product_prices": ["ZPRODUCTPRICE"],
        "history_entries": ["ZHISTORYENTRY"],
        "pending": ["ZLOCALPENDINGCHANGE"],
        "outbox": ["ZSYNCEVENTOUTBOXENTRY"],
    }[kind]
    upper = {t.upper(): t for t in tables}
    for name in wanted:
        if name in upper:
            return upper[name]
    token = wanted[0].replace("Z", "")
    for table in tables:
        u = table.upper()
        if token in u and "METADATA" not in u:
            if kind == "products" and "PRODUCTPRICE" in u:
                continue
            return table
    return None

def cols(table):
    if not table:
        return {}
    return {r[1].upper(): r[1] for r in con.execute(f"PRAGMA table_info({table})")}

def q(sql):
    try:
        return int(con.execute(sql).fetchone()[0] or 0)
    except Exception:
        return None

def count(table, where=None):
    if not table:
        return None
    sql = f"SELECT count(*) FROM {table}" + (f" WHERE {where}" if where else "")
    return q(sql)

def sample(table, where=None):
    if not table:
        return []
    cs = cols(table)
    col = cs.get("ZREMOTEID") or cs.get("ZID") or cs.get("ZCHANGEID") or "rowid"
    sql = f"SELECT {col} FROM {table}" + (f" WHERE {where}" if where else "") + f" ORDER BY {col} LIMIT 5"
    try:
        return [hashlib.sha256(str(r[0]).encode()).hexdigest()[:16] for r in con.execute(sql)]
    except Exception:
        return []

entity_tables = {k: find_table(k) for k in ["products", "suppliers", "categories", "product_prices", "history_entries", "pending", "outbox"]}

def remote_deleted_where(table):
    c = cols(table)
    deleted = c.get("ZREMOTEDELETEDAT")
    return f"{deleted} IS NULL" if deleted else None

def local_only_where(table):
    c = cols(table)
    remote = c.get("ZREMOTEID")
    return f"{remote} IS NULL" if remote else None

def pending_count(kind=None):
    table = entity_tables["pending"]
    if not table:
        return 0
    c = cols(table)
    status = c.get("ZSTATUSRAW")
    entity = c.get("ZENTITYKINDRAW")
    where = []
    if status:
        where.append(f"{status} NOT IN ('acknowledged','superseded')")
    if kind and entity:
        where.append(f"{entity} = '{kind}'")
    return count(table, " AND ".join(where)) or 0

counts = {}
kind_map = {
    "products": "product",
    "suppliers": "supplier",
    "categories": "productCategory",
    "product_prices": "productPrice",
    "history_entries": "historySession",
}
for key, pending_kind in kind_map.items():
    table = entity_tables[key]
    deleted_where = remote_deleted_where(table)
    local_only = local_only_where(table)
    active = count(table, deleted_where)
    all_count = count(table)
    deleted = None if active is None or all_count is None else max(0, all_count - active)
    counts[key] = {
        "active": active,
        "deleted": deleted,
        "all": all_count,
        "dirty": pending_count(pending_kind),
        "pending": pending_count(pending_kind),
        "localOnly": count(table, local_only) if local_only else None,
        "userVisible": None,
    }

history = entity_tables["history_entries"]
if history:
    c = cols(history)
    id_col = c.get("ZID")
    deleted_col = c.get("ZREMOTEDELETEDAT")
    where = []
    if id_col:
        where.append(f"{id_col} NOT LIKE 'APPLY_IMPORT_%'")
        where.append(f"{id_col} NOT LIKE 'FULL_IMPORT_%'")
    if deleted_col:
        where.append(f"{deleted_col} IS NULL")
    counts["history_entries"]["userVisible"] = count(history, " AND ".join(where)) if where else counts["history_entries"]["active"]

outbox = entity_tables["outbox"]
outbox_pending = 0
if outbox:
    c = cols(outbox)
    status = c.get("ZSTATUSRAW")
    outbox_pending = count(outbox, f"{status} IN ('pending','retryable','failedRetryable','blocked')") if status else count(outbox)

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
payload = {
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["STARTED_AT"],
    "completedAt": now,
    "source": "ios",
    "account": {"state": "redacted"},
    "session": {"state": "simulator-local-redacted"},
    "counts": counts,
    "checkpoint": {"local": {"pendingAggregate": pending_count() + (outbox_pending or 0)}, "remote": None},
    "lastPush": None,
    "lastPull": None,
    "lastFullReconciliation": None,
    "inserted": 0,
    "updated": 0,
    "deleted": counts["history_entries"]["deleted"] or 0,
    "pruned": {
        "wouldPrune": 0,
        "didPrune": 0,
        "skippedDirty": pending_count(),
        "skippedLocalOnly": 0,
        "skippedPendingTombstone": 0,
        "skippedScopedSnapshot": 0,
        "isCompleteSnapshot": None
    },
    "skipped": 0,
    "drift": {},
    "samples": {
        "androidLocalProductsMissingRemote": [],
        "iosMissingSupplierCategory": sample(entity_tables["suppliers"], local_only_where(entity_tables["suppliers"])) + sample(entity_tables["categories"], local_only_where(entity_tables["categories"])),
        "remotePriceHistoryWithoutLocalProduct": [],
        "historySessionActiveAllTombstone": [{"active": counts["history_entries"]["active"], "all": counts["history_entries"]["all"], "tombstone": counts["history_entries"]["deleted"]}],
        "localOnlyNotPrunable": sample(entity_tables["products"], local_only_where(entity_tables["products"])),
    },
    "status": "PASS"
}
print(json.dumps(payload, sort_keys=True))
PY
  code=$?
  if [[ "$code" -ne 0 ]]; then
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "ios" "SwiftData store was found but count queries failed.")"
    return "$MC_EXIT_BLOCKED"
  fi
  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-ios-counts.$$.json)"
  rm -f /tmp/mc-agent-ios-counts.$$.json
  return "$MC_EXIT_PASS"
}

mc_sync_counts() {
  local task_id="$1"
  local source="$2"
  local profile="$3"
  MC_PLATFORM="sync"
  MC_SAFETY_LEVEL="safe-readonly"
  MC_PROFILE="$profile"
  MC_CA_REFS="CA-01,CA-02,CA-03,CA-07,CA-10"
  case "$source" in
    supabase) mc_sync_counts_supabase "$task_id" "$profile" ;;
    android) mc_sync_counts_android "$task_id" ;;
    ios) mc_sync_counts_ios "$task_id" ;;
    *)
      MC_SUMMARY="Unknown sync count source: ${source}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
  local code=$?
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
  if [[ "$code" -eq 0 ]]; then
    MC_SUMMARY="Sync counts ${source} PASS for ${task_id}."
    MC_NEXT_ACTION="Run remaining sync counts or live reconcile-counts."
    return "$MC_EXIT_PASS"
  fi
  MC_SUMMARY="Sync counts ${source} BLOCKED for ${task_id}."
  MC_NEXT_ACTION="Resolve source-specific access/auth/device blocker and retry."
  return "$code"
}

mc_sync_reconcile_counts() {
  local task_id="$1"
  local prefix="$2"
  local profile="${3:-linked}"
  local started supabase_json android_json ios_json code_s code_a code_i
  MC_PLATFORM="live"
  MC_SAFETY_LEVEL="live-write"
  MC_REQUIRES_LIVE="true"
  MC_CA_REFS="CA-01,CA-02,CA-03,CA-06,CA-07,CA-10"
  mc_validate_task_prefix "$prefix" || return $?
  mc_require_live || return $?
  MC_TEST_PREFIX="$prefix"
  started="$(mc_now_iso)"

  mc_sync_counts_supabase "$task_id" "$profile"; code_s=$?; supabase_json="$MC_SYNC_JSON_RESULT"
  mc_sync_counts_android "$task_id"; code_a=$?; android_json="$MC_SYNC_JSON_RESULT"
  mc_sync_counts_ios "$task_id"; code_i=$?; ios_json="$MC_SYNC_JSON_RESULT"

  RECON_STARTED="$started" TASK_ID="$task_id" PREFIX="$prefix" SUPABASE_JSON="$supabase_json" ANDROID_JSON="$android_json" IOS_JSON="$ios_json" CODES="$code_s,$code_a,$code_i" python3 - > /tmp/mc-agent-reconcile-counts.$$.json <<'PY'
import json, os
from datetime import datetime, timezone

sources = {
    "supabase": json.loads(os.environ["SUPABASE_JSON"]),
    "android": json.loads(os.environ["ANDROID_JSON"]),
    "ios": json.loads(os.environ["IOS_JSON"]),
}
codes = [int(x) for x in os.environ["CODES"].split(",")]
tables = ["products", "suppliers", "categories", "product_prices", "history_entries"]
comparison_fields = {
    "products": ["active", "pending", "localOnly"],
    "suppliers": ["active", "pending", "localOnly"],
    "categories": ["active", "pending", "localOnly"],
    "product_prices": ["active", "pending", "localOnly"],
    "history_entries": ["userVisible", "pending", "localOnly"],
}
drift = {}
blocked = {}
for name, payload in sources.items():
    if payload.get("status") == "BLOCKED":
        blocked[name] = payload.get("blocker")
for table in tables:
    drift[table] = {}
    for field in comparison_fields[table]:
        values = {name: payload.get("counts", {}).get(table, {}).get(field) for name, payload in sources.items()}
        comparable = {k: v for k, v in values.items() if v is not None}
        if len(set(comparable.values())) > 1:
            drift[table][field] = values
    if not drift[table]:
        drift.pop(table)

status = "BLOCKED" if blocked else ("PASS" if not drift else "FAIL")
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
payload = {
    "schemaVersion": "1.1",
    "taskId": os.environ["TASK_ID"],
    "startedAt": os.environ["RECON_STARTED"],
    "completedAt": now,
    "source": "live.reconcile-counts",
    "account": {"state": "redacted"},
    "session": {"state": "redacted"},
    "prefix": os.environ["PREFIX"],
    "counts": {
        "supabase": sources["supabase"].get("counts", {}),
        "android": sources["android"].get("counts", {}),
        "ios": sources["ios"].get("counts", {}),
    },
    "checkpoint": {
        "supabase": sources["supabase"].get("checkpoint"),
        "android": sources["android"].get("checkpoint"),
        "ios": sources["ios"].get("checkpoint"),
    },
    "lastPush": None,
    "lastPull": None,
    "lastFullReconciliation": None,
    "inserted": 0,
    "updated": 0,
    "deleted": 0,
    "pruned": {
        "wouldPrune": sum((sources[s].get("pruned", {}).get("wouldPrune") or 0) for s in sources),
        "didPrune": sum((sources[s].get("pruned", {}).get("didPrune") or 0) for s in sources),
        "skippedDirty": sum((sources[s].get("pruned", {}).get("skippedDirty") or 0) for s in sources),
        "skippedLocalOnly": sum((sources[s].get("pruned", {}).get("skippedLocalOnly") or 0) for s in sources),
        "skippedPendingTombstone": sum((sources[s].get("pruned", {}).get("skippedPendingTombstone") or 0) for s in sources),
        "skippedScopedSnapshot": sum((sources[s].get("pruned", {}).get("skippedScopedSnapshot") or 0) for s in sources),
        "isCompleteSnapshot": None,
    },
    "comparison": {"fields": comparison_fields, "definition": "TASK-114 canonical compare uses active/pending/localOnly for catalog/prices and userVisible/pending/localOnly for history; raw active/all/deleted remain diagnostic."},
    "skipped": 0,
    "drift": drift,
    "samples": {
        "androidLocalProductsMissingRemote": sources["android"].get("samples", {}).get("androidLocalProductsMissingRemote", []),
        "iosMissingSupplierCategory": sources["ios"].get("samples", {}).get("iosMissingSupplierCategory", []),
        "remotePriceHistoryWithoutLocalProduct": sources["android"].get("samples", {}).get("remotePriceHistoryWithoutLocalProduct", []),
        "historySessionActiveAllTombstone": sources["supabase"].get("samples", {}).get("historySessionActiveAllTombstone", []),
        "localOnlyNotPrunable": (
            sources["android"].get("samples", {}).get("localOnlyNotPrunable", []) +
            sources["ios"].get("samples", {}).get("localOnlyNotPrunable", [])
        ),
    },
    "status": status,
    "blockers": blocked,
}
print(json.dumps(payload, sort_keys=True))
PY
  local py_code=$?
  if [[ "$py_code" -ne 0 ]]; then
    MC_SYNC_JSON_RESULT="$(mc_sync_make_blocked_json "$task_id" "live.reconcile-counts" "Failed to assemble reconciliation JSON.")"
    mc_sync_set_detail "$MC_SYNC_JSON_RESULT"
    MC_SUMMARY="Live reconcile-counts BLOCKED: report assembly failed."
    MC_NEXT_ACTION="Inspect sync count sub-reports and retry."
    return "$MC_EXIT_BLOCKED"
  fi

  MC_SYNC_JSON_RESULT="$(cat /tmp/mc-agent-reconcile-counts.$$.json)"
  rm -f /tmp/mc-agent-reconcile-counts.$$.json
  mc_sync_set_detail "$MC_SYNC_JSON_RESULT"

  local status
  status="$(python3 - "$MC_SYNC_JSON_RESULT" <<'PY'
import json, sys
print(json.loads(sys.argv[1]).get("status", "FAIL"))
PY
)"
  case "$status" in
    PASS)
      MC_SUMMARY="Live reconcile-counts PASS for ${prefix}: Android, iOS and Supabase count definitions align."
      MC_NEXT_ACTION="Run live sync-matrix and cleanup/residue if test data was created."
      return "$MC_EXIT_PASS"
      ;;
    BLOCKED)
      MC_SUMMARY="Live reconcile-counts BLOCKED for ${prefix}: one or more local/live count sources unavailable."
      MC_NEXT_ACTION="Resolve device/auth/local store blockers and retry."
      return "$MC_EXIT_BLOCKED"
      ;;
    *)
      MC_SUMMARY="Live reconcile-counts FAIL for ${prefix}: drift remains between Android, iOS and Supabase."
      MC_NEXT_ACTION="Inspect drift table in report, repair sync/apply/prune, then rerun."
      return "$MC_EXIT_FAIL"
      ;;
  esac
}

mc_cmd_sync() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    counts)
      local task_id source profile
      task_id="$(mc_parse_opt --task "$@" || true)"
      task_id="${task_id:-$MC_TASK_ID}"
      source="$(mc_parse_opt --source "$@" || true)"
      profile="$(mc_parse_opt --profile "$@" || true)"
      profile="${profile:-${MC_SUPABASE_PROFILE:-linked}}"
      [[ -n "$source" ]] || {
        MC_SUMMARY="--source is required for sync counts."
        return "$MC_EXIT_MISCONFIGURED"
      }
      mc_sync_counts "$task_id" "$source" "$profile"
      ;;
    *)
      MC_SUMMARY="Unknown sync subcommand: ${sub}"
      return "$MC_EXIT_MISCONFIGURED"
      ;;
  esac
}
