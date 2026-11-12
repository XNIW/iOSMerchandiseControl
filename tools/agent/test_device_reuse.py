#!/usr/bin/env python3
"""Device identity and existing-lock regressions; no SDK/device mutation."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

LIB = Path(__file__).resolve().parent / "lib"


class DeviceReuseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("MC_")}
        self.env.update(PATH=str(self.root) + os.pathsep + os.environ["PATH"],
                        MC_EXIT_PASS="0", MC_EXIT_BLOCKED="2", MC_TASK_ID="TASK-146",
                        MC_IOS_REPO=str(self.root), MC_ARTIFACT_RUN="registered-test")
        self.simulators([("canonical", "iPhone 15 Pro Max", "Shutdown", "26-1")])
        self.adb([("emulator-5554", "Medium_Phone_API_35")])

    def executable(self, name, content):
        p = self.root / name
        p.write_text("#!/usr/bin/env python3\n" + content)
        p.chmod(0o700)

    def simulators(self, rows):
        data = {}
        for ident, name, state, version in rows:
            data.setdefault("com.apple.CoreSimulator.SimRuntime.iOS-" + version, []).append(
                dict(udid=ident, name=name, state=state, isAvailable=True))
        self.env["SIM_DATA"] = json.dumps(dict(devices=data))
        self.executable("xcrun", "import os,sys\nassert sys.argv[1:] == ['simctl','list','devices','--json']\nprint(os.environ['SIM_DATA'])\n")

    def adb(self, rows):
        self.env["ADB_DATA"] = json.dumps(dict(rows))
        self.executable("adb", """import os,sys,json
rows=json.loads(os.environ['ADB_DATA']); a=sys.argv[1:]
if a==['devices']:
 print('List of devices attached'); print('\\n'.join(k+'\\tdevice' for k in rows))
elif a[:1]==['-s'] and a[1] in rows:
 if a[2:]==['emu','avd','name']: print(rows[a[1]]+'\\nOK')
 elif a[2:]==['get-state']: print('device')
 elif a[2:]==['shell','getprop','ro.kernel.qemu']: print('1')
 else: sys.exit(7)
else: sys.exit(8)
""")

    def shell(self, body, lib="ios.sh"):
        return subprocess.run(["bash", "-c", "source " + shlex.quote(str(LIB/lib)) +
            "; mc_artifact_call() { return 0; }; mc_android_set_preflight_detail() { :; }; mc_relpath() { printf '%s' \"$1\"; }; " + body],
            env=self.env, text=True, capture_output=True, timeout=10)

    def test_existing_ios_selected_by_id(self):
        r = self.shell("mc_ios_destination")
        self.assertEqual((r.returncode, r.stdout), (0, "platform=iOS Simulator,id=canonical"))

    def test_booted_other_device_does_not_override_canonical(self):
        self.simulators([("other", "Other", "Booted", "26-1"),
                         ("canonical", "iPhone 15 Pro Max", "Shutdown", "26-1")])
        self.assertEqual(self.shell("mc_ios_simulator_target").stdout.strip(), "canonical")

    def test_duplicate_name_is_blocked_even_if_one_booted(self):
        self.simulators([("a", "iPhone 15 Pro Max", "Booted", "26-1"),
                         ("b", "iPhone 15 Pro Max", "Shutdown", "26-1")])
        self.assertEqual(self.shell("mc_ios_simulator_target").returncode, 2)

    def test_missing_ios_is_blocked_without_creation(self):
        self.simulators([])
        self.assertEqual(self.shell("mc_ios_destination").returncode, 2)

    def test_explicit_id_checks_runtime_and_existence(self):
        self.env.update(MC_IOS_SIMULATOR_ID="canonical", MC_IOS_SIMULATOR_OS="26.2")
        self.assertEqual(self.shell("mc_ios_simulator_target").returncode, 2)
        self.env["MC_IOS_SIMULATOR_OS"]="26.1"
        self.assertEqual(self.shell("mc_ios_simulator_target").stdout.strip(), "canonical")
        self.env["MC_IOS_SIMULATOR_ID"]="missing"
        self.assertEqual(self.shell("mc_ios_simulator_target").returncode, 2)

    def test_explicit_ci_destination_and_physical_unchanged(self):
        self.env["MC_IOS_DESTINATION"]="generic/platform=iOS Simulator"
        self.assertEqual(self.shell("mc_ios_destination").stdout, "generic/platform=iOS Simulator")
        self.env["MC_IOS_DEVICE_UDID"]="physical"
        self.assertEqual(self.shell("mc_ios_destination").stdout, "platform=iOS,id=physical")

    def test_canonical_physical_only_and_temporary_cleanup(self):
        self.executable("xcrun", """import json,sys
from pathlib import Path
assert sys.argv[1:4]==['devicectl','list','devices']
rows=[{'identifier':'canonical-physical','hardwareProperties':{'platform':'iOS','udid':'00008130-001644523A2A001C'},'deviceProperties':{'name':'iPhone di Min'},'connectionProperties':{'tunnelState':'connected'}},
      {'identifier':'other','hardwareProperties':{'platform':'iOS','udid':'other'},'deviceProperties':{'name':'Other'},'connectionProperties':{'tunnelState':'connected'}}]
