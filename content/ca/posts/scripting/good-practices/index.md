---
title: "Bones pràctiques i depuració"
date: 2026-04-05
lastmod: 2026-04-05
description: "PEP 8, gestió d'errors amb try/except, logging i eines d'anàlisi de codi"
summary: "PEP 8, gestió d'errors amb try/except, logging i eines d'anàlisi de codi"
categories: ["teaching"]
tags: ["python", "scripting"]
series: ["Scripting"]
series_order: 8
weight: 80
slug: bones-practiques
---

Escriure codi que funciona és només el primer pas. Escriure codi que sigui **llegible**, **mantenible** i **robust** és el que distingeix un script ràpid d'una eina professional. En aquest article veurem les convencions d'estil de Python, com gestionar errors de manera elegant i les eines que ens ajuden a escriure millor codi.

## Per què importen

Les bones pràctiques importen, i molt. Imaginem un escenari en el qual escrivim un script ràpidament. Aquest script funciona i el deixam. Sis mesos després hem de modificar-lo... i no entenem res del que vam escriure. Variables com `x`, `tmp` i `data2`, sense comentaris, funcions de 200 línies. Hem de reescriure'l de zero.

Les bones pràctiques no són burocràcia: són una inversió que rendeix quan tornam al codi després d'un temps, quan altres persones llegeixen el codi, quan hem de depurar un error o quan volem ampliar funcionalitats.

Per exemple, comparem les dues següents funcions:

```python
# Versió 1
def f(d):
    r=0
    for x in d:
        if x>0:r+=x
    return r

# Versió 2
def sumar_positius(nombres):
    """Retorna la suma dels nombres positius de la llista."""
    total = 0
    for nombre in nombres:
        if nombre > 0:
            total += nombre
    return total
```

Les dues funcions fan el mateix, però la segona és molt més fàcil d'entendre i modificar.

## L'estil de codi

