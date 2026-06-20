#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const adminRoot =
  process.env.TASK136_ADMIN_WEB_ROOT ||
  "/Users/minxiang/Projects/merchandise-control-admin-web";
const envPath = join(adminRoot, ".env.local");

const selectedShopId = process.argv[2] || process.env.TASK136_SHOP_ID;
const refsDir = process.argv[3] || "/tmp";

if (!selectedShopId) {
  fail("Usage: node tools/task136/android-remote-refs-audit.mjs <shop_id> [refs_dir]");
}

function fail(message) {
  console.error(`[task136-android-refs-audit] ${message}`);
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

function refFromUrl(value) {
  return new URL(value).hostname.split(".")[0] || "unknown";
}

function redactRef(ref) {
  return ref ? `${ref.slice(0, 4)}...${ref.slice(-3)}` : "unknown";
}

function hash12(value) {
  if (!value) return null;
  return createHash("md5").update(String(value)).digest("hex").slice(0, 12);
}

function safePrefix(value, max = 32) {
  if (!value) return null;
  const text = String(value);
  if (/^[A-Z0-9_:-]+$/.test(text) && text.length <= 96) {
    return text.slice(0, max);
  }
  return hash12(text);
}

function readJson(path, fallback = []) {
  if (!existsSync(path)) return fallback;
  const text = readFileSync(path, "utf8").trim();
  return text ? JSON.parse(text) : fallback;
}

function refsPath(name) {
  return join(refsDir, `task136_android_${name}_refs.json`);
}

function buildUrl(table, params = []) {
  const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
  for (const [key, value] of params) {
    url.searchParams.append(key, value);
  }
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

async function fetchByIds(table, keyColumn, ids, select) {
  const rows = [];
  const chunkSize = 100;
  for (let index = 0; index < ids.length; index += chunkSize) {
    const chunk = ids.slice(index, index + chunkSize);
    rows.push(
      ...(await rest(table, [
        ["select", select],
        [keyColumn, `in.(${chunk.join(",")})`],
      ])),
    );
  }
  return rows;
}

function summarizeRows(localRefs, remoteRows, keyColumn, options = {}) {
  const remoteById = new Map(remoteRows.map((row) => [row[keyColumn], row]));
  const summary = {
    local_refs: localRefs.length,
    distinct_remote_ids: new Set(localRefs.map((row) => row.remote_id).filter(Boolean)).size,
    remote_found: 0,
    remote_missing: 0,
    deleted_or_tombstoned: 0,
    selected_shop: 0,
    other_shop: 0,
    legacy_shop_null: 0,
    current_owner: 0,
    other_owner: 0,
    current_store_scope: 0,
    other_store_scope: 0,
  };
  const rows = localRefs.map((local) => {
    const remote = remoteById.get(local.remote_id);
    if (!remote) {
      summary.remote_missing += 1;
      return {
        remote_hash: hash12(local.remote_id),
        exists: false,
        local_label_prefix: safePrefix(local.local_label),
      };
    }

    summary.remote_found += 1;
    const deleted = Boolean(remote.deleted_at);
    const shopId = remote.shop_id || null;
    const ownerId = remote.owner_user_id || null;
    const storeScope = shopId || "";

    if (deleted) summary.deleted_or_tombstoned += 1;
    if (shopId === selectedShopId) summary.selected_shop += 1;
    else if (shopId) summary.other_shop += 1;
    else summary.legacy_shop_null += 1;

    if (currentOwnerId && ownerId === currentOwnerId) summary.current_owner += 1;
    else summary.other_owner += 1;

    if ((androidStoreScope || "") === storeScope) summary.current_store_scope += 1;
    else summary.other_store_scope += 1;

    return {
      remote_hash: hash12(local.remote_id),
      exists: true,
      shop_hash: hash12(shopId || "LEGACY_NULL"),
      shop_is_selected_admin_shop: shopId === selectedShopId,
      shop_is_null: !shopId,
      owner_hash: hash12(ownerId),
      owner_is_current_account: Boolean(currentOwnerId && ownerId === currentOwnerId),
      store_scope_matches_watermark: (androidStoreScope || "") === storeScope,
      deleted: deleted,
      updated_at: remote.updated_at || remote.created_at || null,
      barcode_prefix: safePrefix(remote.barcode, 24),
      name_prefix: safePrefix(
        remote.product_name ||
          remote.name ||
          remote.display_name ||
          remote.source ||
          local.local_label,
      ),
      price_product_hash: options.productIdColumn ? hash12(remote[options.productIdColumn]) : undefined,
    };
  });
  return { summary, rows };
}

const env = parseEnv(envPath);
const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceRoleKey) {
  fail(".env.local must contain NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
}

const watermarks = readJson(join(refsDir, "task136_android_watermarks.json"), []);
const currentOwnerId = watermarks[0]?.ownerUserId || null;
const androidStoreScope = watermarks[0]?.storeScope || "";

const datasets = {
  products: {
    refs: readJson(refsPath("product")),
    table: "inventory_products",
    keyColumn: "id",
    select: "id,owner_user_id,shop_id,deleted_at,updated_at,barcode,product_name",
  },
  suppliers: {
    refs: readJson(refsPath("supplier")),
    table: "inventory_suppliers",
    keyColumn: "id",
    select: "id,owner_user_id,shop_id,deleted_at,updated_at,name",
  },
  categories: {
    refs: readJson(refsPath("category")),
    table: "inventory_categories",
    keyColumn: "id",
    select: "id,owner_user_id,shop_id,deleted_at,updated_at,name",
  },
  price_history: {
    refs: readJson(refsPath("price")),
    table: "inventory_product_prices",
    keyColumn: "id",
    select: "id,owner_user_id,shop_id,created_at,product_id,source,type",
    productIdColumn: "product_id",
  },
  history_sessions: {
    refs: readJson(refsPath("history")),
    table: "shared_sheet_sessions",
    keyColumn: "remote_id",
    select: "remote_id,owner_user_id,shop_id,deleted_at,updated_at,display_name",
  },
};

const results = {};
for (const [name, dataset] of Object.entries(datasets)) {
  const ids = Array.from(
    new Set(dataset.refs.map((row) => row.remote_id).filter(Boolean)),
  );
  const remoteRows =
    ids.length === 0
      ? []
      : await fetchByIds(dataset.table, dataset.keyColumn, ids, dataset.select);
  results[name] = summarizeRows(
    dataset.refs,
    remoteRows,
    dataset.keyColumn,
    { productIdColumn: dataset.productIdColumn },
  );
}

const output = {
  generated_at: new Date().toISOString(),
  runtime_env: {
    project_ref: redactRef(refFromUrl(supabaseUrl)),
    env_source: envPath,
  },
  selected_admin_shop_hash: hash12(selectedShopId),
  android_watermark: {
    owner_hash: hash12(currentOwnerId),
    store_scope_hash: hash12(androidStoreScope || "EMPTY_STORE_SCOPE"),
    store_scope_is_empty: !androidStoreScope,
    last_sync_event_id: watermarks[0]?.lastSyncEventId ?? null,
  },
  results,
};

console.log(JSON.stringify(output, null, 2));
