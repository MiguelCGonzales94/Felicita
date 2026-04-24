"""
Servicio de consulta de RUC en SUNAT (mock por ahora).
"""
from typing import Optional
from pydantic import BaseModel


class FichaRUC(BaseModel):
    ruc: str
    razon_social: str
    estado: str
    condicion_domicilio: str
    direccion_fiscal: Optional[str] = None
    distrito: Optional[str] = None
    provincia: Optional[str] = None
    departamento: Optional[str] = None
    ubigeo: Optional[str] = None
    tipo_via: Optional[str] = None
    fuente: str = "MOCK"


_MOCK_DATA = {
    "20100070970": {
        "razon_social": "SAGA FALABELLA S.A.",
        "estado": "ACTIVO", "condicion_domicilio": "HABIDO",
        "direccion_fiscal": "AV. PASEO DE LA REPUBLICA NRO. 3220",
        "distrito": "San Isidro", "provincia": "Lima", "departamento": "Lima",
    },
    "20477314832": {
        "razon_social": "HIPERMERCADOS TOTTUS S.A.",
        "estado": "ACTIVO", "condicion_domicilio": "HABIDO",
        "direccion_fiscal": "AV. ANGAMOS ESTE NRO. 1805",
        "distrito": "Surquillo", "provincia": "Lima", "departamento": "Lima",
    },
    "20100047218": {
        "razon_social": "TELEFONICA DEL PERU S.A.A.",
        "estado": "ACTIVO", "condicion_domicilio": "HABIDO",
        "direccion_fiscal": "AV. ESCUELA MILITAR NRO. 798",
        "distrito": "Chorrillos", "provincia": "Lima", "departamento": "Lima",
    },
}


def consultar_ruc(ruc: str) -> Optional[FichaRUC]:
    if ruc in _MOCK_DATA:
        data = _MOCK_DATA[ruc]
        return FichaRUC(ruc=ruc, **data)
    return FichaRUC(
        ruc=ruc,
        razon_social=f"EMPRESA {ruc[-4:]} SAC",
        estado="ACTIVO", condicion_domicilio="HABIDO",
        direccion_fiscal="Direccion fiscal no disponible",
        distrito="Lima", provincia="Lima", departamento="Lima",
        fuente="GENERICO",
    )
