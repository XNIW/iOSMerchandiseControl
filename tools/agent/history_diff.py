#!/usr/bin/env python3
import argparse
import collections
import json
from pathlib import Path


def load_snapshot(path, visible_only=False):
    payload = json.loads(Path(path).read_text())
    if isinstance(payload, list):
        rows = payload
        source = Path(path).stem
    else:
        rows = payload.get("rows", [])
        source = payload.get("source") or Path(path).stem
    for row in rows:
        row.setdefault("source", source)
    if visible_only:
        rows = [row for row in rows if row.get("isShownInHistoryList")]
    return source, rows


def duplicate_values(rows, field):
    values = collections.defaultdict(list)
    for row in rows:
        value = row.get(field) or ""
        if value:
            values[value].append(row)
    return {key: value for key, value in values.items() if len(value) > 1}


def task_residue(rows):
    result = []
    for row in rows:
        joined = " ".join(str(row.get(field) or "") for field in ("remote_id", "local_id", "title"))
        if "TASK135" in joined.upper():
            result.append(row)
    return result


def main():
    parser = argparse.ArgumentParser(description="Compare normalized TASK-135 History snapshots.")
    parser.add_argument("snapshots", nargs="+", help="JSON snapshots from history_snapshot_*.sh")
    parser.add_argument(
        "--visible-only",
        action="store_true",
        help="Compare only rows shown by the History UI / Options public count predicate.",
    )
    parser.add_argument("--output", "-o", help="Write markdown report to this path")
    args = parser.parse_args()

    by_source = {}
    all_rows = []
    for path in args.snapshots:
        source, rows = load_snapshot(path, visible_only=args.visible_only)
        by_source[source] = rows
        all_rows.extend(rows)

    sources = sorted(by_source)
    fingerprints_by_source = {
        source: {row.get("fingerprint") for row in rows if row.get("fingerprint")}
        for source, rows in by_source.items()
    }
    all_fingerprints = set().union(*fingerprints_by_source.values()) if fingerprints_by_source else set()
    common = set(all_fingerprints)
    for values in fingerprints_by_source.values():
        common &= values

    lines = []
    lines.append("# TASK-135 History Row-Level Diff")
    lines.append("")
    lines.append(f"- mode: {'visible-only' if args.visible_only else 'all rows'}")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    for source in sources:
        rows = by_source[source]
        active = [row for row in rows if not row.get("tombstone")]
        lines.append(f"- {source}: rows={len(rows)} active={len(active)} fingerprints={len(fingerprints_by_source[source])}")
    lines.append(f"- present_on_all={len(common)}")
    lines.append("")

    lines.append("## Presence By Fingerprint")
    lines.append("")
    for source in sources:
        only = fingerprints_by_source[source] - set().union(
            *(fingerprints_by_source[other] for other in sources if other != source)
        )
        lines.append(f"- only_{source}: {len(only)}")
    lines.append("")

    lines.append("## Duplicates")
    lines.append("")
    for source in sources:
        rows = by_source[source]
        remote_dupes = duplicate_values(rows, "remote_id_key")
        fingerprint_dupes = duplicate_values(rows, "fingerprint")
        lines.append(f"- {source}: duplicate_remote_id={len(remote_dupes)} duplicate_fingerprint={len(fingerprint_dupes)}")
    lines.append("")

    lines.append("## Mismatches")
    lines.append("")
    comparable = collections.defaultdict(dict)
    for source, rows in by_source.items():
        for row in rows:
            fp = row.get("fingerprint")
            if fp:
                comparable[fp][source] = row
    mismatch_count = 0
    for fp, rows in sorted(comparable.items()):
        if len(rows) < 2:
            continue
        payload_hashes = {source: row.get("payloadHash") for source, row in rows.items()}
        timestamps = {source: row.get("timestamp") for source, row in rows.items()}
        tombstones = {source: row.get("tombstone") for source, row in rows.items()}
        if len(set(payload_hashes.values())) > 1 or len(set(timestamps.values())) > 1 or len(set(tombstones.values())) > 1:
            mismatch_count += 1
            lines.append(f"- {fp}: payload={payload_hashes} timestamp={timestamps} tombstone={tombstones}")
    if mismatch_count == 0:
        lines.append("- none")
    lines.append("")

    lines.append("## TASK135 Residue")
    lines.append("")
    residue_count = 0
    for source in sources:
        residue = task_residue(by_source[source])
        residue_count += len(residue)
        lines.append(f"- {source}: {len(residue)}")
    if residue_count:
        lines.append("")
        for source in sources:
            for row in task_residue(by_source[source])[:20]:
                lines.append(f"- {source}: remote_id={row.get('remote_id')} local_id={row.get('local_id')} title={row.get('title')}")

    output = "\n".join(lines) + "\n"
    if args.output:
        Path(args.output).write_text(output)
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
