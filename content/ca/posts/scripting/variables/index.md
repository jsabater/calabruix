---
title: "Variables i tipus de dades"
date: 2026-04-05
lastmod: 2026-04-05
description: "Variables, tipus bàsics, conversions, f-strings i entrada de dades amb Python"
summary: "Variables, tipus bàsics, conversions, f-strings i entrada de dades amb Python"
categories: ["teaching"]
tags: ["python", "scripting"]
series: ["Scripting"]
series_order: 2
weight: 20
slug: variables-tipus-dades
---

Els programes necessiten emmagatzemar i manipular informació: noms d'usuaris, rutes de fitxers, ports de xarxa, percentatges d'ús, etc. Per fer-ho, usen **variables**. En aquest article aprendrem què són les variables, quins tipus de dades bàsics ofereix Python i com podem fer-hi feina.

## Variables

Una **variable** és un nom que associam a un valor emmagatzemat a la memòria de l'ordinador. Podem pensar-hi com una capsa etiquetada: l'etiqueta és el nom de la variable i el contingut és el valor.

Per crear una variable i assignar-li un valor, usam l'operador `=`:

```python
nom_usuari = "admin"
port_ssh = 22
servei_actiu = True
```

A partir d'aquest moment, podem usar el nom de la variable per accedir al seu valor:

```python
>>> nom_usuari = "admin"
>>> print(nom_usuari)
admin
>>> port_ssh = 22
>>> print(port_ssh)
22
```

Les variables poden canviar de valor durant l'execució del programa. Per això es diuen "variables":

```python
>>> comptador = 1
>>> print(comptador)
1
>>> comptador = 2
>>> print(comptador)
2
```

### Noms de variables

Python té algunes regles sobre quins noms podem usar per a les variables:

- Només poden contenir lletres, números i guions baixos (`_`).
- No poden començar amb un número.
- No podem usar paraules reservades del llenguatge (`if`, `for`, `while`, `def`, `class`, `import`, `True`, `False`, `None`, etc.).
- Python distingeix entre majúscules i minúscules: `usuari`, `Usuari` i `USUARI` són tres variables diferents.

Exemples de noms vàlids:

```python
nom_usuari = "jaume"
ruta_backup = "/home/backup"
pid_proces = 1234
espai_lliure_gb = 45.5
_variable_interna = "valor"
usuari2 = "maria"
```

Exemples de noms **no vàlids**:

```python
2usuari = "error"      # No pot començar amb un número
nom-usuari = "error"   # El guió no està permès, només el guió baix
for = "error"          # 'for' és una paraula reservada
```

### Convencions de noms

A més de les regles obligatòries, hi ha convencions que la comunitat Python segueix per escriure codi llegible. La guia d'estil oficial és el [PEP 8](https://peps.python.org/pep-0008/) i recomana:

- Usar `snake_case` per a variables i funcions: paraules en minúscules separades per guions baixos.
- Usar noms descriptius que expliquin el propòsit de la variable.

Comparem un mal exemple amb un bon exemple:

```python
# Mal exemple: noms curts i poc descriptius
x = "/var/log"
n = 3
a = True

# Bon exemple: noms descriptius
directori_logs = "/var/log"
max_intents = 3
connexio_activa = True
```

El codi amb noms descriptius és més fàcil de llegir i mantenir, especialment quan hi tornam mesos després.

## Tipus de dades

Cada valor a Python té un **tipus de dada** que determina quines operacions podem fer amb ell. Python té quatre tipus bàsics que usarem constantment:

1. Enters (int).
2. Decimals (float).
3. Cadenes de text (str).
4. Booleans (bool).

### Enters

Els nombres enters són nombres sense decimals, tant positius com negatius:

```python
port_ssh = 22
pid_proces = 1547
nombre_usuaris = 150
temperatura = -5
```

Podem fer operacions aritmètiques amb enters:

```python
>>> 10 + 3
13
>>> 10 - 3
7
>>> 10 * 3
30
>>> 10 // 3    # Divisió entera (sense decimals)
3
>>> 10 % 3     # Residu de la divisió (mòdul)
1
>>> 2 ** 10    # Potència (2 elevat a 10)
1024
```

En administració de sistemes, usam enters per a PIDs, ports, nombre de connexions, permisos en octal, etc.

### Decimals

Els nombres decimals, o de coma flotant[^1], representen valors amb part fraccionària:

[^1]: Els nombres de coma flotant funcionen de manera similar a la notació científica: la coma decimal no té una posició fixa, sinó que "flota" per adaptar-se a la magnitud del número. En anglès prové del terme *floating point*, ja que usen el punt com a separador decimal.

```python
espai_total_gb = 500.0
espai_usat_gb = 234.7
percentatge_us = 46.94
temperatura_cpu = 52.5
```

Podem fer les mateixes operacions que amb enters:

```python
>>> 10.0 / 3
3.3333333333333335
>>> 100 * 0.8
80.0
```

Fixem-nos que la divisió amb `/` sempre retorna un `float`, mentre que `//` retorna un enter (divisió entera).

> Els nombres decimals tenen una precisió limitada. Per a la majoria de tasques d'administració això no és un problema, però cal tenir-ho en compte si fem càlculs financers o científics.

### Cadenes de text

Les cadenes de text, o *strings*, representen seqüències de caràcters. Les podem escriure amb cometes simples o dobles:

```python
nom_servidor = "webserver01"
missatge = 'Connexió establerta'
ruta = "/var/log/syslog"
```

Si necessitam incloure cometes dins el text, podem usar l'altre tipus de cometes per delimitar la cadena:

```python
missatge = "L'usuari ha iniciat sessió"
consulta = "SELECT nom, cognom FROM usuari WHERE role = 'admin'"
```

Per a textos multilínia, usam cometes triples:

```python
missatge_error = """Error crític:
El servei no ha pogut iniciar.
Revisau els logs per a més informació."""
```

### Booleans

Els valors booleans només poden ser `True` (vertader) o `False` (fals). Són fonamentals per a les decisions dins els programes:

```python
servei_actiu = True
fitxer_existeix = False
connexio_segura = True
```

Els booleans solen ser el resultat de comparacions:

```python
>>> 10 > 5
True
>>> 10 < 5
False
>>> "admin" == "admin"
True
>>> "admin" == "root"
False
```

En administració de sistemes, usam booleans per representar estats: un servei està actiu o no, un fitxer existeix o no, una connexió és segura o no.

### Inspeccionar el tipus

Podem usar la funció `type()` per saber el tipus d'un valor o variable:

```python
>>> type(22)
<class 'int'>
>>> type(3.14)
<class 'float'>
>>> type("hola")
<class 'str'>
>>> type(True)
<class 'bool'>
>>> port = 22
>>> type(port)
<class 'int'>
```

Això és útil quan depuram i volem verificar quin tipus de dada conté una variable.

### Tipat dinàmic

Python és un llenguatge de **tipat dinàmic**, el que significa que no hem de declarar el tipus d'una variable; Python el dedueix automàticament segons el valor que li assignam. A més, una variable pot canviar de tipus durant l'execució:

```python
>>> valor = 42
>>> type(valor)
<class 'int'>
>>> valor = "ara som text"
>>> type(valor)
<class 'str'>
```

Aquesta flexibilitat és còmoda, però també pot provocar errors si no anam amb compte. És bona pràctica mantenir el mateix tipus per a una variable al llarg del programa.

## Operacions amb cadenes

Les cadenes de text són un dels tipus de dades que més usarem en scripting. Python ofereix moltes operacions per manipular-les.

### Concatenació i repetició

Podem unir cadenes amb l'operador `+`:

```python
>>> salutacio = "Hola, " + "món!"
>>> print(salutacio)
Hola, món!
>>> nom = "admin"
>>> missatge = "Benvingut, " + nom
>>> print(missatge)
Benvingut, admin
```

