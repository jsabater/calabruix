---
title: "Col·leccions de dades"
date: 2026-04-05
lastmod: 2026-04-08
description: "Llistes, tuples, diccionaris i conjunts per organitzar informació amb Python"
summary: "Llistes, tuples, diccionaris i conjunts per organitzar informació amb Python"
categories: ["teaching"]
tags: ["python", "scripting"]
series: ["Scripting"]
series_order: 3
weight: 30
slug: colleccions
---

Fins ara hem fet feina amb variables que contenen un sol valor: un número, una cadena, un booleà. Però sovint necessitam gestionar conjunts de dades: llistes de servidors, configuracions amb múltiples paràmetres, registres d'IPs, etc. Per a aquestes situacions, Python ofereix les **col·leccions**.

Imaginem que volem gestionar els servidors d'una xarxa. Amb variables individuals, hauríem de fer:

```python
servidor1 = "web01"
servidor2 = "web02"
servidor3 = "db01"
servidor4 = "mail01"
```

Això és poc pràctic: si tenim 50 servidors, necessitam 50 variables. I si volem recórrer-los tots per comprovar el seu estat? Hauríem de repetir el codi 50 vegades.

Amb una **llista**, podem agrupar tots els servidors en una sola variable:

```python
servidors = ["web01", "web02", "db01", "mail01"]
```

Ara podem afegir servidors, eliminar-ne, ordenar-los i recórrer-los tots amb poques línies de codi.

Python ofereix quatre tipus principals de col·leccions, cadascuna amb característiques diferents:

| Tipus      | Ordenat | Mutable | Duplicats | Sintaxi         |
|------------|:-------:|:-------:|:---------:|-----------------|
| Llista     | Sí      | Sí      | Sí        | `[a, b, c]`     |
| Tupla      | Sí      | No      | Sí        | `(a, b, c)`     |
| Diccionari | Sí*     | Sí      | Claus: No | `{clau: valor}` |
| Conjunt    | No      | Sí      | No        | `{a, b, c}`     |

> *Els diccionaris mantenen l'ordre d'inserció des de Python 3.7.

Vegem cada tipus en detall.

## Llistes

Una **llista** és una col·lecció ordenada i mutable d'elements. "Ordenada" significa que els elements mantenen la posició en què els hem afegit. "Mutable" significa que podem modificar la llista després de crear-la: afegir, eliminar o canviar elements.

**Creació**

Cream una llista posant els elements entre claudàtors `[]`, separats per comes:

```python
# Llista de servidors
servidors = ["web01", "web02", "db01", "mail01"]

# Llista de ports
ports_oberts = [22, 80, 443, 3306]

# Llista buida
alertes = []

# Llista amb tipus mesclats
dades = ["servidor01", 22, True, "192.168.0.3", 3.14]
```

**Accés**

Accedim als elements usant índexs entre claudàtors. Recordem que els índexs comencen al 0:

```python
servidors = ["web01", "web02", "db01", "mail01"]

print(servidors[0])    # web01 (primer element)
print(servidors[1])    # web02 (segon element)
print(servidors[-1])   # mail01 (últim element)
print(servidors[-2])   # db01 (penúltim element)
```

L'slicing també funciona amb llistes:

```python
servidors = ["web01", "web02", "db01", "mail01"]

print(servidors[0:2])   # ['web01', 'web02']
print(servidors[1:])    # ['web02', 'db01', 'mail01']
print(servidors[:2])    # ['web01', 'web02']
```

**Modificació**

Podem canviar un element assignant un nou valor a la seva posició:

```python
servidors = ["web01", "web02", "db01"]
servidors[0] = "mail01"
print(servidors)  # ['mail01', 'web02', 'db01']
```

**Addició**

Hi ha diverses maneres d'afegir elements a una llista. Donada la llista següent:

```python
servidors = ["web01", "web02"]
```

Podem afegir un element al final:

```python
servidors.append("db01")
print(servidors)  # ['web01', 'web02', 'db01']
```

Podem afegir un element en una posició específica:

```python
servidors.insert(1, "web03")
print(servidors)  # ['web01', 'web03', 'web02', 'db01']
```

Podem afegir múltiples elements al final:

```python
servidors.extend(["mail01", "backup01"])
print(servidors)  # ['web01', 'web03', 'web02', 'db01', 'mail01', 'backup01']
```