El [PEP 8](https://peps.python.org/pep-0008/) és la guia d'estil oficial de Python. No és obligatòria, però és l'estàndard que segueix la comunitat. Un codi que segueix PEP 8 és immediatament familiar per a qualsevol programador de Python.

Revisem alguns dels aspectes més rellevants inclosos en aquesta [*](PEP).

**Indentació**

S'usen **4 espais** per nivell d'indentació. Mai tabuladors, mai 2 espais.

```python
def funcio():
    if condicio:
        fer_cosa()
```

**Longitud de línia**

Les línies no haurien de superar els **79 caràcters** (o 99-120 en projectes moderns). Si una línia és massa llarga, la dividim. Per exemple, donada la següent cridada a una funció amb assignació del resultat retornat a una variable:

```python
resultat = funcio_amb_nom_molt_llarg(argument1, argument2, argument3, argument4, argument5)
```

La podem dividir de la següent manera:

```python
resultat = funcio_amb_nom_molt_llarg(
    argument1,
    argument2,
    argument3,
    argument4,
    argument5
)
```

**Línies en blanc**

El nombre de línies en blanc entre funcions, mètodes i blocs lògics està definit:

- **Dues línies** en blanc entre funcions de nivell superior.
- **Una línia** en blanc entre mètodes dins una classe.
- Línies en blanc dins funcions per separar blocs lògics (amb moderació).

```python
def primera_funcio():
    pass


def segona_funcio():
    pass
```

**Imports**

Els imports van al principi del fitxer, agrupats en aquest ordre:

1. Biblioteca estàndard
2. Biblioteques de tercers
3. Mòduls locals

I cada grup va separat per una línia en blanc:

```python
import os
import sys
from datetime import datetime

import requests
import yaml

from utils import formatar_mida
from config import TIMEOUT
```

Evitam `from modul import *` perquè fa difícil saber d'on venen els noms.

**Noms**

La forma de noms de variables, funcions, constants i classes es la següent:

| Element   | Convenció            | Exemples                              |
|-----------|----------------------|---------------------------------------|
| Variables | snake_case           | `nom_usuari`, `total_bytes`           |
| Funcions  | snake_case           | `calcular_espai()`, `enviar_alerta()` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_INTENTS`, `PORT_DEFECTE`         |
| Classes   | PascalCase           | `ServidorWeb`, `GestorConnexions`     |
| Mòduls    | snake_case           | `utils.py`, `gestio_errors.py`        |

**Espais**

S'usen espais al voltant d'operadors d'assignació i comparació, però no dins parèntesis. Exemples:

```python
x = 5
y = x + 10
if x == 5:
    pass
llista = [1, 2, 3]
funcio(arg1, arg2)
```

**Comentaris**

Els comentaris expliquen el **per què**, no el **què** (el codi ja diu què fa). Exemple de mal comentari, car descriu el que és obvi:

```python
x = x + 1  # Incrementa x en 1
```

Exemple de bon comentari, car explica el motiu:

```python
x = x + 1  # Compensar el desplaçament del protocol (RFC 1234)
```

## Gestió d'errors

Els programes interactuen amb el món real: llegeixen fitxers que potser no existeixen, es connecten a servidors que potser no responen, processen dades que potser estan malformades. Una manera de gestionar aquestes situacions és a través de les excepcions.

Una excepció és un esdeveniment anòmal o inesperat que es produeix durant l'execució d'un programa i que interromp el seu flux normal d'instruccions, per exemple intentar dividir per zero, accedir a un índex fora de rang o obrir un fitxer que no existeix.

Les excepcions permeten separar el codi de gestió d'errors del codi lògic principal i es poden classificar com a específiques (per a un error concret) o generals (per a qualsevol error no capturat).

**L'estructura bàsica**

Usam les instruccions `try` i `except` per gestionar els errors (capturant excepcions):

```python
try:
    # Codi que pot fallar
    resultat = operacio_arriscada()
except TipusError:
    # Codi que s'executa si hi ha error
    gestionar_error()
```

Exemple:

```python
try:
    edat = int(input("Quina edat tens? "))
    print(f"L'any que ve tendràs {edat + 1} anys")
except ValueError:
    print("Error: has d'introduir un nombre enter")
```

**Capturar excepcions específiques**

És important capturar l'excepció **específica** que esperem, no totes. Per exemple, el següent codi captura totes les excepcions que es puguin produir:

```python
try:
    resultat = fer_operacio()
except:  # Captura qualsevol error, fins i tot Ctrl+C!
    print("Error")
```

El següent codi és una mica millor, però encara massa genèric:

```python
try:
    resultat = fer_operacio()
except Exception:
    print("Error")
```

El següent codi és correcte perquè especifica l'excepció que volem capturar:

```python
try:
    valor = int(cadena)
except ValueError:
    print("La cadena no és un nombre vàlid")
```

**Capturar múltiples excepcions**

És possible capturar més d'un tipus d'excepció. El següent exemple captura els errors de fitxer i de conversió i en fa un tractament individualitzat:

```python
try:
    with open(fitxer) as f:
        dades = f.read()
    valor = int(dades)

except FileNotFoundError:
    print(f"El fitxer {fitxer} no existeix")
except PermissionError:
    print(f"No tens permisos per llegir {fitxer}")
except ValueError:
    print("El contingut del fitxer no és un nombre vàlid")
```

Però també podem agrupar excepcions similars i donar-les el mateix tractament:

```python
try:
    valor = int(cadena)
except (ValueError, TypeError) as e:
    print(f"Error de conversió: {e}")
```

**Les clàusules else i finally**

A més de les instruccions `try` i `except`, tenim al nostre abast dues instruccions addicionals per a la correcta gestió d'errors:

- `else`: s'executa només si **no** hi ha hagut cap excepció.
- `finally`: s'executa **sempre**, hi hagi hagut error o no.

Exemple:

```python
try:
    fitxer = open("config.txt")

except FileNotFoundError:
    print("Fitxer no trobat")

else:
    # Només s'executa si no hi ha hagut error
    contingut = fitxer.read()
    fitxer.close()

finally:
    # Sempre s'executa (neteja)
    print("Operació finalitzada")
```

**Accedir a la informació de l'error**

Podem accedir a l'objecte excepció, el qual conté tota la informació de l'error, amb `as`:

```python
try:
    resultat = 10 / 0
    
except ZeroDivisionError as e:
    print(f"Error: {e}")  # Error: division by zero
```

## Quan usar excepcions

Aquesta és una de les decisions més importants en el disseny de codi. Python té dues filosofies:

- **LBYL** (Look Before You Leap): comprova les condicions abans d'actuar.
- **EAFP** (Easier to Ask Forgiveness than Permission): intenta l'operació i gestiona l'error si passa.

Python, per disseny, afavoreix **EAFP**, però això no vol dir que sempre haguem d'usar excepcions.

### Quan sí usar-les

Casos d'ús on ens convé usar excepcions:

1. Errors externs i imprevisibles, és a dir, situacions que no podem controlar. Per exemple, fitxers, xarxa o entrada d'usuari.

   ```python
   # No podem garantir que el fitxer existeixi
   try:
       with open(ruta) as f:
           dades = f.read()
   except FileNotFoundError:
       dades = configuracio_per_defecte()
   ```

2. Quan la comprovació prèvia és costosa o té race conditions. Si comprovam i després actuam, la situació pot canviar entre la comprovació i l'acció.

   ```python
   # Verificam que el fitxer existeix abans d'obrir-lo.
   # Però el fitxer pot desaparèixer entre exists() i open()
   if os.path.exists(ruta):
       with open(ruta) as f:  # Pot fallar!
           dades = f.read()
   
   # Amb excepcions
   try:
       with open(ruta) as f:
           dades = f.read()
   except FileNotFoundError:
       dades = None
   ```

3. Quan l'error és realment excepcional. Si la situació d'error és rara i el cas normal és l'èxit, les excepcions són adequades.

   ```python
   # L'usuari normalment introdueix dades correctes
   try:
       port = int(input("Port: "))
   except ValueError:
       print("Port no vàlid")
   ```

### Quan no usar-les

Casos d'ús on ens convé no usar excepcions:

1. Per controlar el flux normal del programa. Les excepcions no haurien de ser un substitut d'instruccions com `if` o `else`.

   ```python
   # Usar excepcions per al control de flux no és correcte
   def obtenir_valor(dicc, clau):
       try:
           return dicc[clau]
       except KeyError:
           return None
   
   # Usar el mètode adequat és la solució correcta
   def obtenir_valor(dicc, clau):
       return dicc.get(clau)  # Retorna None si no existeix
   ```

2. Quan la comprovació prèvia és trivial i no hi ha race conditions. Si podem comprovar fàcilment, sovint és més clar fer-ho.

   ```python
   # Comprovació trivial
   def dividir(a, b):
       if b == 0:
           return None
       return a / b
   
   # No és tan clar usar excepcions per un cas fàcil de preveure
   def dividir(a, b):
       try:
           return a / b
       except ZeroDivisionError:
           return None
   ```

3. Per validar dades d'entrada conegudes. Si controlam les dades, validem-les explícitament.

   ```python
   # Validar paràmetres de funció
   def processar_port(port):
       if not isinstance(port, int):
           raise TypeError("El port ha de ser un enter")
       if not 1 <= port <= 65535:
           raise ValueError(f"Port fora de rang: {port}")
       
       ...  # Processam el port
   ```

### Codis vs excepcions

És més convenient retornar **codis d'error**, e.g., retornar `None`, `False`, tuples `(ok, resultat)`, etc.:

- Quan l'error és un resultat esperat i freqüent.
- Quan la funció ja retorna un valor que pot indicar error naturalment.
- En funcions molt simples on l'excepció seria excessiva.

Exemple:

```python
def cercar_usuari(nom):
    """Retorna l'usuari o None si no existeix."""
    return usuaris.get(nom)  # None és un resultat vàlid i esperat

usuari = cercar_usuari("anna")
if usuari is None:
    print("Usuari no trobat")
```

En canvi, és més convenient llançar **excepcions** en els següents casos:

- Quan l'error és realment excepcional.
- Quan no volem que l'error passi desapercebut.
- Quan hi ha múltiples tipus d'error a distingir.
- Quan l'error pot ocórrer en crides niuades i volem propagar-lo.

Exemple:

```python
def connectar_servidor(host, port):
    """
    Connecta al servidor.
    
    :raises ConnectionError: Si no es pot connectar.
    :raises TimeoutError: Si la connexió supera el timeout.
    """
    # Si falla, és un problema real que cal gestionar
    pass
```

### Documentació

Sigui quina sigui l'aproximació, documentar el comportament és sempre convenient i necessari. Exemple:

```python
def cercar_element(llista, valor):
    """
    Cerca un element a la llista.
    
    :param llista: Llista on cercar.
    :param valor: Valor a cercar.
    :return: Índex de l'element o -1 si no es troba.
    """
    # Retornem -1 com a convenció (similar a str.find())
    try:
        return llista.index(valor)
    except ValueError:
        return -1
```

## Excepcions comunes

Quan el nostre codi falla, Python llança una excepció amb un nom que indica el tipus de problema. Aquestes són les més habituals:

| Excepció            | Causa              | Exemple                  |
|---------------------|--------------------|--------------------------|
| `ValueError`        | Valor incorrecte   | `int("abc")`             |
| `TypeError`         | Tipus incorrecte   | `"hola" + 5`             |
| `KeyError`          | Clau no trobada    | `dicc["inexistent"]`     |
| `IndexError`        | Índex fora de rang | `llista[100]`            |
| `FileNotFoundError` | Fitxer no trobat   | `open("inexistent.txt")` |
| `PermissionError`   | Sense permisos     | `open("/etc/shadow")`    |
| `ZeroDivisionError` | Divisió per zero   | `10 / 0`                 |
| `AttributeError`    | Atribut inexistent | `None.metode()`          |
| `ImportError`       | Mòdul no trobat    | `import inexistent`      |

**Llegir els tracebacks**

Quan Python llança una excepció no capturada, mostra una traça, o *traceback*, que conté la pila de crides que han duit a l'error. Exemple breu de traça (normalment són més llargues):

```python
Traceback (most recent call last):
  File "script.py", line 15, in <module>
    resultat = processar_dades(dades)
  File "script.py", line 8, in processar_dades
    valor = int(element)
ValueError: invalid literal for int() with base 10: 'abc'
```

La llegim de baix a dalt:

1. **Última línia:** el tipus d'error i el missatge.
2. **Línies anteriors:** la cadena de crides, de la més recent a la més antiga.
3. **Primera línia amb "File":** on s'ha originat l'error.

## Registre d'esdeveniments

La funció `print()` és útil per depurar, però no és adequat per a logs permanents. El mòdul `logging` ofereix un sistema més sofisticat per a enregistrar informació sobre els esdeveniments de l'aplicació.

Per poder classificar els missatges que vulguem registrar, el mòdul `logging` ofereix nivells de prioritat:

| Nivell     | Valor | Ús                                      |
|------------|-------|-----------------------------------------|
| `DEBUG`    | 10    | Informació detallada per depurar        |
| `INFO`     | 20    | Confirmació que les coses funcionen     |
| `WARNING`  | 30    | Alguna cosa inesperada o problema futur |
| `ERROR`    | 40    | Error que impedeix una funcionalitat    |
| `CRITICAL` | 50    | Error greu que pot aturar el programa   |


Quan inicialitzam el registre d'esdeveniments, podem configurar el nivell de prioritat per defecte (habitualment `INFO`). Això vol dir que qualsevol missatge amb un nivell inferior a l'actual no es mostra. Exemple:

```python
import logging

# Configuració bàsica
logging.basicConfig(level=logging.INFO)

# Usar el logger
logging.debug("Missatge de depuració")    # No es mostra (nivell massa baix)
logging.info("Informació general")        # Es mostra
logging.warning("Alguna cosa sospitosa")  # Es mostra
logging.error("Ha ocorregut un error")    # Es mostra
logging.critical("Error crític!")         # Es mostra
```

És a dir, si volem enregistrar també els missatges del nivell `DEBUG`, habitualment al nostre entorn de desenvolupament, configurarem el registre amb `level=logging.DEBUG`.

**Configuració amb format**

El mòdul `logging` també permet configurar el format de cada missatge a través de l'opció `format`. Per exemple, podem incloure i definir el format de data i hora per a la consola. Exemple:

```python
import logging

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

logging.info("Servidor iniciat")
logging.warning("Espai en disc baix")
```

Sortida:

```
2026-04-11 10:30:45 [INFO] Servidor iniciat
2026-04-11 10:30:45 [WARNING] Espai en disc baix
```

La secció [LogRecord attributes](https://docs.python.org/3/library/logging.html#logrecord-attributes) de la documentació oficial enumera tots els camps disponibles per personalitzar el format dels missatges de registre. Alguns dels més comuns són:

- `%(asctime)s`: Data i hora llegible del registre.
- `%(levelname)s`: Nivell del missatge (`DEBUG`, `INFO`, `WARNING`, etc.).
- `%(message)s`: El missatge de registre propiament dit.
- `%(name)s`: Nom del logger.
- `%(filename)s`: Nom del fitxer des d’on s’ha fet el registre.
- `%(funcName)s`: Nom de la funció des d’on s’ha cridat el registre.
- `%(lineno)d`: Número de línia del codi. 

**Escriure logs a fitxer**

Fins ara hem enregistrat missatges per pantalla, amb un format al nostre gust. Si volem mantenir la informació al llarg del temps, haurem d'escriurer-la a un fitxer. Per això usarem l'opció `handlers`. Exemple:

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("aplicacio.log"),
        logging.StreamHandler()  # També a pantalla
    ]
)

logging.info("Aquesta línia va al fitxer i a la pantalla")
```

**Exemple pràctic**

Vegem una configuració completa del `logging` amb un exemple pràctic:

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)