I també podem repetir-les amb `*`:

```python
>>> linia = "-" * 40
>>> print(linia)
----------------------------------------
```

### Mètodes i funcions

La funció `len()` retorna el nombre de caràcters d'una cadena:

```python
>>> len("administrador")
13
>>> ruta = "/var/log/syslog"
>>> len(ruta)
15
```

Les cadenes tenen molts mètodes incorporats. Els mètodes són funcions que "pertanyen" a un objecte i es criden amb la notació `objecte.metode()`. Vegem els més útils:

```python
>>> missatge = "  Error al servidor  "
>>> missatge.strip()          # Elimina espais en blanc als extrems
'Error al servidor'
>>> missatge.upper()          # Tot en majúscules
'  ERROR AL SERVIDOR  '
>>> missatge.lower()          # Tot en minúscules
'  error al servidor  '
>>> missatge.replace("Error", "Alerta")  # Substituir text
'  Alerta al servidor  '
```

Altres mètodes útils:

```python
>>> "webserver01".startswith("web")
True
>>> "webserver01".endswith(".local")
False
>>> "admin:x:1000:1000::/home/admin:/bin/bash".split(":")
['admin', 'x', '1000', '1000', '', '/home/admin', '/bin/bash']
>>> ", ".join(["un", "dos", "tres"])
'un, dos, tres'
```

El mètode `split()` és especialment útil per processar línies de fitxers de configuració o logs.

### Índexs i slicing

Podem accedir a caràcters individuals usant índexs entre claudàtors. Els índexs comencen a 0:

```python
>>> ruta = "/var/log"
>>> ruta[0]
'/'
>>> ruta[1]
'v'
>>> ruta[-1]    # L'últim caràcter
'g'
>>> ruta[-2]    # El penúltim
'o'
```

L'*slicing* ens permet extreure subcadenes amb la sintaxi `[inici:fi]`:

```python
>>> ruta = "/var/log/syslog"
>>> ruta[0:4]     # Des de l'índex 0 fins al 3 (el 4 no s'inclou)
'/var'
>>> ruta[5:8]     # Des de l'índex 5 fins al 7
'log'
>>> ruta[9:]      # Des de l'índex 9 fins al final
'syslog'
>>> ruta[:4]      # Des del principi fins a l'índex 3
'/var'
```

## Conversions entre tipus

Sovint necessitam convertir valors d'un tipus a un altre. Python proporciona funcions per fer-ho:

```python
>>> int("42")         # Cadena a enter
42
>>> float("3.14")     # Cadena a decimal
3.14
>>> str(22)           # Enter a cadena
'22'
>>> str(3.14)         # Decimal a cadena
'3.14'
>>> bool(1)           # Enter a booleà
True
>>> bool(0)
False
```

> Aquesta operació es coneix com a *casting* en anglès.

Si intentam convertir un text que no és un nombre vàlid, Python genera un error:

```python
>>> int("hola")
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
ValueError: invalid literal for int() with base 10: 'hola'
```

Més endavant aprendrem a gestionar aquests errors de manera controlada.

### Valors falsos

Quan convertim a booleà, alguns valors es consideren "falsos":

```python
>>> bool(0)
False
>>> bool(0.0)
False
>>> bool("")       # Cadena buida
False
>>> bool([])       # Llista buida
False
>>> bool({})       # Diccionari buid
False
>>> bool(None)     # Valor nul
False
```

Tots els altres valors es consideren "vertaders". Això és útil perquè podem usar valors directament en condicions sense comparar-los explícitament amb zero o amb cadenes buides.

## Formatació de cadenes

Una de les funcionalitats més útils de Python modern (3.6+) són les **f-strings** (formatted string literals). Ens permeten inserir valors dins una cadena de manera molt llegible.

La sintaxi és senzilla: posam una `f` davant les cometes i les variables entre claus `{}`:

```python
>>> nom = "webserver01"
>>> ip = "192.168.1.100"
>>> port = 443
>>> 
>>> missatge = f"Servidor: {nom}, IP: {ip}, Port: {port}"
>>> print(missatge)
Servidor: webserver01, IP: 192.168.1.100, Port: 443
```

### Avantatges

Comparem les dues formes d'aconseguir el mateix resultat:

```python
# Amb concatenació
>>> missatge = "Servidor: " + nom + ", IP: " + ip + ", Port: " + str(port)

# Amb f-string
>>> missatge = f"Servidor: {nom}, IP: {ip}, Port: {port}"
```

Amb f-strings és molt més clar. A més, fixem-nos que amb concatenació hem de convertir `port` a cadena amb `str()`, mentre que amb f-strings la conversió és automàtica.

### Formatar nombres

Les f-strings permeten formatar nombres de diverses maneres:

```python
>>> percentatge = 73.456789
>>> print(f"Ús de disc: {percentatge:.2f}%")  # Limitar a 2 decimals
Ús de disc: 73.46%
>>> print(f"Valor: {42:5d}")  # Forçar 5 caràcters d'ample
Valor:   42
>>> print(f"Codi: {7:03d}")  # Omplir amb zeros
Codi: 007
```

Exemples pràctics per a administració:

```python
>>> espai_total = 500
>>> espai_usat = 234.7
>>> percentatge = (espai_usat / espai_total) * 100
>>> print(
... f"Espai usat: {espai_usat:.1f} GB de {espai_total} GB "
... f"({percentatge:.1f}%)"
    )
Espai usat: 234.7 GB de 500 GB (46.9%)
```

### Expressions

Podem posar expressions completes dins les claus:

```python
>>> a = 10
>>> b = 3
>>> print(f"La suma de {a} i {b} és {a + b}")
La suma de 10 i 3 es 13
>>> print(f"El resultat de {a} / {b} és {a / b:.2f}")
El resultat de 10 / 3 es 3.33
```

## Entrada de dades

La funció `input()` ens permet llegir dades que l'usuari escriu per teclat. Accepta un paràmetre opcional que és el missatge que es mostra a l'usuari:

```python
nom = input("Quin és el teu nom? ")
print(f"Hola, {nom}!")
Quin és el teu nom? Jaume
Hola, Jaume!
```

És important recordar que `input()` **sempre** retorna una cadena de text, encara que l'usuari escrigui un nombre:

```python
>>> edat = input("Quina edat tens? ")
Quina edat tens? 25
>>> type(edat)
<class 'str'>
>>> edat + 1
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: can only concatenate str (not "int") to str
```

Per fer operacions numèriques, hem de convertir el valor:

```python
edat_text = input("Quina edat tens? ")
edat = int(edat_text)
print(f"L'any que ve tendràs {edat + 1} anys.")
```

O de manera més compacta:

```python
edat = int(input("Quina edat tens? "))
print(f"L'any que ve tendràs {edat + 1} anys.")
```

### Exemple pràctic

Un script senzill que demana informació sobre un servidor:

```python
#!/usr/bin/env python3
"""Recull informació bàsica d'un servidor."""

print("=== Informació del servidor ===")
nom = input("Nom del servidor: ")
ip = input("Adreça IP: ")
port = int(input("Port SSH: "))

print()
print(f"Servidor '{nom}' configurat a {ip}:{port}")
```

## Constants i convencions

Python no té constants en el sentit estricte; totes les variables es poden modificar. Tanmateix, per convenció, usam **noms en majúscules** per indicar que un valor no s'hauria de modificar:

```python
MAX_INTENTS = 3
DIRECTORI_LOGS = "/var/log"
PORT_SSH_DEFECTE = 22
TIMEOUT_SEGONS = 30
```

Quan altres programadors veuen un nom en majúscules, entenen que és un valor constant que no s'ha de canviar durant l'execució del programa.

