const request = require('supertest');

// Mock du module db : aucune connexion PostgreSQL réelle en test
jest.mock('../db', () => ({
  pool: { query: jest.fn() },
  ensureUsersTable: jest.fn(),
  waitForDb: jest.fn(),
}));

const app = require('../app');
const { pool } = require('../db');

afterEach(() => jest.clearAllMocks());

describe('GET /', () => {
  it('retourne 200 avec la structure attendue', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.type).toMatch(/json/);
    expect(res.body).toEqual({ ok: true, service: 'api', users: '/users' });
  });
});

describe('GET /users', () => {
  it('retourne la liste des utilisateurs', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [
        { id: 1, email: 'alice@test.fr', name: 'Alice', created_at: '2024-01-01T00:00:00Z' },
        { id: 2, email: 'bob@test.fr',   name: 'Bob',   created_at: '2024-01-02T00:00:00Z' },
      ],
    });
    const res = await request(app).get('/users');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
    expect(res.body[0]).toMatchObject({ id: 1, email: 'alice@test.fr', name: 'Alice' });
  });

  it('retourne un tableau vide si aucun utilisateur', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app).get('/users');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});

describe('GET /users/:id', () => {
  it('retourne un utilisateur existant', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ id: 1, email: 'alice@test.fr', name: 'Alice', created_at: '2024-01-01T00:00:00Z' }],
    });
    const res = await request(app).get('/users/1');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ id: 1, email: 'alice@test.fr', name: 'Alice' });
  });

  it('retourne 404 si l utilisateur n existe pas', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app).get('/users/999');
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: 'Utilisateur introuvable' });
  });

  it('retourne 400 pour un id invalide (string)', async () => {
    const res = await request(app).get('/users/abc');
    expect(res.status).toBe(400);
    expect(res.body).toEqual({ error: 'Identifiant invalide' });
  });

  it('retourne 400 pour un id invalide (négatif)', async () => {
    const res = await request(app).get('/users/-5');
    expect(res.status).toBe(400);
    expect(res.body).toEqual({ error: 'Identifiant invalide' });
  });
});
