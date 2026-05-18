# Frontend (React + Vite)

Single-page app built with **React 19** and **Vite 8**. It provides a small **users** UI: list, create, update, and delete records by calling the backend REST API. Styling lives in `src/App.css` and `src/index.css`.

## Requirements

- **Node.js** (LTS recommended)
- **pnpm** (lockfile provided) or **npm**

## Environment variables

Vite exposes only variables prefixed with `VITE_`.

| Variable                  | Used in app | Description |
|---------------------------|-------------|---------------|
| `VITE_FRONTEND_API_URL`   | Yes         | Base URL for API requests (no trailing slash required; it is stripped). All calls use paths such as `${VITE_FRONTEND_API_URL}/users`. If unset, requests use relative URLs (e.g. `/users`), which only work if the dev server or reverse proxy forwards `/users` to the API. |

Other `VITE_*` variables may exist in the repo root `.env` for Docker or tooling; only `VITE_FRONTEND_API_URL` is read in `src/App.jsx`.

## Full stack with Make (repo root)

The root **`Makefile`** drives **Docker Compose** for Postgres, backend, frontend, and nginx. Run everything from the **repository root** (not from `frontend/`):

1. Configure the root **`.env`** (see root `.env.example` and `devops/README.md` for Compose-specific variables such as `POSTGRES_*_DEV`, `NGINX_CONF`, and `VITE_*`).
2. Start containers:

   ```bash
   make up
   ```

3. Useful targets: `make help` (lists targets and URLs), `make logs` or `make logs s=frontend`, `make shell s=frontend`, `make down`.

Typical URLs after `make up`:

- App through nginx: **`http://localhost:8088`**
- Vite directly: **`http://localhost:5173`**
- API directly: **`http://localhost:3000`**

Inside Compose, env vars come from the root `.env`; align `VITE_FRONTEND_API_URL` with how you reach the API (often via nginx, e.g. `http://localhost:8088/api/v1`).

## Install (local Node only)

```bash
cd frontend
pnpm install
```

## Scripts

| Script    | Command        | Description |
|-----------|----------------|-------------|
| `dev`     | `vite`         | Dev server with HMR |
| `build`   | `vite build`   | Production bundle to `dist/` |
| `preview` | `vite preview` | Serve the production build locally |
| `lint`    | `eslint .`     | ESLint (flat config, React Hooks + Refresh) |

## Run locally (without Docker)

```bash
pnpm dev
```

Default dev server: **`http://0.0.0.0:5173`** (`strictPort: true` in `vite.config.js`). For the containerized stack, use **`make up`** at the repository root instead of this command.

### API base URL

Point `VITE_FRONTEND_API_URL` at wherever your Express app serves `/users` (with or without a path prefix), for example:

- Direct backend: `http://localhost:3000`
- Through nginx (see repo `devops/docker/nginx/nginx.dev.conf`): often something like `http://localhost:8088/api/v1` so that `${base}/users` matches the `/api/v1/...` → backend rewrite.

Create a `frontend/.env` or `frontend/.env.local` (gitignored by convention) for local `pnpm dev`, or rely on the root `.env` when using **`make up`** at the repo root.

### HMR behind nginx

`vite.config.js` sets HMR to **`localhost:8088`** (WebSocket). That matches a typical setup where the browser loads the app through nginx on port **8088** while the Vite process listens on **5173** inside Docker.

## Features (current UI)

- Load users on mount (`GET .../users`) with loading and error states.
- Form to **create** (`POST .../users`) or **update** (`PUT .../users/:id`) with `email` and `name` (JSON).
- Table listing `id`, `name`, `email`, `createdAt` (dates formatted with `fr-FR` locale).
- **Delete** with browser confirm (`DELETE .../users/:id`).
- Error messages combine API `error` fields and local French fallbacks (`App.jsx`).

The page title and copy are **French**; API error strings may be French if the backend returns them that way.

## Project layout

```
frontend/
├── index.html
├── vite.config.js
├── eslint.config.js
├── package.json
├── pnpm-lock.yaml
├── public/
└── src/
    ├── main.jsx       # React root + StrictMode
    ├── App.jsx        # Users CRUD UI + fetch logic
    ├── App.css
    └── index.css
```

## Production build

```bash
pnpm build
pnpm preview   # optional local check of dist/
```

Output is static files under **`dist/`**, suitable for any static host or the production Docker image defined under `devops/docker/frontend/`.

## Stack summary

- **React** 19 + **react-dom** 19  
- **Vite** 8 with `@vitejs/plugin-react`  
- **ESLint** 10 flat config: `@eslint/js`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`

No router, no global state library: one main component in `App.jsx`.
