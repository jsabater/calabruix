---
title: "Estructures de control"
date: 2026-04-05
lastmod: 2026-04-05
description: "Decisions amb if, elif, else i match-case per controlar el flux dels programes"
summary: "Decisions amb if, elif, else i match-case per controlar el flux dels programes"
categories: ["teaching"]
tags: ["python", "scripting"]
series: ["Scripting"]
series_order: 5
weight: 50
slug: estructures-control
---

Fins ara, els nostres programes s'han executat línia per línia, de dalt a baix, sense cap desviació. Però els programes reals necessiten prendre decisions: si el disc està ple, mostra una alerta; si l'usuari és administrador, permet l'accés; si el servei no respon, reinicia'l. En aquest article aprendrem les **estructures de control** que ens permeten decidir quin codi s'executa segons les condicions.

## El flux de control

Per defecte, Python executa les instruccions en ordre seqüencial: una darrere l'altra, de la primera a l'última. Això s'anomena **flux seqüencial**:

```python
print("Primera instrucció")
print("Segona instrucció")
print("Tercera instrucció")
```

Però sovint necessitam que el programa prengui camins diferents segons les circumstàncies. Per exemple, un script de monitoratge podria:

- Mostrar "OK" si l'ús de disc és inferior al 80%.
- Mostrar "Advertència" si està entre el 80% i el 95%.
- Mostrar "Crític" si supera el 95%.

Això és el **flux condicional**: el programa decideix quin codi executar basant-se en condicions que avaluam en temps d'execució.

## L'estructura if

L'estructura `if` és la més bàsica per prendre decisions. Executa un bloc de codi només si una condició és certa:

```python
if condicio:
    # Codi que s'executa si la condició és certa
    instruccio1
    instruccio2
```

La condició d'un `if` és una expressió, tal com vam veure a l'article anterior. Python avalua l'expressió i, si el resultat és cert (o un valor "truthy"), executa el bloc de codi. Per això podem usar comparacions (`x > 10`), operadors lògics (`a and b`), pertinença (`x in llista`) o fins i tot valors directes (`if llista`) com a condicions.

Vegem un exemple pràctic:

```python
espai_usat = 85

if espai_usat > 80:
    print("Alerta: l'ús de disc supera el 80%")
    print(f"Ús actual: {espai_usat}%")
```

Si `espai_usat` és 85, la condició `espai_usat > 80` és `True` i es mostren els dos missatges. Si fos 70, la condició seria `False` i no es mostraria res.

A diferència d'altres llenguatges que usen claus `{}` per delimitar blocs de codi, Python usa la **indentació**. Tot el codi que pertany al bloc `if` ha d'estar indentat (desplaçat cap a la dreta) respecte a la línia del `if`.

La convenció estàndard és usar **4 espais** per nivell d'indentació:

```python
if condicio:
    # Aquesta línia pertany al if (4 espais)
    print("Dins el bloc if")
    print("També dins el bloc if")
print("Fora del bloc if")  # Sense indentació, s'executa sempre
```

> La indentació no és només una qüestió d'estil a Python; és part de la sintaxi. Una indentació incorrecta provoca errors o comportaments inesperats.

**Exemples pràctics**

```python
port = 22

if port < 1024:
    print(f"El port {port} és privilegiat")
    print("Necessites permisos de root per usar-lo")
```

```python
usuari = "admin"
usuaris_autoritzats = ["admin", "root", "operador"]

if usuari in usuaris_autoritzats:
    print(f"Benvingut, {usuari}")
    print("Accés concedit al sistema")
```

## L'estructura if-else

Sovint volem executar un codi si la condició és certa i un altre codi si és falsa. Per això usam `if-else`:

```python
if condicio:
    # Codi si la condició és certa
else:
    # Codi si la condició és falsa
```

Exemple amb comparació numèrica:

```python
espai_lliure_gb = 5
espai_minim_gb = 10

if espai_lliure_gb >= espai_minim_gb:
    print(f"Espai suficient: {espai_lliure_gb} GB disponibles")
else:
    print(f"Espai insuficient: només {espai_lliure_gb} GB disponibles")
    print(f"Es recomanen almenys {espai_minim_gb} GB")
```

## L'estructura if-elif-else

Quan tenim més de dues alternatives, usam `elif` (contracció de "else if"):

