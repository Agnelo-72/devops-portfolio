# Automation of Site Deployment on EC2 Instance

This phase completes the deployment process started in the previous phases.

I implement a CI/CD pipeline using GitHub Actions to automate the build of the site's Docker image, push it to ECR, and deploy it to the EC2 instance over SSH — triggered on every push to `main`.

This is the piece that closes the loop: [`infra-as-code`](https://github.com/Agnelo-72/infra-as-code) provisions the EC2 instance and ECR repository with Terraform, and this repo gets the site actually running on them.



## What it does??

```text
Push to main
     │
     ▼
GitHub Actions
     │
     ▼
Build Docker image
     │
     ▼
Push image to Amazon ECR
     │
     ▼
SSH into the EC2 instance
     │
     ▼
Pull the new image
     │
     ▼
Run Docker container
     │
     ▼
Website available on EC2
```

The AWS infrastructure used by this pipeline is created in the previous phase:

- **EC2** – runs the website container
- **ECR** – stores the Docker image
- **Security Group** – controls network access
- **IAM Role** – allows the EC2 instance to access ECR
- **GitHub Actions IAM Role** – allows GitHub Actions to access AWS using OIDC

## Project Structure

```text
application-repository/
│
├── Dockerfile
├── website/
│   ├── index.html
│   ├── css/
│   │   └── style.css
│   └── js/
│       └── script.js
│
├── images/
│
└── .github/
    └── workflows/
        └── pipeline-cd.yml
```

## CD Pipeline

The pipeline runs automatically when there is a push to the `main` branch.

It has two jobs:

### 1. `build_ecr`

The first job builds the Docker image and pushes it to Amazon ECR (created by Terraform).

The main steps are:

1. Checkout the repository.
2. Configure AWS credentials using GitHub OIDC.
3. Login to Amazon ECR.
4. Build the Docker image.
5. Tag the image.
6. Push the image to ECR.

### 2. `deploy_ec2`

The second job connects to the EC2 instance using SSH.

It only runs after the first job finishes successfully:

```yaml
needs: job1
```

This is important because the deployment should not start if the Docker image was not built or pushed successfully.

The deployment does the following:

1. Connects to the EC2 instance using SSH.
2. Logs Docker into ECR.
3. Pulls the new Docker image.
4. Starts the container.
5. Checks the running containers.

## Auth (AWS Authentication)

The GitHub Actions workflow uses **OIDC** to access AWS.

This means that AWS access keys are not stored in GitHub Secrets.

GitHub Actions assumes the IAM role:

```text
GitHubActionsRepoApp
```

The workflow has:

```yaml
permissions:
  id-token: write
  contents: read
```

The `id-token: write` permission is required for GitHub Actions to use OIDC.

The EC2 instance also has an IAM role that allows it to access ECR and pull the Docker image.

### GitHub Secrets

The deployment uses two GitHub Secrets:

- `INSTANCE_KEY` – SSH private key used to connect to the EC2 instance.
- `PUBLIC_IP` – public IP address of the EC2 instance.

AWS credentials are **not** stored as GitHub Secrets because AWS access is handled through OIDC.

## Security

Some security choices were made to keep this project simple.

### SSH Access

SSH port `22` is currently open to:

```text
0.0.0.0/0
```

This allows the GitHub-hosted runner to connect to the EC2 instance.

A more restricted solution would be to temporarily allow the IP address of the GitHub runner during the deployment and remove the rule afterwards.

I tested this approach, but it adds more steps to the pipeline. For this personal project, I kept the simpler solution.

### ECR Image Tags

The ECR repository uses:

```text
MUTABLE
```

The current pipeline uses the `v1.0` tag.

A better solution would be to create a unique tag for every build, for example:

```text
v1.0-<commit-sha>
```

This would make it easier to identify and deploy a specific version of the application.

### HTTP

The website is currently available through HTTP on port `80`.

HTTPS was not added in this phase because it would require additional AWS infrastructure, such as a domain, certificate and usually a load balancer.

For this project, the focus of this phase is the CI/CD deployment process.

## Problem Found During Development

(1)
During development, GitHub Actions could not connect to the EC2 instance.

The problem was not the SSH key.

The Security Group only allowed SSH from my home IP address:

```text
<my-ip>/32
```

GitHub-hosted runners use different public IP addresses, so the connection was blocked by the Security Group before the SSH connection could start.

The connection therefore ended with a timeout.

I changed the SSH rule to:

```text
0.0.0.0/0
```

This allowed the GitHub-hosted runner to connect to the EC2 instance.

This was an important lesson about the difference between:

- **SSH authentication** – checking the SSH key.
- **Network access** – checking whether the Security Group allows the connection.

(2)
After changing the website and pushing a new version, the CI/CD pipeline successfully built and pushed the new Docker image to ECR.

However, the deployment failed when starting the new container:
```bash
Conflict. The container name "/site" is already in use
```

The previous container was still running on the EC2 instance. Docker does not allow two containers to use the same name.

I fixed this by stopping and removing the existing container before starting the new one:
```bash
...
docker stop site || true
docker rm site || true
docker run ...
```
This allows the pipeline to replace the old container with the new version after every deployment.