logger = logging.getLogger("monitor")

def comprovar_espai(llindar=80):
    logger.debug("Iniciant comprovació d'espai")
    
    # Simulam obtenir l'ús
    us_actual = 85
    
    logger.info(f"Ús de disc actual: {us_actual}%")
    
    if us_actual > llindar:
        logger.warning(f"Ús de disc supera el llindar ({llindar}%)")
        return False
    
    logger.debug("Comprovació completada sense alertes")
    return True

comprovar_espai()
```

## Tècniques de depuració

Quan el codi no fa el que esperam hem de depurar-lo. Hi ha diverses formes de fer-ho:

### Ús de `print()`

La tècnica més bàsica és afegir instruccions `print()` al codi per veure valors intermedis. Exemple:

```python
def processar(dades):
    print(f"DEBUG: dades rebudes = {dades}")  # Temporal

    resultat = transformar(dades)

    print(f"DEBUG: després de transformar = {resultat}")  # Temporal
    
    return resultat
```

> No t'oblidis d'eliminar els `print()` de depuració quan hagis acabat o, millor encara, usa `logging.debug()`, que pots desactivar.

### Assertions

La instrucció `assert` comprova que una condició sigui certa. Si no ho és, llança una excepció de tipus `AssertionError`. Exemple:

```python
def calcular_mitjana(llista):
    assert len(llista) > 0, "La llista no pot ser buida"
    return sum(llista) / len(llista)