És habitual definir les constants a la part superior del fitxer, després dels imports:

```python
#!/usr/bin/env python3
"""Script de monitoratge de serveis."""

# Constants
MAX_INTENTS = 3
TIMEOUT_SEGONS = 30
FITXER_LOG = "/var/log/monitoratge.log"

# Codi principal
intents = 0
# ...
```

## Exercicis

Es proposen quatre exercicis pràctics per consolidar els conceptes d'aquest article.

### Exercici 1

**Informació del servidor**

Objectiu: Crear variables per emmagatzemar informació d'un servidor i mostrar-les formatades amb f-strings.

1. Crea un script anomenat `info_servidor.py`.
2. Defineix variables per a: nom del servidor, adreça IP, port SSH, sistema operatiu i si el servidor està actiu (booleà).
3. Mostra tota la informació de manera organitzada usant f-strings.
4. Afegeix una línia separadora entre el títol i les dades.

> Pista: pots usar la multiplicació de cadenes per crear línies decoratives, e.g., `"=" * 40`.

{{< details summary="Resposta" >}}

Exemple d'script `info_servidor.py`:

```python
#!/usr/bin/env python3
"""Mostra informació d'un servidor usant variables i f-strings."""

# Informació del servidor
nom_servidor = "webserver01"
ip = "192.168.1.100"
port_ssh = 22
sistema_operatiu = "Debian 13"
actiu = True

# Mostrar informació
print("=== Informació del servidor ===")
print("=" * 31)
print(f"Nom:              {nom_servidor}")
print(f"IP:               {ip}")
print(f"Port SSH:         {port_ssh}")
print(f"Sistema operatiu: {sistema_operatiu}")
print(f"Actiu:            {actiu}")
```

Sortida esperada:

```
=== Informació del servidor ===
===============================
Nom:              webserver01
IP:               192.168.1.100
Port SSH:         22
Sistema operatiu: Debian 13
Actiu:            True
```

{{< /details >}}

### Exercici 2

**Càlcul d'espai en disc**

Objectiu: Crear un script que demani a l'usuari informació sobre l'espai en disc i calculi el percentatge d'ús.

1. Crea un script anomenat `espai_disc.py`.
2. Demana a l'usuari l'espai total del disc en GB.
3. Demana l'espai usat en GB.
4. Calcula l'espai lliure i el percentatge d'ús.
5. Mostra els resultats amb un decimal de precisió.

> Pista: recorda que `input()` retorna una cadena i l'hauràs de convertir a `float` per fer càlculs.

{{< details summary="Resposta" >}}

Exemple d'script `espai_disc.py`:

```python
#!/usr/bin/env python3
"""Calcula l'espai en disc usat i lliure."""

print("=== Càlcul d'espai en disc ===")

# Demanar dades
espai_total = float(input("Espai total del disc (GB): "))
espai_usat = float(input("Espai usat (GB): "))

# Calcular
espai_lliure = espai_total - espai_usat
percentatge_usat = (espai_usat / espai_total) * 100
percentatge_lliure = 100 - percentatge_usat

# Mostrar resultats
print()
print(f"Espai total:  {espai_total:.1f} GB")
print(f"Espai usat:   {espai_usat:.1f} GB ({percentatge_usat:.1f}%)")
print(f"Espai lliure: {espai_lliure:.1f} GB ({percentatge_lliure:.1f}%)")
```

Exemple d'execució:

```
=== Càlcul d'espai en disc ===
Espai total del disc (GB): 500
Espai usat (GB): 234.7

Espai total:  500.0 GB
Espai usat:   234.7 GB (46.9%)
Espai lliure: 265.3 GB (53.1%)
```

{{< /details >}}

### Exercici 3

**Processament de rutes**

Objectiu: Extreure les parts d'una ruta de fitxer usant mètodes de cadenes i slicing.

