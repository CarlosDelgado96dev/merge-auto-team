import re
import sys
import os
from datetime import datetime
from pathlib import Path

import pandas as pd
from openpyxl import load_workbook
from openpyxl.styles import Alignment


# =========================
# 1. DETECCIÓN USUARIO Y DOWNLOADS
# =========================

def detectar_usuario_windows() -> str:
    return os.environ.get("USERNAME") or os.environ.get("USER") or ""

def detectar_downloads() -> Path:
    user = detectar_usuario_windows()
    if not user:
        raise RuntimeError("No se pudo detectar el usuario Windows")

    posibles = [
        Path(f"C:/Users/{user}/Downloads"),
        Path(f"/mnt/c/Users/{user}/Downloads"),
        Path(f"/c/Users/{user}/Downloads"),
    ]

    for p in posibles:
        if p.is_dir():
            return p

    raise RuntimeError("No se encontró la carpeta Downloads")

def buscar_archivo_por_ejecucion(downloads: Path, ejecucion: str) -> Path:
    expected_name = f"#{ejecucion}.txt"
    # Listar últimos 50 archivos por fecha de modificación
    archivos = sorted(
        downloads.glob("*"),
        key=lambda p: p.stat().st_mtime,
        reverse=True
    )[:50]

    for f in archivos:
        if f.is_file() and f.name == expected_name:
            return f

    raise FileNotFoundError(
        f"No se encontró '{expected_name}' entre los últimos 50 archivos en {downloads}"
    )


# =========================
# 2. FUNCIÓN PARA MAPEAR USER + EXECUTION DESDE LA RUTA
# =========================

def convertUserAndExecution(ruta: str):
    """
    ruta: string tipo 'C:/Users/<user>/Downloads/#1348.txt' o similar
    """
    partes = ruta.replace("\\", "/").split("/")
    # Buscar índice de 'Users' y tomar el siguiente como usuario
    user = None
    if "Users" in partes:
        idx = partes.index("Users")
        if idx + 1 < len(partes):
            user = partes[idx + 1]
    if not user and len(partes) > 2:
        # fallback muy básico
        user = partes[2]

    nombre_archivo = os.path.basename(ruta)
    coincidencia = re.search(r"#(\d+)", nombre_archivo)
    execution = coincidencia.group(1) if coincidencia else None
    return user, execution


# =========================
# 3. LÓGICA DE NEGOCIO (TU CÓDIGO)
# =========================

class Test:
    ALLOWED_SPA = ('Ficha de Cliente', 'Pangea', 'Jazztel')
    ALLOWED_ENT = ('PROD', 'ASEG', 'ENT1', 'ENT2')

    def __init__(self, spa: str, ent: str, front, message, src, date, job, step, responsibleEntity, user):
        if spa not in self.ALLOWED_SPA:
            raise ValueError(
                f"Valor inválido para spa: {spa}. "
                f"Solo se permiten: {self.ALLOWED_SPA}"
            )
        if ent not in self.ALLOWED_ENT:
            raise ValueError(
                f"Valor inválido para ent: {ent}. "
                f"Solo se permiten: {self.ALLOWED_ENT}"
            )

        self.spa = spa
        self.ent = ent
        self.front = front
        self.message = message
        self.src = src
        self.date = date
        self.job = job
        self.step = step
        self.responsibleEntity = responsibleEntity
        self.user = user

    @staticmethod
    def convertObjectForExcelLines(listObjects, execution, user):
        for test in listObjects:
            if 'Ficha de Cliente' in test.spa:
                test.spa = 'FDC'

            if 'Pangea' in test.spa:
                test.spa = 'PDV'

            test.src = 'JOB'
            
            # Fecha actual
            fecha_actual = datetime.now()
            test.date = fecha_actual.strftime("%d/%m/%Y")

            test.job = execution
            test.step = '0'
            test.responsibleEntity = 'Application'
            test.user = userSystemToUserInExcel(user)

    def toString(self):
        return (
            f"test: {self.front} SPA: {self.spa}  entorno: {self.ent} "
            f"SRC: {self.src} Date: {self.date} JOB: {self.job} Step: {self.step} "
            f"Mensaje: {self.message} Rentity: {self.responsibleEntity} User: {self.user}"
        )


def sanitize_text(value):
    if value is None:
        return value
    return ''.join(
        ch for ch in value
        if ch in ("\t", "\n", "\r") or ord(ch) >= 32
    ).strip()

