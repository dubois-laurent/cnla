# CI / AWS — sample full-stack app

Monorepo for **continuous integration** (GitLab) and **Docker Compose** development: **React + Vite** frontend, **Express** API, **PostgreSQL**, and **nginx** on port **8088** serving a **static production build** of the SPA while proxying **`/api/`** to the backend. The **frontend** service still runs the **Vite dev server** on **5173** for direct debugging. Assets and CI live under **`devops/`**.

**GitLab (optional):** *Settings → General → Badges* — add **Pipeline status** and **Coverage report** badges (e.g. for **`develop`**).

## Quick start (Docker)

1. **Prerequisites:** [Docker](https://docs.docker.com/get-docker/) with Compose, [GNU Make](https://www.gnu.org/software/make/) (recommended).

2. At the **repository root**, copy **`.env.example`** to **`.env`** and set at least:
   - **Postgres:** `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (must match the connection string you use for the API).
   - **Vite / nginx build:** `VITE_APP_ENV`, `VITE_FRONTEND_URL`, `VITE_FRONTEND_API_URL` — used when building the **nginx** image so the SPA calls the correct API base (e.g. `http://localhost:8088/api/v1`).
   - **`DATABASE_URL`** is expanded in the template for the `db` host from Compose; details in [`devops/README.md`](devops/README.md).

3. Start the stack:

   ```bash
   make up
   ```

4. URLs (see also `make help`):

   | What | URL |
   |------|-----|
   | App (nginx: static UI + `/api/` proxy) | http://localhost:8088 |
   | API (direct) | http://localhost:3000 |
   | Vite dev (direct) | http://localhost:5173 |

Common Make targets: `make help`, `make down`, `make logs`, `make logs s=backend`, `make shell s=frontend`. See the [`Makefile`](Makefile) for the full list.

## Repository layout

| Path | Description |
|------|-------------|
| [`backend/`](backend/) | Express REST API (`/users` CRUD), `pg`, Node **pnpm** |
| [`frontend/`](frontend/) | React 19 + Vite SPA, **pnpm** |
| [`devops/`](devops/) | Dockerfiles, nginx configs, Postgres init SQL, GitLab CI YAML |
| `docker-compose.yml` | Local stack (`db`, `backend`, `frontend`, `nginx`) |
| `.gitlab-ci.yml` | Includes `devops/ci/gitlab/pipeline.yml` |

## Continuous integration (GitLab)

Pipeline stages: **Lint → Test → Build** (`devops/ci/gitlab/`).

**Triggers:** merge requests; pushes to **`develop`**, **`$CI_DEFAULT_BRANCH`** (e.g. `main`), and **`feature/*`**.

**Lint** jobs use **`allow_failure: false`** — any failure fails the pipeline (Compose config, Hadolint, yamllint, shellcheck, backend syntax/deps check, frontend ESLint).

| Requirement | Implementation |
|-------------|----------------|
| JUnit in GitLab UI | `reports/junit.xml`, `reports/junit-integration.xml`, `reports/junit-e2e.xml` with `reports.junit` in jobs |
| Coverage | `test:unit` — Cobertura / lcov via **c8** |
| Image tags (build job) | **`$CI_COMMIT_SHA`**, **`$CI_COMMIT_SHORT_SHA`**, **`$CI_COMMIT_REF_SLUG`** pushed to the GitLab Container Registry |
| Secrets | Configure under **GitLab → Settings → CI/CD → Variables** (mask when possible). Never commit secrets. |
| Container scan | `test:images` runs **Trivy** on built images (HIGH/CRITICAL reported; job does not fail the pipeline on findings with current flags) |

The **`deploy.yml`** fragment holds notes for future preprod/prod automation; it is **not** included in `pipeline.yml` yet.

## Documentation

- **[`backend/README.md`](backend/README.md)** — environment variables, API contract, local `pnpm` vs Docker.
- **[`frontend/README.md`](frontend/README.md)** — Vite env vars, URLs, scripts.
- **[`devops/README.md`](devops/README.md)** — Compose wiring, CI jobs, Dockerfiles.

## Local development without Docker

Install **Node.js** (LTS) and **pnpm**, run Postgres, then `pnpm install` and run **`pnpm dev`** / **`pnpm start`** in **`frontend/`** and **`backend/`**. See each package README for details.
