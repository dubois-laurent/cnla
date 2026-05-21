const express = require("express");
const usersRouter = require("./routes/users");

function createApp() {
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

  return app;
}

module.exports = { createApp };
