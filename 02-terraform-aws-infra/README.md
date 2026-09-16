# Terraform AWS Infrastructure

Provisions the AWS infrastructure needed to run the containerized site from [`01-docker-static-website`](../01-docker-static-website): an EC2 instance, a Security Group with least-privilege ingress rules, and an ECR repository to store the built image. Terraform state is stored remotely in an S3 bucket rather than locally.

## Architecture

```
                    ┌───────────────────────────┐
   docker push      │   Amazon ECR               │
   ───────────────► │   site_prod repository     │
                     └──────────────┬────────────┘
                                     │ docker pull
                                     ▼
   ┌─────────────────────────────────────────────┐
   │  EC2 instance (t3.micro, Amazon Linux)        │
   │  - Docker installed & running                 │
   │  - IAM instance profile → pulls from ECR       │
   │                                                 │
   │  Security Group:                               │
   │    22  (SSH)   ← restricted to a single IP      │
   │    80  (HTTP)  ← open                           │
   │    443 (HTTPS) ← open                           │
   │    all outbound ← open                          │
   └─────────────────────────────────────────────┘

   Terraform state → S3 bucket (encrypted, remote backend)
```

## Files

| File | Responsibility |
|---|---|
| `provider.tf` | Configures the AWS provider and target region |
| `backend.tf` | Configures the remote S3 backend for Terraform state |
| `ec2.tf` | EC2 instance, Security Group, and ingress/egress rules |
| `ecr.tf` | ECR repository for the Docker image |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- AWS CLI configured with credentials that have permission to manage EC2, ECR, S3 and IAM instance profiles: `aws configure`
- An existing S3 bucket for the remote state (referenced in `backend.tf`)
- An SSH key pair already created in the target AWS region
- An IAM instance profile with ECR pull permissions (referenced by `iam_instance_profile` in `ec2.tf`)

## Usage

```bash
terraform init      # downloads the AWS provider, configures the S3 backend
terraform fmt        # normalizes formatting
terraform validate   # checks syntax without contacting AWS
terraform plan        # shows exactly what will be created/changed/destroyed
terraform apply        # applies the plan (requires typing "yes")
```

To tear everything down:

```bash
terraform destroy
```

## Design notes

- **Security Group scope.** SSH is restricted to a single `/32` CIDR (the author's IP) rather than `0.0.0.0/0` — least-privilege by default. HTTP/HTTPS are open, as expected for a public-facing web server.
- **Remote state on S3, encrypted.** Keeps the state out of any single machine's disk and makes the setup safe to work on from more than one workstation.
- **IAM instance profile instead of static credentials.** The EC2 instance authenticates to ECR through an attached IAM role rather than access keys baked into the machine — the AWS-recommended pattern for workload identity.

