---
title: "Bucles"
date: 2026-04-05
lastmod: 2026-04-05
description: "Repetició de codi amb for i while, range, enumerate, zip i comprensions de llista"
summary: "Repetició de codi amb for i while, range, enumerate, zip i comprensions de llista"
categories: ["teaching"]
tags: ["python", "scripting"]
series: ["Scripting"]
series_order: 6
weight: 60
slug: bucles
---

Imaginem que volem comprovar l'estat de 50 servidors. Sense bucles, hauríem d'escriure 50 línies de codi gairebé idèntiques. Amb un bucle, n'escrivim unes poques i deixam que Python faci la repetició per nosaltres.

Les **iteracions** o **bucles** són estructures que ens permeten executar un bloc de codi múltiples vegades i són una de les eines més potents de la programació.

Comparem aquestes dues aproximacions per mostrar una llista de servidors. La primera sense usar bucles:

```python
servidors = ["web01", "web02", "db01", "mail01"]
print(f"Comprovant {servidors[0]}...")
print(f"Comprovant {servidors[1]}...")
print(f"Comprovant {servidors[2]}...")
print(f"Comprovant {servidors[3]}...")
```

I la segona amb bucles:

```python
servidors = ["web01", "web02", "db01", "mail01"]
for servidor in servidors:
    print(f"Comprovant {servidor}...")
```

El bucle fa el mateix amb manco codi i funcionaria igual si la llista tengués 400 elements.

Python ofereix dos tipus de bucles:

- `for`: per iterar sobre una seqüència d'elements (llista, tupla, cadena, diccionari...).
- `while`: per repetir mentre es compleixi una condició.

## El bucle `for`

El bucle `for` recorre els elements d'una seqüència un per un:

```python
for element in seqüència:
    # Codi que s'executa per a cada element
    # La variable 'element' pren el valor de l'element actual
```

En cada volta (o *iteració*) del bucle, la variable `element` pren el valor del següent element de la seqüència.

**Amb llistes**

Quan iteram sobre una llista, la variable pren el valor de l'element de la llista corresponent a la iteració actual:

```python
servidors = ["web01", "web02", "db01", "mail01"]

for servidor in servidors:
    print(f"Comprovant {servidor}...")
```

**Amb cadenes**

Les cadenes són seqüències de caràcters. Per tant, quan iteram sobre una cadena, la variable pren el caràcter de la cadena corresponent a la iteració actual:

```python
ip = "192.168.1.1"

for caracter in ip:
    print(caracter)
```

**Amb diccionaris**

Per defecte, iterar sobre un diccionari recorre les claus:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 22}

for clau in servidor:
    print(clau)
```

Per obtenir els valors ens fa falta usar l'atribut `values()`:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 22}

for valor in servidor.values():
    print(valor)
```

Finalment, per iterar sobre parells clau-valor, ens fa falta usar l'atribut `items()`:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 22}

for clau, valor in servidor.items():
    print(f"{clau}: {valor}")
```

**Exemple pràctic**

Anem a usar un bucle `for` per processar un diccionari de configuració:

```python
config = {
    "port": 8080,
    "timeout": 30,
    "max_connections": 100,
    "ssl": True,
}

print("Configuració actual:")
print("-" * 30)
for parametre, valor in config.items():
    print(f"  {parametre}: {valor}")
```

Sortida:

```
Configuració actual:
------------------------------
  port: 8080
  timeout: 30
  max_connections: 100
  ssl: True
```

## La funció `range()`

Quan volem repetir una acció un nombre determinat de vegades o generar una seqüència de nombres, usam `range()`.

**`range(n)`**

Quan passam un valor enter a la funció `range()`, aquesta genera una seqüència de nombres de 0 a n-1. Exemple:

```python
for i in range(5):
    print(i)
```

En aquest cas, la funció genera els valors 0, 1, 2, 3, 4.

**`range(inici, fi)`**

Quan passam dos valors enters a la funció `range()`, aquesta genera una seqüència de nombres que comença amb `inici` i acaba amb `fi - 1`. Exemple:

```python
for i in range(1, 6):
    print(i)
