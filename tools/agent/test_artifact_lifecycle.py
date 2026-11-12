#!/usr/bin/env python3
"""Finite tiny-directory/process tests. No SDK, dependency download or Git mutation."""
import argparse
import importlib.util
import json
import os
import plistlib
from pathlib import Path
import signal
import sqlite3
import shutil
import subprocess
import sys
import time
import unittest
import uuid
import zipfile
from unittest.mock import patch

sys.dont_write_bytecode = True
HELPER = Path(__file__).parent / "lib/artifact_lifecycle.py"
spec = importlib.util.spec_from_file_location("artifact_lifecycle", HELPER)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
ROOT = Path(os.environ.get("MC_ARTIFACT_TEST_ROOT", "/Users/minxiang/DiskSpaceReports/maintenance-20261105/prevention/lifecycle-fixtures"))
REPO = Path(__file__).resolve().parents[2]


def args(**values):
    return argparse.Namespace(**values)


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.base = ROOT / uuid.uuid4().hex
        self.root = self.base / "agent-runs/managed-artifacts"
        self.reg = m.Registry(self.root)
        self.context = {"repo": str(REPO), "head": "fixture", "delta_sha256": "fixture",
                        "complete": True, "clean_inputs": False, "toolchain": {}}
        self.source = patch.object(m, "source_context", return_value=self.context)
        self.deps = patch.object(m, "dependencies", return_value={"complete": True, "pins": []})
        self.source.start()
        self.deps.start()
        self.addCleanup(self.source.stop)
        self.addCleanup(self.deps.stop)
        self.base.mkdir(parents=True, exist_ok=True)
        self.diag = self.base / "diagnostic.log"
        self.diag.write_text("unique diagnostic\n")

    def begin(self, **overrides):
        values = dict(run_id=uuid.uuid4().hex, owner=os.getpid(), repo=str(REPO),
                      command="fixture only", pin=[], retry_pending=False, final_evidence=False, dependency_root=None)
        values.update(overrides)
        with self.reg.exclusive():
            return self.reg.begin(args(**values))

    def test_quiescent_cli_blocks_until_native_consumers_terminate(self):
        token = self.begin()
        argv = [str(HELPER), "--root", str(self.root), "quiescent", "--run", token]
        with patch.object(sys, "argv", argv), patch.object(m.Registry, "quiescent", return_value=False) as check:
            self.assertEqual(m.main(), 2)
            check.assert_called_once()
            self.assertEqual(check.call_args.kwargs, {"for_cleanup": False})
        with patch.object(sys, "argv", argv), patch.object(m.Registry, "quiescent", return_value=True):
            self.assertEqual(m.main(), 0)

    def output(self, token, kind="integral-result", config="Debug"):
        with self.reg.exclusive():
            path = Path(self.reg.path(args(run=token, kind=kind, configuration=config)))
        path.mkdir(parents=True, exist_ok=True)
        (path / "fixture.bin").write_bytes(b"compiled fixture")
        if kind == "products":
            (path / "Build/Products").mkdir(parents=True, exist_ok=True)
            (path / "Build/Products/app.bin").write_bytes(b"generated app")
            db = path / "Build/Intermediates.noindex/XCBuildData/build.db"
            db.parent.mkdir(parents=True, exist_ok=True)
            db.write_bytes(b"SQLite format 3\0" + b"generated Xcode database")
        return path

    def finish(self, token, code=0):
        report = self.base / (token + ".json")
        report.write_text(json.dumps({"registry_token": token, "exit_code": code,
                                      "diagnostic_paths": [str(self.diag)]}))
        with self.reg.exclusive():
            self.reg.finish(args(run=token, code=code, report=str(report)))

    def clean(self, apply=False):
        with self.reg.exclusive():
            return self.reg.clean(apply)

    def release(self, token, closed):
        receipt = self.base / (token + ".release.json")
        receipt.write_text(json.dumps({"registry_token": token, "disposition": "products_superseded",
                                       "consumers_complete": True, "retry_pending": False,
                                       "closed_pins": closed, "reason": "fixture successor qualified",
                                       "diagnostic_paths": [str(self.diag)]}))
        with self.reg.exclusive():
            self.reg.release_products(args(run=token, receipt=str(receipt)))

    def test_completed_result_deleted_latest_two_kept_and_idempotent(self):
        outputs = []
        for _ in range(3):
            token = self.begin()
            outputs.append(self.output(token))
            self.finish(token)
        analysis = self.clean()
        self.assertTrue(outputs[0].exists())
        self.assertEqual([r["path"] for r in analysis["eligible"]], [str(outputs[0])])
        result = self.clean(True)
        self.assertEqual(result["removed_outputs"], [str(outputs[0])])
        self.assertTrue(all(p.exists() for p in outputs[1:]))
        self.assertEqual(self.clean(True)["removed_outputs"], [])

    def test_generated_build_db_allowed_real_app_database_protected(self):
        first = self.begin(pin=["pending-native"])
        old = self.output(first, "products")
        self.finish(first)
        for _ in range(2):
            token = self.begin()
            self.output(token, "products")
            self.finish(token)
        self.assertTrue(old.exists())
        self.release(first, ["pending-native"])
        self.assertIn(str(old), self.clean(True)["removed_outputs"])
        active = self.begin()
        protected = self.output(active)
        (protected / "app.sqlite").write_bytes(b"SQLite format 3\0data")
        self.assertRaises(m.Hold, m.tree, protected)


    def generated_metadata(self, root, product=False):
        database = root / ("XCBuildData/build.db" if product else "database.sqlite3")
        database.parent.mkdir(parents=True, exist_ok=True)
        if database.exists():
            database.unlink()  # Only this test's tiny generated placeholder.
        names = {"info", "key_names", "rule_results"} if product else set("""Actions Activities
Arguments Attachments BuildIssues DeveloperTools Devices DocumentLocations ExpectedFailures Expressions
Invocations IssueTrackingMetadata Parameters PerformanceMetrics Platforms RepetitionPolicies RunDestinations
SDKs SkipNotices SourceCodeContexts SourceCodeFrames SourceCodeLocations SourceCodeSymbolInfos
TestCaseResultsByDestinationAndConfiguration TestCaseRuns TestCases TestDocumentations TestErrors TestIssues
TestPlanConfigurations TestPlanRuns TestPlans TestSuiteRuns TestSuites TestTags TestValues TestableRuns
Testables UserInfoKeyValues UserInfos""".split())
        connection = sqlite3.connect(database)
        try:
            for name in names:
                connection.execute('CREATE TABLE "' + name + '" (fixture TEXT)')
            connection.commit()
        finally:
            connection.close()
        if not product:
            root_hash = "0~" + "A" * 86 + "=="
            data = root / "Data"; data.mkdir(exist_ok=True)
            (data / ("data." + root_hash)).write_bytes(b"generated result root fixture")
            (root / "Info.plist").write_bytes(plistlib.dumps({
                "dateCreated": m.dt.datetime(2026, 11, 7), "directoryImportMode": "concurrent",
                "externalLocations": [], "rootId": {"hash": root_hash},
                "storage": {"backend": "fileBacked2", "compression": "standard"},
                "version": {"major": 3, "minor": 60}}))
        return database

    def test_registered_xcresult_metadata_cleanup_keeps_last_two_and_no_original_db_write(self):
        outputs = []
        for _ in range(3):
            token = self.begin(); root = self.output(token); self.generated_metadata(root)
            outputs.append(root); self.finish(token)
        original = (outputs[0] / "database.sqlite3").read_bytes()
        self.assertRaises(m.Hold, m.tree, outputs[0])
        self.assertEqual((outputs[0] / "database.sqlite3").read_bytes(), original)
        self.assertEqual(self.clean(True)["removed_outputs"], [str(outputs[0])])
        self.assertTrue(all(p.exists() for p in outputs[1:]))
        self.assertFalse(any(p.exists() for p in [outputs[1] / "database.sqlite3-wal", outputs[1] / "database.sqlite3-shm"]))

    def test_xcresult_metadata_requires_registered_kind_format_and_schema(self):
        for failure in ("unregistered", "wrong-kind", "wrong-info", "app-schema", "extra-app-db", "missing-root-reference"):
            with self.subTest(failure=failure):
                token = self.begin(); root = self.output(token); database = self.generated_metadata(root)
                if failure == "unregistered":
                    self.reg.read(token)
                    run = self.reg.read(token); run["outputs"] = []; self.reg.save(run)
                elif failure == "wrong-kind":
                    run = self.reg.read(token); run["outputs"][0]["kind"] = "integral-directory"; self.reg.save(run)
                elif failure == "wrong-info":
                    value = plistlib.loads((root / "Info.plist").read_bytes()); value["version"]["minor"] = 61
                    (root / "Info.plist").write_bytes(plistlib.dumps(value))
                elif failure == "app-schema":
                    connection = sqlite3.connect(database); connection.execute("CREATE TABLE Products (id TEXT)"); connection.close()
                elif failure == "extra-app-db":
                    (root / "Data/app.sqlite").write_bytes(b"SQLite format 3\0persistent app data")
                else:
                    next((root / "Data").iterdir()).unlink()
                self.assertRaises(m.Hold, m.tree, root, self.reg)
                self.assertTrue(database.exists())

    def test_registered_intermediate_component_allows_only_build_metadata(self):
        token = self.begin(); root = self.output(token, "products")
        component = root / "Build/Intermediates.noindex"; self.generated_metadata(component, product=True)
        self.assertRaises(m.Hold, m.tree, component)
        with self.reg.exclusive():
            m.remove_tree(component, self.reg)
        self.assertFalse(component.exists()); self.assertTrue((root / "Build/Products/app.bin").exists())
        for failure in ("unregistered", "app-schema", "extra-app-db"):
            with self.subTest(failure=failure):
                token = self.begin(); root = self.output(token, "products")
                component = root / "Build/Intermediates.noindex"; database = self.generated_metadata(component, product=True)
                if failure == "unregistered":
                    run = self.reg.read(token); run["outputs"] = []; self.reg.save(run)
                elif failure == "app-schema":
                    connection = sqlite3.connect(database); connection.execute("CREATE TABLE Products (id TEXT)"); connection.close()
                else:
                    (component / "app.sqlite").write_bytes(b"SQLite format 3\0persistent app data")
                self.assertRaises(m.Hold, m.remove_tree, component, self.reg)
                self.assertTrue(database.exists()); self.assertTrue((root / "Build/Products/app.bin").exists())

    def test_xcresult_database_signature_sidecars_and_opaque_app_payload_stay_protected(self):
        for failure in ("signature", "sidecar", "opaque-sqlite"):
            with self.subTest(failure=failure):
                token = self.begin(); root = self.output(token); database = self.generated_metadata(root)
                if failure == "signature":
                    database.write_bytes(b"not an SQLite metadata database")
                elif failure == "sidecar":
                    (root / "database.sqlite3-wal").write_bytes(b"still unqualified sidecar")
                else:
                    (root / "Data/opaque.bin").write_bytes(b"SQLite format 3\0persistent app data")
                self.assertRaises(m.Hold, m.remove_tree, root, self.reg)
                self.assertTrue(database.exists())

    def test_reused_products_remain_until_the_registered_consumer_finishes(self):
        first = self.begin()
        old = self.output(first, "products")
        self.finish(first)
        consumer = self.begin()
        with self.reg.exclusive():
            reused = self.reg.reuse_products(args(run=consumer, configuration="Debug"))
        self.assertEqual(reused, str(old))
        successor = self.begin()
        current = self.output(successor, "products")
        self.finish(successor)
        self.assertEqual(self.clean(True)["removed_outputs"], [])
        self.finish(consumer)
        self.assertEqual(self.clean(True)["removed_outputs"], [str(old)])
        self.assertTrue(current.exists())

    def rebuild_fixture(self):
        prior = self.begin()
        products = self.output(prior, "products")
        self.finish(prior, 1)
        self.context.update(head="new-" + uuid.uuid4().hex, delta_sha256="changed-source")
        run = self.begin()
        with self.reg.exclusive():
            self.reg.lease(args(run=run, action="lease-acquire"))
        archive = self.base / ("historical-products-" + prior)
        shutil.copytree(products / "Build/Products", archive)
        old, new = self.reg.read(prior), self.reg.read(run)
        files = []
        for source, source_stat in m.tree(products / "Build/Products"):
            if not source.is_file():
                continue
            relative = str(source.relative_to(products / "Build/Products"))
            files.append(dict(path=relative, size=source_stat.st_size, sha256=m.file_sha256(source),
                              source_identity=m.file_identity(source_stat),
                              archive_identity=m.file_identity((archive / relative).lstat())))
        proof = self.base / (run + ".rebuild-proof.json")
        proof.write_text(json.dumps(dict(schema=1, run=run, prior_run=prior, configuration="Debug",
            source_products=str(products / "Build/Products"), archive_products=str(archive),
            prior_inputs=old["inputs"], new_inputs=new["inputs"], prior_commit=old["inputs"]["head"],
            new_commit=new["inputs"]["head"], owner=os.getuid(), dependency_root=new["dependency_root"],
            all_hashes_match=True, consumers_complete=True, unattributed_consumers_reviewed_closed=True,
            reason="fixture incremental rebuild", release_condition="first failure closes", files=files)))
        return args(run=run, prior=prior, configuration="Debug", archive=str(archive), proof=str(proof)), products

    def test_rebuild_products_transfers_ownership_and_retains_historical_products(self):
        for action in (None, "test-without-building", "source-changed", "build-for-testing"):
            request, products = self.rebuild_fixture()
            with self.reg.exclusive():
                self.assertEqual(self.reg.rebuild_products(request), str(products))
            old, new = self.reg.read(request.prior), self.reg.read(request.run)
            self.assertNotEqual(old["inputs"], new["inputs"])
            self.assertEqual(old["status"], "failed")
            self.assertEqual(old["outputs"][0]["reused_by"], request.run)
            self.assertEqual(old["outputs"][0]["historical_products"], request.archive)
            self.assertTrue(new["outputs"][0]["managed"])
            self.assertTrue(new["outputs"][0]["requires_rebuild"])
            self.assertFalse(new["outputs"][0]["valid_products"])
            if action:
                token = uuid.uuid4().hex
                execution = dict(state="terminal", raw_returncode=0, observed=[], pgid=-999999,
                    command=["/usr/bin/xcodebuild", "-derivedDataPath", str(products),
                             "build-for-testing" if action == "source-changed" else action])
                m.write_json(self.root / "executions" / (token + ".json"), execution)
                new["executions"].append(token)
                with self.reg.exclusive():
                    self.reg.save(new)
                if action == "source-changed":
                    self.context.update(delta_sha256="changed-after-compile")
            self.finish(request.run)
            self.assertEqual(self.reg.read(request.run)["outputs"][0]["valid_products"],
                             action == "build-for-testing", action)
            self.assertEqual((Path(request.archive) / "app.bin").read_bytes(), b"generated app")
            with self.reg.exclusive():
                self.reg.lease(args(run=request.run, action="lease-release"))
        for flag in ("-showBuildSettings", "-showdestinations", "-list", "-resolvePackageDependencies", "-dry-run", "-n"):
            probe = dict(execution, command=execution["command"] + [flag])
            self.assertFalse(m._completed_xcode_build(probe, products), flag)
        for flag in ("timed_out", "cancel_signal", "monitor_error"):
            self.assertFalse(m._completed_xcode_build(dict(execution, **{flag: True}), products), flag)

    def test_rebuild_products_rejects_live_consumers_and_changed_archive_proof(self):
        request, products = self.rebuild_fixture()
        with self.reg.exclusive(), patch.object(self.reg, "quiescent", return_value=False):
            self.assertRaises(m.Hold, self.reg.rebuild_products, request)
        consumer = self.begin(retry_pending=True)
        with self.reg.exclusive():
            self.reg.reference(args(run=consumer, path=str(products), kind="products", configuration="Debug"))
        self.finish(consumer)
        with self.reg.exclusive():
            self.assertRaises(m.Hold, self.reg.rebuild_products, request)
        self.release(consumer, [])
        proof_path = Path(request.proof)
        original_proof = json.loads(proof_path.read_text())
        for missing in ("dependency_root", "path"):
            malformed = json.loads(json.dumps(original_proof))
            if missing == "path":
                del malformed["files"][0][missing]
            else:
                del malformed[missing]
            proof_path.write_text(json.dumps(malformed))
            with self.reg.exclusive():
                self.assertRaises(m.Hold, self.reg.rebuild_products, request)
        proof_path.write_text(json.dumps(original_proof))
        native = subprocess.CompletedProcess([], 0, stdout="p999999\nn" + str(products / "app.bin") + "\n", stderr="")
        with self.reg.exclusive(), patch.object(m.subprocess, "run", return_value=native):
            self.assertRaises(m.Hold, self.reg.rebuild_products, request)
        copied = Path(request.archive) / "app.bin"
        replacement = copied.with_suffix(".replacement")
        replacement.write_bytes(copied.read_bytes())
        os.replace(replacement, copied)
        with self.reg.exclusive():
            self.assertRaises(m.Hold, self.reg.rebuild_products, request)
        proof = json.loads(proof_path.read_text())
        proof["files"][0]["archive_identity"] = m.file_identity(copied.lstat())
        proof_path.write_text(json.dumps(proof))
        before = copied.stat()
        copied.write_bytes(b"X" * before.st_size)
        os.utime(copied, ns=(before.st_atime_ns, before.st_mtime_ns))
        with self.reg.exclusive():
            self.assertRaises(m.Hold, self.reg.rebuild_products, request)
        self.assertNotIn("reused_by", self.reg.read(request.prior)["outputs"][0])
        self.assertEqual(self.reg.read(request.run)["outputs"], [])
        self.assertEqual(list(self.root.glob("rebuild-transfer-*.json")), [])
        self.assertEqual((products / "Build/Products/app.bin").read_bytes(), b"generated app")

    def test_rebuild_products_interrupted_transfer_preserves_both_copies(self):
        request, products = self.rebuild_fixture()
        save = self.reg.save
        def interrupted(run):
            if run["token"] == request.run:
                raise OSError("fixture crash before successor registry save")
            save(run)
        with self.reg.exclusive(), patch.object(self.reg, "save", side_effect=interrupted):
            self.assertRaises(OSError, self.reg.rebuild_products, request)
        journal = json.loads((self.root / ("rebuild-transfer-" + request.run + ".json")).read_text())
        self.assertEqual(journal["state"], "prepared")
        self.assertEqual(self.clean(True)["removed_outputs"], [])
        self.assertTrue((products / "Build/Products/app.bin").exists())
        self.assertTrue((Path(request.archive) / "app.bin").exists())

    def test_active_retry_pin_final_and_external_symlink_kept(self):
        protected = []
        for settings in ({}, {"retry_pending": True}, {"pin": ["open-issue"]}, {"final_evidence": True}):
            token = self.begin(**settings)
            protected.append(self.output(token, config=uuid.uuid4().hex))
            if settings:
                self.finish(token)
        external = self.base / "important"
        external.mkdir()
        (external / "keep").write_text("personal fixture")
        linked_run = self.begin()
        linked = self.output(linked_run, config="linked")
        (linked / "external").symlink_to(external, target_is_directory=True)
        self.finish(linked_run)
        self.clean(True)
        self.assertTrue(all(p.exists() for p in protected))
        self.assertEqual((external / "keep").read_text(), "personal fixture")
        self.assertRaises(m.Hold, m.tree, linked)

    def test_mixed_android_apk_result_requires_available_inputs(self):
        outputs = []
        for _ in range(3):
            token = self.begin()
            directory = self.output(token, kind="integral-directory")
            (directory / "copy.apk").write_bytes(b"generated APK fixture")
            outputs.append(directory)
            self.finish(token)
            self.assertTrue(self.reg.read(token)["outputs"][0]["requires_rebuild"])
        with patch.object(m, "dependencies", return_value={"complete": False}):
            result = self.clean(True)
        self.assertEqual(result["removed_outputs"], [])
        self.assertTrue(all(path.exists() for path in outputs))

    def test_exclusive_lease_nonce_prevents_concurrent_owner(self):
        one, two = self.begin(), self.begin()
        with self.reg.exclusive():
            self.reg.lease(args(run=one, action="lease-acquire"))
            self.assertRaises(m.Hold, self.reg.lease, args(run=two, action="lease-acquire"))
            self.assertRaises(m.Hold, self.reg.lease, args(run=two, action="lease-release"))
            self.reg.lease(args(run=one, action="lease-release"))
            self.reg.lease(args(run=two, action="lease-acquire"))
            self.reg.lease(args(run=two, action="lease-release"))

    def test_timeout_and_sdk_failure_survive_overall_success(self):
        token = self.begin()
        rc = m.execute(self.reg, args(run=token, timeout=0.2,
                                     argv=[sys.executable, "-c", "import time; time.sleep(4)"]))
        self.assertEqual(rc, 124)
        self.finish(token, 0)  # Models a legacy runtime fallback returning aggregate PASS.
        run = self.reg.read(token)
        self.assertIn("sdk_failure_diagnostic_and_retry", run["pins"])
        self.assertTrue(run["retry_pending"])
        execution = json.loads(next((self.root / "executions").iterdir()).read_text())
        self.assertTrue(execution["timed_out"])
        self.assertNotEqual(execution["raw_returncode"], 0)

    def test_harmless_execution_becomes_quiescent(self):
        token = self.begin()
        # This isolated program cannot spawn children. Detached-child attribution
        # is exercised by the separate real-child test below; unrelated host
        # arrivals must not turn this fixture into a global-idleness requirement.
        with patch.object(m, "unattributed_survivors", return_value=[]):
            rc = m.execute(self.reg, args(run=token, timeout=0, argv=[sys.executable, "-I", "-S", "-c", "pass"]))
        self.assertEqual(rc, 0)
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            if self.reg.quiescent(self.reg.read(token)):
                break
            time.sleep(0.05)
        self.assertTrue(self.reg.quiescent(self.reg.read(token)))

    def test_detached_child_with_and_without_environment_blocks_cleanup(self):
        for drop_environment in (False, True):
            token = self.begin()
            pidfile = self.base / (uuid.uuid4().hex + ".pid")
            child = "import os,time;open(" + repr(str(pidfile)) + ",'w').write(str(os.getpid()));time.sleep(1.6)"
            program = "import subprocess,sys,time;time.sleep(.03);subprocess.Popen([sys.executable,'-c'," + repr(child) + "],start_new_session=True" + (",env={}" if drop_environment else "") + ")"
            rc = m.execute(self.reg, args(run=token, timeout=0, argv=[sys.executable, "-c", program]))
            self.assertEqual(rc, 0)
            self.assertTrue(pidfile.exists())
            self.assertIsNotNone(m.birth(int(pidfile.read_text())))
            self.assertFalse(self.reg.quiescent(self.reg.read(token)))
            time.sleep(1.8)  # Owned fixture ends naturally; no external process is signalled.

    def test_signal_preserves_raw_exit_and_diagnostic_metadata(self):
        token = self.begin()
        process = subprocess.Popen([sys.executable, str(HELPER), "--root", str(self.root), "exec",
                                    "--run", token, "--", sys.executable, "-c", "import time;time.sleep(5)"])
        deadline = time.monotonic() + 3
        while not list((self.root / "executions").iterdir()) and time.monotonic() < deadline:
            time.sleep(0.02)
        process.send_signal(signal.SIGTERM)
        self.assertEqual(process.wait(timeout=5), 143)
        execution = json.loads(next((self.root / "executions").iterdir()).read_text())
        self.assertEqual(execution["cancel_signal"], signal.SIGTERM)
        self.assertNotEqual(execution["raw_returncode"], 0)

    def test_two_cleanup_processes_do_not_delete_twice(self):
        outputs = []
        for _ in range(3):
            token = self.begin()
            outputs.append(self.output(token))
            self.finish(token)
        command = [sys.executable, str(HELPER), "--root", str(self.root), "cleanup", "--apply"]
        processes = [subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
        removed = []
        for process in processes:
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, stderr)
            removed.extend(json.loads(stdout)["removed_outputs"])
        self.assertEqual(removed, [str(outputs[0])])
        self.assertTrue(all(p.exists() for p in outputs[1:]))

    def test_source_context_covers_tests_vendor_and_configuration(self):
        required = {"iOSMerchandiseControlTests", "iOSMerchandiseControlUITests", "Vendor", "Vendor 2", "Configuration"}
        seen = []
        def fake_git(command, **kwargs):
            seen.append(command)
            return b"fixture-head\n" if "rev-parse" in command else b""
        self.source.stop()
        with patch.object(m.subprocess, "check_output", side_effect=fake_git):
            m.source_context(REPO)
        diff = next(c for c in seen if "diff" in c)
        self.assertTrue(required.issubset(set(diff)))
        self.source.start()

    def test_bash32_artifact_begin_preserves_mandatory_and_optional_arguments(self):
        common = HELPER.parent / "common.sh"
        optional_keys = ("MC_ARTIFACT_PIN_REASON", "MC_ARTIFACT_RETRY_PENDING",
                         "MC_ARTIFACT_FINAL_EVIDENCE", "MC_IOS_SOURCE_PACKAGES_DIR")
        for protected in (False, True):
            with self.subTest(protected=protected):
                capture = self.base / ("protected.args" if protected else "unflagged.args")
                command = "android local-tests" if protected else "scan sensitive"
                env = os.environ.copy()
                for key in optional_keys:
                    env.pop(key, None)
                env.update(MC_TEST_COMMON=str(common), MC_TEST_CAPTURE=str(capture),
                           MC_IOS_REPO=str(self.base / "ios source"),
                           MC_ANDROID_REPO=str(self.base / "android source"),
                           MC_EVIDENCE_ABS=str(self.base / "evidence path"),
                           MC_RUN_ID="fixture-run", MC_COMMAND=command)
                dependency = self.base / "evidence path/agent-runs/managed-artifacts/shared-packages"
                if protected:
                    dependency = self.base / "pinned packages"
                    env.update(MC_ARTIFACT_PIN_REASON="native consumers pending",
                               MC_ARTIFACT_RETRY_PENDING="1", MC_ARTIFACT_FINAL_EVIDENCE="1",
                               MC_IOS_SOURCE_PACKAGES_DIR=str(dependency))
                script = r'''source "$MC_TEST_COMMON"
mc_artifact_call() {
  printf '%s\0' "$@" > "$MC_TEST_CAPTURE"
  printf '%s\n' fixture-token
}
mc_artifact_begin || exit "$?"
test "$MC_ARTIFACT_RUN" = fixture-token || exit 91
test -z "${MC_WARNINGS:-}" || exit 92
trap - EXIT INT TERM
'''
                result = subprocess.run(["/bin/bash", "-uo", "pipefail", "-c", script],
                                        env=env, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(result.stderr, "")
                actual = capture.read_bytes().split(b"\0")
                self.assertEqual(actual.pop(), b"")
                actual = [value.decode() for value in actual]
                self.assertTrue(actual[4].isdigit())
                repo = self.base / ("android source" if protected else "ios source")
                expected = ["begin", "--run-id", "fixture-run", "--owner", actual[4],
                            "--repo", str(repo), "--command", command,
                            "--dependency-root", str(dependency)]
                if protected:
                    expected += ["--pin", "native consumers pending", "--retry-pending", "--final-evidence"]
                self.assertEqual(actual, expected)
                self.assertNotIn("", actual)

    def test_cleanup_error_under_errexit_preserves_command_status(self):
        script = f'''source {str(HELPER.parent / 'common.sh')!r}
MC_ARTIFACT_RUN=fixture
MC_ARTIFACT_BASE={str(self.root)!r}
MC_JSON_PATH={str(self.base / 'fixture.json')!r}
mc_artifact_call() {{ case "$1" in finish) return 0;; cleanup) return 7;; esac; }}
set -e
mc_artifact_finish 65
exit 65
'''
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
        self.assertEqual(result.returncode, 65)
        self.assertIn("ARTIFACT_CLEANUP_EXIT=7", result.stdout)

    def test_low_space_runs_cleanup_then_remeasures(self):
        budget = self.base / "budget.txt"
        budget.write_text("1000000000\n")
        script = f'''source {str(HELPER.parent / 'common.sh')!r}
mc_disk_available_bytes() {{ cat {str(budget)!r}; }}
mc_artifact_maintain() {{ printf '30000000000\\n' > {str(budget)!r}; }}
mc_require_disk_space {str(REPO)!r}
'''
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("WARNING_DISK_SPACE", result.stderr)

    def test_reserve_subtracts_predicted_growth(self):
        script = f'''source {str(HELPER.parent / 'common.sh')!r}
mc_disk_available_bytes() {{ printf '32500000000\\n'; }}
mc_artifact_maintain() {{ :; }}
MC_EXIT_BLOCKED=2
MC_ARTIFACT_BATCH_GROWTH_BYTES=3500000000 mc_require_disk_space {str(REPO)!r}
'''
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("32500000000 bytes available minus 3500000000 predicted", result.stderr)

    def test_complete_failure_log_retained_without_changing_sdk_code(self):
        token = self.begin()
        original = self.base / "fixture-failure.log"
        content = "UNIQUE_FIRST_FAILURE_LINE\n" + "diagnostic line\n" * 300
        original.write_text(content)
        script = f'''source {str(HELPER.parent / 'common.sh')!r}
source {str(HELPER.parent / 'redact.sh')!r}
source {str(HELPER.parent / 'report.sh')!r}
MC_ARTIFACT_BASE={str(self.root)!r}
MC_ARTIFACT_RUN={token!r}
MC_LOG_TMP={str(self.base / 'report.tmp')!r}
code=65
mc_preserve_failure_log {str(original)!r} "$code"
test "$code" -eq 65
'''
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(original.exists())
        output = self.reg.read(token)["outputs"][-1]
        self.assertFalse(output["managed"])
        self.assertEqual(Path(output["path"]).read_text(), content)

    def test_real_mc_agent_entrypoint_with_sdk_stub_registers_and_finalizes(self):
        binaries = self.base / "bin"
        binaries.mkdir()
        stub = binaries / "xcodebuild"
        stub.write_text(f'''#!{sys.executable}
import os, pathlib, sys
a = sys.argv[1:]
if '-derivedDataPath' in a:
 p = pathlib.Path(a[a.index('-derivedDataPath')+1]) / 'Build/Products'
 p.mkdir(parents=True, exist_ok=True)
 (p/'fixture.bin').write_bytes(b'fixture compiled product')
if '-resultBundlePath' in a:
 p = pathlib.Path(a[a.index('-resultBundlePath')+1]);p.mkdir(parents=True)
 (p/'result.txt').write_text('fixture success')
print('SDK_STUB_ONLY')
''')
        stub.chmod(0o755)
        config = self.base / "config.env"
        config.write_text(f'''source {str(REPO / 'tools/agent/config.example.env')!r}
MC_IOS_REPO={str(REPO)!r}
MC_IOS_SCHEME=Fixture
MC_IOS_DESTINATION="generic/platform=iOS Simulator"
PATH={str(binaries)!r}:"$PATH"
mc_disk_available_bytes() {{ printf '100000000000\\n'; }}
''')
        env = os.environ.copy()
        env.update(MC_AGENT_CONFIG=str(config), MC_EVIDENCE_DIR=str(self.base / "evidence"),
                   MC_TASK_ID="TASK-146", MC_ARTIFACT_FINAL_EVIDENCE="1")
        result = subprocess.run(["bash", str(REPO / "tools/agent/mc-agent.sh"), "ios", "build", "debug"],
                                env=env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        managed = self.base / "evidence/agent-runs/managed-artifacts"
        run = json.loads(next((managed / "runs").glob("*.json")).read_text())
        self.assertEqual(run["status"], "success")
        self.assertTrue(run["final_evidence"])
        self.assertEqual({o["kind"] for o in run["outputs"]}, {"products", "integral-result"})
        self.assertTrue(Path(run["report"]).is_file())
        self.assertIn("ARTIFACT_CLEANUP_EXIT=0", result.stdout)

    def test_native_command_refuses_missing_lifecycle_registration(self):
        binaries = self.base / "bin"
        binaries.mkdir()
        marker = self.base / "sdk-must-not-start"
        stub = binaries / "xcodebuild"
        stub.write_text("#!/bin/sh\n" + "touch " + repr(str(marker)) + "\n")
        stub.chmod(0o755)
        config = self.base / "config.env"
        config.write_text(f"""source {str(REPO / 'tools/agent/config.example.env')!r}
MC_IOS_REPO={str(REPO)!r}
MC_IOS_DESTINATION="generic/platform=iOS Simulator"
PATH={str(binaries)!r}:"$PATH"
mc_artifact_begin() {{ MC_ARTIFACT_RUN=""; return 1; }}
""")
        env = os.environ.copy()
        env.update(MC_AGENT_CONFIG=str(config), MC_EVIDENCE_DIR=str(self.base / "evidence"), MC_TASK_ID="TASK-146")
        result = subprocess.run(["bash", str(REPO / "tools/agent/mc-agent.sh"), "ios", "build", "debug"],
                                env=env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertFalse(marker.exists())
        self.assertIn("Reconcile the existing artifact registry", result.stdout)

    def gradle_fixture(self, execute=True, prefix=""):
        token = self.begin()
        workspace = self.base / prefix
        workspace.mkdir(parents=True, exist_ok=True)
        if execute:
            # This fixture verifies Gradle retention, not attribution of unrelated
            # processes on the host. The child and its group are still observed.
            with patch.object(m, "unattributed_survivors", return_value=[]):
                self.assertEqual(m.execute(self.reg, args(run=token, timeout=0,
                                                          argv=[sys.executable, "-c", "pass"])), 0)
        source = workspace / "fake-source"
        (source / "app/src").mkdir(parents=True)
        (source / "app/src/Main.kt").write_text("class Fixture\n")
        declaration = source / "build.gradle.kts"
        declaration.write_text("plugins {}\n")
        cache = workspace / "fake-cache"
        cache.mkdir()
        (cache / "required.jar").write_bytes(b"fixture dependency bytes")
        apks = []
        for variant in ("debug", "release"):
            path = workspace / (variant + ".apk")
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("AndroidManifest.xml", "fixture " + variant)
                archive.writestr("classes.dex", b"fixture dex " + variant.encode())
            apks.append({"variant": variant, "path": str(path), "sha256": m.file_sha256(path)})
        full = workspace / "fake-full.json"
        full.write_text(json.dumps({"status": "FIXTURE_FULL_PASS", "exit_code": 0,
                                    "finalizationErrors": [], "registry_token": token,
                                    "admission": {"registryToken": token}, "artifacts": apks}))
        qualification = workspace / "fake-qualification.json"
        qualification.write_text(json.dumps({"registry_token": token, "evidence_kind": "fixture_full_pass",
                                             "qualified": True, "source_before_after_identical": True,
                                             "full_variants": ["debug", "release"], "apks": apks,
                                             "source_roots": [str(source / "app/src")],
                                             "declaration_files": [str(declaration)], "dependency_roots": [str(cache)],
                                             "expected_absent": [str(workspace / "optional.properties")],
                                             "full_qualification": {"path": str(full), "sha256": m.file_sha256(full)}}))
        return token, qualification, source, cache

    def test_gradle_capture_defaults_analysis_and_fixture_not_production(self):
        token, qualification, _, _ = self.gradle_fixture()
        with self.reg.exclusive():
            result = self.reg.capture_gradle(args(run=token, qualification=str(qualification), apply=False, fixture=True))
            self.assertFalse(result["applied"])
            self.assertNotIn("gradle_profile", self.reg.read(token))
            result = self.reg.capture_gradle(args(run=token, qualification=str(qualification), apply=True, fixture=True))
        self.assertTrue(result["applied"])
        self.assertTrue(m.verify_gradle_profile(self.reg.read(token), allow_fixture=True))
        self.assertFalse(m.input_available(self.reg.read(token)))

    def test_gradle_source_change_holds_availability(self):
        token, qualification, source, _ = self.gradle_fixture()
        with self.reg.exclusive():
            self.reg.capture_gradle(args(run=token, qualification=str(qualification), apply=True, fixture=True))
        extra = source / "app/src/New.kt"
        extra.write_text("class New\n")
        self.assertFalse(m.verify_gradle_profile(self.reg.read(token), allow_fixture=True))
        extra.unlink()
        (source / "app/src/Main.kt").write_text("class Changed\n")
        self.assertFalse(m.verify_gradle_profile(self.reg.read(token), allow_fixture=True))

    def test_gradle_dependency_change_holds_availability(self):
        token, qualification, _, cache = self.gradle_fixture()
        with self.reg.exclusive():
            self.reg.capture_gradle(args(run=token, qualification=str(qualification), apply=True, fixture=True))
        (cache / "required.jar").write_bytes(b"changed dependency bytes")
        self.assertFalse(m.verify_gradle_profile(self.reg.read(token), allow_fixture=True))

    def test_gradle_optional_declaration_appearance_holds_availability(self):
        token, qualification, _, _ = self.gradle_fixture()
        with self.reg.exclusive():
            self.reg.capture_gradle(args(run=token, qualification=str(qualification), apply=True, fixture=True))
        (self.base / "optional.properties").write_text("changed=true\n")
        self.assertFalse(m.verify_gradle_profile(self.reg.read(token), allow_fixture=True))

    def test_gradle_qualified_mixed_retention_after_consumer_closure_fixture_only(self):
        outputs = []
        for index in range(3):
            token, qualification, _, _ = self.gradle_fixture(prefix=str(index))
            directory = self.output(token, kind="integral-directory")
            for apk in json.loads(qualification.read_text())["apks"]:
                shutil.copy2(apk["path"], directory / (apk["variant"] + ".apk"))
            with self.reg.exclusive():
                self.reg.protect(args(run=token, pin=["pending-native"], retry_pending=True, final_evidence=False))
                self.reg.capture_gradle(args(run=token, qualification=str(qualification), apply=True, fixture=True))
            self.finish(token)
            self.release(token, ["pending-native"])
            outputs.append(directory)
        verifier = m.verify_gradle_profile
        with patch.object(m, "verify_gradle_profile", side_effect=lambda run: verifier(run, allow_fixture=True)):
            result = self.clean(True)
        self.assertEqual(result["removed_outputs"], [str(outputs[0])])
        self.assertTrue(all(path.exists() for path in outputs[1:]))

    def test_gradle_capture_rejects_missing_execution_and_wrong_scope(self):
        token, qualification, _, _ = self.gradle_fixture(execute=False)
        with self.reg.exclusive():
            self.assertRaises(m.Hold, self.reg.capture_gradle,
                              args(run=token, qualification=str(qualification), apply=True, fixture=True))
            self.assertRaises(m.Hold, self.reg.capture_gradle,
                              args(run=token, qualification=str(qualification), apply=True, fixture=False))


if __name__ == "__main__":
    unittest.main(verbosity=2)
