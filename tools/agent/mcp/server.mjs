#!/usr/bin/env node
/**
 * Minimal MCP server: thin wrapper over mc-agent.sh.
 * No duplicated harness logic, no arbitrary shell commands, no MC_ALLOW_* mutation.
 */
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MC_AGENT = path.resolve(__dirname, "..", "mc-agent.sh");
const MC_IOS_REPO = process.env.MC_IOS_REPO || "/Users/minxiang/Desktop/iOSMerchandiseControl";
const TIMEOUT_MS = Number(process.env.MC_MCP_TIMEOUT_MS || 120000);

const TOOLS = [
  { name: "mc_preflight", args: ["preflight"], live: false, cleanup: false },
  { name: "mc_task118_head_consistency", args: ["git", "head-consistency", "--task"], taskArg: true, defaultTask: "TASK-118", live: false, cleanup: false },
  { name: "mc_task118_preflight_head_consistency", args: ["preflight", "--require-head-consistency", "--task"], taskArg: true, defaultTask: "TASK-118", live: false, cleanup: false },
  { name: "mc_task118_scan_sync_boundaries", args: ["scan", "sync-boundaries", "--task"], taskArg: true, defaultTask: "TASK-118", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task118_scan_no_full_pull_normal_path", args: ["scan", "no-full-pull-normal-path", "--task"], taskArg: true, defaultTask: "TASK-118", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task118_ios_test_automatic_domain", args: ["ios", "test", "automatic-domain", "--task"], taskArg: true, defaultTask: "TASK-118", live: false, cleanup: false },
  { name: "mc_task118_report_validate_json", args: ["report", "validate-json", "--task"], taskArg: true, defaultTask: "TASK-118", suffixArgs: ["--path"], reportPathArg: true, defaultPath: "docs/TASKS/EVIDENCE/TASK-118/agent-runs", live: false, cleanup: false },
  { name: "mc_task119_head_consistency", args: ["git", "head-consistency", "--task"], taskArg: true, defaultTask: "TASK-119", live: false, cleanup: false },
  { name: "mc_task119_preflight_head_consistency", args: ["preflight", "--require-head-consistency", "--task"], taskArg: true, defaultTask: "TASK-119", live: false, cleanup: false },
  { name: "mc_task119_scan_sync_architecture", args: ["scan", "sync-architecture", "--task"], taskArg: true, defaultTask: "TASK-119", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task119_scan_manual_boundary", args: ["scan", "manual-boundary", "--task"], taskArg: true, defaultTask: "TASK-119", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task119_scan_dead_code", args: ["scan", "dead-code", "--task"], taskArg: true, defaultTask: "TASK-119", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task119_scan_xcode_membership", args: ["scan", "xcode-membership", "--task"], taskArg: true, defaultTask: "TASK-119", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task119_ios_test_automatic_architecture", args: ["ios", "test", "automatic-architecture", "--task"], taskArg: true, defaultTask: "TASK-119", live: false, cleanup: false },
  { name: "mc_task119_report_validate_json", args: ["report", "validate-json", "--task"], taskArg: true, defaultTask: "TASK-119", suffixArgs: ["--path"], reportPathArg: true, defaultPath: "docs/TASKS/EVIDENCE/TASK-119/agent-runs", live: false, cleanup: false },
  { name: "mc_task120_head_consistency", args: ["git", "head-consistency", "--task"], taskArg: true, defaultTask: "TASK-120", live: false, cleanup: false },
  { name: "mc_task120_preflight_head_consistency", args: ["preflight", "--require-head-consistency", "--task"], taskArg: true, defaultTask: "TASK-120", live: false, cleanup: false },
  { name: "mc_task120_scan_task_docs", args: ["scan", "task-docs", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task120_scan_harness_routing", args: ["scan", "harness-routing", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task120_scan_harness_health", args: ["scan", "harness-health", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task120_scan_source_format", args: ["scan", "source-format", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task120_scan_scanner_self_tests", args: ["scan", "scanner-self-tests", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task120_scan_sync_architecture", args: ["scan", "sync-architecture", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task120_scan_manual_boundary", args: ["scan", "manual-boundary", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task120_scan_xcode_membership", args: ["scan", "xcode-membership", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task120_report_validate_json", args: ["report", "validate-json", "--task"], taskArg: true, defaultTask: "TASK-120", suffixArgs: ["--path"], reportPathArg: true, defaultPath: "docs/TASKS/EVIDENCE/TASK-120/agent-runs", live: false, cleanup: false },
  { name: "mc_task121_head_consistency", args: ["git", "head-consistency", "--task"], taskArg: true, defaultTask: "TASK-121", live: false, cleanup: false },
  { name: "mc_task121_preflight_head_consistency", args: ["preflight", "--require-head-consistency", "--task"], taskArg: true, defaultTask: "TASK-121", live: false, cleanup: false },
  { name: "mc_task121_scan_task_docs", args: ["scan", "task-docs", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_master_plan_consistency", args: ["scan", "master-plan-consistency", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_harness_routing", args: ["scan", "harness-routing", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_harness_health", args: ["scan", "harness-health", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_mcp_wrapper", args: ["scan", "mcp-wrapper", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_status_taxonomy", args: ["scan", "status-taxonomy", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_evidence_metadata", args: ["scan", "evidence-metadata", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_scanner_self_tests", args: ["scan", "scanner-self-tests", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_source_format", args: ["scan", "source-format", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_sync_inventory", args: ["scan", "sync-inventory", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_sync_architecture", args: ["scan", "sync-architecture", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_retry_ownership", args: ["scan", "retry-ownership", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_manual_boundary", args: ["scan", "manual-boundary", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_root_residue", args: ["scan", "root-residue", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_shared_purity", args: ["scan", "shared-purity", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_dead_code", args: ["scan", "dead-code", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_xcode_membership", args: ["scan", "xcode-membership", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_scan_duplicate_symbols", args: ["scan", "duplicate-symbols", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task121_report_validate_json", args: ["report", "validate-json", "--task"], taskArg: true, defaultTask: "TASK-121", suffixArgs: ["--path"], reportPathArg: true, defaultPath: "docs/TASKS/EVIDENCE/TASK-121/agent-runs", live: false, cleanup: false },
  { name: "mc_task122_head_consistency", args: ["git", "head-consistency", "--task"], taskArg: true, defaultTask: "TASK-122", live: false, cleanup: false },
  { name: "mc_task122_preflight_head_consistency", args: ["preflight", "--require-head-consistency", "--task"], taskArg: true, defaultTask: "TASK-122", live: false, cleanup: false },
  { name: "mc_task122_scan_task_docs", args: ["scan", "task-docs", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_master_plan_consistency", args: ["scan", "master-plan-consistency", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_evidence_metadata", args: ["scan", "evidence-metadata", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_harness_routing", args: ["scan", "harness-routing", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_harness_health", args: ["scan", "harness-health", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_mcp_wrapper", args: ["scan", "mcp-wrapper", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_source_format", args: ["scan", "source-format", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_swift_source_shape", args: ["scan", "swift-source-shape", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_sync_inventory", args: ["scan", "sync-inventory", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_sync_architecture", args: ["scan", "sync-architecture", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_remote_transport_thin", args: ["scan", "remote-transport-thin", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_adapter_delegation_depth", args: ["scan", "adapter-delegation-depth", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_domain_method_ownership", args: ["scan", "domain-method-ownership", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_manual_debug_boundary", args: ["scan", "manual-debug-boundary", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_transport_protocol_conformance", args: ["scan", "transport-protocol-conformance", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_composition_import_boundary", args: ["scan", "composition-import-boundary", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_remote_query_ownership", args: ["scan", "remote-query-ownership", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_debug_seed_boundary", args: ["scan", "debug-seed-boundary", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_dto_mapper_duplication", args: ["scan", "dto-mapper-duplication", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_supabase_query_map", args: ["scan", "supabase-query-map", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict", "--read-only"], live: false, cleanup: false },
  { name: "mc_task122_scan_transport_callsite_map", args: ["scan", "transport-callsite-map", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_protocol_conformance_map", args: ["scan", "protocol-conformance-map", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_supabase_contract_map", args: ["scan", "supabase-contract-map", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict", "--read-only"], live: false, cleanup: false },
  { name: "mc_task122_scan_android_parity_ledger", args: ["scan", "android-parity-ledger", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_xcode_membership", args: ["scan", "xcode-membership", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_dead_code", args: ["scan", "dead-code", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_scan_sync_efficiency_acceptance", args: ["scan", "sync-efficiency-acceptance", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--strict"], live: false, cleanup: false },
  { name: "mc_task122_report_validate_json", args: ["report", "validate-json", "--task"], taskArg: true, defaultTask: "TASK-122", suffixArgs: ["--path"], reportPathArg: true, defaultPath: "docs/TASKS/EVIDENCE/TASK-122/agent-runs", live: false, cleanup: false },
  { name: "mc_report", args: ["report", "--task", "TASK-115"], live: false, cleanup: false },
  { name: "mc_report_task115", args: ["report", "--task", "TASK-115"], live: false, cleanup: false },
  { name: "mc_ios_build_debug", args: ["ios", "build", "debug"], live: false, cleanup: false },
  { name: "mc_ios_build_release", args: ["ios", "build", "release"], live: false, cleanup: false },
  { name: "mc_ios_test_sync", args: ["ios", "test", "sync"], live: false, cleanup: false },
  { name: "mc_android_build_debug", args: ["android", "build", "debug"], live: false, cleanup: false },
  { name: "mc_android_build_release", args: ["android", "build", "release"], live: false, cleanup: false },
  { name: "mc_android_test_sync", args: ["android", "test", "sync"], live: false, cleanup: false },
  { name: "mc_android_test_offline", args: ["android", "test", "offline"], live: false, cleanup: false },
  { name: "mc_sync_counts_supabase_task115", args: ["sync", "counts", "--task", "TASK-115", "--source", "supabase", "--profile", "linked"], live: false, cleanup: false },
  { name: "mc_sync_counts_android_task115", args: ["sync", "counts", "--task", "TASK-115", "--source", "android"], live: false, cleanup: false },
  { name: "mc_sync_counts_ios_task115", args: ["sync", "counts", "--task", "TASK-115", "--source", "ios"], live: false, cleanup: false },
  { name: "mc_supabase_status_redacted", args: ["supabase", "status-redacted"], live: false, cleanup: false },
  { name: "mc_supabase_residue_check", args: ["supabase", "residue-check", "--prefix"], live: false, cleanup: false, prefixArg: true, profileArg: true },
  { name: "mc_live_reconcile_counts_task115", args: ["live", "reconcile-counts", "--task", "TASK-115", "--prefix"], live: true, cleanup: false, prefixArg: true },
  { name: "mc_live_sync_matrix", args: ["live", "sync-matrix", "--task", "TASK-115", "--prefix"], live: true, cleanup: false, prefixArg: true },
  { name: "mc_live_sync_matrix_task115", args: ["live", "sync-matrix", "--task", "TASK-115", "--prefix"], live: true, cleanup: false, prefixArg: true },
  { name: "mc_live_offline_matrix", args: ["live", "offline-matrix", "--task", "TASK-115", "--prefix"], live: true, cleanup: false, prefixArg: true },
];

function validatePrefix(prefix) {
  return typeof prefix === "string" &&
    /^TASK[0-9]{3,}_[A-Za-z0-9_.*-]*$/.test(prefix) &&
    !/[;&|`$<>/]/.test(prefix) &&
    !prefix.includes("..");
}

function validateTaskId(task) {
  return typeof task === "string" && /^TASK-[0-9]{3,}$/.test(task);
}

function validateEvidencePath(task, candidate) {
  if (!validateTaskId(task) || typeof candidate !== "string" || candidate.includes("..") || /[;&|`$<>]/.test(candidate)) {
    return false;
  }
  const relRoot = `docs/TASKS/EVIDENCE/${task}`;
  const absRoot = path.join(MC_IOS_REPO, relRoot);
  return candidate === relRoot ||
    candidate.startsWith(`${relRoot}/`) ||
    candidate === absRoot ||
    candidate.startsWith(`${absRoot}/`);
}

function buildArgs(tool, provided = {}) {
  if (tool.live && process.env.MC_ALLOW_LIVE !== "1") {
    throw new Error("Refused: MC_ALLOW_LIVE=1 is required by the CLI safety contract.");
  }
  if (tool.cleanup && process.env.MC_ALLOW_CLEANUP !== "1") {
    throw new Error("Refused: MC_ALLOW_CLEANUP=1 is required by the CLI safety contract.");
  }
  const args = [...tool.args];
  let task = tool.defaultTask || provided.task;
  if (tool.taskArg) {
    task = provided.task || tool.defaultTask;
    if (!validateTaskId(task)) {
      throw new Error("Invalid or missing TASK id.");
    }
    args.push(task);
  }
  if (tool.prefixArg) {
    const prefix = provided.prefix;
    if (!validatePrefix(prefix)) {
      throw new Error("Invalid or missing TASK* prefix.");
    }
    args.push(prefix);
  }
  if (tool.profileArg && provided.profile) {
    if (!["local", "linked", "dry-run-no-db"].includes(provided.profile)) {
      throw new Error("Invalid Supabase profile.");
    }
    args.push("--profile", provided.profile);
  }
  if (tool.suffixArgs) {
    args.push(...tool.suffixArgs);
  }
  if (tool.reportPathArg) {
    const reportPath = provided.path || tool.defaultPath;
    if (!validateEvidencePath(task, reportPath)) {
      throw new Error("Invalid evidence path for task.");
    }
    args.push(reportPath);
  }
  return args;
}

function compact(text, maxLines = 30) {
  return String(text || "")
    .split(/\r?\n/)
    .filter(Boolean)
    .slice(-maxLines)
    .join("\n");
}

function runMcAgent(extraArgs = [], timeoutMs = TIMEOUT_MS) {
  return new Promise((resolve) => {
    const child = spawn("bash", [MC_AGENT, ...extraArgs], {
      cwd: MC_IOS_REPO,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, timeoutMs);
    child.stdout.on("data", (d) => { stdout += d.toString(); });
    child.stderr.on("data", (d) => { stderr += d.toString(); });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({
        code: timedOut ? 2 : (code ?? 1),
        stdout: compact(stdout),
        stderr: compact(stderr),
        timedOut,
      });
    });
  });
}

async function selfTest() {
  const names = new Set(TOOLS.map((tool) => tool.name));
  if (!names.has("mc_preflight") ||
      !names.has("mc_report_task115") ||
      !names.has("mc_task118_head_consistency") ||
      !names.has("mc_task118_scan_sync_boundaries") ||
      !names.has("mc_task118_ios_test_automatic_domain") ||
      !names.has("mc_task119_scan_sync_architecture") ||
      !names.has("mc_task119_scan_manual_boundary") ||
      !names.has("mc_task119_ios_test_automatic_architecture") ||
      !names.has("mc_task120_scan_task_docs") ||
      !names.has("mc_task120_scan_harness_routing") ||
      !names.has("mc_task120_scan_source_format") ||
      !names.has("mc_task120_scan_scanner_self_tests") ||
      !names.has("mc_task120_scan_sync_architecture") ||
      !names.has("mc_task121_scan_task_docs") ||
      !names.has("mc_task121_scan_sync_inventory") ||
      !names.has("mc_task121_scan_retry_ownership") ||
      !names.has("mc_task121_scan_shared_purity") ||
      !names.has("mc_task121_scan_root_residue") ||
      !names.has("mc_task122_scan_task_docs") ||
      !names.has("mc_task122_scan_remote_transport_thin") ||
      !names.has("mc_task122_scan_adapter_delegation_depth") ||
      !names.has("mc_task122_scan_sync_efficiency_acceptance") ||
      !names.has("mc_android_test_offline") ||
      !names.has("mc_sync_counts_supabase_task115") ||
      !names.has("mc_live_sync_matrix_task115")) {
    throw new Error("allowlist missing required tool");
  }
  try {
    buildArgs({ name: "bad", args: ["preflight"], prefixArg: true }, { prefix: "TASK115_; rm -rf /" });
    throw new Error("injection prefix accepted");
  } catch (error) {
    if (!String(error.message).includes("Invalid")) throw error;
  }
  const timed = await runMcAgent(["help"], 1);
  if (!timed.timedOut && timed.code !== 0) {
    throw new Error("timeout smoke did not complete predictably");
  }
  console.log("MCP self-test PASS: allowlist, injection refusal, timeout smoke");
}

if (process.argv.includes("--self-test")) {
  await selfTest();
  process.exit(0);
}

const { Server } = await import("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = await import("@modelcontextprotocol/sdk/server/stdio.js");
const { CallToolRequestSchema, ListToolsRequestSchema } = await import("@modelcontextprotocol/sdk/types.js");

const server = new Server(
  { name: "mc-agent-mcp", version: "0.5.0-task122" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS.map((tool) => ({
    name: tool.name,
    description: `Run mc-agent.sh ${tool.args.join(" ")}`,
    inputSchema: {
      type: "object",
      properties: {
        ...(tool.prefixArg ? { prefix: { type: "string", description: "TASK* prefix required" } } : {}),
        ...(tool.taskArg ? { task: { type: "string", pattern: "^TASK-[0-9]{3,}$", description: "Task id, defaults to the tool task when omitted" } } : {}),
        ...(tool.reportPathArg ? { path: { type: "string", description: "Evidence path under docs/TASKS/EVIDENCE/<task>" } } : {}),
        ...(tool.profileArg ? { profile: { type: "string", enum: ["local", "linked", "dry-run-no-db"] } } : {}),
      },
      required: tool.prefixArg ? ["prefix"] : [],
      additionalProperties: false,
    },
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const tool = TOOLS.find((candidate) => candidate.name === request.params.name);
  if (!tool) {
    return { content: [{ type: "text", text: `Unknown tool: ${request.params.name}` }], isError: true };
  }
  try {
    const args = buildArgs(tool, request.params.arguments || {});
    const result = await runMcAgent(args);
    const text = [
      `exit_code=${result.code}`,
      result.timedOut ? "timeout=true" : "",
      result.stdout,
      result.stderr,
    ].filter(Boolean).join("\n");
    return {
      content: [{ type: "text", text }],
      isError: result.code !== 0,
    };
  } catch (error) {
    return {
      content: [{ type: "text", text: String(error.message || error) }],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