```

En aquest cas, la funció genera els valors 1, 2, 3, 4, 5. És a dir, el valor inicial s'inclou, però el final no.

**`range(inici, fi, pas)`**

Quan passam tres valors enters a la funció `range()`, aquesta genera una seqüència de nombres que comença amb `inici`, acaba amb `fi - 1` i te un pas de `pas`. Exemple:

```python
for i in range(0, 10, 2):
    print(i)
```

En aquest cas, la funció general els valors 0, 2, 4, 6, 8. El valor inicial i el pas s'inclouen, però el final no.

També podem usar aquesta funció per generar seqüències de nombres negatius. Per aconseguir-ho només cal usar un pas negatiu. Exemple:

```python
for i in range(10, 0, -1):
    print(i)
print("Take off!")
```

En aquest cas, la funció general els valors 10, 9, 8, 7, 6, 5, 4, 3, 2, 1. El valor inicial i el pas s'inclouen, però el final no.


**Exemples pràctics**

Alguns exemples pràctics d'ús de la funció `range()` dins un bucle `for`. Comencem amb la repetició d'una acció N vegades:

```python
max_intents = 3

for intent in range(max_intents):
    print(f"Intent {intent + 1} de {max_intents}")
```

Continuem amb la generació d'un rang de ports:

```python
port_inici = 8080
port_fi = 8085

print("Ports a escanejar:")
for port in range(port_inici, port_fi + 1):
    print(f"  - Port {port}")
```

I acabem amb el processament d'elements amb índex:

```python
servidors = ["web01", "web02", "db01"]

for i in range(len(servidors)):
    print(f"{i}: {servidors[i]}")
```

> Tot i que podem usar `range(len(llista))` per obtenir índexs, hi ha una manera més elegant: `enumerate()`, que veurem a continuació.

## La funció `enumerate()`

La funció `enumerate()` ens permet obtenir l'índex i el valor de cada element alhora:

```python
servidors = ["web01", "web02", "db01", "mail01"]

for index, servidor in enumerate(servidors):
    print(f"{index}: {servidor}")
```

Sortida:

```
0: web01
1: web02
2: db01
3: mail01
```

Per defecte, `enumerate()` comença des de 0, però podem canviar-ho amb el paràmetre `start`:

```python
servidors = ["web01", "web02", "db01", "mail01"]

for numero, servidor in enumerate(servidors, start=1):
    print(f"{numero}. {servidor}")
```

Sortida:

```
1. web01
2. web02
3. db01
4. mail01
```

**Exemple pràctic**

Un ús pràctic de la funció `enumerate()` és el de numerar línies. En aquest exemple usam una llista, però normalment llegiríem les línies d'un fitxer de log:

```python
atacs_log = [
45.148.10.160 - - [10/Apr/2026:15:46:17 +0000] "GET /kxyj/index.htm HTTP/1.1" 404 52916 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0" "-"
47.243.91.232 - - [10/Apr/2026:15:48:37 +0000] "\x16\x03\x01\x00\xF2\x01\x00\x00\xEE\x03\x03\x10ZX\xC5\xB8<\xD2\xF9m\xD5\x12\xF1uEU\xC1\xD1A\xBE\xBE\xE2Ywz\xDF\xA5\x8A@\xF6[\x0E\x8D lBU\xA8\xDD\x888\xE44nD\xB5\x87{l?\x04\xE2Nq\x9C'\xE8d|\xE6F\xF7\x0Cq\xD1C\x00&\xC0+\xC0/\xC0,\xC00\xCC\xA9\xCC\xA8\xC0\x09\xC0\x13\xC0" 400 52861 "-" "-" "-"
45.227.254.156 - - [10/Apr/2026:15:51:09 +0000] "\x03\x00\x00/*\xE0\x00\x00\x00\x00\x00Cookie: mstshash=Administr" 400 11596 "-" "-" "-"
18.116.101.220 - - [10/Apr/2026:15:54:01 +0000] "SSH-2.0-Go" 400 157 "-" "-" "-"
18.116.101.220 - - [10/Apr/2026:15:58:36 +0000] "" 400 0 "-" "-" "-"
20.168.12.63 - - [10/Apr/2026:16:10:28 +0000] "MGLNDD_116.202.120.41_443" 400 157 "-" "-" "-"
78.153.140.147 - - [10/Apr/2026:16:15:38 +0000] "GET /.env HTTP/1.1" 404 35884 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.140 Safari/537.36" "-"
78.153.140.147 - - [10/Apr/2026:16:15:39 +0000] "POST / HTTP/1.1" 405 52986 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.140 Safari/537.36" "-"
]

