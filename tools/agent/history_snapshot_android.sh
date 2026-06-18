#!/usr/bin/env bash
set -euo pipefail

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
PACKAGE="${ANDROID_PACKAGE:-com.example.merchandisecontrolsplitview}"
SERIAL="${ANDROID_SERIAL:-}"
DB_PATH="${ANDROID_HISTORY_DB:-}"
SOURCE_NAME="${HISTORY_SOURCE_NAME:-android}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if [[ -z "$DB_PATH" ]]; then
  if [[ -z "$SERIAL" ]]; then
    SERIAL="$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  fi
  if [[ -z "$SERIAL" ]]; then
    echo "history_snapshot_android: no adb device available" >&2
    exit 2
  fi
  DB_PATH="$tmp_dir/app_database"
  "$ADB" -s "$SERIAL" shell "run-as $PACKAGE cat databases/app_database" > "$DB_PATH"
  if "$ADB" -s "$SERIAL" shell "run-as $PACKAGE sh -c '[ -f databases/app_database-wal ]'" >/dev/null 2>&1; then
    "$ADB" -s "$SERIAL" shell "run-as $PACKAGE cat databases/app_database-wal" > "$DB_PATH-wal"
  fi
  if "$ADB" -s "$SERIAL" shell "run-as $PACKAGE sh -c '[ -f databases/app_database-shm ]'" >/dev/null 2>&1; then
    "$ADB" -s "$SERIAL" shell "run-as $PACKAGE cat databases/app_database-shm" > "$DB_PATH-shm"
  fi
fi

if [[ ! -f "$DB_PATH" ]]; then
  echo "history_snapshot_android: Room DB not found" >&2
  exit 2
fi

python3 - "$DB_PATH" "$SOURCE_NAME" <<'PY'
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys

db_path, source_name = sys.argv[1], sys.argv[2]

def parse_jsonish(raw, default):
    if raw is None:
        return default
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8", errors="ignore")
    if not isinstance(raw, str) or not raw.strip():
        return default
    try:
        return json.loads(raw)
    except Exception:
        return default

def json_canonical(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)

def sha256(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()

uuid_display_name_pattern = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)

def payload_display_name(value):
    text = (value or "").strip()
    return "" if uuid_display_name_pattern.match(text) else (value or "")

def normalize_timestamp(raw):
    if not raw:
        return ""
    text = str(raw).strip()
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            parsed = dt.datetime.strptime(text, fmt)
            return parsed.replace(tzinfo=dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        except ValueError:
            pass
    try:
        parsed = dt.datetime.fromisoformat(text.replace("Z", "+00:00"))
        return parsed.astimezone(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    except ValueError:
        return text

def logical_fingerprint(row):
    canonical = "|".join([
        str(row["payloadVersion"]),
        payload_display_name(row["title"]).strip(),
        row["timestamp"],
        row["supplier"].strip(),
        row["category"].strip(),
        "1" if row["isManualEntry"] else "0",
        json_canonical(row["data"]),
        json_canonical(row["editable"]),
        json_canonical(row["complete"]),
        row["deletedAt"] or "",
    ])
    return sha256(canonical)

def is_user_facing_identifier(value):
    trimmed = (value or "").strip()
    if not trimmed:
        return True
    upper = trimmed.upper()
    return not (
        upper.startswith("APPLY_IMPORT_")
        or upper.startswith("FULL_IMPORT_")
        or upper.startswith("TASK135_MATRIX_")
    )

def visibility(title, export_id, tombstone, pending_delete=False):
    reasons = []
    if tombstone and not pending_delete:
        reasons.append("tombstone")
    if not is_user_facing_identifier(export_id):
        reasons.append("local id technical/TASK")
    if not is_user_facing_identifier(title):
        reasons.append("title technical/TASK")
    visible = (not tombstone or pending_delete) and not reasons
    return visible, visible, ", ".join(reasons)

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
query = """
select h.uid, h.id, h.displayName, h.timestamp, h.supplier, h.category,
       h.isManualEntry, h.data, h.editable, h.complete, h.deletedAt,
       h.orderTotal, h.paymentTotal, h.missingItems, h.totalItems,
       h.syncStatus,
       r.remoteId, r.lastRemotePayloadFingerprint, r.lastRemoteAppliedAt,
       r.localChangeRevision, r.lastSyncedLocalRevision
from history_entries h
left join history_entry_remote_refs r on r.historyEntryUid = h.uid
order by coalesce(r.remoteId, h.id), h.uid
"""
rows = []
for record in conn.execute(query):
    data = parse_jsonish(record["data"], [])
    editable = parse_jsonish(record["editable"], [])
    complete = parse_jsonish(record["complete"], [])
    remote_id = record["remoteId"] or ""
    row = {
        "source": source_name,
        "remote_id": remote_id,
        "remote_id_key": remote_id.lower().replace("-", ""),
        "local_id": str(record["uid"]),
        "logical_key": "",
        "title": record["displayName"] or record["id"] or "",
        "timestamp": normalize_timestamp(record["timestamp"]),
        "supplier": record["supplier"] or "",
        "category": record["category"] or "",
        "isManualEntry": bool(record["isManualEntry"]),
        "totalItems": record["totalItems"],
        "orderTotal": record["orderTotal"],
        "paymentTotal": record["paymentTotal"],
        "missingItems": record["missingItems"],
        "rowCount": len(data) if isinstance(data, list) else 0,
        "rowsHash": sha256(json_canonical(data)),
        "editableHash": sha256(json_canonical(editable)),
        "completeHash": sha256(json_canonical(complete)),
        "payloadHash": "",
        "fingerprint": "",
        "storedFingerprint": record["lastRemotePayloadFingerprint"],
        "tombstone": record["deletedAt"] is not None,
        "deletedAt": normalize_timestamp(record["deletedAt"]) if record["deletedAt"] else "",
        "updatedAt": "",
        "localChangeRevision": record["localChangeRevision"],
        "lastSyncedLocalRevision": record["lastSyncedLocalRevision"],
        "data": data,
        "editable": editable,
        "complete": complete,
    }
    row["payloadVersion"] = 2
    row["payloadHash"] = sha256(json_canonical({"data": data, "editable": editable, "complete": complete}))
    row["fingerprint"] = logical_fingerprint(row)
    row["logical_key"] = row["fingerprint"]
    pending_delete = row["tombstone"] and record["syncStatus"] == "NOT_ATTEMPTED"
    row["pendingDelete"] = pending_delete
    is_visible, is_shown, hidden_reason = visibility(
        row["title"],
        record["id"] or "",
        row["tombstone"],
        pending_delete=pending_delete
    )
    row["isUserVisible"] = is_visible
    row["isShownInHistoryList"] = is_shown
    row["reasonHidden"] = hidden_reason
    rows.append(row)

print(json.dumps({"source": source_name, "db": db_path, "rows": rows}, indent=2, sort_keys=True))
PY