calcular_mitjana([])  # AssertionError: La llista no pot ser buida
```

Usam `assert` per:

- Verificar precondicions de funcions.
- Comprovar invariants durant el desenvolupament.
- Documentar assumpcions del codi.

> Les *assertions* es poden desactivar amb `python -O`, així que no les useu per validar entrada d'usuaris o dades externes.

### El depurador integrat

Python inclou un depurador integrat anomenat `pdb` que permet executar el codi línia per línia i inspeccionar variables. Hi ha dues maneres d'usar-lo:

**Opció 1: Inserir un breakpoint al codi**

```python
def funcio_problematica(x):
    breakpoint()  # El programa s'atura aquí
    resultat = x * 2
    return resultat + 1

funcio_problematica(5)
```

Executam l'script normalment:

```bash
python3 script.py
```

El programa s'aturarà al `breakpoint()` i veurem el prompt del depurador:

```bash
> /home/usuari/script.py(3)funcio_problematica()
-> resultat = x * 2
(Pdb)
```

**Opció 2: Executar l'script amb el depurador**

Podem executar qualsevol script sota el control de `pdb` sense modificar el codi:

```bash
python3 -m pdb script.py
```

L'script s'aturarà a la primera línia i podrem avançar pas a pas.

La següent taula presente les comandes bàsiques del depurador:

| Comanda        | Descripció                                    |
|----------------|-----------------------------------------------|
| `n` (next)     | Executar la línia següent                     |
| `s` (step)     | Entrar dins una funció                        |
| `c` (continue) | Continuar fins al proper breakpoint           |
| `p variable`   | Imprimir el valor d'una variable              |
| `l` (list)     | Mostrar el codi al voltant de la línia actual |
| `q` (quit)     | Sortir del depurador                          |

### Divide et impera

El procés de depuració té una part d'enginyeria però també una part d'intuició i experiència. Quan tenim un error difícil de trobar, podem seguir els seguents consells:

1. Aïlla el codi, és a dir, reduir el problema al mínim codi que el reprodueix.
2. Divideix el codi. Si el codi és llarg, comenta'n la meitat i mira si l'error persisteix.
3. Afegeix assumpcions per comprovar que les variables tenen els valors esperats.
4. Llegeix les traces, sovint indiquen exactament on és el problema.

## Eines d'anàlisi de codi

Els **linters** són eines que analitzen el codi sense executar-lo i detecten problemes d'estil, errors potencials i males pràctiques. Per a Python, els dos *linters* més populars són Ruff i Pylint.

### Ruff

[Ruff](https://github.com/astral-sh/ruff) és un linter modern i extremadament ràpid. Podem trobar les instruccions d'instal·lació per a diverses plataformes a [la seva documentació](https://docs.astral.sh/ruff/installation/). Una vegada instal·lat, podem analitzar el codi amb:

```bash
ruff check script.py
```

I també podem demanar-li que corregeixi els problemes automàticament:

```bash
ruff check --fix script.py
```

Exemple de sortida:

```
script.py:3:1: F401 `os` imported but unused
script.py:10:5: E722 Do not use bare `except`
script.py:15:1: W293 blank line contains whitespace
Found 3 errors.
```

### Pylint

[Pylint](https://pylint.org/) és més exhaustiu i configurable. Podem trobar les instruccions d'instal·lació per a diverses plataformes a [la seva documentació](https://docs.pylint.org/installation.html). Una vegada instal·lat, podem analitzar el codi amb:

```bash
pylint script.py
```

Pylint dona una puntuació sobre 10 i suggeriments detallats.

### Integració amb editors

VS Code, VS Codium i altres editors poden executar linters automàticament mentre escrivim, mostrant els problemes en temps real. Això és molt més eficient que executar-los manualment. Exemple de fitxer `.vscode/extensions.json` del nostre directori d'scripts:

```json
{
    "recommendations": [
        "ms-python.python",
        "charliermarsh.ruff"
    ]
}
```

## Estructura d'un script

Un script ben organitzat segueix una estructura consistent:

```python
#!/usr/bin/env python3
"""
Descripció breu del que fa l'script.

Descripció més detallada si cal, explicant el context,
l'ús previst i qualsevol informació rellevant.

:Author: El teu nom
:Date: 2026-04-11
"""

