const express = require("express");
const usersRouter = require("./routes/users");
const { ensureUsersTable, waitForDb } = require("./db");

const app = express();

app.use(express.json());

app.get("/", (_req, res) => {
  res.json({ ok: true, service: "api", users: "/users" });
});

app.use("/users", usersRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "Erreur serveur" });
});

const port = Number(process.env.PORT) || 3000;

async function main() {
  await waitForDb();
  await ensureUsersTable();

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