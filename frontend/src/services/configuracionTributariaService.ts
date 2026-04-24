import api from './api'
import type {
  ConfiguracionTributaria, ValoresLegales, CamposSireResponse,
} from '../types/configuracionTributaria'

export const configTributariaService = {
  async obtener(empresaId: number) {
    const { data } = await api.get(`/empresas/${empresaId}/configuracion-tributaria`)
    return data as ConfiguracionTributaria
  },

  async actualizarLegales(empresaId: number, valores: ValoresLegales) {
    const { data } = await api.put(
      `/empresas/${empresaId}/configuracion-tributaria/valores-legales`,
      valores,
    )
    return data as ConfiguracionTributaria
  },

  async obtenerCamposSire(empresaId: number, tipo: 'rvie' | 'rce') {
    const { data } = await api.get(
      `/empresas/${empresaId}/configuracion-tributaria/campos/${tipo}`,
    )
    return data as CamposSireResponse
  },

  async actualizarCamposSire(empresaId: number, tipo: 'rvie' | 'rce', seleccion: Record<string, boolean>) {
    const { data } = await api.put(
      `/empresas/${empresaId}/configuracion-tributaria/campos/${tipo}`,
      { seleccion },
    )
    return data as ConfiguracionTributaria
  },

  async restaurar(empresaId: number, seccion: 'legales' | 'rvie' | 'rce' | 'todo') {
    const { data } = await api.post(
      `/empresas/${empresaId}/configuracion-tributaria/restaurar`,
      { seccion },
    )
    return data as ConfiguracionTributaria
  },
}