```python
if condicio1:
    # Codi si condicio1 és certa
elif condicio2:
    # Codi si condicio1 és falsa i condicio2 és certa
elif condicio3:
    # Codi si les anteriors són falses i condicio3 és certa
else:
    # Codi si totes les condicions són falses
```

Python avalua les condicions en ordre, de dalt a baix. Quan troba la primera condició certa, executa el seu bloc i ignora la resta. Si cap condició és certa, executa el bloc `else` (si existeix).

Exemple amb la classificació del nivell d'alerta segons l'ús de disc:

```python
espai_usat = 87

if espai_usat >= 95:
    nivell = "CRÍTIC"
    missatge = "Espai gairebé exhaurit!"
elif espai_usat >= 80:
    nivell = "ADVERTÈNCIA"
    missatge = "L'espai comença a escassejar"
elif espai_usat >= 60:
    nivell = "ATENCIÓ"
    missatge = "Ús moderat"
else:
    nivell = "OK"
    missatge = "Espai suficient"

print(f"[{nivell}] {missatge} ({espai_usat}%)")
```

L'ordre de les condicions importa. Fixem-nos que comprovam primer `>= 95`, després `>= 80`, etc. Si ho féssim al revés, no funcionaria correctament:

```python
espai_usat = 97

if espai_usat >= 60:
    print("ATENCIÓ")      # Això s'executaria per a 97!
elif espai_usat >= 80:
    print("ADVERTÈNCIA")  # Mai s'arribaria aquí per a 97
elif espai_usat >= 95:
    print("CRÍTIC")       # Mai s'arribaria aquí per a 97
```

Quan les condicions se solapen, hem de posar primer les més restrictives.

L'`else` és opcional, és a dir, podem tenir `if-elif` sense `else` final. Això vol dir que, si el codi no coincideix amb cap condició, no es fa res.

```python
codi_http = 404

if codi_http == 200:
    print("Petició correcta")
elif codi_http == 404:
    print("Recurs no trobat")
elif codi_http == 500:
    print("Error intern del servidor")
```

Tanmateix, és bona pràctica incloure un `else` per gestionar casos inesperats:

```python
codi_http = 418

if codi_http == 200:
    print("Petició correcta")
elif codi_http == 404:
    print("Recurs no trobat")
elif codi_http == 500:
    print("Error intern del servidor")
else:
    print(f"Codi HTTP no gestionat: {codi_http}")
```

## Condicions niuades

Podem posar estructures `if` dins d'altres estructures `if`:

```python
usuari = "admin"
hora = 22
usuaris_autoritzats = ["admin", "root"]

if usuari in usuaris_autoritzats:
    print(f"Usuari {usuari} reconegut")
    
    if 8 <= hora < 20:
        print("Accés complet concedit")
    else:
        print("Accés limitat (fora d'horari)")
else:
    print("Usuari no autoritzat")
```

Cada nivell d'`if` niuat requereix un nivell addicional d'indentació.

Ara bé, els niuaments profunds fan el codi difícil de llegir. Sovint podem simplificar-los combinant condicions amb `and`:

```python
if usuari in usuaris_autoritzats and 8 <= hora < 20:
    print("Accés complet concedit")
```

> Més endavant veurem la tècnica de "clàusula de guarda" que també ajuda a reduir niuaments.

## Bones pràctiques

En aquest apartat es revisen un seguit de pràctiques que ajuden a escriure codi segur i mantenible:

**Condicions en positiu**

Sempre que sigui possible, escrivim les condicions en positiu perquè són més fàcils d'entendre:

```python
# Manco clar
if not servei_aturat:
    print("El servei funciona")

# Més clar
if servei_actiu:
    print("El servei funciona")
```

**Evitar comparacions redundants amb booleans**

Quan una variable ja és booleana, no cal comparar-la explícitament amb `True` o `False`:

```python
actiu = True

# Redundant
if actiu == True:
    print("Actiu")

# Correcte
if actiu:
    print("Actiu")

# Correcte
if not actiu:
    print("Inactiu")
```

**Aprofitar els valors "falsy"**

Recordem que alguns valors es consideren "falsos" en un context booleà: `0`, `0.0`, `""` (cadena buida), `[]` (llista buida), `{}` (diccionari buit), `None`. Podem aprofitar-ho, per exemple, per comprovar si una llista és buida:

