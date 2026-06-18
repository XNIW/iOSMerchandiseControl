#!/usr/bin/env bash
set -euo pipefail

DATABASE_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
SUPABASE_PROFILE="${HISTORY_SUPABASE_PROFILE:-${SUPABASE_PROFILE:-local}}"
SUPABASE_REPO="${SUPABASE_REPO:-/Users/minxiang/Desktop/MerchandiseControlSupabase}"
OWNER_UUID="${OWNER_UUID:-${SUPABASE_OWNER_UUID:-}}"
SOURCE_NAME="${HISTORY_SOURCE_NAME:-supabase}"

if [[ -n "$OWNER_UUID" && ! "$OWNER_UUID" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  echo "history_snapshot_supabase: OWNER_UUID is not a UUID" >&2
  exit 2
fi

if [[ "$SUPABASE_PROFILE" != "local" && "$SUPABASE_PROFILE" != "linked" ]]; then
  echo "history_snapshot_supabase: SUPABASE_PROFILE must be local or linked" >&2
  exit 2
fi

tmp_rows="$(mktemp)"
trap 'rm -f "$tmp_rows"' EXIT

if [[ -n "$OWNER_UUID" ]]; then
  owner_sql="'$OWNER_UUID'::uuid"
  owner_selection="explicit"
else
  owner_sql="NULL::uuid"
  owner_selection="inferred_top_history_owner"
fi

read -r -d '' sql <<SQL || true
with selected_owner as (
  select coalesce(
    ${owner_sql},
    (
      select owner_user_id
      from public.shared_sheet_sessions
      group by owner_user_id
      order by count(*) filter (where deleted_at is null) desc, count(*) desc
      limit 1
    )
  ) as owner_user_id
)
select owner_user_id::text as owner_user_id,
       remote_id::text as remote_id,
       payload_version::text as payload_version,
       display_name,
       timestamp::text as timestamp,
       supplier,
       category,
       is_manual_entry::text as is_manual_entry,
       data::text as data_json,
       coalesce(session_overlay::text, '') as overlay_json,
       deleted_at::text as deleted_at,
       updated_at::text as updated_at
from public.shared_sheet_sessions
where owner_user_id = (select owner_user_id from selected_owner)
order by remote_id
SQL

if [[ "$SUPABASE_PROFILE" == "linked" ]]; then
  (
    cd "$SUPABASE_REPO"
    env -u SUPABASE_PROFILE supabase db query --linked -o json "$sql"
  ) > "$tmp_rows"
else
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -c "copy (${sql}) to stdout with csv header" > "$tmp_rows"
fi

python3 - "$tmp_rows" "$SOURCE_NAME" "$SUPABASE_PROFILE" "$owner_selection" <<'PY'
import csv
import datetime as dt
import hashlib
import json
import sys

rows_path, source_name, profile, owner_selection = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def parse_jsonish(raw, default):
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

def visibility(title, remote_id, tombstone):
    reasons = []
    if tombstone:
        reasons.append("tombstone")
    if not is_user_facing_identifier(remote_id):
        reasons.append("remote_id technical/TASK")
    if not is_user_facing_identifier(title):
        reasons.append("title technical/TASK")
    visible = not tombstone and not reasons
    return visible, visible, ", ".join(reasons)

def boolish(value):
    if isinstance(value, bool):
        return value
    return str(value or "").strip().lower() in ("t", "true", "1", "yes")

rows = []

def load_records(path):
    raw = open(path, newline="").read()
    stripped = raw.strip()
    if not stripped:
        return []
    if stripped[0] in "[{":
        payload = json.loads(stripped)
        if isinstance(payload, dict):
            return payload.get("rows", payload.get("data", []))
        return payload
    return list(csv.DictReader(stripped.splitlines()))

owner_hash = ""
records = load_records(rows_path)
if records:
    owner = records[0].get("owner_user_id") or ""
    owner_hash = sha256(owner) if owner else ""
    if not owner:
        owner_selection = "unknown"

for record in records:
    data = parse_jsonish(record["data_json"], [])
    overlay = parse_jsonish(record["overlay_json"], {})
    editable = overlay.get("editable", []) if isinstance(overlay, dict) else []
    complete = overlay.get("complete", []) if isinstance(overlay, dict) else []
    remote_id = record["remote_id"] or ""
    row = {
        "source": source_name,
        "remote_id": remote_id,
        "remote_id_key": remote_id.lower().replace("-", ""),
        "local_id": "",
        "logical_key": "",
        "title": record["display_name"] or "",
        "timestamp": normalize_timestamp(record["timestamp"]),
        "supplier": record["supplier"] or "",
        "category": record["category"] or "",
        "isManualEntry": boolish(record["is_manual_entry"]),
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
        "tombstone": bool(record["deleted_at"]),
        "deletedAt": normalize_timestamp(record["deleted_at"]),
        "updatedAt": normalize_timestamp(record["updated_at"]),
        "data": data,
        "editable": editable,
        "complete": complete,
        "payloadVersion": int(record["payload_version"] or 2),
    }
    row["payloadHash"] = sha256(json_canonical({"data": data, "editable": editable, "complete": complete}))
    row["fingerprint"] = logical_fingerprint(row)
    row["logical_key"] = row["fingerprint"]
    is_visible, is_shown, hidden_reason = visibility(row["title"], row["remote_id"], row["tombstone"])
    row["isUserVisible"] = is_visible
    row["isShownInHistoryList"] = is_shown
    row["reasonHidden"] = hidden_reason
    rows.append(row)

print(json.dumps({
    "source": source_name,
    "profile": profile,
    "ownerHash": owner_hash,
    "ownerSelection": owner_selection,
    "rows": rows
}, indent=2, sort_keys=True))
PY
