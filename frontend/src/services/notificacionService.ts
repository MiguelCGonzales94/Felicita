import api from './api'

export interface Notificacion {
  id: number
  empresa_id: number
  titulo: string
  mensaje: string
  tipo: string
  ano: number
  mes: number
  igv_a_pagar: number
  renta_a_pagar: number
  total_a_pagar: number
  fecha_vencimiento: string
  leido: boolean
  enviado_app: boolean
  enviado_email: boolean
  enviado_whatsapp: boolean
  fecha_envio: string
}

export const notificacionService = {
  async listar(leido?: boolean, limit = 20) {
    const params: any = { limit }
    if (leido !== undefined) params.leido = leido
    const { data } = await api.get('/notificaciones', { params })
    return data as { total: number; no_leidas: number; notificaciones: Notificacion[] }
  },

  async generar(ano: number, mes: number) {
    const { data } = await api.post('/notificaciones/generar', null, { params: { ano, mes } })
    return data as { generadas: number; mensaje: string }
  },

  async enviar(notifId: number, email?: string, whatsapp?: string) {
    const params: any = {}
    if (email) params.email = email
    if (whatsapp) params.whatsapp = whatsapp
    const { data } = await api.post(`/notificaciones/${notifId}/enviar`, null, { params })
    return data
  },

  async marcarLeida(notifId: number) {
    const { data } = await api.patch(`/notificaciones/${notifId}/leer`)
    return data
  },

  async marcarTodasLeidas() {
    const { data } = await api.patch('/notificaciones/leer-todas')
    return data
  },
}
