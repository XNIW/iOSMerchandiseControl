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
  { name: "mc_report", args: ["report", "--task", "TASK-113"], live: false, cleanup: false },
  { name: "mc_ios_build_debug", args: ["ios", "build", "debug"], live: false, cleanup: false },
  { name: "mc_ios_build_release", args: ["ios", "build", "release"], live: false, cleanup: false },
  { name: "mc_ios_test_sync", args: ["ios", "test", "sync"], live: false, cleanup: false },
  { name: "mc_android_build_debug", args: ["android", "build", "debug"], live: false, cleanup: false },
  { name: "mc_android_build_release", args: ["android", "build", "release"], live: false, cleanup: false },
  { name: "mc_android_test_sync", args: ["android", "test", "sync"], live: false, cleanup: false },
  { name: "mc_android_test_offline", args: ["android", "test", "offline"], live: false, cleanup: false },
  { name: "mc_supabase_status_redacted", args: ["supabase", "status-redacted"], live: false, cleanup: false },
  { name: "mc_supabase_residue_check", args: ["supabase", "residue-check", "--prefix"], live: false, cleanup: false, prefixArg: true, profileArg: true },
  { name: "mc_live_sync_matrix", args: ["live", "sync-matrix", "--task", "TASK-113", "--prefix"], live: true, cleanup: false, prefixArg: true },
  { name: "mc_live_offline_matrix", args: ["live", "offline-matrix", "--task", "TASK-113", "--prefix"], live: true, cleanup: false, prefixArg: true },
];

function validatePrefix(prefix) {
  return typeof prefix === "string" &&
    /^TASK[0-9]{3,}_[A-Za-z0-9_.*-]*$/.test(prefix) &&
    !/[;&|`$<>/]/.test(prefix) &&
    !prefix.includes("..");
}

function buildArgs(tool, provided = {}) {
  if (tool.live && process.env.MC_ALLOW_LIVE !== "1") {
    throw new Error("Refused: MC_ALLOW_LIVE=1 is required by the CLI safety contract.");
  }
  if (tool.cleanup && process.env.MC_ALLOW_CLEANUP !== "1") {
    throw new Error("Refused: MC_ALLOW_CLEANUP=1 is required by the CLI safety contract.");
  }
  const args = [...tool.args];
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
  if (!names.has("mc_preflight") || !names.has("mc_android_test_offline")) {
    throw new Error("allowlist missing required tool");
  }
  try {
    buildArgs({ name: "bad", args: ["preflight"], prefixArg: true }, { prefix: "TASK113_; rm -rf /" });
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
  { name: "mc-agent-mcp", version: "0.2.0-task113" },
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
