# Cost and Cleanup Notes

## Cost drivers

The main DevBox cost drivers are:

- Compute Engine VM runtime.
- Persistent boot disk storage.
- External IP usage, if applicable.
- Network egress.
- Growth of Docker images, build caches, and logs on disk.

## Stop unused VMs

Stop the DevBox when it is not actively being used:

```bash
gcloud compute instances stop compose-aspire-devbox-04 \
  --project ai-agent-host-497515 \
  --zone us-central1-a
```

Stopping the VM stops compute charges, but persistent disk charges continue.

## Start the VM again

```bash
gcloud compute instances start compose-aspire-devbox-04 \
  --project ai-agent-host-497515 \
  --zone us-central1-a
```

## Delete unused VMs

Delete the DevBox when the experiment is complete and the evidence has been collected:

```bash
gcloud compute instances delete compose-aspire-devbox-04 \
  --project ai-agent-host-497515 \
  --zone us-central1-a
```

Review the command output before confirming deletion. Deleting the VM is destructive and may delete the boot disk depending on disk settings.

## Persistent disk costs

The boot disk can continue to incur cost while the VM is stopped. If the VM is deleted but a disk is preserved, delete the disk separately after confirming no evidence or work remains on it.

List disks:

```bash
gcloud compute disks list \
  --project ai-agent-host-497515 \
  --filter="zone:(us-central1-a)"
```

## Docker storage growth

Docker images and build cache can consume disk space quickly.

Inspect usage:

```bash
docker system df
```

Cleanup unused Docker data only after confirming no required containers, images, volumes, or build cache entries are needed:

```bash
docker system prune
```

Use volume cleanup with extra care because it can remove application data:

```bash
docker volume ls
```

## Development-only purpose

The DevBox is a development and validation host. It is not intended for production workloads, public service hosting, or long-lived unattended infrastructure.
