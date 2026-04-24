export interface Empresa {
  id: number
  ruc: string
  razon_social: string
  nombre_comercial: string | null
  direccion_fiscal: string
  distrito: string | null
  provincia: string | null
  departamento: string | null
  regimen_tributario: string
  estado_sunat: string
  condicion_domicilio: string
  representante_legal: string | null
  email_empresa: string | null
  telefono_empresa: string | null
  nivel_alerta: 'VERDE' | 'AMARILLO' | 'ROJO'
  motivo_alerta: string | null
  color_identificacion: string
  tipo_acceso_sol: 'RUC' | 'DNI'
  dni_sol: string | null
  usuario_sol: string | null
  tiene_clave_sol: boolean
  tiene_credenciales_api_sunat: boolean
  activa: boolean
  fecha_creacion: string
}

export interface EmpresaDetalle extends Empresa {
  total_pdt621s: number
  pdt621s_pendientes: number
  ultima_declaracion: string | null
  proximo_vencimiento: string | null
}

export interface ValidacionRUC {
  ruc: string
  es_valido: boolean
  mensaje: string
  tipo: string
  razon_social: string | null
  estado_sunat: string | null
  condicion_domicilio: string | null
  direccion_fiscal: string | null
  distrito: string | null
  provincia: string | null
  departamento: string | null
  ya_registrada: boolean
}

export interface EmpresaListFilters {
  buscar?: string
  nivel_alerta?: 'VERDE' | 'AMARILLO' | 'ROJO'
  regimen?: 'RG' | 'RMT' | 'RER' | 'NRUS'
  orden?: 'alerta' | 'nombre' | 'fecha' | 'ruc'
}

export interface EmpresaListResponse {
  total: number
  empresas: Empresa[]
}

export const REGIMENES_LABEL: Record<string, string> = {
  RG:   'Regimen General',
  RMT:  'Regimen MYPE Tributario',
  RER:  'Regimen Especial',
  NRUS: 'Nuevo RUS',
}

export const COLORES_EMPRESA = [
  '#3B82F6', '#10B981', '#F59E0B', '#EF4444',
  '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16',
  '#F97316', '#6366F1',
]
