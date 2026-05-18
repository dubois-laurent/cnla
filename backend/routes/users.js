const express = require("express");
const { pool } = require("../db");

const router = express.Router();

function asyncHandler(fn) {
  return function route(req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

function normalizeUser(row) {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    createdAt: row.created_at,
  };
}

router.get(
  "/",
  asyncHandler(async (_req, res) => {
    const { rows } = await pool.query(
      "SELECT id, email, name, created_at FROM users ORDER BY id ASC",
    );
    res.json(rows.map(normalizeUser));
  }),
);

router.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (!Number.isInteger(id) || id < 1) {
      res.status(400).json({ error: "Identifiant invalide" });
      return;
    }
    const { rows } = await pool.query(
      "SELECT id, email, name, created_at FROM users WHERE id = $1",
      [id],
    );
    if (rows.length === 0) {
      res.status(404).json({ error: "Utilisateur introuvable" });
      return;
    }
    res.json(normalizeUser(rows[0]));
  }),
);

router.post(
  "/",
  asyncHandler(async (req, res) => {
    const email = String(req.body?.email ?? "").trim();
    const name = String(req.body?.name ?? "").trim();
    if (!email || !name) {
      res.status(400).json({ error: "Email et nom sont obligatoires" });
      return;
    }
    try {
      const { rows } = await pool.query(
        `INSERT INTO users (email, name)
         VALUES ($1, $2)
         RETURNING id, email, name, created_at`,
        [email, name],
      );
      res.status(201).json(normalizeUser(rows[0]));
    } catch (err) {
      if (err.code === "23505") {
        res.status(409).json({ error: "Cet email est déjà utilisé" });
        return;
      }
      throw err;
    }
  }),
);

router.put(
  "/:id",
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (!Number.isInteger(id) || id < 1) {
      res.status(400).json({ error: "Identifiant invalide" });
      return;
    }
    const email = String(req.body?.email ?? "").trim();
    const name = String(req.body?.name ?? "").trim();
    if (!email || !name) {
      res.status(400).json({ error: "Email et nom sont obligatoires" });
      return;
    }
    try {
      const { rows } = await pool.query(
        `UPDATE users SET email = $1, name = $2 WHERE id = $3
         RETURNING id, email, name, created_at`,
        [email, name, id],
      );
      if (rows.length === 0) {
        res.status(404).json({ error: "Utilisateur introuvable" });
        return;
      }
      res.json(normalizeUser(rows[0]));
    } catch (err) {
      if (err.code === "23505") {
        res.status(409).json({ error: "Cet email est déjà utilisé" });
        return;
      }
      throw err;
    }
  }),
);

router.delete(
  "/:id",
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (!Number.isInteger(id) || id < 1) {
      res.status(400).json({ error: "Identifiant invalide" });
      return;
    }
    const { rowCount } = await pool.query("DELETE FROM users WHERE id = $1", [
      id,
    ]);
    if (rowCount === 0) {
      res.status(404).json({ error: "Utilisateur introuvable" });
      return;
    }
    res.status(204).send();
  }),
);

module.exports = router;
