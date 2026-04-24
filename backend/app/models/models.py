from sqlalchemy import (
    Column, Integer, String, Boolean, Numeric, Date, DateTime,
    Text, ForeignKey, UniqueConstraint, CheckConstraint, Index
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
from datetime import datetime


class EstudioContable(Base):
    __tablename__ = "estudios_contables"
    id = Column(Integer, primary_key=True, index=True)
    razon_social = Column(String(255), nullable=False)
    ruc = Column(String(11), unique=True)
    direccion = Column(String(255))
    telefono = Column(String(15))
    email_principal = Column(String(120))
    plan_actual = Column(String(20), default="ESTUDIO")
    cantidad_max_contadores = Column(Integer, default=5)
    cantidad_max_empresas = Column(Integer, default=100)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    usuarios = relationship("Usuario", back_populates="estudio")


class Usuario(Base):
    __tablename__ = "usuarios"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(120), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    nombre = Column(String(100), nullable=False)
    apellido = Column(String(100), nullable=False)
    telefono = Column(String(15))
    rol = Column(String(20), nullable=False, index=True)
    cep_numero = Column(String(20))
    especialidad = Column(String(100))
    plan_actual = Column(String(20), default="FREE")
    fecha_inicio_plan = Column(Date)
    fecha_fin_plan = Column(Date)
    activo = Column(Boolean, default=True)
    estudio_id = Column(Integer, ForeignKey("estudios_contables.id"), nullable=True)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_ultimo_login = Column(DateTime(timezone=True))
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    estudio = relationship("EstudioContable", back_populates="usuarios")
    empresas = relationship("Empresa", back_populates="contador", cascade="all, delete-orphan")
    config_notificaciones = relationship("ConfiguracionNotificaciones", back_populates="contador", uselist=False)
    suscripciones = relationship("Suscripcion", back_populates="contador")
    eventos_calendario = relationship("CalendarioTributario", back_populates="contador")
    notificaciones = relationship("NotificacionWhatsapp", back_populates="contador")
    logs = relationship("LogEvento", back_populates="usuario")
    __table_args__ = (
        Index("idx_usuarios_email", "email"),
        Index("idx_usuarios_rol", "rol"),
        Index("idx_usuarios_estudio", "estudio_id"),
    )


class Empresa(Base):
    __tablename__ = "empresas"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="RESTRICT"), nullable=False)
    ruc = Column(String(11), nullable=False)
    razon_social = Column(String(255), nullable=False)
    nombre_comercial = Column(String(255))
    direccion_fiscal = Column(String(255), nullable=False)
    distrito = Column(String(100))
    provincia = Column(String(100))
    departamento = Column(String(100))
    regimen_tributario = Column(String(20), default="RG")
    tasa_renta_pc = Column(Numeric(5, 2), default=1.50)
    fecha_inicio_actividades = Column(Date)
    estado_sunat = Column(String(20), default="ACTIVO")
    condicion_domicilio = Column(String(20), default="HABIDO")
    representante_legal = Column(String(255))
    email_empresa = Column(String(120))
    telefono_empresa = Column(String(15))
    usuario_sol = Column(String(50))
    clave_sol_encrypted = Column(Text)
    sunat_client_id_encrypted = Column(Text, nullable=True)
    sunat_client_secret_encrypted = Column(Text, nullable=True)
    tipo_acceso_sol = Column(String(10), default="RUC")
    dni_sol = Column(String(8))
    activa = Column(Boolean, default=True)
    color_identificacion = Column(String(7), default="#3B82F6")
    notas_contador = Column(Text)
    nivel_alerta = Column(String(10), default="VERDE")
    motivo_alerta = Column(Text)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    contador = relationship("Usuario", back_populates="empresas")
    pdt621s = relationship("PDT621", back_populates="empresa", cascade="all, delete-orphan")
    eventos_calendario = relationship("CalendarioTributario", back_populates="empresa", cascade="all, delete-orphan")
    notificaciones = relationship("NotificacionWhatsapp", back_populates="empresa")
    logs = relationship("LogEvento", back_populates="empresa")
    __table_args__ = (
        UniqueConstraint("ruc", "contador_id", name="uq_empresa_ruc_contador"),
        Index("idx_empresas_contador", "contador_id"),
        Index("idx_empresas_ruc", "ruc"),
        Index("idx_empresas_alerta", "nivel_alerta"),
        Index("idx_empresas_activa", "activa"),
    )


