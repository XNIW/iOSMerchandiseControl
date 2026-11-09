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
import ctypes
import struct
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
marker_rows = []
errors = []
# One bounded region avoids concurrent pre-symbolication of the same process.
# Existing markers locate the requested queue/render intervals inside the trace.
phases = {"cache-process-start": ("mainactor-admission-region", 5)}
# Reuse the existing kernel birth-identity helper, also used by local runner
# custody. A unique constant in the log predicate identifies only this stream.
birth = runpy.run_path("tools/agent/lib/artifact_lifecycle.py")["birth"]
def selected_process_environment(pid, keys):
    # KERN_PROCARGS2 is read only for an already verified owned target. Never
    # persist or print its other environment fields, including inherited secrets.
    libc = ctypes.CDLL(None, use_errno=True)
    libc.sysctl.argtypes = [ctypes.POINTER(ctypes.c_int), ctypes.c_uint,
        ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p, ctypes.c_size_t]
    libc.sysctl.restype = ctypes.c_int
    mib = (ctypes.c_int * 3)(1, 49, pid)  # CTL_KERN, KERN_PROCARGS2
    size = ctypes.c_size_t()
    if libc.sysctl(mib, 3, None, ctypes.byref(size), None, 0) != 0:
        return None
    if not 4 < size.value <= 1048576:
        return None
    buffer = ctypes.create_string_buffer(size.value)
    if libc.sysctl(mib, 3, buffer, ctypes.byref(size), None, 0) != 0:
        return None
    raw = buffer.raw[:size.value]
    argc = struct.unpack_from("i", raw)[0]
    if not 0 < argc <= 1024:
        return None
    index = raw.find(b"\0", 4)
    if index < 0:
        return None
    while index < len(raw) and raw[index] == 0:
        index += 1
    for _ in range(argc):
        end = raw.find(b"\0", index)
        if end < 0:
            return None
        index = end + 1
    result = {}
    for field in raw[index:].split(b"\0"):
        key, separator, value = field.partition(b"=")
        if separator and key in keys:
            if key in result:
                return None
            result[key] = value.decode("ascii", errors="strict")
    return result


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def record_command(pid, duration):
    return ["sudo", "-n", "/usr/sbin/spindump", str(pid), str(duration), "10",
            "-onlyTarget", "-noSymbolicate", "-noProcessingWhileSampling", "-noIPC",
            "-noText", "-noFile", "-timelimit", str(duration + 10)]

def offline_report(raw, destination, inspect_after_render=False):
    # Live image lookup is allowed only after recording AND the existing physical
    # row-render marker. It cannot perturb a captured stack or its render time.
    with destination.with_suffix(".stderr.txt").open("xb") as error:
        result = subprocess.run(["/usr/sbin/spindump", "-i", str(raw), "-o", str(destination),
            "-noBinary", "-onlyTarget", "-noIPC", "-aggregateCallTreesByThread",
            "-timestampsInCallTrees", "machabssec"]
            + (["-inspectLiveSystem"] if inspect_after_render else []), stdout=subprocess.DEVNULL,
            stderr=error, timeout=90)
    return result.returncode

def self_probe():
    probe = output / "self-probe"
    probe.mkdir(exist_ok=False)
    child = subprocess.Popen([sys.executable, "-c",
        "import time\ndeadline=time.monotonic()+35\nx=1.0\nwhile time.monotonic()<deadline:x=(x+1.0001)**0.5"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        env={**os.environ, "TASK146_IDENTITY_PROBE": "synthetic-kernel-args-v1"})
    identity = birth(child.pid)
    raw, report = probe / "self.raw.spindump", probe / "self.symbolicated.txt"
    record_exit, reparse_exit = None, None
    try:
        assert child.poll() is None and identity is not None
        assert selected_process_environment(child.pid, {b"TASK146_IDENTITY_PROBE"}) == {b"TASK146_IDENTITY_PROBE": "synthetic-kernel-args-v1"}
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
        "recordExit": record_exit, "offlineExit": reparse_exit, "processEnvironmentProbe": "PASS",
        "rawBytes": raw.stat().st_size, "reportBytes": report.stat().st_size if report.exists() else 0,
        "scope": "OWNED_PYTHON_PROBE_ONLY_NOT_APP_ACCEPTANCE"}
    proof["status"] = "PASS" if record_exit == reparse_exit == 0 and proof["reportBytes"] > 0 else "FAIL"
    (probe / "proof.json").write_text(json.dumps(proof, indent=2) + "\n")
    print(json.dumps(proof), flush=True)
    return 0 if proof["status"] == "PASS" else 87

def after_render_symbol_information(row):
    # This fixture emits owner-qualification-observed only AFTER the unchanged
    # ProductRow render boundary. Never query live images before that fact.
    process = row["process"]
    try:
        code = process.wait(timeout=25)
        row["recordFinishedAtMonotonicNs"] = time.monotonic_ns()
        if code != 0:
            return
        deadline = time.monotonic() + 15
        while not stop.is_set() and time.monotonic() < deadline:
            if birth(row["pid"]) != row["targetBirth"]:
                return
            predicate = 'processID == ' + str(row["pid"]) + ' AND eventMessage BEGINSWITH "TASK146_B2_COST39 phase.owner-qualification-observed"'
            result = subprocess.run(["xcrun", "simctl", "spawn", device, "log", "show",
                "--last", "20s", "--style", "ndjson", "--predicate", predicate],
                capture_output=True, timeout=8)
            if len(result.stdout) > 65536:
                return
            matched = re.search(rb'phase\.owner-qualification-observed uptime_ns\.(\d+)', result.stdout)
            if result.returncode == 0 and matched and birth(row["pid"]) == row["targetBirth"]:
                row["afterRenderAuthorityMarkerUptimeNs"] = int(matched[1])
                row["symbolLookupStartedAtMonotonicNs"] = time.monotonic_ns()
                symbolic = output / (row["label"] + ".symbolicated.txt")
                row["afterRenderOfflineExit"] = offline_report(row["raw"], symbolic, inspect_after_render=True)
                row["liveImageLookupScope"] = "AFTER_KERNEL_RECORDING_AND_PHYSICAL_RENDER_ONLY_SAME_PID_BIRTH"
                return
            stop.wait(0.2)
    except Exception as error:
        row["afterRenderSymbolError"] = type(error).__name__


