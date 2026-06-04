# Terraform Placeholder

Terraform is intentionally not implemented in Experiment 04.

The first DevBox iteration should be created manually with `scripts/create-devbox-gce.sh` and validated through SSH. After the manual workflow proves that the VM design, access model, tooling prerequisites, and evidence collection are correct, Terraform can be added as a separate focused change.

Future Terraform work should preserve the same principles:

- no secrets in source control;
- least-privilege IAM;
- cost-aware defaults;
- explicit resource naming;
- safe cleanup guidance;
- no unrelated platform automation.