print("=== Contingut del log ===")
for num_linia, linia in enumerate(atacs_log, start=1):
    print(f"{num_linia:3}: {linia}")
```

## La funció `zip()`

La funció `zip()` combina múltiples seqüències element per element:

```python
noms = ["web01", "web02", "db01"]
ips = ["192.168.1.10", "192.168.1.11", "192.168.1.20"]

for nom, ip in zip(noms, ips):
    print(f"{nom}: {ip}")
```

Sortida:

```
web01: 192.168.1.10
web02: 192.168.1.11
db01: 192.168.1.20
```

Si les seqüències tenen longituds diferents, `zip()` s'atura quan s'esgota la més curta:

```python
noms = ["web01", "web02", "db01", "mail01"]
ips = ["192.168.1.10", "192.168.1.11"]

for nom, ip in zip(noms, ips):
    print(f"{nom}: {ip}")
```

Sortida:

```
web01: 192.168.1.10
web02: 192.168.1.11
```

Els elements `db01` i `mail01` no es processen perquè no tenen IP corresponent.

La funció `zip()` permet combinar més de dues seqüències:

```python
noms = ["web01", "web02", "db01"]
ips = ["192.168.1.10", "192.168.1.11", "192.168.1.20"]
ports = [80, 80, 5432]

for nom, ip, port in zip(noms, ips, ports):
    print(f"{nom}: {ip}:{port}")
```

Sortida:

```
web01: 192.168.1.10:80
web02: 192.168.1.11:80
db01: 192.168.1.20:5432
```

**Exemples pràctics**

La funció `zip()` és molt útil per crear diccionaris a partir de dues llistes:

```python
claus = ["nom", "ip", "port", "actiu"]
valors = ["web01", "192.168.1.10", 80, True]

servidor = dict(zip(claus, valors))
print(servidor)
```

Sortida:

```
{'nom': 'web01', 'ip': '192.168.1.10', 'port': 80, 'actiu': True}
```

La funció `zip()` també és molt útil per comparar dues versions d'una configuració línia per línia:

```python
config_actual = ["port=8080", "timeout=30", "max_conn=100", "ssl=true"]
config_nova = ["port=8080", "timeout=60", "max_conn=200", "ssl=true"]

print("Canvis detectats:")
for actual, nova in zip(config_actual, config_nova):
    if actual != nova:
        print(f"  - Abans: {actual}")
        print(f"  + Ara:   {nova}")
```

Sortida:

```
Canvis detectats:
  - Abans: timeout=30
  + Ara:   timeout=60
  - Abans: max_conn=100
  + Ara:   max_conn=200
```

## El bucle `while`

El bucle `while` repeteix un bloc de codi **mentre** una condició sigui certa:

```python
while condicio:
    # Codi que s'executa mentre la condició és True
```

La condició s'avalua abans de cada iteració. Quan esdevé falsa, el bucle s'atura i la següent iteració no es processa.

Exemple bàsic:

```python
comptador = 5

while comptador > 0:
    print(f"Compte enrere: {comptador}")
    comptador -= 1

print("Take off!")
```

Sortida:

```
Compte enrere: 5
Compte enrere: 4
Compte enrere: 3
Compte enrere: 2
Compte enrere: 1
Take off!
```

### `for` vs `while`

Com a regla general, usam `for` quan sabem quants elements volem processar o tenim una seqüència definida:

```python
for i in range(5):
    print(i)