class PDT621(Base):
    __tablename__ = "pdt621s"
    id = Column(Integer, primary_key=True, index=True)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="CASCADE"), nullable=False)
    mes = Column(Integer, nullable=False)
    ano = Column(Integer, nullable=False)
    fecha_vencimiento = Column(Date, nullable=False)
    estado = Column(String(20), default="DRAFT")
    c100_ventas_gravadas = Column(Numeric(15, 2), default=0)
    c102_descuentos = Column(Numeric(15, 2), default=0)
    c104_ventas_no_gravadas = Column(Numeric(15, 2), default=0)
    c105_exportaciones = Column(Numeric(15, 2), default=0)
    c140_subtotal_ventas = Column(Numeric(15, 2), default=0)
    c140igv_igv_debito = Column(Numeric(15, 2), default=0)
    c120_compras_gravadas = Column(Numeric(15, 2), default=0)
    c180_igv_credito = Column(Numeric(15, 2), default=0)
    c184_igv_a_pagar = Column(Numeric(15, 2), default=0)
    c301_ingresos_netos = Column(Numeric(15, 2), default=0)
    c309_pago_a_cuenta_renta = Column(Numeric(15, 2), default=0)
    c310_retenciones = Column(Numeric(15, 2), default=0)
    c311_pagos_anticipados = Column(Numeric(15, 2), default=0)
    c318_renta_a_pagar = Column(Numeric(15, 2), default=0)
    total_a_pagar = Column(Numeric(15, 2), default=0)
    nps = Column(String(20))
    numero_operacion = Column(String(20))
    codigo_rechazo_sunat = Column(String(10))
    mensaje_error_sunat = Column(Text)
    observaciones = Column(Text)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    fecha_presentacion_sunat = Column(DateTime(timezone=True))
    empresa = relationship("Empresa", back_populates="pdt621s")
    detalles = relationship("PDT621Detalle", back_populates="pdt621", cascade="all, delete-orphan")
    eventos_calendario = relationship("CalendarioTributario", back_populates="pdt621")
    __table_args__ = (
        UniqueConstraint("empresa_id", "mes", "ano", name="uq_pdt621_empresa_periodo"),
        CheckConstraint("mes >= 1 AND mes <= 12", name="chk_pdt621_mes"),
        CheckConstraint("ano >= 2020", name="chk_pdt621_ano"),
        Index("idx_pdt621_empresa", "empresa_id"),
        Index("idx_pdt621_periodo", "ano", "mes"),
        Index("idx_pdt621_estado", "estado"),
        Index("idx_pdt621_vencimiento", "fecha_vencimiento"),
    )

    # Relaciones con el detalle de comprobantes
    ventas_detalle = relationship("PDT621VentaDetalle", back_populates="pdt621", cascade="all, delete-orphan")
    compras_detalle = relationship("PDT621CompraDetalle", back_populates="pdt621", cascade="all, delete-orphan")

class PDT621Detalle(Base):
    __tablename__ = "pdt621_detalles"
    id = Column(Integer, primary_key=True, index=True)
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="CASCADE"), nullable=False)
    tipo_comprobante = Column(String(10), nullable=False)
    numero_comprobante = Column(String(20), nullable=False)
    ruc_cliente = Column(String(11))
    cliente = Column(String(255), nullable=False)
    fecha_emision = Column(Date, nullable=False)
    monto_base = Column(Numeric(15, 2), nullable=False)
    monto_igv = Column(Numeric(15, 2), nullable=False)
    monto_total = Column(Numeric(15, 2), nullable=False)
    tipo_operacion = Column(String(20), nullable=False)
    fecha_registro = Column(DateTime(timezone=True), server_default=func.now())
    pdt621 = relationship("PDT621", back_populates="detalles")


class CalendarioTributario(Base):
    __tablename__ = "calendario_tributario"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="CASCADE"), nullable=False)
    tipo_evento = Column(String(30), nullable=False)
    titulo = Column(String(255), nullable=False)
    descripcion = Column(Text)
    fecha_evento = Column(Date, nullable=False)
    fecha_vencimiento = Column(Date, nullable=False)
    estado = Column(String(20), default="PENDIENTE")
    dias_aviso_previo = Column(Integer, default=5)
    aviso_enviado = Column(Boolean, default=False)
    color = Column(String(7), default="#3B82F6")
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="SET NULL"), nullable=True)
    es_recurrente = Column(Boolean, default=True)
    frecuencia = Column(String(20))
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    contador = relationship("Usuario", back_populates="eventos_calendario")
    empresa = relationship("Empresa", back_populates="eventos_calendario")
    pdt621 = relationship("PDT621", back_populates="eventos_calendario")
    __table_args__ = (
        Index("idx_cal_contador", "contador_id"),
        Index("idx_cal_empresa", "empresa_id"),
        Index("idx_cal_fecha", "fecha_vencimiento"),
        Index("idx_cal_estado", "estado"),
    )


