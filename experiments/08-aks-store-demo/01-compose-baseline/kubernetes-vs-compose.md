# Kubernetes Versus Compose Notes

The upstream Kubernetes manifests are supporting evidence only; local runtime authority for Experiment 08A is the approved Compose baseline.

Important differences:

- Kubernetes uses published application images while Compose builds local images from source.
- Kubernetes exposes frontend/admin through service objects; Compose binds UI ports to `127.0.0.1` only.
- Kubernetes backend services are cluster-internal; this baseline keeps Compose backends internal as well.
- Kubernetes probes and init behavior are not reproduced exactly; validation uses Compose health plus application-level readiness.
- Kubernetes excludes `ai-service` from the full all-in-one non-AI deployment path; Compose keeps it optional behind profile `ai`.
- Kubernetes workload rates differ from Compose and are not treated as local validation requirements.