```

I usam `while` quan no sabem quantes iteracions necessitarem i aquestes depenen d'una condició:

```python
resposta = ""
while resposta != "S":
    resposta = input("Vols continuar? (S/N): ")
```

### Bucles infinits

Si la condició del `while` mai esdevé falsa, tenim un **bucle infinit**:

```python
while True:
    print("Això no acabarà mai...")
```

Per aturar un programa amb bucle infinit, premem `Ctrl+C` al terminal.

Tanmateix, els bucles infinits poden ser intencionats si usam `break` per sortir-ne:

```python
while True:
    paraula = input("Introdueix una paraula o 'exit' per sortir: ")
    if paraula == "exit":
        print("Adéu!")
        break
    print(f"Has escrit: {paraula}")
```

**Exemples pràctics**

Anem a provar el bucle `while` amb reintents de connexió:

```python
import random

max_intents = 5
intent = 0
connectat = False

while intent < max_intents and not connectat:
    intent += 1
    print(f"Intent {intent} de {max_intents}...")
    
    # Simular connexió (50% probabilitat d'èxit)
    if random.random() > 0.5:
        connectat = True
        print("Connexió establerta!")
    else:
        print("Connexió fallida, reintentant...")

if not connectat:
    print("No s'ha pogut connectar després de tots els intents.")
```

## Control del flux

A vegades necessitam alterar el flux normal d'un bucle: sortir-ne abans d'hora o botar alguna iteració.

### `break`

La instrucció `break` atura el bucle immediatament i continua amb el codi que ve després:

```python
servidors = ["web01", "web02", "db01", "mail01", "backup01"]

print("Cercant servidor de base de dades...")

for servidor in servidors:
    print(f"Comprovant {servidor}...")
    if servidor.startswith("db"):
        print(f"Trobat: {servidor}")
        break

print("Cerca finalitzada")
```

Sortida:

```
Cercant servidor de base de dades...
Comprovant web01...
Comprovant web02...
Comprovant db01...
Trobat: db01
Cerca finalitzada
```

El bucle s'atura en trobar `db01` i no continua amb `mail01` ni `backup01`.

### `continue`

La instrucció `continue` bota la resta del codi de la iteració actual i passa a la següent iteració:

```python
servidors = ["web01", "", "db01", None, "mail01"]

print("Processant servidors (ignorant entrades buides)...")

for servidor in servidors:
    if not servidor:  # Entrada buida
        continue
    print(f"Processant {servidor}")
```

Sortida:

```
Processant servidors (ignorant entrades buides)...
Processant web01
Processant db01
Processant mail01
```

Les entrades buides (`""` i `None`) se salten gràcies a `continue`.

**Exemple pràctic**

Anem a filtrar i processar una llista d'adreces IP:

```python
ips_log = [
    "192.168.1.10",
    "10.0.0.5",
    "192.168.1.20",
    "206.204.158.12",
    "127.0.0.1",
    "192.168.1.30",
    "74.10.0.14"
]

print("IPs externes:")

for ip in ips_log:
    # Ignorar localhost
    if ip.startswith("127."):
        continue

    # Ignorar xarxa 10.x
    if ip.startswith("10."):
        continue

    # Ignorar xarxa 192.x
    if ip.startswith("192."):
        continue

    print(f"  {ip}")
```

Sortida:

```
IPs externes:
  206.204.158.12
  74.10.0.14
```

## `else` als bucles `for`

Python permet afegir una clàusula `else` als bucles `for`. El codi de l'`else` s'executa **només si el bucle acaba normalment**, és a dir, sense `break`:

```python
for element in llista:
    if condicio:
        break
else:
    # S'executa si no hi ha hagut break
```

Vegem un exemple d'una cerca amb un missatge final "no trobat":

```python
usuaris = ["anna", "pere", "maria", "joan"]
cercat = "laura"

for usuari in usuaris:
    if usuari == cercat:
        print(f"Usuari {cercat} trobat!")
        break
else:
    print(f"Usuari {cercat} no trobat a la llista")
