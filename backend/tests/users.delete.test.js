const request = require('supertest');
const express = require('express');
const usersRouter = require('../routes/users');
const { pool } = require('../db');


jest.mock('../db', () => ({
  pool: {
    query: jest.fn(),
  },
}));

const app = express();
app.use(express.json());
app.use('/users', usersRouter);

describe('DELETE /users/:id', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  test('should delete a user and return 204 No Content', async () => {
    pool.query.mockResolvedValueOnce({ rowCount: 1 });

    const response = await request(app)
      .delete('/users/1');

    expect(response.status).toBe(204);
    expect(pool.query).toHaveBeenCalledWith(
      'DELETE FROM users WHERE id = $1',
      [1]
    );
  });

  test('should return 404 when user does not exist', async () => {
    pool.query.mockResolvedValueOnce({ rowCount: 0 });

    const response = await request(app)
      .delete('/users/999');

    expect(response.status).toBe(404);
    expect(response.body).toEqual({ error: 'Utilisateur introuvable' });
  });

  test('should return 400 for invalid ID format (not a number)', async () => {
    const response = await request(app)
      .delete('/users/invalid');

    expect(response.status).toBe(400);
    expect(response.body).toEqual({ error: 'Identifiant invalide' });
    expect(pool.query).not.toHaveBeenCalled();
  });

  test('should return 400 for ID less than 1', async () => {
    const response = await request(app)
      .delete('/users/0');

    expect(response.status).toBe(400);
    expect(response.body).toEqual({ error: 'Identifiant invalide' });
    expect(pool.query).not.toHaveBeenCalled();
  });

  test('should return 400 for negative ID', async () => {
    const response = await request(app)
      .delete('/users/-1');

    expect(response.status).toBe(400);
    expect(response.body).toEqual({ error: 'Identifiant invalide' });
    expect(pool.query).not.toHaveBeenCalled();
  });

  test('should handle database errors gracefully', async () => {
    const dbError = new Error('Database connection failed');
    pool.query.mockRejectedValueOnce(dbError);

    const response = await request(app)
      .delete('/users/1');

    expect(response.status).toBe(500);
  });
});
