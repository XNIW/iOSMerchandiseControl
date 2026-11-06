#!/usr/bin/env python3
"""Bounded lifecycle for outputs created by mc-agent; never discovers old disk lots."""
import argparse
import ctypes
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import time
import uuid
import zipfile
from contextlib import contextmanager

CAP = 20_000_000_000  # Warn when protected outputs exceed this operating budget.
MAX_FILES = 200_000


class Hold(Exception):
    pass


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def no_links(path):
    path = Path(os.path.abspath(path))
    for part in (path, *path.parents):
        if os.path.lexists(part) and part.is_symlink():
            raise Hold("symlink component: " + str(part))
    return path


def write_json(path, value):
    tmp = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    with tmp.open("x") as out:
        json.dump(value, out, separators=(",", ":"))
        out.flush()
        os.fsync(out.fileno())
    os.replace(tmp, path)


class BsdInfo(ctypes.Structure):
    _fields_ = [(n, ctypes.c_uint32) for n in (
        "flags", "status", "xstatus", "pid", "ppid", "uid", "gid", "ruid",
        "rgid", "svuid", "svgid", "reserved")]
    _fields_ += [("comm", ctypes.c_char * 16), ("name", ctypes.c_char * 32)]
    _fields_ += [(n, ctypes.c_uint32) for n in (
        "nfiles", "pgid", "jobc", "tdev", "tpgid")]
    _fields_ += [("nice", ctypes.c_int32), ("start_sec", ctypes.c_uint64),
                ("start_usec", ctypes.c_uint64)]


def birth(pid):
    """Kernel birth timestamp, not a PID/lock-age heuristic."""
    lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    retry_started, retry_deadline, first_kernel_errno = None, None, None
    identity_reads = 0
    for _ in range(6):
        if retry_deadline is not None and time.monotonic() >= retry_deadline:
            break
        buf = BsdInfo()
        n = lib.proc_pidinfo(int(pid), 3, 0, ctypes.byref(buf), ctypes.sizeof(buf))
        kernel_errno = ctypes.get_errno()
        identity_reads += 1
        if n == 0 and kernel_errno == 3:  # ESRCH
            return None
        if n == ctypes.sizeof(buf):
            return {"pid": int(pid), "sec": buf.start_sec, "usec": buf.start_usec}
        if retry_deadline is None:
            retry_started = time.monotonic()
            retry_deadline = retry_started + 0.05
            first_kernel_errno = kernel_errno
        presence_probe = "not-run"
        try:
            presence_probe = present(int(pid))
            if not presence_probe:
                return None
        except OSError as exc:
            presence_probe = "error:" + type(exc).__name__ + ":" + str(exc.errno)
        # A short-lived privileged child may deny this read until it exits.
        # Retry only EPERM; never substitute UID/name/census data for identity.
        if n != 0 or kernel_errno != 1 or presence_probe is not True or identity_reads == 6:
            break
        remaining = retry_deadline - time.monotonic()
        if remaining <= 0:
            break
        time.sleep(min(0.01, remaining))
    raise Hold("kernel process identity unavailable: " + str(pid)
               + " [n=" + str(n) + ", expected_size=" + str(ctypes.sizeof(buf))
               + ", kernel_errno=" + str(kernel_errno)
               + ", present_probe=" + str(presence_probe)
               + ", last_census_only="
               + str(getattr(process_table, "_last_census", {}).get(int(pid), "unavailable"))
               + ", identity_reads=" + str(identity_reads)
               + ", first_kernel_errno=" + str(first_kernel_errno) + "]")


def live(identity):
    current = birth(identity["pid"])
    return current == identity