class CronogramaSunat(Base):
    __tablename__ = "cronograma_sunat"
    id = Column(Integer, primary_key=True, index=True)
    ano = Column(Integer, nullable=False)
    mes = Column(Integer, nullable=False)
    ultimo_digito_ruc = Column(String(4), nullable=False)
    fecha_pdt621 = Column(Date)
    fecha_plame = Column(Date)
    fecha_otros = Column(Date)
    __table_args__ = (
        UniqueConstraint("ano", "mes", "ultimo_digito_ruc", name="uq_cronograma_periodo_digito"),
        Index("idx_cronograma_periodo", "ano", "mes"),
        Index("idx_cronograma_digito", "ultimo_digito_ruc"),
        CheckConstraint("mes >= 1 AND mes <= 12", name="chk_cronograma_mes"),
    )


class PlanSuscripcion(Base):
    __tablename__ = "planes_suscripcion"
    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(50), unique=True, nullable=False)
    descripcion = Column(Text)
    precio_mensual = Column(Numeric(10, 2))
    precio_anual = Column(Numeric(10, 2))
    max_empresas = Column(Integer, nullable=False)
    max_pdt621_mes = Column(Integer)
    max_contadores = Column(Integer, default=1)
    max_notificaciones_mes = Column(Integer)
    permite_ia_avanzada = Column(Boolean, default=False)
    permite_api_access = Column(Boolean, default=False)
    permite_reportes_consolidados = Column(Boolean, default=False)
    permite_multi_usuario = Column(Boolean, default=False)
    nivel_soporte = Column(String(20))
    activo = Column(Boolean, default=True)
    orden_visualizacion = Column(Integer)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    suscripciones = relationship("Suscripcion", back_populates="plan")


class Suscripcion(Base):
    __tablename__ = "suscripciones"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    plan_id = Column(Integer, ForeignKey("planes_suscripcion.id"), nullable=False)
    fecha_inicio = Column(Date, nullable=False)
    fecha_fin = Column(Date, nullable=False)
    estado = Column(String(20), default="ACTIVA")
    monto_pagado = Column(Numeric(10, 2), nullable=False)
    metodo_pago = Column(String(30))
    referencia_pago = Column(String(100))
    renovacion_automatica = Column(Boolean, default=True)
    fecha_proxima_facturacion = Column(Date)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    contador = relationship("Usuario", back_populates="suscripciones")
    plan = relationship("PlanSuscripcion", back_populates="suscripciones")
    __table_args__ = (
        Index("idx_suscripciones_contador", "contador_id"),
        Index("idx_suscripciones_estado", "estado"),
    )


class ConfiguracionNotificaciones(Base):
    __tablename__ = "configuracion_notificaciones"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False, unique=True)
    numero_whatsapp = Column(String(20))
    numero_alternativo = Column(String(20))
    notif_cpe_aceptado = Column(Boolean, default=True)
    notif_cpe_rechazado = Column(Boolean, default=True)
    notif_pdt621_generado = Column(Boolean, default=True)
    notif_pdt621_presentado = Column(Boolean, default=True)
    notif_alertas_compliance = Column(Boolean, default=True)
    notif_recordatorio_pago = Column(Boolean, default=True)
    notif_resumen_diario = Column(Boolean, default=False)
    notif_calendario_diario = Column(Boolean, default=True)
    notif_errores = Column(Boolean, default=True)
    hora_inicio = Column(Integer, default=8)
    hora_fin = Column(Integer, default=18)
    consolidar_notificaciones = Column(Boolean, default=False)
    validado = Column(Boolean, default=False)
    codigo_verificacion = Column(String(6))
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    contador = relationship("Usuario", back_populates="config_notificaciones")
    __table_args__ = (Index("idx_config_notif_contador", "contador_id"),)


