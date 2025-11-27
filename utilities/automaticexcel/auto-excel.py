import re
import sys
import os
from datetime import datetime

ruta = sys.argv[1]



resultTxt = sys.argv[2]

partes = ruta.split("/")

user = partes[2] 

nombre_archivo = os.path.basename(ruta)  

coincidencia = re.search(r"#(\d+)", nombre_archivo)
if coincidencia:
    execution = coincidencia.group(1)  # "1528"
else:
    execution = None

print("user:", user)
print("numero_ejecucion:", execution)


class Test:
    ALLOWED_SPA = ('Ficha de Cliente', 'Pangea')
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

    def convertObjectForExcelLines(listObjects):
        for test in listTest:
            if 'Ficha de Cliente' in test.spa:
                test.spa = 'FDC'

            if 'Pangea' in test.spa:
                test.spa = 'PDV'

            test.src = 'JOB'
            
            # Obtener la fecha actual
            fecha_actual = datetime.now()
            test.date = fecha_actual.strftime("%d/%m/%Y")

            test.job = execution

            test.step = '0'

            test.responsibleEntity = 'Application'

            test.user = convertUserWindowsInUserExcel(user)
            


    def toString(self):
        return f"test: {self.front} SPA: {self.spa}  entorno: {self.ent} SRC: {self.src} Date: {self.date} JOB: {self.job} Step: {self.step} Mensaje: {self.message} Rentity: {self.responsibleEntity} User: {self.user} "


listTest = []


contador = 0
for linea in resultTxt.splitlines():
    print(linea)
    spa_encontrado = None
    ent_encontrado = None
    front_code = None
    for spa in Test.ALLOWED_SPA:
        if spa in linea:
            spa_encontrado = spa
            break
    for ent in Test.ALLOWED_ENT:
        if ent in linea:
            ent_encontrado = ent
            break

    if 'FRONT' in linea:
        # Busca algo que empiece por FRONT y llegue hasta el primer punto
        match = re.search(r'(FRONT[^.]*)\.', linea)
        if match:
            front_code = match.group(1).strip()

    if 'Failed' in linea:
        match_failed = re.search(r'Failed:\s*(.+)', linea)
        if match_failed:
            message_failed = match_failed.group(1).strip()
            if listTest:
                listTest[-1].message = message_failed
        
    
    if spa_encontrado and ent_encontrado and front_code:
        listTest.append(Test(spa_encontrado, ent_encontrado, front_code, None , None , None , None , None , None, None))
        contador += 1
        
print("La lista tiene un total de elementos de " + str(len(listTest)) + " tests")

def convertUserWindowsInUserExcel(user):
    if 'cdelgadb' in user:
        return 'Carlos Delgado Benito'


Test.convertObjectForExcelLines(listTest)





for test in listTest:
    print(test.toString())

