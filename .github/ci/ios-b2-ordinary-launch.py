#!/usr/bin/env python3
"""Launch B2's measured cache process normally, attach AX after observation.

The original XCTest owns seed, both held-domain phases and every assertion.
Its T0 precedes this IPC and launch. No profiler, warmup, app edit or time
subtraction; all physical frames from the existing6s window are preserved.
"""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import signal
import subprocess
import sys
import time
import uuid

BUNDLE = "com.niwcyber.iOSMerchandiseControl"
RUNNER = BUNDLE + "UITests.xctrunner"
CHANNEL = "TASK146-B2-NATIVE-LAUNCH"
ARGUMENTS = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
             "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
KEYS = {"TASK144_LOCAL_AVAILABILITY_FIXTURE", "TASK131_INITIAL_TAB",
        "TASK146_B2_DOMAIN_UI", "TASK146_B2_LAUNCH_REQUEST_UPTIME"}


def write(path, value):
    data = json.dumps(value, indent=2) + "\n"
    tmp = path.with_suffix(".tmp")
    tmp.write_text(data)
    tmp.replace(path)


def read(path):
    assert not path.is_symlink() and path.stat().st_size <= 8192
    return json.loads(path.read_text())


def request_identity(request, admission, now):
    assert request["schema"] == 1 and request["challenge"] == admission["challenge"]
    assert request["targetUDID"] == admission["targetUDID"]
    assert request["arguments"] == ARGUMENTS
    assert request["runnerPID"] > 0
    env = request["environment"]
    assert set(env) == KEYS
    namespace = str(uuid.UUID(env["TASK144_LOCAL_AVAILABILITY_FIXTURE"]))
    assert namespace == env["TASK144_LOCAL_AVAILABILITY_FIXTURE"]
    assert env["TASK131_INITIAL_TAB"] == "database" and env["TASK146_B2_DOMAIN_UI"] == "cache"
    t0 = float(env["TASK146_B2_LAUNCH_REQUEST_UPTIME"])
    assert t0 == request["requestUptime"] and 0 <= now - t0 < 10
    return namespace, t0


def current_request_channel(data_root, admission):
    """The runner's data UUID can change at install; follow only our challenge.

    MCM can move the already-admitted data directory between enumeration and
    the real runner launch. Never keep polling the old pathname, recreate an
    admission in another scope, or grant a longer request deadline.
    """
    found = []
    for container in data_root.iterdir():
        if container.is_symlink():
            continue
        metadata = container / ".com.apple.mobile_container_manager.metadata.plist"
        channel = container / "Library/Caches" / CHANNEL
        request = channel / "request.json"
        if not metadata.is_file() or not request.is_file():
            continue
        if plistlib.loads(metadata.read_bytes()).get("MCMMetadataIdentifier") != RUNNER:
            continue
        assert channel.resolve() == channel and not request.is_symlink()
        current = read(channel / "admission.json")
        if current != admission:
            continue
        found.append(channel)
    assert len(found) <= 1, "Ambiguous current runner request"
    return found[0] if found else None


