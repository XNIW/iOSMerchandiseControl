#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const adminRoot =
  process.env.TASK136_ADMIN_WEB_ROOT ||
  "/Users/minxiang/Projects/merchandise-control-admin-web";
const envPath = join(adminRoot, ".env.local");
const selectedShopId = process.argv[2] || process.env.TASK136_SHOP_ID;
const androidProductRefsPath = process.argv[3] || process.env.TASK136_ANDROID_PRODUCT_REFS_JSON;

if (!selectedShopId) {
  fail("Usage: node tools/task136/supabase-scope-audit.mjs <shop_id> [android_product_refs_json]");
}

function fail(message) {
  console.error(`[task136-supabase-audit] ${message}`);
  process.exit(2);
}

function parseEnv(path) {
  if (!existsSync(path)) {
    fail(`Missing env file: ${path}`);
  }

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
  const url = new URL(value);
  return url.hostname.split(".")[0] || "unknown";
}

function redactRef(ref) {
  return ref ? `${ref.slice(0, 4)}...${ref.slice(-3)}` : "unknown";
}

function hash12(value) {
  if (!value) return null;
  return createHash("md5").update(String(value)).digest("hex").slice(0, 12);
}

function buildUrl(table, params = []) {
  const url = new URL(`${supabaseUrl}/rest/v1/${table}`);
  for (const [key, value] of params) {
    url.searchParams.append(key, value);
  }
  return url;
}

