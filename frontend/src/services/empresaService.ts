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

  async consultarRucSunat(ruc: string) {
    const { data } = await api.get(`/empresas/validar-ruc//${ruc}`)
    return data as {
      ruc: string
      es_valido: boolean
      tipo: string
      razon_social: string | null
      estado_sunat: string | null
      condicion_domicilio: string | null
      direccion_fiscal: string | null
      distrito: string | null
      provincia: string | null
      departamento: string | null
      fuente: string
      mensaje: string
      ya_registrada?: boolean
    }
  },
}
