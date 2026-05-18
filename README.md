# CI / AWS — sample full-stack app

Monorepo used for **continuous integration** and **containerized** local development: a **React + Vite** frontend, an **Express** API, **PostgreSQL**, and **nginx** as a reverse proxy. Docker assets and GitLab CI stubs live under `devops/`.

## Quick start (Docker)

1. **Prerequisites:** [Docker](https://docs.docker.com/get-docker/) with Compose, [GNU Make](https://www.gnu.org/software/make/) (optional but recommended).

2. From the **repository root**, create a `.env` file. Copy `.env.example` and adjust values so they match `docker-compose.yml` (see [`devops/README.md`](devops/README.md) for the exact variable names, including `POSTGRES_*_DEV`, `NGINX_CONF`, `DATABASE_URL`, and `VITE_*`).

3. Start the stack:

   ```bash
   make up
   ```

4. Open the app and APIs (also shown by `make help`):

   | What        | URL                   |
   | ----------- | --------------------- |
   | App (nginx) | http://localhost:8088 |
   | API         | http://localhost:3000 |
   | Vite dev    | http://localhost:5173 |

Common Make targets: `make help`, `make down`, `make logs`, `make logs s=backend`, `make shell s=frontend`. See the [`Makefile`](Makefile) for the full list.

## Repository layout

| Path                     | Description                                                                 |
| ------------------------ | --------------------------------------------------------------------------- |
| [`backend/`](backend/)   | Express REST API (`/users` CRUD), `pg`, Node **pnpm**                       |
| [`frontend/`](frontend/) | React 19 + Vite SPA, users UI, **pnpm**                                     |
| [`devops/`](devops/)     | Dockerfiles, nginx config, Postgres init SQL, GitLab CI YAML fragments      |
| `docker-compose.yml`     | Local multi-service stack                                                   |
| `.gitlab-ci.yml`         | GitLab entrypoint (pipeline include may be commented until CI is filled in) |

## Documentation

- **[`backend/README.md`](backend/README.md)** — environment variables, API contract, local `pnpm start` vs `make up`.
- **[`frontend/README.md`](frontend/README.md)** — Vite env vars, HMR behind nginx, scripts.
- **[`devops/README.md`](devops/README.md)** — Docker/Compose wiring, CI placeholders, production image stubs.

## Local development without Docker

Install **Node.js** (LTS) and **pnpm**, run Postgres yourself, then use `pnpm install` and `pnpm dev` / `pnpm start` inside `frontend/` and `backend/` respectively. Details are in each package README.