La diferència entre `append()` i `extend()` és important:

* `append()` afegeix l'element tal qua, fins i tot si és una llista.
* `extend()` afegeix cada element de la llista.

Exemple:

```python
llista = [1, 2, 3]

llista.append([4, 5])
print(llista)  # [1, 2, 3, [4, 5]]

llista = [1, 2, 3]

llista.extend([4, 5])
print(llista)  # [1, 2, 3, 4, 5]
```

**Eliminació**

També hi ha diverses maneres d'eliminar elements. Donada la següent llista:

```python
servidors = ["web01", "web02", "db01", "mail01", "web02"]
```

Podem eliminar per valor (només la primera coincidència):

```python
servidors.remove("web02")
print(servidors)  # ['web01', 'db01', 'mail01', 'web02']
```

Podem eliminar per índex i obtenir el valor eliminat:

```python
eliminat = servidors.pop(1)
print(eliminat)   # db01
print(servidors)  # ['web01', 'mail01', 'web02']
```

Podem eliminar l'últim element:

```python
ultim = servidors.pop()
print(ultim)      # web02
print(servidors)  # ['web01', 'mail01']
```

Podem eliminar per índex sense obtenir el valor:

```python
del servidors[0]
print(servidors)  # ['mail01']
```

Podem buidar la llista completament:

```python
servidors.clear()
print(servidors)  # []
```

**Cerca**

Podem comprovar si un element existeix i trobar la seva posició. Donada la llista:

```python
servidors = ["web01", "web02", "db01", "mail01"]
```

Podem usar l'operador `in` per comprovar si un element existeix:

```python
print("web01" in servidors)     # True
print("backup01" in servidors)  # False
```

Podem usar `.index()` per trobar la posició d'un element:

```python
print(servidors.index("db01"))  # 2
```

I també podem comptar quantes vegades apareix un element:

```python
ports = [22, 80, 443, 80, 22, 80]
print(ports.count(80))  # 3
```

> Si intentam trobar l'índex d'un element que no existeix, Python genera un error `ValueError`. Abans de cridar `.index()`, és bona pràctica comprovar si l'element existeix amb `in`.

**Ordenació**

Podem ordenar una llista de dues maneres, modificant la llista existent o creant una nova llista.

Si volem modificar la llista existent tenim al nostre abast les següents operacions:

```python
servidors = ["db01", "web01", "mail01", "web02"]

servidors.sort()
print(servidors)  # ['db01', 'mail01', 'web01', 'web02']

# Ordenar en ordre invers
servidors.sort(reverse=True)
print(servidors)  # ['web02', 'web01', 'mail01', 'db01']

# Invertir l'ordre actual (no ordena, només inverteix)
servidors.reverse()
print(servidors)  # ['db01', 'mail01', 'web01', 'web02']
```

Si volem obtenir una còpia ordenada sense modificar l'original, usam `sorted()`:

```python
servidors = ["db01", "web01", "mail01", "web02"]
ordenats = sorted(servidors)
print(servidors)  # ['db01', 'web01', 'mail01', 'web02'] (no canvia)
print(ordenats)   # ['db01', 'mail01', 'web01', 'web02']

# Invertir l'ordre
invertits = sorted(servidors, reverse=True)
print(invertits)  # ['web02', 'web01', 'mail01', 'db01']
```

> Per invertir l'ordre d'una llista sense ordernar-la usaríem el built-in `reversed()`.

**Longitud**

La funció `len()` retorna el nombre d'elements:

```python
servidors = ["web01", "web02", "db01", "mail01"]
print(len(servidors))  # 4
print(f"Tenim {len(servidors)} servidors")
```

## Tuples

Una **tupla** és una col·lecció ordenada i **immutable** d'elements. Un cop creada, no podem modificar-la: no podem afegir, eliminar ni canviar elements. Això pot semblar una limitació, però és útil quan volem assegurar que les dades no canviaran accidentalment.

**Creació**

Cream una tupla posant els elements entre parèntesis `()`. Exemple d'una tupla amb dades d'un servidor:

```python
servidor = ("web01", "192.168.1.10", 22)
```

Una tupla amb un sol element necessita coma final:

```python
un_element = ("valor",)
```

Una tupla pot estar buida:

```python
buida = ()
```

Els parèntesis són opcionals en molts casos:

```python
coordenades = "web01", "192.168.1.10", 22
```

