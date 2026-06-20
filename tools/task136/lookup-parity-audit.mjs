#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const adminRoot =
  process.env.TASK136_ADMIN_WEB_ROOT ||
  "/Users/minxiang/Projects/merchandise-control-admin-web";
const envPath = join(adminRoot, ".env.local");
const selectedShopId = process.argv[2] || process.env.TASK136_SHOP_ID;
const outputPath =
  process.argv[3] ||
  "docs/TASKS/EVIDENCE/TASK-136/live-audit/lookup-parity-audit.json";

if (!selectedShopId) {
  fail("Usage: node tools/task136/lookup-parity-audit.mjs <shop_id> [output_json]");
}

function fail(message) {
  console.error(`[task136-lookup-parity] ${message}`);
  process.exit(2);
}

function parseEnv(path) {
  if (!existsSync(path)) fail(`Missing env file: ${path}`);
  const values = {};
  for (const raw of readFileSync(path, "utf8").split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) continue;
    const index = line.indexOf("=");
    const key = line.slice(0, index).trim();
    let value = line.slice(index + 1).trim();
    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }
  return values;
}

function hash12(value) {
  if (!value) return null;
  return createHash("md5").update(String(value)).digest("hex").slice(0, 12);
}

function redactRef(value) {
  return value ? `${value.slice(0, 4)}...${value.slice(-3)}` : "unknown";
}

function refFromUrl(value) {
  return new URL(value).hostname.split(".")[0] || "unknown";
}

function remoteKey(value) {
  return String(value || "").toLowerCase().replaceAll("-", "");
}

function normalizeName(value) {
  return String(value || "")
    .trim()
    .toLocaleLowerCase("en-US")
    .replace(/\s+/g, " ");
}

