# CI/CD Pipeline for Terraform (GitHub Actions + OIDC + AWS)

Runs `terraform plan`/`apply` for [`02-terraform-aws-infra`](../02-terraform-aws-infra) from GitHub Actions, triggered manually, with no AWS keys stored anywhere — authentication is via OIDC.

Code and pipeline live in a separate repo: [infra-as-code](https://github.com/Agnelo-72/infra-as-code). This page is the write-up.

## Pipeline stages

Triggered by `workflow_dispatch` with three boolean inputs — `apply`, `plan_destroy`, `destroy` — all default `false`, so running the workflow with no input touches nothing.

```
checkout → configure AWS credentials (OIDC) → terraform init/validate
  → tflint          (bad HCL / provider misuse)
  → checkov         (security posture, results in Security → Code scanning)
  → plan  → apply     (only if apply=true)
  → plan -destroy → destroy   (only if destroy=true)
```

Full workflow file: [`.github/workflows/terraform.yaml`](https://github.com/Agnelo-72/infra-as-code/blob/main/.github/workflows/terraform.yaml)

**Why OIDC:** GitHub requests a short-lived token per run, AWS exchanges it for temporary credentials via `sts:AssumeRoleWithWebIdentity`. No long-lived key sitting in repo secrets to leak. The trust policy on `GitHubInfraRole` checks two claims — `aud` must be `sts.amazonaws.com`, `sub` must match this repo/branch:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:Agnelo-72*infra-as-code*:ref:refs/heads/main"
}
```

(the wildcard is explained below — it's not decorative)

## Engineering log

Three real problems hit while building this, each worth remembering because the error messages didn't point at the actual cause.

**1. OIDC kept rejecting every AssumeRoleWithWebIdentity call.**
Provider, role, and trust policy all looked correct. The fix came from CloudTrail (Event history → filter `AssumeRoleWithWebIdentity` → open the denied event), which showed the actual `sub` GitHub sent:
`repo:Agnelo-72@92796392/infra-as-code@1376462513:ref:refs/heads/main` — numeric IDs glued onto the owner and repo name. GitHub does this for a while after an account or repo rename, so old trust relationships can't be silently hijacked. The trust policy's condition, written against the clean name, could never match. Fixed by widening the pattern (`repo:Agnelo-72*infra-as-code*:ref:refs/heads/main`) — flagged by AWS's console as an "overly permissive wildcard" warning, which is fair, but in practice only this account can produce a matching token. Meant to be tightened back once the rename settles; not done yet.
*Lesson: when AWS gives a vague auth error, CloudTrail shows the exact request it rejected — faster than guessing at policy JSON.*

**2. The destroy step could silently not destroy anything.**
Early version had `Terraform Plan Destroy` and `Terraform Destroy` share the same plan file as the normal `apply` flow. If someone ran `destroy=true` without `plan_destroy=true`, the destroy step would apply on the file left over from the earlier plan step — a create/update plan, not a destroy one. `terraform apply -destroy <file>` ignores `-destroy` when given a saved plan; it just reapplies whatever the file contains. No error, just the opposite of what was asked. Fixed by having `Terraform Destroy` run `terraform destroy -auto-approve` directly, computing its own plan instead of trusting a file from another step.

**3. Adding Checkov took three broken attempts.**
`bridgecrewio/checkov-action@v3` only accepts `entryPoint`/`args` — wrong version, nothing ran. Switched to `@v12.1347.0`, which accepts the real inputs, but `output_format: cli,sarif` failed: that Checkov build only accepts one output format at a time, not a list — dropped to `sarif` alone. Got a SARIF file, upload still failed with "Resource not accessible by integration" — turned out to be nothing in the YAML at all: private repos need GitHub Advanced Security to use Code Scanning uploads, which isn't on the free plan. Making the repo public fixed it instantly.
*Lesson: three failures, three unrelated layers — action version, a tool limit one level down, and a repo setting with no relation to YAML.*

## Security hardening from the Checkov findings

Checkov flagged 12 issues once it was actually running. Fixes:

```hcl
resource "aws_instance" "website_server" {
  ebs_optimized = true              # free on t3 (Nitro-based)
  monitoring    = true              # CloudWatch detailed monitoring — has a small real cost
  metadata_options {
    http_tokens   = "required"      # enforce IMDSv2
    http_endpoint = "enabled"
  }
  root_block_device {
    encrypted = true                # ⚠ forces instance replacement, not an in-place update
  }
}

resource "aws_ecr_repository" "ecr_site" {
  image_tag_mutability = "IMMUTABLE"          # ⚠ see note below
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration     { encryption_type = "KMS" }  # AWS-managed key, no extra cost
}
```

Two things to know before applying:
- `root_block_device.encrypted` can't change on a live instance — Terraform will show `-/+` (destroy + recreate), not `~`. Read the plan before approving.
- `IMMUTABLE` breaks a `latest` tag on the second push. The deploy workflow (not built yet) needs to stop pushing `latest` and always deploy by commit SHA once it exists — catching this now, before it silently breaks a future release.

## Manual verification

After the first successful `apply`, confirmed the instance was actually reachable, not just "created" per Terraform:

```
$ ssh -i ~/.ssh/chave-site-prod.pem ec2-user@34.231.241.181
[ec2-user@ip-172-31-8-145 ~]$ ls
[ec2-user@ip-172-31-8-145 ~]$
```

Connects fine, empty home dir — expected, nothing installed yet (no `user_data`). Still using `chave-site-prod.pem`, the same key exposed earlier in this project — rotating it is still open, see below.

## Still to do

- Tighten the `sub` trust policy condition once the embedded owner/repo IDs drop out of CloudTrail events.
- Rotate the EC2 key pair (`key_name` in `ec2.tf`) — the key currently in use was exposed earlier.
- Add `user_data` to install Docker automatically instead of by hand.
- Build the deploy job (build → push to ECR → SSH restart on EC2); stop tagging `latest` when this lands.
- Add a `concurrency` block so two runs can't race on the same S3 state.
- Add a confirmation gate in front of `destroy` — anyone with write access can currently tear everything down in one click.
- `upload-sarif@v3` is flagged for deprecation in December 2026 — move to `v4` before then.
