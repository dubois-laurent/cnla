# Projet CNLA — Full-stack app · CI/CD · AWS Infrastructure

> **Group 2** — HETIC  
> Laurent Dubois · Alexia Mea · Berenice kenne · Camille Paillou

Monorepo for a **React + Vite** frontend, **Express** API, **PostgreSQL** database and **nginx** reverse proxy, with a full **GitLab CI/CD pipeline** deploying to **AWS** (ECR, EC2, ALB, SSM, S3, CloudWatch).

---

## Table of contents

1. [Quick start](#quick-start-docker)
2. [Repository layout](#repository-layout)
3. [CI/CD pipeline](#cicd-pipeline)
4. [AWS infrastructure](#aws-infrastructure)
5. [FinOps & cleanup](#finops--cleanup)
6. [GitLab CI variables](#gitlab-ci-variables)
7. [Documentation](#documentation)
8. [Credits](#credits)

---

## Quick start (Docker)

**Prerequisites:** [Docker](https://docs.docker.com/get-docker/) with Compose, [GNU Make](https://www.gnu.org/software/make/).

```bash
cp .env.example .env   # fill in POSTGRES_*, VITE_*, DATABASE_URL
make up
```

| What | URL |
|------|-----|
| App — nginx (static UI + `/api/` proxy) | http://localhost:8088 |
| API — direct | http://localhost:3000 |
| Vite dev server — direct | http://localhost:5173 |

Common targets: `make help`, `make down`, `make logs`, `make logs s=backend`, `make shell s=frontend`.

---

## Repository layout

```
.
├── backend/                  Express REST API (/users CRUD), pg, pnpm
├── frontend/                 React 19 + Vite SPA, pnpm
├── docker-compose.yml        Local stack (db, backend, frontend, nginx)
├── Makefile                  Compose helpers
└── devops/
    ├── ci/
    │   ├── gitlab/           GitLab CI YAML (pipeline, lint, test, build, deploy)
    │   └── scripts/          Helper shell scripts (wait-for-url, instance provisioning…)
    ├── docker/               Dockerfiles for all services (dev + prod)
    └── aws/
        ├── lib/              Shared shell libraries (args.sh, finops_common.sh)
        ├── ec2/              deploy.sh · rollback.sh · rolling_deploy.sh
        ├── ecr/              prune_image.sh
        ├── s3/               archive_logs.sh · prune_logs.sh
        ├── cloudwatch/       logs_retention.sh · watch_config.sh
        └── finops-cleanup.sh Orchestrator for all FinOps cleanup jobs
```

---

## CI/CD pipeline

**Stages:** `lint → test → build → deploy → finops`

**Triggers:**
- `feature/*`, merge requests, `dev`, `main` → **lint / test / build**
- `dev` push → **deploy:preprod** (single EC2 instance via SSM)
- `main` push → **deploy:prod** (rolling deploy across prod instances via SSM + ALB)

### Lint

| Job | Tool | What |
|-----|------|------|
| `lint:compose` | Docker Compose | Validates `docker-compose.yml` |
| `lint:hadolint` | Hadolint v2.12 | All Dockerfiles under `devops/docker/` |
| `lint:yaml` | yamllint | `docker-compose.yml`, `.gitlab-ci.yml`, `devops/ci/gitlab/` |
| `lint:shell` | shellcheck | Shell scripts |
| `lint:backend` | Node | Syntax check + dependency imports |
| `lint:eslint` | ESLint | React frontend |

All lint jobs use `allow_failure: false`.

### Test

| Job | What |
|-----|------|
| `test:unit` | Node test runner + **c8** coverage (Cobertura/lcov) + JUnit |
| `test:integration` | Compose stack (db + backend) + API health wait + JUnit |
| `test:e2e` | Full Compose stack + nginx health wait + JUnit |
| `test:images` | Image build + **Trivy** security scan (HIGH/CRITICAL) |

JUnit reports uploaded as artifacts and shown in GitLab UI.  
Coverage visible in `test:unit` via the `coverage:` regex.

### Build

Builds `backend`, `frontend`, `nginx` images with Docker-in-Docker and pushes **4 tags** per service to **AWS ECR** (`grp2/aws-hetic/{service}`):

| Tag | Value |
|-----|-------|
| Short SHA | `$CI_COMMIT_SHORT_SHA` |
| Full SHA | `$CI_COMMIT_SHA` |
| Branch slug | `$CI_COMMIT_REF_SLUG` |
| Latest | `latest` |

### Deploy

| Job | Branch | Mechanism |
|-----|--------|-----------|
| `deploy:preprod` | `dev` | Base64-encoded script sent via **AWS SSM** to `PREPROD_INSTANCE_ID`; pulls images, stops/removes old containers, starts new ones on `app-net` |
| `deploy:prod` | `main` | **Rolling deploy** via `rolling_deploy.sh`: for each instance — deregister from ALB → drain → SSM deploy → re-register → wait for health check |

---

## AWS infrastructure

### ECR — Container Registry

Namespace: `grp2/aws-hetic` — repositories: `backend`, `frontend`, `nginx`.  
Region: `eu-central-1`.

ECR authentication uses `aws ecr get-login-password` piped to `docker login` in both CI and on-instance scripts.

### EC2 — Runtime

Containers run directly with `docker run` (no Compose on EC2) on a shared `app-net` Docker network:

```
nginx  (:80, --restart unless-stopped)  →  frontend + backend
```

**Instance Profile** (`EC2-Readonly-Role`) grants ECR read + SSM access — no port 22 needed.

#### Scripts (`devops/aws/ec2/`)

| Script | Purpose |
|--------|---------|
| `deploy.sh` | Pull images, stop/remove old containers, start new ones |
| `rollback.sh` | Delegates to `deploy.sh` with a previous `image_tag` |
| `rolling_deploy.sh` | Zero-downtime rolling update: ALB drain → SSM deploy → ALB re-register, instance by instance |

All scripts use `key=value` CLI args parsed by `lib/args.sh`.

### ALB — Application Load Balancer (prod)

`rolling_deploy.sh` uses:
- `aws elbv2 deregister-targets` → 30 s connection drain
- `aws ssm send-command` + `aws ssm wait command-executed`
- `aws elbv2 register-targets` + `aws elbv2 wait target-in-service`

### CloudWatch

| Script | Purpose |
|--------|---------|
| `cloudwatch/logs_retention.sh` | Set retention on the GitLab runner log group |
| `cloudwatch/watch_config.sh` | Create dashboard + CPU alarm + ALB 5xx alarm with SNS notification |

### S3 — Log archiving

| Script | Purpose |
|--------|---------|
| `s3/archive_logs.sh` | Compress + upload logs: `s3://<bucket>/<env>/YYYY/MM/DD/<hostname>.log.gz` |
| `s3/prune_logs.sh` | Delete S3 log objects older than `retention_days` (default: 30) |

---

## FinOps & cleanup

`devops/aws/finops-cleanup.sh` orchestrates all cleanup in one pass:

```bash
sh devops/aws/finops-cleanup.sh \
  aws_region=eu-central-1 \
  aws_account_id=123456789012 \
  dry_run=true \        # set to false to actually delete
  confirm=true \        # interactive confirmation
  ecr_keep_count=10 \   # images to keep per repository
  s3_bucket=my-logs \   # opt-in (skip_s3=true by default)
  s3_retention_days=30
```

| Sub-script | Default behaviour |
|-----------|------------------|
| `ecr/prune_image.sh` | Keep 10 most recent images per repo |
| `s3/prune_logs.sh` | Delete objects older than 30 days (opt-in) |
| `cloudwatch/log_retention.sh` | Set retention to 30 days on any log group |

All scripts support `dry_run=true` (default) — no destructive action without explicit opt-out.

---

## GitLab CI variables

Configure under **Settings → CI/CD → Variables** (mask sensitive values):

| Variable | Used by | Description |
|----------|---------|-------------|
| `AWS_ACCESS_KEY_ID` | build, deploy | IAM key with ECR push + SSM + ELBv2 rights |
| `AWS_SECRET_ACCESS_KEY` | build, deploy | IAM secret |
| `AWS_REGION` | build, deploy | e.g. `eu-central-1` |
| `AWS_ACCOUNT_ID` | build, deploy | 12-digit AWS account ID |
| `PREPROD_INSTANCE_ID` | deploy:preprod | EC2 instance ID (`i-0abc…`) |
| `PROD_INSTANCE_1_ID` | deploy:prod | First prod EC2 instance ID |
| `PROD_INSTANCE_2_ID` | deploy:prod | Second prod EC2 instance ID |
| `PROD_TG_ARN` | deploy:prod | ALB target group ARN |

Never commit secrets. Use GitLab variable masking for all AWS credentials.

---

## Documentation

- **[`backend/README.md`](backend/README.md)** — environment variables, API contract, local `pnpm` vs Docker.
- **[`frontend/README.md`](frontend/README.md)** — Vite env vars, URLs, scripts.
- **[`devops/README.md`](devops/README.md)** — Compose wiring, CI jobs, Dockerfiles.

---

## Credits

**Group 2 — HETIC**

| Name | Role |
|------|------|
| Laurent Dubois | CEO |
| Alexia Mea  | CTO |
| Berenice kenne | Developer |
| Camille Paillou | Developer |

ECR namespace: `grp2/aws-hetic`

## Local development without Docker

Install **Node.js** (LTS) and **pnpm**, run Postgres, then `pnpm install` and run **`pnpm dev`** / **`pnpm start`** in **`frontend/`** and **`backend/`**. See each package README for details.