```

Sortida:

```
Usuari laura no trobat a la llista
```

Si canviem `cercat = "maria"`:

```
Usuari maria trobat!
```

**Exemple pràctic**

Vegem un exemple pràctic per verificar si un port està disponible:

```python
ports_usats = [22, 80, 443, 8080]
port_desitjat = 8000

for port in ports_usats:
    if port == port_desitjat:
        print(f"El port {port_desitjat} ja està en ús")
        break
else:
    print(f"El port {port_desitjat} està disponible")
```

> La clàusula `else` en bucles pot semblar estranya al principi, però és molt útil per a cerques on volem fer alguna cosa si no trobam l'element.

## Comprensions de llista

Les **comprensions de llista** (list comprehensions) són una manera concisa de crear llistes a partir d'iteracions:

```python
[expressio for element in iterable]
```

Vegem un exemple bàsic. En comptes d'escriure:

```python
quadrats = []
for x in range(1, 6):
    quadrats.append(x ** 2)
print(quadrats)  # [1, 4, 9, 16, 25]
```

Podem escriure:

```python
quadrats = [x ** 2 for x in range(1, 6)]
print(quadrats)  # [1, 4, 9, 16, 25]
```

Podem afegir una condició per filtrar els elements:

```python
[expressio for element in iterable if condicio]
```

Per exemple, per obtenir només els nombres parells d'un rang:

```python
parells = [x for x in range(10) if x % 2 == 0]
print(parells)  # [0, 2, 4, 6, 8]
```

**Exemples pràctics**

Podem usar la comprensió de llista per obtenir IPs privades d'una llista d'adreces IP.

```python
ips = ["192.168.1.10", "8.8.8.8", "10.0.0.1", "172.16.0.5", "1.1.1.1"]

ips_privades = [ip for ip in ips if ip.startswith(("192.168.", "10.", "172."))]
print(ips_privades)  # ['192.168.1.10', '10.0.0.1', '172.16.0.5']
```

Podem usar la comprensió de llista per convertir els elements d'una llista a majúscules:

```python
servidors = ["web01", "db01", "mail01"]

servidors_upper = [s.upper() for s in servidors]
print(servidors_upper)  # ['WEB01', 'DB01', 'MAIL01']
```

Podem usar la comprensió de llista per obtenir els noms de fitxers d'una llista de fitxers amb extensions:

```python
fitxers = ["config.yaml", "script.py", "notes.txt", "backup.tar.gz"]

noms = [f.split(".")[0] for f in fitxers]
print(noms)  # ['config', 'script', 'notes', 'backup']
```

O, finalment, podem usar la comprensió, de diccionari en aquest cas, per generar un diccionari de serveis i ports:

```python
serveis = ["ssh", "http", "https"]
ports = [22, 80, 443]

mapeig = {servei: port for servei, port in zip(serveis, ports)}
print(mapeig)  # {'ssh': 22, 'http': 80, 'https': 443}
```

> La comprensió de diccionari funciona igual que la de llista però genera un diccionari.

**Quan usar comprensions**

Les comprensions són ideals per a:

- Transformar tots els elements d'una llista.
- Filtrar elements segons una condició.
- Crear llistes noves de manera concisa.

Ara bé, si la comprensió es torna complexa, és millor usar un bucle tradicional. Per exemple, la següent comprensió de llista és massa complexa i difícil de llegir:

```python
resultat = [f(x) for x in llista if g(x) > 0 and h(x) < 10 or x in excepcions]
```

Per això és millor usar un bucle tradicional:

```python
resultat = []
for x in llista:
    if g(x) > 0 and h(x) < 10:
        resultat.append(f(x))
    elif x in excepcions:
        resultat.append(f(x))
```

## Bucles niuats

A vegades necessitam bucles dins d'altres bucles:

```python
for element_extern in llista_externa:
    for element_intern in llista_interna:
        # Codi que s'executa per a cada combinació
```

Vegem un exemple amb les taules de multiplicar de l'1 fins al 10:

```python
for i in range(1, 11):
    for j in range(1, 11):
        print(f"{i} x {j} = {i * j}")
    print()  # Línia en blanc entre files
