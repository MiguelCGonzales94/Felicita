import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../services/api'
import { useAuthStore } from '../store/authStore'

export default function LoginPage() {
  const navigate = useNavigate()
  const { login } = useAuthStore()
  const [form, setForm] = useState({ email: '', password: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError('')
    try {
      const { data } = await api.post('/auth/login', form)
      login(data.access_token, data.usuario)
      navigate('/dashboard')
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al iniciar sesion')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex">
      <div className="flex-1 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-sm">
          <div className="mb-8">
            <div className="w-12 h-12 bg-brand-800 rounded-xl flex items-center justify-center mb-5">
              <span className="text-white text-xl font-bold">F</span>
            </div>
            <h1 className="text-3xl font-heading font-bold text-gray-900">Bienvenido de vuelta</h1>
            <p className="text-gray-500 text-sm mt-2">Inicia sesion para acceder a tu panel contable</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="label">Email</label>
              <input type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} className="input" placeholder="contador@email.com" required />
            </div>
            <div>
              <label className="label">Contrasena</label>
              <input type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} className="input" placeholder="........" required />
            </div>

            {error && (
              <div className="bg-danger-50 border border-danger-600/20 text-danger-900 text-sm rounded-lg px-4 py-2.5">{error}</div>
            )}

            <button type="submit" disabled={loading} className="btn-primary w-full py-2.5 disabled:opacity-50">
              {loading ? 'Ingresando...' : 'Iniciar sesion'}
            </button>
          </form>

          <div className="mt-8 pt-6 border-t border-gray-100">
            <p className="text-xs text-gray-400 text-center">
              Prueba: <span className="font-mono">ana.perez@felicita.pe</span> / <span className="font-mono">contador123</span>
            </p>
          </div>
        </div>
      </div>

      <div className="hidden lg:flex flex-1 bg-sidebar text-white items-center justify-center p-12 relative overflow-hidden">
        <div className="absolute inset-0 opacity-[0.03]" style={{ backgroundImage: 'radial-gradient(circle at 1px 1px, white 1px, transparent 0)', backgroundSize: '32px 32px' }} />
        <div className="relative z-10 max-w-md">
          <div className="inline-block bg-brand-800 text-xs font-semibold uppercase tracking-wider px-3 py-1 rounded-full mb-6">
            Felicita Plataforma contable
          </div>
          <h2 className="text-4xl font-heading font-bold mb-4 leading-tight">
            Gestiona todas tus empresas desde un solo lugar
          </h2>
          <p className="text-slate-300 text-base leading-relaxed">
            Calendario tributario consolidado, alertas automaticas y generacion de declaraciones para toda tu cartera de clientes.
          </p>
          <div className="grid grid-cols-3 gap-4 mt-10">
            <div>
              <div className="text-2xl font-heading font-bold text-white font-mono">30+</div>
              <div className="text-xs text-slate-400 mt-1">Empresas por contador</div>
            </div>
            <div>
              <div className="text-2xl font-heading font-bold text-white font-mono">100%</div>
              <div className="text-xs text-slate-400 mt-1">Compliance SUNAT</div>
            </div>
            <div>
              <div className="text-2xl font-heading font-bold text-white font-mono">24/7</div>
              <div className="text-xs text-slate-400 mt-1">Monitoreo automatico</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
