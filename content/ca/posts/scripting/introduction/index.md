---
title: "Introducció a Python i algorismes"
date: 2026-04-04
lastmod: 2026-04-14
description: "Primers passos amb Python: què és un algorisme, instal·lació, l'intèrpret interactiu, primer script i permisos d'execució"
summary: "Primers passos amb Python: què és un algorisme, instal·lació, l'intèrpret interactiu, primer script i permisos d'execució"
categories: ["teaching"]
tags: ["python", "scripting"]
series: ["Scripting"]
series_order: 1
weight: 10
slug: introduccio-algorismes
---

L'administració de sistemes implica moltes tasques repetitives: comprovar l'estat de serveis, gestionar usuaris, revisar logs, fer còpies de seguretat, etc. Fer aquestes tasques manualment una vegada és assumible, però fer-les cada dia (o pitjor, cada hora) és tediós i propens a errors. Aquí és on entra la programació.

En aquesta sèrie d'articles aprendrem a programar amb Python, un llenguatge especialment adequat per a l'administració de sistemes. No pretenem convertir-nos en desenvolupadors de programari, sinó adquirir les habilitats necessàries per automatitzar tasques, crear petites eines d'administració i entendre scripts existents.

## Per què Python?

Hi ha molts llenguatges de programació, però Python destaca per diverses raons que el fan ideal per a administradors de sistemes:

**Llegibilitat.** Python té una sintaxi neta i clara que s'assembla a l'anglès. Això fa que els scripts siguin fàcils de llegir i mantenir, fins i tot mesos després d'haver-los escrit.

**Biblioteca estàndard rica.** Python inclou mòduls per fer feina amb fitxers, xarxes, processos, expressions regulars i moltes altres tasques habituals en administració de sistemes. No cal reinventar la roda.

**Comunitat activa.** Quan tenguem un problema, és molt probable que algú altre ja l'hagi resolt. La documentació oficial és excel·lent i hi ha milers de tutorials i exemples disponibles.