**Accés**

L'accés funciona igual que amb les llistes:

```python
servidor = ("web01", "192.168.1.10", 22)

print(servidor[0])   # web01
print(servidor[1])   # 192.168.1.10
print(servidor[-1])  # 22
print(servidor[0:2]) # ('web01', '192.168.1.10')
```

**Immutabilitat**

Si intentam modificar una tupla, Python genera un error:

```python
servidor = ("web01", "192.168.1.10", 22)
servidor[0] = "webserver01"  # TypeError: 'tuple' object does not support item assignment
```

**Desempaquetament**

Una característica molt útil és el **desempaquetament**, que permet assignar cada element a una variable en una sola línia:

```python
servidor = ("web01", "192.168.1.10", 22)

# Desempaquetament
nom, ip, port = servidor

print(nom)   # web01
print(ip)    # 192.168.1.10
print(port)  # 22
```

Això és especialment pràctic quan una funció retorna múltiples valors:

```python
def obtenir_info_servidor():
    return ("web01", "192.168.1.10", True)

nom, ip, actiu = obtenir_info_servidor()
print(f"Servidor {nom} ({ip}): {'Actiu' if actiu else 'Inactiu'}")
```

## Tuples vs llistes

Usam **tuples** quan:

- Les dades no han de canviar: coordenades, configuració fixa, registres.
- Volem protegir les dades de modificacions accidentals.
- Necessitam usar la col·lecció com a clau de diccionari (les llistes no poden ser claus).

Usam **llistes** quan:

- Necessitam afegir o eliminar elements.
- Les dades poden canviar durant l'execució.

**Exemple pràctic**

Una llista de tuples per a un inventari de servidors. Cada servidor es defineix com a una tupla amb el seu nom, l'adreç IP i el port, i és inmutable. La llista de servidors és mutable (podem afegir o eliminar servidors).

```python
inventari = [
    ("web01", "192.168.1.10", 22),
    ("web02", "192.168.1.11", 22),
    ("db01", "192.168.1.20", 5432),
]
```

Podem afegir un nou servidor a la llista:

```python
inventari.append(("mail01", "192.168.1.30", 25))
```

Però no podem modificar les dades d'un servidor individual:

```python
inventari[0][0] = "webserver01"  # Error!
```

## Diccionaris

Un **diccionari** és una col·lecció de parells **clau-valor**. En comptes d'accedir als elements per índex numèric, hi accedim per una clau que nosaltres definim. Això fa els diccionaris ideals per emmagatzemar dades estructurades.

**Creació**

Cream un diccionari posant parells `clau: valor` entre claus `{}`. Per exemple:

```python
servidor = {
    "nom": "web01",
    "ip": "192.168.1.10",
    "port": 22,
    "actiu": True
}
```

Podem crear un diccionari buit:

```python
config = {}
```

Les claus poden ser qualsevol tipus immutable (strings, nombres, tuples), però normalment usam strings. Els valors poden ser de qualsevol tipus, incloses altres col·leccions:

```python
servidor = {
    "nom": "web01",
    "ports": [22, 80, 443],            # Llista com a valor
    "recursos": {"cpu": 4, "ram": 8},  # Diccionari niuat
    "actiu": True
}
```

**Accés**

Accedim als valors usant la clau entre claudàtors:

```python
servidor = {
    "nom": "web01",
    "ip": "192.168.1.10",
    "port": 22,
    "actiu": True
}

print(servidor["nom"])    # web01
print(servidor["ip"])     # 192.168.1.10
print(servidor["actiu"])  # True
```

Si intentam accedir a una clau que no existeix, Python genera un error `KeyError`:

```python
print(servidor["sistema"])  # KeyError: 'sistema'
```

Per evitar l'error, podem usar el mètode `.get()`, que retorna `None` (o un valor per defecte) si la clau no existeix:

```python
print(servidor.get("sistema"))           # None
print(servidor.get("sistema", "Linux"))  # Linux (valor per defecte)
print(servidor.get("nom", "desconegut")) # web01 (la clau existeix)
```

**Modificació**

Podem modificar un valor existent o afegir un nou parell clau-valor amb la mateixa sintaxi:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10"}

# Modificar un valor existent
servidor["ip"] = "192.168.1.100"
print(servidor)  # {'nom': 'web01', 'ip': '192.168.1.100'}

