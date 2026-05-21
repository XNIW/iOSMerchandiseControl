#!/usr/bin/env node
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const agent = path.resolve(__dirname, "..", "mc-agent.sh");
const server = path.resolve(__dirname, "server.mjs");

function run(command, args, env = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env, ...env },
    });
    let out = "";
    child.stdout.on("data", (data) => { out += data.toString(); });
    child.stderr.on("data", (data) => { out += data.toString(); });
    child.on("close", (code) => resolve({ code: code ?? 1, out }));
  });
}

const preflight = await run("bash", [agent, "preflight"]);
console.log("mc_preflight wrapper:", preflight.code === 0 || preflight.code === 2 ? "OK" : "FAIL", preflight.code);

const report = await run("bash", [agent, "report", "--task", "TASK-113"]);
console.log("mc_report wrapper:", report.code === 0 || report.code === 2 ? "OK" : "FAIL", report.code);

const self = await run("node", [server, "--self-test"], { MC_MCP_TIMEOUT_MS: "1" });
console.log("mcp self-test:", self.code === 0 ? "OK" : "FAIL", self.code);
if (self.code !== 0) {
  console.log(self.out);
}

process.exit((preflight.code === 3 || report.code === 3 || self.code !== 0) ? 1 : 0);
