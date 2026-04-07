---
title: "Expressions i operadors"
date: 2026-04-05
lastmod: 2026-04-05
description: "Operadors aritmètics, de comparació, lògics i de pertinença amb Python"
summary: "Operadors aritmètics, de comparació, lògics i de pertinença amb Python"
categories: ["teaching"]
tags: ["python", "scripting"]
series: ["Scripting"]
series_order: 4
weight: 40
slug: expressions-operadors
---

Ara que coneixem les variables i les col·leccions, és hora d'aprendre a fer operacions amb elles. En aquest article veurem els **operadors** de Python: les eines que ens permeten fer càlculs, comparar valors i combinar condicions.

## Expressions i instruccions

Abans d'entrar en matèria, és útil distingir entre dos conceptes fonamentals:

- Una **instrucció** és una ordre que Python executa, com assignar un valor o mostrar un missatge.
- Una **expressió** és qualsevol combinació de valors, variables i operadors que Python pot avaluar per obtenir un resultat.

Vegem alguns exemples d'instruccions (executen una acció):

```python
x = 10                     # assignació
print("Hola")              # mostrar per pantalla
servidors.append("web03")  # modificar una llista
```

Vegem alguns exemples d'expressions (produeixen un valor)

```python
2 + 3        # 5
x * 2        # el doble de x
len("hola")  # 4
port > 1024  # True o False
```

Una expressió pot formar part d'una instrucció. Per exemple, en `x = 2 + 3`, la part `2 + 3` és una expressió que s'avalua a `5`, i tota la línia és una instrucció d'assignació.

## Operadors aritmètics

Els operadors aritmètics ens permeten fer càlculs matemàtics. Ja n'hem vist alguns, però ara els veurem tots amb detall.

| Operador | Operació       | Exemple   | Resultat |
|----------|----------------|-----------|----------|
| `+`      | Suma           | `10 + 3`  | `13`     |
| `-`      | Resta          | `10 - 3`  | `7`      |
| `*`      | Multiplicació  | `10 * 3`  | `30`     |
| `/`      | Divisió        | `10 / 3`  | `3.3...` |
| `//`     | Divisió entera | `10 // 3` | `3`      |
| `%`      | Mòdul (residu) | `10 % 3`  | `1`      |
| `**`     | Potència       | `2 ** 10` | `1024`   |

La divisió amb `/` sempre retorna un `float`, fins i tot si el resultat és exacte:

```python
>>> 10 / 2
5.0
>>> 10 / 3
3.3333333333333335
```

La divisió entera amb `//` retorna només la part entera del resultat, descartant els decimals:

```python
>>> 10 // 3
3
>>> 17 // 5
3
>>> -10 // 3
-4  # Arrodoneix cap a l'infinit negatiu
```

L'operador mòdul `%` retorna el residu de la divisió:

```python
>>> 10 % 3
1  # 10 = 3*3 + 1
>>> 17 % 5
2  # 17 = 5*3 + 2
>>> 20 % 5
0  # 20 és divisible per 5
```

Aquest operador és molt útil per:

- Comprovar si un nombre és parell o senar: `n % 2 == 0` (parell) o `n % 2 == 1` (senar).
- Fer operacions cícliques: `index % len(llista)` per tornar al principi.
- Validar múltiples: `segons % 60` per obtenir els segons dins un minut.

**Exemple pràctic**

Convertir segons a hores, minuts i segons:

```python
total_segons = 3725

hores = total_segons // 3600
minuts = (total_segons % 3600) // 60
segons = total_segons % 60

print(f"{hores}h {minuts}m {segons}s")  # 1h 2m 5s
```

**Exemple pràctic**

Convertir bytes a unitats més llegibles:

```python
bytes_totals = 5368709120  # 5 GB en bytes

kilobytes = bytes_totals / 1024
megabytes = bytes_totals / (1024 ** 2)
gigabytes = bytes_totals / (1024 ** 3)

print(f"Bytes:     {bytes_totals}")
print(f"Kilobytes: {kilobytes:.2f}")
print(f"Megabytes: {megabytes:.2f}")
print(f"Gigabytes: {gigabytes:.2f}")
```

Això produirà la següent sortida:

