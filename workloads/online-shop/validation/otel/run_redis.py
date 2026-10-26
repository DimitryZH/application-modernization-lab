"""Bounded Redis/cart acceptance using the real cart release Dockerfile. No publication."""
import hashlib
import json
import os
import pathlib
import subprocess
import threading
import time
import uuid

from redis_contract import HERE, WORKLOAD, check, dependency, no_application_export, prepare_data
from redis_assertions import validate


def main():
    project = "online-shop-23-" + uuid.uuid4().hex[:8]
    root = HERE / "output" / project
    for directory in ["logs", "raw", "telemetry"]:
        (root / directory).mkdir(parents=True)
    repo = WORKLOAD.parents[1]
    def git(*args):
        return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()
    # Fail before Docker mutations if source/tooling is not a reviewable commit.
    assert not git("status", "--porcelain", "--", "workloads/online-shop"), "commit source/tooling before acceptance"
    revision = git("rev-parse", "HEAD")
    app_revision = git("log", "-1", "--format=%H", "--", "workloads/online-shop/src/cartservice/src")
    paths = sorted(git("ls-files", "workloads/online-shop/src/cartservice/src", "workloads/online-shop/protos").splitlines())
    digest = hashlib.sha256()
    for name in paths:
        digest.update(name.encode() + b"\0" + (repo / name).read_bytes())
    app_inputs = digest.hexdigest()
    env = {k: v for k, v in os.environ.items() if not k.startswith("COMPOSE_")}
    env.update(EVIDENCE_DIR=str(root), REDIS_INSTANCE=project, COLLECTOR_UID="1000", COLLECTOR_GID="1000", SOURCE_REVISION=app_revision + "." + app_inputs[:12], TOOLING_REVISION=revision)
    base = ["docker", "compose", "-p", project, "-f", str(HERE / "compose.yaml")]
    captures = []
    owns_resources = False
    deadline = time.monotonic() + 900
    report = {"project": project, "tooling_revision": revision, "application_revision": app_revision, "application_inputs_sha256": app_inputs, "status": "incomplete", "checks": []}

    def command(args, timeout=90, checked=True):
        if checked:
            assert time.monotonic() < deadline, "overall 15-minute deadline"
            timeout = min(timeout, max(.1, deadline - time.monotonic()))
        result = subprocess.run(args, env=env, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        with (root / "commands.log").open("a", encoding="utf-8") as output:
            output.write(" ".join(args[:8]) + "\n" + result.stdout + "\n")
        if checked and result.returncode:
            raise RuntimeError("command failed; see ignored commands.log: " + " ".join(args[:8]))
        return result.stdout

    def docker(*args, **kwargs):
        return command(["docker", *args], **kwargs)

    def compose(*args, **kwargs):
        return command(base + list(args), **kwargs)

    def probe(mode, *args):
        return compose("run", "--rm", "--no-deps", "--entrypoint", "python", "probe", "/validation/redis_probe.py", mode, *args)

    def redis(*args):
        return compose("exec", "-T", "redis-cart", "redis-cli", "--raw", *args).strip()

    def wait_redis():
        stop = time.monotonic() + 30
        while time.monotonic() < stop:
            if "PONG" in compose("exec", "-T", "redis-cart", "redis-cli", "ping", checked=False):
                return
            time.sleep(.5)
        raise AssertionError("Redis readiness deadline")

    def capture(service, target, since=None):
        container = compose("ps", "-a", "-q", service).strip()
        # Docker log followers exit on stop. Reattach after restart without replay.
        output = (root / target).open("a", encoding="utf-8")
        args = ["docker", "logs", "--follow"] + (["--since", str(since // 1_000_000_000)] if since else [])
        p = subprocess.Popen(args + [container], stdout=output, stderr=subprocess.STDOUT)
        captures.append((p, output))

    def checkpoint(name):
        report["checks"].append(name)
        print("PASS", name, flush=True)

    try:
        assert docker("version", "--format", "{{.Server.Os}}/{{.Server.Arch}} {{.Server.Version}}").startswith("linux/amd64 ")
        assert docker("context", "inspect", "--format", "{{.Endpoints.docker.Host}}").strip().startswith(("npipe:", "unix:")), "local engine required"
        for kind in ["container", "network", "volume"]:
            assert not docker(kind, "ls", *(["-a"] if kind == "container" else []), "-q", "--filter", "label=com.docker.compose.project=" + project).strip(), "resource collision"
        contract, image = check(json.loads(compose("config", "--format", "json")))
        docker("pull", "--platform", contract["platform"], image, timeout=180)
        selected = json.loads(docker("image", "inspect", image))[0]
        assert selected["Id"] == contract["configDigest"]
        assert selected["Os"] + "/" + selected["Architecture"] == contract["platform"]
        assert image.removeprefix("docker.io/") in selected["RepoDigests"]
        report["redis"] = {"reference": image, "config_digest": selected["Id"], "platform": contract["platform"], "runtime": contract}
        compose("build", "cartservice", "probe", timeout=300)
        report["images"] = {}
        for service in ["cartservice", "probe"]:
            tag = "online-shop-21-" + service + ":local"
            inspected = json.loads(docker("image", "inspect", tag))[0]
            assert inspected["Config"]["Labels"]["org.opencontainers.image.revision"] == env["SOURCE_REVISION"]
            if service == "probe":
                assert inspected["Config"]["Labels"]["online-shop.validation.revision"] == revision
            assert inspected["Os"] + "/" + inspected["Architecture"] == "linux/amd64"
            report["images"][service] = {"id": inspected["Id"], "revision_label": env["SOURCE_REVISION"], "role": "application" if service == "cartservice" else "validation-tool", "tooling_revision": revision if service == "probe" else None}
        owns_resources = True
        probe("check-kubernetes", image)
        prepare_data(compose, docker, project)
        compose("up", "-d", "--no-build", "redis-cart", "collector", "cartservice")
        wait_redis()
        container = compose("ps", "-q", "redis-cart").strip()
        state = json.loads(docker("inspect", container))[0]
        assert state["Config"]["User"] == contract["user"] and state["HostConfig"]["ReadonlyRootfs"]
        assert state["HostConfig"]["CapDrop"] == ["ALL"]
        assert compose("exec", "-T", "redis-cart", "sh", "-c", "id -u; id -g").split() == ["1000", "1000"]
        assert "ro" in compose("exec", "-T", "redis-cart", "sh", "-c", "awk '$2 == \"/\" {print $4}' /proc/mounts")
        compose("exec", "-T", "redis-cart", "sh", "-c", "printf synthetic > /data/storage-marker")
        capture("redis-cart", "logs/redis.log")
        capture("cartservice", "logs/cartservice.jsonl")
        capture("collector", "raw/collector.txt")
        probe("primitives")
        checkpoint("identity/security/strings/hash/expiry/persistence configuration")
        probe("healthy")
        checkpoint("cart CRUD and two-session isolation")
        time.sleep(5)
        before = json.loads(docker("inspect", compose("ps", "-q", "cartservice").strip()))[0]
        shutdown_start = time.monotonic()
        compose("stop", "-t", "15", "redis-cart")
        report["redis_shutdown_seconds"] = time.monotonic() - shutdown_start
        stopped = json.loads(docker("inspect", container))[0]["State"]
        assert stopped["ExitCode"] == 0 and not stopped["OOMKilled"]
        outage = {"stopped_ns": time.time_ns()}
        probe("outage")
        time.sleep(5)
        outage["restored_ns"] = time.time_ns()
        compose("start", "redis-cart")
        wait_redis()
        capture("redis-cart", "logs/redis.log", outage["restored_ns"])
        assert redis("EXISTS", "restart-marker") == "0"
        assert compose("exec", "-T", "redis-cart", "cat", "/data/storage-marker").strip() == "synthetic"
        recovery_start = time.monotonic()
        probe("recovered")
        report["recovery_seconds_including_probe_start"] = time.monotonic() - recovery_start
        after = json.loads(docker("inspect", before["Id"]))[0]
        assert after["State"]["StartedAt"] == before["State"]["StartedAt"] and after["RestartCount"] == before["RestartCount"]
        checkpoint("bounded Redis failure and same-cartservice reconnection; retained storage loses Redis state")
        time.sleep(5)
        compose("stop", "-t", "15", "redis-cart")
        compose("rm", "-f", "-v", "redis-cart")
        docker("volume", "rm", project + "_redis-data")
        prepare_data(compose, docker, project)
        compose("start", "redis-cart")
        wait_redis()
        capture("redis-cart", "logs/redis.log")
        assert compose("exec", "-T", "redis-cart", "sh", "-c", "test ! -e /data/storage-marker && echo absent").strip() == "absent"
        assert redis("DBSIZE") == "0"
        checkpoint("full container/storage replacement resets state")
        # Keep the original collector running across outage; allow final SDK export.
        time.sleep(3)
        compose("stop", "-t", "15", "cartservice")
        time.sleep(3)
        compose("stop", "collector")
        for p, output in captures:
            p.terminate()
            p.wait(timeout=5)
            output.close()
        captures.clear()
        report["signals"] = validate(root, project, outage)
        collector_text = (root / "raw/collector.txt").read_text(errors="replace")
        assert "Error scraping metrics" in collector_text, "missing receiver outage diagnostics"
        report["outage"] = outage
        checkpoint("Redis metrics/stdout, cache CLIENT parentage/RED/correlated logs, privacy")
        # Distinct evidence trees preserve infrastructure metrics without application export.
        for mode in ["disabled", "unavailable"]:
            phase = root / mode
            for directory in ["logs", "raw", "telemetry"]:
                (phase / directory).mkdir(parents=True)
            env["EVIDENCE_DIR"] = str(phase)
            env["TELEMETRY_ENABLED"] = "false" if mode == "disabled" else "true"
            env["OTEL_ENDPOINT"] = "http://127.0.0.1:1"
            compose("up", "-d", "--no-build", "collector", "cartservice")
            probe(mode)
            time.sleep(3)
            compose("stop", "-t", "15", "cartservice")
            time.sleep(3)
            compose("stop", "collector")
            no_application_export(phase)
            assert (phase / "telemetry/metrics.jsonl").stat().st_size > 0, "infrastructure metrics remain enabled"
            checkpoint("cart operations with application telemetry " + mode)
        report["status"] = "passed"
    except BaseException as error:
        report["failure"] = type(error).__name__ + ": " + str(error)
        raise
    finally:
        for p, output in captures:
            p.terminate()
            p.wait(timeout=5)
            output.close()
        cleanup = {"status": "incomplete"}
        try:
            if owns_resources:
                compose("--profile", "tools", "down", "--volumes", "--remove-orphans", checked=False)
            remaining = {kind: docker(kind, "ls", *(["-a"] if kind == "container" else []), "-q", "--filter", "label=com.docker.compose.project=" + project, checked=False).strip() for kind in ["container", "network", "volume"]} if owns_resources else {}
            assert not any(remaining.values()), "project resources remain"
            cleanup = {"status": "passed", "remaining": remaining}
        finally:
            report["cleanup"] = cleanup
            (root / "redis-result.json").write_text(json.dumps(report, indent=2))
            print("Evidence:", root, flush=True)
        assert cleanup["status"] == "passed", "cleanup incomplete"


if __name__ == "__main__":
    main()