**Ús real en el sector.** Eines com [Ansible](https://ansible.com/), [SaltStack](https://saltproject.io/), [Pyinfra](https://pyinfra.com/) o molts scripts interns d'empreses estan escrits en Python. Aprendre Python ens obre portes.

A diferència dels llenguatges compilats com C o Go, on cal transformar el codi font en un executable abans de poder-lo usar, Python és un llenguatge interpretat: escrivim el codi i l'executam directament. Això accelera el cicle de desenvolupament, cosa especialment útil quan creem scripts per resoldre problemes puntuals.

## Què és un algorisme?

Abans d'escriure codi, hem d'entendre què volem fer. Un **algorisme** és una seqüència finita i ordenada de passos per resoldre un problema. És com una recepta de cuina: una llista d'instruccions que, si les seguim correctament, ens duen a un resultat.

Un bon algorisme té aquestes característiques:

- **Precís:** cada pas està ben definit, sense ambigüitats.
- **Finit:** acaba en algun moment, no s'executa indefinidament.
- **Entrada i sortida definides:** sabem què rep i què produeix.

Pensem en un exemple quotidià per a un administrador de sistemes: comprovar si un servei està actiu i, si no ho està, reiniciar-lo. L'algorisme seria:

1. Inici
2. Comprovar l'estat del servei
3. El servei està actiu?
   - Sí → Mostrar "El servei funciona correctament"
   - No → Reiniciar el servei
4. Mostrar "Comprovació finalitzada"
5. Fi

Aquest algorisme el podem representar visualment amb un **diagrama de flux**. Els diagrames de flux usen formes estàndard per representar diferents tipus d'operacions:

- **Oval:** inici o fi del procés.
- **Rectangle:** procés o acció.
- **Rombe:** decisió (pregunta amb resposta sí/no).
- **Paral·lelogram:** entrada o sortida de dades.

El nostre algorisme quedaria així:

{{< mermaid >}}
flowchart TD
    A([Inici]) --> B[Comprovar estat del servei]
    B --> C{Està actiu?}
    C -->|Sí| D[/Mostrar 'El servei funciona correctament'/]
    C -->|No| E[Reiniciar el servei]
    E --> D
    D --> F[/Mostrar 'Comprovació finalitzada'/]
    F --> G([Fi])
{{< /mermaid >}}

Abans d'escriure codi, és útil pensar en l'algorisme que volem implementar. No cal fer sempre un diagrama formal, però sí tenir clar quins passos seguirà el nostre programa i quines decisions haurà de prendre.

## Instal·lació de Python

### Linux

La bona notícia és que Python ja ve instal·lat per defecte a Debian i Ubuntu. Podem comprovar la versió obrint un terminal i executant:

```bash
python3 --version
```

Per al contingut d'aquest curs, qualsevol versió de Python 3.10 o superior és perfectament vàlida. Si per algun motiu no el tenim instal·lat, el podem instal·lar amb una simple comanda:

```bash
sudo apt update
sudo apt install python3
```

### Windows

Python no ve instal·lat per defecte a Windows. Per instal·lar-lo:

1. Anam a la [pàgina oficial de descàrregues de Python per a Windows](https://www.python.org/downloads/windows/).
2. Descarregam i executam la versió més recent de l'instal·lador per a Windows seguint la ruta `Stable releases > Python install manager > Download installer (MSIX)`.
3. Durant la instal·lació, marcam la casella *"Add Python to PATH"*. Això ens permetrà executar Python des de qualsevol terminal.
4. Completam la instal·lació.

Per verificar que tot ha anat bé, obrim el símbol del sistema (cmd) o PowerShell i executam:

```
py --version
```

A Windows, el llançador `py` és la manera recomanada d'executar Python, ja que gestiona automàticament les diferents versions si en tenim més d'una instal·lada.

### macOS

Les versions recents de macOS no inclouen Python per defecte (o inclouen una versió antiga). Per instal·lar-lo:

1. Anam a la [pàgina oficial de descàrregues de Python per a macOS](https://www.python.org/downloads/macos/).
2. Descarregam la versió més recent de l'instal·lador per a macOS seguint la ruta `Stable releases > Python > Download macOS installer`.
3. Executam l'instal·lador i seguim les instruccions.

Un cop instal·lat, obrim el Terminal i verificam:

```bash
python3 --version
```

> A macOS, igual que a Linux, usam `python3` per executar Python.

## L'intèrpret interactiu

Python inclou un **intèrpret interactiu**, també conegut com a REPL (Read-Eval-Print Loop), que ens permet executar codi línia per línia i veure'n immediatament el resultat. És una eina excel·lent per experimentar i aprendre.

Per accedir a l'intèrpret, obrim un terminal i executam:

```bash
python3
```

A Windows, usam:

```
py
```

Veurem un missatge de benvinguda amb la versió de Python i el símbol `>>>`, que indica que l'intèrpret està esperant que escrivim codi:

```
Python 3.12.3 (main, Mar  3 2026, 12:15:18) [GCC 13.3.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>>
```

Podem usar l'intèrpret com una calculadora:

```python
>>> 2 + 2
4
>>> 100 / 7
14.285714285714286
>>> 2 ** 10
1024
```

> Python interpreta les expressions, que inclouen un un operador i dos operands, i en presenta el resultat.

També podem treballar amb text (el que en programació anomenam *strings* o cadenes de caràcters):

```python
>>> "Hola, món!"
'Hola, món!'
>>> "administrador" + "@" + "domini.eu"
'administrador@domini.eu'
```

L'operador suma `+` ens permet concatenar cadenes de caràcters.

> Python, de nou, interpreta l'expressió. Com que aqui usam cadenes de caràcters, el resultat serà una cadena.

La funció `print()` ens permet mostrar missatges per pantalla:

```python
>>> print("There is no spoon")
There is no spoon
```

Quan vulguem explorar què fa una funció o un mòdul, podem usar `help()`:

```python
>>> help(print)
```

Això ens mostrarà la documentació de la funció `print`. Per sortir de l'ajuda, premem la tecla `q`.

Per sortir de l'intèrpret interactiu, podem escriure `exit()` o prémer `Ctrl+D` (a Linux i macOS) o `Ctrl+Z` seguit d'Enter (a Windows).

L'intèrpret interactiu és fantàstic per fer proves ràpides, però per a programes reals necessitam escriure el codi en fitxers.

## El primer script

Un **script** és un fitxer de text que conté codi Python. En lloc d'escriure les instruccions una per una a l'intèrpret, les escrivim totes en un fitxer i les executam juntes.

Creem el nostre primer script. Obrim un editor de text (Nano, Vim, Notepad++, VSCodium...) i escrivim:

```python
# El meu primer script de Python
# Aquest programa mostra un missatge de benvinguda

print("Hola! Aquest és el meu primer script de Python.")
print("Som un futur administrador de sistemes.")
```

Guardam el fitxer amb el nom `hola.py`. L'extensió `.py` indica que és un fitxer de Python.

{{ < alert > }}
És necessari guardar el fitxer `hola.py` com a fitxer sense format, també conegut com a fitxer de text pla.
{{ < /alert > }}

Per executar l'script, obrim un terminal, anam al directori on hem guardat el fitxer i executam:

```bash
python3 hola.py
```

A Windows:

```
py hola.py
```

Hauríem de veure:

```
Hola! Aquest és el meu primer script de Python.
Som un futur administrador de sistemes.
```

Fixem-nos en alguns detalls del nostre script:

- Les línies que comencen amb `#` són **comentaris**. Python les ignora completament, però són molt útils per documentar què fa el codi. Escriure bons comentaris és un hàbit que hem d'adquirir des del principi.
- Cada instrucció `print()` ocupa una línia.
- El text que volem mostrar va entre cometes (podem usar cometes simples `'...'` o dobles `"..."`).

## Editors de text

Per escriure scripts necessitam un editor de text. Les opcions varien segons la plataforma.

Si ens resulta còmode fer feina des del terminal, tant a Linux com a macOS podem usar [Nano](https://www.nano-editor.org/) o [Vim](https://www.vim.org), mentre que a Windows podem usar [Micro](https://micro-editor.github.io/).

Nano és senzill i és ideal per edicions ràpides, mentre que Vim és més potent però amb corba d'aprenentatge. Ambdós venen inclosos en la distribució. Si volem usar la versió millorada Vim la podem instal·lar amb la comanda `sudo apt install vim`. Micro vol ser el successor de Nano, però inclou algunes funcionalitats addicionals.

En canvi, si ens estimam més fer feina des de l'entorn gràfic, tant a Linux com a macOS podem usar l'editor per defecte del nostre entorn d'escriptori, e.g., [Text Editor](https://apps.gnome.org/TextEditor/) si usam GNOME, [Kate](https://apps.kde.org/es/kate/) si usam KDE i [TextEdit](https://support.apple.com/guide/textedit/welcome/mac) si usam macOS. A Windows podem usar [Notepad++](https://notepad-plus-plus.org/).

Tanmateix, l'estàndar actual de la indústria quan volem anar més enllà d'un senzill script és [VSCode](https://code.visualstudio.com/), un editor modern amb moltes funcionalitats, o la seva versió completament oberta i sense seguiment ni telemetria [VSCodium](https://vscodium.com/).

> Si fem feina sovint amb servidors remots per SSH, és especialment útil dominar `nano` o `vim`, ja que sempre estaran disponibles.

## Scripts executables

A Linux i macOS, podem fer que els nostres scripts siguin directament executables, com qualsevol altra comanda del sistema. Això requereix dos passos: afegir un **shebang** i donar permisos d'execució.

### El shebang

El *shebang*[^1] és una línia especial que posam al principi del fitxer per indicar al sistema quin intèrpret ha d'usar per executar l'script. Per a Python, la forma recomanada és:

[^1]: El terme prové d'una contracció aproximada de "SHArp bang" o "haSH bang", en anglès. Això combina "hash" (el símbol `#`) i "bang" (argot per al signe d'exclamació).

```python
#!/usr/bin/env python3
```

Aquesta línia diu al sistema: "cerca l'executable `python3` al `PATH` i usa'l per executar aquest fitxer". Usam `env` en comptes d'una ruta absoluta (com `/usr/bin/python3`) perquè la ubicació de Python pot variar entre sistemes.

Per tant, l'script de l'apartat anterior quedaria així:

```python
#!/usr/bin/env python3

# El meu primer script de Python
# Aquest programa mostra un missatge de benvinguda

print("Hola! Aquest és el meu primer script de Python.")
print("Som un futur administrador de sistemes.")
```

### Permisos d'execució

Per defecte, els fitxers de text no tenen permís d'execució, però els podem afegir amb `chmod`:

```bash
chmod +x hola.py
```

Ara podem executar l'script directament, sense haver de cridar explícitament `python3`:

```bash
./hola.py
```

El `./` indica que volem executar un fitxer del directori actual. Això és necessari perquè, per seguretat, el directori actual no està al `PATH` per defecte. Tanmateix, continu essent possible executar l'script amb l'intèrpret:

```bash
python3 hola.py
```

### A Windows

A Windows, el concepte de shebang no existeix. El sistema operatiu decideix com obrir un fitxer basant-se en l'extensió. Quan instal·lam Python marcant l'opció `Add Python to PATH`, l'extensió `.py` queda associada amb l'intèrpret de Python.

Per executar un script a Windows, simplement usam:

```
py hola.py
```

O, si l'associació està configurada correctament, podem fer doble clic al fitxer o executar-lo directament escrivint el nom:

```
hola.py
```

Tot i que el shebang no és necessari a Windows, és bona pràctica incloure'l igualment. D'aquesta manera, el mateix script funcionarà tant a Linux/macOS com a Windows sense modificacions.

## Entorn de feina

Abans de continuar amb més contingut, és convenient organitzar el nostre entorn de feina. Cream un directori on guardarem tots els scripts del curs:

```bash
mkdir -p ~/Projects/scripts-python
cd ~/Projects/scripts-python
```

Dins aquest directori podem crear subcarpetes per a cada tema si volem mantenir-ho ordenat.

A l'hora de posar nom als nostres scripts, es convenient seguir aquestes convencions:

- Usar noms descriptius: `comprovar_servei.py` és millor que `script1.py`.
- Escriure en minúscules i separar les paraules amb guions baixos: `gestio_usuaris.py`.
- Sempre usar l'extensió `.py`.

Ara és un bon moment per a crear una plantilla que podrem usar com a punt de partida per a nous scripts:

```python
#!/usr/bin/env python3
"""
Descripció breu del que fa l'script.

:Author: El teu nom
:Date: 2026-04-04
"""

# Inici del codi
print("Plantilla d'script")
```

El text entre `"""..."""` és un *docstring*, un tipus especial de comentari que serveix per documentar l'script, mòdul, funció, classe o mètode. És una bona pràctica usar reStructuredText[^2] (reST) dins el docstring per a donar format al docstring. Els atributs `:Author:` i `:Date:` s'usen per a indicar l'autor i la data de creació o modificació, respectivament.

[^2]: [PEP 257](https://peps.python.org/pep-0257/) defineix les convencions a l'hora d'usar [reST](https://restructuredtext.org) a docstring amb Python.

## Exercicis

Es proposen quatre exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Dissenyar un algorisme**

Objectiu: Crear un diagrama de flux per a un algorisme que comprovi l'espai en disc i mostri una alerta si l'ús supera el 80%.

1. Pensa en els passos necessaris: obtenir l'ús de disc, comparar amb el llindar, mostrar el missatge adequat.
2. Dibuixa el diagrama de flux usant les formes estàndard (oval per inici/fi, rectangle per processos, rombe per decisions).
3. Pots usar un editor en línia com [Mermaid Live Editor](https://mermaid.live) o [draw.io](https://www.draw.io) per crear el diagrama digitalment.
4. Opcionalment, amplia l'algorisme amb accions com enviar un correu electrònic d'alerta o netejar fitxers temporals si l'espai es criti.

{{< details summary="Resposta" >}}

Exemple de diagrama de flux:

```text
                    ┌─────────┐
                    │  Inici  │
                    └────┬────┘
                         │
                         ▼
          ┌──────────────────────────────┐
          │ Obtenir percentatge d'ús     │
          │ de disc                      │
          └──────────────┬───────────────┘
                         │
                         ▼
                  ┌─────────────┐
                  │ Ús > 80%?   │
                  └──────┬──────┘
                    /          \
                 Sí              No
                /                  \
               ▼                    ▼
┌──────────────────────────┐   ┌────────────────────────────┐
│ Mostrar 'ALERTA: Espai   │   │ Mostrar 'Espai en disc     │
│ en disc crític'          │   │ correcte'                  │
└────────────┬─────────────┘   └─────────────┬──────────────┘
             │                               │
             ▼                               │
┌──────────────────────────┐                 │
│ Netejar fitxers          │                 │
│ temporals                │                 │
└────────────┬─────────────┘                 │
             │                               │
             ▼                               │
┌──────────────────────────┐                 │
│ Enviar correu            │                 │
│ d'alerta                 │                 │
└────────────┬─────────────┘                 │
             │                               │
             └───────────────┬───────────────┘
                             │
                             ▼
                       ┌───────────┐
                       │    Fi     │
                       └───────────┘
```

{{< /details >}}

### Exercici 2

**Explorant l'intèrpret**

Objectiu: Usar l'intèrpret interactiu per descobrir què retornen algunes funcions bàsiques de Python.

1. Obri l'intèrpret de Python.
2. Prova la funció `len()` amb diferents valors: un text, una llista de nombres, un text buit.
3. Prova la funció `type()` amb un nombre enter, un nombre decimal, un text i el valor `True`.
4. Prova la funció `abs()` amb nombres positius i negatius.
5. Intenta deduir què fa cada funció basant-te en els resultats.

> Pista: les llistes a Python s'escriuen entre claudàtors, e.g., `[1, 2, 3, 4, 5]`.

{{< details summary="Resposta" >}}

Exemple d'execució de les comandes i la seva sortida:

```python
>>> len("administrador")
13
>>> len([1, 2, 3, 4, 5])
5
>>> len("")
0

>>> type(42)
<class 'int'>
>>> type(3.14)
<class 'float'>
>>> type("hola")
<class 'str'>
>>> type(True)
<class 'bool'>

>>> abs(10)
10
>>> abs(-10)
10
>>> abs(-3.5)
3.5
```
Observacions:

- `len()` retorna la longitud (nombre d'elements o caràcters) del valor que li passam.
- `type()` retorna el tipus de dada del valor.
- `abs()` retorna el valor absolut d'un nombre (sempre positiu).

{{< /details >}}

### Exercici 3

**Script multiplataforma**

Objectiu: Crear un script que mostri un missatge de benvinguda amb el nom del sistema operatiu.

1. Crea un fitxer anomenat `benvinguda_sistema.py`.
2. L'script ha de mostrar un missatge com: "Benvingut! Estàs executant aquest script a Linux."
3. A Linux/macOS, l'script ha de ser executable amb `./benvinguda_sistema.py`.
4. Investiga el mòdul `platform` de Python per obtenir el nom del sistema operatiu.

> Pista: el mòdul `platform` té una funció `system()` que retorna el nom del sistema operatiu. Per usar un mòdul, primer l'hem d'importar amb `import platform`.

{{< details summary="Resposta" >}}

Exemple d'script de benvinguda al sistema:

```python
#!/usr/bin/env python3
"""Mostra un missatge de benvinguda amb el sistema operatiu."""

import platform

sistema = platform.system()
print("Benvingut al sistema " + sistema + ".")
```

Per fer-lo executable a Linux/macOS:

```bash
chmod +x benvinguda_sistema.py
./benvinguda_sistema.py
```

A Windows, l'executam amb:

```
py benvinguda_sistema.py
```

La funció `platform.system()` retorna:

- `"Linux"` a Linux.
- `"Windows"` a Windows.
- `"Darwin"` a macOS (Darwin és el nucli de macOS).

{{< /details >}}

### Exercici 4

**Preparar l'entorn**

Objectiu: Crear l'estructura de directoris per al curs i un script inicial que serveixi de plantilla.

1. Crea el directori `~/Projects/scripts-python/` amb subdirectoris per als temes: `fonaments/`, `fitxers/`, `xarxes/`, `automatitzacio/`.
2. Dins el directori principal, crea un fitxer `plantilla.py` amb:
   - Shebang
   - Docstring amb descripció, autor i data
   - Un `print()` de prova
3. Dona permisos d'execució a la plantilla i comprova que funciona.

> Pista: pots crear múltiples directoris alhora amb `mkdir -p ~/Projects/scripts-python/{fonaments,fitxers,xarxes,automatitzacio}`.

{{< details summary="Resposta" >}}

Per crear l'estructura de directoris usarem `mkdir`:

```bash
mkdir -p ~/Projects/scripts-python/{fonaments,fitxers,xarxes,automatitzacio}
```

> A la pàgina del manual de `mkdir` (`man mkdir`) pots veure els paràmetres de la comanda.

Podem verificar l'estructura llistant el contingut del directori pare:

```bash
ls ~/scripts-python/
```

Contingut de `~/scripts-python/plantilla.py`:

```python
#!/usr/bin/env python3
"""
Descripció de l'script.

:Author: El teu nom
:Date: 2026-04-04
"""

print("Plantilla funcionant correctament!")
```

Per fer-lo executable i provar-lo:

```bash
chmod +x ~/scripts-python/plantilla.py
~/scripts-python/plantilla.py
```

Sortida esperada:

```
Plantilla funcionant correctament!
```

A partir d'ara, quan vulguem crear un nou script, podem copiar aquesta plantilla:

```bash
cp ~/Projects/scripts-python/plantilla.py \
   ~/Projects/scripts-python/fonaments/nou_script.py
```

{{< /details >}}
