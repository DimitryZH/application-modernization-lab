"""Run from any directory with Python 3 and Docker Compose. No host SDKs required."""

import hashlib
import argparse, json, os, pathlib, socket, subprocess, sys, threading, time, uuid
from assertions import validate, SERVICES
from redis_contract import check as check_redis, prepare_data, no_application_export

HERE = pathlib.Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("--skip-build", action="store_true")
parser.add_argument("--project")
parser.add_argument(
    "--only",
    choices=["full", "disabled", "unavailable", "refused", "redis"],
    default=None,
)
args = parser.parse_args()
project = args.project or "online-shop-21-" + uuid.uuid4().hex[:8]
assert project.startswith(
    "online-shop-21-"
), "project must be dedicated to this validation"
root = HERE / "output" / project
root.mkdir(parents=True, exist_ok=False)
for directory in ["logs", "raw", "telemetry"]:
    (root / directory).mkdir()
sock = socket.socket()
sock.bind(("127.0.0.1", 0))
port = sock.getsockname()[1]
sock.close()
env = dict(
    os.environ,
    EVIDENCE_DIR=str(root),
    FRONTEND_PORT=str(port),
    REDIS_INSTANCE=project,
    COLLECTOR_UID=str(os.getuid() if hasattr(os, "getuid") else 1000),
    COLLECTOR_GID=str(os.getgid() if hasattr(os, "getgid") else 1000),
    SOURCE_REVISION=subprocess.check_output(
        ["git", "describe", "--always", "--dirty", "--abbrev=40"],
        text=True,
        cwd=HERE.parents[3],
    ).strip(),
)
input_paths = subprocess.check_output(
    [
        "git",
        "ls-files",
        "--cached",
        "--others",
        "--exclude-standard",
        "workloads/online-shop/src",
        "workloads/online-shop/protos",
    ],
    text=True,
    cwd=HERE.parents[3],
).splitlines()
fingerprint = hashlib.sha256()
repo = HERE.parents[3]
for name in sorted(input_paths):
    fingerprint.update(name.encode())
    fingerprint.update((repo / name).read_bytes())
env["SOURCE_REVISION"] += "." + fingerprint.hexdigest()[:12]
base = ["docker", "compose", "-p", project, "-f", str(HERE / "compose.yaml")]
processes = []
threads = []
checks = []