class NotificacionWhatsapp(Base):
    __tablename__ = "notificaciones_whatsapp"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="SET NULL"), nullable=True)
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="SET NULL"), nullable=True)
    tipo_notificacion = Column(String(50), nullable=False)
    asunto = Column(String(255), nullable=False)
    mensaje = Column(Text, nullable=False)
    numero_destino = Column(String(20), nullable=False)
    estado = Column(String(20), default="PENDING")
    mensaje_id_twilio = Column(String(50))
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_envio = Column(DateTime(timezone=True))
    fecha_entrega = Column(DateTime(timezone=True))
    codigo_error = Column(String(10))
    descripcion_error = Column(Text)
    reintentos = Column(Integer, default=0)
    max_reintentos = Column(Integer, default=3)
    contador = relationship("Usuario", back_populates="notificaciones")
    empresa = relationship("Empresa", back_populates="notificaciones")
    __table_args__ = (
        Index("idx_notif_contador", "contador_id"),
        Index("idx_notif_empresa", "empresa_id"),
        Index("idx_notif_estado", "estado"),
    )


class LogEvento(Base):
    __tablename__ = "log_eventos"
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="SET NULL"), nullable=True)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="SET NULL"), nullable=True)
    tipo_evento = Column(String(50), nullable=False)
    descripcion = Column(Text, nullable=False)
    datos_json = Column(Text)
    nivel = Column(String(10), default="INFO")
    ip_address = Column(String(45))
    user_agent = Column(Text)
    fecha_evento = Column(DateTime(timezone=True), server_default=func.now())
    usuario = relationship("Usuario", back_populates="logs")
    empresa = relationship("Empresa", back_populates="logs")
    __table_args__ = (
        Index("idx_log_usuario", "usuario_id"),
        Index("idx_log_empresa", "empresa_id"),
        Index("idx_log_tipo", "tipo_evento"),
    )


# ════════════════════════════════════════════════════════════
# DETALLE DE COMPROBANTES IMPORTADOS DESDE SIRE
# Un registro por comprobante descargado. Permite al contador
# marcar/desmarcar cuales entran al calculo del PDT.
# ════════════════════════════════════════════════════════════

class PDT621VentaDetalle(Base):
    __tablename__ = "pdt621_ventas_detalle"

    id = Column(Integer, primary_key=True, index=True)
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="CASCADE"), nullable=False, index=True)

    # Datos del comprobante (RVIE)
    tipo_comprobante = Column(String(4), nullable=False)      # 01=Factura, 03=Boleta, 07=NC, 08=ND
    serie = Column(String(10), nullable=False)
    numero = Column(String(20), nullable=False)
    fecha_emision = Column(Date, nullable=False)
    ruc_cliente = Column(String(11))
    razon_social_cliente = Column(String(255), nullable=False)

    # Importes
    base_gravada = Column(Numeric(15, 2), default=0)
    base_no_gravada = Column(Numeric(15, 2), default=0)
    exportacion = Column(Numeric(15, 2), default=0)
    igv = Column(Numeric(15, 2), default=0)
    total = Column(Numeric(15, 2), nullable=False)

    # Control
    incluido = Column(Boolean, default=True, nullable=False)  # Si entra al calculo
    fuente = Column(String(20), default="SUNAT_SIRE")         # SUNAT_SIRE o MOCK
    fecha_importacion = Column(DateTime, default=datetime.utcnow)

    # Relacion
    pdt621 = relationship("PDT621", back_populates="ventas_detalle")


class PDT621CompraDetalle(Base):
    __tablename__ = "pdt621_compras_detalle"

    id = Column(Integer, primary_key=True, index=True)
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="CASCADE"), nullable=False, index=True)

    # Datos del comprobante (RCE)
    tipo_comprobante = Column(String(4), nullable=False)
    serie = Column(String(10), nullable=False)
    numero = Column(String(20), nullable=False)
    fecha_emision = Column(Date, nullable=False)
    ruc_proveedor = Column(String(11))
    razon_social_proveedor = Column(String(255), nullable=False)

    # Importes
    base_gravada = Column(Numeric(15, 2), default=0)
    base_no_gravada = Column(Numeric(15, 2), default=0)
    igv = Column(Numeric(15, 2), default=0)
    total = Column(Numeric(15, 2), nullable=False)

    # Clasificacion del credito (para casos mixtos)
    # GRAVADA_EXCLUSIVA, GRAVADA_Y_NO_GRAVADA, NO_GRAVADA_EXCLUSIVA
    tipo_destino = Column(String(30), default="GRAVADA_EXCLUSIVA")

    # Control
    incluido = Column(Boolean, default=True, nullable=False)
    fuente = Column(String(20), default="SUNAT_SIRE")
    fecha_importacion = Column(DateTime, default=datetime.utcnow)

    # Relacion
    pdt621 = relationship("PDT621", back_populates="compras_detalle")