#### Imports

# Biblioteca estàndard
import logging
import sys
from datetime import datetime
from pathlib import Path

# Tercers (si n'hi ha)
# import requests

# Locals (si n'hi ha)
# from utils import formatar_mida


#### Constants

MAX_INTENTS = 3
TIMEOUT_SEGONS = 30
FITXER_LOG = Path("/var/log/script.log")


#### Configuració de mòduls, e.g., `logging`

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

logger = logging.getLogger(__name__)


#### Funcions

def funcio_auxiliar():
    """Fa alguna cosa auxiliar."""
    pass


def funcio_principal():
    """
    Executa la lògica principal de l'script.
    
    :return: Codi de sortida (0 = èxit, 1 = error).
    """
    logger.info("Iniciant execució")
    
    try:
        # Lògica principal
        pass
        logger.info("Execució completada correctament")
        return 0
    except Exception as e:
        logger.error(f"Error durant l'execució: {e}")
        return 1


#### Punt d'entrada

if __name__ == "__main__":
    sys.exit(funcio_principal())
```

### El punt d'entrada

El punt d'entrada d'un script es el bloc `if __name__ == "__main__":`. Aquest bloc s'executa **només** quan executam el fitxer directament, no quan l'importam com a mòdul. Per exemple, suposem que cream un mòdul o llibreria `utils.py` com el següent:

```python
# utils.py
def formatar(x):
    return f"Valor: {x}"