# Afegir un nou parell clau-valor
servidor["port"] = 22
servidor["actiu"] = True
print(servidor)  # {'nom': 'web01', 'ip': '192.168.1.100', 'port': 22, 'actiu': True}
```

Per fusionar dos diccionaris, usam `.update()`:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10"}
config_extra = {"port": 22, "actiu": True}

servidor.update(config_extra)
print(servidor)  # {'nom': 'web01', 'ip': '192.168.1.10', 'port': 22, 'actiu': True}
```

**Eliminació**

Podem eliminar elements de diverses maneres. Donat el diccionari següent:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 22, "temporal": True}
```

Podem eliminar i obtenir el valor:

```python
port = servidor.pop("port")
print(port)      # 22
print(servidor)  # {'nom': 'web01', 'ip': '192.168.1.10', 'temporal': True}
```

També podem eliminar sense obtenir el valor:

```python
del servidor["temporal"]
print(servidor)  # {'nom': 'web01', 'ip': '192.168.1.10'}
```

I també podem eliminar tot el diccionari:

```python
servidor.clear()
print(servidor)  # {}
```

**Claus, valors i parells**

Els diccionaris ofereixen mètodes per obtenir les seves parts. Donat el diccionari següent:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 22}
```

Podem obtenir totes les claus:

```python
print(servidor.keys())    # dict_keys(['nom', 'ip', 'port'])
```

Podem obtenir tots els valors:

```python
print(servidor.values())  # dict_values(['web01', '192.168.1.10', 22])
```

Podem obtenir tots els parells clau-valor:

```python
print(servidor.items())   # dict_items([('nom', 'web01'), ('ip', '192.168.1.10'), ('port', 22)])
```

Aquests mètodes són especialment útils per iterar sobre el diccionari, com veurem més endavant.

**Pertinença**

Usam l'operador `in` per comprovar si una clau existeix:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 22}

print("nom" in servidor)     # True
print("sistema" in servidor) # False
```

Fixem-nos que `in` cerca entre les **claus**, no entre els valors.

**Exemple pràctic**

Un ús molt comú dels diccionaris és emmagatzemar configuracions:

```python
config_nginx = {
    "listen": 80,
    "server_name": "exemple.com",
    "root": "/var/www/html",
    "index": ["index.html", "index.htm"],
    "ssl": {
        "enabled": True,
        "certificate": "/etc/ssl/certs/cert.pem",
        "key": "/etc/ssl/private/key.pem"
    }
}

# Accedir a valors niuats
print(config_nginx["ssl"]["certificate"])  # /etc/ssl/certs/cert.pem

# Modificar un valor niuat
config_nginx["ssl"]["enabled"] = False
```

## Conjunts

Un **conjunt** és una col·lecció **no ordenada** d'elements **únics**. Els conjunts eliminen automàticament els duplicats i són molt eficients per comprovar si un element existeix.

**Creació**

Cream un conjunt amb `set()` o posant elements entre claus `{}`:

```python
# Conjunt de ports en ús
ports_en_us = {22, 80, 443, 22, 80}  # Els duplicats s'eliminen
print(ports_en_us)  # {80, 443, 22} (l'ordre pot variar)
```

També podem crear un conjunt a partir d'una llista, el que farà que s'eliminin els duplicats:

```python
ips_log = ["192.168.1.10", "192.168.1.20", "192.168.1.10", "192.168.1.30", "192.168.1.10"]
ips_uniques = set(ips_log)
print(ips_uniques)  # {'192.168.1.30', '192.168.1.20', '192.168.1.10'}
```

Per crear un conjunt buit usarem `set()`, no `{}`:

```python
buit = set()
```

> Els elements d'un conjunt han de ser immutables (strings, nombres, tuples). No podem posar llistes ni diccionaris dins un conjunt.

**Addició**

Donat el següent conjunt:

```python
usuaris_connectats = {"anna", "pere", "maria"}
```

Podem afegir un element:

```python
usuaris_connectats.add("joan")
print(usuaris_connectats)  # {'anna', 'joan', 'maria', 'pere'}
```

Podem afegir un element que ja existeix (no fa res):

```python
usuaris_connectats.add("anna")
print(usuaris_connectats)  # {'anna', 'joan', 'maria', 'pere'}
```

Podem eliminar un element de forma que retorni error si no existeix:

```python
usuaris_connectats.remove("pere")
print(usuaris_connectats)  # {'anna', 'joan', 'maria'}
```

I podem eliminar un element sense que retorni error si no existeix:

```python
usuaris_connectats.discard("inexistent")
print(usuaris_connectats)  # {'anna', 'joan', 'maria'}
```

**Operacions**

Els conjunts suporten operacions matemàtiques de teoria de conjunts. Donat el següent conjunt:

```python
servidors_producció = {"web01", "web02", "db01"}
servidors_backup = {"web01", "backup01", "db01"}
```

Podem fer la unió, que retorn tots els elements de tots dos conjunts:

```python
tots = servidors_producció | servidors_backup
print(tots)  # {'web02', 'backup01', 'db01', 'web01'}
```

Podem dur a terme la intersecció, que retorna els elements que estan en tots dos conjunts:

```python
comuns = servidors_producció & servidors_backup
print(comuns)  # {'web01', 'db01'}
```

Podem fer la diferència, que retorna els elements que estan en el primer conjunt però no en el segon:

```python
nomes_produccio = servidors_producció - servidors_backup
print(nomes_produccio)  # {'web02'}
```

I podem fer la diferència simètrica, que retorna els elements que estan en un o l'altre, però no en tots dos:

```python
exclusius = servidors_producció ^ servidors_backup
print(exclusius)  # {'web02', 'backup01'}
```

**Pertinença**

Comprovar si un element existeix en un conjunt és molt ràpid:

```python
ports_permesos = {22, 80, 443, 8080}