```
Bytes:     5368709120
Kilobytes: 5242880.00
Megabytes: 5120.00
Gigabytes: 5.00
```

## Operadors de comparació

Els operadors de comparació comparen dos valors i retornen un booleà (`True` o `False`). Són fonamentals per prendre decisions als nostres programes.

| Operador | Significat    | Exemple  | Resultat |
|----------|---------------|----------|----------|
| `==`     | Igual a       | `5 == 5` | `True`   |
| `!=`     | Diferent de   | `5 != 3` | `True`   |
| `<`      | Menor que     | `3 < 5`  | `True`   |
| `>`      | Major que     | `3 > 5`  | `False`  |
| `<=`     | Menor o igual | `5 <= 5` | `True`   |
| `>=`     | Major o igual | `3 >= 5` | `False`  |

**Exemple pràctic**

Validar un port:

```python
port = 8080

print(port == 22)   # False
print(port != 22)   # True
print(port > 1024)  # True (no és privilegiat)
```

**Exemple pràctic**

Comprovar llindars:

```python
espai_lliure_gb = 15
usuaris_connectats = 50

print(espai_lliure_gb < 10)        # False
print(usuaris_connectats >= 100)   # False
```

## Comparació de cadenes

Les cadenes es comparen en ordre lexicogràfic (com en un diccionari), caràcter per caràcter:

```python
>>> "apple" < "banana"
True
>>> "web01" < "web02"
True
>>> "Web" < "web"
True  # Les majúscules van abans que les minúscules
```

Això és útil per ordenar noms de servidors o fitxers:

```python
>>> "server10" < "server2"
True  # Atenció! Compara caràcter per caràcter, no numèricament
>>> "server02" < "server10"
True  # Amb zeros a l'esquerra funciona millor
```

> Quan comparem cadenes que contenen números, cal anar amb compte perquè la comparació és lexicogràfica, no numèrica. Per això és bona pràctica usar zeros a l'esquerra en noms de servidors o fitxers.

**Encadenament de comparacions**

Python permet encadenar comparacions de manera natural. Per exemple:

```python
port = 8080

port >= 1024 and port <= 65535  # True
print(1024 <= port <= 65535)    # True
```

Altres exemples:

```python
x = 50
print(0 < x < 100)      # True
print(10 <= x <= 20)    # False
```

Aquesta sintaxi és més llegible i s'assembla a com ho escriuríem matemàticament.

## Operadors lògics

Els operadors lògics ens permeten combinar múltiples condicions:

| Operador | Significat        | Exemple   |
|----------|-------------------|-----------|
| `and`    | Totes dues certes | `a and b` |
| `or`     | Almenys una certa | `a or b`  |
| `not`    | Negació           | `not a`   |


**AND**

L'operador `and` retorna `True` només si **totes dues** condicions són certes:

```python
port = 8080
actiu = True

print(port > 1024 and actiu)           # True
print(port > 1024 and port < 9000)     # True
print(port > 1024 and port < 5000)     # False (la segona és falsa)
```

Taula de veritat de `and`:

| A     | B     | A and B |
|-------|-------|---------|
| True  | True  | True    |
| True  | False | False   |
| False | True  | False   |
| False | False | False   |

**OR**

L'operador `or` retorna `True` si **almenys una** de les condicions és certa:

```python
protocol = "https"

# N'hi ha prou que una sigui certa
print(protocol == "http" or protocol == "https")  # True
print(protocol == "ftp" or protocol == "sftp")    # False (cap és certa)
```

Taula de veritat de `or`:

| A     | B     | A or B |
|-------|-------|--------|
| True  | True  | True   |
| True  | False | True   |
| False | True  | True   |
| False | False | False  |

**NOT**

L'operador `not` inverteix el valor booleà:

```python
actiu = True
print(not actiu)     # False

porta_oberta = False
print(not porta_oberta)  # True
```

És útil per expressar condicions negatives:

```python
usuari = "guest"
autoritzats = ["admin", "root", "operador"]

if not usuari in autoritzats:
    print("Accés denegat")
```

**Avaluació en curtcircuit**

Python avalua les expressions lògiques d'esquerra a dreta i s'atura quan ja sap el resultat. Això s'anomena **avaluació en curtcircuit** (short-circuit evaluation):