if __name__ == "__main__":
    # Proves o execució directa
    print(formatar(42))
```

Llavors, en un script nou, e.g, `script.py`, l'importam perquè volem fer ús d'alguna funció. En aquest context, el bloc `__main__` d'`utils.py` no s'executa:

```python
# script.py
from utils import formatar  

print(formatar(10))
```

Això permet que un fitxer sigui alhora un mòdul importable i un script executable.

## Exercicis

Es proposen tres exercicis pràctics per consolidar els conceptes d'aquest article.

### Exercici 1

**Refactoritzar codi**

Objectiu: Millorar un script amb mal estil seguint les bones pràctiques.

A continuació tens un script funcional però amb molts problemes d'estil. Refactoritza'l seguint PEP 8, afegint *docstrings* i millorant els noms.

```python
def f(l):
    t=0
    for x in l:
        if x>0:t=t+x
    return t
def calc(d,u):
 p=(u/d)*100
 if p>80:return "ALERTA"
 elif p>60:return "WARNING"
 else:return "OK"
import os
data=[10,-5,20,-3,15]
r=f(data)
print(r)
disk=500
used=420
print(calc(disk,used))
```

> Pista: separa imports, afegeix espais, usa noms descriptius, afegeix *docstrings*.

{{< details summary="Resposta" >}}

Script refactoritzat:

```python
#!/usr/bin/env python3
"""
Script d'exemple refactoritzat.

Demostra bones pràctiques de Python: noms descriptius,
docstrings, format PEP 8 i estructura clara.
"""