```

Sortida:

```
1 x 1 = 1
1 x 2 = 2
1 x 3 = 3
...

2 x 1 = 2
2 x 2 = 4
2 x 3 = 6
...

3 x 1 = 3
3 x 2 = 6
3 x 3 = 9
...
```

**Exemples pràctics**

Vegem un exemple d'escaneig de ports:

```python
hosts = ["192.168.1.10", "192.168.1.11"]
ports = [22, 80, 443]

print("Escaneig de ports:")
for host in hosts:
    print(f"\nHost: {host}")
    for port in ports:
        # Aquí aniria el codi real de comprovació
        print(f"  Comprovant port {port}...")
```

Sortida:

```
Escaneig de ports:

Host: 192.168.1.10
  Comprovant port 22...
  Comprovant port 80...
  Comprovant port 443...

Host: 192.168.1.11
  Comprovant port 22...
  Comprovant port 80...
  Comprovant port 443...
```

Vegem també com generar una matriu de connectivitat:

```python
servidors = ["web01", "web02", "db01"]

print("Matriu de connexions:")
print("        ", end="")
for s in servidors:
    print(f"{s:8}", end="")  # Usam f-strings per formatar
print()

for origen in servidors:
    print(f"{origen:8}", end="")
    for desti in servidors:
        if origen == desti:
            print("   -    ", end="")
        else:
            print("   OK   ", end="")
    print()
```

Sortida:

```
Matriu de connexions:
        web01   web02   db01    
web01      -      OK      OK   
web02     OK       -      OK   
db01      OK      OK       -   
```

## Exercicis

Es proposen quatre exercicis pràctics per consolidar els conceptes d'aquest article.

### Exercici 1

**Monitor de serveis**

Objectiu: Mostrar un informe numerat de l'estat de diversos serveis.

1. Crea un script anomenat `monitor_serveis.py`.
2. Defineix una llista de diccionaris, on cada diccionari representa un servei amb claus `nom` de tipus cadena i `actiu` de tipus booleà (veure exemple més abaix).
3. Recorr la llista amb `enumerate()` per mostrar cada servei numerat.
4. Compta quants serveis estan actius i quants aturats.
5. Mostra el recompte final.

Pots usar la següent llista de diccionaris de serveis com a punt de partida:

```python
# Llista de serveis
serveis = [
    {"nom": "nginx", "actiu": True},
    {"nom": "postgresql", "actiu": True},
    {"nom": "redis", "actiu": False},
    {"nom": "docker", "actiu": True},
    {"nom": "cron", "actiu": True},
    {"nom": "postfix", "actiu": False},
]
```

> Pista: usa una variable comptador per als serveis actius i resta del total per als aturats.

{{< details summary="Resposta" >}}

Exemple d'script `monitor_serveis.py`:

```python
#!/usr/bin/env python3
"""Monitor d'estat de serveis."""

# Llista de serveis
serveis = [
    {"nom": "nginx", "actiu": True},
    {"nom": "postgresql", "actiu": True},
    {"nom": "redis", "actiu": False},
    {"nom": "docker", "actiu": True},
    {"nom": "cron", "actiu": True},
    {"nom": "postfix", "actiu": False},
]

# Comptador
actius = 0

# Mostrar informe
print("=== Estat dels serveis ===")
print()

for num, servei in enumerate(serveis, start=1):
    nom = servei["nom"]
    estat = "✓ Actiu" if servei["actiu"] else "✗ Aturat"
    print(f"{num:2}. {nom:15} [{estat}]")
    
    if servei["actiu"]:
        actius += 1

# Resum
total = len(serveis)
aturats = total - actius