print(22 in ports_permesos)    # True
print(3306 in ports_permesos)  # False
```

Aquesta operació és molt útil per a validacions:

```python
port_sol·licitat = 443
if port_sol·licitat in ports_permesos:
    print(f"Port {port_sol·licitat} permès")
else:
    print(f"Port {port_sol·licitat} bloquejat")
```

**Exemple pràctic**

Un cas d'ús típic és extreure valors únics d'una llista amb duplicats. Per exemple, donat el següent conjunt que simula les IPs d'un log, amb repeticions:

```python
ips_del_log = [
    "192.168.1.10",
    "192.168.1.20",
    "192.168.1.10",
    "192.168.1.30",
    "192.168.1.10",
    "192.168.1.20",
    "10.0.0.5",
    "192.168.1.10",
]
```

Podem obtenir una llista d'IPs uniques:

```python
ips_uniques = set(ips_del_log)
print(f"IPs úniques: {len(ips_uniques)}")
print(ips_uniques)
```

Podem comptar connexions per IP (combinant amb un diccionari):

```python
connexions_per_ip = {}
for ip in ips_del_log:
    if ip in connexions_per_ip:
        connexions_per_ip[ip] = connexions_per_ip[ip] + 1
    else:
        connexions_per_ip[ip] = 1

print(connexions_per_ip)
# {'192.168.1.10': 4, '192.168.1.20': 2, '192.168.1.30': 1, '10.0.0.5': 1}
```

## Iteració bàsica

Una de les operacions més freqüents amb col·leccions és **iterar** sobre els seus elements, és a dir, recórrer-los un per un. La manera més senzilla de fer-ho es utilitzar un bucle `for`, que veurem en detall al proper article. Aquí n'introduïm la sintaxi bàsica.

Podem iterar sobre llistes i tuples:

```python
servidors = ["web01", "web02", "db01", "mail01"]

for servidor in servidors:
    print(f"Comprovant {servidor}...")
```

Sortida:

```
Comprovant web01...
Comprovant web02...
Comprovant db01...
Comprovant mail01...
```

La variable `servidor` pren el valor de cada element de la llista en cada volta del bucle.

### Diccionaris

Amb diccionaris, podem iterar sobre claus, valors o parells. Donat el següent diccionari:

```python
servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 22}
```

Podem iterar sobre claus (comportament per dfecte):

```python
for clau in servidor:
    print(clau)
# nom, ip, port
```

Podem iterar sobre els valors:

```python
for valor in servidor.values():
    print(valor)
# web01, 192.168.1.10, 22
```

I podem iterar sobre els parells clau-valor:

```python
for clau, valor in servidor.items():
    print(f"{clau}: {valor}")
# nom: web01
# ip: 192.168.1.10
# port: 22
```

### Conjunts

També podem usar `for` per a iterar sobre conjunts:

```python
usuaris = {"anna", "pere", "maria"}