```python
errors = []

# En lloc de comprovar la longitud
if len(errors) > 0:
    print("Hi ha errors")

# Podem fer directament
if errors:
    print("Hi ha errors")
```

Això fa el codi més idiomàtic i llegible.

**Clàusula de guarda (early return)**

Quan escrivim funcions (que veurem al proper article), una tècnica útil és gestionar els casos "especials" primer i sortir aviat. Això redueix els niuaments:

```python
# Amb niuaments (menys clar)
def processar_dades(dades):
    if dades is not None:
        if len(dades) > 0:
            if validar(dades):
                # Processar...
                pass

# Amb clàusules de guarda (més clar)
def processar_dades(dades):
    if dades is None:
        return
    if len(dades) == 0:
        return
    if not validar(dades):
        return
    
    # Processar... (sense niuaments)
```

## L'operador ternari

Per a assignacions condicionals simples, Python ofereix l'**operador ternari** (o expressió condicional):

```python
valor = valor_si_cert if condicio else valor_si_fals
```

Exemple:

```python
edat = 20
categoria = "adult" if edat >= 18 else "menor"
print(categoria)  # adult
```

Això és equivalent a:

```python
edat = 20
if edat >= 18:
    categoria = "adult"
else:
    categoria = "menor"
```

Exemple pràctic amb un valor per defecte:

```python
config_timeout = None
timeout = config_timeout if config_timeout is not None else 30
print(f"Timeout: {timeout} segons")
```

També podem usar l'operador ternari dins un f-string:

```python
connexions = 0
print(f"Hi ha {connexions} {'connexió' if connexions == 1 else 'connexions'}")
```

**Quan no usar-lo**

L'operador ternari és útil per a expressions simples, però no l'hem d'abusar. Si la condició o els valors són complexos, és millor usar un `if-else` tradicional. Donat el següen exemple:

```python
resultat = calcular_a()
  if condicio_complexa and altra_condicio
  else calcular_b() if segona_condicio else calcular_c()
```

És millor usar `if-elif-else`:

```python
if condicio_complexa and altra_condicio:
    resultat = calcular_a()
elif segona_condicio:
    resultat = calcular_b()
else:
    resultat = calcular_c()
```

## L'estructura match-case

L'estructura `match-case` permet comparar un valor contra múltiples patrons de manera elegant:

```python
match valor:
    case patro1:
        # Codi si valor coincideix amb patro1
    case patro2:
        # Codi si valor coincideix amb patro2
    case _:
        # Codi per defecte (si no coincideix cap patró)
```

