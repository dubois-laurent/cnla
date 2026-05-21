# Backend API

Small **Express 5** REST API backed by **PostgreSQL** (`pg`). CRUD for a `users` table, DB wait/retry on startup, and **CREATE TABLE IF NOT EXISTS** when the table is missing.

## Requirements

- **Node.js** (LTS recommended)
- **PostgreSQL** 16+ (or compatible)
- **pnpm** (lockfile provided) or **npm**

## Environment variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL URL (e.g. `postgresql://user:pass@host:5432/dbname`). Optional query params `serverVersion` and `charset` are stripped before connecting. |
| `PORT` | HTTP port. Default: **3000**. |

If `DATABASE_URL` is unset, `pg` falls back to its default behaviour.

## Full stack with Make (repo root)

The root **`Makefile`** wraps **Docker Compose** (Postgres, backend, frontend, nginx). From the **repository root**:

1. Set **`POSTGRES_USER`**, **`POSTGRES_PASSWORD`**, **`POSTGRES_DB`**, and **`DATABASE_URL`** in **`.env`** (see root **`.env.example`** and **`devops/README.md`**). Compose expects the `db` hostname for the database service.
2. Start everything:

   ```bash
   make up
   ```

3. Use **`make help`** for URLs and targets (`make logs`, `make logs s=backend`, `make shell s=backend`, `make down`, …).

The API is on **`http://localhost:3000`** when published by Compose. The main browser entry is **`http://localhost:8088`** (nginx static app + `/api/` proxy).

## Install (local Node only)

```bash
cd backend
pnpm install
```

## Run (local Node + Postgres)

With PostgreSQL running and **`DATABASE_URL`** set:

```bash
pnpm start
```

The server listens on **`0.0.0.0`** and logs a startup line to the console.

On startup it:

1. Retries the database connection (default: 30 attempts, 1s apart).
2. Ensures the **`users`** table exists.

For the containerized stack, prefer **`make up`** at the repo root instead of **`pnpm start`** on the host.

## API

Base path for users: **`/users`**.  
JSON bodies: **`Content-Type: application/json`**.

### Health / discovery

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | `{ "ok": true, "service": "api", "users": "/users" }` |

### Users

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/users` | List users, ordered by `id` ascending |
| `GET` | `/users/:id` | Get one user by numeric `id` |
| `POST` | `/users` | Create. Body: `{ "email", "name" }` (required, trimmed) |
| `PUT` | `/users/:id` | Replace `email` and `name`. Body: `{ "email", "name" }` |
| `DELETE` | `/users/:id` | Delete. **204** on success |

**Response shape** (camelCase):

```json
{
  "id": 1,
  "email": "user@example.com",
  "name": "Jane Doe",
  "createdAt": "2026-01-01T12:00:00.000Z"
}
```

### HTTP status codes (users)

- **200** — OK (list / get / PUT)
- **201** — Created (POST)
- **204** — No content (DELETE)
- **400** — Invalid `id` or missing `email` / `name`
- **404** — Not found
- **409** — Duplicate email
- **500** — Server error (JSON body may include `{ "error": "..." }`)

Validation and human-readable errors are whatever the handlers return in **`routes/users.js`** and **`app.js`**.

## Database schema

Table **`users`** (created automatically if missing):

| Column | Type | Notes |
|--------|------|-------|
| `id` | `SERIAL` | Primary key |
| `email` | `VARCHAR(255)` | `NOT NULL`, `UNIQUE` |
| `name` | `VARCHAR(255)` | `NOT NULL` |
| `created_at` | `TIMESTAMPTZ` | Default `NOW()` |

## Project layout

```
backend/
├── server.js          # HTTP server entry
├── app.js             # Express app factory
├── db.js              # Pool, waitForDb, ensureUsersTable
├── routes/
│   └── users.js       # /users handlers
├── test/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── package.json
└── pnpm-lock.yaml
```

## Scripts

| Script | Command |
|--------|---------|
| `start` | `node server.js` |
| `test:unit` | Node built-in test runner, `test/unit/*.test.js` |
| `test:unit:coverage` | Same with **c8** reporters |
| `test:integration` | `test/integration/*.test.js` |
| `test:e2e` | `test/e2e/*.test.js` |

CI runs unit tests with **c8** and JUnit output; see **`devops/ci/gitlab/test.yml`**.
