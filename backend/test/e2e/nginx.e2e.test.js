const { describe, test } = require("node:test");
const assert = require("node:assert/strict");

const appBase = (process.env.E2E_BASE_URL || "http://127.0.0.1:8088").replace(
  /\/$/,
  "",
);

describe("Stack — E2E via nginx", () => {
  test("GET / sert le shell Vite (index.html)", async () => {
    const res = await fetch(`${appBase}/`);
    const html = await res.text();
    assert.equal(res.status, 200, html.slice(0, 300));
    assert.match(html, /id="root"/);
  });

  test("GET /api/v1/users proxifie l’API", async () => {
    const res = await fetch(`${appBase}/api/v1/users`);
    const text = await res.text();
    assert.equal(res.status, 200, text.slice(0, 400));
    let users;
    try {
      users = JSON.parse(text);
    } catch {
      assert.fail(`réponse non-JSON: ${text.slice(0, 200)}`);
    }
    assert.ok(Array.isArray(users));
  });
});