# No necessitam os en aquest exemple, l'eliminam


def sumar_positius(nombres):
    """
    Retorna la suma dels nombres positius d'una llista.
    
    :param nombres: Llista de nombres.
    :return: Suma dels nombres positius.
    """
    total = 0
    for nombre in nombres:
        if nombre > 0:
            total += nombre
    return total


def calcular_nivell_alerta(espai_total, espai_usat):
    """
    Determina el nivell d'alerta segons l'ús de disc.
    
    :param espai_total: Espai total del disc.
    :param espai_usat: Espai usat.
    :return: Cadena amb el nivell ('OK', 'WARNING' o 'ALERTA').
    """
    if espai_total == 0:
        return "ERROR"
    
    percentatge = (espai_usat / espai_total) * 100
    
    if percentatge > 80:
        return "ALERTA"
    elif percentatge > 60:
        return "WARNING"
    else:
        return "OK"


if __name__ == "__main__":
    # Exemple d'ús
    dades = [10, -5, 20, -3, 15]
    suma = sumar_positius(dades)
    print(f"Suma de positius: {suma}")
    
    espai_disc = 500
    espai_usat = 420
    nivell = calcular_nivell_alerta(espai_disc, espai_usat)
    print(f"Nivell d'alerta: {nivell}")
```

Canvis realitzats:

- Import `os` eliminat (no s'usava).
- Noms de funcions i variables descriptius.
- Docstrings afegits.
- Indentació correcta (4 espais).
- Espais al voltant d'operadors.
- Línies en blanc entre funcions.
- Bloc `if __name__ == "__main__":` afegit.
- Gestió de divisió per zero afegida.

{{< /details >}}

### Exercici 2

**Gestió d'errors robusta**

Objectiu: Crear un script que llegeixi una configuració d'un fitxer amb gestió completa d'errors.

1. Crea un script anomenat `llegir_config.py`.
2. L'script ha de llegir un fitxer `config.txt` amb format `clau=valor`, descartant comentaris amb `#`. Exemples de claus a incloure són `host`, `port`, `timeout` i `debug`. Inclou algunes línies amb errors de format.
3. Gestiona tots els errors possibles: fitxer no trobat, permisos, format incorrecte.
4. Usa el mòdul `logging` per enregistrar els errors.
5. Retorna un diccionari amb la configuració o valors per defecte si hi ha error.

> Pista: cada línia pot tenir errors de format diferents.

{{< details summary="Resposta" >}}

Exemple d'script `llegir_config.py`:

```python
#!/usr/bin/env python3
"""
Llegeix configuració d'un fitxer amb gestió robusta d'errors.

Format del fitxer: línies amb 'clau=valor'.
Es descarten comentaris amb #.
"""

import logging
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(__name__)

# Configuració per defecte
CONFIG_DEFECTE = {
    "host": "localhost",
    "port": "8080",
    "timeout": "30",
    "debug": "false",
}


def llegir_configuracio(ruta_fitxer):
    """
    Llegeix configuració d'un fitxer.

    :param ruta_fitxer: Ruta al fitxer de configuració.
    :return: Diccionari amb la configuració.
    """
    ruta = Path(ruta_fitxer)
    config = CONFIG_DEFECTE.copy()
    
    # Intentar llegir el fitxer
    try:
        with open(ruta, "r", encoding="utf-8") as f:
            linies = f.readlines()
    except FileNotFoundError:
        logger.warning(f"Fitxer {ruta} no trobat, usant configuració per defecte")
        return config
    except PermissionError:
        logger.error(f"Sense permisos per llegir {ruta}")
        return config
    except Exception as e:
        logger.error(f"Error inesperat llegint {ruta}: {e}")
        return config
    
    logger.info(f"Llegint configuració de {ruta}")
    
    # Processar línies
    for num_linia, linia in enumerate(linies, start=1):
        linia = linia.strip()
        
        # Ignorar línies buides i comentaris
        if not linia or linia.startswith("#"):
            continue
        
        # Validar format
        if "=" not in linia:
            logger.warning(f"Línia {num_linia}: format incorrecte (falta '=')")
            continue
        
        # Separar clau i valor
        try:
            clau, valor = linia.split("=", 1)
            clau = clau.strip()
            valor = valor.strip()
            
            if not clau:
                logger.warning(f"Línia {num_linia}: clau buida")
                continue
            
            config[clau] = valor
            logger.debug(f"Configurat: {clau} = {valor}")
            
        except ValueError as e:
            logger.warning(f"Línia {num_linia}: error processant - {e}")
            continue
    
    logger.info(f"Configuració carregada: {len(config)} paràmetres")
    return config


def mostrar_configuracio(config):
    """Mostra la configuració de manera formatada."""
    print("\n=== Configuració actual ===")
    for clau, valor in sorted(config.items()):
        print(f"  {clau}: {valor}")
    print()


if __name__ == "__main__":
    # Provar amb un fitxer que potser no existeix
    configuracio = llegir_configuracio("config.txt")
    mostrar_configuracio(configuracio)
```

