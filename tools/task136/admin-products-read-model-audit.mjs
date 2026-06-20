#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const adminRoot =
  process.env.TASK136_ADMIN_WEB_ROOT ||
  "/Users/minxiang/Projects/merchandise-control-admin-web";
const envPath = join(adminRoot, ".env.local");
const selectedShopId = process.argv[2] || process.env.TASK136_SHOP_ID;

if (!selectedShopId) {
  fail("Usage: node tools/task136/admin-products-read-model-audit.mjs <shop_id>");
}

function fail(message) {
  console.error(`[task136-admin-products-audit] ${message}`);
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

function safePrefix(value, max = 36) {
  if (!value) return null;
  const text = String(value);
  if (/^[A-Z0-9_:-]+$/.test(text) && text.length <= 128) {
    return text.slice(0, max);
  }
  return hash12(text);
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
  const contentRange = response.headers.get("content-range") || "";
  const text = options.method === "HEAD" ? "" : await response.text();
  return {
    contentRange,
    rows: text ? JSON.parse(text) : [],
  };
}

function countFromRange(contentRange, rowLength = 0) {
  const match = contentRange.match(/\/(\d+|\*)$/);
  if (match && match[1] !== "*") return Number(match[1]);
  return rowLength;
}

async function countRows(table, filters, select = "id") {
  const result = await rest(table, [["select", select], ...filters], {
    range: "0-0",
  });
  return countFromRange(result.contentRange, result.rows.length);
}

async function countPrices(filters) {
  return countRows("inventory_product_prices", filters);
}

const env = parseEnv(envPath);
const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceRoleKey) {
  fail(".env.local must contain NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
}

const [shopsResult, mappingsResult] = await Promise.all([
  rest("shops", [
    ["select", "shop_id,shop_code,shop_name,shop_status"],
    ["shop_id", `eq.${selectedShopId}`],
  ]),
  rest("shop_inventory_sources", [
    ["select", "shop_id,owner_user_id,mapping_state,source_kind,disabled_at"],
    ["shop_id", `eq.${selectedShopId}`],
    ["disabled_at", "is.null"],
  ]),
]);

const selectedShop = shopsResult.rows[0] ?? null;
const mapping =
  mappingsResult.rows.find((row) => row.mapping_state === "mapped" && row.owner_user_id) ??
  null;
const ownerId = mapping?.owner_user_id ?? null;
const preferMappedMobileOwnerBridge =
  mapping?.source_kind === "mobile_owner" &&
  mapping?.mapping_state === "mapped" &&
  Boolean(mapping?.owner_user_id);
const legacyOwnerOnlySchema = preferMappedMobileOwnerBridge;
const useLegacyOwnerBridge = preferMappedMobileOwnerBridge || Boolean(ownerId);
const catalogScope = useLegacyOwnerBridge ? "legacy_owner_bridge" : "shop_scoped";

const firstPaintFilters =
  catalogScope === "legacy_owner_bridge" && legacyOwnerOnlySchema
    ? [
        ["owner_user_id", `eq.${ownerId}`],
        ["deleted_at", "is.null"],
      ]
    : catalogScope === "legacy_owner_bridge"
      ? [
          ["owner_user_id", `eq.${ownerId}`],
          ["shop_id", "is.null"],
          ["deleted_at", "is.null"],
        ]
      : [
          ["shop_id", `eq.${selectedShopId}`],
          ["deleted_at", "is.null"],
        ];

const firstPaint = await rest(
  "inventory_products",
  [
    ["select", "id,owner_user_id,shop_id,deleted_at,updated_at,barcode,product_name"],
    ...firstPaintFilters,
    ["order", "updated_at.desc,id.asc"],
  ],
  { range: "0-10" },
);

const rowScopeSummary = { selected_shop: 0, legacy_shop_null: 0, other_shop: 0 };
for (const row of firstPaint.rows) {
  if (row.shop_id === selectedShopId) rowScopeSummary.selected_shop += 1;
  else if (row.shop_id) rowScopeSummary.other_shop += 1;
  else rowScopeSummary.legacy_shop_null += 1;
}

const [
  ownerActive,
  ownerDeleted,
  ownerPrices,
  selectedShopActive,
  selectedShopDeleted,
  selectedShopPrices,
  legacyNullActive,
] = await Promise.all([
  countRows("inventory_products", [
    ["owner_user_id", `eq.${ownerId}`],
    ["deleted_at", "is.null"],
  ]),
  countRows("inventory_products", [
    ["owner_user_id", `eq.${ownerId}`],
    ["deleted_at", "not.is.null"],
  ]),
  countPrices([["owner_user_id", `eq.${ownerId}`]]),
  countRows("inventory_products", [
    ["shop_id", `eq.${selectedShopId}`],
    ["deleted_at", "is.null"],
  ]),
  countRows("inventory_products", [
    ["shop_id", `eq.${selectedShopId}`],
    ["deleted_at", "not.is.null"],
  ]),
  countPrices([["shop_id", `eq.${selectedShopId}`]]),
  countRows("inventory_products", [
    ["owner_user_id", `eq.${ownerId}`],
    ["shop_id", "is.null"],
    ["deleted_at", "is.null"],
  ]),
]);

const pageSize = 10;
const firstPaintCurrentRows = firstPaint.rows.slice(0, pageSize);
const firstPaintHasNextPage = firstPaint.rows.length > pageSize;

const output = {
  generated_at: new Date().toISOString(),
  runtime_env: {
    project_ref: redactRef(refFromUrl(supabaseUrl)),
    env_source: envPath,
  },
  admin_browser_route: "/shop/products?shop_id=<selected_admin_shop>",
  selected_shop: selectedShop
    ? {
        shop_hash: hash12(selectedShop.shop_id),
        shop_code: selectedShop.shop_code,
        shop_name: selectedShop.shop_name,
        shop_status: selectedShop.shop_status,
      }
    : null,
  mapping: mapping
    ? {
        shop_hash: hash12(mapping.shop_id),
        owner_hash: hash12(mapping.owner_user_id),
        mapping_state: mapping.mapping_state,
        source_kind: mapping.source_kind,
        disabled: Boolean(mapping.disabled_at),
      }
    : null,
  route_logic: {
    function: "getShopInventoryProductsPage",
    includeExactTotals: false,
    preferMappedMobileOwnerBridge,
    legacyOwnerOnlySchema,
    useLegacyOwnerBridge,
    catalogScope,
    query_shape:
      catalogScope === "legacy_owner_bridge" && legacyOwnerOnlySchema
        ? "inventory_products WHERE owner_user_id = mapped owner AND deleted_at IS NULL ORDER BY updated_at DESC, id ASC RANGE 0..10"
        : catalogScope === "legacy_owner_bridge"
          ? "inventory_products WHERE owner_user_id = mapped owner AND shop_id IS NULL AND deleted_at IS NULL ORDER BY updated_at DESC, id ASC RANGE 0..10"
          : "inventory_products WHERE shop_id = selected shop AND deleted_at IS NULL ORDER BY updated_at DESC, id ASC RANGE 0..10",
  },
  first_paint_lower_bound: {
    fetched_rows_for_has_next: firstPaint.rows.length,
    current_page_rows: firstPaintCurrentRows.length,
    page_size: pageSize,
    has_next_page: firstPaintHasNextPage,
    ui_total_products_label: `${firstPaint.rows.length}+`,
    ui_filtered_rows_label: `${firstPaint.rows.length}+`,
    row_scope_summary: rowScopeSummary,
    rows: firstPaintCurrentRows.map((row) => ({
      remote_hash: hash12(row.id),
      owner_hash: hash12(row.owner_user_id),
      shop_hash: hash12(row.shop_id || "LEGACY_NULL"),
      shop_is_selected_admin_shop: row.shop_id === selectedShopId,
      shop_is_null: !row.shop_id,
      updated_at: row.updated_at,
      barcode_prefix: safePrefix(row.barcode, 24),
      product_name_prefix: safePrefix(row.product_name),
    })),
  },
  exact_counts_if_not_deferred: {
    admin_read_model_owner_only_active: ownerActive,
    admin_read_model_owner_only_deleted: ownerDeleted,
    admin_read_model_owner_only_price_history: ownerPrices,
    supabase_canonical_selected_shop_active: selectedShopActive,
    supabase_canonical_selected_shop_deleted: selectedShopDeleted,
    supabase_canonical_selected_shop_price_history: selectedShopPrices,
    legacy_shop_id_null_by_owner_active: legacyNullActive,
  },
  comparison_targets: {
    android_room_live_products: 11,
    ios_swiftdata_products_observed: 19710,
  },
};

console.log(JSON.stringify(output, null, 2));
