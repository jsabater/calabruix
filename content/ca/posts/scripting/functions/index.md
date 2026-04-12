---
title: "Funcions"
date: 2026-04-05
lastmod: 2026-04-05
description: "Definició de funcions, paràmetres, retorn de valors i documentació amb docstrings"
summary: "Definició de funcions, paràmetres, retorn de valors i documentació amb docstrings"
categories: ["teaching"]
tags: ["python", "scripting"]
series: ["Scripting"]
series_order: 7
weight: 70
slug: funcions
---

Fins ara hem escrit codi que s'executa de dalt a baix, amb bucles i condicions que controlen el flux. Però a mesura que els nostres scripts creixen, ens trobam repetint blocs de codi similars en diversos llocs. Les **funcions** ens permeten encapsular codi en blocs reutilitzables amb un nom, fent els programes més organitzats, llegibles i fàcils de mantenir.

## Raó de ser

Imaginem que volem mostrar un separador visual en diversos punts del nostre script. Sense funcions repetim el codi cada vegada:

```python
print("=" * 40)
print("Secció 1: Estat del sistema")
print("=" * 40)

# ... codi ...

print("=" * 40)
print("Secció 2: Ús de recursos")
print("=" * 40)

# ... més codi ...

print("=" * 40)
print("Secció 3: Alertes")
print("=" * 40)

# ... i més codi ...
```

Si volem canviar l'amplada del separador de 40 a 50, hem de modificar-ho en tres llocs. Amb una funció:

```python
def mostrar_seccio(titol):
    print("=" * 40)
    print(titol)
    print("=" * 40)

mostrar_seccio("Secció 1: Estat del sistema")

# ... codi ...

mostrar_seccio("Secció 2: Ús de recursos")

# ... més codi ...

mostrar_seccio("Secció 3: Alertes")

# ... i més codi ...
```

Ara el codi és més curt, més clar, i si volem canviar el format només hem de modificar la funció.

Les funcions ens aporten:

- Reutilització, car escrivim el codi una vegada i l'usam moltes.
- Organització, car dividim el programa en blocs amb propòsits clars.
- Mantenibilitat, car els canvis es fan en un sol lloc.
- Llegibilitat, car el codi principal queda més net i fàcil d'entendre.

## Definir i cridar

Definim una funció amb la paraula clau `def`, seguida del nom, parèntesis i dos punts:

```python
def nom_funcio():
    # Codi de la funció
    # indentat amb 4 espais
    pass
```

> `pass` és una instrucció buida que no fa res.

Per executar la funció, la **cridam** escrivint el seu nom seguit de parèntesis:

```python
nom_funcio()
```

Exemple:

```python
def mostrar_benvinguda():
    print("=" * 40)
    print("Benvingut al sistema de monitoratge")
    print("=" * 40)

# Cridar la funció
mostrar_benvinguda()
```

Sortida:

```
========================================
Benvingut al sistema de monitoratge
========================================
```

**Convencions de noms**

Seguim les mateixes convencions que vàrem adoptar per a les variables:

- Usam `snake_case`: paraules en minúscules separades per guions baixos.
- Triam noms descriptius que indiquin què fa la funció.
- Solem usar verbs: `mostrar_informe()`, `calcular_percentatge()`, `validar_entrada()`.

Exemples de noms a evitar, car són poc descriptius:

```python
def func1():
    pass

def fer_coses():
    pass
```

## Paràmetres i arguments

Les funcions poden rebre informació a través de **paràmetres**. Els paràmetres es defineixen dins dels parèntesis:

```python
def saludar(nom):
    print(f"Hola, {nom}!")

saludar("Anna")   # Hola, Anna!
saludar("Pere")   # Hola, Pere!
```

Tècnicament parlant:

- **Paràmetre:** la variable definida a la funció (`nom` a l'exemple), que s'inicialitza quan cridam la funció.
- **Argument:** el valor que passam quan cridam la funció (`"Anna"` i `"Pere"` a l'exemple).

Podem definir diversos paràmetres separats per comes:

```python
def mostrar_info_servidor(nom, ip, port):
    print(f"Servidor: {nom}")
    print(f"  IP:   {ip}")
    print(f"  Port: {port}")

mostrar_info_servidor("web01", "192.168.1.10", 80)
```

Sortida:

```
Servidor: web01
  IP:   192.168.1.10
  Port: 80
```

L'ordre dels arguments ha de coincidir amb l'ordre dels paràmetres.

**Exemple pràctic**

Anem a revisar un exemple de codi que hem usat en anteriors articles per formatar una mida, però usant funcions:

```python
def formatar_bytes(bytes_valor):
    if bytes_valor >= 1024 ** 3:
        valor = bytes_valor / (1024 ** 3)
        unitat = "GB"
    elif bytes_valor >= 1024 ** 2:
        valor = bytes_valor / (1024 ** 2)
        unitat = "MB"
    elif bytes_valor >= 1024:
        valor = bytes_valor / 1024
        unitat = "KB"
    else:
        valor = bytes_valor
        unitat = "bytes"
    
    print(f"{valor:.2f} {unitat}")

formatar_bytes(1536)           # 1.50 KB
formatar_bytes(2621440)        # 2.50 MB
formatar_bytes(5368709120)     # 5.00 GB
```

## Retornar valors

Les funcions anteriors mostren informació per pantalla, però sovint volem que la funció **calculi un valor** i ens el retorni per usar-lo després. Per això usam `return`:

```python
def sumar(a, b):
    resultat = a + b
    return resultat

total = sumar(5, 3)
print(total)  # 8
```

Quan Python troba `return`, la funció acaba immediatament i retorna el valor especificat.

Vegem un segon exemple, senzill, per calcular el percentatge d'espai usat:

```python
def calcular_percentatge(part, total):
    if total == 0:
        return 0
    return (part / total) * 100

espai_usat = 350
espai_total = 500

percentatge = calcular_percentatge(espai_usat, espai_total)
print(f"Ús de disc: {percentatge:.1f}%")  # Ús de disc: 70.0%
```

**return vs print**

És important entendre la diferència entre `return` i `print()`.:

- `print()` és una funció integrada que mostra un valor per pantalla però no el retorna.
- `return` és una instrucció reservada que retorna un valor que podem emmagatzemar o usar en expressions.

```python
def amb_print(x):
    print(x * 2)

def amb_return(x):
    return x * 2

# amb_print mostra el resultat però no el podem usar
resultat1 = amb_print(5)   # Mostra: 10
print(resultat1)           # None (no ha retornat res)

# amb_return retorna el resultat i el podem usar
resultat2 = amb_return(5)  # No mostra res
print(resultat2)           # 10
print(resultat2 + 3)       # 13
```

**Múltiples valors**

Podem retornar múltiples valors com una tupla:

```python
def analitzar_llista(llista):
    minim = min(llista)
    maxim = max(llista)
    mitjana = sum(llista) / len(llista)
    return minim, maxim, mitjana

valors = [10, 25, 8, 42, 15]
min_value, max_value, avg_value = analitzar_llista(valors)

print(f"Mínim: {min_value}")    # Mínim: 8
print(f"Màxim: {max_value}")    # Màxim: 42
print(f"Mitjana: {avg_value}")  # Mitjana: 20.0
```

**Retorn implícit**

Si una funció no té `return` o té `return` sense valor, retorna `None`:

```python
def sense_return():
    print("Hola")

resultat = sense_return()
print(resultat)  # None
```

**Exemple pràctic**

De nou, revisem un exemple de codi que hem usat en anteriors articles per comprovar si una cadena es una IP vàlida:

```python
def es_ip_valida(ip):
    """Comprova si una cadena té format d'IP vàlida."""
    parts = ip.split(".")
    
    if len(parts) != 4:
        return False
    
    for part in parts:
        if not part.isdigit():
            return False
        if not 0 <= int(part) <= 255:
            return False
    
    return True

# Ús
print(es_ip_valida("192.168.1.10"))   # True
print(es_ip_valida("256.1.2.3"))      # False
print(es_ip_valida("192.168.1"))      # False
```

## Paràmetres per defecte

Podem assignar valors per defecte als paràmetres. Si no passam un argument per a aquest paràmetre, s'usa el valor per defecte:

```python
def saludar(nom, salutacio="Hola"):
    print(f"{salutacio}, {nom}!")

saludar("Anna")              # Hola, Anna!
saludar("Pere", "Bon dia")   # Bon dia, Pere!
```

**Ordre dels paràmetres**

Els paràmetres amb valor per defecte han d'anar **després** dels paràmetres obligatoris. El següent exemple és correcte perquè la funció `connectar()` té ambdós paràmetres opcionals (amb valor per defecte) després del paràmetre obligatori `host`:

```python
def connectar(host, port=22, timeout=30):
    print(f"Connectant a {host}:{port} (timeout: {timeout}s)")
```

En canvi, el següent exemple és incorrecte perquè la funció `connectar()` té el paràmetre obligatori `timeout` després del paràmetre opcional `port`:

```python
def connectar(host, port=22, timeout):  # SyntaxError
    pass
```

**Exemple pràctic**

Anem a posar en pràctica l'ús de paràmetres obligatoris i opcionals amb un exemple de funció de representació d'una configuració:

```python
def mostrar_taula(dades, titol="Servidor", amplada=40, separador="-"):
    """Mostra dades en format de taula."""
    print(separador * amplada)
    print(titol.center(amplada))
    print(separador * amplada)
    for clau, valor in dades.items():
        print(f"  {clau}: {valor}")
    print(separador * amplada)
    print()

servidor = {"nom": "web01", "ip": "192.168.1.10", "port": 80}

# Amb valors per defecte
mostrar_taula(servidor)

# Amb paràmetres personalitzats
mostrar_taula(servidor, titol="Proxy", amplada=30, separador="=")
```

Sortida:

```
----------------------------------------
               Servidor                  
----------------------------------------
  nom: web01
  ip: 192.168.1.10
  port: 80
----------------------------------------

==============================
            Proxy         
==============================
  nom: web01
  ip: 192.168.1.10
  port: 80
==============================
```

## Arguments amb nom

Quan cridam una funció, podem passar els arguments pel seu nom en lloc de la posició. Aquests arguments es coneixen com a paràmetres nombrats, o *keyword arguments*. Per exemple, donada la següent funció:

```python
def crear_usuari(nom, uid, shell, home):
    print(f"Creant usuari {nom} (UID: {uid})")
    print(f"  Shell: {shell}")
    print(f"  Home:  {home}")
```

Podem passar els paràmetres per posició, recordant l'ordre:

```python
crear_usuari("anna", 1001, "/bin/bash", "/home/anna")
```

O els podem passar per nom, més clar i on l'ordre no importa:

```python
crear_usuari(
    nom="pere",
    uid=1002,
    home="/home/pere",
    shell="/bin/zsh"
)
```

**Combinar arguments posicionals i amb nom**

Podem combinar els arguments posicionals i els arguments amb nom en una funció, però els posicionals han d'anar primer:

```python
def connectar(host, port, timeout=30, ssl=False):
    print(f"Host: {host}, Port: {port}, Timeout: {timeout}, SSL: {ssl}")

# Correcte
connectar("exemple.com", 443, ssl=True)
connectar("exemple.com", 443, timeout=60, ssl=True)

# Incorrecte
connectar(host="exemple.com", 443)  # SyntaxError
```

**Exemple pràctic**

La següent funció ens ofereix un interessant nivell de flexibilitat a l'hora d'enviar alertes:

```python
def enviar_alerta(
    missatge,
    nivell="INFO",
    destinatari="admin@exemple.com",
    urgent=False):
    """Envia una alerta amb diferents nivells de prioritat."""
    prefix = "URGENT: " if urgent else ""
    print(f"[{nivell}] {prefix}{missatge}")
    print(f"  Enviant a: {destinatari}")

# Diferents maneres de cridar-la
enviar_alerta("Sistema operatiu")
enviar_alerta("Espai en disc baix", nivell="WARNING")
enviar_alerta("Servei caigut", nivell="ERROR", urgent=True)
enviar_alerta("Backup completat", destinatari="backups@exemple.com")
```

## Paràmetres variables

A vegades volem que una funció accepti un nombre variable d'arguments.

**Arguments posicionals variables**

El paràmetre `*args` recull tots els arguments posicionals extra en una tupla. La paraula de referència `args` vol dir *arguments* i no és més que una convenció; el que importa és l'asterisc. Podem usar el nom de paràmetre o variable que vulguem. En el següent exemple usam `nombres` en comptes d'`args`:

```python
def sumar_tots(*nombres):
    total = 0
    for n in nombres:
        total += n
    return total

print(sumar_tots(1, 2))           # 3
print(sumar_tots(1, 2, 3, 4, 5))  # 15
print(sumar_tots(10))             # 10
```

Vegem un altre exemple amb una funció de logging:

```python
def log(*missatges, nivell="INFO"):
    prefix = f"[{nivell}]"
    text = " ".join(str(m) for m in missatges)
    print(f"{prefix} {text}")

log("Servidor", "iniciat")
log("Port", 8080, "obert")
log("Error", "de", "connexió", nivell="ERROR")
```

Sortida:

```
[INFO] Servidor iniciat
[INFO] Port 8080 obert
[ERROR] Error de connexió
```

> Podem combinar l'ús de `*args` i paràmetres posicionals: `def f(*args, x, y)`.

**Arguments amb nom variables**

El paràmetre `**kwargs` recull tots els arguments amb nom extra en un diccionari, on les claus són els noms dels paràmetres i els valors són els arguments o valors proporcionats. La paraula de referència `kwargs` vol dir *keyword arguments* i no és més que una convenció; el que importa és el doble asterisc. Podem usar el nom de paràmetre o variable que vulguem.

En el següent exemple usam `opcions` en comptes de `kwargs`:

```python
def mostrar_config(**opcions):
    print("Configuració:")
    for clau, valor in opcions.items():
        print(f"  {clau}: {valor}")

mostrar_config(host="localhost", port=8080, debug=True)
```

Sortida:

```
Configuració:
  host: localhost
  port: 8080
  debug: True
```

**Combinar paràmetres normals amb `*args` i `**kwargs`**

Podem combinar paràmetres normals amb `*args` i `**kwargs`, però hem de respectar el següent ordre:

1. Paràmetres normals.
2. `*args`.
3. Paràmetres amb valor per defecte.
4. `**kwargs`

Per exemple:

```python
def configurar_servei(nom, *ports, actiu=True, **opcions):
    print(f"Servei: {nom}")
    print(f"Ports: {ports}")
    print(f"Actiu: {actiu}")
    print(f"Opcions: {opcions}")

configurar_servei("web", 80, 443, timeout=30, max_conn=100)
```

Sortida:

```
Servei: web
Ports: (80, 443)
Actiu: True
Opcions: {'timeout': 30, 'max_conn': 100}
```

**Exemple pràctic**

Vegem un exemple pràctic de funció amb paràmetres variables:

```python
def configurar_servei(nom, *ports, **opcions):
    """
    Configura un servei amb ports i opcions variables.
    
    :param nom: Nom del servei.
    :param ports: Ports on escoltarà (nombre variable).
    :param opcions: Opcions addicionals (clau=valor).
    """
    print(f"Configurant servei: {nom}")
    
    # Mostrar ports
    if ports:
        print(f"  Ports: {', '.join(str(p) for p in ports)}")
    else:
        print("  Ports: cap especificat")
    
    # Mostrar opcions
    if opcions:
        print("  Opcions:")
        for clau, valor in opcions.items():
            print(f"    {clau}: {valor}")
    else:
        print("  Opcions: cap especificada")


# Diferents maneres de cridar la funció
configurar_servei("nginx")

print()

configurar_servei("apache", 80, 443)

print()

configurar_servei("postgresql", 5432, timeout=30, max_connections=100, ssl=True)
```

Sortida:

```
Configurant servei: nginx
  Ports: cap especificat
  Opcions: cap especificada

Configurant servei: apache
  Ports: 80, 443
  Opcions: cap especificada

Configurant servei: postgresql
  Ports: 5432
  Opcions:
    timeout: 30
    max_connections: 100
    ssl: True
```

## Docstrings

Un **docstring** és una cadena de text que documenta què fa una funció. Es posa just després de la línia `def`:

```python
def calcular_percentatge(part, total):
    """Calcula el percentatge que representa 'part' respecte a 'total'."""
    if total == 0:
        return 0
    return (part / total) * 100
```

**Format recomanat**

Per a funcions més complexes, és útil documentar els paràmetres i el valor de retorn:

```python
def formatar_mida(bytes_valor, decimals=2):
    """
    Converteix bytes a una cadena amb la unitat adequada.
    
    :param bytes_valor: Mida en bytes a convertir.
    :param decimals: Nombre de decimals a mostrar (per defecte 2).
    :return: Cadena formatada amb la mida i la unitat.
    
    Exemple:
        >>> formatar_mida(1536)
        '1.50 KB'
        >>> formatar_mida(5368709120, decimals=0)
        '5 GB'
    """
    unitats = ["bytes", "KB", "MB", "GB", "TB"]
    
    for unitat in unitats:
        if bytes_valor < 1024:
            return f"{bytes_valor:.{decimals}f} {unitat}"
        bytes_valor /= 1024
    
    return f"{bytes_valor:.{decimals}f} PB"
```

És una bona pràctica usar reStructuredText[^1] (reST) dins el docstring per a donar format al docstring. Els atributs `:param:` i `:return:` s'usen per a indicar el tipus i propòsit de cada paràmetre i el tipus retornat per la funció, respectivament.

[^1]: [PEP 257](https://peps.python.org/pep-0257/) defineix les convencions a l'hora d'usar [reST](https://restructuredtext.org) a docstring amb Python.


**Accedir a la documentació**

Podem veure el docstring d'una funció amb `help()` o accedint a l'atribut `__doc__`:

```python
>>> help(formatar_mida)
Help on function formatar_mida in module __main__:

formatar_mida(bytes_valor, decimals=2)
    Converteix bytes a una cadena amb la unitat adequada.
    
    :param bytes_valor: Mida en bytes a convertir.
    ...

>>> print(formatar_mida.__doc__)
    Converteix bytes a una cadena amb la unitat adequada.
    ...
```

## Àmbit de les variables

L'**àmbit** o *scope* d'una variable determina on és visible i accessible. Python té dos àmbits principals:

1. Variables locals.
2. Variables globals.

**Variables locals**

Les variables creades dins una funció són **locals**, és a dir, només existeixen dins la funció. Exemple:

```python
def exemple():
    variable_local = 10
    print(variable_local)

exemple()  # 10
print(variable_local)  # NameError
```

**Variables globals**

Les variables creades fora de qualsevol funció són **globals**, és a dir, són visibles a tot el mòdul. Exemple:

```python
variable_global = "Hola"

def exemple():
    print(variable_global)  # Pot llegir variables globals

exemple()  # Hola
print(variable_global)  # Hola
```

**Modificar variables globals**

Si intentam modificar una variable global dins una funció, Python crea una variable local nova:

```python
comptador = 0

def incrementar():
    # Error! Python pensa que és local
    # però no té valor inicial
    comptador = comptador + 1

incrementar()  # UnboundLocalError
```

Podem usar `global` per indicar que volem modificar la variable global:

```python
comptador = 0

def incrementar():
    global comptador
    comptador = comptador + 1

incrementar()
print(comptador)  # 1
```

{{< alert >}}
Evitau usar `global`. El codi és més bo de seguir i depurar quan passam valors com a paràmetres i retornam resultats.
{{< /alert >}}

**Alternativa: passar i retornar**

En comptes d'usar variables globals, és millor passar valors com a paràmetre i retornar resultats. Exemple:

```python
def incrementar(comptador):
    return comptador + 1

valor = 0
valor = incrementar(valor)
print(valor)  # 1
valor = incrementar(valor)
print(valor)  # 2
```

## Bones pràctiques

En aquesta secció veurem quatre bones pràctiques que ens ajuden a escriure codi més robust i mantenible:

1. Funcions petites i amb un sol propòsit.
2. Noms descriptius.
3. Evitar efectes secundaris.
4. Clàusules de guarda (early return)

**Funcions petites i amb un sol propòsit**

Cada funció hauria de fer una sola cosa i fer-la bé. Exemple de funció que fa massa coses:

```python
def processar_servidor(nom, ip, port):
    # Valida les dades
    # Es connecta al servidor
    # Comprova l'estat
    # Genera un informe
    # Envia una alerta si cal
    pass
```

És millor definir funcions separades:

```python
def validar_dades(nom, ip, port):
    pass

def connectar(ip, port):
    pass

def comprovar_estat(connexio):
    pass

def generar_informe(estat):
    pass

def enviar_alerta(informe):
    pass
```

**Noms descriptius**

El nom de la funció hauria d'indicar clarament què fa. Exemples:

```python
def processar_fitxer_log(ruta):
    pass

def calcular_espai_lliure(disc):
    pass

def es_usuari_autoritzat(nom_usuari):
    pass
```

**Evitar efectes secundaris**

Una funció hauria de fer el que diu el seu nom i poca cosa més. Els **efectes secundaris**, e.g.,  modificar variables globals, imprimir, escriure fitxers, etc., haurien de ser explícits. Per exemple, en comptes de modificar la variable global `usuaris`, la següent funció rep tant la llista com el nou nom d'usuari i en retorna el resultat:

```python
usuaris = []

def afegir_usuari(llista_usuaris, nom):
    return llista_usuaris + [nom]

usuaris = afegir_usuari(usuaris, "anna")
```

**Clàusules de guarda**

Les clàusules de guarda són comprovacions condicionals gestionen els casos especials al principi per evitar niuaments (early return). Per exemple, donada la següent funció amb niuaments:

```python
def validar(dades):
    ...  # Codi que valida les dades

def processar(dades):
    if dades is not None:
        if len(dades) > 0:
            if validar(dades):
                ...  # Codi que processa les dades
                return resultat
    
    return None  # Algun if no es compleix
```

Amb clàusules de guarda ens queda un codi més clar i eficient:

```python
def processar(dades):
    if dades is None:
        return None
    if len(dades) == 0:
        return None
    if not validar(dades):
        return None
    
    ...  # Codi que processa les dades
    return resultat
```

## Exercicis

Es proposen quatre exercicis pràctics per consolidar els conceptes d'aquest article.

### Exercici 1

**Generador de contrasenyes**

Objectiu: Crear funcions per generar contrasenyes aleatòries amb diferents nivells de complexitat.

1. Crea un script anomenat `generador_contrasenyes.py`.
2. Implementa una funció `generar_contrasenya()` que accepti:
   - `longitud`: nombre de caràcters (per defecte 12)
   - `majuscules`: si inclou majúscules (per defecte True)
   - `numeros`: si inclou números (per defecte True)
   - `simbols`: si inclou símbols (per defecte False)
3. Implementa una funció `avaluar_fortalesa()` que retorni "feble", "mitjana" o "forta" segons la longitud i varietat de caràcters.
4. Documenta les funcions amb docstrings complets.
5. Genera diverses contrasenyes amb diferents configuracions per demostrar l'ús.

> Pista: usa el mòdul `random` i la funció `random.choice()` per triar caràcters aleatoris d'una cadena.

{{< details summary="Resposta" >}}

Exemple d'script `generador_contrasenyes.py`:

```python
#!/usr/bin/env python3
"""
Generador de contrasenyes amb opcions de complexitat.

Permet generar contrasenyes aleatòries amb control sobre
els tipus de caràcters inclosos i avaluar-ne la fortalesa.
"""

import random
import string


def generar_contrasenya(longitud=12, majuscules=True, numeros=True, simbols=False):
    """
    Genera una contrasenya aleatòria.
    
    :param longitud: Nombre de caràcters (per defecte 12).
    :param majuscules: Inclou majúscules (per defecte True).
    :param numeros: Inclou números (per defecte True).
    :param simbols: Inclou símbols (per defecte False).
    :return: Contrasenya generada.
    """
    # Construir el conjunt de caràcters disponibles
    caracters = string.ascii_lowercase  # Sempre incloem minúscules
    
    if majuscules:
        caracters += string.ascii_uppercase
    if numeros:
        caracters += string.digits
    if simbols:
        caracters += "!@#$%^&*()-_=+[]{}|;:,.<>?"
    
    # Generar la contrasenya
    contrasenya = ""
    for _ in range(longitud):
        contrasenya += random.choice(caracters)
    
    return contrasenya


def avaluar_fortalesa(contrasenya):
    """
    Avalua la fortalesa d'una contrasenya.
    
    :param contrasenya: Contrasenya a avaluar.
    :return: "feble", "mitjana" o "forta".
    
    Criteris:
    - Feble: menys de 8 caràcters o només un tipus de caràcter.
    - Mitjana: 8-11 caràcters amb almenys 2 tipus de caràcters.
    - Forta: 12+ caràcters amb almenys 3 tipus de caràcters.
    """
    longitud = len(contrasenya)
    
    # Comptar tipus de caràcters presents
    te_minuscules = any(c in string.ascii_lowercase for c in contrasenya)
    te_majuscules = any(c in string.ascii_uppercase for c in contrasenya)
    te_numeros = any(c in string.digits for c in contrasenya)
    te_simbols = any(c in "!@#$%^&*()-_=+[]{}|;:,.<>?" for c in contrasenya)
    
    tipus_caracters = sum([te_minuscules, te_majuscules, te_numeros, te_simbols])
    
    # Avaluar fortalesa
    if longitud < 8 or tipus_caracters < 2:
        return "feble"
    elif longitud >= 12 and tipus_caracters >= 3:
        return "forta"
    else:
        return "mitjana"


def mostrar_contrasenya(contrasenya):
    """Mostra una contrasenya amb la seva avaluació."""
    fortalesa = avaluar_fortalesa(contrasenya)
    
    print(f"  {contrasenya}  ({len(contrasenya)} cars.) és {fortalesa}.")


if __name__ == "__main__":
    print("=== Generador de contrasenyes ===")
    print()
    
    print("Contrasenyes per defecte (12 cars., majúscules i números):")
    for _ in range(3):
        pwd = generar_contrasenya()
        mostrar_contrasenya(pwd)
    
    print()
    print("Contrasenyes curtes (8 cars., només minúscules):")
    for _ in range(3):
        pwd = generar_contrasenya(longitud=8, majuscules=False, numeros=False)
        mostrar_contrasenya(pwd)
    
    print()
    print("Contrasenyes fortes (16 cars., amb símbols):")
    for _ in range(3):
        pwd = generar_contrasenya(longitud=16, simbols=True)
        mostrar_contrasenya(pwd)
    
    print()
    print("Contrasenyes molt llargues (24 cars., tots els caràcters):")
    for _ in range(3):
        pwd = generar_contrasenya(longitud=24, simbols=True)
        mostrar_contrasenya(pwd)
```

{{< /details >}}

### Exercici 2

**Validador d'entrada**

Objectiu: Crear una funció que validi i converteixi entrada de l'usuari.

1. Crea un script anomenat `validador.py`.
2. Implementa una funció `llegir_enter()` que:
   - Demani un nombre a l'usuari
   - Validi que sigui un enter
   - Accepti un rang opcional (mínim, màxim)
   - Accepti un valor per defecte si l'usuari prem Enter
   - Reintenti si l'entrada no és vàlida
3. Usa la funció per demanar un port (1-65535) i un timeout (per defecte 30).

> Pista: usa un bucle `while` dins la funció per reintentar.

{{< details summary="Resposta" >}}

Exemple d'script `validador.py`:

```python
#!/usr/bin/env python3
"""Funcions per validar entrada de l'usuari."""


def llegir_enter(prompt, minim=None, maxim=None, defecte=None):
    """
    Demana un nombre enter a l'usuari amb validació.
    
    :param prompt: Missatge a mostrar.
    :param minim: Valor mínim permès (opcional).
    :param maxim: Valor màxim permès (opcional).
    :param defecte: Valor per defecte si l'usuari no escriu res (opcional).
    :return: El nombre enter validat.
    """
    while True:
        # Construir el prompt amb informació addicional
        prompt_complet = prompt
        if defecte is not None:
            prompt_complet += f" [{defecte}]"
        prompt_complet += ": "
        
        entrada = input(prompt_complet).strip()
        
        # Valor per defecte
        if entrada == "" and defecte is not None:
            return defecte
        
        # Validar que sigui un enter
        if not entrada.lstrip("-").isdigit():
            print("Error: has d'introduir un nombre enter.")
            continue
        
        valor = int(entrada)
        
        # Validar rang
        if minim is not None and valor < minim:
            print(f"Error: el valor ha de ser almenys {minim}.")
            continue
        
        if maxim is not None and valor > maxim:
            print(f"Error: el valor ha de ser com a màxim {maxim}.")
            continue
        
        return valor


def llegir_si_no(prompt, defecte=True):
    """
    Demana una resposta sí/no a l'usuari.
    
    :param prompt: Missatge a mostrar.
    :param defecte: Valor per defecte (True = sí, False = no).
    :return: True o False.
    """
    opcio_defecte = "S/n" if defecte else "s/N"
    
    while True:
        entrada = input(f"{prompt} [{opcio_defecte}]: ").strip().lower()
        
        if entrada == "":
            return defecte
        if entrada in ["s", "sí", "si", "yes", "y"]:
            return True
        if entrada in ["n", "no"]:
            return False
        
        print("Error: respon 's' o 'n'.")


# Exemple d'ús
if __name__ == "__main__":
    print("=== Configuració de connexió ===")
    print()
    
    port = llegir_enter("Port", minim=1, maxim=65535)
    timeout = llegir_enter("Timeout (segons)", minim=1, maxim=300, defecte=30)
    ssl = llegir_si_no("Usar SSL?", defecte=True)
    
    print()
    print("Configuració seleccionada:")
    print(f"  Port:    {port}")
    print(f"  Timeout: {timeout}s")
    print(f"  SSL:     {'Sí' if ssl else 'No'}")
```

{{< /details >}}

### Exercici 3

**Calculadora de temps d'execució**

Objectiu: Crear funcions per treballar amb durades de processos i tasques.

1. Crea un script anomenat `temps_execucio.py`.
2. Implementa una funció `segons_a_hms(segons)` que retorni una tupla (hores, minuts, segons).
3. Implementa una funció `formatar_duracio(segons, format)` que accepti:
   - `segons`: durada en segons
   - `format`: "complet" (2h 15m 30s), "curt" (02:15:30) o "paraules" (2 hores, 15 minuts i 30 segons)
4. Implementa una funció `sumar_durades(*durades)` que accepti múltiples durades en segons i retorni el total formatat.
5. Prova les funcions amb exemples de temps d'execució de tasques del sistema.

> Pista: usa divisió entera `//` i mòdul `%` per separar hores, minuts i segons.

{{< details summary="Resposta" >}}

Exemple d'script `temps_execucio.py`:

```python
#!/usr/bin/env python3
"""
Calculadora de temps d'execució.

Funcions per convertir, formatar i sumar durades de temps,
útils per analitzar logs i temps d'execució de processos.
"""


def segons_a_hms(segons):
    """
    Converteix segons a hores, minuts i segons.
    
    :param segons: Durada en segons (enter o decimal).
    :return: Tupla (hores, minuts, segons).
    
    Exemple:
        >>> segons_a_hms(3725)
        (1, 2, 5)
    """
    segons = int(segons)
    hores = segons // 3600
    minuts = (segons % 3600) // 60
    secs = segons % 60
    return hores, minuts, secs


def formatar_duracio(segons, format="complet"):
    """
    Formata una durada en segons segons el format especificat.
    
    :param segons: Durada en segons.
    :param format: Tipus de format:
        - "complet": 2h 15m 30s
        - "curt": 02:15:30
        - "paraules": 2 hores, 15 minuts i 30 segons
    :return: Cadena formatada.
    """
    hores, minuts, secs = segons_a_hms(segons)
    
    if format == "complet":
        parts = []
        if hores > 0:
            parts.append(f"{hores}h")
        if minuts > 0:
            parts.append(f"{minuts}m")
        if secs > 0 or not parts:
            parts.append(f"{secs}s")
        return " ".join(parts)
    
    elif format == "curt":
        return f"{hores:02d}:{minuts:02d}:{secs:02d}"
    
    elif format == "paraules":
        parts = []
        if hores > 0:
            parts.append(f"{hores} {'hora' if hores == 1 else 'hores'}")
        if minuts > 0:
            parts.append(f"{minuts} {'minut' if minuts == 1 else 'minuts'}")
        if secs > 0 or not parts:
            parts.append(f"{secs} {'segon' if secs == 1 else 'segons'}")
        
        if len(parts) == 1:
            return parts[0]
        elif len(parts) == 2:
            return f"{parts[0]} i {parts[1]}"
        else:
            return f"{parts[0]}, {parts[1]} i {parts[2]}"
    
    else:
        raise ValueError(f"Format desconegut: {format}")


def sumar_durades(*durades):
    """
    Suma múltiples durades i retorna el total formatat.
    
    :param durades: Durades en segons (nombre variable d'arguments).
    :return: Diccionari amb el total en segons i en diferents formats.
    
    Exemple:
        >>> sumar_durades(120, 3600, 45)
        {'segons': 3765, 'complet': '1h 2m 45s', ...}
    """
    total = sum(durades)
    
    return {
        "segons": total,
        "complet": formatar_duracio(total, "complet"),
        "curt": formatar_duracio(total, "curt"),
        "paraules": formatar_duracio(total, "paraules"),
    }


if __name__ == "__main__":
    print("=== Calculadora de temps d'execució ===")
    print()
    
    # Exemple 1: Conversió bàsica
    print("Conversió de segons a hores:minuts:segons:")
    for segons in [45, 125, 3725, 7384, 86400]:
        h, m, s = segons_a_hms(segons)
        print(f"  {segons:6} segons = {h}h {m}m {s}s")
    
    print()
    
    # Exemple 2: Diferents formats
    print("Diferents formats per a 8145 segons:")
    temps = 8145
    print(f"  Complet:  {formatar_duracio(temps, 'complet')}")
    print(f"  Curt:     {formatar_duracio(temps, 'curt')}")
    print(f"  Paraules: {formatar_duracio(temps, 'paraules')}")
    
    print()
    
    # Exemple 3: Temps d'execució de tasques
    print("Temps d'execució de tasques del sistema:")
    tasques = [
        ("Backup base de dades", 1847),
        ("Compressió de logs", 423),
        ("Sincronització remota", 2156),
        ("Neteja de temporals", 67),
    ]
    
    for nom, segons in tasques:
        print(f"  {nom}: {formatar_duracio(segons, 'complet')}")
    
    print()
    
    # Exemple 4: Suma de durades
    print("Temps total de totes les tasques:")
    durades = [t[1] for t in tasques]
    total = sumar_durades(*durades)
    print(f"  Total: {total['segons']} segons")
    print(f"  Format complet: {total['complet']}")
    print(f"  Format curt: {total['curt']}")
    print(f"  Format paraules: {total['paraules']}")
    
    print()
    
    # Exemple 5: Casos especials
    print("Casos especials:")
    print(f"  0 segons: {formatar_duracio(0, 'paraules')}")
    print(f"  1 segon: {formatar_duracio(1, 'paraules')}")
    print(f"  60 segons: {formatar_duracio(60, 'paraules')}")
    print(f"  3600 segons: {formatar_duracio(3600, 'paraules')}")
```

{{< /details >}}

### Exercici 4

**Validador de configuració de xarxa**

Objectiu: Crear un conjunt de funcions per validar paràmetres de xarxa.

1. Crea un script anomenat `validador_xarxa.py`.
2. Implementa les funcions següents:
   - `es_ip_valida(ip)`: comprova si una adreça IPv4 és vàlida.
   - `es_mascara_valida(mascara)`: comprova si una màscara de xarxa és vàlida.
   - `es_port_valid(port, permetre_privilegiats)`: comprova si un port és vàlid, amb opció per bloquejar ports privilegiats.
3. Implementa una funció `validar_configuracio(**params)` que accepti paràmetres variables (ip, mascara, gateway, dns, port) i retorni un diccionari amb el resultat de cada validació.
4. Mostra exemples amb configuracions vàlides i invàlides.

> Pista: una màscara de xarxa vàlida, en binari, és una seqüència d'uns seguits d'una seqüència de zeros (e.g., 255.255.255.0 = 11111111.11111111.11111111.00000000).

{{< details summary="Resposta" >}}

Exemple d'script `validador_xarxa.py`:

```python
#!/usr/bin/env python3
"""
Validador de configuració de xarxa.

Funcions per validar adreces IP, màscares de xarxa,
ports i configuracions completes.
"""


def es_ip_valida(ip):
    """
    Comprova si una adreça IPv4 és vàlida.
    
    :param ip: Adreça IP com a cadena (e.g., "192.168.1.1").
    :return: True si és vàlida, False altrament.
    """
    if not isinstance(ip, str):
        return False
    
    parts = ip.split(".")
    
    if len(parts) != 4:
        return False
    
    for part in parts:
        # Ha de ser un nombre
        if not part.isdigit():
            return False
        
        # Ha d'estar entre 0 i 255
        valor = int(part)
        if valor < 0 or valor > 255:
            return False
        
        # No pot tenir zeros a l'esquerra (excepte "0")
        if len(part) > 1 and part[0] == "0":
            return False
    
    return True


def es_mascara_valida(mascara):
    """
    Comprova si una màscara de xarxa és vàlida.
    
    Una màscara vàlida, en binari, és una seqüència d'uns
    seguida d'una seqüència de zeros.
    
    :param mascara: Màscara com a cadena (e.g., "255.255.255.0").
    :return: True si és vàlida, False altrament.
    """
    # Primer ha de ser una IP vàlida
    if not es_ip_valida(mascara):
        return False
    
    # Convertir a binari (32 bits)
    parts = mascara.split(".")
    binari = ""
    for part in parts:
        binari += format(int(part), "08b")
    
    # Ha de ser uns seguits de zeros (no pot haver-hi 01)
    trobat_zero = False
    for bit in binari:
        if bit == "0":
            trobat_zero = True
        elif trobat_zero:
            # Un "1" després d'un "0" no és vàlid
            return False
    
    return True


def es_port_valid(port, permetre_privilegiats=True):
    """
    Comprova si un port és vàlid.
    
    :param port: Número de port.
    :param permetre_privilegiats: Si permet ports < 1024 (per defecte True).
    :return: True si és vàlid, False altrament.
    """
    # Ha de ser un enter
    if not isinstance(port, int):
        return False
    
    # Ha d'estar en el rang vàlid
    if port < 1 or port > 65535:
        return False
    
    # Comprovar ports privilegiats
    if not permetre_privilegiats and port < 1024:
        return False
    
    return True


def validar_configuracio(**params):
    """
    Valida una configuració de xarxa completa.
    
    :param params: Paràmetres de xarxa (ip, mascara, gateway, dns, port).
    :return: Diccionari amb el resultat de cada validació.
    
    Exemple:
        >>> validar_configuracio(ip="192.168.1.10", port=8080)
        {'ip': {'valor': '192.168.1.10', 'valid': True}, ...}
    """
    resultats = {}
    
    for clau, valor in params.items():
        resultat = {"valor": valor, "valid": False, "error": None}
        
        if clau in ["ip", "gateway", "dns"]:
            if es_ip_valida(valor):
                resultat["valid"] = True
            else:
                resultat["error"] = "Adreça IP no vàlida"
        
        elif clau == "mascara":
            if es_mascara_valida(valor):
                resultat["valid"] = True
            else:
                resultat["error"] = "Màscara de xarxa no vàlida"
        
        elif clau == "port":
            permetre = params.get("permetre_privilegiats", True)
            if es_port_valid(valor, permetre):
                resultat["valid"] = True
            else:
                if valor < 1 or valor > 65535:
                    resultat["error"] = "Port fora de rang (1-65535)"
                else:
                    resultat["error"] = "Port privilegiat no permès"
        
        elif clau == "permetre_privilegiats":
            # Paràmetre auxiliar, no cal validar
            continue
        
        else:
            resultat["error"] = f"Paràmetre desconegut: {clau}"
        
        resultats[clau] = resultat
    
    return resultats


def mostrar_validacio(resultats):
    """Mostra els resultats de validació de manera formatada."""
    print("Resultats de la validació:")
    print("-" * 50)
    
    tot_valid = True
    for clau, info in resultats.items():
        icona = "✓" if info["valid"] else "✗"
        estat = "vàlid" if info["valid"] else info["error"]
        print(f"  {icona} {clau}: {info['valor']} ({estat})")
        if not info["valid"]:
            tot_valid = False
    
    print("-" * 50)
    if tot_valid:
        print("✓ Configuració vàlida")
    else:
        print("✗ Configuració amb errors")


if __name__ == "__main__":
    print("=== Validador de configuració de xarxa ===")
    print()
    
    # Exemple 1: Configuració vàlida
    print("Exemple 1: Configuració vàlida")
    resultats = validar_configuracio(
        ip="192.168.1.100",
        mascara="255.255.255.0",
        gateway="192.168.1.1",
        dns="8.8.8.8",
        port=8080
    )
    mostrar_validacio(resultats)
    
    print()
    
    # Exemple 2: Configuració amb errors
    print("Exemple 2: Configuració amb errors")
    resultats = validar_configuracio(
        ip="192.168.1.300",       # IP invàlida
        mascara="255.255.128.0",  # Màscara vàlida
        gateway="192.168.1",      # Gateway invàlid
        port=80,
        permetre_privilegiats=False  # Port privilegiat no permès
    )
    mostrar_validacio(resultats)
    
    print()
    
    # Exemple 3: Validacions individuals
    print("Exemple 3: Validacions individuals")
    print()
    
    ips_a_validar = [
        "192.168.1.1",
        "10.0.0.1",
        "256.1.2.3",
        "192.168.1",
        "192.168.01.1",
    ]
    
    print("Validació d'IPs:")
    for ip in ips_a_validar:
        resultat = "✓ vàlida" if es_ip_valida(ip) else "✗ invàlida"
        print(f"  {ip:18} {resultat}")
    
    print()
    
    mascares_a_validar = [
        "255.255.255.0",
        "255.255.0.0",
        "255.255.255.128",
        "255.255.128.128",  # Invàlida
        "255.0.255.0",      # Invàlida
    ]
    
    print("Validació de màscares:")
    for mascara in mascares_a_validar:
        resultat = "✓ vàlida" if es_mascara_valida(mascara) else "✗ invàlida"
        print(f"  {mascara:18} {resultat}")
    
    print()
    
    ports_a_validar = [
        (22, True),
        (22, False),
        (8080, True),
        (8080, False),
        (70000, True),
    ]
    
    print("Validació de ports:")
    for port, permetre in ports_a_validar:
        resultat = "✓ vàlid" if es_port_valid(port, permetre) else "✗ invàlid"
        mode = "amb privilegiats" if permetre else "sense privilegiats"
        print(f"  Port {port:5} ({mode:18}) {resultat}")
```

{{< /details >}}

## Resum

En aquest article hem après a organitzar el codi en funcions reutilitzables:

- Definim funcions amb `def nom():` i les cridam amb `nom()`.
- Els paràmetres permeten passar informació a les funcions; els arguments són els valors que passam.
- La instrucció `return` retorna un valor (o múltiples com a tupla) i acaba la funció.
- Els paràmetres per defecte fan les funcions més flexibles.
- Els arguments amb nom milloren la llegibilitat quan hi ha molts paràmetres.
- Les construccions sintáctiques especials `*args` i `**kwargs` permeten funcions amb nombre variable d'arguments.
- Els docstrings documenten què fa la funció, els seus paràmetres i el valor de retorn.
- Les variables tenen un àmbit (*scope*): local dins funcions, global fora. Evitam modificar variables globals.
- Seguim bones pràctiques: funcions petites, amb un únic propòsit, amb noms descriptius i sense efectes secundaris.
