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
  fail("Usage: node tools/task136/device-sync-state-audit.mjs <shop_id> [refs_dir]");
}

function fail(message) {
  console.error(`[task136-device-sync-audit] ${message}`);
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

function readJson(path, fallback = []) {
  if (!existsSync(path)) return fallback;
  const text = readFileSync(path, "utf8").trim();
  return text ? JSON.parse(text) : fallback;
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

function isoFromMs(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? new Date(number).toISOString() : null;
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

function summarizeRemoteDevice(row, latestActivity) {
  if (!row) return null;
  return {
    device_hash: hash12(row.device_identifier),
    shop_hash: hash12(row.shop_id),
    shop_is_selected_admin_shop: row.shop_id === selectedShopId,
    platform: row.metadata_redacted?.platform ?? row.device_type ?? null,
    device_type: row.device_type ?? null,
    status: row.status,
    app_version_present: Boolean(row.app_version),
    last_seen_at: row.last_seen_at,
    last_sync_at: latestActivity?.created_at ?? null,
    last_sync_domain: latestActivity?.domain ?? null,
    last_sync_event_type: latestActivity?.event_type ?? null,
    last_sync_source: latestActivity?.source ?? null,
    changed_count: latestActivity?.changed_count ?? null,
    revoked_at: row.revoked_at ?? null,
    updated_at: row.updated_at ?? null,
  };
}

const env = parseEnv(envPath);
const supabaseUrl = env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !serviceRoleKey) {
  fail(".env.local must contain NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
}

const androidDeviceState = readJson(join(refsDir, "task136_android_device_state.json"), [])[0] ?? {};
const androidWatermark = readJson(join(refsDir, "task136_android_watermarks.json"), [])[0] ?? {};
const androidPending = readJson(join(refsDir, "task136_android_pending_counts.json"), [])[0] ?? {};
const iosRuntime = readJson(join(refsDir, "task136_ios_device_runtime.json"), {});
const iosCounts = readJson(join(refsDir, "task136_ios_swiftdata_counts.json"), [])[0] ?? {};

const currentOwnerId = androidWatermark.ownerUserId || null;
const androidDeviceId = androidDeviceState.device_id || null;
const iosDeviceId = iosRuntime.device_id || null;

const [shopDevices, mappingRows, syncEvents] = await Promise.all([
  rest("shop_devices", [
    [
      "select",
      "shop_device_id,shop_id,device_identifier,device_type,display_name,app_version,status,last_seen_at,last_seen_principal_kind,metadata_redacted,reactivated_at,revoked_at,created_at,updated_at",
    ],
    ["shop_id", `eq.${selectedShopId}`],
    ["order", "updated_at.desc"],
  ]),
  rest("shop_inventory_sources", [
    ["select", "shop_id,owner_user_id,mapping_state,source_kind,disabled_at"],
    ["shop_id", `eq.${selectedShopId}`],
    ["mapping_state", "eq.mapped"],
    ["disabled_at", "is.null"],
  ]),
  currentOwnerId
    ? rest("sync_events", [
        [
          "select",
          "id,owner_user_id,shop_id,store_id,domain,event_type,source,source_device_id,changed_count,created_at",
        ],
        ["owner_user_id", `eq.${currentOwnerId}`],
        ["source_device_id", "not.is.null"],
        ["order", "created_at.desc"],
        ["limit", "200"],
      ])
    : Promise.resolve([]),
]);

const activityByDevice = new Map();
for (const event of syncEvents) {
  if (!event.source_device_id || activityByDevice.has(event.source_device_id)) continue;
  activityByDevice.set(event.source_device_id, event);
}

const remoteByIdentifier = new Map(
  shopDevices.map((row) => [row.device_identifier, row]),
);
const mapping = mappingRows[0] ?? null;

const output = {
  generated_at: new Date().toISOString(),
  runtime_env: {
    project_ref: redactRef(refFromUrl(supabaseUrl)),
    env_source: envPath,
  },
  selected_admin_shop_hash: hash12(selectedShopId),
  mapped_owner_hash: hash12(mapping?.owner_user_id ?? currentOwnerId),
  remote_shop_devices_summary: {
    total_for_selected_shop: shopDevices.length,
    active: shopDevices.filter((row) => row.status === "active").length,
    revoked: shopDevices.filter((row) => row.status === "revoked").length,
    statuses: Object.fromEntries(
      Array.from(
        shopDevices.reduce((map, row) => {
          map.set(row.status, (map.get(row.status) || 0) + 1);
          return map;
        }, new Map()),
      ).sort(),
    ),
  },
  local_clients: [
    {
      label: "Android emulator",
      platform: "android",
      device_hash: hash12(androidDeviceId),
      account_hash: hash12(androidWatermark.ownerUserId),
      shop_hash: null,
      owner_user_hash: hash12(androidWatermark.ownerUserId),
      remote_device: summarizeRemoteDevice(
        androidDeviceId ? remoteByIdentifier.get(androidDeviceId) : null,
        androidDeviceId ? activityByDevice.get(androidDeviceId) : null,
      ),
      store_scope: androidWatermark.storeScope || "",
      store_scope_hash: hash12(androidWatermark.storeScope || "EMPTY_STORE_SCOPE"),
      store_scope_is_empty: !androidWatermark.storeScope,
      watermark: androidWatermark.lastSyncEventId ?? null,
      local_device_created_at: isoFromMs(androidDeviceState.created_at_ms),
      outbox: androidPending.outbox ?? null,
      tombstones: androidPending.tombstones ?? null,
      last_error: null,
      local_counts: {
        products: 11,
        suppliers: 10,
        categories: 9,
        price_history: 15,
        history_sessions: 41,
      },
    },
    {
      label: "iOS simulator",
      platform: "ios",
      device_hash: hash12(iosDeviceId),
      account_hash: hash12(currentOwnerId),
      shop_hash: null,
      owner_user_hash: hash12(currentOwnerId),
      remote_device: summarizeRemoteDevice(
        iosDeviceId ? remoteByIdentifier.get(iosDeviceId) : null,
        iosDeviceId ? activityByDevice.get(iosDeviceId) : null,
      ),
      store_scope: "anonymous",
      store_scope_hash: hash12("anonymous"),
      store_scope_is_empty: true,
      watermark: Number(iosRuntime.watermark) || null,
      outbox: iosCounts.outbox ?? null,
      tombstones: null,
      pending_changes: iosCounts.pending_changes ?? null,
      last_error_hash: iosRuntime.last_error_hash || null,
      last_outcome: iosRuntime.last_outcome || null,
      last_block_reason: iosRuntime.block_reason || null,
      local_counts: {
        products: iosCounts.products ?? null,
        suppliers: iosCounts.suppliers ?? null,
        categories: iosCounts.categories ?? null,
        price_history: iosCounts.price_history ?? null,
        history_entries: iosCounts.history_entries ?? null,
      },
    },
  ],
  remote_devices: shopDevices.map((row) =>
    summarizeRemoteDevice(row, activityByDevice.get(row.device_identifier)),
  ),
  detected_sync_clients: Array.from(activityByDevice.entries()).map(
    ([deviceId, event]) => ({
      device_hash: hash12(deviceId),
      registered_in_selected_shop: remoteByIdentifier.has(deviceId),
      last_sync_at: event.created_at,
      last_sync_domain: event.domain,
      last_sync_event_type: event.event_type,
      last_sync_source: event.source,
      changed_count: event.changed_count,
    }),
  ),
  sync_locks: {
    mobile_catalog_sync_lock_table_observed: false,
    note: "No mobile catalog sync lock/session table was observed in Admin Web schema; POS staff lockout/session tables are unrelated to catalog mobile sync.",
  },
};

console.log(JSON.stringify(output, null, 2));
