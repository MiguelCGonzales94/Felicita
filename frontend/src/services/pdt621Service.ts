import api from './api'
import type {
  PDT621, PDT621ListItem, ImportacionSunat, Ajustes, ResultadoCalculo, EstadoPDT
} from '../types/pdt621'

export const pdt621Service = {
  // Listar todos los PDTs del contador
  async listar(filtros: { ano?: number; mes?: number; estado?: string; empresa_id?: number } = {}) {
    const { data } = await api.get('/pdt621', { params: filtros })
    return data as { total: number; pdts: PDT621ListItem[] }
  },

  // Listar PDTs de una empresa
  async listarPorEmpresa(empresaId: number) {
    const { data } = await api.get(`/empresas/${empresaId}/pdt621`)
    return data as {
      empresa: { id: number; ruc: string; razon_social: string }
      total: number
      pdts: PDT621ListItem[]
    }
  },

  // Obtener o crear PDT de un periodo
  async obtenerPorPeriodo(empresaId: number, ano: number, mes: number) {
    const { data } = await api.get(`/empresas/${empresaId}/pdt621/periodo/${ano}/${mes}`)
    return data as PDT621
  },

  // Obtener PDT por ID
  async obtener(pdtId: number) {
    const { data } = await api.get(`/pdt621/${pdtId}`)
    return data as PDT621
  },

  // Generar PDT
  async generar(empresaId: number, ano: number, mes: number) {
    const { data } = await api.post(`/empresas/${empresaId}/pdt621/generar`, { ano, mes })
    return data as PDT621
  },

  // Importar desde SUNAT (SIRE real o mock)
  async importarSunat(pdtId: number) {
    const { data } = await api.post(`/pdt621/${pdtId}/importar-sunat`)
    return data as ImportacionSunat
  },

  // Probar conexion con SUNAT
  async probarConexionSire(empresaId: number) {
    const { data } = await api.post(`/empresas/${empresaId}/sire/probar-conexion`)
    return data as {
      conectado: boolean
      usando_mock: boolean
      mensaje: string
      codigo?: string
    }
  },

  // Sugerir saldo a favor del mes anterior
  async sugerirSaldoFavor(empresaId: number, ano: number, mes: number) {
    const { data } = await api.get(`/empresas/${empresaId}/pdt621/saldo-favor/${ano}/${mes}`)
    return data as { saldo_sugerido: number; editable: boolean; fuente: string }
  },

  // Aplicar ajustes
  async aplicarAjustes(pdtId: number, ajustes: Ajustes) {
    const { data } = await api.put(`/pdt621/${pdtId}/ajustes`, ajustes)
    return data as ResultadoCalculo
  },

  // Recalcular
  async recalcular(pdtId: number) {
    const { data } = await api.post(`/pdt621/${pdtId}/recalcular`)
    return data as PDT621
  },

  // Cambiar estado
  async cambiarEstado(pdtId: number, nuevoEstado: EstadoPDT, numero_operacion?: string, mensaje?: string) {
    const { data } = await api.post(`/pdt621/${pdtId}/cambiar-estado`, {
      nuevo_estado: nuevoEstado,
      numero_operacion,
      mensaje,
    })
    return data as PDT621
  },

  // Eliminar borrador
  async eliminar(pdtId: number) {
    await api.delete(`/pdt621/${pdtId}`)
  },
}

// Helper para formatear numeros como moneda peruana
export function formatoSoles(n: number): string {
  return `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}
