# DevOps

This directory holds **Docker** assets and **GitLab CI** templates for the monorepo (`backend/`, `frontend/`). The stack is wired from the repository root via `docker-compose.yml` and `Makefile`.

## Layout

| Path | Purpose |
|------|---------|
| `docker/backend/` | Node (pnpm) images for the Express API |
| `docker/frontend/` | Node (pnpm) images for the Vite dev server |
| `docker/nginx/` | Nginx reverse proxy (dev config and image stubs) |
| `docker/postgres/` | Database bootstrap SQL mounted on first Postgres start |
| `ci/gitlab/` | GitLab CI/CD YAML fragments (stages: build, test, deploy) |

## Local development (Docker Compose)

From the **repo root**:

1. Copy and edit environment variables (see root `.env.example`). Values must match what `docker-compose.yml` interpolates, including:
   - **Postgres (Compose):** `POSTGRES_USER_DEV`, `POSTGRES_PASSWORD_DEV`, `POSTGRES_DB_DEV`
   - **Backend:** `DATABASE_URL` pointing at the `db` service (same user/password/database as above)
   - **Nginx:** `NGINX_CONF` — filename under `devops/docker/nginx/` (e.g. `nginx.dev.conf`)
   - **Vite:** `VITE_APP_ENV`, `VITE_FRONTEND_URL`, `VITE_FRONTEND_API_URL`

2. Start the stack:

   ```bash
   make up
   ```

   Typical URLs (see `make help`):

   - App (via Nginx): `http://localhost:8088`
   - API (direct): `http://localhost:3000`
   - Vite (direct): `http://localhost:5173`

### Services (how `devops` is used)

- **db** — `postgres:16-alpine` with `devops/docker/postgres/init.sql` applied on first init (creates the `users` table; the backend also ensures this schema at runtime).
- **backend** — built with `devops/docker/backend/Dockerfile.backend.dev` (Node 22, pnpm 9, `pnpm start`).
- **frontend** — built with `devops/docker/frontend/Dockerfile.frontend.dev` (Vite dev server on `0.0.0.0:5173`).
- **nginx** — built with `devops/docker/nginx/Dockerfile.nginx.dev`; mounts `devops/docker/nginx/${NGINX_CONF}` as the default site. The sample `nginx.dev.conf` proxies `/` to the frontend and `/api/` to the backend (with a rewrite so `/api/v1/...` maps to backend routes).

## Docker images

| File | Status |
|------|--------|
| `Dockerfile.backend.dev` | Used by Compose for local API |
| `Dockerfile.frontend.dev` | Used by Compose for local UI |
| `Dockerfile.nginx.dev` | Minimal Nginx Alpine base for dev |
| `Dockerfile.*.prod` | Placeholders (empty); extend when defining production builds |

Build contexts are the **repository root** so Dockerfiles can `COPY backend/` and `COPY frontend/` as in the current Compose file.

## GitLab CI

- `ci/gitlab/pipeline.yml` — intended entry for a multi-file pipeline.
- `ci/gitlab/build.yml`, `test.yml`, `deploy.yml` — stage fragments (currently empty stubs).

The root `.gitlab-ci.yml` ships with the `include` for `devops/ci/gitlab/pipeline.yml` **commented out**. Uncomment and fill the YAML files when you are ready to run CI on GitLab.

## Related files at repo root

- `docker-compose.yml` — service definitions referencing this folder.
- `Makefile` — common Compose workflows (`up`, `down`, `logs`, `shell`, etc.).
