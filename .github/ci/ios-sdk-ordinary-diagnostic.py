#!/usr/bin/env python3
"""One same-SDK, seed/cache comparison without XCTest; never a B2 verdict.

No compilation, debugger, profiler, AX automation, production credentials or
application edits. Existing B2 seed and cache controls use a synthetic transport.
Physical frame bounds include the entire launch request, as in the ordinary tool.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tarfile
import time
import uuid

SDK_HEAD = "6dbf2b656db1d8e582100d741cbb77af2d0053a9"
APP_TREE = "c31ef0b915869dd30cd3301c0d2a7f82e51906d7"
MANIFEST_SHA = "33b3d9c294fc08c884af3f062e4a694bd5eeee95469a594a5c571b6cd8a6a061"
PACKAGE_SHA = "589285fba7a49d361d556d17b400306c5b727150612aa66064a7e4339065b40f"
RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-26-2"
BUNDLE = "com.niwcyber.iOSMerchandiseControl"
ROOT = Path(os.environ["RUNNER_TEMP"]) / "task146-sdk-ordinary-diagnostic"
INPUT = Path(os.environ["RUNNER_TEMP"]) / "task146-sdk-input"
SIMCTL = ["xcrun", "simctl"]


def run(args, timeout=25, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          timeout=timeout, **kwargs).stdout.strip()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(name, value):
    (ROOT / name).write_text(json.dumps(value, indent=2) + "\n")


def verify_files(app, manifest):
    expected = {row["path"] for row in manifest["files"]}
    assert {p.relative_to(app).as_posix() for p in app.rglob("*") if p.is_file()} == expected
    for row in manifest["files"]:
        p = app / row["path"]
        assert not p.is_symlink() and p.stat().st_size == row["bytes"]
        assert digest(p) == row["sha256"], row["path"]


def main():
    ROOT.mkdir(exist_ok=False)
    stat = os.statvfs(ROOT)
    # Fresh hosted target plus archive expansion and bounded frames, not a build.
    assert stat.f_bavail * stat.f_frsize - 4_000_000_000 >= 30_000_000_000
    manifest_path = INPUT / "ordinary-app.manifest.json"
    assert digest(manifest_path) == MANIFEST_SHA
    manifest = json.loads(manifest_path.read_text())
    assert manifest["head"] == SDK_HEAD and manifest["appSourceTree"] == APP_TREE
    assert manifest["runID"] == "42994746252" and manifest["fileCount"] == 85
    assert run(["git", "rev-parse", "HEAD:iOSMerchandiseControl"]) == APP_TREE
    assert run(["uname", "-m"]) == manifest["architecture"] == "arm64"
    assert run(["xcodebuild", "-version"]) == manifest["xcode"] == "Xcode 26.6\nBuild version 17F113"
    profile = manifest["debugBuildProfile"]
    assert profile["SDKBuildExit"] == 0 and profile["optimization"] == "-O"
    assert profile["assertionProbe"]["status"] == "PASS_REAL_DEBUG_ASSERTION_RETAINED"
    package = INPUT / "ordinary-app.tar.gz"
    assert package.stat().st_size == manifest["packageBytes"]
    assert digest(package) == manifest["packageSHA256"] == PACKAGE_SHA
    unpack = ROOT / "sdk"
    unpack.mkdir()
    with tarfile.open(package) as archive:
        for row in archive.getmembers():
            p = Path(row.name)
            assert p.parts[0] == "iOSMerchandiseControl.app" and not p.is_absolute()
            assert ".." not in p.parts and (row.isdir() or row.isfile())
        archive.extractall(unpack, filter="data")
    app = unpack / "iOSMerchandiseControl.app"
    verify_files(app, manifest)
    assert plistlib.loads((app / "Info.plist").read_bytes())["CFBundleIdentifier"] == BUNDLE
    run(["codesign", "--verify", "--deep", "--strict", str(app)])
    assert any(r["identifier"] == RUNTIME and r["isAvailable"] for r in
               json.loads(run(SIMCTL + ["list", "runtimes", "--json"]))["runtimes"])
    name = "TASK146-SDK-only-" + os.environ["GITHUB_RUN_ID"]
    device = run(SIMCTL + ["create", name, "iPhone 16e", RUNTIME])
    assert str(uuid.UUID(device)).upper() == device
    namespace = str(uuid.uuid4())
    write("admission.json", {"scope": "DIAGNOSTIC_ONLY_NOT_ORIGINAL_FOUR_PHASE_B2",
          "sdkHead": SDK_HEAD, "appSourceTree": APP_TREE, "all85SDKPinsVerified": True,
          "device": device, "runtime": RUNTIME, "namespace": namespace,
          "noBuildDebuggerProfilerOrXCTest": True, "singleSeedSingleCache": True,
          "difference": "seed-only baseline; hold-prices/history/workbook/hold-sessions not traversed"})
    env = {k: v for k, v in os.environ.items() if not k.startswith("SIMCTL_CHILD_")}
    for key, value in {"TASK144_LOCAL_AVAILABILITY_FIXTURE": namespace,
                       "TASK131_INITIAL_TAB": "database"}.items():
        env["SIMCTL_CHILD_" + key] = value

    def launch(phase, request=None):
        child = dict(env, SIMCTL_CHILD_TASK146_B2_DOMAIN_UI=phase)
        if request is not None:
            child["SIMCTL_CHILD_TASK146_B2_LAUNCH_REQUEST_UPTIME"] = repr(request)
        output = run(SIMCTL + ["launch", "--stdout=" + str(ROOT / (phase + ".stdout")),
                     "--stderr=" + str(ROOT / (phase + ".stderr")), device, BUNDLE,
                     "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                     "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"],
                     timeout=16, env=child)
        match = re.fullmatch(re.escape(BUNDLE) + r": (\d+)", output)
        assert match, output
        return int(match[1])

    try:
        run(SIMCTL + ["boot", device])
        run(SIMCTL + ["bootstatus", device, "-b"], timeout=120)
        run(SIMCTL + ["install", device, str(app)], timeout=60)
        installed = Path(run(SIMCTL + ["get_app_container", device, BUNDLE, "app"]))
        verify_files(installed, manifest)
        data = Path(run(SIMCTL + ["get_app_container", device, BUNDLE, "data"]))
        seed_pid = launch("seed")
        workbook = data / "Library/Application Support/task144-root-fixtures" / namespace / "independent-domain-workbook.html"
        deadline = time.monotonic() + 30
        while not workbook.is_file() and time.monotonic() < deadline:
            time.sleep(0.1)
        assert workbook.is_file(), "Original seed30s preparation deadline; cache NOT_TRAVERSED"
        assert "8050000000001" in workbook.read_text()
        run(SIMCTL + ["terminate", device, BUNDLE])
        # Original T0 is before dispatch, never App.init or launch return.
        t0 = time.monotonic()
        pid = launch("cache", t0)
        returned = time.monotonic()
        frames = []
        for index in range(32):
            p = ROOT / ("frame-%02d.jpg" % index)
            lo = time.monotonic()
            run(SIMCTL + ["io", device, "screenshot", "--type=jpeg", str(p)], timeout=5)
            hi = time.monotonic()
            frames.append({"path": p.name, "loSeconds": lo-t0, "hiSeconds": hi-t0, "sha256": digest(p)})
            if hi-t0 >= 6:
                break
        write("frames.json", {"t0Uptime": t0, "launchReturnSeconds": returned-t0,
              "pid": pid, "seedPID": seed_pid, "frames": frames,
              "scope": "OBSERVATION_BOUNDS_ONLY_ALL_NEGATIVE_FRAMES_RETAINED"})
        process_env = run(["ps", "eww", "-p", str(pid), "-o", "command="])
        assert "XCTestConfigurationFilePath=" not in process_env
        assert "DYLD_INSERT_LIBRARIES=" not in process_env
        assert (str(installed / "iOSMerchandiseControl")) in process_env
        write("runtime-identity.json", {"pid": pid, "installedApp": str(installed),
              "absenceOfTestInjectionEnvironment": True, "SDKHead": SDK_HEAD})
        # Log postprocessing happens after the measured6s; no live log/AX observer.
        predicate = "processID == " + str(pid)
        logs = run(SIMCTL + ["spawn", device, "log", "show", "--last", "2m", "--info",
                            "--predicate", predicate], timeout=30)
        (ROOT / "cache-runtime.log").write_text(logs)
        write("diagnostic-complete.json", {"status": "CAPTURED_NOT_B2_QUALIFICATION", "pid": pid,
              "physicalReusedPublication": "physical-reused.true" in logs and "authority-passed.true" in logs,
              "scanMarkers": logs.count("populated-qualification-cost kind.scan entity."),
              "rowVisibleWithin5": "REQUIRES_FRAME_INSPECTION_NO_AUTOMATIC_PASS"})
    finally:
        run(SIMCTL + ["shutdown", device], timeout=30)
        devices = json.loads(run(SIMCTL + ["list", "devices", "--json"]))["devices"]
        current = [r for rows in devices.values() for r in rows if r["udid"] == device]
        assert len(current) == 1 and current[0]["state"] == "Shutdown"
        write("postflight.json", {"device": device, "state": "Shutdown", "ownedConsumersClosed": True,
              "preserved": "SDK input and controlled data until hosted-job disposal; metadata and every frame uploaded",
              "noMacDataTouched": True})


if __name__ == "__main__":
    main()