for usuari in usuaris:
    print(f"Usuari: {usuari}")
```

> Recordem que els conjunts no tenen ordre, per tant l'ordre d'iteració pot variar.

### Exemple

Donada la següent llista de diccionaris que simula un inventari:

```python
inventari = [
    {"nom": "web01", "ip": "192.168.1.10", "actiu": True},
    {"nom": "web02", "ip": "192.168.1.11", "actiu": True},
    {"nom": "db01", "ip": "192.168.1.20", "actiu": False},
    {"nom": "mail01", "ip": "192.168.1.30", "actiu": True},
]
```

Podem imprimir els detalls de cada servidor de la següent forma:

```python
print("=== Informe d'inventari ===")
print()

for servidor in inventari:
    estat = "Actiu" if servidor["actiu"] else "Inactiu"
    print(f"Servidor: {servidor['nom']}")
    print(f"  IP:    {servidor['ip']}")
    print(f"  Estat: {estat}")
    print()
```

> Recordem que un diccionari conté parells clau-valor, mentre que un conjunt, tot i compartir l'ús de claus, conté valors individuals.

Sortida esperada:

```
=== Informe d'inventari ===

Servidor: web01
  IP:    192.168.1.10
  Estat: Actiu

Servidor: web02
  IP:    192.168.1.11
  Estat: Actiu

Servidor: db01
  IP:    192.168.1.20
  Estat: Inactiu

Servidor: mail01
  IP:    192.168.1.30
  Estat: Actiu
```

## Resum

Resum dels tipus de col·leccions que hem vist en aquest article i els seus usos més apropiats:

- Les **llistes** són col·leccions ordenades i mutables. Les usam quan necessitam una seqüència d'elements que pot canviar.
- Les **tuples** són col·leccions ordenades i immutables. Les usam per a dades que no han de canviar i per retornar múltiples valors des d'una funció.
- Els **diccionaris** emmagatzemen parells clau-valor. Són ideals per a configuracions i dades estructurades.
- Els **conjunts** són col·leccions sense ordre ni duplicats. Són molt eficients per comprovar pertinença i eliminar duplicats.

En la pràctica, sovint combinam diferents tipus. Exemples:

- **Llista de diccionaris:** inventari de servidors on cada servidor és un diccionari amb les seves propietats.
- **Diccionari de llistes:** configuració on cada clau té múltiples valors.
- **Llista de tuples:** registres de dades on cada registre és immutable.
- **Conjunt a partir de llista:** per eliminar duplicats.

## Exercicis

Es proposen quatre exercicis pràctics per consolidar els conceptes d'aquest article.

### Exercici 1

**Gestió de servidors**

Objectiu: Crear i manipular una llista de servidors.

1. Crea un script anomenat `gestio_servidors.py`.
2. Crea una llista inicial amb tres servidors: "web01", "db01", "mail01".
3. Afegeix dos servidors nous: "web02" i "backup01".
4. Elimina el servidor "mail01".
5. Ordena la llista alfabèticament.
6. Mostra la llista final i el nombre total de servidors.

{{< details summary="Resposta" >}}

Exemple d'script `gestio_servidors.py`:

```python
#!/usr/bin/env python3
"""Gestió bàsica d'una llista de servidors."""

# Llista inicial
servidors = ["web01", "db01", "mail01"]
print(f"Llista inicial: {servidors}")

# Afegir servidors
servidors.append("web02")
servidors.append("backup01")
print(f"Després d'afegir: {servidors}")

# Eliminar un servidor
servidors.remove("mail01")
print(f"Després d'eliminar mail01: {servidors}")

# Ordenar
servidors.sort()
print(f"Llista ordenada: {servidors}")

# Resum final
print()
print(f"Total de servidors: {len(servidors)}")
```

{{< /details >}}

### Exercici 2

**Configuració de servei**

Objectiu: Crear un diccionari amb la configuració d'un servei i mostrar-la formatada.

1. Crea un script anomenat `config_servei.py`.
2. Crea un diccionari amb la configuració d'un servidor web: nom del servei, port, directori arrel, nombre màxim de connexions i si SSL està actiu.
3. Mostra cada paràmetre de configuració usant un bucle `for` sobre `.items()`.
4. Modifica el port a 8080 i afegeix un nou paràmetre "timeout" amb valor 30.
5. Mostra la configuració actualitzada.

> Pista: usa `.items()` per obtenir parells clau-valor i f-strings per al format.

{{< details summary="Resposta" >}}

Exemple d'script `config_servei.py`:

```python
#!/usr/bin/env python3
"""Gestió de la configuració d'un servei."""