print()
print("-" * 35)
print(f"Total: {total} serveis")
print(f"  Actius:  {actius}")
print(f"  Aturats: {aturats}")
```

{{< /details >}}

### Exercici 2

**Generador de rangs de ports**

Objectiu: Generar una llista de ports dins un rang especificat per l'usuari.

1. Crea un script anomenat `generador_ports.py`.
2. Demana a l'usuari el port inicial i el port final.
3. Demana si vol excloure els ports privilegiats (< 1024).
4. Genera i mostra la llista de ports.
5. Si la llista és molt llarga (> 20), mostra només els primers 10 i els últims 10.

> Pista: usa `range()` per generar els ports i una condició per filtrar si cal.

{{< details summary="Resposta" >}}

Exemple d'script `generador_ports.py`:

```python
#!/usr/bin/env python3
"""Generador de rangs de ports."""

# Demanar rang
port_inici = int(input("Port inicial: "))
port_fi = int(input("Port final: "))

# Validar ordre
if port_inici > port_fi:
    port_inici, port_fi = port_fi, port_inici
    print("(S'ha invertit l'ordre dels ports)")

# Preguntar per ports privilegiats
excloure = input("Excloure ports privilegiats (< 1024)? (s/n): ").lower()
excloure_privilegiats = excloure == "s"

# Generar llista
if excloure_privilegiats:
    ports = [p for p in range(port_inici, port_fi + 1) if p >= 1024]
else:
    ports = list(range(port_inici, port_fi + 1))

# Mostrar resultat
print()
print(f"Ports generats: {len(ports)}")
print()

if len(ports) == 0:
    print("Cap port al rang especificat.")
elif len(ports) <= 20:
    # Mostrar tots
    print("Llista de ports:")
    for port in ports:
        print(f"  {port}")
else:
    # Mostrar primers 10 i últims 10
    print("Primers 10 ports:")
    for port in ports[:10]:
        print(f"  {port}")
    
    print(f"  ... ({len(ports) - 20} ports més) ...")
    
    print("Últims 10 ports:")
    for port in ports[-10:]:
        print(f"  {port}")
```

{{< /details >}}

### Exercici 3

**Reintents de connexió**

Objectiu: Simular un sistema de reintents de connexió amb `while`.

1. Crea un script anomenat `reintents_connexio.py`.
2. Defineix un màxim de 5 intents.
3. En cada intent, simula una connexió amb probabilitat d'èxit del 30%.
4. Si la connexió té èxit, mostra un missatge i surt.
5. Si s'esgoten els intents, mostra un missatge d'error.
6. Usa `else` amb el `while` per detectar quan s'han esgotat els intents.

> Pista: usa `import random` i `random.random()` per generar un nombre entre 0 i 1.

{{< details summary="Resposta" >}}

Exemple d'script `reintents_connexio.py`:

```python
#!/usr/bin/env python3
"""Simula reintents de connexió a un servidor."""

import random
import time

# Configuració
MAX_INTENTS = 5
PROBABILITAT_EXIT = 0.3
SERVIDOR = "db.exemple.com"

print(f"Connectant a {SERVIDOR}...")
print()

intent = 0

while intent < MAX_INTENTS:
    intent += 1
    print(f"Intent {intent}/{MAX_INTENTS}...", end=" ")
    
    # Simular temps de connexió
    time.sleep(0.5)
    
    # Simular resultat (30% probabilitat d'èxit)
    if random.random() < PROBABILITAT_EXIT:
        print("✓ Connexió establerta!")
        break
    else:
        print("✗ Fallida")
        
        if intent < MAX_INTENTS:
            print("  Reintentant en 1 segon...")
            time.sleep(1)
else:
    # S'executa si el bucle acaba sense break
    print()
    print("=" * 40)
    print(f"ERROR: No s'ha pogut connectar a {SERVIDOR}")
    print(f"       després de {MAX_INTENTS} intents.")
    print("=" * 40)