Exemple de fitxer `config.txt`:

```
# Configuració del servidor
host=192.168.1.100
port=8443

# Opcions de connexió
timeout=60
debug=true

# Línia amb error
format_incorrecte

# Altra línia vàlida
max_connexions=100
```

{{< /details >}}

### Exercici 3

**Analitzador de logs de servidor web**

Objectiu: Crear un script professional que analitzi un fitxer de logs i n'extregui estadístiques.

**Context**

L'equip d'operacions ens ha passat un fitxer de logs on s'han agregat les sortides de diversos serveis d'un servidor. Això ha passat perquè tots els serveis escrivien al mateix destí de `journald` durant una sessió de depuració. Ara ens demanen que n'extraguem estadístiques per analitzar el comportament del sistema.

**Fitxer de logs proporcionat**

Es proporciona {{< icon "download" >}} [el fitxer a analitzar](/downloads/scripting/good-practices/servidor.log). Exemple del fitxer per a veure el format de cada línia:

```log
2026-04-11 10:15:32 [INFO] nginx: GET /api/users 200 45ms
2026-04-11 10:15:33 [DEBUG] postgres: SELECT executed in 12ms
2026-04-11 10:15:34 [INFO] postgres: INSERT executed in 8ms
2026-04-11 10:15:35 [WARNING] nginx: Slow response for /api/reports 1250ms
2026-04-11 10:15:36 [INFO] nginx: GET /health 200 3ms
2026-04-11 10:15:40 [ERROR] postgres: Connection timeout after 30000ms
```

Els camps són: data, hora, nivell, procés i missatge.

**Estadístiques a extreure**

L'script ha de mostrar:

1. **Resum general:**
   - Total de línies processades
   - Distribució per nivell (INFO, WARNING, ERROR, DEBUG) amb percentatges

2. **Estadístiques per procés:**
   - Nombre de línies per procés (nginx, postgres, redis, cron)

3. **Anàlisi de peticions HTTP (nginx):**
   - Total de peticions
   - Distribució per codi de resposta (200, 404, 500)
   - Endpoint més sol·licitat
   - Temps mitjà de resposta (en ms)
   - Peticions lentes (> 500ms)

4. **Anàlisi de queries SQL (postgres):**
   - Total de queries
   - Distribució per tipus (SELECT, INSERT, UPDATE, DELETE)
   - Temps mitjà d'execució (en ms)
   - Queries lentes (> 100ms)

5. **Anàlisi de cache (redis):**
   - Total d'accessos a cache
   - Hit/miss ratio

6. **Alertes:**
   - Llistat de totes les línies amb nivell ERROR

**Requisits tècnics**

L'script s'ha de dir `analitzador.py` ha d'obrir i processar el fitxer de log, mostrar les estadístiques i ha de seguir totes les bones pràctiques:

- Estructura professional: shebang, docstring de mòdul, imports ordenats, constants, funcions i bloc d'entrada.
- Funcions ben documentades amb docstrings.
- Gestió d'errors: fitxer no trobat, línia amb format incorrecte.
- Logging per informar del progrés de l'anàlisi.
- Codi seguint PEP 8.

> Pista: pots usar expressions regulars (`import re`) per parsejar les línies, o bé mètodes de cadenes com `split()`. El mòdul `collections.Counter` és útil per comptar ocurrències.
