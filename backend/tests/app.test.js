const request = require("supertest");
const app = require("../server");

describe("GET /", () => {
  test("should return api information", async () => {
    const response = await request(app).get("/");

    expect(response.statusCode).toBe(200);

    expect(response.body).toEqual({
      ok: true,
      service: "api",
      users: "/users",
    });
  });
});