"""
Validador de RUC peruano.
Algoritmo oficial SUNAT.
"""
import re


def validar_formato_ruc(ruc: str) -> bool:
    if not ruc:
        return False
    return bool(re.match(r"^\d{11}$", ruc))


def validar_digito_verificador_ruc(ruc: str) -> bool:
    if not validar_formato_ruc(ruc):
        return False
    factores = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]
    suma = sum(int(ruc[i]) * factores[i] for i in range(10))
    resto = suma % 11
    digito_esperado = 11 - resto
    if digito_esperado == 10:
        digito_esperado = 0
    elif digito_esperado == 11:
        digito_esperado = 1
    return int(ruc[10]) == digito_esperado


def validar_tipo_ruc(ruc: str) -> str:
    if not validar_formato_ruc(ruc):
        return "INVALIDO"
    prefijo = ruc[:2]
    tipos = {
        "10": "PERSONA_NATURAL",
        "15": "PERSONA_NATURAL_NO_DOMICILIADA",
        "17": "PERSONA_NATURAL_EXTRANJERA",
        "20": "PERSONA_JURIDICA",
    }
    return tipos.get(prefijo, "OTRO")


def validar_ruc_completo(ruc: str) -> dict:
    resultado = {
        "ruc": ruc, "formato_valido": False,
        "digito_verificador_valido": False,
        "tipo": "INVALIDO", "es_valido": False, "mensaje": "",
    }
    if not validar_formato_ruc(ruc):
        resultado["mensaje"] = "El RUC debe tener exactamente 11 digitos numericos"
        return resultado
    resultado["formato_valido"] = True
    resultado["tipo"] = validar_tipo_ruc(ruc)
    if resultado["tipo"] == "OTRO":
        resultado["mensaje"] = "El RUC debe empezar con 10, 15, 17 o 20"
        return resultado
    if not validar_digito_verificador_ruc(ruc):
        resultado["mensaje"] = "El digito verificador del RUC es incorrecto"
        return resultado
    resultado["digito_verificador_valido"] = True
    resultado["es_valido"] = True
    resultado["mensaje"] = "RUC valido"
    return resultado