- Amb `and`: si la primera condició és `False`, ja no avalua la segona, car el resultat serà `False` sigui com sigui.
- Amb `or`: si la primera condició és `True`, ja no avalua la segona, car el resultat serà `True` sigui com sigui.

Examples:

```python
# AND
x = 0
print(x != 0 and 10 / x > 1)  # False

# OR
y = 5
print(y > 0 or 10 / 0 > 1)    # True
```

> Cap dels dos exemples anteriors donen error de divisió per zero car la segona condició no s'avalua.

Això és útil per protegir operacions que podrien fallar. En el següent cas, si la llista és buida, la segona condició no s'avalua i evitam l'excepció `IndexError`:

```python
llista = []

# Primer comprovam que la llista no sigui buida
if len(llista) > 0 and llista[0] == "valor":
    print("El primer element és 'valor'")
```

**Combinant operadors lògics**

Podem combinar múltiples operadors per crear condicions complexes:

```python
port = 443
protocol = "https"
actiu = True

# Accés permès si el port és 443 o 8443, usa HTTPS i està actiu
acces_permes =
  (port == 443 or port == 8443) and
  protocol == "https" and
  actiu
print(acces_permes)  # True
```

> Usam parèntesis per agrupar condicions i fer el codi més llegible, encara que no sempre siguin necessaris.

## Operadors de pertinença

Els operadors de pertinença comproven si un element existeix dins una col·lecció:

| Operador | Significat    | Exemple              |
|----------|---------------|----------------------|
| `in`     | Existeix a    | `"a" in "hola"`      |
| `not in` | No existeix a | `5 not in [1, 2, 3]` |

**Cadenes**

Podem comprovar si una subcadena existeix dins una cadena:

```python
missatge = "Error: connexió refusada"

print("Error" in missatge)      # True
print("Warning" in missatge)    # False
print("connexió" in missatge)   # True

# not in
print("Warning" not in missatge)  # True
```

**Ús amb llistes i tuples**

Podem comprovar si un valor forma part d'una llista o d'una tupla:

```python
ports_oberts = [22, 80, 443, 8080]

print(22 in ports_oberts)       # True
print(3306 in ports_oberts)     # False
print(3306 not in ports_oberts) # True

# Validar un port
port_sol·licitat = 443
if port_sol·licitat in ports_oberts:
    print(f"El port {port_sol·licitat} està obert")
```

**Ús amb diccionaris**

Amb diccionaris, `in` comprova les **claus**, no els valors:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 22}

print("nom" in servidor)     # True
print("web01" in servidor)   # False
print("sistema" in servidor) # False
```

Per comprovar si un valor existeix:

```python
print("web01" in servidor.values())  # True
```

**Ús amb conjunts**

Els conjunts són molt eficients per comprovar pertinença:

```python
ports_permesos = {22, 80, 443, 8080, 8443}

port = 443
if port in ports_permesos:
    print(f"Port {port} permès")
else:
    print(f"Port {port} bloquejat")
```

## Operadors d'identitat

Els operadors d'identitat comproven si dos objectes són el **mateix objecte** a memòria, no només si tenen el mateix valor:

| Operador | Significat              |
|----------|-------------------------|
| `is`     | És el mateix objecte    |
| `is not` | No és el mateix objecte |

L'operador `==` s'usa per comparar valors, mentre que l'operador `is` s'usa per comparar identitats (d'objectes). Vegem la diferència entre aquests dos operadors amb un exemple:

```python
llista1 = [1, 2, 3]
llista2 = [1, 2, 3]
llista3 = llista1

print(llista1 == llista2)  # True (tenen el mateix contingut)
print(llista1 == llista3)  # True

print(llista1 is llista2)  # False (són objectes diferents)
print(llista1 is llista3)  # True (apunten al mateix objecte)
```

> A Python, tots els tipus de dades són objectes, inclosos els tipus primitius, com enters i booleans.

**Ús principal: comparar amb `None`**

L'ús més comú de `is` és comparar amb `None`:

```python
resultat = None

if resultat is None:
    print("No hi ha resultat")
```

També se pot aconseguir el mateix amb l'operador `==`. És una forma no recomanada, però que també funciona:

```python
if resultat == None:
    print("No hi ha resultat")