def main():
    assert sys.argv[1] == "--" and len(sys.argv) > 2
    device = str(uuid.UUID(os.environ["DEVICE_ID"])).upper()
    root = Path(os.environ["RUNNER_TEMP"]) / "task146-b2-ordinary-launch"
    root.mkdir(exist_ok=False)
    data_root = Path.home() / "Library/Developer/CoreSimulator/Devices" / device / "data/Containers/Data/Application"
    lifecycle = runpy.run_path("tools/agent/lib/artifact_lifecycle.py")
    birth = lifecycle["birth"]
    BsdInfo = lifecycle["BsdInfo"]
    lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    lib.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    lib.proc_pidpath.restype = ctypes.c_int

    def executable(pid):
        info = BsdInfo()
        assert lib.proc_pidinfo(pid, 3, 0, ctypes.byref(info), ctypes.sizeof(info)) == ctypes.sizeof(info)
        assert info.pid == pid and info.uid == os.getuid()
        b = ctypes.create_string_buffer(4096)
        assert lib.proc_pidpath(pid, b, len(b)) > 0
        return Path(os.fsdecode(b.value))

    native = subprocess.Popen(sys.argv[2:])
    channel, admission, handled = None, None, False
    try:
        while native.poll() is None:
            if channel is None and data_root.is_dir():
                matches = []
                for p in data_root.iterdir():
                    m = p / ".com.apple.mobile_container_manager.metadata.plist"
                    if m.is_file() and plistlib.loads(m.read_bytes()).get("MCMMetadataIdentifier") == RUNNER:
                        matches.append(p)
                assert len(matches) <= 1, "Ambiguous owned runner container"
                if matches:
                    channel = matches[0] / "Library/Caches" / CHANNEL
                    channel.mkdir(parents=True, exist_ok=False)
                    admission = {"schema": 1, "challenge": str(uuid.uuid4()),
                                 "targetUDID": device, "nativePID": native.pid,
                                 "head": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()}
                    write(channel / "admission.json", admission)
                    write(root / "admission.json", admission)
                    write(root / "channel-custody.json", {"initial": str(channel), "moves": []})
            if channel is not None and not handled:
                current_channel = current_request_channel(data_root, admission)
                if current_channel is not None and current_channel != channel:
                    custody = read(root / "channel-custody.json")
                    custody["moves"].append({"from": str(channel), "to": str(current_channel),
                                              "observedUptime": time.monotonic()})
                    write(root / "channel-custody.json", custody)
                    channel = current_channel
            if channel is not None and not handled and (channel / "request.json").is_file():
                request = read(channel / "request.json")
                namespace, t0 = request_identity(request, admission, time.monotonic())
                assert request["channelPath"] == str(channel)
                runner_pid = request["runnerPID"]
                runner_path = executable(runner_pid)
                assert device in runner_path.parts and runner_path.parent.name.endswith(".app")
                assert runner_path.name.endswith("UITests-Runner")
                runner_birth = birth(runner_pid)
                assert runner_birth is not None
                write(root / "request.json", request)
                env = {k: v for k, v in os.environ.items() if not k.startswith("SIMCTL_CHILD_")}
                env.update({"SIMCTL_CHILD_"+k: v for k, v in request["environment"].items()})
                launched = subprocess.run(["xcrun", "simctl", "launch", device, BUNDLE] + ARGUMENTS,
                                          env=env, capture_output=True, text=True, timeout=16)
                write(root / "launch.json", {"exit": launched.returncode, "stdout": launched.stdout[:4096],
                      "stderr": launched.stderr[:4096], "returnedUptime": time.monotonic()})
                assert launched.returncode == 0
                matched = re.fullmatch(re.escape(BUNDLE) + r": (\d+)\s*", launched.stdout)
                assert matched
                pid = int(matched[1])
                app_path = executable(pid)
                assert device in app_path.parts and app_path.name == "iOSMerchandiseControl"
                assert app_path.parent.name == "iOSMerchandiseControl.app"
                app_birth = birth(pid)
                frames = []
                for i in range(32):
                    lo = time.monotonic()
                    if lo >= t0 + 6:
                        break  # A late launch return never starts post-window capture.
                    p = root / ("frame-%02d.jpg" % i)
                    frame = {"path": p.name, "loSeconds": lo-t0}
                    try:
                        captured = subprocess.run(["xcrun", "simctl", "io", device, "screenshot", "--type=jpeg", str(p)],
                            capture_output=True, timeout=min(5, t0+6-lo))
                        frame.update(status="CAPTURED" if captured.returncode == 0 else "FAILED",
                                     exitCode=captured.returncode)
                    except subprocess.TimeoutExpired:
                        # Optional diagnostic failure must not kill XCTest and
                        # discard the original row/cache/authority assertions.
                        frame["status"] = "TIMEOUT"
                    frame["hiSeconds"] = time.monotonic()-t0
                    if p.is_file():
                        frame["sha256"] = hashlib.sha256(p.read_bytes()).hexdigest()
                    frames.append(frame)
                # This is the original observation window, not app scheduling
                # or a shifted clock. Even32 fast frames cannot attach AX early.
                while True:
                    remaining = t0+6-time.monotonic()
                    if remaining <= 0:
                        break
                    time.sleep(min(.05, remaining))
                assert birth(pid) == app_birth and birth(runner_pid) == runner_birth
                response = {"schema": 1, "challenge": admission["challenge"], "pid": pid,
                            "runnerPID": runner_pid, "targetUDID": device, "namespace": namespace,
                            "requestUptime": t0, "appBirth": app_birth,
                            "executable": str(app_path), "automationMayAttachAfterUptime": time.monotonic(),
                            "originalT0And5sRetained": True, "profilerOrDebugger": False}
                write(root / "frames.json", {"pid": pid, "requestUptime": t0, "frames": frames,
                    "scope": "OPTIONAL_DIAGNOSTIC_NOT_THE_ORIGINAL_NATIVE_ROW_OR_5S_ASSERTION",
                    "windowTraversal": "ATTEMPTED" if frames else "NOT_TRAVERSED_LAUNCH_RETURN_AFTER_WINDOW"})
                write(root / "response.json", response)
                write(channel / "response.json", response)
                handled = True
            time.sleep(0.05)
        code = native.wait()
        final_channels = []
        if data_root.is_dir():
            for container in data_root.iterdir():
                metadata = container / ".com.apple.mobile_container_manager.metadata.plist"
                if metadata.is_file() and plistlib.loads(metadata.read_bytes()).get("MCMMetadataIdentifier") == RUNNER:
                    path = container / "Library/Caches" / CHANNEL
                    final_channels.append({"path": str(path), "exists": path.is_dir(),
                                           "requestPresent": (path / "request.json").is_file(),
                                           "responsePresent": (path / "response.json").is_file()})
        write(root / "channel-final.json", {"runnerOwnedChannelsAfterNativeExit": final_channels})
        write(root / "native-result.json", {"exitCode": code, "cacheRequestHandled": handled,
              "scope": "ORIGINAL_FOUR_PHASE_B2_NATIVE_ASSERTIONS_REQUIRED_NOT_A_FRAME_ONLY_PASS"})
        return code if code else (0 if handled else 1)
    except Exception as error:
        # Stop broker actions, retain its failure, and let the unchanged test
        # reach its own16s response guard and write the native result bundle.
        # The outer CI deadline still bounds this owned xcodebuild process.
        write(root / "driver-error.json", {"status": "FAIL_DRIVER",
              "errorClass": type(error).__name__, "cacheRequestHandled": handled,
              "nativeResult": "AWAITING_ORIGINAL_TEST_COMPLETION"})
        code = native.wait()
        write(root / "native-result.json", {"exitCode": code, "cacheRequestHandled": handled,
              "driverFailure": True, "scope": "NATIVE_RESULT_RETAINED_DRIVER_STILL_FAILS"})
        return code if code else 1
    finally:
        if native.poll() is None:
            native.terminate()
            try:
                native.wait(timeout=5)
            except subprocess.TimeoutExpired:
                native.kill()
                native.wait()


if __name__ == "__main__":
    raise SystemExit(main())
