import sys

ruta = sys.argv[1]

resultTxt = sys.argv[2]

class Test:
    ALLOWED_SPA = ('Ficha de Cliente', 'Pangea')
    ALLOWED_ENT = ('PROD', 'ASEG', 'ENT1', 'ENT2')

    def __init__(self, spa: str, ent: str, front):
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
    def toString(self):
        return f"{self.spa} en entorno {self.ent}"


listTest = []

print("archivo recibido: ",  ruta)
#print("result recibido: ",  resultTxt)

contador = 0
for linea in resultTxt.splitlines():
    print(linea)
    spa_encontrado = None
    ent_encontrado = None
    for spa in Test.ALLOWED_SPA:
        if spa in linea:
            spa_encontrado = spa
            break
    for ent in Test.ALLOWED_ENT:
        if ent in linea:
            ent_encontrado = ent
            break
    
    if spa_encontrado and ent_encontrado:
        listTest.append(Test(spa_encontrado, ent_encontrado))
        contador += 1

    

print("Total de coincidencias ", str(contador))
print("La lista tiene un total de elementos de " + str(len(listTest)) + " tests")

for test in listTest:
    print(test.toString())

