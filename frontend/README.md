# Frontend (React + Vite)

Single-page app: **React 19** and **Vite 8**. Small **users** UI (list, create, update, delete) calling the backend REST API. Styles: `src/App.css`, `src/index.css`.

## Requirements

- **Node.js** (LTS recommended)
- **pnpm** (lockfile provided) or **npm**

## Environment variables

Vite only exposes variables prefixed with **`VITE_`**.

| Variable | Used in app | Description |
|----------|-------------|-------------|
| `VITE_FRONTEND_API_URL` | Yes | Base URL for API calls (trailing slash is trimmed). Requests use paths like `${VITE_FRONTEND_API_URL}/users`. If unset, requests are relative (e.g. `/users`), which only works if the dev server or reverse proxy forwards them to the API. |

The root **`.env.example`** also lists **`VITE_APP_ENV`** and **`VITE_FRONTEND_URL`** for Docker / nginx **build args** when the **production** bundle is built (see **`devops/docker/nginx/Dockerfile.nginx.prod`**).

## Full stack with Make (repo root)

From the **repository root** (not `frontend/`):

1. Configure **`.env`** (see **`.env.example`** and **`devops/README.md`**: Postgres, **`DATABASE_URL`**, **`VITE_*`** for the nginx image build).
2. Start containers:

   ```bash
   make up
   ```

3. Targets: `make help`, `make logs` / `make logs s=frontend`, `make shell s=frontend`, `make down`.

**Typical URLs after `make up`:**

| URL | What |
|-----|------|
| **`http://localhost:8088`** | **Main app** — nginx serves the **built** static SPA and proxies **`/api/v1/...`** to the backend (no Vite HMR on this port). |
| **`http://localhost:5173`** | **Vite dev server** — HMR when you develop against this port directly. |
| **`http://localhost:3000`** | API only |

Set **`VITE_FRONTEND_API_URL`** in **`.env`** so the **production build** (baked into the nginx image) points at the public API base, e.g. **`http://localhost:8088/api/v1`**.

## Install (local Node only)

```bash
cd frontend
pnpm install
```

## Scripts

| Script | Command | Description |
|--------|---------|-------------|
| `dev` | `vite` | Dev server with HMR |
| `build` | `vite build` | Output to **`dist/`** |
| `preview` | `vite preview` | Serve **`dist/`** locally |
| `lint` | `eslint .` | ESLint (flat config, React Hooks + Refresh) |

## Run locally (without Docker)

```bash
pnpm dev
```

Dev server: **`http://0.0.0.0:5173`** (`strictPort: true` in `vite.config.js`).

For **`VITE_FRONTEND_API_URL`** when running **`pnpm dev`** only:

- Point at the backend: **`http://localhost:3000`**, or  
- If you use a reverse proxy that exposes **`/api/v1`**, use that base instead.

Use **`frontend/.env`** or **`frontend/.env.local`** (gitignored by convention).

### Vite HMR and port 8088

`vite.config.js` configures HMR **`clientPort` 8088** so that setups that **terminate TLS or a reverse proxy on 8088** can still attach the websocket. With the **current Compose file**, **`http://localhost:8088`** is served by **nginx with a static build**, not by proxying to Vite — use **`http://localhost:5173`** for HMR during local UI work.

## Features (current UI)

- Load users on mount (`GET .../users`) with loading and error states.
- Create (`POST`) / update (`PUT .../users/:id`) with `email` and `name`.
- Table: `id`, `name`, `email`, `createdAt` (dates formatted with **`toLocaleString`** and the locale constant in **`App.jsx`**).
- Delete with confirm (`DELETE .../users/:id`).
- UI copy and client-side fallback messages are defined inline in **`App.jsx`** (same wording the API returns is shown when present).

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
    ├── main.jsx
    ├── App.jsx
    ├── App.css
    └── index.css
```

## Production build

```bash
pnpm build
pnpm preview   # optional check of dist/
```

**`dist/`** is what the **nginx** production Dockerfile copies into the image (see **`devops/docker/nginx/`**).

## Stack summary

- **React** 19 + **react-dom** 19  
- **Vite** 8 + `@vitejs/plugin-react`  
- **ESLint** 10 (flat config)

No router or global state library: main logic in **`App.jsx`**.