def present(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def process_table():
    p = subprocess.run(["/bin/ps", "-axo", "pid=,ppid=,pgid=,uid=,stat=,comm="],
                       capture_output=True, text=True, check=True)
    if p.stderr:
        raise Hold("incomplete process table")
    triples, census = [], {}
    for row in p.stdout.splitlines():
        fields = row.split(None, 5)
        triple = tuple(map(int, fields[:3]))
        triples.append(triple)
        if len(triple) == 3:
            census[triple[0]] = {"pid": triple[0], "ppid": triple[1], "pgid": triple[2],
                                 "uid": fields[3] if len(fields) > 3 else "unavailable",
                                 "stat": fields[4] if len(fields) > 4 else "unavailable",
                                 "comm": fields[5] if len(fields) > 5 else "unavailable"}
    process_table._last_census = census  # Diagnostic census sample, never kernel-read authority.
    return triples


def identities():
    result, unknown = [], []
    rows = subprocess.check_output(["/bin/ps", "-axo", "pid=,uid="]).decode()
    for row in rows.splitlines():
        pid, uid = map(int, row.split())
        if uid != os.getuid():
            # Pre-existing foreign-UID processes cannot be direct children of an unprivileged SDK.
            if present(pid):
                result.append({"pid": pid, "uid": uid, "excluded_foreign_uid": True})
            continue
        try:
            identity = birth(pid)
            if identity:
                result.append({**identity, "uid": uid})
        except Hold:
            unknown.append(pid)
    return result, unknown


def unattributed_survivors(execution):
    if execution.get("baseline_unknown"):
        raise Hold("current-user kernel identity baseline incomplete")
    baseline = execution["baseline"]
    old_foreign = {(i["pid"], i["uid"]) for i in baseline if i.get("excluded_foreign_uid")}
    old_own = {(i["pid"], i["sec"], i["usec"]) for i in baseline if not i.get("excluded_foreign_uid")}
    own = {(i["pid"], i["sec"], i["usec"]) for i in execution.get("observed", [])}
    current, unknown = identities()
    if unknown:
        raise Hold("current-user kernel identity postflight incomplete")
    result = []
    for identity in current:
        if identity["pid"] == os.getpid():
            continue
        if identity.get("excluded_foreign_uid"):
            if (identity["pid"], identity["uid"]) not in old_foreign:
                result.append(identity)
        elif (identity["pid"], identity["sec"], identity["usec"]) not in old_own | own:
            result.append(identity)
    return result


def source_context(repo):
    paths = ["iOSMerchandiseControl", "iOSMerchandiseControlTests", "iOSMerchandiseControlUITests",
             "Configuration", "Vendor", "Vendor 2", "contracts", "Data",
             "iOSMerchandiseControl.xcodeproj", "Package.resolved",
             "app/src", "app/schemas", "app/build.gradle", "app/build.gradle.kts", "build.gradle",
             "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "gradle",
             "gradle.properties"]
    def git(*args):
        return subprocess.check_output(["git", "--no-optional-locks", "-C", str(repo), *args],
                                       stderr=subprocess.DEVNULL)
    head = git("rev-parse", "HEAD").decode().strip()
    delta = git("diff", "--binary", "HEAD", "--", *paths)
    untracked = git("ls-files", "--others", "--exclude-standard", "-z", "--", *paths)
    ignored = git("ls-files", "--others", "--ignored", "--exclude-standard", "-z", "--", *paths)
    ignored_inputs = [raw for raw in ignored.split(b"\0") if raw and not (
        Path(os.fsdecode(raw)).name == ".DS_Store" or
        os.fsdecode(raw).endswith(".xcuserdatad/UserInterfaceState.xcuserstate"))]
    digest = hashlib.sha256(delta)
    complete = True
    for raw in untracked.split(b"\0") + ignored_inputs:
        if not raw:
            continue
        try:
            path = no_links(repo / os.fsdecode(raw))
            if not path.is_file() or path.stat().st_size > 20_000_000:
                raise Hold("unbounded or nonregular source input")
        except (OSError, Hold):
            complete = False
            digest.update(raw + b"\0UNATTESTED")
            continue
        digest.update(raw)
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    xcode = Path(os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"))
    tool = {"developer_dir": str(xcode), "java_home": os.environ.get("JAVA_HOME", "")}
    info = xcode.parent / "Info.plist"
    if info.is_file():
        tool["xcode_info_sha256"] = hashlib.sha256(info.read_bytes()).hexdigest()
    return {"repo": str(repo), "head": head, "delta_sha256": digest.hexdigest(),
            "clean_inputs": not delta and not untracked and not ignored_inputs,
            "complete": complete, "ignored_inputs_sha256": hashlib.sha256(b"\0".join(ignored_inputs)).hexdigest(),
            "toolchain": tool}


def dependencies(repo, root, cache_path=None):
    cache = no_links(cache_path or root / "shared-packages")
    resolved = [repo / "Package.resolved", repo / "iOSMerchandiseControl.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"]
    paths = [p for p in resolved if p.is_file()]
    if not paths:
        return {"complete": False, "reason": "no explicit dependency resolution receipt"}
    rows = []
    try:
        for path in paths:
            for pin in json.loads(path.read_text()).get("pins", []):
                identity, revision = pin["identity"], pin["state"]["revision"]
                matches = [p for p in (cache / "checkouts").iterdir() if p.name.lower() == identity.lower()]
                if len(matches) != 1:
                    raise Hold("dependency checkout unavailable")
                checkout = no_links(matches[0])
                head = subprocess.check_output(["git", "--no-optional-locks", "-C", str(checkout), "rev-parse", "HEAD"], stderr=subprocess.DEVNULL).decode().strip()
                dirty = subprocess.check_output(["git", "--no-optional-locks", "-C", str(checkout), "status", "--porcelain", "-uall"], stderr=subprocess.DEVNULL)
                if head != revision or dirty:
                    raise Hold("dependency revision or local changes differ")
                rows.append([identity, revision])
        return {"complete": True, "root": str(cache), "pins": sorted(rows)}
    except (OSError, KeyError, Hold, subprocess.SubprocessError) as exc:
        return {"complete": False, "reason": str(exc)}


def file_sha256(path):
    if getattr(Path(path).lstat(), "st_flags", 0) & 0x40000000:
        raise Hold("cloud placeholder is not materialized; no download attempted")
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def file_identity(s):
    return [s.st_dev, s.st_ino, s.st_mode, s.st_size, s.st_mtime_ns, s.st_uid]


def availability_inventory(values, hash_all, budget):
    roots = sorted({no_links(v["path"] if isinstance(v, dict) else v) for v in values}, key=lambda p: (len(p.parts), str(p)))
    roots = [p for p in roots if not any(other in p.parents for other in roots)]
    result = []
    for root in roots:
        if not root.exists():
            raise Hold("required availability root missing: " + str(root))
        paths = [root] if root.is_file() else []
        if root.is_dir():
            for parent, dirs, files in os.walk(root, followlinks=False):
                def volatile(name):
                    return not hash_all and (name in ("daemon", "tmp", ".tmp", "gc.properties", "file-access.bin")
                                             or name.endswith((".lock", ".lck", ".pid", ".lastUpdated", ".part")))
                dirs[:] = [name for name in dirs if not volatile(name)]
                paths.extend(Path(parent) / name for name in files if not volatile(name))
                paths.extend(Path(parent) / name for name in dirs if (Path(parent) / name).is_symlink())
                if len(paths) + budget["files"] > 50_000:
                    raise Hold("availability witness exceeds 50000 files")
        if not paths and not hash_all:
            raise Hold("required availability root is empty")
        rows = []
        for path in sorted(paths):
            s = path.lstat()
            row = {"relative": "" if path == root else str(path.relative_to(root)), "identity": file_identity(s)}
            budget["files"] += 1
            identity = (s.st_dev, s.st_ino)
            if identity not in budget["seen"]:
                budget["seen"].add(identity)
                budget["bytes"] += s.st_size
                if hash_all:
                    budget["source_bytes"] += s.st_size
            if budget["files"] > 50_000 or budget["bytes"] > 30_000_000_000 or budget["source_bytes"] > 100_000_000:
                raise Hold("availability witness file/byte budget exceeded")
            if stat.S_ISLNK(s.st_mode):
                target = path.resolve(strict=True)
                if not any(target == allowed or allowed in target.parents for allowed in roots):
                    raise Hold("availability symlink leaves explicit roots")
                row["link_target"] = os.readlink(path)
            elif stat.S_ISREG(s.st_mode):
                if getattr(s, "st_flags", 0) & 0x40000000:
                    raise Hold("cloud placeholder is not materialized; no download attempted")
                if hash_all or s.st_size <= 65_536:
                    row["sha256"] = file_sha256(path)
            else:
                raise Hold("availability witness contains nonregular input")
            if file_identity(path.lstat()) != row["identity"]:
                raise Hold("availability input changed during capture")
            rows.append(row)
        result.append({"path": str(root), "directory": root.is_dir(), "hash_all": hash_all, "entries": rows})
    return result


def verify_gradle_profile(run, allow_fixture=False):
    try:
        binding = run["gradle_profile"]
        path = no_links(binding["path"])
        if file_sha256(path) != binding["sha256"]:
            return False
        profile = json.loads(path.read_text())
        if profile["scope"] != "real_sdk_full_pass" and not allow_fixture:
            return False
        if (profile["registry_token"] != run["token"] or profile["inputs"] != run["inputs"]
                or profile["inputs"] != source_context(Path(run["inputs"]["repo"]))):
            return False
        for receipt in (profile["qualification"], profile["full_qualification"]):
            if file_sha256(no_links(receipt["path"])) != receipt["sha256"]:
                return False
        if any(os.path.lexists(path) for path in profile.get("expected_absent", [])):
            return False
        allowed = [no_links(group["path"]) for group in profile["roots"]]
        for group in profile["roots"]:
            root = no_links(group["path"])
            if not root.exists() or root.is_dir() != group["directory"]:
                return False
            if group["hash_all"] and root.is_dir():
                actual = set()
                for parent, dirs, files in os.walk(root, followlinks=False):
                    actual.update(str((Path(parent) / name).relative_to(root)) for name in files)
                    actual.update(str((Path(parent) / name).relative_to(root)) for name in dirs if (Path(parent) / name).is_symlink())
                    if len(actual) > 50_000:
                        return False
                if actual != {row["relative"] for row in group["entries"]}:
                    return False
            for row in group["entries"]:
                relative = Path(row["relative"])
                if relative.is_absolute() or ".." in relative.parts:
                    return False
                file = root / relative
                no_links(file.parent)
                if file_identity(file.lstat()) != row["identity"]:
                    return False
                if "link_target" in row:
                    target = file.resolve(strict=True)
                    if os.readlink(file) != row["link_target"] or not any(target == p or p in target.parents for p in allowed):
                        return False
                elif "sha256" in row and file_sha256(file) != row["sha256"]:
                    return False
        return True
    except (OSError, Hold, KeyError, ValueError, subprocess.SubprocessError):
        return False


def input_available(run):
    try:
        if run.get("gradle_profile"):
            return verify_gradle_profile(run)
        old = run["inputs"]
        current = source_context(Path(old["repo"]))
        deps = dependencies(Path(old["repo"]), Path(run["registry_root"]), run.get("dependency_root"))
        if not old.get("complete") or not deps.get("complete") or deps != run.get("dependencies"):
            return False
        if current == old:
            return True
        if old["clean_inputs"] and current["toolchain"] == old["toolchain"]:
            p = subprocess.run(["git", "--no-optional-locks", "-C", old["repo"],
                                "cat-file", "-e", old["head"] + "^{commit}"],
                               capture_output=True)
            return p.returncode == 0
    except (OSError, subprocess.SubprocessError, Hold, KeyError):
        pass
    return False


class Registry:
    def __init__(self, root):
        self.root = no_links(root)
        if self.root.name != "managed-artifacts" or self.root.parent.name != "agent-runs":
            raise Hold("root must be explicit agent-runs/managed-artifacts")
        self.root.mkdir(parents=True, exist_ok=True)
        no_links(self.root)
        self.lock = self.root / ".lock"

    @contextmanager
    def exclusive(self):
        fd = os.open(self.lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            marker = self.root / "owner.json"
            if not marker.exists():
                if set(p.name for p in self.root.iterdir()) != {".lock"}:
                    raise Hold("existing output root has no ownership marker")
                write_json(marker, {"schema": 1, "uid": os.getuid(), "root": str(self.root),
                                    "nonce": uuid.uuid4().hex, "created": now()})
            owner = json.loads(no_links(marker).read_text())
            if owner["uid"] != os.getuid() or owner["root"] != str(self.root):
                raise Hold("output root ownership changed")
            for name in ("runs", "products", "results", "executions", "raw", "gradle-profiles"):
                no_links(self.root / name).mkdir(exist_ok=True)
            yield
        finally:
            os.close(fd)

    def run_path(self, token):
        if not re.fullmatch(r"[0-9a-f]{32}", token):
            raise Hold("invalid run token")
        return no_links(self.root / "runs" / (token + ".json"))

    def read(self, token):
        return json.loads(self.run_path(token).read_text())

    def save(self, run):
        write_json(self.run_path(run["token"]), run)

    def all_runs(self):
        return [json.loads(no_links(p).read_text()) for p in (self.root / "runs").glob("*.json")]

    def event(self, event, **values):
        with (self.root / "index.jsonl").open("a") as out:
            out.write(json.dumps({"time": now(), "event": event, **values}) + "\n")

    def quiescent(self, run, for_cleanup=True):
        for token in run.get("executions", []):
            e = json.loads(no_links(self.root / "executions" / (token + ".json")).read_text())
            if e.get("state") != "terminal":
                return False
            if any(live(i) for i in e.get("observed", [])):
                return False
            if any(pgid == e["pgid"] for _, _, pgid in process_table()):
                return False
            if e.get("cohort_nonce") and cohort_members(e["cohort_nonce"], e["leader"], e.get("finished_epoch_us")):
                return False
            # Polling alone cannot prove a fast child did not detach and clear its environment.
            # Foreign new processes only hold retention; they are never signalled.
            if for_cleanup:
                if run.get("quiescence_review_receipt"):
                    continue  # Own observed/group/cohort checks above still apply.
                if e.get("quiescence_coverage_error"):
                    return False
                for identity in e.get("unattributed_survivors", []):
                    if ((identity.get("excluded_foreign_uid") and present(identity["pid"]))
                            or (not identity.get("excluded_foreign_uid") and live({k: identity[k] for k in ("pid", "sec", "usec")}))):
                        return False
        return True

    def reconcile(self):
        for run in self.all_runs():
            if run["status"] == "running" and not live(run["owner"]):
                # An unfinalized exec is uncertain even when the original owner died.
                run["status"] = "interrupted_needs_review"
                run["pins"] = sorted(set(run["pins"] + ["crash_diagnostic_and_retry"]))
                run["owner_dead_verified_at"] = now()
                run["descendants_quiescent"] = self.quiescent(run)
                self.save(run)
                self.event("interrupted_preserved", run=run["token"])

    def begin(self, args):
        self.reconcile()
        token = uuid.uuid4().hex
        run = {"schema": 1, "token": token, "run_id": args.run_id, "started": now(),
               "owner": birth(args.owner), "lease_nonce": uuid.uuid4().hex,
               "status": "running", "command": args.command, "inputs": source_context(Path(args.repo)),
               "registry_root": str(self.root), "outputs": [], "executions": [],
               "dependency_root": str(no_links(getattr(args, "dependency_root", None) or self.root / "shared-packages")),
               "rebuild_required": getattr(args, "rebuild_required", False),
               "pins": list(args.pin), "retry_pending": args.retry_pending,
               "final_evidence": args.final_evidence}
        if run["owner"] is None:
            raise Hold("run owner already absent")
        self.save(run)
        return token

    def path(self, args):
        run = self.read(args.run)
        if run["status"] != "running" or not live(run["owner"]):
            raise Hold("run lease is not live")
        key = hashlib.sha256(args.configuration.encode()).hexdigest()[:20]
        existing = [o for o in run["outputs"] if o["kind"] == args.kind and o["configuration"] == key]
        if existing and args.kind == "products":
            return existing[0]["path"]
        parent = "products" if args.kind == "products" else "results"
        suffix = ".xcresult" if args.kind == "integral-result" else ""
        path = self.root / parent / (key + "-" + uuid.uuid4().hex + suffix)
        no_links(path)
        run["outputs"].append({"path": str(path), "kind": args.kind, "configuration": key,
                               "requires_rebuild": getattr(args, "requires_rebuild", False) or run.get("rebuild_required", False),
                               "configuration_label": args.configuration, "created": now()})
        self.save(run)
        self.event("output_registered", run=run["token"], path=str(path), kind=args.kind)
        return str(path)

    def reuse_products(self, args):
        run = self.read(args.run)
        if run["status"] != "running" or not live(run["owner"]):
            raise Hold("run lease is not live")
        key = hashlib.sha256(args.configuration.encode()).hexdigest()[:20]
        for prior in sorted(self.all_runs(), key=lambda r: r.get("finished", ""), reverse=True):
            if (prior["status"] != "success" or prior["inputs"] != run["inputs"]
                    or prior["retry_pending"] or prior.get("products_release")):
                continue
            for output in prior["outputs"]:
                if (output["kind"] != "products" or output["configuration"] != key
                        or not output.get("managed", True) or not output.get("valid_products")
                        or output.get("removed") or output.get("reused_by")):
                    continue
                path = no_links(output["path"])
                if (path.parent == self.root / "products" and (path / "Build/Products").is_dir()
                        and prior.get("dependency_root") == run.get("dependency_root")
                        and input_available(prior) and self.quiescent(prior)):
                    self.reference(argparse.Namespace(run=run["token"], path=path,
                                   kind="products", configuration=args.configuration))
                    return str(path)
        raise Hold("no completed product with matching source inputs and dependencies")

    def finish(self, args):
        run = self.read(args.run)
        if run["status"] != "running":
            raise Hold("run already finalized")
        report = no_links(args.report)
        if report.suffix != ".json" or report.stat().st_size > 5_000_000:
            raise Hold("report is not a bounded JSON receipt")
        payload = json.loads(report.read_text())
        if payload.get("exit_code") != args.code:
            raise Hold("saved report does not match command exit")
        external = payload.get("registry_token") == run["token"]
        if not external and report.parent != self.root.parent:
            raise Hold("external receipt is not bound to this registry token")
        proofs = [report] + [Path(p) for p in payload.get("diagnostic_paths", [])] if external else [report.with_suffix(ext) for ext in (".json", ".md", ".log")]
        for p in proofs:
            p = no_links(p)
            if not p.is_file() or p.stat().st_nlink != 1:
                raise Hold("report set is incomplete")
        run.update(finished=now(), exit_code=args.code,
                   status="success" if args.code == 0 else "failed",
                   report=str(report), report_sha256=hashlib.sha256(report.read_bytes()).hexdigest())
        run["retry_pending"] = run["retry_pending"] or args.code != 0
        run["dependencies"] = dependencies(Path(run["inputs"]["repo"]), self.root, run.get("dependency_root"))
        if args.code != 0:
            run["pins"].append("failure_diagnostic_and_retry")
        for token in run["executions"]:
            execution = json.loads((self.root / "executions" / (token + ".json")).read_text())
            if (execution.get("raw_returncode") != 0 or execution.get("timed_out")
                    or execution.get("cancel_signal") or execution.get("monitor_error")):
                run["pins"].append("sdk_failure_diagnostic_and_retry")
                run["retry_pending"] = True
        for output in run["outputs"]:
            path = no_links(output["path"])
            # Mixed result directories may contain copied APKs/apps as well as diagnostics.
            if path.is_dir() and not output.get("requires_rebuild"):
                for parent, dirs, files in os.walk(path, followlinks=False):
                    if any(Path(name).suffix.lower() in (".apk", ".aab", ".ipa", ".app", ".xctest") for name in dirs + files):
                        output["requires_rebuild"] = True
                        break
            output["valid_products"] = output["kind"] != "products" or (path / "Build/Products").is_dir()
            if path.exists() and output.get("managed", True):
                measured = subprocess.run(["/usr/bin/du", "-k", "-P", "-x", "-s", str(path)], capture_output=True, text=True)
                if measured.returncode == 0 and not measured.stderr:
                    output["allocated_bytes_at_finish"] = int(measured.stdout.split()[0]) * 1024
        self.save(run)
        self.event("run_finalized", run=run["token"], exit_code=args.code)

    def interrupt(self, args):
        run = self.read(args.run)
        if run["status"] == "running":
            run.update(status="interrupted_needs_review", finished=now(),
                       interruption_exit_code=args.code, retry_pending=True)
            run["pins"].append("interrupted_diagnostic_and_retry")
            self.save(run)
            self.event("run_interrupted", run=run["token"], exit_code=args.code)

    def protect(self, args):
        run = self.read(args.run)
        run["pins"] = sorted(set(run["pins"] + args.pin))
        run["retry_pending"] = run["retry_pending"] or args.retry_pending
        run["final_evidence"] = run["final_evidence"] or args.final_evidence
        self.save(run)

    def release_products(self, args):
        run = self.read(args.run)
        receipt = no_links(args.receipt)
        proof = json.loads(receipt.read_text())
        if (run["status"] == "running" or not self.quiescent(run, for_cleanup=False)
                or proof.get("registry_token") != run["token"]
                or proof.get("disposition") != "products_superseded"
                or proof.get("consumers_complete") is not True
                or proof.get("retry_pending") is not False or not proof.get("reason")):
            raise Hold("products release has no bound closure/quiescence proof")
        for name in proof.get("diagnostic_paths", []):
            if not no_links(name).is_file():
                raise Hold("diagnostic proof file missing")
        if not proof.get("diagnostic_paths"):
            raise Hold("closure must retain diagnostic files")
        if not self.quiescent(run):
            if proof.get("unattributed_consumers_reviewed_closed") is not True:
                raise Hold("unattributed process coverage needs explicit closure review receipt")
            run["quiescence_review_receipt"] = {"path": str(receipt), "sha256": hashlib.sha256(receipt.read_bytes()).hexdigest()}
        run["retry_pending"] = False
        closed = proof.get("closed_pins", [])
        run["pins"] = [p for p in run["pins"] if p not in closed]
        run["products_release"] = {"receipt": str(receipt), "sha256": hashlib.sha256(receipt.read_bytes()).hexdigest(), "time": now()}
        self.save(run)
        self.event("products_released_for_retention", run=run["token"])

    def reference(self, args):
        run = self.read(args.run)
        path = no_links(args.path)
        run["outputs"].append({"path": str(path), "kind": args.kind, "managed": False,
                               "configuration": hashlib.sha256(args.configuration.encode()).hexdigest()[:20],
                               "configuration_label": args.configuration,
                               "reason": "external output reference; never automatically deleted"})
        if path.is_file():
            run["outputs"][-1]["allocated_bytes_at_finish"] = path.stat().st_blocks * 512
        self.save(run)

    def capture_gradle(self, args):
        run = self.read(args.run)
        qpath = no_links(args.qualification)
        if qpath.stat().st_size > 5_000_000:
            raise Hold("Gradle qualification exceeds bounded receipt size")
        q = json.loads(qpath.read_text())
        fixture = bool(args.fixture)
        expected_scope = "fixture_full_pass" if fixture else "real_sdk_full_pass"
        if (q.get("registry_token") != run["token"] or q.get("evidence_kind") != expected_scope
                or q.get("qualified") is not True or q.get("source_before_after_identical") is not True
                or set(q.get("full_variants", [])) != {"debug", "release"}
                or run["inputs"] != source_context(Path(run["inputs"]["repo"]))
                or not run["inputs"].get("complete")):
            raise Hold("Gradle qualification/source/variant binding incomplete")
        if not run["executions"]:
            raise Hold("Gradle proof has no actual recorded execution")
        for token in run["executions"]:
            e = json.loads((self.root / "executions" / (token + ".json")).read_text())
            if (e.get("state") != "terminal" or e.get("raw_returncode") != 0
                    or e.get("timed_out") or e.get("cancel_signal") or e.get("monitor_error")):
                raise Hold("Gradle proof requires naturally successful SDK execution")
        full_binding = q["full_qualification"]
        full_path = no_links(full_binding["path"])
        if file_sha256(full_path) != full_binding["sha256"]:
            raise Hold("full Gradle qualification receipt changed")
        full = json.loads(full_path.read_text())
        expected_status = "FIXTURE_FULL_PASS" if fixture else "PASS_A5_DEBUG_JVM_DEBUG_RELEASE_PACK_LINT_ONLY"
        if (full.get("status") != expected_status or full.get("exit_code") != 0
                or full.get("finalizationErrors") != [] or full.get("registry_token") != run["token"]
                or full.get("admission", {}).get("registryToken") != run["token"]):
            raise Hold("full SDK qualification has no bound successful terminal status")
        if not fixture:
            if (q.get("unit_test_variants") != ["Debug"] or q.get("build_variants") != ["Debug", "Release"]
                    or full.get("unit_test_variants") != ["Debug"] or full.get("build_variants") != ["Debug", "Release"]
                    or set(full.get("variants", {})) != {"Debug"}):
                raise Hold("explicit Debug unit and both build scopes required")
            debug = full["variants"]["Debug"]
            if (debug.get("total", 0) <= 0 or debug.get("failures") != 0 or debug.get("errors") != 0 or not debug.get("XML")):
                raise Hold("current successful Debug JUnit is required")
            canonical = Path(run["inputs"]["repo"]) / "app/build/test-results/testDebugUnitTest"
            if set(canonical.glob("TEST-*.xml")) != {Path(row["path"]) for row in debug["XML"]}:
                raise Hold("canonical Debug JUnit membership changed before capture")
            for row in debug["XML"]:
                path = no_links(row["path"])
                if (path.parent != canonical or file_sha256(path) != row["sha256"]
                        or path.stat().st_mtime_ns != row["mtime_ns"]):
                    raise Hold("canonical Debug JUnit changed before availability capture")
        if not fixture and (not re.fullmatch(r"[0-9a-f]{64}", q.get("rootGO_SHA256", ""))
                            or q["rootGO_SHA256"] != full.get("rootGO_SHA256")):
            raise Hold("full SDK root authority binding differs")
        artifact_hashes = set()
        def collect(value):
            if isinstance(value, dict):
                for key, item in value.items():
                    if key.lower().replace("_", "").endswith("sha256") and isinstance(item, str):
                        artifact_hashes.add(item)
                    collect(item)
            elif isinstance(value, list):
                for item in value:
                    collect(item)
        collect(full.get("artifacts", []))
        if {row.get("variant") for row in q.get("apks", [])} != {"debug", "release"}:
            raise Hold("both retained application APK variants are required")
        for apk in q["apks"]:
            path = no_links(apk["path"])
            if path.stat().st_size > 200_000_000 or file_sha256(path) != apk["sha256"] or apk["sha256"] not in artifact_hashes:
                raise Hold("retained APK is not bound to full SDK qualification")
            with zipfile.ZipFile(path) as archive:
                if not {"AndroidManifest.xml", "classes.dex"}.issubset(archive.namelist()):
                    raise Hold("retained file is not an application APK")
        sources = q.get("source_roots", []) + q.get("declaration_files", [])
        dependencies_roots = q.get("dependency_roots", [])
        if not q.get("source_roots") or not q.get("declaration_files") or not dependencies_roots:
            raise Hold("explicit source, declaration and dependency/tool roots are required")
        expected_absent = [str(no_links(path)) for path in q.get("expected_absent", [])]
        if len(expected_absent) > 100 or any(os.path.lexists(path) for path in expected_absent):
            raise Hold("optional source/build declarations appeared after qualification")
        budget = {"files": 0, "bytes": 0, "source_bytes": 0, "seen": set()}
        profile = {"schema": 1, "registry_token": run["token"], "scope": expected_scope,
                   "inputs": run["inputs"], "qualification": {"path": str(qpath), "sha256": file_sha256(qpath)},
                   "full_qualification": full_binding, "variant_scope": ["debug", "release"],
                   **({} if fixture else {"unit_test_variants": ["Debug"], "build_variants": ["Debug", "Release"]}),
                   "expected_absent": expected_absent,
                   "roots": availability_inventory(sources, True, budget) + availability_inventory(dependencies_roots, False, budget)}
        data = json.dumps(profile, sort_keys=True, separators=(",", ":")).encode()
        if len(data) > 8_000_000:
            raise Hold("Gradle availability metadata exceeds 8 MB; incomplete profiles are not attached")
        digest = hashlib.sha256(data).hexdigest()
        result = {"status": "GRADLE_AVAILABILITY_VERIFIED_DRY_RUN", "applied": False,
                  "scope": expected_scope, "file_count": budget["files"], "logical_bytes": budget["bytes"],
                  "profile_sha256": digest}
        if args.apply:
            path = self.root / "gradle-profiles" / (digest + ".json")
            if not path.exists():
                write_json(path, profile)
            elif json.loads(path.read_text()) != profile:
                raise Hold("availability witness path contains different metadata")
            # write_json is compact without sort_keys; bind the exact saved bytes.
            binding = {"path": str(path), "sha256": file_sha256(path), "scope": expected_scope}
            if not verify_gradle_profile({**run, "gradle_profile": binding}, allow_fixture=fixture):
                raise Hold("source/dependency inputs changed before availability attachment")
            run["gradle_profile"] = binding
            self.save(run)
            result.update(status="GRADLE_AVAILABILITY_ATTACHED", applied=True,
                          profile_path=str(path), profile_sha256=run["gradle_profile"]["sha256"])
            self.event("gradle_availability_attached", run=run["token"], **result)
        return result

    def lease(self, args):
        run = self.read(args.run)
        path = no_links(self.root / "xcode-lease.json")
        if path.exists():
            lease = json.loads(path.read_text())
            owner = self.read(lease["run"])
            if lease["nonce"] != owner["lease_nonce"]:
                raise Hold("Xcode lease nonce changed")
            if args.action == "lease-release":
                if lease["run"] != run["token"] or not self.quiescent(run, for_cleanup=False):
                    raise Hold("Xcode lease still has consumers or a different owner")
                path.unlink()
                return
            if live(owner["owner"]) or not self.quiescent(owner):
                raise Hold("Xcode lease owner/descendants still live")
            # Only a recorded, kernel-identified dead owner with quiescent children is stale.
            path.unlink()
        if args.action == "lease-acquire":
            if run["status"] != "running" or not live(run["owner"]):
                raise Hold("Xcode lease run is not active")
            write_json(path, {"run": run["token"], "nonce": run["lease_nonce"],
                              "owner": run["owner"], "created": now()})

    def clean(self, apply=False):
        self.reconcile()
        runs = sorted(self.all_runs(), key=lambda r: r.get("finished", ""), reverse=True)
        keep, counts, consumers = set(), {}, set()
        for run in runs:
            refs = [output for output in run["outputs"] if not output.get("managed", True)]
            if refs and (run["status"] == "running" or run["pins"] or run["retry_pending"]
                         or run["final_evidence"] or not self.quiescent(run, for_cleanup=False)):
                consumers.update(no_links(output["path"]) for output in refs)
            for output in run["outputs"]:
                if (output.get("removed") or output.get("reused_by") or not output.get("managed", True)
                        or not no_links(output["path"]).exists()):
                    continue
                if output["kind"] == "products" and run.get("products_release"):
                    continue
                key = (output["kind"], output["configuration"])
                if run["status"] == "success" and output.get("valid_products", True):
                    counts[key] = counts.get(key, 0) + 1
                    if counts[key] <= (1 if output["kind"] == "products" else 2):
                        keep.add(output["path"])
        before = os.statvfs(self.root)
        result = {"apply": apply, "cap_bytes": CAP, "deleted_bytes_attributed": 0,
                  "available_bytes_before": before.f_bavail * before.f_frsize,
                  "removed_outputs": [], "held": [], "protected_bytes_attributed": 0}
        for run in runs:
            for output in run["outputs"]:
                size = 0
                path = no_links(output["path"])
                if output.get("removed") or output.get("reused_by") or not path.exists():
                    continue
                try:
                    size = output.get("allocated_bytes_at_finish", 0)
                    if not output.get("managed", True):
                        raise Hold("external output reference is protected")
                    if path.parent not in (self.root / "products", self.root / "results"):
                        raise Hold("output outside explicit product/result roots")
                    if any(ref == path or path in ref.parents or ref in path.parents for ref in consumers):
                        raise Hold("product or result has a registered live consumer")
                    released = output["kind"] == "products" and run.get("products_release")
                    if (run["status"] != "success" and not released) or run["pins"] or run["retry_pending"] or run["final_evidence"]:
                        raise Hold("active, failed, retry, final or explicitly pinned")
                    if str(path) in keep:
                        raise Hold("latest valid products or last two successful integral results")
                    if (output["kind"] == "products" or output.get("requires_rebuild")) and not input_available(run):
                        raise Hold("recorded inputs/toolchain no longer demonstrably available")
                    if not self.quiescent(run):
                        raise Hold("execution descendants/group not proven quiescent")
                    size = sum(s.st_blocks * 512 for _, s in tree(path))
                    opened = subprocess.run(["/usr/sbin/lsof", "-nP", "+D", str(path), "-Fpn"],
                                            capture_output=True, text=True)
                    if opened.returncode != 1 or opened.stdout.strip() or opened.stderr.strip():
                        raise Hold("open handles or incomplete handle check")
                    if apply:
                        allocated = remove_tree(path)
                        output.update(removed=now(), allocated_removed=allocated)
                        self.save(run)
                        self.event("output_removed", run=run["token"], path=str(path), bytes=allocated)
                        result["removed_outputs"].append(str(path))
                        result["deleted_bytes_attributed"] += allocated
                    else:
                        result.setdefault("eligible", []).append({"path": str(path), "bytes": size})
                except (Hold, OSError) as exc:
                    result["held"].append({"path": str(path), "reason": str(exc)})
                    result["protected_bytes_attributed"] += size
                    if not size:
                        result["protected_unknown_size_count"] = result.get("protected_unknown_size_count", 0) + 1
        result["protected_over_cap"] = result["protected_bytes_attributed"] > CAP
        after = os.statvfs(self.root)
        result["available_bytes_after"] = after.f_bavail * after.f_frsize
        result["available_bytes_delta"] = result["available_bytes_after"] - result["available_bytes_before"]
        self.event("cleanup", **result)
        return result


def tree(root):
    root = no_links(root)
    device = root.stat().st_dev
    entries = []
    for parent, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            p = Path(parent) / name
            s = p.lstat()
            if s.st_dev != device or stat.S_ISLNK(s.st_mode) or s.st_uid != os.getuid():
                raise Hold("symlink, mount or owner change in output")
            if not (stat.S_ISDIR(s.st_mode) or stat.S_ISREG(s.st_mode)) or s.st_nlink != 1 and stat.S_ISREG(s.st_mode):
                raise Hold("nonregular or hardlinked output")
            if stat.S_ISREG(s.st_mode):
                generated_db = p.relative_to(root).as_posix() in (
                    "Build/Intermediates.noindex/XCBuildData/build.db",
                    "Build/Intermediates.noindex/XCBuildData/build.db-wal",
                    "Build/Intermediates.noindex/XCBuildData/build.db-shm")
                if not generated_db and (p.suffix.lower() in (".sqlite", ".db", ".sqlite3", ".qcow2", ".img") or p.name.endswith(("-wal", "-shm"))):
                    raise Hold("persistent database/disk name inside output")
                with p.open("rb") as f:
                    if f.read(16).startswith(b"SQLite format 3") and not generated_db:
                        raise Hold("SQLite data inside output")
            entries.append((p, s))
            if len(entries) > MAX_FILES:
                raise Hold("output exceeds bounded metadata walk")
    return entries


def remove_tree(root):
    entries = tree(root)
    manifest = root.parent.parent / ("remove-" + uuid.uuid4().hex + ".jsonl")
    with manifest.open("x") as out:
        for p, s in entries:
            out.write(json.dumps({"path": str(p), "device": s.st_dev, "inode": s.st_ino,
                                  "size": s.st_size, "mtime_ns": s.st_mtime_ns,
                                  "allocated": s.st_blocks * 512}) + "\n")
        out.flush()
        os.fsync(out.fileno())
    total = 0
    for p, s in reversed(entries):
        no_links(p)
        fd = safe_dir_fd(p.parent)
        try:
            current = os.stat(p.name, dir_fd=fd, follow_symlinks=False)
            expected = (s.st_dev, s.st_ino) if stat.S_ISDIR(s.st_mode) else (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns)
            actual = (current.st_dev, current.st_ino) if stat.S_ISDIR(s.st_mode) else (current.st_dev, current.st_ino, current.st_size, current.st_mtime_ns)
            if expected != actual:
                raise Hold("output changed after manifest")
            if stat.S_ISDIR(s.st_mode):
                os.rmdir(p.name, dir_fd=fd)
            else:
                os.unlink(p.name, dir_fd=fd)
                total += s.st_blocks * 512
        finally:
            os.close(fd)
    root.rmdir()
    return total


def safe_dir_fd(path):
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for name in Path(path).parts[1:]:
            other = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = other
        return fd
    except Exception:
        os.close(fd)
        raise


def cohort_members(nonce, earliest, ended_us=None):
    """Read only the run marker from current-user process environments, never log them."""
    if not earliest:
        raise Hold("cohort birth fence unavailable")
    marker = ("MC_ARTIFACT_COHORT=" + nonce).encode()
    libc = ctypes.CDLL(None, use_errno=True)
    raw = subprocess.check_output(["/bin/ps", "-axo", "pid=,uid="]).decode()
    members = []
    for row in raw.splitlines():
        pid, uid = map(int, row.split())
        if uid != os.getuid() or pid == os.getpid():
            continue
        identity = birth(pid)
        if identity is None or (identity["sec"], identity["usec"]) < (earliest["sec"], earliest["usec"]):
            continue
        mib = (ctypes.c_int * 3)(1, 49, pid)  # CTL_KERN, KERN_PROCARGS2
        buf = ctypes.create_string_buffer(1024 * 1024)
        size = ctypes.c_size_t(len(buf))
        if libc.sysctl(mib, 3, buf, ctypes.byref(size), None, 0) != 0:
            if birth(pid) is not None and (ended_us is None or identity["sec"] * 1_000_000 + identity["usec"] <= ended_us):
                raise Hold("process cohort coverage unavailable during execution: " + str(pid))
            continue
        if marker in buf.raw[:size.value].split(b"\0"):
            members.append(identity)
    return members


def execute(reg, args):
    argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
    if not argv:
        raise Hold("empty command")
    cancel, error = [0], None
    old_handlers = {}
    for sig in (signal.SIGINT, signal.SIGTERM):
        old_handlers[sig] = signal.signal(sig, lambda signum, frame: cancel.__setitem__(0, signum))
    with reg.exclusive():
        run = reg.read(args.run)
        if run["status"] != "running" or not live(run["owner"]):
            raise Hold("execution has no live lease")
        baseline, unknown = identities()
        if cancel[0]:
            for sig, handler in old_handlers.items():
                signal.signal(sig, handler)
            return 128 + cancel[0]
        cohort = uuid.uuid4().hex
        environment = os.environ.copy()
        environment["MC_ARTIFACT_COHORT"] = cohort
        child = subprocess.Popen(argv, start_new_session=True, env=environment)
        identity = birth(child.pid)
        token = uuid.uuid4().hex
        ep = reg.root / "executions" / (token + ".json")
        e = {"token": token, "state": "running", "started": now(), "pgid": child.pid,
             "leader": identity, "cohort_nonce": cohort, "observed": [identity] if identity else [],
             "baseline": baseline, "baseline_unknown": unknown,
             "command": [re.sub(r"(?i)(token|password|secret|key)=.*", r"\1=<redacted>", x) for x in argv]}
        write_json(ep, e)
        run["executions"].append(token)
        reg.save(run)
    started, seen, timed_out = time.monotonic(), {}, False
    def stop_owned():
        # Never signal a reused PID/group or an unrelated process.
        if child.poll() is None and identity and live(identity):
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                if live(identity):
                    os.killpg(child.pid, signal.SIGKILL)

    try:
        while child.poll() is None:
            table = process_table()
            owned = {child.pid}
            for _ in range(len(table)):
                more = {pid for pid, ppid, pgid in table if ppid in owned or pgid == child.pid}
                if more.issubset(owned):
                    break
                owned.update(more)
            for pid in owned:
                ident = birth(pid)
                if ident:
                    seen[(ident["pid"], ident["sec"], ident["usec"])] = ident
            e["observed"] = list(seen.values())
            write_json(ep, e)
            timed_out = bool(args.timeout and time.monotonic() - started >= args.timeout)
            if timed_out or cancel[0]:
                stop_owned()
                break
            time.sleep(0.1)
    except BaseException as exc:
        error = type(exc).__name__ + ": " + str(exc)
        stop_owned()
    finally:
        raw = child.wait()
        e.update(state="terminal", finished=now(), raw_returncode=raw, timed_out=timed_out,
                 cancel_signal=cancel[0], monitor_error=error,
                 duration_seconds=time.monotonic() - started, finished_epoch_us=time.time_ns() // 1000)
        try:
            e["unattributed_survivors"] = unattributed_survivors(e)
        except Hold as exc:
            e["quiescence_coverage_error"] = str(exc)
        write_json(ep, e)
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)
    if cancel[0]:
        return 128 + cancel[0]
    if error:
        return 2
    return 124 if timed_out else (128 - raw if raw < 0 else raw)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", required=True)
    sub = p.add_subparsers(dest="action", required=True)
    b = sub.add_parser("begin")
    for key in ("run-id", "repo", "command"):
        b.add_argument("--" + key, required=True)
    b.add_argument("--owner", type=int, required=True)
    b.add_argument("--dependency-root")
    b.add_argument("--rebuild-required", action="store_true")
    for target in (b, sub.add_parser("protect")):
        if target is not b:
            target.add_argument("--run", required=True)
        target.add_argument("--pin", action="append", default=[])
        target.add_argument("--retry-pending", action="store_true")
        target.add_argument("--final-evidence", action="store_true")
    release = sub.add_parser("release-products")
    release.add_argument("--run", required=True)
    release.add_argument("--receipt", required=True)
    g = sub.add_parser("capture-gradle")
    g.add_argument("--run", required=True)
    g.add_argument("--qualification", required=True)
    g.add_argument("--apply", action="store_true")
    g.add_argument("--fixture", action="store_true")
    a = sub.add_parser("path")
    a.add_argument("--run", required=True)
    a.add_argument("--kind", choices=("products", "integral-result", "integral-directory"), required=True)
    a.add_argument("--configuration", required=True)
    a.add_argument("--requires-rebuild", action="store_true")
    reuse = sub.add_parser("reuse-products")
    reuse.add_argument("--run", required=True)
    reuse.add_argument("--configuration", required=True)
    r = sub.add_parser("reference")
    r.add_argument("--run", required=True)
    r.add_argument("--path", required=True)
    r.add_argument("--kind", choices=("products", "integral-result", "integral-directory"), required=True)
    r.add_argument("--configuration", required=True)
    f = sub.add_parser("finish")
    f.add_argument("--run", required=True)
    f.add_argument("--code", type=int, required=True)
    f.add_argument("--report", required=True)
    i = sub.add_parser("interrupt")
    i.add_argument("--run", required=True)
    i.add_argument("--code", type=int, required=True)
    for action in ("lease-acquire", "lease-release"):
        sub.add_parser(action).add_argument("--run", required=True)
    c = sub.add_parser("cleanup")
    c.add_argument("--apply", action="store_true")
    x = sub.add_parser("exec")
    x.add_argument("--run", required=True)
    x.add_argument("--timeout", type=float, default=0)
    x.add_argument("argv", nargs=argparse.REMAINDER)
    args = p.parse_args()
    try:
        reg = Registry(args.root)
        if args.action == "exec":
            return execute(reg, args)
        with reg.exclusive():
            if args.action == "begin":
                print(reg.begin(args))
            elif args.action == "path":
                print(reg.path(args))
            elif args.action == "reuse-products":
                print(reg.reuse_products(args))
            elif args.action == "finish":
                reg.finish(args)
            elif args.action == "reference":
                reg.reference(args)
            elif args.action == "protect":
                reg.protect(args)
            elif args.action == "release-products":
                reg.release_products(args)
            elif args.action == "capture-gradle":
                print(json.dumps(reg.capture_gradle(args)))
            elif args.action == "interrupt":
                reg.interrupt(args)
            elif args.action.startswith("lease-"):
                reg.lease(args)
            elif args.action == "cleanup":
                print(json.dumps(reg.clean(args.apply)))
        return 0
    except (Hold, OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as exc:
        print("ARTIFACT_MAINTENANCE_HOLD: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