# Configuració inicial
config = {
    "servei": "nginx",
    "port": 80,
    "root": "/var/www/html",
    "max_connexions": 1000,
    "ssl": True
}

# Mostrar configuració inicial
print("=== Configuració inicial ===")
for clau, valor in config.items():
    print(f"  {clau}: {valor}")

# Modificar i afegir paràmetres
config["port"] = 8080
config["timeout"] = 30

# Mostrar configuració actualitzada
print()
print("=== Configuració actualitzada ===")
for clau, valor in config.items():
    print(f"  {clau}: {valor}")
```

{{< /details >}}

### Exercici 3

**IPs úniques**

Objectiu: Analitzar una llista d'IPs amb duplicats i extreure'n les úniques.

1. Crea un script anomenat `ips_uniques.py`.
2. Defineix una llista que simuli IPs extretes d'un log (amb duplicats).
3. Usa un conjunt per obtenir les IPs úniques.
4. Mostra quantes IPs totals hi ha al log i quantes són úniques.
5. Mostra la llista d'IPs úniques ordenada.

> Pista: pots convertir un conjunt a llista amb `list()` i després ordenar-la amb `sorted()`.

{{< details summary="Resposta" >}}

Exemple d'script `ips_uniques.py`:

```python
#!/usr/bin/env python3
"""Extreu IPs úniques d'un log."""

# Llista d'IPs del log (amb duplicats)
ips_log = [
    "192.168.1.10",
    "10.0.0.5",
    "192.168.1.20",
    "192.168.1.10",
    "172.16.0.100",
    "192.168.1.10",
    "10.0.0.5",
    "192.168.1.30",
    "192.168.1.20",
    "10.0.0.5",
]

# Obtenir IPs úniques
ips_uniques = set(ips_log)

# Mostrar estadístiques
print(f"Entrades totals al log: {len(ips_log)}")
print(f"IPs úniques: {len(ips_uniques)}")

# Mostrar IPs úniques ordenades
print()
print("Llista d'IPs úniques:")
for ip in sorted(ips_uniques):
    print(f"  {ip}")
```

{{< /details >}}

### Exercici 4

**Inventari de xarxa**

Objectiu: Crear un inventari de servidors combinant diccionaris i tuples.

1. Crea un script anomenat `inventari_xarxa.py`.
2. Crea un diccionari on les claus siguin noms de servidors i els valors siguin tuples amb (IP, port, sistema_operatiu).
3. Afegeix almenys quatre servidors a l'inventari.
4. Itera sobre l'inventari i mostra la informació de cada servidor de manera formatada.
5. Demana a l'usuari el nom d'un servidor i mostra'n la informació (o un missatge d'error si no existeix).

{{< details summary="Resposta" >}}

Exemple d'script `inventari_xarxa.py`:

```python
#!/usr/bin/env python3
"""Inventari de xarxa amb diccionaris i tuples."""

# Inventari: clau = nom, valor = tupla (ip, port, so)
inventari = {
    "web01": ("192.168.1.10", 22, "Debian 13"),
    "web02": ("192.168.1.11", 22, "Debian 13"),
    "db01": ("192.168.1.20", 5432, "Ubuntu 24.04"),
    "mail01": ("192.168.1.30", 25, "Rocky Linux 9"),
}

# Mostrar inventari complet
print("=== Inventari de xarxa ===")
print()
for nom, dades in inventari.items():
    ip, port, sistema = dades  # Desempaquetament de la tupla
    print(f"{nom}:")
    print(f"  IP:     {ip}")
    print(f"  Port:   {port}")
    print(f"  SO:     {sistema}")
    print()

# Consultar un servidor específic
print("-" * 30)
consulta = input("Nom del servidor a consultar: ")

if consulta in inventari:
    ip, port, sistema = inventari[consulta]
    print()
    print(f"Informació de '{consulta}':")
    print(f"  IP:     {ip}")
    print(f"  Port:   {port}")
    print(f"  SO:     {sistema}")
else:
    print(f"Error: el servidor '{consulta}' no existeix a l'inventari.")
```

{{< /details >}}
