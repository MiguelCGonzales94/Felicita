import { useEffect, useState, useMemo } from 'react'
import { useParams, useOutletContext, useNavigate } from 'react-router-dom'
import {
  ArrowLeft, Download, Loader2, CheckCircle2, AlertCircle,
  Save, Send, XCircle, RefreshCw, Info, Database, Cloud,
  TrendingUp, TrendingDown, FileText, Settings, Eye,
  Upload, Plus,
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import Modal from '../../components/Modal'
import DetalleComprobantesModal from '../../components/DetalleComprobantesModal'
import { pdt621Service, formatoSoles } from '../../services/pdt621Service'
import { useDebounce } from '../../hooks/useDebounce'
import {
  MESES_LABEL, ESTADO_CONFIG
} from '../../types/pdt621'
import type {
  PDT621, ImportacionSunat, Ajustes, ResultadoCalculo
} from '../../types/pdt621'
import type { EmpresaDetalle } from '../../types/empresa'
import { REGIMENES_LABEL } from '../../types/empresa'

interface Ctx { empresa: EmpresaDetalle }

export default function DeclaracionEditor() {
  const { pdtId } = useParams<{ pdtId: string }>()
  const { empresa } = useOutletContext<Ctx>()
  const navigate = useNavigate()

  const [pdt, setPdt] = useState<PDT621 | null>(null)
  const [loading, setLoading] = useState(true)
  const [importacion, setImportacion] = useState<ImportacionSunat | null>(null)

  const [ajustes, setAjustes] = useState<Ajustes>({
    saldo_favor_anterior: 0,
    percepciones_periodo: 0,
    retenciones_periodo: 0,
    pagos_anticipados: 0,
    retenciones_renta: 0,
  })

  const [calculo, setCalculo] = useState<ResultadoCalculo | null>(null)
  const [importando, setImportando] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [mensaje, setMensaje] = useState<{ tipo: 'success' | 'error'; texto: string } | null>(null)
  const [modalPresentar, setModalPresentar] = useState(false)
  const [modalResultado, setModalResultado] = useState(false)
  const [numOperacion, setNumOperacion] = useState('')

  // Modales de detalle de comprobantes
  const [modalDetalle, setModalDetalle] = useState<null | 'ventas' | 'compras'>(null)

  // Modal para subir comprobante manualmente
  const [modalSubir, setModalSubir] = useState<null | 'venta' | 'compra'>(null)
  const [formSubir, setFormSubir] = useState({
    tipo_comprobante: '01',
    serie: '',
    numero: '',
    fecha_emision: '',
    ruc: '',
    razon_social: '',
    base_gravada: 0,
    base_no_gravada: 0,
    igv: 0,
    total: 0,
  })
  const [subiendo, setSubiendo] = useState(false)

  const ajustesDebounced = useDebounce(ajustes, 600)

  useEffect(() => {
    if (pdtId) cargar(Number(pdtId))
  }, [pdtId])

  useEffect(() => {
    if (pdt && !loading) {
      recalcularVivo()
    }
  }, [ajustesDebounced, pdt])

  async function cargar(id: number) {
    setLoading(true)
    try {
      const data = await pdt621Service.obtener(id)
      setPdt(data)
      const saldo = await pdt621Service.sugerirSaldoFavor(empresa.id, data.ano, data.mes)
      if (saldo.saldo_sugerido > 0) {
        setAjustes(a => ({ ...a, saldo_favor_anterior: saldo.saldo_sugerido }))
      }
    } finally { setLoading(false) }
  }

  async function recalcularVivo() {
    if (!pdt) return
    try {
      const res = await pdt621Service.aplicarAjustes(pdt.id, ajustesDebounced)
      setCalculo(res)
    } catch (err) { console.error(err) }
  }

  async function handleImportarSunat() {
    if (!pdt) return
    setImportando(true)
    setMensaje(null)
    try {
      const res = await pdt621Service.importarSunat(pdt.id)
      setImportacion(res)
      await cargar(pdt.id)
      setMensaje({
        tipo: 'success',
        texto: res.fuente === 'SUNAT_SIRE'
          ? 'Datos descargados exitosamente desde SUNAT SIRE'
          : 'Datos importados (modo simulado - configura credenciales API SUNAT para descarga real)',
      })
    } catch (err: any) {
      setMensaje({
        tipo: 'error',
        texto: err.response?.data?.detail || 'Error al importar desde SUNAT',
      })
    } finally { setImportando(false) }
  }

  async function handleGuardarBorrador() {
    if (!pdt) return
    setGuardando(true)
    try {
      await pdt621Service.aplicarAjustes(pdt.id, ajustes)
      setMensaje({ tipo: 'success', texto: 'Borrador guardado' })
      setTimeout(() => setMensaje(null), 2500)
    } finally { setGuardando(false) }
  }

  async function handleGenerar() {
    if (!pdt) return
    setGuardando(true)
    try {
      await pdt621Service.aplicarAjustes(pdt.id, ajustes)
      const actualizado = await pdt621Service.cambiarEstado(pdt.id, 'GENERATED')
      setPdt(actualizado)
      setMensaje({ tipo: 'success', texto: 'Declaracion generada correctamente' })
    } catch (err: any) {
      setMensaje({ tipo: 'error', texto: err.response?.data?.detail || 'Error al generar' })
    } finally { setGuardando(false) }
  }

  async function handlePresentar() {
    if (!pdt) return
    setGuardando(true)
    try {
      const actualizado = await pdt621Service.cambiarEstado(
        pdt.id, 'SUBMITTED', numOperacion || undefined
      )
      setPdt(actualizado)
      setModalPresentar(false)
      setMensaje({ tipo: 'success', texto: 'Declaracion marcada como presentada' })
    } finally { setGuardando(false) }
  }

  async function handleResultado(resultado: 'ACCEPTED' | 'REJECTED', mensajeErr?: string) {
    if (!pdt) return
    setGuardando(true)
    try {
      const actualizado = await pdt621Service.cambiarEstado(
        pdt.id, resultado, undefined, mensajeErr
      )
      setPdt(actualizado)
      setModalResultado(false)
      setMensaje({
        tipo: resultado === 'ACCEPTED' ? 'success' : 'error',
        texto: resultado === 'ACCEPTED'
          ? 'Declaracion aceptada por SUNAT'
          : 'Declaracion rechazada',
      })
    } finally { setGuardando(false) }
  }

  // Callback cuando se aplican cambios en el modal: recarga el PDT y recalcula
  async function onSeleccionAplicada() {
    if (!pdt) return
    setMensaje({ tipo: 'success', texto: 'Selección aplicada. PDT recalculado.' })
    setTimeout(() => setMensaje(null), 2500)
    await cargar(pdt.id)
  }

  async function handleSubirComprobante() {
    if (!pdt) return
    setSubiendo(true)
    try {
      if (modalSubir === 'venta') {
        await pdt621Service.agregarVenta(pdt.id, {
          tipo_comprobante: formSubir.tipo_comprobante,
          serie: formSubir.serie,
          numero: formSubir.numero,
          fecha_emision: formSubir.fecha_emision,
          ruc_cliente: formSubir.ruc,
          razon_social_cliente: formSubir.razon_social,
          base_gravada: formSubir.base_gravada,
          base_no_gravada: formSubir.base_no_gravada,
          exportacion: 0,
          igv: formSubir.igv,
          total: formSubir.total,
        })
        setMensaje({ tipo: 'success', texto: 'Venta agregada correctamente' })
      } else {
        await pdt621Service.agregarCompra(pdt.id, {
          tipo_comprobante: formSubir.tipo_comprobante,
          serie: formSubir.serie,
          numero: formSubir.numero,
          fecha_emision: formSubir.fecha_emision,
          ruc_proveedor: formSubir.ruc,
          razon_social_proveedor: formSubir.razon_social,
          base_gravada: formSubir.base_gravada,
          base_no_gravada: formSubir.base_no_gravada,
          igv: formSubir.igv,
          total: formSubir.total,
        })
        setMensaje({ tipo: 'success', texto: 'Compra agregada correctamente' })
      }
      setModalSubir(null)
      setFormSubir({
        tipo_comprobante: '01', serie: '', numero: '',
        fecha_emision: '', ruc: '', razon_social: '',
        base_gravada: 0, base_no_gravada: 0, igv: 0, total: 0,
      })
      await cargar(pdt.id)
    } catch (err: any) {
      setMensaje({ tipo: 'error', texto: err.response?.data?.detail || 'Error al subir comprobante' })
    } finally {
      setSubiendo(false)
    }
  }

  function calcularIGV() {
    const base = formSubir.base_gravada + formSubir.base_no_gravada
    const igv = base * 0.18
    setFormSubir(f => ({ ...f, igv: Math.round(igv * 100) / 100, total: Math.round((base + igv) * 100) / 100 }))
  }

  if (loading || !pdt) {
    return (
      <div className="p-8 flex items-center justify-center text-gray-400">
        <Loader2 size={16} className="animate-spin mr-2" /> Cargando declaracion...
      </div>
    )
  }

  const estadoCfg = ESTADO_CONFIG[pdt.estado]
  const esEditable = pdt.estado === 'DRAFT' || pdt.estado === 'REJECTED'
  const tieneDatos = Number(pdt.c100_ventas_gravadas) > 0 || Number(pdt.c120_compras_gravadas) > 0

  const totales = calculo || {
    igv: {
      igv_debito: Number(pdt.c140igv_igv_debito),
      igv_credito: Number(pdt.c180_igv_credito),
      igv_resultante: Number(pdt.c140igv_igv_debito) - Number(pdt.c180_igv_credito),
      total_creditos_aplicables: 0,
      igv_a_pagar: Number(pdt.c184_igv_a_pagar),
      saldo_favor_siguiente: 0,
      percepciones_aplicadas: 0,
      retenciones_aplicadas: 0,
      saldo_favor_aplicado: 0,
      subtotal_ventas: 0,
      subtotal_compras: 0,
    },
    renta: {
      regimen: empresa.regimen_tributario,
      tasa_aplicada: 0.015,
      base_calculo: Number(pdt.c301_ingresos_netos),
      renta_bruta: Number(pdt.c309_pago_a_cuenta_renta),
      creditos_aplicados: 0,
      renta_a_pagar: Number(pdt.c318_renta_a_pagar),
      observaciones: '',
    },
    total_a_pagar: Number(pdt.total_a_pagar),
  }

  return (
    <>
      <PageHeader
        eyebrow={`${empresa.razon_social} - PDT 621`}
        title={`${MESES_LABEL[pdt.mes]} ${pdt.ano}`}
        description={`Declaracion mensual IGV y Renta - ${REGIMENES_LABEL[empresa.regimen_tributario]}`}
        actions={
          <div className="flex items-center gap-2">
            <button
              onClick={() => navigate(`/empresas/${empresa.id}/declaraciones`)}
              className="btn-secondary flex items-center gap-2"
            >
              <ArrowLeft size={14} /> Volver
            </button>
            <span className={`text-xs font-semibold px-3 py-1.5 rounded-full ${estadoCfg.bg} ${estadoCfg.color}`}>
              {estadoCfg.label}
            </span>
          </div>
        }
      />

      <div className="p-6 lg:p-8 grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* Columna principal */}
        <div className="lg:col-span-2 space-y-4">

          {/* Mensaje */}
          {mensaje && (
            <div className={`rounded-lg p-3 flex items-start gap-2 text-sm ${
              mensaje.tipo === 'success'
                ? 'bg-success-50 text-success-900 border border-success-600/30'
                : 'bg-danger-50 text-danger-900 border border-danger-600/30'
            }`}>
              {mensaje.tipo === 'success' ? <CheckCircle2 size={14} className="mt-0.5" /> : <AlertCircle size={14} className="mt-0.5" />}
              <p>{mensaje.texto}</p>
            </div>
          )}

          {/* Datos desde SUNAT */}
          <div className="card">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <h2 className="font-heading font-bold text-gray-900 flex items-center gap-2">
                  <Database size={14} className="text-brand-800" />
                  Datos desde SUNAT
                </h2>
                {tieneDatos && importacion && (
                  <span className={`text-[10px] px-2 py-0.5 rounded-full font-semibold ${
                    importacion.fuente === 'SUNAT_SIRE'
                      ? 'bg-success-50 text-success-900'
                      : 'bg-warning-50 text-warning-900'
                  }`}>
                    {importacion.fuente === 'SUNAT_SIRE' ? 'Datos reales' : 'Datos simulados'}
                  </span>
                )}
              </div>
              {esEditable && (
                <button
                  onClick={handleImportarSunat}
                  disabled={importando}
                  className="btn-primary flex items-center gap-2 text-xs"
                >
                  {importando
                    ? <Loader2 size={12} className="animate-spin" />
                    : <Download size={12} />}
                  {tieneDatos ? 'Volver a descargar' : 'Descargar de SUNAT'}
                </button>
              )}
            </div>

            {!tieneDatos ? (
              <div className="p-8 text-center">
                <Cloud size={32} className="text-gray-300 mx-auto mb-2" />
                <p className="text-sm text-gray-600 mb-1">No hay datos importados</p>
                <p className="text-xs text-gray-400">
                  Click en <strong>"Descargar de SUNAT"</strong> para obtener las ventas y compras del periodo
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-2 divide-x divide-gray-100">
                {/* ── VENTAS ── */}
                <div className="p-5">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2 text-xs text-gray-500 uppercase tracking-wide font-semibold">
                      <TrendingUp size={12} className="text-success-600" /> Ventas (RVIE)
                    </div>
                    <div className="flex items-center gap-2">
                      {esEditable && (
                        <button
                          onClick={() => {
                            setFormSubir({
                              tipo_comprobante: '01', serie: '', numero: '',
                              fecha_emision: '', ruc: '', razon_social: '',
                              base_gravada: 0, base_no_gravada: 0, igv: 0, total: 0,
                            })
                            setModalSubir('venta')
                          }}
                          className="inline-flex items-center gap-1 text-[11px] text-brand-600 hover:text-brand-800 font-medium"
                          title="Subir venta manualmente"
                        >
                          <Upload size={12} /> Subir venta
                        </button>
                      )}
                      <button
                        onClick={() => setModalDetalle('ventas')}
                        className="inline-flex items-center gap-1 text-[11px] text-brand-800 hover:text-brand-900 font-medium hover:underline"
                        title="Ver detalle de comprobantes"
                      >
                        <Eye size={12} /> Ver detalle
                      </button>
                    </div>
                  </div>
                  <div className="space-y-1 text-sm">
                    <DataRow label="Gravadas" value={formatoSoles(Number(pdt.c100_ventas_gravadas))} />
                    <DataRow label="No gravadas" value={formatoSoles(Number(pdt.c104_ventas_no_gravadas))} />
                    <DataRow label="Exportaciones" value={formatoSoles(Number(pdt.c105_exportaciones))} />
                    <div className="pt-2 mt-2 border-t border-gray-100">
                      <DataRow label="IGV debito" value={formatoSoles(Number(pdt.c140igv_igv_debito))} destacado />
                    </div>
                  </div>
                </div>

                {/* ── COMPRAS ── */}
                <div className="p-5">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2 text-xs text-gray-500 uppercase tracking-wide font-semibold">
                      <TrendingDown size={12} className="text-brand-600" /> Compras (RCE)
                    </div>
                    <div className="flex items-center gap-2">
                      {esEditable && (
                        <button
                          onClick={() => {
                            setFormSubir({
                              tipo_comprobante: '01', serie: '', numero: '',
                              fecha_emision: '', ruc: '', razon_social: '',
                              base_gravada: 0, base_no_gravada: 0, igv: 0, total: 0,
                            })
                            setModalSubir('compra')
                          }}
                          className="inline-flex items-center gap-1 text-[11px] text-brand-600 hover:text-brand-800 font-medium"
                          title="Subir compra manualmente"
                        >
                          <Upload size={12} /> Subir compra
                        </button>
                      )}
                      <button
                        onClick={() => setModalDetalle('compras')}
                        className="inline-flex items-center gap-1 text-[11px] text-brand-800 hover:text-brand-900 font-medium hover:underline"
                        title="Ver detalle de comprobantes"
                      >
                        <Eye size={12} /> Ver detalle
                      </button>
                    </div>
                  </div>
                  <div className="space-y-1 text-sm">
                    <DataRow label="Gravadas" value={formatoSoles(Number(pdt.c120_compras_gravadas))} />
                    <div className="pt-2 mt-2 border-t border-gray-100">
                      <DataRow label="IGV credito" value={formatoSoles(Number(pdt.c180_igv_credito))} destacado />
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Ajustes del contador */}
          <div className="card">
            <div className="px-5 py-4 border-b border-gray-100">
              <h2 className="font-heading font-bold text-gray-900 flex items-center gap-2">
                <Settings size={14} className="text-brand-800" />
                Ajustes del contador
              </h2>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Creditos IGV</p>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <AjusteInput
                    label="Saldo a favor mes anterior"
                    value={ajustes.saldo_favor_anterior || 0}
                    onChange={v => setAjustes(a => ({ ...a, saldo_favor_anterior: v }))}
                    disabled={!esEditable}
                    hint="Sugerido del PDT anterior"
                  />
                  <AjusteInput
                    label="Percepciones del periodo"
                    value={ajustes.percepciones_periodo || 0}
                    onChange={v => setAjustes(a => ({ ...a, percepciones_periodo: v }))}
                    disabled={!esEditable}
                  />
                  <AjusteInput
                    label="Retenciones del periodo"
                    value={ajustes.retenciones_periodo || 0}
                    onChange={v => setAjustes(a => ({ ...a, retenciones_periodo: v }))}
                    disabled={!esEditable}
                  />
                </div>
              </div>

              <div>
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Creditos renta</p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <AjusteInput
                    label="Pagos anticipados"
                    value={ajustes.pagos_anticipados || 0}
                    onChange={v => setAjustes(a => ({ ...a, pagos_anticipados: v }))}
                    disabled={!esEditable}
                  />
                  <AjusteInput
                    label="Retenciones renta"
                    value={ajustes.retenciones_renta || 0}
                    onChange={v => setAjustes(a => ({ ...a, retenciones_renta: v }))}
                    disabled={!esEditable}
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Acciones segun estado */}
          {esEditable && (
            <div className="flex items-center gap-2 justify-end">
              <button
                onClick={handleGuardarBorrador}
                disabled={guardando}
                className="btn-secondary flex items-center gap-2"
              >
                {guardando ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
                Guardar borrador
              </button>
              <button
                onClick={handleGenerar}
                disabled={guardando || !tieneDatos}
                className="btn-primary flex items-center gap-2"
                title={!tieneDatos ? 'Primero descarga datos desde SUNAT' : ''}
              >
                <FileText size={14} /> Generar declaracion
              </button>
            </div>
          )}

          {pdt.estado === 'GENERATED' && (
            <div className="flex items-center gap-2 justify-end">
              <button
                onClick={() => pdt621Service.cambiarEstado(pdt.id, 'DRAFT').then(p => setPdt(p))}
                className="btn-secondary"
              >
                Volver a borrador
              </button>
              <button
                onClick={() => setModalPresentar(true)}
                className="btn-primary flex items-center gap-2"
              >
                <Send size={14} /> Marcar como presentada
              </button>
            </div>
          )}

          {pdt.estado === 'SUBMITTED' && (
            <div className="flex items-center gap-2 justify-end">
              <button
                onClick={() => setModalResultado(true)}
                className="btn-primary flex items-center gap-2"
              >
                <CheckCircle2 size={14} /> Registrar resultado
              </button>
            </div>
          )}

          {pdt.estado === 'ACCEPTED' && (
            <div className="rounded-lg bg-success-50 border border-success-600/30 p-4 flex items-start gap-3">
              <CheckCircle2 className="text-success-600 flex-shrink-0 mt-0.5" size={16} />
              <div className="text-sm">
                <p className="font-semibold text-success-900">Declaracion aceptada por SUNAT</p>
                {pdt.numero_operacion && (
                  <p className="text-success-700 text-xs mt-1">
                    Numero de operacion: <span className="font-mono font-semibold">{pdt.numero_operacion}</span>
                  </p>
                )}
              </div>
            </div>
          )}

          {pdt.estado === 'REJECTED' && pdt.mensaje_error_sunat && (
            <div className="rounded-lg bg-danger-50 border border-danger-600/30 p-4 flex items-start gap-3">
              <XCircle className="text-danger-600 flex-shrink-0 mt-0.5" size={16} />
              <div className="text-sm">
                <p className="font-semibold text-danger-900">Declaracion rechazada</p>
                <p className="text-danger-700 text-xs mt-1">{pdt.mensaje_error_sunat}</p>
              </div>
            </div>
          )}
        </div>

        {/* Sidebar: calculo vivo */}
        <div className="space-y-4">
          <div className="card sticky top-4">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
              <h2 className="font-heading font-bold text-gray-900 flex items-center gap-2">
                <RefreshCw size={14} className="text-brand-800" />
                Calculo en vivo
              </h2>
            </div>

            <div className="p-5 space-y-4">
              {/* IGV */}
              <div>
                <p className="text-[10px] font-semibold text-gray-500 uppercase tracking-wider mb-2">IGV</p>
                <div className="space-y-1 text-sm">
                  <DataRow label="Debito" value={formatoSoles(totales.igv.igv_debito)} />
                  <DataRow label="- Credito" value={formatoSoles(totales.igv.igv_credito)} />
                  <div className="pt-1 mt-1 border-t border-dashed border-gray-200">
                    <DataRow label="Sub-total" value={formatoSoles(totales.igv.igv_resultante)} />
                  </div>
                  {totales.igv.saldo_favor_aplicado > 0 && (
                    <DataRow label="- Saldo aplicado" value={formatoSoles(totales.igv.saldo_favor_aplicado)} chico />
                  )}
                  {totales.igv.percepciones_aplicadas > 0 && (
                    <DataRow label="- Percepciones" value={formatoSoles(totales.igv.percepciones_aplicadas)} chico />
                  )}
                  {totales.igv.retenciones_aplicadas > 0 && (
                    <DataRow label="- Retenciones" value={formatoSoles(totales.igv.retenciones_aplicadas)} chico />
                  )}
                  <div className={`pt-2 mt-2 border-t border-gray-200 p-2 rounded ${
                    totales.igv.igv_a_pagar > 0 ? 'bg-brand-50' : 'bg-gray-50'
                  }`}>
                    <DataRow label="IGV a pagar" value={formatoSoles(totales.igv.igv_a_pagar)} destacado />
                  </div>
                </div>
              </div>

              {/* Renta */}
              <div>
                <p className="text-[10px] font-semibold text-gray-500 uppercase tracking-wider mb-2">
                  Renta ({totales.renta.regimen})
                </p>
                <div className="space-y-1 text-sm">
                  <DataRow label="Base" value={formatoSoles(totales.renta.base_calculo)} />
                  <DataRow
                    label={`Tasa ${(totales.renta.tasa_aplicada * 100).toFixed(2)}%`}
                    value={formatoSoles(totales.renta.renta_bruta)}
                  />
                  {totales.renta.creditos_aplicados > 0 && (
                    <DataRow label="- Creditos" value={formatoSoles(totales.renta.creditos_aplicados)} chico />
                  )}
                  <div className={`pt-2 mt-2 border-t border-gray-200 p-2 rounded ${
                    totales.renta.renta_a_pagar > 0 ? 'bg-brand-50' : 'bg-gray-50'
                  }`}>
                    <DataRow label="Renta a pagar" value={formatoSoles(totales.renta.renta_a_pagar)} destacado />
                  </div>
                </div>
              </div>

              {/* Total */}
              <div className="bg-sidebar-bg text-white rounded-lg p-4">
                <p className="text-[10px] font-semibold text-sidebar-muted uppercase tracking-wider mb-1">Total a pagar</p>
                <p className="font-mono font-bold text-2xl">
                  {formatoSoles(totales.total_a_pagar)}
                </p>
              </div>
            </div>
          </div>
        </div>

      </div>

      {/* ── Modal: Marcar como presentada ── */}
      <Modal
        isOpen={modalPresentar}
        onClose={() => !guardando && setModalPresentar(false)}
        title="Marcar como presentada"
        description="Registra el numero de operacion que devolvio SUNAT"
        size="sm"
        footer={
          <>
            <button onClick={() => setModalPresentar(false)} className="btn-secondary" disabled={guardando}>
              Cancelar
            </button>
            <button onClick={handlePresentar} disabled={guardando} className="btn-primary">
              {guardando ? <Loader2 size={14} className="animate-spin" /> : 'Confirmar'}
            </button>
          </>
        }
      >
        <div className="space-y-3">
          <div>
            <label className="label">Numero de operacion (opcional)</label>
            <input
              value={numOperacion}
              onChange={e => setNumOperacion(e.target.value)}
              className="input font-mono"
              placeholder="Ejemplo: 1234567890"
            />
          </div>
          <div className="bg-warning-50 border border-warning-600/30 rounded-lg p-3 flex gap-2 text-xs">
            <Info size={14} className="text-warning-700 flex-shrink-0 mt-0.5" />
            <p className="text-warning-900">
              Asegurate de haber presentado el PDT en la plataforma de SUNAT antes de marcar como presentada.
            </p>
          </div>
        </div>
      </Modal>

      {/* ── Modal: Registrar resultado ── */}
      <Modal
        isOpen={modalResultado}
        onClose={() => !guardando && setModalResultado(false)}
        title="Registrar resultado"
        description="Indica si SUNAT acepto o rechazo la declaracion"
        size="sm"
        footer={
          <button onClick={() => setModalResultado(false)} className="btn-secondary" disabled={guardando}>
            Cerrar
          </button>
        }
      >
        <div className="space-y-3">
          <button
            onClick={() => handleResultado('ACCEPTED')}
            disabled={guardando}
            className="w-full p-4 border-2 border-success-600/30 hover:bg-success-50 rounded-lg flex items-center gap-3 transition-colors"
          >
            <CheckCircle2 className="text-success-600" size={20} />
            <div className="text-left">
              <p className="font-semibold text-success-900">Aceptada</p>
              <p className="text-xs text-success-700">SUNAT acepto la declaracion</p>
            </div>
          </button>

          <button
            onClick={() => {
              const msg = prompt('Mensaje de error de SUNAT (opcional):')
              handleResultado('REJECTED', msg || undefined)
            }}
            disabled={guardando}
            className="w-full p-4 border-2 border-danger-600/30 hover:bg-danger-50 rounded-lg flex items-center gap-3 transition-colors"
          >
            <XCircle className="text-danger-600" size={20} />
            <div className="text-left">
              <p className="font-semibold text-danger-900">Rechazada</p>
              <p className="text-xs text-danger-700">SUNAT rechazo la declaracion</p>
            </div>
          </button>
        </div>
      </Modal>

      {/* ── Modal: Detalle de comprobantes ── */}
      {modalDetalle && pdt && (
        <DetalleComprobantesModal
          isOpen={!!modalDetalle}
          onClose={() => setModalDetalle(null)}
          pdtId={pdt.id}
          empresaId={empresa.id}
          tipo={modalDetalle}
          editable={esEditable}
          onAplicado={onSeleccionAplicada}
        />
      )}

      {/* ── Modal: Subir comprobante manualmente ── */}
      <Modal
        isOpen={modalSubir !== null}
        onClose={() => !subiendo && setModalSubir(null)}
        title={modalSubir === 'venta' ? 'Subir venta manualmente' : 'Subir compra manualmente'}
        description="Agrega un comprobante que no fue descargado desde SUNAT"
        size="md"
        footer={
          <>
            <button onClick={() => setModalSubir(null)} className="btn-secondary" disabled={subiendo}>
              Cancelar
            </button>
            <button onClick={handleSubirComprobante} disabled={subiendo} className="btn-primary flex items-center gap-2">
              {subiendo ? <Loader2 size={14} className="animate-spin" /> : <Plus size={14} />}
              {subiendo ? 'Guardando...' : 'Agregar comprobante'}
            </button>
          </>
        }
      >
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="label">Tipo de documento</label>
              <select
                value={formSubir.tipo_comprobante}
                onChange={e => setFormSubir(f => ({ ...f, tipo_comprobante: e.target.value }))}
                className="input"
                disabled={subiendo}
              >
                <option value="01">Factura</option>
                <option value="03">Boleta</option>
                <option value="07">Nota de Crédito</option>
                <option value="08">Nota de Débito</option>
              </select>
            </div>
            <div>
              <label className="label">Fecha de emisión</label>
              <input
                type="date"
                value={formSubir.fecha_emision}
                onChange={e => setFormSubir(f => ({ ...f, fecha_emision: e.target.value }))}
                className="input"
                disabled={subiendo}
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="label">Serie</label>
              <input
                type="text"
                value={formSubir.serie}
                onChange={e => setFormSubir(f => ({ ...f, serie: e.target.value.toUpperCase() }))}
                className="input font-mono"
                placeholder="F001"
                disabled={subiendo}
              />
            </div>
            <div>
              <label className="label">Número</label>
              <input
                type="text"
                value={formSubir.numero}
                onChange={e => setFormSubir(f => ({ ...f, numero: e.target.value }))}
                className="input font-mono"
                placeholder="000001"
                disabled={subiendo}
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="label">RUC {modalSubir === 'venta' ? 'cliente' : 'proveedor'}</label>
              <input
                type="text"
                value={formSubir.ruc}
                onChange={e => setFormSubir(f => ({ ...f, ruc: e.target.value }))}
                className="input font-mono"
                placeholder="20100070970"
                maxLength={11}
                disabled={subiendo}
              />
            </div>
            <div>
              <label className="label">Razón Social</label>
              <input
                type="text"
                value={formSubir.razon_social}
                onChange={e => setFormSubir(f => ({ ...f, razon_social: e.target.value.toUpperCase() }))}
                className="input"
                placeholder="NOMBRE DEL CLIENTE"
                disabled={subiendo}
              />
            </div>
          </div>
          <div className="border-t pt-4 mt-4">
            <p className="text-xs font-semibold text-gray-500 uppercase mb-3">Montos (S/)</p>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="label">Base Gravada</label>
                <input
                  type="number"
                  step="0.01"
                  value={formSubir.base_gravada || ''}
                  onChange={e => setFormSubir(f => ({ ...f, base_gravada: Number(e.target.value) || 0 }))}
                  onBlur={calcularIGV}
                  className="input font-mono"
                  placeholder="0.00"
                  disabled={subiendo}
                />
              </div>
              <div>
                <label className="label">Base No Gravada</label>
                <input
                  type="number"
                  step="0.01"
                  value={formSubir.base_no_gravada || ''}
                  onChange={e => setFormSubir(f => ({ ...f, base_no_gravada: Number(e.target.value) || 0 }))}
                  onBlur={calcularIGV}
                  className="input font-mono"
                  placeholder="0.00"
                  disabled={subiendo}
                />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4 mt-3">
              <div>
                <label className="label">IGV (18%)</label>
                <input
                  type="number"
                  step="0.01"
                  value={formSubir.igv || ''}
                  onChange={e => setFormSubir(f => ({ ...f, igv: Number(e.target.value) || 0 }))}
                  className="input font-mono"
                  placeholder="0.00"
                  disabled={subiendo}
                />
              </div>
              <div>
                <label className="label">Total</label>
                <input
                  type="number"
                  step="0.01"
                  value={formSubir.total || ''}
                  onChange={e => setFormSubir(f => ({ ...f, total: Number(e.target.value) || 0 }))}
                  className="input font-mono font-bold"
                  placeholder="0.00"
                  disabled={subiendo}
                />
              </div>
            </div>
            <p className="text-[11px] text-gray-500 mt-2">
              Haz clic fuera de los campos de Base para calcular automáticamente el IGV y Total.
            </p>
          </div>
        </div>
      </Modal>
    </>
  )
}


// ── Componentes internos ────────────────────────────

function DataRow({ label, value, destacado, chico }: {
  label: string; value: string; destacado?: boolean; chico?: boolean
}) {
  return (
    <div className={`flex items-center justify-between ${chico ? 'text-xs text-gray-500' : ''}`}>
      <span className={destacado ? 'font-semibold text-gray-900' : 'text-gray-600'}>{label}</span>
      <span className={`font-mono ${destacado ? 'font-bold text-gray-900' : 'text-gray-700'}`}>{value}</span>
    </div>
  )
}

function AjusteInput({ label, value, onChange, disabled, hint }: {
  label: string; value: number; onChange: (v: number) => void; disabled?: boolean; hint?: string
}) {
  return (
    <div>
      <label className="label text-xs">{label}</label>
      <div className="relative">
        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">S/</span>
        <input
          type="number"
          min="0"
          step="0.01"
          value={value || ''}
          onChange={e => onChange(Number(e.target.value) || 0)}
          disabled={disabled}
          className="input font-mono text-right pl-8 disabled:bg-gray-50 disabled:text-gray-400"
          placeholder="0.00"
        />
      </div>
      {hint && <p className="text-[11px] text-gray-500 mt-1">{hint}</p>}
    </div>
  )
}
