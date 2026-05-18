const request = require("supertest");
const express = require("express");

jest.mock("../db", () => ({
  pool: { query: jest.fn() },
}));

const { pool } = require("../db");
const usersRouter = require("../routes/users");

const app = express();
app.use(express.json());
app.use("/users", usersRouter);

afterEach(() => jest.clearAllMocks());


// ─── PUT /users/:id ───────────────────────────────────────────────────────────

describe("PUT /users/:id", () => {
  const updatedUser = { id: 1, email: "alice@new.com", name: "Alice B", created_at: "2024-01-01T00:00:00.000Z" };

  test("200 — met à jour un utilisateur existant", async () => {
    pool.query.mockResolvedValueOnce({ rows: [updatedUser] });

    const res = await request(app)
      .put("/users/1")
      .send({ email: "alice@new.com", name: "Alice B" });

    expect(res.status).toBe(200);
    expect(res.body.email).toBe("alice@new.com");
    expect(res.body.name).toBe("Alice B");
  });

  test("400 — id invalide (texte)", async () => {
    const res = await request(app)
      .put("/users/abc")
      .send({ email: "alice@test.com", name: "Alice" });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe("Identifiant invalide");
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("400 — champs manquants", async () => {
    const res = await request(app).put("/users/1").send({ email: "alice@test.com" });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe("Email et nom sont obligatoires");
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("404 — utilisateur introuvable", async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .put("/users/999")
      .send({ email: "alice@test.com", name: "Alice" });

    expect(res.status).toBe(404);
    expect(res.body.error).toBe("Utilisateur introuvable");
  });

  test("409 — email déjà utilisé par un autre utilisateur", async () => {
    const duplicateError = Object.assign(new Error("duplicate"), { code: "23505" });
    pool.query.mockRejectedValueOnce(duplicateError);

    const res = await request(app)
      .put("/users/1")
      .send({ email: "already@taken.com", name: "Alice" });

    expect(res.status).toBe(409);
    expect(res.body.error).toBe("Cet email est déjà utilisé");
  });
});
