const { createApp } = require("./app");
const { ensureUsersTable, waitForDb } = require("./db");

const port = Number(process.env.PORT) || 3000;

async function main() {
  await waitForDb();
  await ensureUsersTable();
  const app = createApp();
  app.listen(port, "0.0.0.0", () => {
    console.log(`API sur http://0.0.0.0:${port}`);
  });
}

if (process.env.NODE_ENV !== "test") {
  main().catch((err) => {
    console.error("Impossible de démarrer le serveur:", err);
    process.exit(1);
  });
}

module.exports = app;