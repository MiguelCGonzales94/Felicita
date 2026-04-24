import { useState, useEffect } from 'react'
import { Check, AlertCircle, Loader2, Search, Shield, KeyRound, Info } from 'lucide-react'
import { empresaService } from '../services/empresaService'
import { useDebounce } from '../hooks/useDebounce'
import { COLORES_EMPRESA } from '../types/empresa'
import type { Empresa, ValidacionRUC } from '../types/empresa'

interface EmpresaFormProps {
  empresa?: Empresa | null
  onSubmit: (data: any) => Promise<void>
  onCancel: () => void
  loading?: boolean
}

export default function EmpresaForm({ empresa, onSubmit, onCancel, loading }: EmpresaFormProps) {
  const esEdicion = !!empresa

  const [form, setForm] = useState({
    ruc: empresa?.ruc || '',
    razon_social: empresa?.razon_social || '',
    nombre_comercial: empresa?.nombre_comercial || '',
    direccion_fiscal: empresa?.direccion_fiscal || '',
    distrito: empresa?.distrito || '',
    provincia: empresa?.provincia || '',
    departamento: empresa?.departamento || '',
    regimen_tributario: empresa?.regimen_tributario || 'RG',
    estado_sunat: empresa?.estado_sunat || 'ACTIVO',
    condicion_domicilio: empresa?.condicion_domicilio || 'HABIDO',
    representante_legal: empresa?.representante_legal || '',
    email_empresa: empresa?.email_empresa || '',
    telefono_empresa: empresa?.telefono_empresa || '',

    // Acceso SUNAT (replica el toggle RUC/DNI de SUNAT)
    tipo_acceso_sol: empresa?.tipo_acceso_sol || 'RUC',
    dni_sol: empresa?.dni_sol || '',
    usuario_sol: empresa?.usuario_sol || '',
    clave_sol: '',

    // API SIRE (opcional)
    sunat_client_id: '',
    sunat_client_secret: '',

    color_identificacion: empresa?.color_identificacion || COLORES_EMPRESA[0],
    notas_contador: '',
  })

  const [error, setError] = useState('')
  const [validacionRuc, setValidacionRuc] = useState<ValidacionRUC | null>(null)
  const [validandoRuc, setValidandoRuc] = useState(false)
  const rucDebounced = useDebounce(form.ruc, 500)

  useEffect(() => {
    if (esEdicion) return
    if (rucDebounced.length !== 11 || !/^\d+$/.test(rucDebounced)) {
      setValidacionRuc(null)
      return
    }
    validarRucAuto(rucDebounced)
  }, [rucDebounced, esEdicion])

  async function validarRucAuto(ruc: string) {
    setValidandoRuc(true)
    try {
      const res = await empresaService.validarRuc(ruc)
      setValidacionRuc(res)
      if (res.es_valido && !res.ya_registrada) {
        setForm(f => ({
          ...f,
          razon_social: res.razon_social || f.razon_social,
          direccion_fiscal: res.direccion_fiscal || f.direccion_fiscal,
          distrito: res.distrito || f.distrito,
          provincia: res.provincia || f.provincia,
          departamento: res.departamento || f.departamento,
          estado_sunat: res.estado_sunat || f.estado_sunat,
          condicion_domicilio: res.condicion_domicilio || f.condicion_domicilio,
        }))
      }
    } finally {
      setValidandoRuc(false)
    }
  }

  function updateField(field: string, value: any) {
    setForm(f => ({ ...f, [field]: value }))
    setError('')
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    if (!esEdicion && !form.ruc) return setError('El RUC es obligatorio')
    if (!form.razon_social) return setError('La razon social es obligatoria')
    if (!form.direccion_fiscal) return setError('La direccion fiscal es obligatoria')
    if (!esEdicion && (!validacionRuc || !validacionRuc.es_valido)) {
      return setError('Verifica que el RUC sea valido')
    }
    if (!esEdicion && validacionRuc?.ya_registrada) {
      return setError('Esta empresa ya esta registrada en tu cuenta')
    }

    // Validar DNI si se eligio acceso por DNI
    if (form.tipo_acceso_sol === 'DNI' && form.dni_sol && form.dni_sol.length !== 8) {
      return setError('El DNI debe tener 8 digitos')
    }

    const payload: any = { ...form }
    if (esEdicion) delete payload.ruc
    if (!payload.clave_sol) delete payload.clave_sol
    if (!payload.usuario_sol) delete payload.usuario_sol
    if (!payload.dni_sol) delete payload.dni_sol
    if (!payload.sunat_client_id) delete payload.sunat_client_id
    if (!payload.sunat_client_secret) delete payload.sunat_client_secret
    if (!payload.notas_contador) delete payload.notas_contador

    try {
      await onSubmit(payload)
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al guardar la empresa')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      {/* Identificacion */}
      <Section title="Identificacion">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="md:col-span-1">
            <label className="label">RUC *</label>
            <div className="relative">
              <input
                type="text" value={form.ruc}
                onChange={e => updateField('ruc', e.target.value.replace(/\D/g, '').slice(0, 11))}
                className="input pr-9 font-mono" placeholder="20123456789"
                disabled={esEdicion || loading} maxLength={11}
              />
              {!esEdicion && (
                <div className="absolute right-3 top-1/2 -translate-y-1/2">
                  {validandoRuc ? <Loader2 size={14} className="text-gray-400 animate-spin" />
                    : validacionRuc?.es_valido && !validacionRuc.ya_registrada ? <Check size={14} className="text-success-600" />
                    : validacionRuc && (!validacionRuc.es_valido || validacionRuc.ya_registrada) ? <AlertCircle size={14} className="text-danger-600" />
                    : form.ruc.length === 11 ? <Search size={14} className="text-gray-400" />
                    : null}
                </div>
              )}
            </div>
            {!esEdicion && validacionRuc && (
              <p className={`text-xs mt-1 ${
                validacionRuc.es_valido && !validacionRuc.ya_registrada ? 'text-success-600' : 'text-danger-600'
              }`}>{validacionRuc.mensaje}</p>
            )}
          </div>

          <div className="md:col-span-2">
            <label className="label">Razon social *</label>
            <input type="text" value={form.razon_social}
              onChange={e => updateField('razon_social', e.target.value)}
              className="input" placeholder="EMPRESA EJEMPLO SAC" disabled={loading} />
          </div>

          <div className="md:col-span-2">
            <label className="label">Nombre comercial</label>
            <input type="text" value={form.nombre_comercial || ''}
              onChange={e => updateField('nombre_comercial', e.target.value)}
              className="input" placeholder="Opcional" disabled={loading} />
          </div>

          <div>
            <label className="label">Color</label>
            <div className="flex flex-wrap gap-1.5">
              {COLORES_EMPRESA.map(color => (
                <button key={color} type="button"
                  onClick={() => updateField('color_identificacion', color)}
                  className={`w-7 h-7 rounded-full transition-transform ${
                    form.color_identificacion === color ? 'ring-2 ring-offset-2 ring-brand-800 scale-110' : 'hover:scale-110'
                  }`}
                  style={{ backgroundColor: color }} title={color} />
              ))}
            </div>
          </div>
        </div>
      </Section>

      {/* Ubicacion */}
      <Section title="Ubicacion">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="label">Direccion fiscal *</label>
            <input type="text" value={form.direccion_fiscal}
              onChange={e => updateField('direccion_fiscal', e.target.value)}
              className="input" placeholder="Av. Principal 123, Piso 5" disabled={loading} />
          </div>
          <div>
            <label className="label">Distrito</label>
            <input type="text" value={form.distrito || ''}
              onChange={e => updateField('distrito', e.target.value)}
              className="input" placeholder="San Isidro" disabled={loading} />
          </div>
          <div>
            <label className="label">Provincia</label>
            <input type="text" value={form.provincia || ''}
              onChange={e => updateField('provincia', e.target.value)}
              className="input" placeholder="Lima" disabled={loading} />
          </div>
          <div className="md:col-span-2">
            <label className="label">Departamento</label>
            <input type="text" value={form.departamento || ''}
              onChange={e => updateField('departamento', e.target.value)}
              className="input" placeholder="Lima" disabled={loading} />
          </div>
        </div>
      </Section>

      {/* Configuracion tributaria */}
      <Section title="Configuracion tributaria">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="label">Regimen *</label>
            <select value={form.regimen_tributario}
              onChange={e => updateField('regimen_tributario', e.target.value)}
              className="input" disabled={loading}>
              <option value="RG">Regimen General</option>
              <option value="RMT">Regimen MYPE Tributario</option>
              <option value="RER">Regimen Especial</option>
              <option value="NRUS">Nuevo RUS</option>
            </select>
          </div>
          <div>
            <label className="label">Estado SUNAT</label>
            <select value={form.estado_sunat}
              onChange={e => updateField('estado_sunat', e.target.value)}
              className="input" disabled={loading}>
              <option value="ACTIVO">Activo</option>
              <option value="BAJA">Baja</option>
              <option value="SUSPENDIDO">Suspendido</option>
              <option value="OBSERVADO">Observado</option>
            </select>
          </div>
          <div>
            <label className="label">Condicion domicilio</label>
            <select value={form.condicion_domicilio}
              onChange={e => updateField('condicion_domicilio', e.target.value)}
              className="input" disabled={loading}>
              <option value="HABIDO">Habido</option>
              <option value="NO_HABIDO">No habido</option>
              <option value="NO_HALLADO">No hallado</option>
            </select>
          </div>
        </div>
      </Section>

      {/* Contacto */}
      <Section title="Contacto">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="label">Representante legal</label>
            <input type="text" value={form.representante_legal || ''}
              onChange={e => updateField('representante_legal', e.target.value)}
              className="input" placeholder="Nombres y apellidos" disabled={loading} />
          </div>
          <div>
            <label className="label">Email</label>
            <input type="email" value={form.email_empresa || ''}
              onChange={e => updateField('email_empresa', e.target.value)}
              className="input" placeholder="contacto@empresa.com" disabled={loading} />
          </div>
          <div>
            <label className="label">Telefono</label>
            <input type="tel" value={form.telefono_empresa || ''}
              onChange={e => updateField('telefono_empresa', e.target.value)}
              className="input" placeholder="(01) 234-5678" disabled={loading} />
          </div>
        </div>
      </Section>

      {/* Clave SOL - replica del diseno SUNAT */}
      <Section
        title="Acceso SUNAT Operaciones en Linea"
        description="Credenciales encriptadas para acceder a SUNAT (opcional)"
        icon={<Shield size={14} className="text-brand-800" />}
      >
        {/* Toggle RUC / DNI estilo SUNAT */}
        <div className="bg-sidebar rounded-t-lg p-3">
          <p className="text-[11px] text-slate-300 font-semibold uppercase tracking-wider mb-2">
            SUNAT Operaciones en Linea
          </p>
          <div className="inline-flex bg-white rounded-md overflow-hidden shadow-sm">
            <button type="button"
              onClick={() => updateField('tipo_acceso_sol', 'RUC')}
              className={`px-6 py-1.5 text-sm font-semibold transition-colors ${
                form.tipo_acceso_sol === 'RUC' ? 'bg-brand-700 text-white' : 'text-gray-600 hover:bg-gray-50'
              }`}>
              RUC
            </button>
            <button type="button"
              onClick={() => updateField('tipo_acceso_sol', 'DNI')}
              className={`px-6 py-1.5 text-sm font-semibold transition-colors ${
                form.tipo_acceso_sol === 'DNI' ? 'bg-brand-700 text-white' : 'text-gray-600 hover:bg-gray-50'
              }`}>
              DNI
            </button>
          </div>
        </div>

        {/* Campos segun tipo */}
        <div className="bg-gray-50 border border-gray-200 rounded-b-lg p-4 space-y-3">
          {form.tipo_acceso_sol === 'RUC' ? (
            <>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="label text-xs">RUC</label>
                  <input type="text" value={form.ruc}
                    className="input font-mono bg-gray-100" disabled
                    placeholder="RUC de la empresa" />
                  <p className="text-[11px] text-gray-500 mt-1">Se usa el RUC registrado arriba</p>
                </div>
                <div>
                  <label className="label text-xs">Usuario SOL</label>
                  <input type="text" value={form.usuario_sol}
                    onChange={e => updateField('usuario_sol', e.target.value.toUpperCase())}
                    className="input font-mono" placeholder="Ejemplo: USUARIO1" disabled={loading} />
                </div>
              </div>
            </>
          ) : (
            <div>
              <label className="label text-xs">DNI</label>
              <input type="text" value={form.dni_sol}
                onChange={e => updateField('dni_sol', e.target.value.replace(/\D/g, '').slice(0, 8))}
                className="input font-mono" placeholder="12345678" maxLength={8} disabled={loading} />
              <p className="text-[11px] text-gray-500 mt-1">8 digitos</p>
            </div>
          )}

          <div>
            <label className="label text-xs">Contrasena SOL</label>
            <input type="password" value={form.clave_sol}
              onChange={e => updateField('clave_sol', e.target.value)}
              className="input font-mono"
              placeholder={esEdicion && empresa?.tiene_clave_sol ? '(configurada - dejar vacio para no cambiar)' : 'Contrasena SOL'}
              disabled={loading} />
          </div>
        </div>
      </Section>

      {/* Credenciales API SUNAT (para SIRE) */}
      <Section
        title="Credenciales API SUNAT (para SIRE)"
        description="Necesarias para descargar propuestas RCE/RVIE automaticamente. Se obtienen en SUNAT > Credenciales API."
        icon={<KeyRound size={14} className="text-brand-800" />}
      >
        <div className="bg-brand-50 border border-brand-200 rounded-lg p-3 mb-3 flex gap-2 text-xs">
          <Info size={14} className="text-brand-800 flex-shrink-0 mt-0.5" />
          <div className="text-brand-900">
            Estas credenciales son opcionales. Si las configuras, Felicita podra descargar automaticamente
            las ventas y compras del mes desde SUNAT para prellenar el PDT 621.
            <br />
            <span className="text-[11px] text-brand-700">
              Obtenerlas: SUNAT Operaciones en Linea &gt; Mi RUC y Otros Registros &gt; Credenciales API
            </span>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="label">Client ID</label>
            <input type="text" value={form.sunat_client_id}
              onChange={e => updateField('sunat_client_id', e.target.value)}
              className="input font-mono text-xs"
              placeholder={esEdicion && empresa?.tiene_credenciales_api_sunat ? '(configurado)' : 'aabbccdd-1234-...'}
              disabled={loading} />
          </div>
          <div>
            <label className="label">Client Secret</label>
            <input type="password" value={form.sunat_client_secret}
              onChange={e => updateField('sunat_client_secret', e.target.value)}
              className="input font-mono text-xs"
              placeholder={esEdicion && empresa?.tiene_credenciales_api_sunat ? '(configurado)' : 'CLIENT SECRET'}
              disabled={loading} />
          </div>
        </div>
      </Section>

      {error && (
        <div className="bg-danger-50 border border-danger-600/20 text-danger-900 text-sm rounded-lg px-4 py-3 flex items-start gap-2">
          <AlertCircle size={16} className="flex-shrink-0 mt-0.5" />
          <span>{error}</span>
        </div>
      )}

      <div className="flex items-center justify-end gap-2 pt-4 border-t border-gray-100">
        <button type="button" onClick={onCancel} className="btn-secondary" disabled={loading}>
          Cancelar
        </button>
        <button type="submit" className="btn-primary flex items-center gap-2" disabled={loading || validandoRuc}>
          {loading && <Loader2 size={14} className="animate-spin" />}
          {esEdicion ? 'Guardar cambios' : 'Crear empresa'}
        </button>
      </div>
    </form>
  )
}

function Section({ title, description, icon, children }: {
  title: string
  description?: string
  icon?: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <div>
      <div className="mb-3 flex items-start gap-2">
        {icon && <div className="pt-0.5">{icon}</div>}
        <div>
          <h3 className="font-heading font-bold text-gray-900 text-sm">{title}</h3>
          {description && <p className="text-xs text-gray-500 mt-0.5">{description}</p>}
        </div>
      </div>
      {children}
    </div>
  )
}
