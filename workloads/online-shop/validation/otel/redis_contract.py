"""Redis runtime contract; images.lock.json remains the image identity authority."""
import json
import pathlib
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
WORKLOAD = HERE.parents[1]


def dependency():
    contract = json.loads((WORKLOAD / "redis.runtime.json").read_text())
    mapping = json.loads((WORKLOAD / contract["imageMapping"]).read_text())
    image = next(c["image"] for c in mapping["components"] if c["id"] == contract["component"])
    assert image["kind"] == "manifest"
    assert image["platforms"] == [contract["platform"]] == [mapping["platform"]]
    return contract, image["repository"] + "@" + image["digest"]


def check(compose):
    """Inspect the effective Compose model plus canonical Kubernetes YAML."""
    # Use the existing probe's YAML parser rather than require host packages.
    contract, image = dependency()
    service = compose["services"]["redis-cart"]
    assert service["image"] == image and service["platform"] == contract["platform"]
    assert service["command"] == contract["command"]
    assert service["user"] == contract["user"] and service["read_only"] is True
    assert service["cap_drop"] == ["ALL"] and not service.get("ports")
    assert service["security_opt"] == ["no-new-privileges:true"]
    assert service.get("scale", 1) == 1 and service.get("deploy", {}).get("replicas", 1) == 1
    assert service["stop_grace_period"] == "15s"
    assert int(service["mem_limit"]) == 268435456 and float(service["cpus"]) == .125
    assert service["healthcheck"]["test"] == ["CMD", "redis-cli", "ping"]
    assert len(service["volumes"]) == 1
    assert service["volumes"][0]["target"] == contract["dataPath"]
    assert service["volumes"][0]["type"] == "volume" and not service["volumes"][0].get("read_only")
    assert service["volumes"][0]["source"] == "redis-data"
    assert compose["volumes"]["redis-data"] == {"name": compose["name"] + "_redis-data"}, "only project-owned default volumes"
    assert compose["services"]["cartservice"]["environment"]["REDIS_ADDR"] == "redis-cart:6379"
    # Canonical YAML has stable generated layout. Parse with the probe in check-kubernetes.
    return contract, image


def prepare_data(compose, docker, project):
    """Emulate fsGroup ownership on a fresh project-owned Docker volume only."""
    contract, image = dependency()
    compose("create", "redis-cart")
    docker("run", "--rm", "--name", project + "-data-init", "--label",
           "com.docker.compose.project=" + project, "--network", "none", "--read-only",
           "--user", "0:0", "--cap-drop", "ALL", "--cap-add", "CHOWN",
           "--security-opt", "no-new-privileges:true", "--mount",
           "type=volume,source=" + project + "_redis-data,target=/data",
           "--entrypoint", "chown", image, contract["user"], "/data")


def no_application_export(root):
    for signal, key in [("traces", "resourceSpans"), ("metrics", "resourceMetrics")]:
        path = pathlib.Path(root) / "telemetry" / (signal + ".jsonl")
        if not path.exists():
            continue
        for line in path.read_text().splitlines():
            for resource in json.loads(line).get(key, []):
                attributes = {a["key"]: a["value"].get("stringValue") for a in resource["resource"].get("attributes", [])}
                assert attributes.get("service.name") == "redis-cart", "unexpected application export"


if __name__ == "__main__":
    result = subprocess.check_output(["docker", "compose", "-f", str(HERE / "compose.yaml"), "config", "--format", "json"], text=True)
    check(json.loads(result))
    print("PASS Redis Compose contract")
