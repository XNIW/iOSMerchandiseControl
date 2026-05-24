const TIMEOUT_MS = 1000;
const TOOLS = [
  { name: "mc_task120_scan_task_docs" },
  { name: "mc_task120_scan_harness_routing" },
  { name: "mc_task120_scan_source_format" },
  { name: "mc_task120_scan_scanner_self_tests" },
  { name: "mc_task120_scan_sync_architecture" }
];
function runMcAgent() {
  setTimeout(() => {}, TIMEOUT_MS);
  return spawn("bash", ["mc-agent.sh"], { cwd: MC_IOS_REPO });
}
