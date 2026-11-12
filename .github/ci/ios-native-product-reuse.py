#!/usr/bin/env python3
"""Admit the retained f33f B2 SDK product for a CI-only driver correction."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import shutil
import subprocess
import tarfile

SOURCE_RUN = "43024699201"
SOURCE_HEAD = "f33f55c15ae01217d308cc6e3dbf48640a816c12"
MANIFEST_HASHES = {
    "ordinary-app.manifest.json": "6a06d6b8c4451df0c24a27929b1f880e912703df1c8acc9775118b991e1a6484",
    "native-test-support.manifest.json": "afc166a7564681041c1694893ad35b244cf202b08cd497d1d0221bff6883faee",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_tree(path):
    return subprocess.check_output(["git", "rev-parse", "HEAD:"+path], text=True).strip()


def extract(package, destination, pins):
    """No links, special files, extra/duplicate members or unpinned content."""
    expected = {row["path"]: row for row in pins}
    assert len(expected) == len(pins)
    parents = set()
    for name in expected:
        p = PurePosixPath(name)
        assert not p.is_absolute() and ".." not in p.parts
        parents.update(str(x) for x in p.parents if str(x) != ".")
    with tarfile.open(package, "r:gz") as archive:
        seen = set()
        for member in archive.getmembers():
            assert member.name not in seen
            seen.add(member.name)
            assert member.isfile() or member.isdir()
            if member.isdir():
                directory = PurePosixPath(member.name)
                assert not directory.is_absolute() and ".." not in directory.parts
                assert directory.parts[0] in {PurePosixPath(name).parts[0] for name in expected}
                continue
            assert member.name in expected
            row = expected[member.name]
            assert member.size == row["bytes"] and member.mode == row["mode"]
            data = archive.extractfile(member).read()
            assert hashlib.sha256(data).hexdigest() == row["sha256"]
            path = destination/member.name
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("xb") as stream:
                stream.write(data)
            path.chmod(row["mode"])
        assert {x for x in seen if x in expected} == set(expected)
    for row in pins:
        path = destination/row["path"]
        assert not path.is_symlink() and path.stat().st_size == row["bytes"]
        assert sha(path) == row["sha256"]


def validate_plan_paths(plan):
    # This immutable SDK plan has one coverage-only source prefix. It is not
    # an executable lookup and is retained byte-for-byte, including its gap.
    source_prefix = "/Users/runner/Library/Developer/Xcode/DerivedData/iOSMerchandiseControl-bbhhhqdbwqiitfbjjwnjszuswnjd/SourcePackages/checkouts/supabase-swift/Sources/Supabase/"
    old_paths = []
    def walk(value, path):
        if isinstance(value, dict):
            for key, child in value.items():
                walk(child, path+[key])
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, path+[index])
        elif isinstance(value, str) and "/Users/runner/Library/Developer/Xcode/DerivedData/" in value:
            old_paths.append((path, value))
    assert isinstance(plan, dict)
    walk(plan, [])
    assert old_paths == [(["CodeCoverageBuildableInfos", 0, "SourceFilesCommonPathPrefix"], source_prefix)]
    configurations = plan["TestConfigurations"]
    assert len(configurations) == 1
    targets = configurations[0]["TestTargets"]
    assert {target["BlueprintName"] for target in targets} == {"iOSMerchandiseControlTests", "iOSMerchandiseControlUITests"}
    for target in targets:
        name = target["BlueprintName"]
        assert target["TestBundlePath"] == "__TESTHOST__/PlugIns/"+name+".xctest"
        host = "iOSMerchandiseControlUITests-Runner.app" if name.endswith("UITests") else "iOSMerchandiseControl.app"
        assert target["TestHostPath"] == "__TESTROOT__/Debug-iphonesimulator/"+host
        if name.endswith("UITests"):
            assert target["UITargetAppPath"] == "__TESTROOT__/Debug-iphonesimulator/iOSMerchandiseControl.app"
    return {"executablePaths": "RELATIVE_TESTROOT_AND_TESTHOST_VERIFIED",
            "unchangedCoverageSourcePrefix": source_prefix,
            "coverageSourceAvailability": "NOT_EXPORTED_GAP_NOT_NATIVE_EXECUTABLE_INPUT"}


def main():
    assert os.environ["GITHUB_EVENT_NAME"] == "workflow_dispatch"
    assert os.environ["TASK146_REUSE_NATIVE_RUN"] == SOURCE_RUN
    selectors = json.loads(os.environ["TASK146_FOCUSED_TESTS"])
    assert selectors == ["iOSMerchandiseControlUITests/LocalAvailabilityRootUITests/testIndependentHistoryWorkbookAndCatalogReadWhileAnotherDomainIsHeld"]
    temporary = Path(os.environ["RUNNER_TEMP"])
    incoming = temporary/"task146-native-reuse-input"
    assert {p.name for p in incoming.iterdir()} == set(MANIFEST_HASHES) | {"ordinary-app.tar.gz", "native-test-support.tar.gz"}
    for name, digest in MANIFEST_HASHES.items():
        assert not (incoming/name).is_symlink() and sha(incoming/name) == digest
    app = json.loads((incoming/"ordinary-app.manifest.json").read_text())
    native = json.loads((incoming/"native-test-support.manifest.json").read_text())
    assert native["appManifestSHA256"] == MANIFEST_HASHES["ordinary-app.manifest.json"]
    xcode = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()
    arch = subprocess.check_output(["uname", "-m"], text=True).strip()
    for descriptor, name in [(app, "ordinary-app.tar.gz"), (native, "native-test-support.tar.gz")]:
        assert descriptor["head"] == SOURCE_HEAD and descriptor["runID"] == SOURCE_RUN and descriptor["runAttempt"] == "1"
        assert descriptor["xcode"] == xcode and descriptor["architecture"] == arch == "arm64"
        package = incoming/name
        assert package.stat().st_size == descriptor["packageBytes"] and sha(package) == descriptor["packageSHA256"]
    assert app["appSourceTree"] == git_tree("iOSMerchandiseControl")
    required = {"iOSMerchandiseControl", "iOSMerchandiseControlTests", "iOSMerchandiseControlUITests", "iOSMerchandiseControl.xcodeproj", "contracts", "Vendor 2"}
    assert set(native["sourceTrees"]) == required
    subprocess.run(["git", "diff", "--exit-code", "HEAD", "--", *sorted(required)], check=True,
                   stdout=subprocess.DEVNULL)
    assert all(git_tree(path) == pin for path, pin in native["sourceTrees"].items())
    assert app["debugBuildProfile"] == native["debugBuildProfile"]
    profile = native["debugBuildProfile"]
    assert profile["SDKBuildExit"] == 0 and profile["name"] == "DEBUG_OPTIMIZED_ASSERTIONS_CACHED_START"
    assert profile["SDKProfileVerification"]["status"] == "PASS"
    assert profile["assertionProbe"]["status"] == "PASS_REAL_DEBUG_ASSERTION_RETAINED"
    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"], text=True, timeout=20))
    selected = [(runtime, device) for runtime, rows in devices["devices"].items() for device in rows if device["udid"] == os.environ["DEVICE_ID"]]
    assert len(selected) == 1 and selected[0][0] == "com.apple.CoreSimulator.SimRuntime.iOS-26-2" and selected[0][1]["name"] == "iPhone 16e"
    bytes_to_extract = sum(x["bytes"] for x in app["files"]+native["files"])
    assert shutil.disk_usage(temporary).free-bytes_to_extract-500_000_000 >= 30_300_000_000
    products = temporary/"task146-native-reused-products"
    products.mkdir(exist_ok=False)
    app_pins = [dict(row, path="iOSMerchandiseControl.app/"+row["path"]) for row in app["files"]]
    extract(incoming/"ordinary-app.tar.gz", products/"Debug-iphonesimulator", app_pins)
    extract(incoming/"native-test-support.tar.gz", products, native["files"])
    plan = products/native["xctestrun"]
    parsed = plistlib.loads(plan.read_bytes())
    plan_paths = validate_plan_paths(parsed)
    for bundle in [products/"Debug-iphonesimulator/iOSMerchandiseControl.app", products/"Debug-iphonesimulator/iOSMerchandiseControlUITests-Runner.app"]:
        subprocess.run(["codesign", "--verify", "--strict", str(bundle)], check=True)
    (temporary/"task146-debug-build-profile.json").write_text(json.dumps(profile, indent=2)+"\n")
    receipt = {"status": "PASS_IDENTICAL_NATIVE_PRODUCTS", "sourceHead": SOURCE_HEAD, "sourceRun": SOURCE_RUN,
               "consumerHead": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
               "sourceTrees": native["sourceTrees"], "manifestSHA256": MANIFEST_HASHES, "plan": str(plan),
               "nativeFilesVerified": len(app["files"])+len(native["files"]), "architecture": arch,
               "xcode": xcode, "runtime": selected[0][0], "SDKCompilationInConsumer": "NOT_RUN_REUSED_EXACT_SOURCE_PRODUCTS",
               "nativeAcceptance": "NOT_RUN_YET", "planPaths": plan_paths}
    (temporary/"task146-native-product-reuse.json").write_text(json.dumps(receipt, indent=2)+"\n")
    with Path(os.environ["GITHUB_ENV"]).open("a") as stream:
        stream.write("TASK146_NATIVE_REUSE_PLAN="+str(plan)+"\n")
    print(json.dumps(receipt))


if __name__ == "__main__":
    main()