function safeName(value) {
  const text = String(value || "").trim();
  if (!text) return "";
  return /^[\p{L}\p{N} .,'&()/_-]{1,80}$/u.test(text) ? text : hash12(text);
}

function parseCsv(path) {
  if (!existsSync(path)) return [];
  const text = readFileSync(path, "utf8").trim();
  if (!text) return [];
  const [headerLine, ...lines] = text.split(/\r?\n/);
  const headers = parseCsvLine(headerLine);
  return lines.filter(Boolean).map((line) => {
    const values = parseCsvLine(line);
    return Object.fromEntries(headers.map((header, index) => [header, values[index] || ""]));
  });
}

function parseCsvLine(line) {
  const values = [];
  let current = "";
  let inQuotes = false;
  for (let index = 0; index < line.length; index += 1) {
    const char = line[index];
    if (char === "\"") {
      if (inQuotes && line[index + 1] === "\"") {
        current += "\"";
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === "," && !inQuotes) {
      values.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  values.push(current);
  return values;
}

function buildUrl(table, params = []) {
  const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
  for (const [key, value] of params) url.searchParams.append(key, value);
  return url;
}

async function rest(table, params = [], options = {}) {
  const response = await fetch(buildUrl(table, params), {
    method: options.method || "GET",
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      accept: "application/json",
      prefer: options.prefer || "count=exact",
      ...(options.range ? { range: options.range } : {}),
    },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`${table}:${response.status}:${body.slice(0, 500)}`);
  }
  const text = options.method === "HEAD" ? "" : await response.text();
  return text ? JSON.parse(text) : [];
}

async function fetchAll(table, params, pageSize = 1000) {
  const rows = [];
  for (let from = 0; ; from += pageSize) {
    const page = await rest(table, params, { range: `${from}-${from + pageSize - 1}` });
    rows.push(...page);
    if (page.length < pageSize) break;
  }
  return rows;
}

function localSet(rows) {
  return new Set(rows.map((row) => remoteKey(row.remoteId)).filter(Boolean));
}

function summarize(kind, remoteRows, androidRows, iosRows) {
  const androidIDs = localSet(androidRows);
  const iosIDs = localSet(iosRows);
  const byName = new Map();
  for (const row of remoteRows) {
    const normalized = normalizeName(row.name);
    const current = byName.get(normalized) || [];
    current.push(row);
    byName.set(normalized, current);
  }

  const rows = remoteRows
    .map((row) => {
      const key = remoteKey(row.id);
      return {
        kind,
        remote_hash: hash12(row.id),
        name: safeName(row.name),
        normalized_name_hash: hash12(normalizeName(row.name)),
        shop_hash: hash12(row.shop_id || "LEGACY_NULL"),
        shop_is_selected: row.shop_id === selectedShopId,
        shop_is_null: !row.shop_id,
        owner_hash: hash12(row.owner_user_id),
        deleted: Boolean(row.deleted_at),
        android_present: androidIDs.has(key),
        ios_present: iosIDs.has(key),
      };
    })
    .sort((left, right) => left.name.localeCompare(right.name) || String(left.remote_hash).localeCompare(String(right.remote_hash)));

  const duplicateNames = Array.from(byName.entries())
    .filter(([, items]) => items.length > 1)
    .map(([name, items]) => ({
      normalized_name_hash: hash12(name),
      display_names: Array.from(new Set(items.map((item) => safeName(item.name)))),
      count: items.length,
      remote_hashes: items.map((item) => hash12(item.id)).sort(),
      ios_present: items.filter((item) => iosIDs.has(remoteKey(item.id))).length,
      android_present: items.filter((item) => androidIDs.has(remoteKey(item.id))).length,
    }))
    .sort((left, right) => right.count - left.count || String(left.normalized_name_hash).localeCompare(String(right.normalized_name_hash)));

  return {
    counts: {
      remote_active: remoteRows.length,
      android_local: androidRows.length,
      ios_local: iosRows.length,
      remote_present_android: rows.filter((row) => row.android_present).length,
      remote_present_ios: rows.filter((row) => row.ios_present).length,
      missing_android: rows.filter((row) => !row.android_present).length,
      missing_ios: rows.filter((row) => !row.ios_present).length,
      duplicate_name_groups: duplicateNames.length,
    },
    missing_ios: rows.filter((row) => !row.ios_present),
    missing_android: rows.filter((row) => !row.android_present),
    duplicate_names: duplicateNames,
    rows,
  };
}

const env = parseEnv(envPath);
const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceRoleKey) {
  fail(".env.local must contain NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
}

const mappings = await fetchAll("shop_inventory_sources", [
  ["select", "shop_id,owner_user_id,mapping_state,source_kind,disabled_at"],
  ["shop_id", `eq.${selectedShopId}`],
]);
const activeMapping = mappings.find((row) => row.owner_user_id && !row.disabled_at) || mappings[0];
if (!activeMapping?.owner_user_id) fail(`No owner mapping found for shop ${selectedShopId}`);
const ownerUserId = activeMapping.owner_user_id;

const [remoteSuppliers, remoteCategories] = await Promise.all([
  fetchAll("inventory_suppliers", [
    ["select", "id,owner_user_id,shop_id,name,deleted_at,updated_at"],
    ["owner_user_id", `eq.${ownerUserId}`],
    ["deleted_at", "is.null"],
  ]),
  fetchAll("inventory_categories", [
    ["select", "id,owner_user_id,shop_id,name,deleted_at,updated_at"],
    ["owner_user_id", `eq.${ownerUserId}`],
    ["deleted_at", "is.null"],
  ]),
]);

const androidSuppliers = parseCsv("docs/TASKS/EVIDENCE/TASK-136/live-audit/android-suppliers.csv");
const androidCategories = parseCsv("docs/TASKS/EVIDENCE/TASK-136/live-audit/android-categories.csv");
const iosSuppliers = parseCsv("docs/TASKS/EVIDENCE/TASK-136/live-audit/ios-suppliers.csv");
const iosCategories = parseCsv("docs/TASKS/EVIDENCE/TASK-136/live-audit/ios-categories.csv");

const output = {
  generated_at: new Date().toISOString(),
  runtime_env: {
    project_ref: redactRef(refFromUrl(supabaseUrl)),
    env_source: envPath,
  },
  scope: {
    selected_shop_hash: hash12(selectedShopId),
    owner_user_hash: hash12(ownerUserId),
    mapping_state: activeMapping.mapping_state,
    source_kind: activeMapping.source_kind,
  },
  suppliers: summarize("supplier", remoteSuppliers, androidSuppliers, iosSuppliers),
  categories: summarize("category", remoteCategories, androidCategories, iosCategories),
};

writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`);
console.log(JSON.stringify(output, null, 2));
