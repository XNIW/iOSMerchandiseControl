#!/usr/bin/env python3
"""Two bounded CPU observations of B2; diagnostic only, never final acceptance."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading
import time

SELECTOR = "iOSMerchandiseControlUITests/LocalAvailabilityRootUITests/testIndependentHistoryWorkbookAndCatalogReadWhileAnotherDomainIsHeld"
assert os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch"
assert json.loads(os.environ["TASK146_FOCUSED_TESTS"]) == [SELECTOR]
assert os.environ.get("TASK144_A_CAMPAIGN", "false").lower() == "false"
assert sys.argv[1] == "--" and len(sys.argv) > 2
root = Path(os.environ["RUNNER_TEMP"]).resolve()
output = root / "task146-b2-sampling"
output.mkdir(exist_ok=False)
device = os.environ["DEVICE_ID"]
observations = {}
lock = threading.Lock()
stop = threading.Event()
native = None
log_process = None
errors = []
phases = {"prepare-task-submit": ("mainactor-wait", 1),
          "prepare-task-entry": ("publication-render", 2)}

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def cpu_observation(record):
    message = record.get("eventMessage", "")
    match = re.search(r"TASK146_B2_COST39 phase\.(prepare-task-submit|prepare-task-entry) uptime_ns\.(\d+)", message)
    if not match:
        return
    phase, uptime = match.groups()
    pid = int(record.get("processID", record.get("processIdentifier", 0)))
    if pid <= 0:
        errors.append("marker_missing_process_id")
        return
    with lock:
        if phase in observations or stop.is_set():
            return
        if observations and any(row["pid"] != pid for row in observations.values()):
            errors.append("cache_process_changed_between_markers")
            return
        command = subprocess.check_output(["ps", "-p", str(pid), "-o", "comm="], text=True, timeout=5).strip()
        if Path(command).name != "iOSMerchandiseControl":
            errors.append("marker_process_identity_mismatch")
            return
        label, duration = phases[phase]
        raw = output / (label + ".sample.txt")
        stderr = output / (label + ".stderr.txt")
        started = time.monotonic_ns()
        with stderr.open("xb") as err:
            process = subprocess.Popen(
                ["/usr/bin/sample", str(pid), str(duration), "1", "-mayDie", "-file", str(raw)],
                stdout=subprocess.DEVNULL, stderr=err, start_new_session=True)
        observations[phase] = {"pid": pid, "phase": phase, "label": label,
            "durationSeconds": duration, "samplingIntervalMilliseconds": 1,
            "markerUptimeNs": int(uptime), "requestedAtMonotonicNs": started,
            "deliveryDelayNs": started - int(uptime), "raw": raw, "stderr": stderr,
            "process": process}

def read_markers():
    try:
        for line in log_process.stdout:
            if stop.is_set():
                break
            if len(line) > 16384:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(record, dict):
                cpu_observation(record)
    except Exception as error:
        errors.append(type(error).__name__)

def stop_owned(process):
    if process is None or process.poll() is not None:
        return
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)

def stop_native(signum, frame):
    stop.set()
    if native is not None and native.poll() is None:
        native.terminate()

for sig in (signal.SIGINT, signal.SIGTERM):
    signal.signal(sig, stop_native)

code = 97
thread = None
try:
    log_error = (output / "marker-stream.stderr.txt").open("xb")
    log_process = subprocess.Popen(
        ["xcrun", "simctl", "spawn", device, "log", "stream", "--style", "ndjson", "--level", "debug",
         "--predicate", 'process == "iOSMerchandiseControl" AND eventMessage BEGINSWITH "TASK146_B2_COST39"'],
        stdout=subprocess.PIPE, stderr=log_error, text=True, bufsize=1, start_new_session=True)
    thread = threading.Thread(target=read_markers, daemon=True)
    thread.start()
    native = subprocess.Popen(sys.argv[2:])
    code = native.wait()
finally:
    stop.set()
    stop_owned(log_process)
    if "log_error" in globals():
        log_error.close()
    if thread is not None:
        thread.join(timeout=6)
    rows = []
    for phase, row in observations.items():
        process = row.pop("process")
        try:
            result = process.wait(timeout=20)
        except subprocess.TimeoutExpired:
            stop_owned(process)
            result = process.returncode
        raw = row.pop("raw")
        stderr = row.pop("stderr")
        row.update(exitCode=result, finishedAtUTC=now(), rawPath=raw.name,
                   stderrPath=stderr.name, rawBytes=raw.stat().st_size if raw.exists() else 0)
        if raw.exists():
            with raw.open("rb") as source:
                data = source.read(16000001)
            row["rawReadComplete"] = len(data) <= 16000000
            text = data[:16000000].decode("utf-8", errors="replace")
            lines = text.splitlines()
            main = next((i for i, line in enumerate(lines) if "com.apple.main-thread" in line), None)
            if main is not None:
                end = next((i for i in range(main + 1, len(lines))
                            if re.match(r"^\s+\d+\s+Thread_", lines[i])), len(lines))
                selected = "\n".join(lines[:min(main, 35)] + lines[main:end]) + "\n"
                row["projectionScope"] = "HEADER_AND_MAIN_THREAD"
            else:
                selected = text
                row["projectionScope"] = "UNFILTERED_PREFIX_NOT_MAIN_THREAD_QUALIFIED"
            encoded = selected.encode()
            projected = output / (row["label"] + ".main-thread.txt")
            projected.write_bytes(encoded[:900000])
            row.update(projectionPath=projected.name, projectionComplete=len(encoded) <= 900000,
                       projectionSHA256=hashlib.sha256(projected.read_bytes()).hexdigest())
        rows.append(row)
    report = {"atUTC": now(), "head": os.environ["GITHUB_SHA"],
        "scope": "B2_CPU_DIAGNOSTIC_NOT_GATE_QUALIFICATION",
        "nativeExit": code, "observations": rows, "errors": errors,
        "expectedMarkers": list(phases), "allMarkersObserved": set(observations) == set(phases),
        "interpretation": "Samples include profiler/OS overhead. Compare marker and request clocks; do not replace the original5s verdict. Window names describe requested regions, not exclusive call attribution.",
        "applicationCompilerAndTestsChanged": False,
        "ownedProfilerProcessesTerminated": all(row["exitCode"] is not None for row in rows)}
    report["diagnosticComplete"] = report["allMarkersObserved"] and not errors and all(
        row["exitCode"] == 0 and row.get("rawReadComplete") and row.get("projectionComplete")
        and row.get("projectionScope") == "HEADER_AND_MAIN_THREAD" for row in rows)
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"samplingScope": report["scope"], "markers": len(rows),
                      "errors": errors, "nativeExit": code}), flush=True)
raise SystemExit(code if code != 0 else (0 if report["diagnosticComplete"] else 86))
