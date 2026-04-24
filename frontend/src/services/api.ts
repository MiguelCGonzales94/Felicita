import axios from 'axios'

const api = axios.create({
  baseURL: '/api/v1',
  headers: { 'Content-Type': 'application/json' },
})

// Inyectar token en cada request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('felicita_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Redirigir a login si el token expira
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('felicita_token')
      localStorage.removeItem('felicita_user')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default api
