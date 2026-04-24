import enum


class RolEnum(str, enum.Enum):
    ADMIN = "ADMIN"
    CONTADOR = "CONTADOR"
    ASISTENTE = "ASISTENTE"


class PlanEnum(str, enum.Enum):
    FREE = "FREE"
    STARTER = "STARTER"
    PROFESIONAL = "PROFESIONAL"
    ESTUDIO = "ESTUDIO"


class RegimenTributarioEnum(str, enum.Enum):
    RG = "RG"
    RMT = "RMT"
    RER = "RER"
    NRUS = "NRUS"


class EstadoSunatEnum(str, enum.Enum):
    ACTIVO = "ACTIVO"
    BAJA = "BAJA"
    SUSPENDIDO = "SUSPENDIDO"
    OBSERVADO = "OBSERVADO"


class CondicionDomicilioEnum(str, enum.Enum):
    HABIDO = "HABIDO"
    NO_HABIDO = "NO_HABIDO"
    NO_HALLADO = "NO_HALLADO"


class NivelAlertaEnum(str, enum.Enum):
    VERDE = "VERDE"
    AMARILLO = "AMARILLO"
    ROJO = "ROJO"


class EstadoPDTEnum(str, enum.Enum):
    DRAFT = "DRAFT"
    GENERATED = "GENERATED"
    SUBMITTED = "SUBMITTED"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"


class TipoEventoEnum(str, enum.Enum):
    PDT_621 = "PDT_621"
    PLAME = "PLAME"
    PDT_625 = "PDT_625"
    AFP = "AFP"
    ESSALUD = "ESSALUD"
    IMPUESTO_VEHICULAR = "IMPUESTO_VEHICULAR"
    PREDIAL = "PREDIAL"
    OTROS = "OTROS"


class EstadoEventoEnum(str, enum.Enum):
    PENDIENTE = "PENDIENTE"
    EN_PROCESO = "EN_PROCESO"
    COMPLETADO = "COMPLETADO"
    VENCIDO = "VENCIDO"


class FrecuenciaEnum(str, enum.Enum):
    MENSUAL = "MENSUAL"
    ANUAL = "ANUAL"
    UNICO = "UNICO"


class EstadoSuscripcionEnum(str, enum.Enum):
    ACTIVA = "ACTIVA"
    VENCIDA = "VENCIDA"
    CANCELADA = "CANCELADA"
    SUSPENDIDA = "SUSPENDIDA"


class MetodoPagoEnum(str, enum.Enum):
    TARJETA = "TARJETA"
    TRANSFERENCIA = "TRANSFERENCIA"
    PAYPAL = "PAYPAL"
    YAPE = "YAPE"
    PLIN = "PLIN"


class EstadoNotifEnum(str, enum.Enum):
    PENDING = "PENDING"
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    FAILED = "FAILED"


class NivelLogEnum(str, enum.Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"