def tests_to_dataframe(tests):
    registros = []
    for test in tests:
        registros.append({
            "FRONT": sanitize_text(test.front),
            "SRC": sanitize_text(test.src),
            "SPA": sanitize_text(test.spa),
            "ENT": sanitize_text(test.ent),
            "DATE": sanitize_text(test.date),
            "JOB": sanitize_text(test.job),
            "JOBS": sanitize_text(test.job),
            "STEP": sanitize_text(test.step),
            "RESPONSIBLE": sanitize_text(test.responsibleEntity),
            "ERROR TYPE": "Element not rendered",
            "ALLURE MESSAGE": sanitize_text(test.message),
            "ANALYSIS": " ",
            "STATUS": "0.Define",
            "USUARIO": sanitize_text(test.user),
        })
    return pd.DataFrame(registros)

def userSystemToUserInExcel(user):
    if 'cdelgadb' in user:
        return 'Carlos Delgado Benito'
    if 'smonfort' in user:
        return 'Sergi Monfort Ferrer'
    if 'aclemens' in user:
        return 'Adrián Clement Sax'
    return user  # fallback: devolver el login si no está mapeado


# =========================
# 4. MAIN: UNE TODO
# =========================

def main():
    # 4.1 Pedir número de ejecución
    ejecucion = input("Introduce el número de ejecución (ej: 1348): ").strip()
    if not ejecucion.isdigit():
        print("Error: Debes introducir un número.", file=sys.stderr)
        sys.exit(1)

    # 4.2 Detectar Downloads
    try:
        downloads = detectar_downloads()
    except Exception as e:
        print(f"Error detectando Downloads: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Carpeta Downloads detectada: {downloads}")

    # 4.3 Buscar archivo #<ejecucion>.txt
    try:
        ruta_archivo = buscar_archivo_por_ejecucion(downloads, ejecucion)
    except Exception as e:
        print(e, file=sys.stderr)
        sys.exit(1)

    print(f"Archivo encontrado: {ruta_archivo}")

    # 4.4 Leer contenido del archivo
    with ruta_archivo.open('r', encoding='utf-8', errors='replace') as f:
        contenido = f.read()

    # 4.5 Obtener user y execution desde la ruta
    user, execution = convertUserAndExecution(str(ruta_archivo))
    if not user or not execution:
        print("No se pudo extraer user o execution desde la ruta del archivo.", file=sys.stderr)
        sys.exit(1)

    print("user:", user)
    print("numero_ejecucion:", execution)

    # 4.6 Parsear contenido y rellenar listTest
    listTest = []
    contador = 0

    for linea in contenido.splitlines():
        spa_encontrado = None
        ent_encontrado = None
        front_code = None

        # Buscar SPA
        for spa in Test.ALLOWED_SPA:
            if spa in linea:
                spa_encontrado = spa
                break

        # Buscar ENT
        for ent in Test.ALLOWED_ENT:
            if ent in linea:
                ent_encontrado = ent
                break

        # FRONT
        if 'FRONT' in linea:
            match = re.search(r'(FRONT[^.]*)\.', linea)
            if match:
                front_code = match.group(1).strip()

        # Mensaje de Failed
        if 'Failed' in linea:
            match_failed = re.search(r'Failed:\s*(.+?)(?:\s*\(Step\b|\s*$)', linea)
            if match_failed:
                message_failed = match_failed.group(1).strip()
                if listTest:
                    listTest[-1].message = message_failed

        if spa_encontrado and ent_encontrado and front_code:
            listTest.append(Test(spa_encontrado, ent_encontrado, front_code,
                                 None, None, None, None, None, None, None))
            contador += 1

    print("La lista tiene un total de elementos de " + str(len(listTest)) + " tests")

    # 4.7 Completar campos para Excel
    Test.convertObjectForExcelLines(listTest, execution, user)

    # 4.8 Pasar a DataFrame
    df = tests_to_dataframe(listTest)
    print(df)

    # 4.9 Ruta del Excel de salida
    ruta_excel = os.path.join(f"C:/Users/{user}/Downloads", f"resultados_#{execution}.xlsx")

    # 4.10 Guardar Excel
    df.to_excel(ruta_excel, index=False, engine="openpyxl")

    # 4.11 Formato (alineación)
    workbook = load_workbook(ruta_excel)
    sheet = workbook.active
    alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)

    for row in sheet.iter_rows(
        min_row=1,
        max_row=sheet.max_row,
        min_col=1,
        max_col=sheet.max_column,
    ):
        for cell in row:
            cell.alignment = alignment

    workbook.save(ruta_excel)
    print(f"Excel generado en: {ruta_excel}")


if __name__ == "__main__":
    main()