1. Crea un script anomenat `processa_ruta.py`.
2. Defineix una variable amb una ruta de fitxer, e.g., `/var/log/apache2/error.log`.
3. Extreu i mostra: el directori pare, el nom del fitxer complet i l'extensió.
4. Usa mètodes de cadenes com `rfind()` o `split()`.

> Pista: el mètode `rfind()` cerca un caràcter des del final de la cadena i retorna la seva posició. Això és útil per trobar l'últim `/` o l'últim `.` d'una ruta.

{{< details summary="Resposta" >}}

Exemple d'script `processa_ruta.py`:

```python
#!/usr/bin/env python3
"""Extreu les parts d'una ruta de fitxer."""

ruta = "/var/log/apache2/error.log"

# Trobar l'última barra per separar directori i fitxer
ultima_barra = ruta.rfind("/")
directori = ruta[:ultima_barra]
nom_fitxer = ruta[ultima_barra + 1:]

# Trobar l'últim punt per obtenir l'extensió
ultim_punt = nom_fitxer.rfind(".")
nom_sense_extensio = nom_fitxer[:ultim_punt]
extensio = nom_fitxer[ultim_punt + 1:]

# Mostrar resultats
print(f"Ruta completa: {ruta}")
print(f"Directori:     {directori}")
print(f"Nom fitxer:    {nom_fitxer}")
print(f"Nom base:      {nom_sense_extensio}")
print(f"Extensió:      {extensio}")
```

Sortida esperada:

```
Ruta completa: /var/log/apache2/error.log
Directori:     /var/log/apache2
Nom fitxer:    error.log
Nom base:      error
Extensió:      log
```

Alternativa usant `split()`:

```python
#!/usr/bin/env python3
"""Extreu les parts d'una ruta de fitxer (versió amb split)."""

ruta = "/var/log/apache2/error.log"

# Separar per barres
parts = ruta.split("/")
nom_fitxer = parts[-1]           # Últim element
directori = "/".join(parts[:-1]) # Tot menys l'últim

# Separar nom i extensió
parts_nom = nom_fitxer.split(".")
extensio = parts_nom[-1]
nom_sense_extensio = ".".join(parts_nom[:-1])

print(f"Ruta completa: {ruta}")
print(f"Directori:     {directori}")
print(f"Nom fitxer:    {nom_fitxer}")
print(f"Nom base:      {nom_sense_extensio}")
print(f"Extensió:      {extensio}")
```

> Nota: en un programa real, usaríem el mòdul `pathlib` que veurem més endavant. Proporciona mètodes específics per a aquesta tasca com `.parent`, `.name` i `.suffix`.

{{< /details >}}

### Exercici 4

**Normalització de hostname**

Objectiu: Netejar i normalitzar un hostname introduït per l'usuari.

1. Crea un script anomenat `normalitza_hostname.py`.
2. Demana a l'usuari que introdueixi un hostname.
3. Normalitza el hostname: converteix a minúscules i elimina espais en blanc al principi i al final.
4. Mostra el hostname original, el normalitzat i la seva longitud.

> Pista: pots encadenar mètodes, e.g., `text.strip().lower()`.

{{< details summary="Resposta" >}}

Exemple d'script `normalitza_hostname.py`:

```python
#!/usr/bin/env python3
"""Normalitza un hostname introduït per l'usuari."""

hostname_original = input("Introdueix un hostname: ")

# Normalitzar: eliminar espais i convertir a minúscules
hostname_net = hostname_original.strip().lower()

# Mostrar resultats
print()
print(f"Hostname original:    '{hostname_original}'")
print(f"Hostname normalitzat: '{hostname_net}'")
print(f"Longitud:             {len(hostname_net)} caràcters")
```

Exemple d'execució:

```
Introdueix un hostname:   WebServer01.Local  

Hostname original:    '  WebServer01.Local  '
Hostname normalitzat: 'webserver01.local'
Longitud:             17 caràcters
```

{{< /details >}}