Path(sys.argv[-1]).write_text(json.dumps({'result':{'devices':rows}}))
""")
        r=self.shell("mc_ios_physical_device_json")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout)["identifier"], "canonical-physical")
        self.env["MC_IOS_DEVICE_UDID"]="missing"
        self.assertEqual(self.shell("mc_ios_physical_device_json").returncode, 2)

    def test_explicit_id_precedes_configured_destination(self):
        self.env.update(MC_IOS_SIMULATOR_ID="canonical", MC_IOS_DESTINATION="generic/platform=iOS")
        self.assertEqual(self.shell("mc_ios_destination").stdout, "platform=iOS Simulator,id=canonical")

    def test_android_follows_avd_identity_not_serial_order(self):
        self.adb([("emulator-5554", "Unrelated"), ("emulator-5560", "Medium_Phone_API_35")])
        r = self.shell("mc_android_serial", "android.sh")
        self.assertEqual((r.returncode, r.stdout), (0, "emulator-5560"))

    def test_android_missing_or_ambiguous_blocks(self):
        for rows in [[("emulator-5554", "Unrelated")],
                     [("emulator-5554", "Medium_Phone_API_35"), ("emulator-5560", "Medium_Phone_API_35")]]:
            self.adb(rows)
            self.assertEqual(self.shell("mc_android_serial", "android.sh").returncode, 2)

    def test_explicit_android_serial_still_supported(self):
        self.env["MC_ANDROID_DEVICE_SERIAL"]="emulator-5554"
        self.assertEqual(self.shell("mc_android_serial", "android.sh").stdout, "emulator-5554")
        self.env["MC_ANDROID_DEVICE_SERIAL"]="missing"
        self.assertEqual(self.shell("mc_android_serial", "android.sh").returncode, 2)

    def test_live_android_still_requires_explicit_serial(self):
        self.env["MC_REQUIRES_LIVE"]="true"
        self.assertEqual(self.shell("mc_android_serial", "android.sh").returncode, 2)

    def test_locks_shared_between_tasks_and_separate_platforms(self):
        r=self.shell('MC_COMMAND="ios test"; a=$(mc_lock_path TASK-001); b=$(mc_lock_path TASK-002); '
                     'test "$a" = "$b" || exit 9; MC_COMMAND="android test"; c=$(mc_lock_path); test "$a" != "$c"', "common.sh")
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_live_lock_never_expires_by_age(self):
        r=self.shell('MC_COMMAND="ios test"; p=$(mc_lock_path); mkdir -p "$(dirname "$p")"; '
                     'printf "pid=%s timestamp=old\\n" $$ > "$p"; touch -t 200001010000 "$p"; '
                     'mc_acquire_live_lock; c=$?; test -f "$p" || exit 9; exit "$c"', "common.sh")
        self.assertEqual(r.returncode, 2, r.stderr)

    def test_artifact_traps_retained_and_lock_released(self):
        r=self.shell('MC_COMMAND="android test"; mc_now_iso() { echo now; }; '
                     'trap ": artifact_cleanup" EXIT; before=$(trap -p EXIT); '
                     'mc_acquire_live_lock || exit $?; after=$(trap -p EXIT); '
                     'test "$before" = "$after" || exit 8; p=$MC_LOCK_FILE; '
                     'mc_release_live_lock; test ! -e "$p" || exit 9; test "$before" = "$(trap -p EXIT)"', "common.sh")
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_interrupted_live_consumer_keeps_device_lock(self):
        r=self.shell('MC_COMMAND="android test"; mc_now_iso() { echo now; }; '
                     'mc_artifact_call() { if [[ "$1" == quiescent ]]; then return 2; fi; }; '
                     'mc_artifact_maintain() { :; }; mc_acquire_live_lock || exit $?; '
                     'p=$MC_LOCK_FILE; mc_artifact_interrupt 143; '
                     'test -e "$p" && test "$MC_LOCK_HELD" = 1', "common.sh")
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_dead_owner_without_consumer_receipt_is_held(self):
        r=self.shell('MC_COMMAND="ios test"; p=$(mc_lock_path); mkdir -p "$(dirname "$p")"; '
                     'printf "pid=99999999 timestamp=old\\n" > "$p"; '
                     'mc_acquire_live_lock; c=$?; test -e "$p" || exit 9; exit "$c"', "common.sh")
        self.assertEqual(r.returncode, 2, r.stderr)

    def test_cancellation_quiesces_before_unlock(self):
        r=self.shell('MC_COMMAND="android test"; mc_now_iso() { echo now; }; '
                     'mc_artifact_call() { test -f "$MC_LOCK_FILE" || return 9; touch "$MC_IOS_REPO/quiesced"; }; '
                     'mc_artifact_maintain() { :; }; mc_acquire_live_lock || exit $?; '
                     'p=$MC_LOCK_FILE; mc_artifact_interrupt 143; '
                     'test -f "$MC_IOS_REPO/quiesced" && test ! -e "$p"', "common.sh")
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main()
