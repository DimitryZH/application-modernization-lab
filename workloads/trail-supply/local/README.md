# Local Trail Supply browser review

This configuration runs source-built application images in a dedicated Compose
project until explicitly stopped. It does not start Docker Desktop. The
storefront and catalog use the owner-approved Trail Supply concept and assets.
It is a demo: payment/shipping are simulated, confirmation email is dummy, and
assistant/packaging are disabled. Never enter real personal or payment data.

The telemetry harness cannot serve this role unchanged: it uses a fault proxy,
Collector, evidence capture and automatic cleanup. `compose.yaml` here reuses its
application build contexts/runtime settings with direct service endpoints. It
keeps service identities and Redis security/persistence settings, while disabling
SDK export for manual review. No probe, fault proxy or Collector is needed.

## Prepare and start

Use Docker Desktop's Linux containers after the owner explicitly starts it.
Requires local build capacity, package/registry network access and a pullable
pinned Redis mirror. The mirror's publication/equality/attestation is still pending
in the inherited source contract. If unavailable, stop and resolve that dependency;
do not silently substitute another image or weaken its contract.

Run from the repository root in PowerShell. Keep this shell and `$trailProject`
for the session, or record the displayed project name for later cleanup.

```powershell
$trailProject = 'trail-supply-review-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$trailCompose = 'workloads/trail-supply/local/compose.yaml'
$env:SOURCE_REVISION = (git describe --always --dirty --abbrev=40).Trim()
$env:FRONTEND_PORT = '18081'
$env:BASE_URL = ''
Write-Output $trailProject

docker compose -p $trailProject -f $trailCompose config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Compose configuration failed' }
docker compose -p $trailProject -f $trailCompose build
if ($LASTEXITCODE -ne 0) { throw 'Source build failed; do not start stale images' }
docker compose -p $trailProject -f $trailCompose up -d --no-build
if ($LASTEXITCODE -ne 0) { throw 'Startup failed; inspect logs and use scoped cleanup' }

$ready = $false
for ($attempt = 0; $attempt -lt 90; $attempt++) {
    try {
        $response = Invoke-WebRequest "http://127.0.0.1:$env:FRONTEND_PORT/" -TimeoutSec 5
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw 'Storefront not ready; inspect Compose logs before continuing' }
```

The default storefront is [localhost:18081](http://127.0.0.1:18081/), bound only to
loopback. No backend or Redis ports are published. There are no global container,
network or volume names. Project names isolate containers, networks and storage;
`trail-supply-review-*` image tags are local build caches, separate from validation
and Online Shop tags. Do not concurrently rebuild those shared review tags for
different source revisions. Loadgenerator is opt-in (`--profile load`), not part
of visual review startup. The review build is not strict build acceptance; use
`validation/build/verify.py` from a clean LF checkout for that gate.

Redis has one serving instance, UID/GID 1000:1000, a read-only root, dropped
capabilities, no-new-privileges and a project-owned writable volume. Its separate
network-isolated CHOWN-only init container sets volume ownership before Redis
starts. This helper uses the same pinned Redis image and is not an extra backend.

## Review and diagnose

```powershell
docker compose -p $trailProject -f $trailCompose ps -a
docker compose -p $trailProject -f $trailCompose logs --tail 100 frontend cartservice redis-cart
```

Keep the stack running while the owner reviews desktop/mobile pages, all nine
products, quantity/cart, empty cart, currency change, demo checkout, confirmation,
error states and keyboard navigation. All displayed images, styles and fonts are local. See the validation record for
actual browser checks; owner visual acceptance is separate.
SDK export is disabled, but ordinary application logs continue; this is not a
correlated-log/telemetry-delivery validation session.

## Stop and cleanup

Stopping Redis loses in-memory carts even if the volume is retained. The cleanup
command below removes only the named review project's containers/network and its
synthetic volume; it destroys that session's cart data and diagnostic files.
Images and build caches remain. Never use global prune or another project's name.

```powershell
if ($trailProject -notmatch '^trail-supply-review-[a-f0-9]{8}$') { throw 'Unexpected review project' }
docker compose -p $trailProject -f $trailCompose down --volumes --remove-orphans
```

There is no auto-cleanup so owner review can continue as long as needed. If startup
fails, inspect logs and use the same scoped cleanup command. Local review consumes
resources until stopped; no cloud resource or image publication is involved.

## Prefixed storefront checks

The frontend passes through `BASE_URL`, `FRONTEND_MESSAGE`, `CYMBAL_BRANDING` and
`BANNER_COLOR` unchanged. `BANNER_COLOR` retains its inherited unused behavior;
`CYMBAL_BRANDING=true` explicitly selects the legacy alternate favicon. Use a
separate temporary project and port (for example 18082) with `BASE_URL=/trail` to
check `/trail/` without touching the owner-review session. Loadgenerator does not
support prefixed paths and must remain disabled. Restore `BASE_URL` to empty for
the default owner URL. Cleanup only that temporary project's synthetic resources.