def compose(*cmd, check=True, timeout=600):
    result = subprocess.run(
        base + list(cmd),
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
    )
    with (root / "commands.log").open("a", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n" + result.stdout + "\n")
    if check and result.returncode:
        raise RuntimeError(
            "Compose failed: " + " ".join(cmd) + "\n" + result.stdout[-5000:]
        )
    return result


def capture(service):
    container = compose("ps", "-a", "-q", service).stdout.strip()
    if not container:
        return
    process = subprocess.Popen(
        ["docker", "logs", "--follow", container],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    processes.append(process)

    def consume():
        if service == "redis-cart":
            with (root / "logs" / "redis.log").open("a", encoding="utf-8") as raw:
                for line in process.stdout:
                    raw.write(line)
                    raw.flush()
            return
        with (root / "raw" / f"{service}.txt").open("a", encoding="utf-8") as raw, (
            root / "logs" / f"{service}.jsonl"
        ).open("a", encoding="utf-8") as parsed:
            for line in process.stdout:
                raw.write(line)
                raw.flush()
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(row, dict) or row.get("service.name") != service:
                    continue
                if "trace_id" in row and (
                    len(row["trace_id"]) != 32 or int(row["trace_id"], 16) == 0
                ):
                    row.pop("trace_id", None)
                    row.pop("span_id", None)
                parsed.write(json.dumps(row) + "\n")
                parsed.flush()

    t = threading.Thread(target=consume, daemon=True)
    t.start()
    threads.append(t)


def scenario(mode):
    compose("run", "--rm", "--no-deps", "probe", mode, timeout=300)
    checks.append(mode)
    print("PASS functional", mode, flush=True)


def stop_capture():
    for p in processes:
        if p.poll() is None:
            p.terminate()
    for t in threads:
        t.join(3)
    processes.clear()
    threads.clear()


try:
    check_redis(json.loads(compose("config", "--format", "json").stdout))
    if not args.skip_build:
        compose("--profile", "load", "--profile", "tools", "build", timeout=1800)
    image_records = []
    for service in sorted(SERVICES):
        tag = "online-shop-21-" + service + ":local"
        image = json.loads(
            subprocess.check_output(["docker", "image", "inspect", tag], text=True)
        )[0]
        assert image["Os"] == "linux" and image["Architecture"] == "amd64"
        assert (
            image["Config"].get("Labels", {}).get("org.opencontainers.image.revision")
            == env["SOURCE_REVISION"]
        ), ("stale image; rebuild without --skip-build", service)
        image_records.append(
            {
                "service": service,
                "tag": tag,
                "id": image["Id"],
                "platform": "linux/amd64",
            }
        )
    (root / "image-record.json").write_text(
        json.dumps(
            {"source": env["SOURCE_REVISION"], "images": image_records}, indent=2
        )
    )
    modes = (
        [args.only]
        if args.only
        else ["full", "disabled", "unavailable", "refused", "redis"]
    )
    for mode in modes:
        phase_root = root if mode == "full" else root / mode
        for directory in ["logs", "raw", "telemetry"]:
            (phase_root / directory).mkdir(parents=True, exist_ok=True)
        env["EVIDENCE_DIR"] = str(phase_root)
        env["TELEMETRY_ENABLED"] = "false" if mode == "disabled" else "true"
        env["OTEL_ENDPOINT"] = (
            "http://faults:4319"
            if mode == "unavailable"
            else "http://127.0.0.1:1" if mode == "refused" else "http://collector:4317"
        )
        prepare_data(
            lambda *cmd: compose(*cmd).stdout,
            lambda *cmd: subprocess.run(["docker", *cmd], check=True, timeout=60),
            project,
        )
        compose("up", "-d", "--no-build")
        if mode == "full":
            capture("redis-cart")
            for svc in sorted(SERVICES - {"loadgenerator"}):
                capture(svc)
            scenario(mode)
            compose("--profile", "load", "up", "-d", "--no-build", "loadgenerator")
            capture("loadgenerator")
            time.sleep(15)
            compose("stop", "-t", "15", "loadgenerator")
            start = time.monotonic()
            compose("stop", "-t", "15", *sorted(SERVICES - {"loadgenerator"}))
            elapsed = time.monotonic() - start
            assert elapsed < 20, ("shutdown exceeded", elapsed)
            for service in sorted(SERVICES):
                container = compose("ps", "-a", "-q", service).stdout.strip()
                if container:
                    state = json.loads(
                        subprocess.check_output(
                            [
                                "docker",
                                "inspect",
                                "--format",
                                "{{json .State}}",
                                container,
                            ],
                            text=True,
                        )
                    )
                    assert state["ExitCode"] in (0, 143), (
                        "abnormal shutdown",
                        service,
                        state,
                    )

            time.sleep(3)
            compose("stop", "-t", "15", "redis-cart")
            stop_capture()
            time.sleep(3)
            compose("stop", "collector")
            validate(root)
        elif mode == "redis":
            compose("stop", "redis-cart")
            compose("run", "--rm", "--no-deps", "probe", "redis", timeout=90)
            checks.append("redis")
        else:
            scenario(mode)
            time.sleep(3)
            no_application_export(phase_root)
        if mode != "full":
            started = time.monotonic()
            compose("stop", "-t", "15", *sorted(SERVICES - {"loadgenerator"}))
            elapsed = time.monotonic() - started
            assert elapsed < 20, ("shutdown exceeded", mode, elapsed)
            shutdown_states = {}
            for service in sorted(SERVICES - {"loadgenerator"}):
                container = compose("ps", "-a", "-q", service).stdout.strip()
                state = json.loads(
                    subprocess.check_output(
                        ["docker", "inspect", "--format", "{{json .State}}", container],
                        text=True,
                    )
                )
                assert state["ExitCode"] in (0, 143), (
                    "abnormal shutdown",
                    mode,
                    service,
                    state,
                )
                shutdown_states[service] = {
                    "exit_code": state["ExitCode"],
                    "oom_killed": state["OOMKilled"],
                }
            (root / ("shutdown-" + mode + ".json")).write_text(
                json.dumps({"seconds": elapsed, "services": shutdown_states}, indent=2)
            )
            if mode in ("disabled", "unavailable", "refused"):
                time.sleep(3)
                no_application_export(phase_root)
        states = compose("ps", "-a", "--format", "json").stdout
        (root / f"containers-{mode}.json").write_text(states)
        compose(
            "--profile",
            "load",
            "--profile",
            "tools",
            "down",
            "--volumes",
            "--remove-orphans",
            timeout=90,
        )
    result = {"project": project, "checks": checks, "status": "passed"}
    (root / "result.json").write_text(json.dumps(result, indent=2))
    print("PASS", root, flush=True)
finally:
    stop_capture()
    # Only project-owned ephemeral resources are removed. Built images and evidence remain.
    cleanup = compose(
        "--profile",
        "load",
        "--profile",
        "tools",
        "down",
        "--volumes",
        "--remove-orphans",
        check=False,
        timeout=90,
    )
    remaining = compose("ps", "-a", "-q", check=False).stdout.strip()
    (root / "cleanup.json").write_text(
        json.dumps(
            {"exit_code": cleanup.returncode, "remaining_containers": remaining},
            indent=2,
        )
    )
    if cleanup.returncode or remaining:
        raise RuntimeError("cleanup incomplete")