```

{{< /details >}}

### Exercici 4

**Processador de logs**

Objectiu: Filtrar línies d'error d'un log usant comprensions de llista.

1. Crea un script anomenat `processador_logs.py`.
2. Defineix una llista de línies de log (veure exemple més abaix).
3. Usa una comprensió de llista per extreure només les línies que contenen `ERROR`.
4. Mostra les línies d'error numerades.
5. Crea una segona comprensió per extreure línies amb `WARNING`.
6. Mostra un resum amb el nombre de cada tipus.

Pots usar la següent llista de línies de log com a punt de partida:

```python
linies_log = [
    "2026-04-09 10:15:32 INFO: Servei iniciat correctament",
    "2026-04-09 10:15:33 INFO: Escoltant al port 8080",
    "2026-04-09 10:16:01 WARNING: Connexió lenta detectada",
    "2026-04-09 10:16:45 ERROR: No s'ha pogut connectar a la base de dades",
    "2026-04-09 10:16:46 INFO: Reintentant connexió...",
    "2026-04-09 10:16:47 ERROR: Timeout de connexió excedit",
    "2026-04-09 10:17:00 WARNING: Ús de memòria elevat (85%)",
    "2026-04-09 10:17:30 INFO: Connexió a base de dades establerta",
    "2026-04-09 10:18:00 ERROR: Error d'autenticació per a usuari 'test'",
    "2026-04-09 10:18:15 INFO: Petició processada correctament",
    "2026-04-09 10:19:00 WARNING: Certificat SSL caduca en 7 dies",
]
```

> Pista: usa `"ERROR" in linia` per comprovar si una línia conté el text.

{{< details summary="Resposta" >}}

Exemple d'script `processador_logs.py`:

```python
#!/usr/bin/env python3
"""Processador de logs amb comprensions de llista."""

# Simulació de línies de log
linies_log = [
    "2026-04-09 10:15:32 INFO: Servei iniciat correctament",
    "2026-04-09 10:15:33 INFO: Escoltant al port 8080",
    "2026-04-09 10:16:01 WARNING: Connexió lenta detectada",
    "2026-04-09 10:16:45 ERROR: No s'ha pogut connectar a la base de dades",
    "2026-04-09 10:16:46 INFO: Reintentant connexió...",
    "2026-04-09 10:16:47 ERROR: Timeout de connexió excedit",
    "2026-04-09 10:17:00 WARNING: Ús de memòria elevat (85%)",
    "2026-04-09 10:17:30 INFO: Connexió a base de dades establerta",
    "2026-04-09 10:18:00 ERROR: Error d'autenticació per a usuari 'test'",
    "2026-04-09 10:18:15 INFO: Petició processada correctament",
    "2026-04-09 10:19:00 WARNING: Certificat SSL caduca en 7 dies",
]

# Extreure línies per tipus usant comprensions
errors = [linia for linia in linies_log if "ERROR" in linia]
warnings = [linia for linia in linies_log if "WARNING" in linia]
info = [linia for linia in linies_log if "INFO" in linia]

# Mostrar errors
print("=== ERRORS ===")
if errors:
    for num, error in enumerate(errors, start=1):
        print(f"{num}. {error}")
else:
    print("Cap error trobat.")

print()

# Mostrar warnings
print("=== WARNINGS ===")
if warnings:
    for num, warning in enumerate(warnings, start=1):
        print(f"{num}. {warning}")
else:
    print("Cap warning trobat.")

print()

# Resum
print("=== RESUM ===")
print(f"Total de línies:  {len(linies_log)}")
print(f"  Errors:         {len(errors)}")
print(f"  Warnings:       {len(warnings)}")
print(f"  Info:           {len(info)}")
```

{{< /details >}}

## Resum

En aquest article hem après a repetir codi de manera eficient amb bucles:

- El bucle `for` recorre els elements d'una seqüència: llistes, tuples, cadenes, diccionaris.
- La funció `range()` genera seqüències de nombres.
- La funció `enumerate()` ens dona l'índex i el valor alhora.
- La funció `zip()` combina múltiples seqüències element per element.
- El bucle `while` repeteix mentre una condició sigui certa, útil quan no sabem quantes iteracions necessitarem.
- La instrucció `break` surt del bucle immediatament i la instrucció `continue` bota a la següent iteració.
- La clàusula `else` en bucles `for` s'executa només si el bucle acaba sense `break`.
- Les comprensions de llista permeten crear llistes de manera concisa.
- Els bucles niuats processen combinacions d'elements.
