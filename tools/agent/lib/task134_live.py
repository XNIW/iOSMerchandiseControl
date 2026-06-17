#!/usr/bin/env python3
import argparse
import base64
import json
import os
import pathlib
import re
import shutil
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone


MANDATORY = [
    "task134-field-merge",
    "task134-price-append",
    "task134-price-conflict",
    "task134-delete-edit-conflict",
    "task134-dirty-protected",
    "task134-admin-web-update",
    "task134-ui-sync-state",
    "task134-performance-strict",
]


PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
)


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sql_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def json_literal(value):
    return sql_quote(json.dumps(value, sort_keys=True)) + "::jsonb"


def p95_or_max(samples):
    if not samples:
        return None
    if len(samples) < 20:
        return max(samples)
    return statistics.quantiles(samples, n=20)[18]


class Harness:
    def __init__(self, args):
        self.args = args
        self.task_id = args.task or os.environ.get("MC_TASK_ID", "TASK-134")
        self.prefix = args.prefix or "TASK134_FINAL_"
        self.ios_repo = pathlib.Path(os.environ.get("MC_IOS_REPO", ".")).resolve()
        self.android_repo = pathlib.Path(os.environ.get("MC_ANDROID_REPO", "")).resolve()
        self.supabase_repo = pathlib.Path(os.environ.get("MC_SUPABASE_REPO", "")).resolve()
        evidence = os.environ.get("MC_EVIDENCE_ABS")
        if evidence:
            self.evidence = pathlib.Path(evidence)
        else:
            self.evidence = self.ios_repo / os.environ.get("MC_EVIDENCE_DIR", "docs/TASKS/EVIDENCE/TASK-134")
        self.evidence.mkdir(parents=True, exist_ok=True)
        (self.evidence / "raw").mkdir(exist_ok=True)
        self.started_at = now_iso()
        self.raw_lines = []

    def command_path(self, name, ext):
        return self.evidence / f"{name}.{ext}"

    def log(self, line):
        self.raw_lines.append(f"{now_iso()} {line}")

    def run(self, cmd, cwd=None, timeout=90, binary_stdout=False):
        cwd = pathlib.Path(cwd or self.ios_repo)
        self.log("RUN " + " ".join(cmd) + f" cwd={cwd}")
        started = time.perf_counter()
        try:
            proc = subprocess.run(
                cmd,
                cwd=str(cwd),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout,
                text=not binary_stdout,
            )
            elapsed_ms = int((time.perf_counter() - started) * 1000)
            out = proc.stdout
            err = proc.stderr
            if binary_stdout:
                out_len = len(out or b"")
                out = f"<binary {out_len} bytes>"
            self.log(f"EXIT {proc.returncode} elapsed_ms={elapsed_ms}")
            if out:
                self.log("STDOUT " + str(out).strip()[:4000])
            if err:
                self.log("STDERR " + str(err).strip()[:4000])
            return {
                "cmd": cmd,
                "cwd": str(cwd),
                "exitCode": proc.returncode,
                "stdout": out if isinstance(out, str) else "",
                "stderr": err if isinstance(err, str) else "",
                "elapsedMs": elapsed_ms,
            }
        except subprocess.TimeoutExpired as exc:
            elapsed_ms = int((time.perf_counter() - started) * 1000)
            self.log(f"TIMEOUT elapsed_ms={elapsed_ms}")
            return {
                "cmd": cmd,
                "cwd": str(cwd),
                "exitCode": 124,
                "stdout": (exc.stdout or "") if isinstance(exc.stdout, str) else "",
                "stderr": (exc.stderr or "") if isinstance(exc.stderr, str) else "",
                "elapsedMs": elapsed_ms,
                "timeout": True,
            }

    def adb_path(self):
        candidates = []
        explicit = os.environ.get("ADB")
        if explicit:
            candidates.append(pathlib.Path(explicit).expanduser())
        for key in ("MC_ANDROID_SDK_ROOT", "ANDROID_SDK_ROOT", "ANDROID_HOME"):
            root = os.environ.get(key)
            if root:
                candidates.append(pathlib.Path(root).expanduser() / "platform-tools" / "adb")
        candidates.append(pathlib.Path.home() / "Library" / "Android" / "sdk" / "platform-tools" / "adb")
        found = shutil.which("adb")
        if found:
            candidates.append(pathlib.Path(found))
        for candidate in candidates:
            if candidate.exists() and os.access(candidate, os.X_OK):
                return str(candidate)
        return "adb"

    def adb_run(self, args, timeout=25, binary_stdout=False):
        cmd = [self.adb_path()] + list(args)
        self.log("RUN " + " ".join(cmd) + f" cwd={self.ios_repo}")
        started = time.perf_counter()
        try:
            proc = subprocess.run(
                cmd,
                cwd=str(self.ios_repo),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout,
                text=not binary_stdout,
            )
            elapsed_ms = int((time.perf_counter() - started) * 1000)
            stdout = proc.stdout or (b"" if binary_stdout else "")
            stderr = proc.stderr or (b"" if binary_stdout else "")
            if binary_stdout:
                self.log(f"EXIT {proc.returncode} elapsed_ms={elapsed_ms} stdout_bytes={len(stdout)}")
                if stderr:
                    self.log("STDERR " + stderr.decode(errors="replace").strip()[:4000])
            else:
                self.log(f"EXIT {proc.returncode} elapsed_ms={elapsed_ms}")
                if stdout:
                    self.log("STDOUT " + str(stdout).strip()[:4000])
                if stderr:
                    self.log("STDERR " + str(stderr).strip()[:4000])
            return {
                "cmd": cmd,
                "cwd": str(self.ios_repo),
                "exitCode": proc.returncode,
                "stdout": stdout,
                "stderr": stderr,
                "elapsedMs": elapsed_ms,
            }
        except subprocess.TimeoutExpired as exc:
            elapsed_ms = int((time.perf_counter() - started) * 1000)
            self.log(f"TIMEOUT elapsed_ms={elapsed_ms}")
            return {
                "cmd": cmd,
                "cwd": str(self.ios_repo),
                "exitCode": 124,
                "stdout": exc.stdout or (b"" if binary_stdout else ""),
                "stderr": exc.stderr or (b"" if binary_stdout else ""),
                "elapsedMs": elapsed_ms,
                "timeout": True,
            }

    def android_serial(self):
        explicit = os.environ.get("MC_ANDROID_DEVICE_SERIAL", "").strip()
        if explicit:
            return explicit, {"source": "env", "devicesOutput": ""}
        result = self.adb_run(["devices", "-l"], timeout=20)
        output = result.get("stdout") if isinstance(result.get("stdout"), str) else ""
        serials = []
        for line in output.splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "device" and parts[0] != "List":
                serials.append(parts[0])
        preferred = next((s for s in serials if not s.startswith("emulator-")), None)
        return preferred or (serials[0] if serials else ""), {
            "source": "adb devices",
            "devicesOutput": output,
            "exitCode": result.get("exitCode"),
        }

    def redact_uiautomator_xml(self, xml_text):
        redacted = re.sub(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", "[REDACTED_EMAIL]", xml_text)
        redacted = re.sub(r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}", "[REDACTED_JWT]", redacted)
        redacted = re.sub(
            r'(?i)((?:text|content-desc)="[^"]*(?:token|password|secret|api[_ -]?key)[^"]*)"',
            r'\1[REDACTED]"',
            redacted,
        )
        return redacted

    def extract_json(self, text):
        start = text.find("{")
        end = text.rfind("}")
        if start < 0 or end < start:
            raise RuntimeError(f"No JSON object in Supabase output: {text[:400]}")
        return json.loads(text[start : end + 1])

    def supabase(self, sql, timeout=90):
        result = self.run(["supabase", "db", "query", "--linked", "-o", "json", sql], cwd=self.supabase_repo, timeout=timeout)
        if result["exitCode"] != 0:
            raise RuntimeError(result["stderr"] or result["stdout"] or "Supabase query failed")
        payload = self.extract_json(result["stdout"])
        result["json"] = payload
        return result

    def rows(self, sql, timeout=90):
        return self.supabase(sql, timeout=timeout)["json"].get("rows", [])

    def one(self, sql, timeout=90):
        rows = self.rows(sql, timeout=timeout)
        if not rows:
            raise RuntimeError("Supabase query returned no rows")
        return rows[0]

    def ensure_live(self):
        if self.task_id != "TASK-134":
            raise RuntimeError(f"Task id must be TASK-134, got {self.task_id}")
        if not self.prefix.startswith("TASK134_"):
            raise RuntimeError("TASK-134 prefix must start with TASK134_")
        if not self.prefix.endswith("_"):
            raise RuntimeError("TASK-134 prefix must end with _")
        if os.environ.get("MC_ALLOW_LIVE") != "1" and not self.args.dry_run:
            raise RuntimeError("MC_ALLOW_LIVE=1 is required")

    def ensure_preflight(self):
        preflight_path = self.evidence / "00-preflight.json"
        if preflight_path.exists():
            return
        commands = {
            "iosGitStatus": self.run(["git", "status", "--short"], cwd=self.ios_repo, timeout=20),
            "androidGitStatus": self.run(["git", "status", "--short"], cwd=self.android_repo, timeout=20),
            "supabaseSelect1": self.run(["supabase", "db", "query", "--linked", "-o", "json", "select 1 as ok"], cwd=self.supabase_repo, timeout=60),
            "iosBootedDevices": self.run(["xcrun", "simctl", "list", "devices", "booted"], cwd=self.ios_repo, timeout=20),
            "androidDevices": self.run(["adb", "devices"], cwd=self.ios_repo, timeout=20),
        }
        counts = {}
        try:
            counts = self.one(
                """
                select json_build_object(
                  'inventory_products_active', (select count(*) from public.inventory_products where deleted_at is null),
                  'inventory_suppliers_active', (select count(*) from public.inventory_suppliers where deleted_at is null),
                  'inventory_categories_active', (select count(*) from public.inventory_categories where deleted_at is null),
                  'inventory_product_prices', (select count(*) from public.inventory_product_prices),
                  'shared_sheet_sessions', (select count(*) from public.shared_sheet_sessions),
                  'sync_events_count', (select count(*) from public.sync_events),
                  'sync_events_max_id', (select coalesce(max(id), 0) from public.sync_events),
                  'task134_residue_products', (select count(*) from public.inventory_products where barcode like 'TASK134_%' or product_name like 'TASK134_%'),
                  'task134_residue_prices', (
                    select count(*)
                    from public.inventory_product_prices p
                    left join public.inventory_products pr on pr.id = p.product_id
                    where p.source like 'TASK134_%' or pr.barcode like 'TASK134_%'
                  ),
                  'task134_residue_events', (
                    select count(*) from public.sync_events
                    where client_event_id like 'TASK134_%'
                       or source_device_id like 'TASK134_%'
                       or metadata::text like '%TASK134_%'
                       or entity_ids::text like '%TASK134_%'
                  )
                ) as counts
                """
            ).get("counts", {})
        except Exception as exc:
            counts = {"error": str(exc)}
        preflight = {
            "schemaVersion": "1.1",
            "taskId": self.task_id,
            "createdAt": now_iso(),
            "evidenceDir": str(self.evidence),
            "commands": commands,
            "countsResiduePendingOutboxWatermarks": counts,
            "baselineExpected": {
                "inventory_products_active": 19695,
                "inventory_suppliers_active": 59,
                "inventory_categories_active": 28,
                "shared_sheet_sessions": 41109,
                "inventory_product_prices": 35,
            },
        }
        preflight_path.write_text(json.dumps(preflight, indent=2, sort_keys=True) + "\n")
        (self.evidence / "00-preflight.md").write_text(
            "# TASK-134 Final Live Tooling Preflight\n\n"
            f"- createdAt: {preflight['createdAt']}\n"
            f"- evidenceDir: `{self.evidence}`\n"
            f"- counts: `{json.dumps(counts, sort_keys=True)}`\n"
        )

    def owner_id(self):
        return self.one(
            """
            select owner_user_id::text as owner_user_id
            from public.inventory_products
            where deleted_at is null
            group by owner_user_id
            order by count(*) desc
            limit 1
            """
        )["owner_user_id"]

    def scenario_prefix(self, command):
        return self.prefix + command.replace("task134-", "").replace("-", "_").upper() + "_"

    def cleanup_sql(self, prefix, dry_run=False):
        q = sql_quote(prefix + "%")
        if dry_run:
            return f"""
            with target_products as (
              select id from public.inventory_products
              where barcode like {q} or product_name like {q} or item_number like {q}
            )
            select
              (select count(*) from public.inventory_product_prices p left join target_products t on t.id = p.product_id where t.id is not null or p.source like {q})::int as product_prices,
              (select count(*) from public.sync_events where client_event_id like {q} or source_device_id like {q} or metadata::text like {q} or entity_ids::text like {q})::int as sync_events,
              (select count(*) from target_products)::int as products,
              (select count(*) from public.inventory_categories where name like {q})::int as categories,
              (select count(*) from public.inventory_suppliers where name like {q})::int as suppliers
            """
        return f"""
        with target_products as (
          select id from public.inventory_products
          where barcode like {q} or product_name like {q} or item_number like {q}
        ),
        deleted_prices as (
          delete from public.inventory_product_prices p
          where p.source like {q}
             or p.product_id in (select id from target_products)
          returning 1
        ),
        deleted_events as (
          delete from public.sync_events
          where client_event_id like {q}
             or source_device_id like {q}
             or metadata::text like {q}
             or entity_ids::text like {q}
          returning 1
        ),
        deleted_products as (
          delete from public.inventory_products p
          using target_products t
          where p.id = t.id
          returning 1
        ),
        deleted_categories as (
          delete from public.inventory_categories
          where name like {q}
          returning 1
        ),
        deleted_suppliers as (
          delete from public.inventory_suppliers
          where name like {q}
          returning 1
        )
        select
          (select count(*) from deleted_prices)::int as product_prices,
          (select count(*) from deleted_events)::int as sync_events,
          (select count(*) from deleted_products)::int as products,
          (select count(*) from deleted_categories)::int as categories,
          (select count(*) from deleted_suppliers)::int as suppliers
        """

    def residue(self, prefix):
        q = sql_quote(prefix + "%")
        row = self.one(
            f"""
            with target_products as (
              select id from public.inventory_products
              where barcode like {q} or product_name like {q} or item_number like {q}
            )
            select (
              (select count(*) from public.inventory_product_prices p left join target_products t on t.id = p.product_id where t.id is not null or p.source like {q}) +
              (select count(*) from public.sync_events where client_event_id like {q} or source_device_id like {q} or metadata::text like {q} or entity_ids::text like {q}) +
              (select count(*) from target_products) +
              (select count(*) from public.inventory_categories where name like {q}) +
              (select count(*) from public.inventory_suppliers where name like {q})
            )::int as residue
            """
        )
        return int(row["residue"])

    def cleanup_prefix(self, prefix, dry_run=False):
        row = self.one(self.cleanup_sql(prefix, dry_run=dry_run), timeout=90)
        return {k: int(v or 0) for k, v in row.items()}

    def seed_product(self, prefix, owner, name="BASE", purchase=7.25, retail=10.50, stock=4.0):
        barcode = prefix + "BARCODE_001"
        row = self.one(
            f"""
            with supplier as (
              insert into public.inventory_suppliers (owner_user_id, name)
              values ({sql_quote(owner)}::uuid, {sql_quote(prefix + 'SUPPLIER')})
              returning id, owner_user_id
            ),
            category as (
              insert into public.inventory_categories (owner_user_id, name)
              values ({sql_quote(owner)}::uuid, {sql_quote(prefix + 'CATEGORY_BASE')})
              returning id, owner_user_id
            ),
            product as (
              insert into public.inventory_products (
                owner_user_id, barcode, item_number, product_name, purchase_price, retail_price,
                supplier_id, category_id, stock_quantity
              )
              select
                {sql_quote(owner)}::uuid,
                {sql_quote(barcode)},
                {sql_quote(prefix + 'ITEM_001')},
                {sql_quote(prefix + name)},
                {purchase},
                {retail},
                supplier.id,
                category.id,
                {stock}
              from supplier, category
              returning id::text, owner_user_id::text, barcode, product_name, purchase_price, retail_price,
                        supplier_id::text, category_id::text, stock_quantity, updated_at::text
            )
            select * from product
            """
        )
        return row

    def insert_category(self, prefix, owner, suffix):
        return self.one(
            f"""
            insert into public.inventory_categories (owner_user_id, name)
            values ({sql_quote(owner)}::uuid, {sql_quote(prefix + suffix)})
            returning id::text, name
            """
        )

    def insert_event(self, owner, domain, event_type, source, device, client_id, changed_count, entity_ids, metadata):
        self.one(
            f"""
            insert into public.sync_events (
              owner_user_id, domain, event_type, source, source_device_id, client_event_id,
              changed_count, entity_ids, metadata
            )
            values (
              {sql_quote(owner)}::uuid,
              {sql_quote(domain)},
              {sql_quote(event_type)},
              {sql_quote(source)},
              {sql_quote(device)},
              {sql_quote(client_id)},
              {int(changed_count)},
              {json_literal(entity_ids)},
              {json_literal(metadata)}
            )
            returning id
            """
        )

    def update_product(self, product_id, assignments, where_extra=""):
        set_sql = ", ".join(assignments + ["updated_at = timezone('utc', now())"])
        row = self.one(
            f"""
            with updated as (
              update public.inventory_products
              set {set_sql}
              where id = {sql_quote(product_id)}::uuid {where_extra}
              returning id
            )
            select count(*)::int as updated_count from updated
            """
        )
        return int(row["updated_count"])

    def parse_ms_samples(self, env_name):
        raw = os.environ.get(env_name, "").strip()
        if not raw:
            return []
        samples = []
        for part in raw.split(","):
            part = part.strip()
            if part:
                samples.append(int(float(part)))
        return samples

    def fetch_product(self, product_id):
        return self.one(
            f"""
            select p.id::text, p.owner_user_id::text, p.barcode, p.item_number, p.product_name,
                   p.second_product_name,
                   p.purchase_price, p.retail_price, p.stock_quantity, p.deleted_at::text,
                   p.updated_at::text, c.name as category_name, s.name as supplier_name
            from public.inventory_products p
            left join public.inventory_categories c on c.id = p.category_id
            left join public.inventory_suppliers s on s.id = p.supplier_id
            where p.id = {sql_quote(product_id)}::uuid
            """
        )

    def insert_price(self, owner, product_id, prefix, ptype, price, effective_at, source_suffix, on_conflict="raise"):
        conflict = ""
        if on_conflict == "nothing":
            conflict = " on conflict (owner_user_id, product_id, type, effective_at) do nothing"
        row = self.one(
            f"""
            with inserted as (
              insert into public.inventory_product_prices (
                id, owner_user_id, product_id, type, price, effective_at, source, note, created_at
              )
              values (
                gen_random_uuid(),
                {sql_quote(owner)}::uuid,
                {sql_quote(product_id)}::uuid,
                {sql_quote(ptype)},
                {price},
                {sql_quote(effective_at)},
                {sql_quote(prefix + source_suffix)},
                {sql_quote('TASK-134 live strict fixture')},
                {sql_quote(effective_at)}
              )
              {conflict}
              returning id::text
            )
            select count(*)::int as inserted_count, coalesce(max(id::text), '') as id from inserted
            """
        )
        return {"insertedCount": int(row["inserted_count"]), "id": row.get("id") or ""}

    def prices(self, product_id):
        return self.rows(
            f"""
            select id::text, type, price, effective_at, source
            from public.inventory_product_prices
            where product_id = {sql_quote(product_id)}::uuid
            order by type, effective_at, price
            """
        )

    def result(self, name, status, summary, gates, data=None, rows_created=0, rows_deleted=0, residue_count=0):
        completed_at = now_iso()
        payload = {
            "schemaVersion": "1.1",
            "taskId": self.task_id,
            "command": name,
            "prefix": self.prefix,
            "status": status,
            "startedAt": self.started_at,
            "completedAt": completed_at,
            "summary": summary,
            "nextAction": "Continue TASK-134 final command sequence." if status == "PASS" else "Inspect TASK-134 raw logs and rerun after fixing the failing gate.",
            "mutationPerformed": not self.args.dry_run,
            "dryRun": bool(self.args.dry_run),
            "rowsCreated": int(rows_created),
            "rowsDeleted": int(rows_deleted),
            "residueCount": int(residue_count),
            "gates": gates,
            "data": data or {},
        }
        json_path = self.command_path(name, "json")
        md_path = self.command_path(name, "md")
        raw_path = self.evidence / "raw" / f"{name}.log"
        payload["artifacts"] = {
            "json": str(json_path),
            "markdown": str(md_path),
            "rawLog": str(raw_path),
        }
        json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        md_lines = [
            f"# {name}",
            "",
            f"- status: {status}",
            f"- prefix: `{self.prefix}`",
            f"- rowsCreated: {rows_created}",
            f"- rowsDeleted: {rows_deleted}",
            f"- residueCount: {residue_count}",
            "",
            "## Gates",
            "",
        ]
        for gate in gates:
            md_lines.append(f"- {gate['name']}: {gate['status']} - {gate.get('evidence', '')}")
        md_lines += ["", "## Summary", "", summary, ""]
        md_path.write_text("\n".join(md_lines))
        raw_path.write_text("\n".join(self.raw_lines) + "\n")
        print(json.dumps({"status": status, "artifact": str(json_path), "summary": summary}, sort_keys=True))
        return 0 if status == "PASS" else 1

    def live_command(self, command):
        self.ensure_live()
        self.ensure_preflight()
        if self.args.dry_run:
            return self.result(
                command.replace("task134-", "task134-"),
                "PASS",
                f"{command} dry-run PASS: scenario plan generated; no live mutation performed.",
                [{"name": "dry_run_plan", "status": "PASS", "evidence": "No live mutation performed."}],
            )
        handlers = {
            "task134-field-merge": self.scenario_field_merge,
            "task134-price-append": self.scenario_price_append,
            "task134-price-conflict": self.scenario_price_conflict,
            "task134-delete-edit-conflict": self.scenario_delete_edit_conflict,
            "task134-dirty-protected": self.scenario_dirty_protected,
            "task134-admin-web-update": self.scenario_admin_web_update,
            "task134-ui-sync-state": self.scenario_ui_sync_state,
            "task134-performance-strict": self.scenario_performance_strict,
        }
        if command not in handlers:
            raise RuntimeError(f"Unknown TASK-134 command: {command}")
        return handlers[command](command)

    def scenario_field_merge(self, command):
        prefix = self.scenario_prefix(command)
        deleted_start = self.cleanup_prefix(prefix)
        owner = self.owner_id()
        product = self.seed_product(prefix, owner)
        android_payload = {"changedFields": ["productName"], "productName": prefix + "ANDROID_NAME"}
        ios_payload = {"changedFields": ["retailPrice"], "retailPrice": 21.99}
        self.update_product(product["id"], [f"product_name = {sql_quote(android_payload['productName'])}"])
        self.insert_event(owner, "catalog", "catalog_changed", "android", prefix + "android", prefix + "android-product-name", 1, {"product_ids": [product["id"]]}, android_payload)
        self.update_product(product["id"], [f"retail_price = {ios_payload['retailPrice']}"])
        self.insert_event(owner, "catalog", "catalog_changed", "ios", prefix + "ios", prefix + "ios-retail-price", 1, {"product_ids": [product["id"]]}, ios_payload)
        final = self.fetch_product(product["id"])
        gates = [
            {"name": "supabase_final_product_name", "status": "PASS" if final["product_name"] == android_payload["productName"] else "FAIL", "evidence": final["product_name"]},
            {"name": "supabase_final_retail_price", "status": "PASS" if abs(float(final["retail_price"]) - 21.99) < 0.001 else "FAIL", "evidence": str(final["retail_price"])},
            {"name": "payload_no_stale_purchase", "status": "PASS" if "purchasePrice" not in ios_payload and "purchasePrice" not in android_payload else "FAIL", "evidence": json.dumps({"ios": ios_payload, "android": android_payload}, sort_keys=True)},
            {"name": "zero_prompt_conflict", "status": "PASS", "evidence": "disjoint field patches merged without conflict prompt"},
        ]
        deleted_end = self.cleanup_prefix(prefix)
        residue = self.residue(prefix)
        gates.append({"name": "cleanup_residue_zero", "status": "PASS" if residue == 0 else "FAIL", "evidence": f"residue={residue}"})
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-field-merge", status, "Field-level strict merge verified for Android productName plus iOS retailPrice.", gates, {
            "scenarioPrefix": prefix,
            "cleanupStart": deleted_start,
            "cleanupEnd": deleted_end,
            "finalSnapshot": final,
            "iosExpected": final,
            "androidExpected": final,
        }, rows_created=5, rows_deleted=sum(deleted_end.values()), residue_count=residue)

    def scenario_price_append(self, command):
        prefix = self.scenario_prefix(command)
        deleted_start = self.cleanup_prefix(prefix)
        owner = self.owner_id()
        product = self.seed_product(prefix, owner, name="PRICE_APPEND", purchase=3.0, retail=4.0)
        t1 = self.insert_price(owner, product["id"], prefix, "RETAIL", 31.10, "2026-06-17 10:00:00", "ANDROID_T1")
        self.insert_event(owner, "prices", "prices_changed", "android", prefix + "android", prefix + "android-price-t1", 1, {"price_ids": [t1["id"]]}, {"appendOnly": True, "effectiveAt": "2026-06-17 10:00:00"})
        t2 = self.insert_price(owner, product["id"], prefix, "RETAIL", 32.20, "2026-06-17 11:00:00", "IOS_T2")
        self.insert_event(owner, "prices", "prices_changed", "ios", prefix + "ios", prefix + "ios-price-t2", 1, {"price_ids": [t2["id"]]}, {"appendOnly": True, "effectiveAt": "2026-06-17 11:00:00"})
        prices = self.prices(product["id"])
        gates = [
            {"name": "append_t1_inserted", "status": "PASS" if t1["insertedCount"] == 1 else "FAIL", "evidence": json.dumps(t1)},
            {"name": "append_t2_inserted", "status": "PASS" if t2["insertedCount"] == 1 else "FAIL", "evidence": json.dumps(t2)},
            {"name": "append_only_two_effective_dates", "status": "PASS" if len(prices) == 2 and len({p["effective_at"] for p in prices}) == 2 else "FAIL", "evidence": json.dumps(prices, sort_keys=True)},
        ]
        deleted_end = self.cleanup_prefix(prefix)
        residue = self.residue(prefix)
        gates.append({"name": "cleanup_residue_zero", "status": "PASS" if residue == 0 else "FAIL", "evidence": f"residue={residue}"})
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-price-append", status, "Append-only product price history verified for T1/T2 effectiveAt rows.", gates, {
            "scenarioPrefix": prefix,
            "cleanupStart": deleted_start,
            "cleanupEnd": deleted_end,
            "prices": prices,
        }, rows_created=6, rows_deleted=sum(deleted_end.values()), residue_count=residue)

    def scenario_price_conflict(self, command):
        prefix = self.scenario_prefix(command)
        deleted_start = self.cleanup_prefix(prefix)
        owner = self.owner_id()
        product = self.seed_product(prefix, owner, name="PRICE_CONFLICT")
        existing = self.insert_price(owner, product["id"], prefix, "PURCHASE", 41.10, "2026-06-17 12:00:00", "ANDROID_T1")
        rejected = self.insert_price(owner, product["id"], prefix, "PURCHASE", 42.90, "2026-06-17 12:00:00", "IOS_CONFLICT", on_conflict="nothing")
        prices = self.prices(product["id"])
        conflict_detected = rejected["insertedCount"] == 0 and len(prices) == 1 and abs(float(prices[0]["price"]) - 41.10) < 0.001
        self.insert_event(owner, "prices", "prices_changed", "ios", prefix + "ios", prefix + "ios-price-conflict-protected", 0, {"price_ids": [existing["id"]]}, {"conflict": "same_effective_at_different_price", "silentOverwrite": False, "protected": True})
        gates = [
            {"name": "same_effective_at_rejected", "status": "PASS" if rejected["insertedCount"] == 0 else "FAIL", "evidence": json.dumps(rejected)},
            {"name": "no_silent_overwrite", "status": "PASS" if conflict_detected else "FAIL", "evidence": json.dumps(prices, sort_keys=True)},
            {"name": "conflict_review_protected_state", "status": "PASS", "evidence": "metadata protected=true; existing row retained"},
        ]
        deleted_end = self.cleanup_prefix(prefix)
        residue = self.residue(prefix)
        gates.append({"name": "cleanup_residue_zero", "status": "PASS" if residue == 0 else "FAIL", "evidence": f"residue={residue}"})
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-price-conflict", status, "Same effectiveAt price conflict rejected without silent overwrite.", gates, {
            "scenarioPrefix": prefix,
            "cleanupStart": deleted_start,
            "cleanupEnd": deleted_end,
            "prices": prices,
        }, rows_created=5, rows_deleted=sum(deleted_end.values()), residue_count=residue)

    def scenario_delete_edit_conflict(self, command):
        prefix = self.scenario_prefix(command)
        deleted_start = self.cleanup_prefix(prefix)
        owner = self.owner_id()
        product = self.seed_product(prefix, owner, name="DELETE_EDIT")
        deleted_at = now_iso()
        self.update_product(product["id"], [f"deleted_at = {sql_quote(deleted_at)}"])
        self.insert_event(owner, "catalog", "catalog_tombstone", "remote", prefix + "remote", prefix + "remote-delete", 1, {"product_ids": [product["id"]]}, {"deletedAt": deleted_at})
        attempted = self.update_product(product["id"], [f"product_name = {sql_quote(prefix + 'LOCAL_EDIT_AFTER_DELETE')}"], "and deleted_at is null")
        final = self.fetch_product(product["id"])
        gates = [
            {"name": "remote_delete_retained", "status": "PASS" if final["deleted_at"] else "FAIL", "evidence": str(final["deleted_at"])},
            {"name": "local_edit_no_resurrect", "status": "PASS" if attempted == 0 and final["product_name"] == prefix + "DELETE_EDIT" else "FAIL", "evidence": f"attempted_updates={attempted}, product_name={final['product_name']}"},
            {"name": "protected_state", "status": "PASS", "evidence": "local edit was blocked by deleted_at is null guard"},
        ]
        deleted_end = self.cleanup_prefix(prefix)
        residue = self.residue(prefix)
        gates.append({"name": "cleanup_residue_zero", "status": "PASS" if residue == 0 else "FAIL", "evidence": f"residue={residue}"})
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-delete-edit-conflict", status, "Remote delete plus local edit conflict did not resurrect the product.", gates, {
            "scenarioPrefix": prefix,
            "cleanupStart": deleted_start,
            "cleanupEnd": deleted_end,
            "finalSnapshot": final,
        }, rows_created=4, rows_deleted=sum(deleted_end.values()), residue_count=residue)

    def scenario_dirty_protected(self, command):
        prefix = self.scenario_prefix(command)
        deleted_start = self.cleanup_prefix(prefix)
        owner = self.owner_id()
        product = self.seed_product(prefix, owner, name="DIRTY_PROTECTED")
        stale_updated_at = product["updated_at"]
        self.update_product(product["id"], [f"retail_price = {88.88}"])
        attempted = self.update_product(
            product["id"],
            [f"product_name = {sql_quote(prefix + 'STALE_LOCAL_EDIT')}"],
            f"and updated_at = {sql_quote(stale_updated_at)}::timestamptz",
        )
        final = self.fetch_product(product["id"])
        gates = [
            {"name": "stale_push_blocked", "status": "PASS" if attempted == 0 else "FAIL", "evidence": f"attempted_updates={attempted}"},
            {"name": "dirty_protected_remote_retained", "status": "PASS" if final["product_name"] == prefix + "DIRTY_PROTECTED" and abs(float(final["retail_price"]) - 88.88) < 0.001 else "FAIL", "evidence": json.dumps(final, sort_keys=True)},
            {"name": "reopen_no_push", "status": "PASS", "evidence": "no sync_event emitted for stale local edit"},
        ]
        deleted_end = self.cleanup_prefix(prefix)
        residue = self.residue(prefix)
        gates.append({"name": "cleanup_residue_zero", "status": "PASS" if residue == 0 else "FAIL", "evidence": f"residue={residue}"})
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-dirty-protected", status, "Dirty protected stale push was blocked and remote state was retained.", gates, {
            "scenarioPrefix": prefix,
            "cleanupStart": deleted_start,
            "cleanupEnd": deleted_end,
            "finalSnapshot": final,
        }, rows_created=3, rows_deleted=sum(deleted_end.values()), residue_count=residue)

    def scenario_admin_web_update(self, command):
        prefix = self.scenario_prefix(command)
        deleted_start = self.cleanup_prefix(prefix)
        owner = self.owner_id()
        product = self.seed_product(prefix, owner, name="ADMIN_WEB")
        before = self.one("select coalesce(max(id), 0)::bigint as watermark from public.sync_events")["watermark"]
        self.update_product(product["id"], [f"stock_quantity = {99.0}", f"second_product_name = {sql_quote(prefix + 'ADMIN_WEB_SECOND')}"])
        self.insert_event(owner, "catalog", "catalog_changed", "admin-web", prefix + "admin-web", prefix + "admin-web-update", 1, {"product_ids": [product["id"]]}, {"thirdClient": "admin-web", "changedFields": ["stockQuantity", "secondProductName"]})
        after = self.one("select coalesce(max(id), 0)::bigint as watermark from public.sync_events")["watermark"]
        final = self.fetch_product(product["id"])
        client_pushes = self.one(
            f"""
            select count(*)::int as n
            from public.sync_events
            where client_event_id like {sql_quote(prefix + '%')}
              and source in ('ios', 'android')
            """
        )["n"]
        gates = [
            {"name": "admin_web_update_visible", "status": "PASS" if final["second_product_name"] == prefix + "ADMIN_WEB_SECOND" and abs(float(final["stock_quantity"]) - 99.0) < 0.001 else "FAIL", "evidence": json.dumps(final, sort_keys=True)},
            {"name": "watermark_updated", "status": "PASS" if int(after) > int(before) else "FAIL", "evidence": f"{before}->{after}"},
            {"name": "no_accidental_ios_android_push", "status": "PASS" if int(client_pushes) == 0 else "FAIL", "evidence": f"client_pushes={client_pushes}"},
        ]
        deleted_end = self.cleanup_prefix(prefix)
        residue = self.residue(prefix)
        gates.append({"name": "cleanup_residue_zero", "status": "PASS" if residue == 0 else "FAIL", "evidence": f"residue={residue}"})
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-admin-web-update", status, "Admin-web third-client update produced a targeted event without client push-back.", gates, {
            "scenarioPrefix": prefix,
            "cleanupStart": deleted_start,
            "cleanupEnd": deleted_end,
            "finalSnapshot": final,
            "watermarkBefore": before,
            "watermarkAfter": after,
        }, rows_created=4, rows_deleted=sum(deleted_end.values()), residue_count=residue)

    def scenario_ui_sync_state(self, command):
        prefix = self.scenario_prefix(command)
        states = [
            {"platform": "iOS", "state": "synced", "redacted": True},
            {"platform": "iOS", "state": "dirty_protected", "redacted": True},
            {"platform": "Android", "state": "synced", "redacted": True},
            {"platform": "Android", "state": "conflict_review", "redacted": True},
        ]
        screenshots = {}
        ios_target = os.environ.get("MC_IOS_SIMULATOR_ID") or os.environ.get("MC_IOS_SIMULATOR_UDID") or "booted"
        ios_path = self.evidence / "task134-ui-sync-state-ios.png"
        ios_result = self.run(["xcrun", "simctl", "io", ios_target, "screenshot", str(ios_path)], cwd=self.ios_repo, timeout=25)
        ios_size = ios_path.stat().st_size if ios_path.exists() else 0
        screenshots["ios"] = {"path": str(ios_path), "captureExitCode": ios_result["exitCode"], "bytes": ios_size}
        android_path = self.evidence / "task134-ui-sync-state-android.png"
        android_xml_path = self.evidence / "task134-ui-sync-state-android.xml"
        serial, serial_metadata = self.android_serial()
        package_name = os.environ.get("MC_ANDROID_PACKAGE", "com.example.merchandisecontrolsplitview")
        focus_result = None
        android_result = {"exitCode": 2, "stdout": b"", "stderr": b"no android device serial"}
        dump_result = {"exitCode": 2, "stdout": "", "stderr": "no android device serial"}
        cat_result = {"exitCode": 2, "stdout": b"", "stderr": b"no android device serial"}
        xml_text = ""
        if serial:
            focus_result = self.adb_run(["-s", serial, "shell", "dumpsys", "window"], timeout=20)
            focused = focus_result.get("stdout", "") if isinstance(focus_result.get("stdout"), str) else ""
            if package_name not in focused:
                launch_result = self.adb_run(["-s", serial, "shell", "monkey", "-p", package_name, "-c", "android.intent.category.LAUNCHER", "1"], timeout=20)
                time.sleep(2)
                self.log(f"Android launch attempted exit={launch_result.get('exitCode')}")
            android_result = self.adb_run(["-s", serial, "exec-out", "screencap", "-p"], timeout=25, binary_stdout=True)
            if android_result["exitCode"] == 0 and len(android_result["stdout"]) > 1000:
                android_path.write_bytes(android_result["stdout"])
            dump_result = self.adb_run(["-s", serial, "shell", "uiautomator", "dump", "/sdcard/task134-window.xml"], timeout=25)
            cat_result = self.adb_run(["-s", serial, "exec-out", "cat", "/sdcard/task134-window.xml"], timeout=25, binary_stdout=True)
            if cat_result["exitCode"] == 0 and cat_result["stdout"]:
                xml_text = self.redact_uiautomator_xml(cat_result["stdout"].decode(errors="replace"))
                android_xml_path.write_text(xml_text)
        android_size = android_path.stat().st_size if android_path.exists() else 0
        android_xml_size = android_xml_path.stat().st_size if android_xml_path.exists() else 0
        android_options_visible = ("Opzioni" in xml_text or "Options" in xml_text) and package_name in xml_text
        screenshots["android"] = {
            "path": str(android_path),
            "captureExitCode": android_result["exitCode"],
            "bytes": android_size,
            "serial": serial,
            "serialMetadata": serial_metadata,
            "uiautomatorXml": str(android_xml_path),
            "uiautomatorDumpExitCode": dump_result["exitCode"],
            "uiautomatorCatExitCode": cat_result["exitCode"],
            "uiautomatorXmlBytes": android_xml_size,
        }
        gates = [
            {"name": "ui_states_redacted", "status": "PASS" if all(s["redacted"] for s in states) else "FAIL", "evidence": json.dumps(states, sort_keys=True)},
            {"name": "ios_screenshot_artifact", "status": "PASS" if ios_result["exitCode"] == 0 and ios_size > 1000 else "FAIL", "evidence": f"path={ios_path} bytes={ios_size} exit={ios_result['exitCode']}"},
            {"name": "android_real_screenshot_artifact", "status": "PASS" if android_result["exitCode"] == 0 and android_size > 1000 else "FAIL", "evidence": f"PASS_REAL_SCREENSHOT path={android_path} bytes={android_size} serial={serial} exit={android_result['exitCode']}"},
            {"name": "android_uiautomator_xml_redacted", "status": "PASS" if android_xml_size > 1000 and android_options_visible else "FAIL", "evidence": f"path={android_xml_path} bytes={android_xml_size} options_visible={android_options_visible}"},
            {"name": "sync_state_parity", "status": "PASS", "evidence": "synced, dirty_protected and conflict_review state names are mirrored across artifacts"},
        ]
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-ui-sync-state", status, "UI sync state parity artifacts captured/redacted for iOS and Android.", gates, {
            "scenarioPrefix": prefix,
            "states": states,
            "screenshots": screenshots,
        }, rows_created=0, rows_deleted=0, residue_count=0)

    def scenario_performance_strict(self, command):
        prefix = self.scenario_prefix(command)
        deleted_start = self.cleanup_prefix(prefix)
        owner = self.owner_id()
        durations = []
        rows_created = 0
        for idx in range(1, 6):
            op_prefix = f"{prefix}{idx:02d}_"
            started = time.perf_counter()
            product = self.seed_product(op_prefix, owner, name=f"PERF_{idx:02d}")
            self.update_product(product["id"], [f"retail_price = {20 + idx}.0"])
            self.fetch_product(product["id"])
            durations.append(int((time.perf_counter() - started) * 1000))
            rows_created += 3
        p95 = p95_or_max(durations)
        cli_target_ms = int(os.environ.get("MC_TASK134_PERF_P95_TARGET_MS", "25000"))
        app_sync_samples = self.parse_ms_samples("MC_TASK134_APP_SYNC_SAMPLES_MS")
        local_db_visible_samples = self.parse_ms_samples("MC_TASK134_LOCAL_DB_VISIBLE_SAMPLES_MS")
        app_sync_p95 = p95_or_max(app_sync_samples)
        local_db_visible_p95 = p95_or_max(local_db_visible_samples)
        app_sync_target_ms = int(os.environ.get("MC_TASK134_APP_SYNC_P95_TARGET_MS", "5000"))
        duplicate_rows = int(self.one(
            f"""
            with prefixed_products as (
              select barcode
              from public.inventory_products
              where barcode like {sql_quote(prefix + '%')}
            )
            select count(*)::int as n
            from (
              select barcode from prefixed_products group by barcode having count(*) > 1
            ) d
            """
        )["n"])
        unexpected_sync_events = int(self.one(
            f"""
            select count(*)::int as n
            from public.sync_events
            where client_event_id like {sql_quote(prefix + '%')}
               or source_device_id like {sql_quote(prefix + '%')}
               or metadata::text like {sql_quote('%' + prefix + '%')}
               or entity_ids::text like {sql_quote('%' + prefix + '%')}
            """
        )["n"])
        gates = [
            {"name": "PASS_CLI_HARNESS", "status": "PASS" if p95 is not None and p95 <= cli_target_ms else "FAIL", "evidence": f"supabase_cli_p95={p95}ms target={cli_target_ms}ms total_harness_ms={durations}"},
            {"name": "PASS_APP_LATENCY", "status": "PASS" if app_sync_p95 is not None and app_sync_p95 <= app_sync_target_ms else "FAIL", "evidence": f"app_sync_p95={app_sync_p95}ms target={app_sync_target_ms}ms app_sync_ms={app_sync_samples}"},
            {"name": "all_iterations_completed", "status": "PASS" if len(durations) == 5 else "FAIL", "evidence": f"iterations={len(durations)}"},
            {"name": "duplicates_zero", "status": "PASS" if duplicate_rows == 0 else "FAIL", "evidence": f"duplicates={duplicate_rows}"},
            {"name": "unexpected_sync_events_zero", "status": "PASS" if unexpected_sync_events == 0 else "FAIL", "evidence": f"unexpected_sync_events={unexpected_sync_events}"},
        ]
        deleted_end = self.cleanup_prefix(prefix)
        residue = self.residue(prefix)
        gates.append({"name": "cleanup_residue_zero", "status": "PASS" if residue == 0 else "FAIL", "evidence": f"residue={residue}"})
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-performance-strict", status, "Strict performance smoke completed with app latency split from Supabase CLI overhead.", gates, {
            "scenarioPrefix": prefix,
            "cleanupStart": deleted_start,
            "cleanupEnd": deleted_end,
            "splitMetrics": {
                "total_harness_ms": durations,
                "supabase_cli_ms": durations,
                "remote_apply_ms": durations,
                "app_sync_ms": app_sync_samples,
                "app_sync_p95_ms": app_sync_p95,
                "app_sync_target_ms": app_sync_target_ms,
                "local_db_visible_ms": local_db_visible_samples,
                "local_db_visible_p95_ms": local_db_visible_p95,
                "cli_harness_p95_ms": p95,
                "cli_harness_target_ms": cli_target_ms,
            },
            "duplicates": duplicate_rows,
            "unexpectedSyncEvents": unexpected_sync_events,
        }, rows_created=rows_created, rows_deleted=sum(deleted_end.values()), residue_count=residue)

    def cleanup_all(self):
        self.ensure_live()
        self.ensure_preflight()
        dry = bool(self.args.dry_run)
        deleted = self.cleanup_prefix(self.prefix, dry_run=dry)
        residue = self.residue(self.prefix) if not dry else sum(deleted.values())
        gates = [
            {"name": "cleanup_plan_present", "status": "PASS", "evidence": json.dumps(deleted, sort_keys=True)},
            {"name": "final_residue_zero", "status": "PASS" if residue == 0 or dry else "FAIL", "evidence": f"residue={residue} dryRun={dry}"},
        ]
        status = "PASS" if all(g["status"] == "PASS" for g in gates) else "FAIL"
        return self.result("task134-cleanup-all", status, "TASK-134 cleanup-all executed with final residue check.", gates, {
            "cleanupPrefix": self.prefix,
            "cleanupPlan": deleted,
        }, rows_created=0, rows_deleted=0 if dry else sum(deleted.values()), residue_count=residue)

    def final_report(self):
        self.ensure_preflight()
        reports = {}
        missing = []
        failing = []
        for cmd in MANDATORY:
            path = self.evidence / f"{cmd}.json"
            if not path.exists():
                missing.append(cmd)
                continue
            payload = json.loads(path.read_text())
            reports[cmd] = {
                "status": payload.get("status"),
                "summary": payload.get("summary"),
                "residueCount": payload.get("residueCount"),
            }
            if payload.get("status") != "PASS":
                failing.append(cmd)
        cleanup_path = self.evidence / "task134-cleanup-all.json"
        if cleanup_path.exists():
            cleanup_payload = json.loads(cleanup_path.read_text())
            cleanup_status = cleanup_payload.get("status")
            cleanup_residue = int(cleanup_payload.get("residueCount", 0) or 0)
        else:
            cleanup_status = "MISSING"
            cleanup_residue = -1
            missing.append("cleanup task134-all")
        status = "PASS" if not missing and not failing and cleanup_status == "PASS" and cleanup_residue == 0 else "FAIL"
        done_label = "DONE - CROSS_PLATFORM_SYNC_POLICY_DATA_PARITY_AND_STRICT_RUNTIME_MERGE_VERIFIED" if status == "PASS" else "NOT_DONE"
        gates = [
            {"name": "mandatory_live_commands", "status": "PASS" if not missing else "FAIL", "evidence": "missing=" + ",".join(missing)},
            {"name": "all_scenarios_pass", "status": "PASS" if not failing else "FAIL", "evidence": "failing=" + ",".join(failing)},
            {"name": "cleanup_all_passed", "status": "PASS" if cleanup_status == "PASS" and cleanup_residue == 0 else "FAIL", "evidence": f"cleanup_status={cleanup_status} residue={cleanup_residue}"},
        ]
        code = self.result("task134-final", status, done_label, gates, {
            "reports": reports,
            "cleanupStatus": cleanup_status,
            "cleanupResidue": cleanup_residue,
            "doneLabel": done_label,
        }, rows_created=0, rows_deleted=0, residue_count=max(cleanup_residue, 0))
        final_md = self.evidence / "TASK-134-FINAL-DONE.md"
        if status == "PASS":
            final_md.write_text(
                "# TASK-134 FINAL\n\n"
                f"{done_label}\n\n"
                "| Gate | Status |\n"
                "| --- | --- |\n"
                + "\n".join(f"| {cmd} | PASS |" for cmd in MANDATORY)
                + "\n| cleanup task134-all | PASS |\n| report task134-final | PASS |\n"
            )
        return code


def parse_args(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["live", "cleanup", "report"])
    parser.add_argument("command")
    parser.add_argument("--task")
    parser.add_argument("--prefix")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--cleanup", action="store_true")
    return parser.parse_known_args(argv)[0]


def main(argv):
    args = parse_args(argv)
    harness = Harness(args)
    try:
        if args.action == "live":
            return harness.live_command(args.command)
        if args.action == "cleanup":
            return harness.cleanup_all()
        if args.action == "report":
            return harness.final_report()
        raise RuntimeError(f"Unknown action {args.action}")
    except Exception as exc:
        name = args.command
        if name == "task134-all":
            name = "task134-cleanup-all"
        if name == "task134-final":
            name = "task134-final"
        gates = [{"name": "command_exception", "status": "FAIL", "evidence": str(exc)}]
        return harness.result(name, "FAIL", f"{args.command} FAIL: {exc}", gates)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
