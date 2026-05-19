const { describe, test } = require("node:test");
const assert = require("node:assert/strict");
const { connectionString } = require("../../db");

describe("connectionString", () => {
  test("retourne undefined sans DATABASE_URL", () => {
    const previous = process.env.DATABASE_URL;
    delete process.env.DATABASE_URL;
    try {
      assert.equal(connectionString(), undefined);
    } finally {
      if (previous === undefined) delete process.env.DATABASE_URL;
      else process.env.DATABASE_URL = previous;
    }
  });

  test("retire serverVersion et charset de l’URL", () => {
    const previous = process.env.DATABASE_URL;
    process.env.DATABASE_URL =
      "postgresql://user:pass@db:5432/app?serverVersion=16&charset=utf8";
    try {
      const url = connectionString();
      assert.ok(url.includes("postgresql://user:pass@db:5432/app"));
      assert.ok(!url.includes("serverVersion"));
      assert.ok(!url.includes("charset"));
    } finally {
      if (previous === undefined) delete process.env.DATABASE_URL;
      else process.env.DATABASE_URL = previous;
    }
  });

  test("retourne la chaîne brute si DATABASE_URL ne peut pas être parsée comme URL", () => {
    const previous = process.env.DATABASE_URL;
    process.env.DATABASE_URL = "ceci-n-est-pas-une-url";
    try {
      assert.equal(connectionString(), "ceci-n-est-pas-une-url");
    } finally {
      if (previous === undefined) delete process.env.DATABASE_URL;
      else process.env.DATABASE_URL = previous;
    }
  });
});
