# DevBox Security Hardening Report

## Summary

Minimal remote-access hardening was applied to the existing Experiment 04 DevBox before Experiment 05.

Final status: `PASS`

## Date

- Hardening date: 2026-06-09

## Scope

- Project: `ai-agent-host-497515`
- Zone: `us-central1-a`
- VM: `compose-aspire-devbox-01`
- Network: `default`

No Terraform was created. Shared default-network firewall rules and unrelated resources were not modified.

## Previous security posture

Before hardening:

- the VM was stopped;
- OS Login was enabled on the VM;
- the VM had no attached service account or access scopes;
- Shielded VM protections were enabled;
- the VM had an ephemeral external IPv4 access configuration;
- `default-allow-ssh` allowed TCP port 22 from `0.0.0.0/0`;
- `default-allow-rdp` allowed TCP port 3389 from `0.0.0.0/0`;
- the VM had no network tags;
- the connection helper did not enable IAP tunneling by default.

The main DevBox-specific risk was direct public SSH reachability through the external IP and the broad shared SSH firewall rule.

## Selected improvement

The smallest practical improvement was to move SSH access to IAP without redesigning the shared network or breaking required outbound internet access:

1. Create a tagged firewall rule that allows TCP port 22 only from the Google Cloud IAP TCP forwarding range.
2. Create a lower-priority tagged rule that denies direct SSH from `0.0.0.0/0`.
3. Retain the ephemeral external IP because the current network has no Cloud NAT and the DevBox requires outbound internet access.
4. Keep OS Login enabled.
5. Make the existing connection helper use IAP by default.

The shared `default-allow-ssh` and `default-allow-rdp` rules were intentionally left unchanged because modifying them could affect unrelated resources in the default network.

## Changes applied

### Firewall rules

Created:

| Name | Priority | Action | Protocol and port | Source range | Target tag |
| --- | --- | --- | --- | --- | --- |
| `devbox-allow-iap-ssh` | `900` | `ALLOW` | `tcp:22` | `35.235.240.0/20` | `devbox-iap-ssh` |
| `devbox-deny-public-ssh` | `1000` | `DENY` | `tcp:22` | `0.0.0.0/0` | `devbox-iap-ssh` |

### VM access configuration

- Added network tag: `devbox-iap-ssh`.
- Retained the ephemeral external IP for outbound internet access.
- Preserved VM-level metadata: `enable-oslogin=TRUE`.
- Preserved the stopped VM state after validation.

### Repository configuration

- Updated `scripts/create-devbox-gce.sh` to default to the `devbox-iap-ssh` network tag.
- Added a creation guard that requires both reviewed hardened SSH firewall rules.
- Updated `scripts/check-local-gcloud.sh` to include the IAP API in readiness checks.
- Updated `scripts/connect-devbox.sh` to enable `--tunnel-through-iap` by default.
- Updated the relevant setup and access documentation to describe the hardened IAP SSH access model.

## Validation

The VM was temporarily started only to validate the new access path.

IAP SSH command shape:

```bash
gcloud compute ssh compose-aspire-devbox-01 \
  --project ai-agent-host-497515 \
  --zone us-central1-a \
  --tunnel-through-iap
```

Read-only remote checks confirmed:

- the expected DevBox hostname;
- a non-root OS Login user;
- `enable-oslogin=TRUE`;
- successful command execution through the IAP tunnel;
- successful outbound HTTPS access.

IAP SSH validation result: `PASS`

Direct public TCP port 22 validation result: `BLOCKED`

After validation, the VM was stopped again. Final checks confirmed:

- VM status: `TERMINATED`;
- network tag: `devbox-iap-ssh`;
- OS Login: enabled;
- ephemeral external IP: present for outbound access;
- direct public TCP port 22: blocked.

## Issues and warnings

- Removing the external IP was tested first, but outbound HTTPS timed out because the default network has no Cloud NAT. The external IP was restored after direct public SSH was blocked with the tagged deny rule.
- The local Windows SSH client displayed a first-connection host-key prompt for the IAP endpoint. The remote validation commands completed successfully.
- Shared `default-allow-ssh` and `default-allow-rdp` rules still allow traffic from `0.0.0.0/0`. The tagged DevBox SSH deny rule overrides the shared SSH allow rule for this VM, but the shared rules remain a project-level risk.
- The DevBox still uses the shared default VPC and subnet.
- The DevBox retains an ephemeral external IP because adding Cloud NAT would exceed the minimal hardening scope.
- IAP access depends on appropriate IAM permissions for each operator.

## Remaining risks

- The VM still has a public IP and is exposed to any applicable shared or future firewall rules other than the blocked SSH path.
- The shared default network does not provide strong isolation from other resources in its internal address range.
- Firewall logging is not enabled for the DevBox SSH rules.
- Operator IAM remains broader than the least-privilege target and should be reviewed separately.

## Recommended next steps

1. Configure the Codex Remote SSH project to use the hardened IAP SSH path.
2. Verify the exact least-privilege IAM roles required for future DevBox operators.
3. Keep the VM stopped when it is not actively used.
4. Treat dedicated VPC design and shared default-rule cleanup as separate infrastructure work.

## Final status

`PASS`

Direct public SSH to the DevBox is blocked, SSH access through IAP was validated, required outbound internet access remains available, OS Login remains enabled, and the VM was returned to its stopped state.
