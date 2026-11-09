#!/usr/bin/env python3
"""Owned kernel stackshots with deferred offline processing; diagnostic only."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import uuid
import pty
import signal
import subprocess
import sys
import threading
import time

SELECTOR = "iOSMerchandiseControlUITests/LocalAvailabilityRootUITests/testIndependentHistoryWorkbookAndCatalogReadWhileAnotherDomainIsHeld"
assert os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch"
assert json.loads(os.environ["TASK146_FOCUSED_TESTS"]) == [SELECTOR]
assert os.environ.get("TASK144_A_CAMPAIGN", "false").lower() == "false"
probe_only = sys.argv[1:] == ["--probe-only"]
assert probe_only or (sys.argv[1] == "--" and len(sys.argv) > 2)
root = Path(os.environ["RUNNER_TEMP"]).resolve()
output = root / "task146-b2-sampling"
output.mkdir(exist_ok=not probe_only)
device = os.environ["DEVICE_ID"]
observations = {}
lock = threading.Lock()
stop = threading.Event()
native = None
log_process = None
log_stream = None
marker_rows = []
errors = []
# One bounded region avoids concurrent pre-symbolication of the same process.
# Existing markers locate the requested queue/render intervals inside the trace.
phases = {"app-init-entry": ("mainactor-admission-region", 5)}
# Reuse the existing kernel birth-identity helper, also used by local runner
# custody. A unique constant in the log predicate identifies only this stream.
birth = runpy.run_path("tools/agent/lib/artifact_lifecycle.py")["birth"]
stream_identity_tag = "TASK146_STREAM_" + uuid.uuid4().hex

def stop_owned_marker_stream():
    listing = subprocess.check_output(["ps", "-ww", "-axo", "pid=,uid=,args="], text=True, timeout=5)
    matches = []
    for line in listing.splitlines():
        fields = line.strip().split(None, 2)
        if len(fields) != 3 or stream_identity_tag not in fields[2]:
            continue
        pid, uid, command = fields
        if Path(command.split()[0]).name == "log" and " stream " in command:
            matches.append((int(pid), int(uid), command))
    if len(matches) != 1 or matches[0][1] != os.getuid():
        errors.append("owned_marker_stream_identity_not_unique")
        return None
    pid, uid, command = matches[0]
    identity = birth(pid)
    if identity is None or birth(pid) != identity:
        errors.append("owned_marker_stream_birth_changed")
        return None
    # This exact random predicate was supplied only to our just-created stream.
    # Never stop a stream from another consumer or rely on a reused numeric PID.
    os.kill(pid, signal.SIGTERM)
    stop_owned(log_process)
    deadline = time.monotonic() + 5
    while birth(pid) == identity and time.monotonic() < deadline:
        time.sleep(0.025)
    if birth(pid) == identity:
        errors.append("owned_marker_stream_did_not_exit")
        return None
    return {"pid": pid, "uid": uid, "birthIdentity": identity,
            "identityTag": stream_identity_tag, "terminatedBeforeSampling": True,
            "stoppedAtMonotonicNs": time.monotonic_ns()}

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def record_command(pid, duration):
    return ["sudo", "-n", "/usr/sbin/spindump", str(pid), str(duration), "10",
            "-onlyTarget", "-noSymbolicate", "-noProcessingWhileSampling", "-noIPC",
            "-noText", "-noFile", "-timelimit", str(duration + 10)]

def offline_report(raw, destination):
    # No inspectLiveSystem: the target is never queried for live symbol lookup.
    with destination.with_suffix(".stderr.txt").open("xb") as error:
        result = subprocess.run(["/usr/sbin/spindump", "-i", str(raw), "-o", str(destination),
            "-noBinary", "-onlyTarget", "-noIPC", "-aggregateCallTreesByThread",
            "-timestampsInCallTrees", "machabssec"], stdout=subprocess.DEVNULL,
            stderr=error, timeout=90)
    return result.returncode

def self_probe():
    probe = output / "self-probe"
    probe.mkdir(exist_ok=False)
    child = subprocess.Popen([sys.executable, "-c",
        "import time\ndeadline=time.monotonic()+35\nx=1.0\nwhile time.monotonic()<deadline:x=(x+1.0001)**0.5"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    identity = birth(child.pid)
    raw, report = probe / "self.raw.spindump", probe / "self.symbolicated.txt"
    record_exit, reparse_exit = None, None
    try:
        assert child.poll() is None and identity is not None
        with raw.open("xb") as out, (probe / "record.stderr.txt").open("xb") as error:
            record_exit = subprocess.run(record_command(child.pid, 1), stdout=out,
                stderr=error, timeout=20).returncode
    finally:
        if child.poll() is None:
            child.terminate()
        child.wait(timeout=5)
    # Decoding after target death proves this path does not require live access.
    if record_exit == 0 and 0 < raw.stat().st_size <= 16000000:
        reparse_exit = offline_report(raw, report)
    proof = {"atUTC": now(), "head": os.environ["GITHUB_SHA"],
        "scriptSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "pid": child.pid, "birth": identity, "targetExitedBeforeReparse": child.poll() is not None,
        "recordExit": record_exit, "offlineExit": reparse_exit,
        "rawBytes": raw.stat().st_size, "reportBytes": report.stat().st_size if report.exists() else 0,
        "scope": "OWNED_PYTHON_PROBE_ONLY_NOT_APP_ACCEPTANCE"}
    proof["status"] = "PASS" if record_exit == reparse_exit == 0 and proof["reportBytes"] > 0 else "FAIL"
    (probe / "proof.json").write_text(json.dumps(proof, indent=2) + "\n")
    print(json.dumps(proof), flush=True)
    return 0 if proof["status"] == "PASS" else 87

def cpu_observation(record):
    message = record.get("eventMessage", "")
    match = re.search(r"TASK146_B2_COST39 phase\.([a-z-]+) uptime_ns\.(\d+)", message)
    if not match:
        return
    phase, uptime = match.groups()
    pid = int(record.get("processID", record.get("processIdentifier", 0)))
    if pid <= 0:
        errors.append("marker_missing_process_id")
        return
    with lock:
        if len(marker_rows) < 32:
            marker_rows.append({"phase": phase, "pid": pid, "markerUptimeNs": int(uptime),
                                "deliveredAtMonotonicNs": time.monotonic_ns()})
        if phase not in phases or phase in observations or stop.is_set():
            return
        if observations and any(row["pid"] != pid for row in observations.values()):
            errors.append("cache_process_changed_between_markers")
            return
        fields = subprocess.check_output(["ps", "-p", str(pid), "-o", "uid=,comm="], text=True, timeout=5).strip().split(None, 1)
        target_birth = birth(pid)
        if len(fields) != 2 or int(fields[0]) != os.getuid() or target_birth is None or Path(fields[1]).name != "iOSMerchandiseControl":
            errors.append("marker_process_identity_mismatch")
            return
        label, duration = phases[phase]
        stream_receipt = stop_owned_marker_stream()
        if stream_receipt is None:
            return
        raw = output / (label + ".raw.spindump")
        stderr = output / (label + ".stderr.txt")
        assert birth(pid) == target_birth, "target birth changed before kernel sampler"
        started = time.monotonic_ns()
        # User-owned stdout file; root receives only this already-open descriptor.
        with raw.open("xb") as data, stderr.open("xb") as err:
            process = subprocess.Popen(record_command(pid, duration), stdout=data,
                stderr=err, start_new_session=True)
        observations[phase] = {"pid": pid, "phase": phase, "label": label,
            "durationSeconds": duration, "samplingIntervalMilliseconds": 10, "targetBirth": target_birth,
            "markerStream": stream_receipt,
            "markerUptimeNs": int(uptime), "requestedAtMonotonicNs": started,
            "deliveryDelayNs": started - int(uptime), "raw": raw, "stderr": stderr,
            "process": process}

def read_markers():
    try:
        for line in log_stream:
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
                if observations:
                    return  # The one trigger is complete; the live log stream is closed.
    except Exception as error:
        if not stop.is_set():
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

if probe_only:
    raise SystemExit(self_probe())
probe = json.loads((output / "self-probe/proof.json").read_text())
assert probe["status"] == "PASS" and probe["head"] == os.environ["GITHUB_SHA"]
assert probe["scriptSHA256"] == hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
assert probe["targetExitedBeforeReparse"]
assert not (output / "report.json").exists(), "refuse mixed diagnostic executions"

code = 97
thread = None
try:
    log_error = (output / "marker-stream.stderr.txt").open("xb")
    # A PTY makes the existing log stream line-buffered. The first collector
    # received markers2-3s late through a pipe, outside the intended intervals.
    master, slave = pty.openpty()
    log_stream = os.fdopen(master, "r", encoding="utf-8", errors="replace", buffering=1)
    log_process = subprocess.Popen(
        ["xcrun", "simctl", "spawn", device, "log", "stream", "--style", "ndjson", "--level", "debug",
         "--predicate", 'process == "iOSMerchandiseControl" AND eventMessage BEGINSWITH "TASK146_B2_COST39"'
         + ' AND "' + stream_identity_tag + '" == "' + stream_identity_tag + '"'],
        stdout=slave, stderr=log_error, stdin=subprocess.DEVNULL, start_new_session=True)
    os.close(slave)
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
    if log_stream is not None:
        log_stream.close()
    rows = []
    for phase, row in observations.items():
        process = row.pop("process")
        try:
            result = process.wait(timeout=120)
        except subprocess.TimeoutExpired:
            stop_owned(process)
            result = process.returncode
        raw = row.pop("raw")
        stderr = row.pop("stderr")
        row.update(exitCode=result, finishedAtUTC=now(), rawPath=raw.name,
                   stderrPath=stderr.name, rawBytes=raw.stat().st_size if raw.exists() else 0)
        if raw.exists():
            row["rawReadComplete"] = 0 < raw.stat().st_size <= 16000000
            row["rawSHA256"] = hashlib.sha256(raw.read_bytes()).hexdigest() if row["rawReadComplete"] else None
            symbolic = output / (row["label"] + ".symbolicated.txt")
            row["offlineExit"] = offline_report(raw, symbolic) if result == 0 and row["rawReadComplete"] else None
            row["offlinePath"] = symbolic.name
            data = symbolic.read_bytes() if symbolic.exists() and symbolic.stat().st_size <= 2000000 else b""
            row["offlineComplete"] = bool(data) and row["offlineExit"] == 0
            text = data.decode("utf-8", errors="replace")
            lines = text.splitlines()
            main = next((i for i, line in enumerate(lines) if "com.apple.main-thread" in line), None)
            if main is not None:
                end = next((i for i in range(main + 1, len(lines))
                            if re.match(r"^\s*(?:\d+\s+Thread_|Thread(?:\s|_))", lines[i])), len(lines))
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
        "nativeExit": code, "observations": rows, "markers": marker_rows, "errors": errors,
        "symbolInformation": "Kernel onlyTarget stackshots, noSymbolicate/noProcessingWhileSampling/noIPC during capture; separate offline -i reparse after recorder exit, never inspectLiveSystem",
        "selfProbe": probe,
        "collectorFinalizationLimitSeconds": 120,
        "expectedMarkers": list(phases), "allMarkersObserved": set(observations) == set(phases),
        "interpretation": "Samples include profiler/OS overhead. Compare marker and request clocks; do not replace the original5s verdict. The startup region is diagnostic only. Use actual sample timestamps and recorded markers; no exclusive interval attribution.",
        "applicationCompilerAndTestsChanged": False,
        "ownedProfilerProcessesTerminated": all(row["exitCode"] is not None for row in rows)}
    report["diagnosticComplete"] = report["allMarkersObserved"] and not errors and all(
        row["exitCode"] == 0 and row.get("markerStream", {}).get("terminatedBeforeSampling")
        and row.get("rawReadComplete") and row.get("offlineComplete") and row.get("projectionComplete")
        and row.get("projectionScope") == "HEADER_AND_MAIN_THREAD" for row in rows)
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"samplingScope": report["scope"], "markers": len(rows),
                      "errors": errors, "nativeExit": code}), flush=True)
raise SystemExit(code if code != 0 else (0 if report["diagnosticComplete"] else 86))
