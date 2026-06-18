#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${IOS_BUNDLE_ID:-com.niwcyber.iOSMerchandiseControl}"
SIMULATOR_UDID="${IOS_SIMULATOR_UDID:-${IOS_HISTORY_SIMULATOR:-booted}}"
STORE_PATH="${IOS_HISTORY_STORE:-}"
SOURCE_NAME="${HISTORY_SOURCE_NAME:-ios}"

if [[ -z "$STORE_PATH" ]]; then
  container="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
  STORE_PATH="$(find "$container" -type f -name 'default.store' | sort | head -1)"
fi

if [[ -z "$STORE_PATH" || ! -f "$STORE_PATH" ]]; then
  echo "history_snapshot_ios: default.store not found" >&2
  exit 2
fi

python3 - "$STORE_PATH" "$SOURCE_NAME" "$SIMULATOR_UDID" <<'PY'
import datetime as dt
import hashlib
import json
import sqlite3
import sys
import uuid

store_path, source_name, simulator_udid = sys.argv[1], sys.argv[2], sys.argv[3]

def pick(cols, *names):
    for name in names:
        if name in cols:
            return name
    return None

def value(row, column):
    return row[column] if column else None

def decode_blob(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.hex().lower()
    return str(value).strip().lower().replace("-", "")

def decode_remote_id(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        if len(value) == 16:
            return str(uuid.UUID(bytes=value))
        return value.hex().lower()
    return str(value).strip().lower()

def parse_jsonish(raw, default):
    if raw is None:
        return default
    if isinstance(raw, bytes):
        try:
            raw = raw.decode("utf-8")
        except Exception:
            return default
    if not isinstance(raw, str):
        return default
    raw = raw.strip()
    if not raw:
        return default
    try:
        return json.loads(raw)
    except Exception:
        return default

def json_canonical(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)

def sha256(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()

def normalize_timestamp(raw):
    if raw is None or raw == "":
        return ""
    if isinstance(raw, (int, float)):
        seconds = float(raw)
        if seconds < 1_000_000_000:
            seconds += 978_307_200
        return dt.datetime.fromtimestamp(seconds, tz=dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
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
        row["title"].strip(),
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

def visibility(title, local_id, tombstone, pending_delete=False):
    reasons = []
    if tombstone and not pending_delete:
        reasons.append("tombstone")
    if not is_user_facing_identifier(local_id):
        reasons.append("local_id technical/TASK")
    if not is_user_facing_identifier(title):
        reasons.append("title technical/TASK")
    visible = (not tombstone or pending_delete) and not reasons
    return visible, visible, ", ".join(reasons)

conn = sqlite3.connect(f"file:{store_path}?mode=ro", uri=True)
conn.row_factory = sqlite3.Row
tables = {row[0] for row in conn.execute("select name from sqlite_master where type='table'")}
if "ZHISTORYENTRY" not in tables:
    print(json.dumps({"source": source_name, "rows": []}, indent=2, sort_keys=True))
    sys.exit(0)

cols = {row[1] for row in conn.execute("pragma table_info(ZHISTORYENTRY)")}
columns = {
    "pk": pick(cols, "Z_PK"),
    "id": pick(cols, "ZID"),
    "remote": pick(cols, "ZREMOTEID"),
    "display": pick(cols, "ZDISPLAYNAME", "ZTITLE", "ZID"),
    "timestamp": pick(cols, "ZTIMESTAMP"),
    "supplier": pick(cols, "ZSUPPLIER"),
    "category": pick(cols, "ZCATEGORY"),
    "manual": pick(cols, "ZISMANUALENTRY"),
    "data": pick(cols, "ZDATAJSON", "ZDATA"),
    "editable": pick(cols, "ZEDITABLEJSON", "ZEDITABLE"),
    "complete": pick(cols, "ZCOMPLETEJSON", "ZCOMPLETE"),
    "deleted": pick(cols, "ZREMOTEDELETEDAT", "ZDELETEDAT"),
    "updated": pick(cols, "ZUPDATEDAT", "ZREMOTEUPDATEDAT"),
    "localRevision": pick(cols, "ZLOCALCHANGEREVISION"),
    "lastSyncedRevision": pick(cols, "ZLASTSYNCEDLOCALREVISION"),
}

rows = []
for record in conn.execute("select * from ZHISTORYENTRY"):
    data = parse_jsonish(value(record, columns["data"]), [])
    editable = parse_jsonish(value(record, columns["editable"]), [])
    complete = parse_jsonish(value(record, columns["complete"]), [])
    row = {
        "source": source_name,
        "remote_id": decode_remote_id(value(record, columns["remote"])),
        "remote_id_key": decode_blob(value(record, columns["remote"])),
        "local_id": str(value(record, columns["id"]) or value(record, columns["pk"]) or ""),
        "logical_key": "",
        "title": str(value(record, columns["display"]) or ""),
        "timestamp": normalize_timestamp(value(record, columns["timestamp"])),
        "supplier": str(value(record, columns["supplier"]) or ""),
        "category": str(value(record, columns["category"]) or ""),
        "isManualEntry": bool(value(record, columns["manual"]) or False),
        "totalItems": len(data[1:]) if isinstance(data, list) else 0,
        "orderTotal": None,
        "paymentTotal": None,
        "missingItems": None,
        "rowCount": len(data) if isinstance(data, list) else 0,
        "rowsHash": sha256(json_canonical(data)),
        "editableHash": sha256(json_canonical(editable)),
        "completeHash": sha256(json_canonical(complete)),
        "payloadHash": "",
        "fingerprint": "",
        "tombstone": value(record, columns["deleted"]) is not None,
        "deletedAt": normalize_timestamp(value(record, columns["deleted"])) if value(record, columns["deleted"]) is not None else "",
        "updatedAt": normalize_timestamp(value(record, columns["updated"])) if value(record, columns["updated"]) is not None else "",
        "data": data,
        "editable": editable,
        "complete": complete,
    }
    row["payloadVersion"] = 2
    row["payloadHash"] = sha256(json_canonical({"data": data, "editable": editable, "complete": complete}))
    row["fingerprint"] = logical_fingerprint(row)
    row["logical_key"] = row["fingerprint"]
    local_revision = int(value(record, columns["localRevision"]) or 0)
    last_synced_revision = int(value(record, columns["lastSyncedRevision"]) or 0)
    row["localChangeRevision"] = local_revision
    row["lastSyncedLocalRevision"] = last_synced_revision
    pending_delete = row["tombstone"] and local_revision > last_synced_revision
    row["pendingDelete"] = pending_delete
    is_visible, is_shown, hidden_reason = visibility(
        row["title"],
        row["local_id"],
        row["tombstone"],
        pending_delete=pending_delete
    )
    row["isUserVisible"] = is_visible
    row["isShownInHistoryList"] = is_shown
    row["reasonHidden"] = hidden_reason
    rows.append(row)

print(json.dumps({"source": source_name, "simulator": simulator_udid, "store": store_path, "rows": rows}, indent=2, sort_keys=True))
PY
