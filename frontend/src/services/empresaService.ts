import api from './api'
import type {
  Empresa, EmpresaDetalle, ValidacionRUC,
  EmpresaListFilters, EmpresaListResponse
} from '../types/empresa'

export const empresaService = {
  async listar(filters: EmpresaListFilters = {}): Promise<EmpresaListResponse> {
    const params = Object.entries(filters)
      .filter(([_, v]) => v !== undefined && v !== '')
      .reduce((acc, [k, v]) => ({ ...acc, [k]: v }), {})
    const { data } = await api.get('/empresas', { params })
    return data
  },

  async obtener(id: number): Promise<EmpresaDetalle> {
    const { data } = await api.get(`/empresas/${id}`)
    return data
  },

  async validarRuc(ruc: string): Promise<ValidacionRUC> {
    const { data } = await api.get(`/empresas/validar-ruc/${ruc}`)
    return data
  },

  async crear(payload: any): Promise<Empresa> {
    const { data } = await api.post('/empresas', payload)
    return data
  },

  async actualizar(id: number, payload: any): Promise<Empresa> {
    const { data } = await api.put(`/empresas/${id}`, payload)
    return data
  },

  async eliminar(id: number): Promise<void> {
    await api.delete(`/empresas/${id}`)
  },

  async reactivar(id: number): Promise<Empresa> {
    const { data } = await api.post(`/empresas/${id}/reactivar`)
    return data
  },

  async recalcularAlertas(id: number): Promise<Empresa> {
    const { data } = await api.post(`/empresas/${id}/recalcular-alertas`)
    return data
  },
}