```

Per què usar `is` amb `None`? Perquè `None` és un objecte únic a Python (singleton[^1]) i comparar identitat és més ràpid i més explícit que comparar valors. Exemple:

[^1]: Només existeix una única instància d’aquest objecte en tot el programa.

```python
def obtenir_configuracio(clau):
    config = {"port": 22, "timeout": 30}
    return config.get(clau)  # Retorna None si la clau no existeix

valor = obtenir_configuracio("max_connexions")

if valor is None:
    print("Configuració no trobada")
else:
    print(f"Valor: {valor}")
```

> No usis `is` per comparar nombres o cadenes. Tot i que pot funcionar en alguns casos, el comportament no és garantit i pot donar resultats inesperats.

## Precedència d'operadors

Quan una expressió té múltiples operadors, Python els avalua en un ordre determinat. La **precedència** defineix quins operadors s'avaluen primer:

| Prioritat     | Operadors                                    | Descripció             |
|---------------|----------------------------------------------|------------------------|
| 1 (més alta)  | `**`                                         | Potència               |
| 2             | `+x`, `-x`, `not`                            | Unaris i negació       |
| 3             | `*`, `/`, `//`, `%`                          | Multiplicació, divisió |
| 4             | `+`, `-`                                     | Suma, resta            |
| 5             | `<`, `<=`, `>`, `>=`, `==`, `!=`, `in`, `is` | Comparacions           |
| 6             | `and`                                        | I lògic                |
| 7 (més baixa) | `or`                                         | O lògic                |

Exemples:

* La potència té més prioritat que la multiplicació:
  ```python
  >>> 2 * 3 ** 2
  18  # Primer 3 ** 2 = 9, després 2 * 9 = 18
  ```

* La multiplicació té més prioritat que la suma:
  ```python
  >>> 2 + 3 * 4
  14  # Primer 3 * 4 = 12, després 2 + 12 = 14
  ```

* `not` té més prioritat que `and`:
  ```python
  >>> not True and False
  False  # False
  ```

* `and` té més prioritat que `or`
  ```python
  >>> True or False and False
  True  # True
  ```

**Ús de parèntesis**

Tot i conèixer la precedència, és recomanable usar **parèntesis** per fer el codi més clar:

```python
# Sense parèntesis (correcte però menys clar)
acces = rol == "admin" or rol == "root" and actiu

# Amb parèntesis (més llegible)
acces = (rol == "admin") or (rol == "root" and actiu)

# Encara més clar si l'intenció és altra
acces = (rol == "admin" or rol == "root") and actiu
```

Els parèntesis no només milloren la llegibilitat, sinó que també eviten errors quan no recordam exactament la precedència.

## Operadors d'assignació augmentada

Els operadors d'assignació augmentada combinen una operació aritmètica amb l'assignació. Són una forma abreujada d'actualitzar el valor d'una variable:

| Operador  | Equivalent a |
|-----------|--------------|
| `x += 5`  | `x = x + 5`  |
| `x -= 5`  | `x = x - 5`  |
| `x *= 5`  | `x = x * 5`  |
| `x /= 5`  | `x = x / 5`  |
| `x //= 5` | `x = x // 5` |
| `x %= 5`  | `x = x % 5`  |
| `x **= 5` | `x = x ** 5` |

Exemple d'ús amb un comptador:

```python
intents = 0
intents += 1  # intents = 1
intents += 1  # intents = 2
intents += 1  # intents = 3
print(f"Intents: {intents}")
```

Exemple d'ús amb un acumulador:

```python
total_bytes = 0
total_bytes += 1024
total_bytes += 2048
total_bytes += 512
print(f"Total: {total_bytes} bytes")
```

Exemple d'ús decrementant un comptador:

```python
vides = 3
vides -= 1  # vides = 2
print(f"Vides restants: {vides}")
```

Exemple d'ús per a duplicar un valor:

```python
valor = 1
valor *= 2  # valor = 2
valor *= 2  # valor = 4
valor *= 2  # valor = 8
print(f"Valor: {valor}")
```

**Amb cadenes**

L'operador `+=` també funciona amb cadenes per concatenar:

