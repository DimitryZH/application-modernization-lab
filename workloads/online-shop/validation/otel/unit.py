"""Reproduce service unit tests without installing host language SDKs."""

import argparse, json, pathlib, subprocess, time

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parents[1] / "src"
parser = argparse.ArgumentParser()
parser.add_argument(
    "--output", type=pathlib.Path, default=HERE / "output" / "unit-tests"
)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
results = []


def run(name, cmd):
    start = time.monotonic()
    result = subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=900
    )
    (args.output / (name + ".log")).write_text(result.stdout, encoding="utf-8")
    results.append(
        {
            "check": name,
            "exit_code": result.returncode,
            "seconds": round(time.monotonic() - start, 2),
        }
    )
    print(("PASS" if result.returncode == 0 else "FAIL"), name, flush=True)
    if result.returncode:
        raise RuntimeError(result.stdout[-4000:])


try:
    for service in [
        "frontend",
        "checkoutservice",
        "productcatalogservice",
        "shippingservice",
    ]:
        run(
            service,
            [
                "docker",
                "run",
                "--rm",
                "--mount",
                f"type=bind,source={SRC/service},target=/source,readonly",
                "-v",
                "online-shop-21-gomod:/go/pkg/mod",
                "-v",
                "online-shop-21-gocache:/root/.cache/go-build",
                "golang:1.24.3-alpine",
                "sh",
                "-c",
                "cp -R /source /tmp/service; cd /tmp/service; go test ./...",
            ],
        )
    for service in ["currencyservice", "paymentservice"]:
        run(
            service,
            [
                "docker",
                "run",
                "--rm",
                "--entrypoint",
                "npm",
                f"online-shop-21-{service}:local",
                "test",
            ],
        )
        run(
            service + "-enabled-startup",
            [
                "docker",
                "run",
                "--rm",
                "-e",
                "ONLINE_SHOP_TELEMETRY_ENABLED=true",
                "-e",
                "OTEL_TRACES_SAMPLER_ARG=1",
                "-e",
                "OTEL_METRIC_EXPORT_INTERVAL=1000",
                "-e",
                "OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:1",
                "--entrypoint",
                "node",
                f"online-shop-21-{service}:local",
                "-e",
                'require("./telemetry").operation("test.shutdown",()=>{});process.kill(process.pid,"SIGTERM")',
            ],
        )
    for service in ["emailservice", "recommendationservice", "loadgenerator"]:
        run(
            service,
            [
                "docker",
                "run",
                "--rm",
                "--entrypoint",
                "python",
                "--mount",
                f"type=bind,source={SRC/service},target=/source,readonly",
                "-w",
                "/source",
                f"online-shop-21-{service}:local",
                "-m",
                "unittest",
                "-v",
                "test_telemetry",
            ],
        )
    run(
        "cartservice",
        [
            "docker",
            "run",
            "--rm",
            "--mount",
            f'type=bind,source={SRC/"cartservice"},target=/source,readonly',
            "-v",
            "online-shop-21-nuget:/root/.nuget/packages",
            "mcr.microsoft.com/dotnet/sdk:9.0.100-noble",
            "sh",
            "-c",
            "cp -R /source /tmp/cartservice; cd /tmp/cartservice; DOTNET_CLI_TELEMETRY_OPTOUT=1 dotnet test tests/cartservice.tests.csproj --verbosity minimal",
        ],
    )
    # Java's test is also a required step of the actual release Dockerfile.
    run(
        "adservice",
        [
            "docker",
            "build",
            "--target",
            "builder",
            "--platform",
            "linux/amd64",
            str(SRC / "adservice"),
        ],
    )
finally:
    (args.output / "result.json").write_text(json.dumps(results, indent=2))