def read_cache_process():
    # The measured log/stream closure admitted the previous sampler4.7s after
    # App.init. Detect this exact test launch at process birth instead. No stream
    # or live symbolication is attached to the application.
    seen = set()
    try:
        while not stop.is_set():
            listing = subprocess.check_output(["ps", "-ww", "-axo", "pid=,uid=,comm="],
                text=True, timeout=5)
            for line in listing.splitlines():
                fields = line.strip().split(None, 2)
                if len(fields) != 3 or int(fields[1]) != os.getuid():
                    continue
                pid, command = int(fields[0]), fields[2]
                if Path(command).name != "iOSMerchandiseControl" or device not in Path(command).parts:
                    continue
                if not command.endswith("/iOSMerchandiseControl.app/iOSMerchandiseControl"):
                    continue
                identity = birth(pid)
                if identity is None or (pid, identity["sec"], identity["usec"]) in seen:
                    continue
                environment = selected_process_environment(pid, {b"TASK146_B2_DOMAIN_UI",
                    b"TASK146_B2_LAUNCH_REQUEST_UPTIME", b"TASK144_LOCAL_AVAILABILITY_FIXTURE"})
                if environment is None or b"TASK146_B2_DOMAIN_UI" not in environment:
                    continue  # Retry only while launch environment is not available.
                seen.add((pid, identity["sec"], identity["usec"]))
                if environment[b"TASK146_B2_DOMAIN_UI"] != "cache":
                    continue
                request = float(environment[b"TASK146_B2_LAUNCH_REQUEST_UPTIME"])
                namespace = str(uuid.UUID(environment[b"TASK144_LOCAL_AVAILABILITY_FIXTURE"]))
                assert 0 < request <= time.monotonic() and time.monotonic() - request < 10
                assert birth(pid) == identity and not observations
                phase = "cache-process-start"
                label, duration = phases[phase]
                raw, stderr = output / (label + ".raw.spindump"), output / (label + ".stderr.txt")
                started = time.monotonic_ns()
                with raw.open("xb") as data, stderr.open("xb") as err:
                    process = subprocess.Popen(record_command(pid, duration), stdout=data,
                        stderr=err, start_new_session=True)
                observations[phase] = {"pid": pid, "phase": phase, "label": label,
                    "durationSeconds": duration, "samplingIntervalMilliseconds": 10,
                    "targetBirth": identity, "targetUID": os.getuid(), "namespace": namespace,
                    "requestUptime": request, "requestedAtMonotonicNs": started,
                    "requestToCollectorSeconds": started / 1e9 - request,
                    "targetIdentityVerified": True, "liveMarkerStreamCreated": False,
                    "raw": raw, "stderr": stderr, "process": process}
                after_render_symbol_information(observations[phase])
                return
            stop.wait(0.1)
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
    thread = threading.Thread(target=read_cache_process, daemon=True)
    thread.start()
    native = subprocess.Popen(sys.argv[2:])
    code = native.wait()
finally:
    stop.set()
    if thread is not None:
        thread.join(timeout=100)
        if thread.is_alive():
            errors.append("owned_process_observer_not_finalized")
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
            row["offlineExit"] = row.get("afterRenderOfflineExit")
            if row["offlineExit"] is None and result == 0 and row["rawReadComplete"]:
                row["offlineExit"] = offline_report(raw, symbolic)
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
        "symbolInformation": "Kernel onlyTarget stackshots, noSymbolicate/noProcessingWhileSampling/noIPC during capture; separate -i reparse after recorder exit; live image lookup ONLY after existing physical-render/authority marker with same PID/birth",
        "selfProbe": probe,
        "collectorFinalizationLimitSeconds": 120,
        "expectedMarkers": list(phases), "allMarkersObserved": set(observations) == set(phases),
        "interpretation": "Samples include profiler/OS overhead. Compare request, collector and actual first stackshot clocks; do not replace the original5s verdict. The startup region is diagnostic only. Use actual sample timestamps and recorded markers; no exclusive interval attribution.",
        "applicationCompilerAndTestsChanged": False,
        "ownedProfilerProcessesTerminated": all(row["exitCode"] is not None for row in rows)}
    report["diagnosticComplete"] = report["allMarkersObserved"] and not errors and all(
        row["exitCode"] == 0 and row.get("targetIdentityVerified") and row.get("liveMarkerStreamCreated") is False
        and row.get("rawReadComplete") and row.get("offlineComplete") and row.get("projectionComplete")
        and row.get("projectionScope") == "HEADER_AND_MAIN_THREAD" for row in rows)
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"samplingScope": report["scope"], "markers": len(rows),
                      "errors": errors, "nativeExit": code}), flush=True)
raise SystemExit(code if code != 0 else (0 if report["diagnosticComplete"] else 86))
