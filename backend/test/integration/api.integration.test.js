const { describe, test, before } = require("node:test");
const assert = require("node:assert/strict");

const apiBase = (process.env.API_URL || "http://127.0.0.1:3000").replace(/\/$/, "");

describe("API — intégration", () => {
  before(async () => {
    const res = await fetch(`${apiBase}/`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.ok, true);
  });

  test("GET /users renvoie un tableau", async () => {
    const res = await fetch(`${apiBase}/users`);
    assert.equal(res.status, 200);
    const users = await res.json();
    assert.ok(Array.isArray(users));
  });

  test("cycle CRUD sur /users", async () => {
    const email = `ci-${Date.now()}@example.com`;
    const createRes = await fetch(`${apiBase}/users`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, name: "CI User" }),
    });
    assert.equal(createRes.status, 201);
    const created = await createRes.json();
    assert.equal(created.email, email);

    const getRes = await fetch(`${apiBase}/users/${created.id}`);
    assert.equal(getRes.status, 200);

    const deleteRes = await fetch(`${apiBase}/users/${created.id}`, {
      method: "DELETE",
    });
    assert.equal(deleteRes.status, 204);
  });
});
