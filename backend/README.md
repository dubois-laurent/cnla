# Backend API

Small **Express 5** REST API backed by **PostgreSQL** (`pg`). It exposes CRUD operations for a `users` table, waits for the database on startup, and creates the table if it does not exist.

## Requirements

- **Node.js** (LTS recommended)
- **PostgreSQL** 16+ (or compatible)
- **pnpm** (lockfile provided) or **npm**

## Environment variables

| Variable        | Description                                                                 |
|----------------|------------------------------------------------------------------------------|
| `DATABASE_URL` | PostgreSQL connection string (e.g. `postgresql://user:pass@host:5432/dbname`). Optional query params `serverVersion` and `charset` are stripped before connecting. |
| `PORT`         | HTTP listen port. Default: `3000`.                                          |

If `DATABASE_URL` is missing, `pg` falls back to its default behaviour (typically local socket / env-based config).

## Full stack with Make (repo root)

The root **`Makefile`** wraps **Docker Compose** (Postgres, backend, frontend, nginx). From the **repository root**:

1. Set **`DATABASE_URL`** and related Postgres variables in the root **`.env`** (see root `.env.example` and `devops/README.md`; Compose expects `POSTGRES_*_DEV` for the database service).
2. Start everything:

   ```bash
   make up
   ```

3. See **`make help`** for URLs and targets (`make logs`, `make logs s=backend`, `make shell s=backend`, `make down`, etc.).

The API is exposed on **`http://localhost:3000`** when mapped by Compose; nginx on **`http://localhost:8088`** proxies `/api/` to the backend.

## Install (local Node only)

```bash
cd backend
pnpm install
```

## Run (local Node + Postgres)

Ensure PostgreSQL is running and `DATABASE_URL` points to your database, then:

```bash
pnpm start
```

The server binds to `0.0.0.0` and logs `API sur http://0.0.0.0:<PORT>`.

On startup it:

1. Retries connecting to the database (default: 30 attempts, 1s apart).
2. Ensures the `users` table exists (`CREATE TABLE IF NOT EXISTS`).

For Docker-based development, prefer **`make up`** at the repo root instead of running `pnpm start` on the host.

## API

Base path for user resources: **`/users`**.

JSON bodies use **`Content-Type: application/json`**.

### Health / discovery

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/`  | `{ "ok": true, "service": "api", "users": "/users" }` |

### Users

| Method | Path        | Description |
|--------|-------------|-------------|
| `GET`  | `/users`    | List all users, ordered by `id` ascending. |
| `GET`  | `/users/:id`| Get one user by numeric `id`. |
| `POST` | `/users`    | Create a user. Body: `{ "email", "name" }` (both required, trimmed). |
| `PUT`  | `/users/:id`| Replace `email` and `name` for the given `id`. Body: `{ "email", "name" }`. |
| `DELETE` | `/users/:id` | Delete the user. Response: `204 No Content` on success. |

**User JSON shape** (camelCase in responses):

```json
{
  "id": 1,
  "email": "user@example.com",
  "name": "Jane Doe",
  "createdAt": "2026-01-01T12:00:00.000Z"
}
```

### HTTP status codes (users)

- `200` — OK (`GET` list / single, `PUT` success)
- `201` — Created (`POST`)
- `204` — No content (`DELETE` success)
- `400` — Invalid `id` or missing `email` / `name`
- `404` — User not found
- `409` — Duplicate email (unique constraint)
- `500` — Unhandled server error (`{ "error": "Erreur serveur" }`)

Validation and conflict messages in responses are in **French**, matching the current implementation.

## Database schema

Table `users` (created automatically if missing):

| Column       | Type        | Notes                          |
|-------------|-------------|--------------------------------|
| `id`        | `SERIAL`    | Primary key                    |
| `email`     | `VARCHAR(255)` | `NOT NULL`, `UNIQUE`       |
| `name`      | `VARCHAR(255)` | `NOT NULL`                 |
| `created_at`| `TIMESTAMPTZ`  | Default `NOW()`            |

## Project layout

```
backend/
├── server.js          # App entry: middleware, routes, DB bootstrap, listen
├── db.js              # Pool, waitForDb, ensureUsersTable, DATABASE_URL cleanup
├── routes/
│   └── users.js       # /users CRUD handlers
├── package.json
└── pnpm-lock.yaml
```

## Scripts

| Script    | Command        |
|-----------|----------------|
| `start`   | `node server.js` |

There is no bundled test or lint script in `package.json`; add them if you extend the project.