async function rest(table, params = [], options = {}) {
  const url = buildUrl(table, params);
  const response = await fetch(url, {
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
    const err = new Error(`${table}:${response.status}:${body.slice(0, 500)}`);
    err.status = response.status;
    throw err;
  }

  const contentRange = response.headers.get("content-range") || "";
  const text = options.method === "HEAD" ? "" : await response.text();
  return {
    rows: text ? JSON.parse(text) : [],
    contentRange,
  };
}

function countFromRange(contentRange, rowLength = 0) {
  const match = contentRange.match(/\/(\d+|\*)$/);
  if (match && match[1] !== "*") {
    return Number(match[1]);
  }
  return rowLength;
}

async function countRows(table, filters = [], select = "id") {
  const params = [["select", select], ...filters];
  const { rows, contentRange } = await rest(table, params, { range: "0-0" });
  return countFromRange(contentRange, rows.length);
}

async function countMaybe(table, filters = [], select = "id") {
  try {
    return { count: await countRows(table, filters, select), error: null };
  } catch (error) {
    return { count: null, error: error.message };
  }
}

async function activeDeleted(table, filters = []) {
  const selectColumn = table === "shared_sheet_sessions" ? "remote_id" : "id";
  const [active, deleted, total] = await Promise.all([
    countMaybe(table, [...filters, ["deleted_at", "is.null"]], selectColumn),
    countMaybe(table, [...filters, ["deleted_at", "not.is.null"]], selectColumn),
    countMaybe(table, filters, selectColumn),
  ]);
  return {
    active: active.count,
    deleted: deleted.count,
    total: total.count,
    errors: [active.error, deleted.error, total.error].filter(Boolean),
  };
}

async function fetchAll(table, params, pageSize = 1000) {
  const rows = [];
  for (let from = 0; ; from += pageSize) {
    const to = from + pageSize - 1;
    const page = await rest(table, params, { range: `${from}-${to}` });
    rows.push(...page.rows);
    if (page.rows.length < pageSize) break;
  }
  return rows;
}

async function countPricesByProductFilter(scopeName, productFilters) {
  const productRows = await fetchAll("inventory_products", [
    ["select", "id"],
    ...productFilters,
  ]);
  if (productRows.length === 0) {
    return { active: 0, deleted: null, total: 0, via: "product_id_chunks" };
  }

  let total = 0;
  const chunkSize = 100;
  for (let index = 0; index < productRows.length; index += chunkSize) {
    const ids = productRows.slice(index, index + chunkSize).map((row) => row.id);
    total += await countRows("inventory_product_prices", [
      ["product_id", `in.(${ids.join(",")})`],
    ]);
  }

  return {
    active: total,
    deleted: null,
    total,
    via: `product_id_chunks:${scopeName}:products=${productRows.length}`,
  };
}

async function countPricesByProductIds(productIds) {
  let total = 0;
  const chunkSize = 100;
  for (let index = 0; index < productIds.length; index += chunkSize) {
    const ids = productIds.slice(index, index + chunkSize);
    total += await countRows("inventory_product_prices", [
      ["product_id", `in.(${ids.join(",")})`],
    ]);
  }
  return total;
}

async function priceScope(scopeName, filters, productFilters = null) {
  const direct = await countMaybe("inventory_product_prices", filters);
  if (direct.count !== null) {
    return {
      active: direct.count,
      deleted: null,
      total: direct.count,
      via: "inventory_product_prices direct filters",
    };
  }
  if (productFilters) {
    return countPricesByProductFilter(scopeName, productFilters);
  }
  return { active: null, deleted: null, total: null, via: direct.error };
}

async function scopeCounts(scopeName, filters, productFiltersForPrices = null) {
  const [products, suppliers, categories, history, prices] = await Promise.all([
    activeDeleted("inventory_products", filters),
    activeDeleted("inventory_suppliers", filters),
    activeDeleted("inventory_categories", filters),
    activeDeleted("shared_sheet_sessions", filters),
    priceScope(scopeName, filters, productFiltersForPrices),
  ]);
  return { scope: scopeName, products, suppliers, categories, price_history: prices, history_sessions: history };
}

const env = parseEnv(envPath);
const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  fail(".env.local must contain NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
}

const projectRef = refFromUrl(supabaseUrl);
const [shops, mappings] = await Promise.all([
  fetchAll("shops", [
    ["select", "shop_id,shop_code,shop_name,shop_status"],
    ["shop_id", `eq.${selectedShopId}`],
  ]),
  fetchAll("shop_inventory_sources", [
    ["select", "shop_id,owner_user_id,mapping_state,source_kind,disabled_at"],
    ["shop_id", `eq.${selectedShopId}`],
  ]),
]);

const mappingOwnerIds = mappings
  .map((row) => row.owner_user_id)
  .filter((value, index, array) => value && array.indexOf(value) === index);

const selectedShopCounts = await scopeCounts(
  "selected_shop_id",
  [["shop_id", `eq.${selectedShopId}`]],
  [["shop_id", `eq.${selectedShopId}`]],
);

const ownerCounts = [];
for (const ownerId of mappingOwnerIds) {
  ownerCounts.push(
    await scopeCounts(
      "mapped_owner_user_id",
      [["owner_user_id", `eq.${ownerId}`]],
      [["owner_user_id", `eq.${ownerId}`]],
    ),
  );
  ownerCounts.push(
    await scopeCounts(
      "legacy_shop_id_null_by_owner",
      [
        ["owner_user_id", `eq.${ownerId}`],
        ["shop_id", "is.null"],
      ],
      [
        ["owner_user_id", `eq.${ownerId}`],
        ["shop_id", "is.null"],
      ],
    ),
  );
}

const productRows = await fetchAll("inventory_products", [
  ["select", "owner_user_id,shop_id,deleted_at"],
]);
const productScopeSummary = new Map();
for (const row of productRows) {
  const key = `${row.owner_user_id || "null"}|${row.shop_id || "LEGACY_NULL"}`;
  const current = productScopeSummary.get(key) || {
    owner_hash: hash12(row.owner_user_id),
    shop_hash: hash12(row.shop_id || "LEGACY_NULL"),
    shop_is_null: !row.shop_id,
    active: 0,
    deleted: 0,
    total: 0,
  };
  if (row.deleted_at) current.deleted += 1;
  else current.active += 1;
  current.total += 1;
  productScopeSummary.set(key, current);
}

async function probeAndroidProductRefs(path) {
  if (!path || !existsSync(path)) return null;
  const localRefs = JSON.parse(readFileSync(path, "utf8"));
  const remoteIds = localRefs
    .map((row) => row.remote_id)
    .filter((value, index, array) => value && array.indexOf(value) === index);
  const productNamePrefixes = new Map();
  for (const row of localRefs) {
    const prefix = String(row.product_name || "unknown").slice(0, 24);
    productNamePrefixes.set(prefix, (productNamePrefixes.get(prefix) || 0) + 1);
  }

  const remoteRows = [];
  const chunkSize = 100;
  for (let index = 0; index < remoteIds.length; index += chunkSize) {
    const ids = remoteIds.slice(index, index + chunkSize);
    const rows = await fetchAll("inventory_products", [
      ["select", "id,owner_user_id,shop_id,deleted_at,product_name"],
      ["id", `in.(${ids.join(",")})`],
    ]);
    remoteRows.push(...rows);
  }

  const scopeSummary = new Map();
  for (const row of remoteRows) {
    const key = `${row.owner_user_id || "null"}|${row.shop_id || "LEGACY_NULL"}`;
    const current = scopeSummary.get(key) || {
      owner_hash: hash12(row.owner_user_id),
      shop_hash: hash12(row.shop_id || "LEGACY_NULL"),
      shop_is_null: !row.shop_id,
      active: 0,
      deleted: 0,
      total: 0,
    };
    if (row.deleted_at) current.deleted += 1;
    else current.active += 1;
    current.total += 1;
    scopeSummary.set(key, current);
  }

  return {
    local_product_refs: localRefs.length,
    distinct_remote_ids: remoteIds.length,
    remote_products_found: remoteRows.length,
    remote_products_active: remoteRows.filter((row) => !row.deleted_at).length,
    remote_products_deleted: remoteRows.filter((row) => row.deleted_at).length,
    remote_price_history_for_refs: await countPricesByProductIds(remoteIds),
    by_owner_shop: Array.from(scopeSummary.values()).sort(
      (a, b) => b.active - a.active || b.total - a.total,
    ),
    local_name_prefixes: Array.from(productNamePrefixes.entries())
      .map(([prefix, count]) => ({ prefix, count }))
      .sort((a, b) => b.count - a.count || a.prefix.localeCompare(b.prefix)),
  };
}

const androidRemoteRefProbe = await probeAndroidProductRefs(androidProductRefsPath);

const output = {
  generated_at: new Date().toISOString(),
  runtime_env: {
    project_ref: redactRef(projectRef),
    env_source: envPath,
  },
  selected_shop: shops[0]
    ? {
        shop_hash: hash12(shops[0].shop_id),
        shop_code: shops[0].shop_code,
        shop_name: shops[0].shop_name,
        shop_status: shops[0].shop_status,
      }
    : null,
  mappings: mappings.map((row) => ({
    shop_hash: hash12(row.shop_id),
    owner_hash: hash12(row.owner_user_id),
    mapping_state: row.mapping_state,
    source_kind: row.source_kind,
    disabled: Boolean(row.disabled_at),
  })),
  counts: [selectedShopCounts, ...ownerCounts],
  product_owner_shop_scopes: Array.from(productScopeSummary.values()).sort(
    (a, b) => b.active - a.active || b.total - a.total,
  ),
  product_scopes_with_11ish_active: Array.from(productScopeSummary.values())
    .filter((row) => row.active >= 8 && row.active <= 14)
    .sort((a, b) => b.active - a.active || b.total - a.total),
  android_remote_ref_probe: androidRemoteRefProbe,
};

console.log(JSON.stringify(output, null, 2));
