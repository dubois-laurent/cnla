const http = require("http");
const { describe, test } = require("node:test");
const assert = require("node:assert/strict");
const { createApp } = require("../../app");

describe("createApp — routes critiques", () => {
  test("GET / retourne le contrat santé API", async () => {
    const app = createApp();
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address();
    try {
      const res = await fetch(`http://127.0.0.1:${port}/`);
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.deepEqual(body, {
        ok: true,
        service: "api",
        users: "/users",
      });
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });
});
