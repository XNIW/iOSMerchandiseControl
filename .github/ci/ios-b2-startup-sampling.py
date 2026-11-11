#!/usr/bin/env python3
"""Owned process sampling with bounded startup admission; diagnostic only."""
import datetime
import hashlib
import gzip
import json
import os
from pathlib import Path
import re
import runpy
import uuid
import ctypes
import struct
import shutil
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
lifecycle = runpy.run_path("tools/agent/lib/artifact_lifecycle.py")
birth, BsdInfo = lifecycle["birth"], lifecycle["BsdInfo"]
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


def owned_process_paths():
    # PROC_UID_ONLY is a single kernel query, with no ps child or foreign-UID
    # command inspection. Read executable paths only; environments stay private.
    lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    lib.proc_listpids.argtypes = [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_int]
    lib.proc_listpids.restype = ctypes.c_int
    lib.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    lib.proc_pidpath.restype = ctypes.c_int
    pids = (ctypes.c_int * 8192)()
    count = lib.proc_listpids(4, os.getuid(), pids, ctypes.sizeof(pids))
    assert 0 < count < ctypes.sizeof(pids) and count % ctypes.sizeof(ctypes.c_int) == 0
    for pid in pids[:count // ctypes.sizeof(ctypes.c_int)]:
        if pid <= 0:
            continue
        path = ctypes.create_string_buffer(4096)
        size = lib.proc_pidpath(pid, path, len(path))
        if 0 < size < len(path):
            yield pid, os.fsdecode(path.value)

def cache_process_identity(pid, command, selected_device):
    if (Path(command).name != "iOSMerchandiseControl" or selected_device not in Path(command).parts
        or not command.endswith("/iOSMerchandiseControl.app/iOSMerchandiseControl")):
        return None
    lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    info = BsdInfo()
    if lib.proc_pidinfo(pid, 3, 0, ctypes.byref(info), ctypes.sizeof(info)) != ctypes.sizeof(info):
        return None
    if info.pid != pid or info.uid != os.getuid():
        return None
    identity = {"pid": pid, "sec": info.start_sec, "usec": info.start_usec}
    environment = selected_process_environment(pid, {b"TASK146_B2_DOMAIN_UI",
        b"TASK146_B2_LAUNCH_REQUEST_UPTIME", b"TASK144_LOCAL_AVAILABILITY_FIXTURE"})
    if environment is None or environment.get(b"TASK146_B2_DOMAIN_UI") != "cache":
        return None
    request = float(environment[b"TASK146_B2_LAUNCH_REQUEST_UPTIME"])
    namespace = str(uuid.UUID(environment[b"TASK144_LOCAL_AVAILABILITY_FIXTURE"]))
    if not 0 < request <= time.monotonic() or time.monotonic() - request >= 10 or birth(pid) != identity:
        return None
    return {"pid": pid, "targetBirth": identity, "targetUID": info.uid,
            "namespace": namespace, "requestUptime": request}

def probe_target_admission(probe):
    selected = str(uuid.uuid4())
    folder = probe / selected / "iOSMerchandiseControl.app"
    folder.mkdir(parents=True)
    executable = folder / "iOSMerchandiseControl"
    shutil.copyfile("/bin/sleep", executable)
    executable.chmod(0o700)
    expected_hash = hashlib.sha256(executable.read_bytes()).hexdigest()
    namespace = str(uuid.uuid4())
    child = subprocess.Popen([str(executable), "15"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        env={**os.environ, "TASK146_B2_DOMAIN_UI": "cache", "TASK146_B2_LAUNCH_REQUEST_UPTIME": str(time.monotonic()),
             "TASK144_LOCAL_AVAILABILITY_FIXTURE": namespace})
    try:
        paths = dict(owned_process_paths())
        assert paths.get(child.pid) == str(executable)
        admitted = cache_process_identity(child.pid, paths[child.pid], selected)
        assert admitted and admitted["namespace"] == namespace and admitted["targetUID"] == os.getuid()
        assert cache_process_identity(child.pid, paths[child.pid], "wrong-device") is None
        result = {"status": "PASS", "pid": child.pid, "targetUID": os.getuid(),
                  "kernelBirth": admitted["targetBirth"], "pathUIDBirthEnvironmentAndNamespace": True,
                  "wrongDeviceRejected": True, "onlySyntheticChild": True,
                  "temporaryExecutableBytes": executable.stat().st_size, "executableSHA256": expected_hash}
    finally:
        if child.poll() is None:
            child.terminate()
        child.wait(timeout=5)
        assert hashlib.sha256(executable.read_bytes()).hexdigest() == expected_hash
        executable.unlink();folder.rmdir();folder.parent.rmdir()
    result["childTerminatedAndTemporaryRemoved"] = True
    return result


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def sample_time_coverage(text, request_uptime):
    # machabssec timestamps are inspected only in the completed offline text.
    # A nonempty export alone cannot prove that startup was actually sampled.
    times = []
    for line in text.splitlines():
        if re.match(r"^\s*<\d+\.", line):
            for first, last in re.findall(r"(\d+\.\d+)s(?:-(\d+\.\d+)s)?", line):
                times.extend([float(first), float(last) if last else float(first)])
    if not times:
        return {"status": "NO_SAMPLE_TIMESTAMPS", "measuredPhasesQualified": False}
    first, last = min(times), max(times)
    overlaps = first <= request_uptime + 5 and last >= request_uptime
    return {"status": "PARTIAL_UNQUALIFIED_REQUIRES_PHASE_MATCH" if overlaps
            else "NOT_TRAVERSED_ORIGINAL_T0_5S_WINDOW",
            "firstSampleUptime": first, "lastSampleUptime": last,
            "requestToFirstSampleSeconds": first - request_uptime,
            "originalWindow": [request_uptime, request_uptime + 5],
            "measuredPhasesQualified": False}

def export_complete_offline_report(data, destination):
    # Post-recording only. Preserve every thread and image without relying on
    # the bounded main-thread preview or remote retention for a missing tail.
    if not data or len(data) > 16000000:
        return {"complete": False, "reason": "offline_text_empty_or_over_16MB"}
    encoded = gzip.compress(data, compresslevel=6, mtime=0)
    if len(encoded) > 2000000:
        return {"complete": False, "reason": "compressed_offline_text_over_2MB"}
    assert gzip.decompress(encoded) == data
    destination.write_bytes(encoded)
    return {"complete": True, "path": destination.name,
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "gzipBytes": len(encoded), "gzipSHA256": hashlib.sha256(encoded).hexdigest(),
            "scope": "ALL_THREADS_AND_IMAGES_EXACT_BYTES_NOT_A_TRUNCATED_PROJECTION"}

def record_command(pid, duration, destination):
    # sample without -mayDie gathers symbols after its bounded recording. The
    # prior kernel recorder admitted this SwiftUI target only after row render.
    # Never fall back or retry if this distinct backend also misses startup.
    return ["/usr/bin/sample", str(pid), str(duration), "10", "-file", str(destination)]


def offline_report(raw, destination, inspect_after_render=False):
    # sample already emits every thread and image after recording. Copy exact
    # bytes without another target query or a new collection.
    shutil.copyfile(raw, destination)
    return 0


def self_probe():
    probe = output / "self-probe"
    probe.mkdir(exist_ok=False)
    admission_probe = probe_target_admission(probe)
    child = subprocess.Popen([sys.executable, "-c",
        "import time\ndeadline=time.monotonic()+35\nx=1.0\nwhile time.monotonic()<deadline:x=(x+1.0001)**0.5"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        env={**os.environ, "TASK146_IDENTITY_PROBE": "synthetic-kernel-args-v1"})
    identity = birth(child.pid)
    raw, report = probe / "self.raw.sample.txt", probe / "self.symbolicated.txt"
    record_exit, reparse_exit = None, None
    try:
        assert child.poll() is None and identity is not None
        assert selected_process_environment(child.pid, {b"TASK146_IDENTITY_PROBE"}) == {b"TASK146_IDENTITY_PROBE": "synthetic-kernel-args-v1"}
        with (probe / "record.stderr.txt").open("xb") as error:
            record_exit = subprocess.run(record_command(child.pid, 1, raw), stdout=subprocess.DEVNULL,
                stderr=error, timeout=20).returncode
    finally:
        if child.poll() is None:
            child.terminate()
        child.wait(timeout=5)
    # Exact report copy after target death requires no further live access.
    if record_exit == 0 and 0 < raw.stat().st_size <= 16000000:
        reparse_exit = offline_report(raw, report)
    proof = {"atUTC": now(), "head": os.environ["GITHUB_SHA"],
        "scriptSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "pid": child.pid, "birth": identity, "targetExitedBeforeReparse": child.poll() is not None,
        "recordExit": record_exit, "offlineExit": reparse_exit, "processEnvironmentProbe": "PASS", "targetAdmissionProbe": admission_probe,
        "rawBytes": raw.stat().st_size, "reportBytes": report.stat().st_size if report.exists() else 0,
        "scope": "OWNED_PYTHON_PROBE_ONLY_NOT_APP_ACCEPTANCE", "backend": "sample-10ms-no-mayDie"}
    proof["status"] = "PASS" if record_exit == reparse_exit == 0 and proof["reportBytes"] > 0 else "FAIL"
    (probe / "proof.json").write_text(json.dumps(proof, indent=2) + "\n")
    print(json.dumps(proof), flush=True)
    return 0 if proof["status"] == "PASS" else 87

def after_render_symbol_information(row):
    # The existing marker still records the render/authority boundary. The
    # completed sample report is copied without another target query. sample
    # itself resolves symbols after its recording, not necessarily after render.
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
            if (result.returncode == 0 and matched
                and int(matched[1]) >= int(row["requestUptime"] * 1e9)
                and birth(row["pid"]) == row["targetBirth"]):
                row["afterRenderAuthorityMarkerUptimeNs"] = int(matched[1])
                row["symbolLookupStartedAtMonotonicNs"] = time.monotonic_ns()
                symbolic = output / (row["label"] + ".symbolicated.txt")
                row["afterRenderOfflineExit"] = offline_report(row["raw"], symbolic, inspect_after_render=True)
                row["liveImageLookupScope"] = "SAMPLE_DEFAULT_AFTER_RECORDING; NO_MAYDIE; COPY_AFTER_RENDER_MARKER"
                return
            stop.wait(0.2)
    except Exception as error:
        row["afterRenderSymbolError"] = type(error).__name__


def read_cache_process():
    # The measured log/stream closure admitted the previous sampler4.7s after
    # App.init. Detect this exact test launch at process birth instead. No stream
    # or live symbolication is attached to the application.
    try:
        while not stop.is_set():
            for pid, command in owned_process_paths():
                admitted = cache_process_identity(pid, command, device)
                if admitted is None:
                    continue
                identity, request, namespace = admitted["targetBirth"], admitted["requestUptime"], admitted["namespace"]
                assert birth(pid) == identity and not observations
                phase = "cache-process-start"
                label, duration = phases[phase]
                raw, stderr = output / (label + ".raw.sample.txt"), output / (label + ".stderr.txt")
                started = time.monotonic_ns()
                with stderr.open("xb") as err:
                    process = subprocess.Popen(record_command(pid, duration, raw), stdout=subprocess.DEVNULL,
                        stderr=err, start_new_session=True)
                observations[phase] = {"pid": pid, "phase": phase, "label": label,
                    "durationSeconds": duration, "samplingIntervalMilliseconds": 10,
                    "targetBirth": identity, "targetUID": os.getuid(), "namespace": namespace,
                    "requestUptime": request, "requestedAtMonotonicNs": started, "requestedAtUTC": now(),
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
            data = symbolic.read_bytes() if symbolic.exists() and symbolic.stat().st_size <= 16000000 else b""
            row["offlineComplete"] = bool(data) and row["offlineExit"] == 0
            row["completeOfflineExport"] = export_complete_offline_report(
                data, output / (row["label"] + ".all-threads.txt.gz"))
            text = data.decode("utf-8", errors="replace")
            row["sampleTimeCoverage"] = sample_time_coverage(text, row["requestUptime"])
            row["sampleTimeCoverage"]["limitation"] = "sample call trees aggregate the whole bounded capture; individual sample times and lock owner are not supplied"
            header = re.search(r"^Date/Time:\s+(.+)$", text, re.MULTILINE)
            row["sampleHeaderDateTime"] = header.group(1) if header else None
            row["sampleHeaderPIDMatches"] = bool(re.search(r"^Process:.*\[" + str(row["pid"]) + r"\]$", text, re.MULTILINE))
            row["backend"] = "sample-10ms-no-mayDie"
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
        "scope": "B2_CPU_DIAGNOSTIC_NOT_GATE_QUALIFICATION", "backend": "sample-10ms-no-mayDie",
        "nativeExit": code, "observations": rows, "markers": marker_rows, "errors": errors,
        "symbolInformation": "sample exact owned PID, 5s at10ms, no-mayDie; symbolication after bounded recording, exact all-thread text copied offline; aggregated stacks do not establish per-sample phase or owner",
        "selfProbe": probe,
        "collectorFinalizationLimitSeconds": 120,
        "expectedMarkers": list(phases), "allMarkersObserved": set(observations) == set(phases),
        "interpretation": "Samples include profiler/OS overhead. Compare request, collector and actual first stackshot clocks; do not replace the original5s verdict. The startup region is diagnostic only. Use actual sample timestamps and recorded markers; no exclusive interval attribution.",
        "applicationCompilerAndTestsChanged": False,
        "diagnosticCompleteScope": "TECHNICAL_RECORD_AND_EXPORT_ONLY; sampleTimeCoverage is not qualification of the measured phases or the original5s gate",
        "ownedProfilerProcessesTerminated": all(row["exitCode"] is not None for row in rows)}
    report["diagnosticComplete"] = report["allMarkersObserved"] and not errors and all(
        row["exitCode"] == 0 and row.get("sampleHeaderPIDMatches") and row.get("targetIdentityVerified") and row.get("liveMarkerStreamCreated") is False
        and row.get("rawReadComplete") and row.get("offlineComplete")
        and row.get("completeOfflineExport", {}).get("complete")
        and row.get("projectionScope") == "HEADER_AND_MAIN_THREAD" for row in rows)
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"samplingScope": report["scope"], "markers": len(rows),
                      "errors": errors, "nativeExit": code}), flush=True)
raise SystemExit(code if code != 0 else (0 if report["diagnosticComplete"] else 86))