El patró `_` és el comodí que coincideix amb qualsevol valor (equivalent a l'`else`).

Exemple bàsic:

```python
comanda = "status"

match comanda:
    case "start":
        print("Iniciant el servei...")
    case "stop":
        print("Aturant el servei...")
    case "restart":
        print("Reiniciant el servei...")
    case "status":
        print("Mostrant l'estat del servei...")
    case _:
        print(f"Comanda desconeguda: {comanda}")
```

El mateix codi amb `if-elif-else`:

```python
comanda = "status"

if comanda == "start":
    print("Iniciant el servei...")
elif comanda == "stop":
    print("Aturant el servei...")
elif comanda == "restart":
    print("Reiniciant el servei...")
elif comanda == "status":
    print("Mostrant l'estat del servei...")
else:
    print(f"Comanda desconeguda: {comanda}")
```

Per a comparacions simples com aquesta, `match-case` és més llegible perquè evita repetir `comanda ==` a cada línia.

**Patrons amb múltiples valors**

Podem agrupar diversos patrons amb `|`:

```python
codi_http = 201

match codi_http:
    case 200 | 201 | 204:
        print("Èxit")
    case 400 | 401 | 403 | 404:
        print("Error del client")
    case 500 | 502 | 503:
        print("Error del servidor")
    case _:
        print(f"Codi no categoritzat: {codi_http}")
```

**Patrons amb condicions (guards)**

Podem afegir condicions als patrons amb `if`:

```python
port = 443

match port:
    case p if p < 1024:
        print(f"Port {p}: privilegiat")
    case p if p < 49152:
        print(f"Port {p}: registrat")
    case p:
        print(f"Port {p}: dinàmic/privat")
```

## Diccionaris

Una alternativa elegant a `if-elif-else` i `match-case` és usar un **diccionari** per mapejar valors a accions o resultats. Aquesta tècnica és especialment útil quan tenim molts casos i el codi per a cada cas és similar.

Vegem un exemple de mapeig de codis d'error HTTP a missatges. Comencem amb un estructura `if-elif-else`:

```python
def missatge_http_if(codi):
    if codi == 200:
        return "OK"
    elif codi == 201:
        return "Created"
    elif codi == 400:
        return "Bad Request"
    elif codi == 401:
        return "Unauthorized"
    elif codi == 403:
        return "Forbidden"
    elif codi == 404:
        return "Not Found"
    elif codi == 500:
        return "Internal Server Error"
    else:
        return "Unknown"
```

El mateix codi amb `match-case`:

```python
def missatge_http_match(codi):
    match codi:
        case 200:
            return "OK"
        case 201:
            return "Created"
        case 400:
            return "Bad Request"
        case 401:
            return "Unauthorized"
        case 403:
            return "Forbidden"
        case 404:
            return "Not Found"
        case 500:
            return "Internal Server Error"
        case _:
            return "Unknown"
```

I, finalment, el mateix codi amb un diccionari:

```python
MISSATGES_HTTP = {
    200: "OK",
    201: "Created",
    400: "Bad Request",
    401: "Unauthorized",
    403: "Forbidden",
    404: "Not Found",
    500: "Internal Server Error",
}

def missatge_http_dict(codi):
    return MISSATGES_HTTP.get(codi, "Unknown")
```

La versió amb diccionari és més concisa i fàcil de mantenir: per afegir un nou codi, només hem d'afegir una línia al diccionari.

Vem un altre exemple on mapejarem comandes a funcions:

```python
# Funcions
def iniciar_servei():
    print("Iniciant el servei...")

def aturar_servei():
    print("Aturant el servei...")

def reiniciar_servei():
    print("Reiniciant el servei...")

def mostrar_estat():
    print("Mostrant l'estat del servei...")

# Diccionari que mapeja comandes a funcions
COMANDES = {
    "start": iniciar_servei,
    "stop": aturar_servei,
    "restart": reiniciar_servei,
    "status": mostrar_estat,
}

# Funció principal
def executar_comanda(comanda):
    accio = COMANDES.get(comanda)
    if accio:
        accio()  # Cridam la funció
    else:
        print(f"Comanda desconeguda: {comanda}")

# Ús
executar_comanda("start")    # Iniciant el servei...
executar_comanda("invalid")  # Comanda desconeguda: invalid
```

## Comparació

La següent taula ofereix una guia d'ús de les distintes estructures de control.

| Situació                                        | Recomanació               |
|-------------------------------------------------|---------------------------|
| Poques condicions (2-3)                         | `if-elif-else`            |
| Condicions complexes amb `and`/`or`             | `if-elif-else`            |
| Molts valors simples a comparar                 | `match-case` o diccionari |
| Mapeig directe valor → resultat                 | Diccionari                |
| Mapeig valor → funció a executar                | Diccionari                |
| Patrons amb estructura (tuples, llistes)        | `match-case`              |
| Necessitat de "guards" (condicions als patrons) | `match-case`              |

## Exercicis

Es proposen quatre exercicis pràctics per consolidar els conceptes d'aquest article.

### Exercici 1

**Classificador de ports**

Objectiu: Classificar un port segons el seu rang i identificar-lo si és conegut.

1. Crea un script anomenat `classificador_ports.py`.
2. Demana a l'usuari un número de port.
3. Classifica'l segons el rang:
   - 0-1023: Ports del sistema (privilegiats)
   - 1024-49151: Ports registrats
   - 49152-65535: Ports dinàmics o privats
4. Si el port és un dels coneguts (22=SSH, 80=HTTP, 443=HTTPS, 3306=MySQL, 5432=PostgreSQL), mostra'n el nom.
5. Usa un diccionari per mapejar els ports coneguts.

> Pista: primer comprova el rang, després consulta el diccionari de ports coneguts.

{{< details summary="Resposta" >}}

Exemple d'script `classificador_ports.py`:

```python
#!/usr/bin/env python3
"""Classifica ports segons el rang i identifica els coneguts."""

# Diccionari de ports coneguts
PORTS_CONEGUTS = {
    20: "FTP (dades)",
    21: "FTP (control)",
    22: "SSH",
    23: "Telnet",
    25: "SMTP",
    53: "DNS",
    80: "HTTP",
    443: "HTTPS",
    3306: "MySQL",
    5432: "PostgreSQL",
    6379: "Redis",
    8080: "HTTP alternatiu",
}

# Demanar el port
port = int(input("Introdueix un número de port: "))

# Validar rang
if port < 0 or port > 65535:
    print(f"Error: {port} no és un port vàlid (0-65535)")
else:
    # Classificar per rang
    if port <= 1023:
        categoria = "Port del sistema (privilegiat)"
    elif port <= 49151:
        categoria = "Port registrat"
    else:
        categoria = "Port dinàmic/privat"
    
    print(f"Port {port}: {categoria}")
    
    # Identificar si és conegut
    nom_servei = PORTS_CONEGUTS.get(port)
    if nom_servei:
        print(f"Servei associat: {nom_servei}")
```

{{< /details >}}

### Exercici 2

**Monitor d'espai en disc**

Objectiu: Mostrar alertes de diferents nivells segons l'ús de disc.

1. Crea un script anomenat `monitor_disc.py`.
2. Defineix constants per als llindars: `OK` (`<70%`), `ATENCIÓ` (`70-84%`), `ADVERTÈNCIA` (`85-94%`), `CRÍTIC` (`>=95%`).
3. Demana a l'usuari el percentatge d'ús actual.
4. Mostra el nivell d'alerta amb un missatge adequat.
5. Si el nivell és `ADVERTÈNCIA` o `CRÍTIC`, suggereix accions.

> Pista: recorda l'ordre de les condicions quan els rangs se solapen.

{{< details summary="Resposta" >}}

Exemple d'script `monitor_disc.py`:

```python
#!/usr/bin/env python3
"""Monitor d'espai en disc amb nivells d'alerta."""

# Llindars (en percentatge)
LLINDAR_ATENCIO = 70
LLINDAR_ADVERTENCIA = 85
LLINDAR_CRITIC = 95

# Demanar l'ús actual
us = float(input("Percentatge d'ús de disc: "))

# Validar entrada
if us < 0 or us > 100:
    print("Error: el percentatge ha d'estar entre 0 i 100")
else:
    # Determinar nivell d'alerta
    if us >= LLINDAR_CRITIC:
        nivell = "CRÍTIC"
        missatge = "Espai pràcticament exhaurit!"
    elif us >= LLINDAR_ADVERTENCIA:
        nivell = "ADVERTÈNCIA"
        missatge = "Espai baix, cal actuar aviat"
    elif us >= LLINDAR_ATENCIO:
        nivell = "ATENCIÓ"
        missatge = "Ús moderat-alt"
    else:
        nivell = "OK"
        missatge = "Espai suficient"
    
    # Mostrar resultat
    print()
    print(f"[{nivell}] {missatge}")
    print(f"   Ús actual: {us:.1f}%")
    
    # Suggeriments per a nivells alts
    if us >= LLINDAR_ADVERTENCIA:
        print()
        print("Accions suggerides:")
        print("  - Eliminar fitxers temporals")
        print("  - Revisar logs antics")
        print("  - Buidar la paperera")
        if us >= LLINDAR_CRITIC:
            print("  - URGENT: Alliberar espai immediatament!")
```

{{< /details >}}

### Exercici 3

**Validador d'adreces IP**

Objectiu: Validar el format d'una adreça IPv4 i classificar-la.

1. Crea un script anomenat `validador_ip.py`.
2. Demana una adreça IP versió 4 en format `X.X.X.X`.
3. Comprova que:
   - Tengui exactament 4 parts separades per punts
   - Cada part sigui un nombre entre 0 i 255
4. Si és vàlida, classifica-la:
   - `127.x.x.x`: Localhost
   - `10.x.x.x`: Privada classe A
   - `172.16.x.x` - `172.31.x.x`: Privada classe B
   - `192.168.x.x`: Privada classe C
   - Altres: Pública

> Pista: usa `split(".")` per separar les parts i comprova cada una.

{{< details summary="Resposta" >}}

Exemple d'script `validador_ip.py`:

```python
#!/usr/bin/env python3
"""Valida i classifica adreces IPv4."""

# Demanar l'adreça IP
ip = input("Introdueix una adreça IP: ")

# Separar per punts
parts = ip.split(".")

# Validar que hi hagi 4 parts
if len(parts) != 4:
    print(f"Error: l'adreça ha de tenir 4 octets, n'has posat {len(parts)}")
else:
    # Validar cada part
    valid = True
    octets = []
    
    for i, part in enumerate(parts):
        # Comprovar que sigui un nombre
        if not part.isdigit():
            print(f"Error: '{part}' no és un nombre vàlid")
            valid = False
            break
        
        valor = int(part)
        
        # Comprovar rang
        if valor < 0 or valor > 255:
            print(f"Error: {valor} fora de rang (0-255)")
            valid = False
            break
        
        octets.append(valor)
    
    if valid:
        print(f"Adreça IP vàlida: {ip}")
        
        # Classificar
        primer = octets[0]
        segon = octets[1]
        
        if primer == 127:
            tipus = "Localhost (loopback)"
        elif primer == 10:
            tipus = "Privada (classe A: 10.0.0.0/8)"
        elif primer == 172 and 16 <= segon <= 31:
            tipus = "Privada (classe B: 172.16.0.0/12)"
        elif primer == 192 and segon == 168:
            tipus = "Privada (classe C: 192.168.0.0/16)"
        elif primer == 169 and segon == 254:
            tipus = "Link-local (APIPA)"
        elif primer >= 224 and primer <= 239:
            tipus = "Multicast"
        elif primer >= 240:
            tipus = "Reservada"
        else:
            tipus = "Pública"
        
        print(f"Tipus: {tipus}")
```

{{< /details >}}

### Exercici 4

**Intèrpret de comandes**

Objectiu: Crear un menú interactiu que respongui a diferents comandes.

1. Crea un script anomenat `interpret_comandes.py`.
2. Defineix un diccionari amb les comandes disponibles i les seves descripcions.
3. Mostra un prompt i espera que l'usuari introdueixi una comanda.
4. Usa `match-case` per processar les comandes: `help`, `status`, `version`, `list`, `clear`, `exit`.
5. La comanda `help` ha de mostrar totes les comandes disponibles (usa el diccionari).
6. La comanda `exit` ha de mostrar un missatge de comiat i acabar.
7. Inventa una sortida breu però plausible per a cada comanda.

> Pista: usa un bucle `while True` per mantenir el programa en execució fins que l'usuari escrigui "exit".

{{< details summary="Resposta" >}}

Exemple d'script `interpret_comandes.py`:

```python
#!/usr/bin/env python3
"""Intèrpret de comandes simple."""

# Diccionari de comandes i descripcions
COMANDES = {
    "help": "Mostra aquesta ajuda",
    "status": "Mostra l'estat del sistema",
    "version": "Mostra la versió",
    "list": "Llista els serveis disponibles",
    "clear": "Neteja la pantalla",
    "exit": "Surt de l'intèrpret",
}

# Informació del sistema (simulada)
VERSIO = "1.0.0"
SERVEIS = ["nginx", "postgresql", "redis", "docker"]

print("Intèrpret de comandes v" + VERSIO)
print("Escriu 'help' per veure les comandes disponibles.")
print()

while True:
    # Llegir comanda
    entrada = input("> ").strip().lower()
    
    # Ignorar entrades buides
    if not entrada:
        continue
    
    # Processar comanda
    match entrada:
        case "help":
            print("Comandes disponibles:")
            for cmd, desc in COMANDES.items():
                print(f"  {cmd:10} - {desc}")
        
        case "status":
            print("Estat del sistema:")
            print("  CPU:    45%")
            print("  RAM:    62%")
            print("  Disc:   78%")
            print("  Estat:  Operatiu")
        
        case "version":
            print(f"Versió: {VERSIO}")
        
        case "list":
            print("Serveis disponibles:")
            for servei in SERVEIS:
                print(f"  - {servei}")
        
        case "clear":
            # Imprimir línies en blanc per "netejar"
            print("\n" * 50)
        
        case "exit" | "quit" | "q":
            print("Fins aviat!")
            break
        
        case _:
            print(f"Comanda desconeguda: '{entrada}'")
            print("Escriu 'help' per veure les comandes disponibles.")
    
    print()  # Línia en blanc entre comandes
```

{{< /details >}}
