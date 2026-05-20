const { Pool } = require("pg");

function connectionString() {
  const raw = process.env.DATABASE_URL;
  if (!raw) return raw;
  try {
    const u = new URL(raw);
    u.searchParams.delete("serverVersion");
    u.searchParams.delete("charset");
    return u.toString();
  } catch {
    return raw;
  }
}

const pool = new Pool({
  connectionString: connectionString(),
});

async function ensureUsersTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL UNIQUE,
      name VARCHAR(255) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}

async function waitForDb({ retries = 30, delayMs = 1000 } = {}) {
  for (let i = 0; i < retries; i += 1) {
    try {
      await pool.query("SELECT 1");
      return;
    } catch (err) {
      if (i === retries - 1) throw err;
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
}

module.exports = { pool, ensureUsersTable, waitForDb, connectionString };
