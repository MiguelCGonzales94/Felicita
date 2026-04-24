import { create } from 'zustand'

interface Usuario {
  id: number
  email: string
  nombre: string
  apellido: string
  rol: string
  plan_actual: string
}

interface AuthState {
  token: string | null
  usuario: Usuario | null
  login: (token: string, usuario: Usuario) => void
  logout: () => void
  isAuthenticated: () => boolean
}

export const useAuthStore = create<AuthState>((set, get) => ({
  token: localStorage.getItem('felicita_token'),
  usuario: JSON.parse(localStorage.getItem('felicita_user') || 'null'),

  login: (token, usuario) => {
    localStorage.setItem('felicita_token', token)
    localStorage.setItem('felicita_user', JSON.stringify(usuario))
    set({ token, usuario })
  },

  logout: () => {
    localStorage.removeItem('felicita_token')
    localStorage.removeItem('felicita_user')
    set({ token: null, usuario: null })
  },

  isAuthenticated: () => !!get().token,
}))
