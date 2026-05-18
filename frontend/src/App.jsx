import { useCallback, useEffect, useState, startTransition } from 'react'
import './App.css'

const apiBase = (import.meta.env.VITE_FRONTEND_API_URL || '').replace(/\/$/, '')

async function parseJsonResponse(res) {
  const text = await res.text()
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    return { error: 'Réponse invalide' }
  }
}

export default function App() {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [form, setForm] = useState({ email: '', name: '' })
  const [editingId, setEditingId] = useState(null)
  const [saving, setSaving] = useState(false)

  const loadUsers = useCallback(async () => {
    setError(null)
    setLoading(true)
    try {
      const res = await fetch(`${apiBase}/users`)
      const data = await parseJsonResponse(res)
      if (!res.ok) {
        setError(data?.error || `Erreur ${res.status}`)
        setUsers([])
        return
      }
      setUsers(Array.isArray(data) ? data : [])
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Réseau indisponible')
      setUsers([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    startTransition(() => {
      void loadUsers()
    })
  }, [loadUsers])

  function startEdit(user) {
    setEditingId(user.id)
    setForm({ email: user.email, name: user.name })
  }

  function cancelEdit() {
    setEditingId(null)
    setForm({ email: '', name: '' })
  }

  async function handleSubmit(e) {
    e.preventDefault()
    setSaving(true)
    setError(null)
    const body = JSON.stringify({
      email: form.email.trim(),
      name: form.name.trim(),
    })
    const url = editingId ? `${apiBase}/users/${editingId}` : `${apiBase}/users`
    const method = editingId ? 'PUT' : 'POST'
    try {
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body,
      })
      const data = await parseJsonResponse(res)
      if (!res.ok) {
        setError(data?.error || `Erreur ${res.status}`)
        return
      }
      cancelEdit()
      await loadUsers()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Réseau indisponible')
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(id) {
    if (!window.confirm('Supprimer cet utilisateur ?')) return
    setError(null)
    try {
      const res = await fetch(`${apiBase}/users/${id}`, { method: 'DELETE' })
      if (!res.ok && res.status !== 204) {
        const data = await parseJsonResponse(res)
        setError(data?.error || `Erreur ${res.status}`)
        return
      }
      if (editingId === id) cancelEdit()
      await loadUsers()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Réseau indisponible')
    }
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>Utilisateurs</h1>
        <p className="app-lead">
          Mini-app connectée à l’API via{' '}
          <code>{apiBase || '(VITE_FRONTEND_API_URL)'}</code> et nginx.
        </p>
      </header>

      {error ? (
        <div className="banner banner-error" role="alert">
          {error}
        </div>
      ) : null}

      <section className="panel">
        <h2>{editingId ? 'Modifier' : 'Ajouter'} un utilisateur</h2>
        <form className="form" onSubmit={handleSubmit}>
          <label className="field">
            <span>Email</span>
            <input
              type="email"
              name="email"
              autoComplete="email"
              value={form.email}
              onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
              required
            />
          </label>
          <label className="field">
            <span>Nom</span>
            <input
              type="text"
              name="name"
              autoComplete="name"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              required
            />
          </label>
          <div className="form-actions">
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Enregistrement…' : editingId ? 'Mettre à jour' : 'Créer'}
            </button>
            {editingId ? (
              <button type="button" className="btn btn-ghost" onClick={cancelEdit}>
                Annuler
              </button>
            ) : null}
          </div>
        </form>
      </section>

      <section className="panel">
        <div className="panel-head">
          <h2>Liste</h2>
          <button type="button" className="btn btn-ghost" onClick={loadUsers} disabled={loading}>
            Actualiser
          </button>
        </div>
        {loading ? (
          <p className="muted">Chargement…</p>
        ) : users.length === 0 ? (
          <p className="muted">Aucun utilisateur pour le moment.</p>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Nom</th>
                  <th>Email</th>
                  <th>Créé le</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td>{u.id}</td>
                    <td>{u.name}</td>
                    <td>{u.email}</td>
                    <td className="cell-date">
                      {u.createdAt
                        ? new Date(u.createdAt).toLocaleString('fr-FR')
                        : '—'}
                    </td>
                    <td className="cell-actions">
                      <button
                        type="button"
                        className="btn btn-sm btn-ghost"
                        onClick={() => startEdit(u)}
                      >
                        Modifier
                      </button>
                      <button
                        type="button"
                        className="btn btn-sm btn-danger"
                        onClick={() => handleDelete(u.id)}
                      >
                        Supprimer
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  )
}
