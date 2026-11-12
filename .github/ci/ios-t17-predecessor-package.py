#!/usr/bin/env python3
"""Package a frozen normal T17 input; never install or launch it."""
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import tarfile
import time

SOURCE = "3a24c7ac237eb20f7e279d2deffb2213e77e0e7a"
TREE = "d68a0241ac15e4bf7f245cd46a6ae7642969dd13"
CONFIG = "154a137692161c1a1f5d1014567501428d1706945285431b7639aa5546d302cc"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    kind = os.environ.get("TASK146_T17_PACKAGE_KIND", "predecessor-debug")
    assert kind in {"predecessor-debug", "candidate-release"}
    candidate = kind == "candidate-release"
    source_head = "c4146a1583fae8e1b25df369a171897c3393da69" if candidate else SOURCE
    configuration = "Release" if candidate else "Debug"
    source = Path(os.environ["GITHUB_WORKSPACE"])/"t17-predecessor-source"
    out = Path(os.environ["RUNNER_TEMP"])/"task146-t17-predecessor"
    out.mkdir(exist_ok=False)
    report = {"status": "PREPARING", "source": source_head, "packageKind": kind,
              "configuration": configuration, "signing": "COMMITTED_AUTOMATIC_NO_OVERRIDE",
              "runtime": "NOT_RUN_PACKAGE_ONLY", "timeoutSeconds": 1200}
    def save():
        (out/"package.json").write_text(json.dumps(report, indent=2)+"\n")
    def command(args, **kwargs):
        return subprocess.check_output(args, cwd=source, text=True, timeout=30, **kwargs).strip()
    def projection():
        rows = subprocess.check_output(["git", "ls-tree", "-rz", "HEAD"], cwd=source).split(b"\0")
        pins = []
        for row in filter(None, rows):
            header, name = row.split(b"\t", 1)
            mode, kind, digest = header.decode().split()
            assert kind == "blob" and mode in {"100644", "100755", "120000"}
            path = source/os.fsdecode(name)
            data = os.fsencode(os.readlink(path)) if mode == "120000" else path.read_bytes()
            assert hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest() == digest
            pins.append({"path": os.fsdecode(name), "mode": mode, "bytes": len(data), "sha256": sha(data)})
        return pins
    save()
    started = time.monotonic()
    def bounded(args, log):
        remaining = 1200-(time.monotonic()-started)
        assert remaining > 0
        report.setdefault("commands", []).append(args)
        save()
        with (out/log).open("wb") as stream:
            process = subprocess.Popen(args, cwd=source, stdout=stream, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                code = process.wait(timeout=remaining)
            except BaseException:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise
            assert code == 0, log+" failed: "+str(code)
    try:
        assert os.environ["GITHUB_EVENT_NAME"] == "workflow_dispatch"
        assert command(["git", "rev-parse", "HEAD"]) == source_head
        report["tree"] = command(["git", "rev-parse", "HEAD^{tree}"])
        if not candidate:
            assert report["tree"] == TREE
        else:
            assert report["tree"] == "043c388e70120853771aba7ee4bac68f11987196"
            trees = {"iOSMerchandiseControl": "af49bfda2014d642f8578bfab6c5e5f63069b04b",
                     "iOSMerchandiseControl.xcodeproj": "a23a4fc2d626157a73390e83b6f6925222810ee9",
                     "iOSMerchandiseControlTests": "0c0f87dea5a9a5f3312c990c77a257bf3e8e0d44",
                     "iOSMerchandiseControlUITests": "d2ff72e0aac83f2c0536c61f5618512abe723ec1",
                     "contracts": "4343e2eb0d8f5be3da9ed841af76f8eb4fa58b1d",
                     "Vendor 2": "7f13192c6d31ccfcf9640c20ed5bf6a1ef1af892"}
            assert all(command(["git", "rev-parse", "HEAD:"+path]) == value for path, value in trees.items())
            report["nativeTrees"] = trees
            report["nativeAppSourceCorrespondence"] = "f33f55c15ae01217d308cc6e3dbf48640a816c12"
        assert command(["git", "status", "--porcelain", "--untracked-files=no"]) == ""
        assert command(["uname", "-m"]) == "arm64"
        report["xcode"] = command(["xcodebuild", "-version"])
        assert report["xcode"] == "Xcode 26.6\nBuild version 17F113"
        # Separate checkout, SPM checkout/build, native products and upload tar.
        # Conservative package-only lot; no simulator creation/boot in this job.
        report["space"] = {"beforeBytes": shutil.disk_usage(out).free,
                           "forecastBytes": 8_000_000_000, "concurrentBytes": 500_000_000,
                           "reserveBytes": 30_300_000_000}
        assert report["space"]["beforeBytes"]-8_500_000_000 >= 30_300_000_000
        pins = projection()
        (out/"source-manifest.json").write_text(json.dumps(pins, indent=2)+"\n")
        pbx = (source/"iOSMerchandiseControl.xcodeproj/project.pbxproj").read_bytes()
        assert sha(pbx) == ("3c9ef6835cf5abf7d6bb2316981265ec0975b7ce48f9d52480fa503b59e42b67" if candidate
                            else "a6b1edfa8c227aff0bcbb5d69695bcb2b0d7a1e63b58f82c681eddd342b287bd")
        assert b"PBXShellScriptBuildPhase" not in pbx
        resolved = source/"iOSMerchandiseControl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        resolved_sha = sha(resolved.read_bytes())
        assert resolved_sha == "545d4d0aba273cc38b3e41a5833e56b77513077e4d24ac939d194e5de864a4ec"
        if candidate:
            # Reuse the already verified client's public TEST resource. Inject
            # before standard build/sign; never transplant a session or DB.
            package = Path(os.environ["RUNNER_TEMP"])/"t17-config-source/predecessor-debug.app.tar.gz"
            assert sha(package.read_bytes()) == "caf5431d686fb6f65f45ae326afe61f5f493aab076f76097be93c4c168f7199b"
            with tarfile.open(package, "r:gz") as archive:
                member = archive.getmember("iOSMerchandiseControl.app/SupabaseConfig.plist")
                assert member.isfile() and member.size == 322
                data = archive.extractfile(member).read()
        else:
            data = base64.b64decode(os.environ.pop("TASK146_IOS_CONFIG_154_B64"), validate=True)
        assert sha(data) == CONFIG
        config = plistlib.loads(data)
        assert set(config) == {"PRODUCT_IMAGE_API_BASE_URL", "SUPABASE_PROJECT_URL", "SUPABASE_PUBLISHABLE_KEY"}
        assert config["SUPABASE_PROJECT_URL"] == "https://jpgoimipbothfgkokyvm.supabase.co"
        assert config["SUPABASE_PUBLISHABLE_KEY"].startswith("sb_publishable_")
        config_path = source/"iOSMerchandiseControl/SupabaseConfig.plist"
        assert not config_path.exists()
        config_path.write_bytes(data)
        config_path.chmod(0o600)
        del data, config
        project = ["-project", "iOSMerchandiseControl.xcodeproj", "-scheme", "iOSMerchandiseControl"]
        packages = ["-clonedSourcePackagesDirPath", str(out/"SourcePackages")]
        bounded(["xcodebuild", "-resolvePackageDependencies", *project, *packages,
                 "-onlyUsePackageVersionsFromResolvedFile", "-skipPackageUpdates"], "resolve.log")
        bounded(["xcodebuild", "build", *project, "-configuration", configuration, "-destination",
                 "generic/platform=iOS Simulator", "-derivedDataPath", str(out/"DerivedData"),
                 *packages, "-disableAutomaticPackageResolution", "-onlyUsePackageVersionsFromResolvedFile",
                 "-skipPackageUpdates"], "build.log")
        assert projection() == pins and sha(resolved.read_bytes()) == resolved_sha
        app = out/("DerivedData/Build/Products/"+configuration+"-iphonesimulator/iOSMerchandiseControl.app")
        assert sha((app/"SupabaseConfig.plist").read_bytes()) == CONFIG
        info = plistlib.loads((app/"Info.plist").read_bytes())
        assert info["CFBundleIdentifier"] == "com.niwcyber.iOSMerchandiseControl"
        assert info["CFBundleSupportedPlatforms"] == ["iPhoneSimulator"]
        assert not (app/"PlugIns").exists()
        subprocess.run(["codesign", "--verify", "--strict", str(app)], check=True, timeout=30)
        for name, args in [("signature.txt", ["codesign", "-d", "--verbose=4", str(app)]),
                           ("entitlements.plist", ["codesign", "-d", "--entitlements", ":-", str(app)]),
                           ("macho-load-commands.txt", ["otool", "-l", str(app/info["CFBundleExecutable"])])]:
            result = subprocess.run(args, capture_output=True, timeout=30, check=True)
            (out/name).write_bytes(result.stdout if name != "signature.txt" else result.stderr)
        macho = (out/"macho-load-commands.txt").read_text()
        assert "__entitlements" in macho and "__ents_der" in macho
        files = []
        for path in sorted(app.rglob("*")):
            assert not path.is_symlink()
            if path.is_file():
                payload = path.read_bytes()
                files.append({"path": str(path.relative_to(app)), "bytes": len(payload),
                              "mode": path.stat().st_mode & 0o777, "sha256": sha(payload)})
        (out/"app-manifest.json").write_text(json.dumps(files, indent=2)+"\n")
        package_name = kind+".app.tar.gz"
        with tarfile.open(out/package_name, "w:gz") as archive:
            archive.add(app, arcname="iOSMerchandiseControl.app")
        report.update(status="PASS_PACKAGE_ONLY_PENDING_COMPATIBILITY_REVIEW", configSHA256=CONFIG,
                      sourceFiles=len(pins), appFiles=len(files),
                      executableSHA256=sha((app/info["CFBundleExecutable"]).read_bytes()),
                      packageFile=package_name, packageSHA256=sha((out/package_name).read_bytes()))
    except BaseException as error:
        report.update(status="FAIL_PACKAGE", errorType=type(error).__name__, error=str(error))
        raise
    finally:
        report.update(elapsedSeconds=time.monotonic()-started, freeAfterBytes=shutil.disk_usage(out).free)
        save()
        print(json.dumps(report))


if __name__ == "__main__":
    main()