```python
missatge = "Errors: "
missatge += "connexió fallida, "
missatge += "timeout excedit"
print(missatge)  # Errors: connexió fallida, timeout excedit
```

I amb llistes per afegir elements:

```python
logs = []
logs += ["missatge 1"]
logs += ["missatge 2", "missatge 3"]
print(logs)  # ['missatge 1', 'missatge 2', 'missatge 3']
```

> Amb llistes, `+=` és equivalent a `.extend()`, no a `.append()`. Afegeix cada element de la llista de la dreta, no la llista sencera.

## Exercicis

Es proposen quatre exercicis pràctics per consolidar els conceptes d'aquest article.

### Exercici 1

**Calculadora d'espai en disc**

Objectiu: Crear un script que converteixi una mida en bytes a KB, MB i GB.

1. Crea un script anomenat `convertidor_bytes.py`.
2. Demana a l'usuari una mida en bytes.
3. Converteix i mostra el valor en kilobytes, megabytes i gigabytes.
4. Mostra els resultats amb 2 decimals de precisió.

> Pista: 1 KB = 1024 bytes, 1 MB = 1024 KB, 1 GB = 1024 MB.

{{< details summary="Resposta" >}}

Exemple d'script `convertidor_bytes.py`:

```python
#!/usr/bin/env python3
"""Converteix bytes a KB, MB i GB."""

# Demanar la mida en bytes
bytes_totals = int(input("Introdueix la mida en bytes: "))

# Conversions
kilobytes = bytes_totals / 1024
megabytes = bytes_totals / (1024 ** 2)
gigabytes = bytes_totals / (1024 ** 3)

# Mostrar resultats
print()
print(f"Bytes:     {bytes_totals:,}")
print(f"Kilobytes: {kilobytes:,.2f} KB")
print(f"Megabytes: {megabytes:,.2f} MB")
print(f"Gigabytes: {gigabytes:,.2f} GB")
```

> Nota: el format `:,` afegeix separadors de milers per fer els nombres més llegibles.

{{< /details >}}

### Exercici 2

**Validador de ports**

Objectiu: Crear un script que validi si un port és vàlid i si és privilegiat (requereix permisos de root).

1. Crea un script anomenat `validador_port.py`.
2. Demana a l'usuari un número de port.
3. Comprova si el port està dins el rang vàlid (1-65535).
4. Si és vàlid, indica si és un port privilegiat (< 1024) o no privilegiat.
5. Mostra missatges informatius amb el protocol associat al port per a tres casos.

{{< details summary="Resposta" >}}

Exemple d'script `validador_port.py`:

```python
#!/usr/bin/env python3
"""Valida un número de port."""

# Demanar el port
port = int(input("Introdueix un número de port: "))

# Validar rang
if 1 <= port <= 65535:
    print(f"El port {port} és vàlid.")
    
    # Comprovar si és privilegiat
    if port < 1024:
        print("És un port privilegiat.")
    else:
        print("És un port no privilegiat.")
        
    # Ports coneguts
    if port == 22:
        print("Port estàndard per a SSH.")
    elif port == 80:
        print("Port estàndard per a HTTP.")
    elif port == 443:
        print("Port estàndard per a HTTPS.")
else:
    print(f"Error: {port} no és un port vàlid.")
    print("Els ports vàlids estan entre 1 i 65535.")
```

{{< /details >}}

### Exercici 3

**Comprovador d'accés**

Objectiu: Simular un sistema de control d'accés amb múltiples condicions.

1. Crea un script anomenat `control_acces.py`.
2. Defineix una llista d'usuaris autoritzats.
3. Defineix un rang d'hores permeses (e.g., de 8 a 18).
4. Demana el nom d'usuari i l'hora actual.
5. Comprova si l'usuari està autoritzat i l'hora està dins el rang permès.
6. Mostra si l'accés és concedit o denegat, i per quin motiu.

> Pista: combina l'operador `in` per comprovar l'usuari amb operadors de comparació per a l'hora.

{{< details summary="Resposta" >}}

Exemple d'script `control_acces.py`:

```python
#!/usr/bin/env python3
"""Sistema de control d'accés."""

# Configuració
usuaris_autoritzats = ["admin", "operador", "supervisor", "backup"]
hora_inici = 8
hora_fi = 18

# Demanar dades
print("=== Sistema de control d'accés ===")
usuari = input("Nom d'usuari: ")
hora = int(input("Hora actual (0-23): "))

# Comprovar condicions
usuari_valid = usuari in usuaris_autoritzats
hora_valida = hora_inici <= hora < hora_fi

# Determinar accés
print()
if usuari_valid and hora_valida:
    print(f"Accés CONCEDIT a {usuari}.")
elif not usuari_valid and not hora_valida:
    print("Accés DENEGAT.")
    print(f"  - Usuari '{usuari}' no autoritzat.")
    print(f"  - Hora {hora}:00 fora de l'horari permès ({hora_inici}:00-{hora_fi}:00).")
elif not usuari_valid:
    print("Accés DENEGAT.")
    print(f"  - Usuari '{usuari}' no autoritzat.")
else:
    print("Accés DENEGAT.")
    print(f"  - Hora {hora}:00 fora de l'horari permès ({hora_inici}:00-{hora_fi}:00).")
```

{{< /details >}}

### Exercici 4

**Acumulador de trànsit**

Objectiu: Simular el recompte de bytes transferits per diverses connexions.

1. Crea un script anomenat `acumulador_trafic.py`.
2. Defineix una llista de transferències en bytes (simula diverses connexions).
3. Usa un bucle i l'operador `+=` per acumular el total.
4. Mostra el total en bytes i en la unitat més adequada (KB, MB o GB).

> Pista: tria la unitat segons la magnitud del total.

{{< details summary="Resposta" >}}

Exemple d'script `acumulador_trafic.py`:

```python
#!/usr/bin/env python3
"""Acumula el trànsit de xarxa de diverses connexions."""

# Transferències de diverses connexions (en bytes)
transferencies = [
    1048576,      # 1 MB
    524288,       # 512 KB
    2097152,      # 2 MB
    15728640,     # 15 MB
    3145728,      # 3 MB
    262144,       # 256 KB
]

# Acumular total
total_bytes = 0
for transfer in transferencies:
    total_bytes += transfer

# Mostrar resum de connexions
print("=== Resum de trànsit ===")
print(f"Connexions processades: {len(transferencies)}")
print()

# Mostrar cada connexió
print("Detall per connexió:")
for i, transfer in enumerate(transferencies, 1):
    mb = transfer / (1024 ** 2)
    print(f"  Connexió {i}: {mb:.2f} MB")

# Mostrar total en la unitat més adequada
print()
print(f"Total acumulat: {total_bytes:,} bytes")

if total_bytes >= 1024 ** 3:
    total_formatat = total_bytes / (1024 ** 3)
    unitat = "GB"
elif total_bytes >= 1024 ** 2:
    total_formatat = total_bytes / (1024 ** 2)
    unitat = "MB"
elif total_bytes >= 1024:
    total_formatat = total_bytes / 1024
    unitat = "KB"
else:
    total_formatat = total_bytes
    unitat = "bytes"

print(f"Total formatat: {total_formatat:.2f} {unitat}")
```

{{< /details >}}

## Resum

En aquest article hem après a fer operacions amb valors i variables usant els operadors de Python:

- Els **operadors aritmètics** (`+`, `-`, `*`, `/`, `//`, `%`, `**`) ens permeten fer càlculs matemàtics. La divisió entera `//` i el mòdul `%` són especialment útils per a conversions d'unitats.
- Els **operadors de comparació** (`==`, `!=`, `<`, `>`, `<=`, `>=`) comparen valors i retornen booleans. Podem encadenar comparacions per fer el codi més llegible.
- Els **operadors lògics** (`and`, `or`, `not`) combinen condicions. L'avaluació en curtcircuit pot evitar errors.
- Els **operadors de pertinença** (`in`, `not in`) comproven si un element existeix en una col·lecció.
- Els **operadors d'identitat** (`is`, `is not`) comparen si dos objectes són el mateix. Usa `is` principalment per comparar amb `None`.
- La **precedència d'operadors** determina l'ordre d'avaluació, però és millor usar parèntesis per claredat.
- Els **operadors d'assignació augmentada** (`+=`, `-=`, etc.) permeten actualitzar variables de forma concisa.
