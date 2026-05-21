# DevOps

Docker assets and **GitLab CI** for the monorepo (`backend/`, `frontend/`). The stack is driven from the repository root with **`docker-compose.yml`** and **`Makefile`**.

## Layout

| Path | Purpose |
|------|---------|
| `docker/backend/` | Node (pnpm) image for the Express API (dev Dockerfile used by Compose) |
| `docker/frontend/` | Node (pnpm) image for the Vite **dev** server |
| `docker/nginx/` | Multi-stage **production-style** nginx image: builds the SPA, serves static files, proxies `/api/` to the backend |
| `docker/postgres/` | `init.sql` mounted on first database start |
| `ci/gitlab/` | `pipeline.yml`, `test.yml`, `build.yml`; `deploy.yml` is placeholder notes only |
| `ci/scripts/` | Helper shell scripts used in CI |

## Local development (Docker Compose)

From the **repository root**:

1. Copy **`.env.example`** to **`.env`** and fill in values Compose and the nginx **build args** need:
   - **`POSTGRES_USER`**, **`POSTGRES_PASSWORD`**, **`POSTGRES_DB`** — Postgres service ; must stay consistent with **`DATABASE_URL`** in `.env`.
   - **`VITE_APP_ENV`**, **`VITE_FRONTEND_URL`**, **`VITE_FRONTEND_API_URL`** — passed into the **`nginx`** image build so **`pnpm run build`** bakes the correct public API base (typical value: `http://localhost:8088/api/v1`).
   - Optional application keys in the template (`APP_*`) are placeholders unless your services read them.

2. Start the stack:

   ```bash
   make up
   ```

   Typical URLs (`make help`):

   - **App (nginx):** `http://localhost:8088` — static SPA + `/api/v1/...` → backend  
   - **API (direct):** `http://localhost:3000`  
   - **Vite dev (direct):** `http://localhost:5173`

### Services (current `docker-compose.yml`)

| Service | Role |
|---------|------|
| **db** | `postgres:16-alpine`; healthcheck; `./devops/docker/postgres/init.sql` on first init. The backend also ensures the schema at runtime. |
| **backend** | `Dockerfile.backend.dev` — Node 22, **pnpm**, `pnpm start`. Waits on healthy **db**. |
| **frontend** | `Dockerfile.frontend.dev` — Vite on `0.0.0.0:5173` (dev HMR when you open this port directly). |
| **nginx** | **`Dockerfile.nginx.prod`** — multi-stage build: installs frontend deps, **`pnpm run build`**, copies **`dist/`** into nginx; **`nginx.prod.conf`** serves static files and proxies **`/api/`** to **backend**. Does not proxy to the **frontend** container (the UI is embedded as static files). |

Build contexts are the **repository root** so Dockerfiles can `COPY backend/` and `COPY frontend/`.

## Docker images

| Dockerfile | Role |
|------------|------|
| `Dockerfile.backend.dev` | Used by Compose for the API |
| `Dockerfile.frontend.dev` | Used by Compose for Vite dev |
| `Dockerfile.nginx.prod` | Used by Compose for port **8088** (static UI + API reverse proxy) |
| `Dockerfile.*.prod` (backend/frontend) | Reserved for future production-only images |

## GitLab CI

- **`ci/gitlab/pipeline.yml`** — defines stages **lint**, **test**, **build** and includes `test.yml` and `build.yml`.
- **`ci/gitlab/test.yml`** — lint jobs (Compose, Hadolint, yamllint, shellcheck, backend checks, ESLint), **unit** (Node test runner + c8 + JUnit), **integration** and **e2e** (Compose + JUnit), **test:images** (image build + **Trivy** + registry tags).
- **`ci/gitlab/build.yml`** — **`build`** job: builds images, tags **`$CI_COMMIT_SHA`**, **`$CI_COMMIT_SHORT_SHA`**, **`$CI_COMMIT_REF_SLUG`**, pushes to **`$CI_REGISTRY_IMAGE/{backend,frontend,nginx}`** (requires registry credentials in CI variables).
- **`ci/gitlab/deploy.yml`** — comments only; not included in the active pipeline.

The root **`.gitlab-ci.yml`** contains:

```yaml
include:
  - local: 'devops/ci/gitlab/pipeline.yml'
```

## Related files at the repo root

- **`docker-compose.yml`** — services and nginx build args  
- **`Makefile`** — Compose workflows (`up`, `down`, `logs`, `shell`, …)
