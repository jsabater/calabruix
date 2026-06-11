---
title: "Transformacions XSLT"
date: 2026-01-03
lastmod: 2026-01-11
description: "Transformacions XSLT per convertir documents XML a HTML, text o altres formats XML. Plantilles, XPath, iteracions, condicions i exemple complet amb l'XML de l'institut."
summary: "Plantilles, expressions XPath, estructures de control i transformació d'XML a HTML."
categories: ["teaching"]
tags: ["xml", "xslt"]
series: ["XML"]
series_order: 7
weight: 70
slug: xslt
---

L'eXtensible Stylesheet Language Transformations (XSLT) és un llenguatge de programació declaratiu dissenyat per transformar documents XML en altres formats: HTML, text pla, PDF (via XSL-FO) o, fins i tot, altres documents XML amb estructura diferent.

A diferència de CSS, que només modifica l'aparença visual, XSLT pot:

* Reestructurar completament el document.
* Reordenar elements.
* Filtrar i seleccionar dades.
* Realitzar càlculs.
* Generar contingut nou.
* Combinar múltiples fonts de dades.

El funcionament bàsic és molt senzill: un document d'entrada més un conjunt de regles de transformació generen un document de sortida.

```
Document XML + Full XSLT = Document transformat
```

Un processador XSLT llegeix el document XML d'entrada, aplica les regles definides al full d'estils XSLT i genera el document de sortida.

## Estructura d'un XSLT

Un full XSLT és, en si mateix, un document XML:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <!-- Configuració de sortida -->
    <xsl:output method="html" encoding="UTF-8" indent="yes"/>
    
    <!-- Plantilles de transformació -->
    <xsl:template match="...">
        [..]
    </xsl:template>
    
</xsl:stylesheet>
```

Els elements principals d'XPath són els següents:

| Element                 | Funció                                  |
|-------------------------|-----------------------------------------|
| `<xsl:stylesheet>`      | Element arrel del full XSLT             |
| `<xsl:output>`          | Configura el format de sortida          |
| `<xsl:template>`        | Defineix una plantilla de transformació |
| `<xsl:apply-templates>` | Aplica plantilles als nodes fills       |
| `<xsl:value-of>`        | Extreu el valor d'un node               |
| `<xsl:for-each>`        | Itera sobre un conjunt de nodes         |
| `<xsl:if>`              | Condició simple                         |
| `<xsl:choose>`          | Condició múltiple (switch)              |
| `<xsl:sort>`            | Ordena els nodes                        |
| `<xsl:variable>`        | Defineix una variable                   |

## Enllaçar XSLT

Similar a CSS, per enllaçar XSLT a un document XML s'usa una instrucció de processament:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="transformacio.xsl"?>
<arrel>
    [..]
</arrel>
```

## XPath

XSLT utilitza **XPath** (XML Path Language) per seleccionar nodes del document XML. XPath és un llenguatge de consultes usat per a navegar i seleccionar nodes en documents XML i HTML. Proporciona una forma flexible de localitzar elements basant-se en atributs, contingut textual, estructura o relacions dins la jerarquia del document.

Originalment desenvolupat pel [*](W3C) l'any 1999, XPath és àmpliament usat per eines d'automatizació web (e.g., Selenium), web scrapping, extracció de dades i transformació de contingut XML usant tecnologies com [*](XSLT) i XQuery. Suporta rutes tant relatives com absolutes i usa una sintaxi parescuda als paths dels sistemes de fitxers per a travessar l'arbre del document.

Algunes expressions bàsiques d'XPath són:

|   Expressió   | Selecciona                 |
|---------------|----------------------------|
| `/`           | L'arrel del document       |
| `element`     | Fills amb aquest nom       |
| `/arrel/fill` | Camí absolut               |
| `//element`   | Element a qualsevol nivell |
| `.`           | Node actual                |
| `..`          | Node pare                  |
| `@atribut`    | Atribut                    |
| `*`           | Qualsevol element          |
| `@*`          | Qualsevol atribut          |

Els predicats, o filtres, principals són els següents:

| Expressió                | Selecciona                    |
|--------------------------|-------------------------------|
| `element[1]`             | Primer element                |
| `element[last()]`        | Últim element                 |
| `element[@id]`           | Elements que tenen atribut id |
| `element[@id='A001']`    | Element amb id igual a 'A001' |
| `element[hores>100]`     | Elements on hores > 100       |
| `element[position()<=3]` | Els tres primers elements     |

Les funcions XPath més comunes són les següents:

| Funció              | Descripció            | Exemple                      |
|---------------------|-----------------------|------------------------------|
| `text()`            | Contingut textual     | `nom/text()`                 |
| `count()`           | Compta nodes          | `count(//alumne)`            |
| `sum()`             | Suma valors           | `sum(//hores)`               |
| `concat()`          | Concatena textos      | `concat(nom, ' ', cognoms)`  |
| `contains()`        | Cerca en text         | `contains(email, '@')`       |
| `substring()`       | Extreu subcadena      | `substring(data, 1, 4)`      |
| `normalize-space()` | Neteja espais         | `normalize-space(nom)`       |
| `translate()`       | Substitueix caràcters | `translate(nom, 'áé', 'ae')` |

## Plantilles

Les plantilles són el cor d'XSLT. Defineixen com transformar cada tipus de node del document XML d'entrada. Quan el processador XSLT troba un node que coincideix amb el patró d'una plantilla, executa el contingut d'aquesta plantilla per generar la sortida corresponent.

### Estructura bàsica

Una plantilla es defineix amb l'element `<xsl:template>` i l'atribut `match`, que indica a quins nodes s'aplica mitjançant una expressió XPath:

```xml
<xsl:template match="expressió-xpath">
    <!-- Contingut que es generarà quan es trobi un node coincident -->
</xsl:template>
```

Per exemple, la següent plantilla s'aplicarà cada vegada que el processador trobi un element `<alumne>`:

```xml
<xsl:template match="alumne">
    <div class="alumne">
        <xsl:value-of select="nom"/>
    </div>
</xsl:template>
```

Quan el processador trobi aquest XML:

```xml
<alumne>
    <nom>Maria</nom>
    <cognoms>García López</cognoms>
</alumne>
```

Generarà aquesta sortida:

```html
<div class="alumne">
    Maria
</div>
```

### La plantilla arrel

La plantilla que coincideix amb `/` (l'arrel del document) és el **punt d'entrada** de la transformació. És la primera plantilla que s'executa i normalment defineix l'estructura general del document de sortida:

```xml
<xsl:template match="/">
    <html>
        <head>
            <title>Document transformat</title>
        </head>
        <body>
            <xsl:apply-templates/>
        </body>
    </html>
</xsl:template>
```

L'element `<xsl:apply-templates/>` indica al processador que continui processant els nodes fills, cercant plantilles que hi coincideixin. Sense aquesta instrucció, el processament s'aturaria i els fills no es transformarien.

### Aplicació de plantilles

L'element `<xsl:apply-templates>` és fonamental per al funcionament recursiu d'XSLT. Indica al processador que ha de cercar i aplicar les plantilles coincidents als nodes seleccionats. Sense l'atribut `select`, processa tots els nodes fills del node actual:

```xml
<xsl:template match="curs">
    <div class="curs">
        <xsl:apply-templates/>  <!-- Processa TOTS els fills: assignatures, alumnes, etc. -->
    </div>
</xsl:template>
```

En canvi, amb l'atribut `select`, podem especificar exactament quins nodes volem processar i en quin ordre:

```xml
<xsl:template match="curs">
    <div class="curs">
        <!-- Primer processem les assignatures, després els alumnes -->
        <xsl:apply-templates select="assignatures"/>
        <xsl:apply-templates select="alumnes"/>
    </div>
</xsl:template>
```

Com a exemple, suposem aquest XML d'entrada:

```xml
<alumnes>
    <alumne>
        <nom>Maria</nom>
        <email>maria@cifpfbmoll.eu</email>
    </alumne>
    <alumne>
        <nom>Pere</nom>
        <email>pere@cifpfbmoll.eu</email>
    </alumne>
</alumnes>
```

Amb aquestes plantilles:

```xml
<!-- Plantilla per al contenidor d'alumnes -->
<xsl:template match="alumnes">
    <ul class="llista-alumnes">
        <xsl:apply-templates select="alumne"/>
    </ul>
</xsl:template>

<!-- Plantilla per a cada alumne individual -->
<xsl:template match="alumne">
    <li>
        &quote;<xsl:value-of select="nom"/>&quote; &lt;<xsl:value-of select="email"/>&gt;
    </li>
</xsl:template>
```

El resultat seria:

```html
<ul class="llista-alumnes">
    <li>"Maria" <maria@cifpfbmoll.eu></li>
    <li>"Pere" <pere@cifpfbmoll.eu></li>
</ul>
```

El processament segueix aquest flux:

1. Es troba `<alumnes>`, aplica la primera plantilla i genera `<ul>`.
2. `<xsl:apply-templates select="alumne"/>` indica que cal processar cada `<alumne>`.
3. Per a cada `<alumne>`, s'aplica la segona plantilla, que genera `<li>`.
4. Es tanca `</ul>`.

### Extracció de valors

L'element `<xsl:value-of>` extreu i insereix el valor de text d'un node o expressió XPath a la sortida. És l'eina principal per obtenir dades del document XML. L'atribut `select` especifica quin valor extreure:

```xml
<xsl:template match="alumne">
    <p>Nom: <xsl:value-of select="nom"/></p>
    <p>Email: <xsl:value-of select="email"/></p>
</xsl:template>
```

Si l'XML conté:

```xml
<alumne>
    <nom>Maria</nom>
    <email>maria@cifpfbmoll.eu</email>
</alumne>
```

La sortida serà:

```html
<p>Nom: Maria</p>
<p>Email: maria@cifpfbmoll.eu</p>
```

El punt (`.`) representa el node actual en `XPath`. És útil quan ja estem dins del node del qual volem extreure el valor:

```xml
<xsl:template match="nom">
    <strong><xsl:value-of select="."/></strong>
</xsl:template>
```

Si el processador aplica aquesta plantilla a `<nom>Maria</nom>`, la sortida serà `<strong>Maria</strong>`.

Per accedir al valor d'un atribut, s'utilitza `@` seguit del nom de l'atribut:

```xml
<xsl:template match="alumne">
    <!-- Accés a l'atribut de l'element XML dins d'un atribut HTML -->
    <div id="{@id}">
        <p>Identificador: <xsl:value-of select="@id"/></p>
        <p>Nom: <xsl:value-of select="nom"/></p>
    </div>
</xsl:template>
```

Si l'XML és `<alumne id="A001"><nom>Maria</nom></alumne>`, la sortida serà:

```html
<div id="A001">
    <p>Identificador: A001</p>
    <p>Nom: Maria</p>
</div>
```

Fixa't en la sintaxi `{@id}` dins de l'atribut HTML. Les claus `{}` s'anomenen **plantilles de valor d'atribut** (Attribute Value Templates) i permeten inserir valors dinàmics dins d'atributs.

### Comparativa

Els elements `apply-templates` i `value-of` tenen propòsits molt diferents i complementaris:

| Aspecte      | `<xsl:apply-templates>`                  | `<xsl:value-of>`                      |
|--------------|------------------------------------------|---------------------------------------|
| Propòsit     | Controlar el flux de processament        | Extreure dades                        |
| Funcionament | Cerca i aplica plantilles coincidents    | Avalua l'expressió i insereix el text |
| Processament | Recursiu, continua amb altres plantilles | Directe, s'atura aquí                 |
| Sortida      | Pot generar estructures complexes        | Només text pla                        |
| Ús típic     | Processar nodes fills estructurats       | Obtenir el valor final d'un camp      |

**Regla pràctica:** Utilitza `apply-templates` quan vulguis que el contingut es processi amb altres plantilles, i `value-of` quan vulguis inserir directament un valor de text.

### Iteració

L'element `<xsl:for-each>` permet iterar sobre un conjunt de nodes sense necessitat de definir una plantilla separada. És útil quan la transformació és senzilla i no es reutilitzarà. La seva intaxi bàsica és:

```xml
<xsl:for-each select="expressió-xpath">
    <!-- Contingut a repetir per cada node -->
</xsl:for-each>
```

El següent exemple permet generar una taula:

```xml
<xsl:template match="alumnes">
    <table>
        <thead>
            <tr>
                <th>Nom</th>
                <th>Cognoms</th>
                <th>Email</th>
            </tr>
        </thead>
        <tbody>
            <xsl:for-each select="alumne">
                <tr>
                    <td><xsl:value-of select="nom"/></td>
                    <td><xsl:value-of select="cognoms"/></td>
                    <td><xsl:value-of select="email"/></td>
                </tr>
            </xsl:for-each>
        </tbody>
    </table>
</xsl:template>
```

Si tenim tres alumnes, es generaran tres files `<tr>` dins del `<tbody>`.

Tant `for-each` com `apply-templates` permeten processar múltiples nodes, però tenen diferències importants:

| Aspecte        | `<xsl:for-each>`                   | `<xsl:apply-templates>`                                |
|----------------|------------------------------------|--------------------------------------------------------|
| Modularitat    | Tot el codi en un lloc             | Plantilles separades i reutilitzables                  |
| Mantenibilitat | Pot crear plantilles llargues      | Codi més organitzat                                    |
| Reutilització  | No es pot reutilitzar              | Les plantilles es poden aplicar des de diferents llocs |
| Recomanació    | Transformacions simples i puntuals | Transformacions complexes o reutilitzables             |

### Ordenació

L'element `<xsl:sort>` permet ordenar els nodes abans de processar-los. Es col·loca dins de `<xsl:for-each>` o `<xsl:apply-templates>`. La seva sintaxi és la següent:

```xml
<xsl:sort select="expressió" order="ascending|descending" data-type="text|number"/>
```

On:

* `select`: Camp pel qual ordenar.
* `order`: Direcció de l'ordenació (`ascending` per defecte, o `descending`).
* `data-type`: Tipus de dades (`text` per defecte, o `number` per a valors numèrics).

El següent exemple permet ordenar alumnes per cognoms:

```xml
<xsl:for-each select="alumne">
    <xsl:sort select="cognoms" order="ascending"/>
    <xsl:sort select="nom" order="ascending"/>
    <li>
        <xsl:value-of select="cognoms"/>, <xsl:value-of select="nom"/>
    </li>
</xsl:for-each>
```

En aquest exemple, els alumnes s'ordenen primer per cognoms i, en cas d'empat, per nom. Ambdós en ordre ascendent (A-Z).

El següent exemple ordena assignatures per hores (descendent):

```xml
<xsl:for-each select="assignatura">
    <xsl:sort select="hores" data-type="number" order="descending"/>
    <tr>
        <td><xsl:value-of select="nom"/></td>
        <td><xsl:value-of select="hores"/>h</td>
    </tr>
</xsl:for-each>
```

Fixa't en `data-type="number"`. Sense aquest atribut, "128" s'ordenaria abans que "66" perquè el caràcter "1" ve abans que "6" en ordre alfabètic. Amb `data-type="number"`, es comparen com a números reals.

L'ordenació també funciona amb `apply-templates`:

```xml
<xsl:apply-templates select="alumne">
    <xsl:sort select="cognoms"/>
    <xsl:sort select="nom"/>
</xsl:apply-templates>
```

### Condició simple

L'element `<xsl:if>` permet incloure contingut a la sortida només si es compleix una condició. La seva sintaxi és la següent:

```xml
<xsl:if test="expressió-booleana">
    <!-- Contingut que es genera si la condició és certa -->
</xsl:if>
```

El següent exemple mostra un avís si l'assignatura té moltes hores:

```xml
<xsl:template match="assignatura">
    <div class="assignatura">
        <xsl:value-of select="nom"/>
        <xsl:if test="hores > 100">
            <span class="avis">Assignatura extensa!</span>
        </xsl:if>
    </div>
</xsl:template>
```

El següent exemple mostra un camp només si existeix:

```xml
<xsl:template match="alumne">
    <div class="alumne">
        <p><xsl:value-of select="nom"/> <xsl:value-of select="cognoms"/></p>
        <xsl:if test="telefon">
            <p>Telèfon: <xsl:value-of select="telefon"/></p>
        </xsl:if>
    </div>
</xsl:template>
```

Si l'element `<telefon>` no existeix dins de l'alumne, no es mostrarà res.

El següent exemple comprova el valor d'un atribut:

```xml
<xsl:if test="@actiu = 'si'">
    <span class="badge-actiu">Actiu</span>
</xsl:if>
```

Una limitació important és que `<xsl:if>` no té clàusula `else`. Si necessites una alternativa quan la condició és falsa, cal usar `<xsl:choose>`.

### Condició múltiple

L'element `<xsl:choose>` permet avaluar múltiples condicions, similar a una estructura `switch` o `match` en altres llenguatges. La seva sintaxi és la següent:

```xml
<xsl:choose>
    <xsl:when test="condició1">
        <!-- Contingut si condició1 és certa -->
    </xsl:when>
    <xsl:when test="condició2">
        <!-- Contingut si condició2 és certa -->
    </xsl:when>
    <xsl:otherwise>
        <!-- Contingut si cap condició anterior és certa -->
    </xsl:otherwise>
</xsl:choose>
```

On:

* Les condicions s'avaluen en ordre.
* S'executa només el primer `<xsl:when>` que sigui cert.
* `<xsl:otherwise>` és opcional i s'executa si cap `<xsl:when>` és cert.

El següent exemple classifica assignatures per càrrega horària:

```xml
<xsl:template match="assignatura">
    <tr>
        <td><xsl:value-of select="nom"/></td>
        <td><xsl:value-of select="hores"/>h</td>
        <td>
            <xsl:choose>
                <xsl:when test="hores >= 120">
                    <span class="carrega-alta">Càrrega alta</span>
                </xsl:when>
                <xsl:when test="hores >= 80">
                    <span class="carrega-mitjana">Càrrega mitjana</span>
                </xsl:when>
                <xsl:otherwise>
                    <span class="carrega-baixa">Càrrega baixa</span>
                </xsl:otherwise>
            </xsl:choose>
        </td>
    </tr>
</xsl:template>
```

El següent exemple aplica un format condicional segons la posició:

```xml
<xsl:for-each select="alumne">
    <xsl:choose>
        <xsl:when test="position() = 1">
            <li class="primer"><xsl:value-of select="nom"/> (Primer)</li>
        </xsl:when>
        <xsl:when test="position() = last()">
            <li class="ultim"><xsl:value-of select="nom"/> (Últim)</li>
        </xsl:when>
        <xsl:otherwise>
            <li><xsl:value-of select="nom"/></li>
        </xsl:otherwise>
    </xsl:choose>
</xsl:for-each>
```

Les funcions `position()` i `last()` retornen la posició actual i el nombre total d'elements, respectivament.

## Variables

Les variables en XSLT permeten emmagatzemar valors per reutilitzar-los al llarg de la transformació. A diferència de la majoria de llenguatges de programació, les variables XSLT són **immutables**: un cop definides, no es poden modificar. Això reflecteix la naturalesa declarativa (no imperativa) d'XSLT.

Les variables es defineixen amb l'element `<xsl:variable>` i es referencien amb el prefix `$` seguit del nom. El valor s'especifica directament com a contingut de l'element:

```xml
<xsl:variable name="titol">Llistat d'alumnes del curs ASIX</xsl:variable>
```

Per utilitzar-la:

```xml
<title><xsl:value-of select="$titol"/></title>
```

Una sortida d'exemple seria:

```html
<title>Llistat d'alumnes del curs ASIX</title>
```

### Valors calculats

L'atribut `select` permet assignar el resultat d'una expressió `XPath`:

```xml
<xsl:variable name="total-alumnes" select="count(//alumne)"/>
<xsl:variable name="total-hores" select="sum(//assignatura/hores)"/>
<xsl:variable name="primer-alumne" select="//alumne[1]/nom"/>
```

Exemple d'ús:

```xml
<p>Aquest curs té <xsl:value-of select="$total-alumnes"/> alumnes matriculats.</p>
<p>La càrrega lectiva total és de <xsl:value-of select="$total-hores"/> hores.</p>
```

Si el document té 10 alumnes i 320 hores totals, la sortida serà:

```html
<p>Aquest curs té 10 alumnes matriculats.</p>
<p>La càrrega lectiva total és de 320 hores.</p>
```

### Contingut XML

Una variable pot contenir fragments XML complets, útil per definir blocs reutilitzables:

```xml
<xsl:variable name="capcalera">
    <header class="pagina-header">
        <h1>CIFP Francesc de Borja Moll</h1>
        <p>Formació Professional a Palma</p>
    </header>
</xsl:variable>
```

Per inserir contingut XML emmagatzemat en una variable, cal usar `<xsl:copy-of>` en lloc de `<xsl:value-of>`:

```xml
<body>
    <xsl:copy-of select="$capcalera"/>
    <!-- Resta del contingut -->
</body>
```

Sortida:

```html
<body>
    <header class="pagina-header">
        <h1>CIFP Francesc de Borja Moll</h1>
        <p>Formació Professional a Palma</p>
    </header>
    <!-- Resta del contingut -->
</body>
```

### Diferències

Les diferències entre `value-of` i `copy-of` són:

| Element          | Comportament                                                | Ús típic                                     |
|------------------|-------------------------------------------------------------|----------------------------------------------|
| `<xsl:value-of>` | Extreu només el contingut de text, descartant les etiquetes | Variables amb valors simples (text, números) |
| `<xsl:copy-of>`  | Copia l'estructura XML completa, mantenint les etiquetes    | Variables amb fragments XML                  |

Exemple il·lustratiu:

```xml
<xsl:variable name="fragment">
    <p>Text amb <strong>negreta</strong></p>
</xsl:variable>

<!-- Amb value-of: només text -->
<xsl:value-of select="$fragment"/>
<!-- Sortida: Text amb negreta -->

<!-- Amb copy-of: estructura completa -->
<xsl:copy-of select="$fragment"/>
<!-- Sortida: <p>Text amb <strong>negreta</strong></p> -->
```

### Àmbit

Les variables tenen un àmbit limitat al seu element pare i els seus germans posteriors. Una variable definida dins d'una plantilla no és accessible des d'una altra plantilla.

Les variables definides com a filles directes de `<xsl:stylesheet>` són **globals** i accessibles des de qualsevol plantilla:

```xml
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <!-- Variables globals: accessibles a tot arreu -->
    <xsl:variable name="any-actual">2025</xsl:variable>
    <xsl:variable name="nom-centre">CIFP Francesc de Borja Moll</xsl:variable>
    
    <xsl:template match="/">
        <html>
            <head>
                <title><xsl:value-of select="$nom-centre"/></title>
            </head>
            <body>
                <xsl:apply-templates/>
                <footer>© <xsl:value-of select="$any-actual"/></footer>
            </body>
        </html>
    </xsl:template>
    
    <xsl:template match="curs">
        <!-- $nom-centre és accessible aquí també -->
        <h1><xsl:value-of select="$nom-centre"/> - <xsl:value-of select="@id"/></h1>
    </xsl:template>
    
</xsl:stylesheet>
```

Les variables definides dins d'una plantilla són **locals** i només accessibles dins del seu àmbit:

```xml
<xsl:template match="alumne">
    <!-- Variable local: només accessible dins d'aquesta plantilla -->
    <xsl:variable name="nom-complet" 
                  select="concat(nom, ' ', cognoms)"/>
    
    <div class="alumne">
        <h3><xsl:value-of select="$nom-complet"/></h3>
        <p>Email: <xsl:value-of select="email"/></p>
    </div>
</xsl:template>
```

### Casos d'ús

Si un càlcul s'utilitza múltiples vegades, emmagatzemar-lo en una variable millora la llegibilitat i el rendiment:

```xml
<xsl:template match="assignatures">
    <xsl:variable name="total-hores" select="sum(assignatura/hores)"/>
    <xsl:variable name="num-assignatures" select="count(assignatura)"/>
    <xsl:variable name="mitjana-hores" select="$total-hores div $num-assignatures"/>
    
    <div class="estadistiques">
        <p>Total d'assignatures: <xsl:value-of select="$num-assignatures"/></p>
        <p>Total d'hores: <xsl:value-of select="$total-hores"/></p>
        <p>Mitjana d'hores per assignatura: <xsl:value-of select="format-number($mitjana-hores, '#.##')"/></p>
    </div>
</xsl:template>
```

Les variables també permeten simplificar expressions `XPath` llargues:

```xml
<xsl:template match="/">
    <!-- Sense variable: expressió repetida i llarga -->
    <p><xsl:value-of select="institut/curs/alumnes/alumne[1]/nom"/></p>
    <p><xsl:value-of select="institut/curs/alumnes/alumne[1]/email"/></p>
    
    <!-- Amb variable: més net i mantenible -->
    <xsl:variable name="primer" select="institut/curs/alumnes/alumne[1]"/>
    <p><xsl:value-of select="$primer/nom"/></p>
    <p><xsl:value-of select="$primer/email"/></p>
</xsl:template>
```

Finalment, les variables es poden combinar amb `<xsl:choose>` per assignar valors segons condicions:

```xml
<xsl:template match="assignatura">
    <xsl:variable name="classe-carrega">
        <xsl:choose>
            <xsl:when test="hores >= 120">carrega-alta</xsl:when>
            <xsl:when test="hores >= 80">carrega-mitjana</xsl:when>
            <xsl:otherwise>carrega-baixa</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    
    <div class="assignatura {$classe-carrega}">
        <xsl:value-of select="nom"/>
    </div>
</xsl:template>
```

Fixa't en l'ús de `{$classe-carrega}` dins l'atribut `class`. Les claus permeten inserir el valor de la variable dins d'un atribut (Attribute Value Template).

### Immutabilitat

La immutabilitat de les variables pot semblar una limitació, però té avantatges:

* Predictibilitat: El valor d'una variable és sempre el mateix, facilitant la depuració.
* Paral·lelització: El processador pot executar parts de la transformació en paral·lel sense preocupar-se per canvis d'estat.
* Coherència funcional: XSLT segueix un paradigma funcional on les transformacions no tenen efectes secundaris.

Si necessites un valor diferent segons el context, defineix una nova variable amb un altre nom o utilitza plantilles diferents.

## Exemple complet

Una vegada hem explicat els eines que tenim al nostre abast a l'hora d'aplicar transformacions XSLT a documents XML, anem a transformar {{< icon "download" >}} [l'XML de l'institut](/downloads/xml/xslt/institut.xml) a HTML. El document XML d'entrada és el següent:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="institut.xsl"?>
<institut>
    <nom>CIFP Francesc de Borja Moll</nom>
    <codi>08012345</codi>
    <any-academic>2025-26</any-academic>
    
    <curs id="ASIX" nom="Administració de Sistemes Informàtics en Xarxa">
        <assignatures>
            <assignatura codi="LLM">
                <nom>Llenguatges de Marques i Sistemes de Gestió d'Informació</nom>
                <hores>128</hores>
            </assignatura>
            [..]
        </assignatures>
        
        <alumnes>
            <alumne id="A001">
                <nom>Maria</nom>
                <cognoms>García López</cognoms>
                <data-naixement>2005-03-15</data-naixement>
                <email>maria.garcia@cifpfbmoll.eu</email>
            </alumne>
            [..]
        </alumnes>
    </curs>
</institut>
```

I el {{< icon "download" >}} [full d'estils XSLT usat](/downloads/xml/xslt/institut.xsl) serà el següent, el qual podríem guardaren un fitxer `institut.xsl`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <!-- Configuració de sortida HTML5 -->
    <xsl:output 
        method="html" 
        encoding="UTF-8" 
        indent="yes"
        doctype-system="about:legacy-compat"/>
    
    <!-- Variables globals -->
    <xsl:variable name="total-hores" select="sum(//assignatura/hores)"/>
    <xsl:variable name="total-alumnes" select="count(//alumne)"/>
    
    <!-- Plantilla principal (arrel) -->
    <xsl:template match="/">
        <html lang="ca">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                <title><xsl:value-of select="institut/nom"/> - <xsl:value-of select="institut/curs/@id"/></title>
                <link rel="stylesheet" type="text/css" href="institut.css"/>
            </head>
            <body>
                <div class="container">
                    <xsl:apply-templates select="institut"/>
                </div>
            </body>
        </html>
    </xsl:template>
    
    <!-- Plantilla: institut -->
    <xsl:template match="institut">
        <header>
            <h1><xsl:value-of select="nom"/></h1>
            <p class="codi">Codi del centre: <xsl:value-of select="codi"/></p>
            <p>Any acadèmic: <xsl:value-of select="any-academic"/></p>
            <span class="curs">
                <xsl:value-of select="curs/@id"/> - <xsl:value-of select="curs/@nom"/>
            </span>
        </header>
        
        <!-- Resum estadístic -->
        <div class="resum">
            <div class="resum-item">
                <div class="valor"><xsl:value-of select="$total-alumnes"/></div>
                <div class="etiqueta">Alumnes matriculats</div>
            </div>
            <div class="resum-item">
                <div class="valor"><xsl:value-of select="count(//assignatura)"/></div>
                <div class="etiqueta">Assignatures</div>
            </div>
            <div class="resum-item">
                <div class="valor"><xsl:value-of select="$total-hores"/></div>
                <div class="etiqueta">Hores totals</div>
            </div>
        </div>
        
        <xsl:apply-templates select="curs/assignatures"/>
        <xsl:apply-templates select="curs/alumnes"/>
        
        <footer>
            <p>Document generat mitjançant transformació XSLT</p>
            <p><xsl:value-of select="nom"/> © <xsl:value-of select="substring(any-academic, 1, 4)"/></p>
        </footer>
    </xsl:template>
    
    <!-- Plantilla: assignatures -->
    <xsl:template match="assignatures">
        <section>
            <h2>📚 Assignatures del curs</h2>
            <table>
                <thead>
                    <tr>
                        <th>Codi</th>
                        <th>Nom de l'assignatura</th>
                        <th class="hores">Hores</th>
                        <th>Càrrega</th>
                    </tr>
                </thead>
                <tbody>
                    <xsl:for-each select="assignatura">
                        <xsl:sort select="hores" data-type="number" order="descending"/>
                        <tr>
                            <td><span class="codi-assig"><xsl:value-of select="@codi"/></span></td>
                            <td><xsl:value-of select="nom"/></td>
                            <td class="hores"><xsl:value-of select="hores"/>h</td>
                            <td>
                                <xsl:choose>
                                    <xsl:when test="hores >= 120">
                                        <span class="hores-alta">Alta</span>
                                    </xsl:when>
                                    <xsl:when test="hores >= 80">
                                        <span class="hores-mitjana">Mitjana</span>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <span class="hores-baixa">Baixa</span>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </td>
                        </tr>
                    </xsl:for-each>
                </tbody>
            </table>
        </section>
    </xsl:template>
    
    <!-- Plantilla: alumnes -->
    <xsl:template match="alumnes">
        <section>
            <h2>👥 Alumnes matriculats</h2>
            <div class="alumnes-grid">
                <xsl:for-each select="alumne">
                    <xsl:sort select="cognoms"/>
                    <xsl:sort select="nom"/>
                    <div class="alumne-card">
                        <span class="id"><xsl:value-of select="@id"/></span>
                        <div class="nom-complet">
                            <xsl:value-of select="cognoms"/>, <xsl:value-of select="nom"/>
                        </div>
                        <a class="email" href="mailto:{email}">
                            <xsl:value-of select="email"/>
                        </a>
                        <div class="edat">
                            Naixement: <xsl:value-of select="data-naixement"/>
                        </div>
                    </div>
                </xsl:for-each>
            </div>
        </section>
    </xsl:template>
    
</xsl:stylesheet>
```

Cal notar que el fitxer `institut.xsd` fa referència al fitxer `institut.css`, que {{< icon "download" >}} [també haurem de menester](/downloads/xml/xslt/institut.css).

## Anàlisi de la transformació

Les tècniques utilitzades són les següents:

| Tècnica             | Ubicació              | Propòsit                                       |
|---------------------|-----------------------|------------------------------------------------|
| Variables globals   | Capçalera             | Calcular estadístiques reutilitzables          |
| `apply-templates`   | Diverses              | Delegar processament a plantilles específiques |
| `for-each` + `sort` | Assignatures, alumnes | Iterar ordenadament                            |
| `choose/when`       | Assignatures          | Classificar per càrrega horària                |
| `value-of`          | Diverses              | Extreure valors de text                        |
| `substring()`       | Footer                | Extreure l'any del curs acadèmic               |
| Atributs XPath      | Enllaç email          | Generar `mailto:` dinàmic                      |

I les transformacions aplicades són les següents:

1. Reestructuració: L'XML pla es converteix en HTML semàntic amb seccions.
2. Ordenació: Assignatures per hores (descendent), alumnes per cognoms.
3. Càlculs: Suma d'hores, comptatge d'alumnes.
4. Enriquiment: Classificació de càrrega horària, enllaços mailto.
5. Presentació: Graella responsive, taula estilitzada, targetes d'alumnes.

## Execució de transformacions

Podem usar un navegador web per a dur a terme les transformacions. Simplement obre {{< icon "download" >}} [el fitxer XML](/downloads/xml/xslt/institut.xml) que conté la instrucció `xml-stylesheet` en un navegador modern. Firefox ofereix el millor suport.

També podem usar `xmllint` a la línia de comandes d'un Linux:

```bash
xsltproc institut.xsl institut.xml > institut.html
```

## Versions d'XSLT

XSLT ha evolucionat en tres versions principals, cadascuna afegint funcionalitats per cobrir necessitats que la versió anterior no resolia adequadament. Per il·lustrar les diferències, vegem com es resol un problema comú: agrupar alumnes per any de naixement.

### XSLT 1.0 (1999)

La primera versió, desenvolupada pel [*](W3C), va establir els fonaments del llenguatge. És senzilla, ben documentada i suportada per tots els navegadors i processadors. La majoria de tutorials i exemples que es troben a Internet usen aquesta versió.

Limitacions principals:

* No es poden definir funcions pròpies
* L'agrupació de dades requereix tècniques complexes (mètode Muenchian)
* No suporta expressions regulars
* Tipus de dades molt bàsics (tot és text o conjunts de nodes)

En la versió 1.0, l'agrupació requereix el mètode Muenchian, que utilitza claus (`<xsl:key>`) i una tècnica no intuïtiva:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <xsl:output method="html" encoding="UTF-8" indent="yes"/>
    
    <!-- Definim una clau per agrupar alumnes per any de naixement -->
    <xsl:key name="alumnes-per-any" match="alumne" 
             use="substring(data-naixement, 1, 4)"/>
    
    <xsl:template match="/">
        <html>
            <head><title>Alumnes per any de naixement</title></head>
            <body>
                <h1>Alumnes agrupats per any de naixement</h1>
                
                <!-- Iterem només el primer alumne de cada grup (mètode Muenchian) -->
                <xsl:for-each select="//alumne[generate-id() = 
                    generate-id(key('alumnes-per-any', 
                    substring(data-naixement, 1, 4))[1])]">
                    
                    <xsl:sort select="substring(data-naixement, 1, 4)"/>
                    
                    <xsl:variable name="any" select="substring(data-naixement, 1, 4)"/>
                    
                    <h2>Any <xsl:value-of select="$any"/></h2>
                    <ul>
                        <!-- Mostrem tots els alumnes d'aquest any -->
                        <xsl:for-each select="key('alumnes-per-any', $any)">
                            <xsl:sort select="cognoms"/>
                            <li>
                                <xsl:value-of select="cognoms"/>, 
                                <xsl:value-of select="nom"/>
                            </li>
                        </xsl:for-each>
                    </ul>
                </xsl:for-each>
            </body>
        </html>
    </xsl:template>
    
</xsl:stylesheet>
```

Aquesta solució funciona però és difícil d'entendre i recordar.

### XSLT 2.0 (2007)

Introdueix millores substancials per facilitar tasques que eren complicades en la versió 1.0. El canvi més notable és el suport complet per als tipus de dades d'XML Schema (dates, números, booleans...) i la possibilitat de definir funcions pròpies.

Novetats destacades:

* Element `<xsl:for-each-group>` per agrupar dades fàcilment.
* Funcions definides per l'usuari amb `<xsl:function>`.
* Suport per a expressions regulars.
* Múltiples documents de sortida amb `<xsl:result-document>`.
* Tipus de dades rics (xs:date, xs:integer, xs:boolean...).

La versió 2.0 introdueix `<xsl:for-each-group>`, que fa l'agrupació molt més intuïtiva:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema">
    
    <xsl:output method="html" encoding="UTF-8" indent="yes"/>
    
    <xsl:template match="/">
        <html>
            <head><title>Alumnes per any de naixement</title></head>
            <body>
                <h1>Alumnes agrupats per any de naixement</h1>
                
                <!-- Agrupació directa i clara -->
                <xsl:for-each-group select="//alumne" 
                    group-by="year-from-date(xs:date(data-naixement))">
                    
                    <xsl:sort select="current-grouping-key()"/>
                    
                    <h2>Any <xsl:value-of select="current-grouping-key()"/></h2>
                    <ul>
                        <xsl:for-each select="current-group()">
                            <xsl:sort select="cognoms"/>
                            <li>
                                <xsl:value-of select="cognoms"/>, 
                                <xsl:value-of select="nom"/>
                            </li>
                        </xsl:for-each>
                    </ul>
                </xsl:for-each-group>
            </body>
        </html>
    </xsl:template>
    
</xsl:stylesheet>
```

El codi és més curt, més llegible i més fàcil de mantenir.

### XSLT 3.0 (2017)

La versió més recent, orientada a processament de grans volums de dades i integració amb tecnologies modernes. Afegeix funcions anònimes, streaming per a documents grans i millor gestió d'errors.

Novetats destacades:

* Funcions anònimes (lambdas).
* Processament en streaming (per a fitxers molt grans).
* Mapes i arrays com a tipus de dades.
* Millor gestió d'errors amb `<xsl:try>` i `<xsl:catch>`.
* Suport per a JSON.

La versió 3.0 permet simplificar encara més usant funcions anònimes i altres millores:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema">
    
    <xsl:output method="html" encoding="UTF-8" indent="yes"/>
    
    <!-- Funció anònima per extreure l'any -->
    <xsl:variable name="obtenir-any" as="function(element()) as xs:integer"
        select="function($a as element()) { year-from-date(xs:date($a/data-naixement)) }"/>
    
    <xsl:template match="/">
        <html>
            <head><title>Alumnes per any de naixement</title></head>
            <body>
                <h1>Alumnes agrupats per any de naixement</h1>
                
                <xsl:for-each-group select="//alumne" group-by="$obtenir-any(.)">
                    <xsl:sort select="current-grouping-key()"/>
                    
                    <h2>Any <xsl:value-of select="current-grouping-key()"/></h2>
                    <p>Total: <xsl:value-of select="count(current-group())"/> alumnes</p>
                    <ul>
                        <!-- Ordenació amb funció anònima in-line -->
                        <xsl:for-each select="sort(current-group(), (), 
                            function($a) { $a/cognoms })">
                            <li>
                                <xsl:value-of select="cognoms"/>, 
                                <xsl:value-of select="nom"/>
                            </li>
                        </xsl:for-each>
                    </ul>
                </xsl:for-each-group>
            </body>
        </html>
    </xsl:template>
    
</xsl:stylesheet>
```

### Comparativa

Aquesta és una taula resum de les característiques de cada versió:

| Característica          | XSLT 1.0                   | XSLT 2.0                      | XSLT 3.0                      |
|-------------------------|----------------------------|-------------------------------|-------------------------------|
| Any de publicació       | 1999                       | 2007                          | 2017                          |
| Agrupació de dades      | Mètode Muenchian (complex) | `for-each-group` (simple)     | `for-each-group` + millores   |
| Funcions personalitzades| No disponible              | `<xsl:function>`              | Funcions anònimes (lambdas)   |
| Tipus de dades          | Text i nodes               | Tipus XSD (date, integer...)  | Tipus XSD + mapes i arrays    |
| Expressions regulars    | No                         | Sí (`matches()`, `replace()`) | Sí, amb millores              |
| Múltiples sortides      | No                         | `<xsl:result-document>`       | Sí                            |
| Processament JSON       | No                         | No                            | Sí (`json-to-xml()`, etc.)    |
| Streaming (fitxers grans)| No                        | No                            | Sí                            |
| Gestió d'errors         | Limitada                   | Limitada                      | `<xsl:try>` / `<xsl:catch>`   |

Els navegadors web suporten plenament la versió 1.0, però no les següents versions. Per treballar amb les versions 2.0 i 3.0 necessitaràs Saxon, el processador de referència per a XSLT 2.0 i 3.0, desenvolupat per Michael Kay, editor de l'especificació XSLT 2.0. Està escrit en Java i té *bindings* per a C, Python i PHP.

## Resum

XSLT és un llenguatge potent per transformar documents XML. Combinant plantilles, XPath i estructures de control, permet convertir dades XML en qualsevol format de sortida desitjat. Tot i tenir una corba d'aprenentatge costeruda, XSLT continua sent una eina valuosa en entorns empresarials i de publicació on XML és prevalent.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Transformació bàsica a HTML**

Crea un full XSLT per transformar el següent document XML `cinema.xml` d'una **programació de cinema** a una pàgina HTML.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="cinema.xsl"?>
<cinema nom="Cines Ocimax" ciutat="Palma">
    <sala id="S1" capacitat="200">
        <sessio hora="16:00">
            <pelicula id="P001">
                <titol>Dune: Part Two</titol>
                <director>Denis Villeneuve</director>
                <durada>166</durada>
                <classificacio>12</classificacio>
            </pelicula>
        </sessio>
        <sessio hora="19:30">
            <pelicula id="P002">
                <titol>Oppenheimer</titol>
                <director>Christopher Nolan</director>
                <durada>180</durada>
                <classificacio>12</classificacio>
            </pelicula>
        </sessio>
    </sala>
    <sala id="S2" capacitat="150">
        <sessio hora="17:00">
            <pelicula id="P003">
                <titol>Inside Out 2</titol>
                <director>Kelsey Mann</director>
                <durada>96</durada>
                <classificacio>TP</classificacio>
            </pelicula>
        </sessio>
        <sessio hora="20:00">
            <pelicula id="P001">
                <titol>Dune: Part Two</titol>
                <director>Denis Villeneuve</director>
                <durada>166</durada>
                <classificacio>12</classificacio>
            </pelicula>
        </sessio>
    </sala>
</cinema>
```

Requisits del full XSLT:

1. **Estructura HTML completa** amb `<html>`, `<head>` (amb títol dinàmic usant el nom del cinema) i `<body>`.
2. **Capçalera** amb el nom del cinema i la ciutat.
3. **Una secció per a cada sala** que mostri:
   * Identificador i capacitat de la sala.
   * Llista de sessions amb hora i títol de la pel·lícula.
4. **Usa `<xsl:value-of>`** per extreure valors.
5. **Usa `<xsl:for-each>`** per iterar sobre sales i sessions.
6. **Usa `<xsl:apply-templates>`** almanco una vegada.

Estructura de sortida esperada:

```html
<html>
<head><title>Programació - Cines Ocimax</title></head>
<body>
    <h1>Cines Ocimax</h1>
    <p>Ciutat: Palma</p>
    
    <section class="sala">
        <h2>Sala S1 (200 places)</h2>
        <ul>
            <li>16:00 - Dune: Part Two (166 min)</li>
            <li>19:30 - Oppenheimer (180 min)</li>
        </ul>
    </section>
    <!-- més sales... -->
</body>
</html>
```

Una vegada resolt l'exercici hauries de tenir els fitxers `cinema.xml`, `cinema.xsl` i `cinema.html`.

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/). Obre el fitxer HTML resultant al navegador per verificar la transformació.

### Exercici 2

**Ordenació, condicions i càlculs**

Partint del document XML de l'exercici anterior, crea un nou full XSLT (`cinema-avancat.xsl`) amb les funcionalitats següents:

1. **Ordenació:**
   * Les sessions de cada sala han d'aparèixer ordenades per hora.
   * Afegeix una secció "Totes les pel·lícules" al final amb les pel·lícules ordenades alfabèticament per títol (sense repeticions — pots mostrar-les totes, les repeticions no es penalitzaran).

2. **Condicions amb `<xsl:if>`:**
   * Mostra un avís "🎬 Sessió llarga" al costat de les pel·lícules que durin més de 150 minuts.
   * Mostra la classificació amb un estil diferent si és "TP" (tots els públics).

3. **Condicions amb `<xsl:choose>`:** Classifica cada pel·lícula segons la durada:
   * Menys de 100 min: "Curta".
   * Entre 100 i 150 min: "Estàndard".
   * Més de 150 min: "Llarga".

4. **Càlculs amb variables:** Crea les següents variables globals i mostra aquestes estadístiques en un resum a la capçalera:
   * Total de sessions (`count()`).
   * Durada mitjana de les pel·lícules (`sum()` dividit per `count()`).

5. **Attribute Value Templates:** Usa `{}` per generar atributs dinàmics (per exemple, `class="{@id}"` o `id="sala-{@id}"`).

Estructura de sortida esperada (parcial):

```html
<div class="resum">
    <p>Total sessions: 4</p>
    <p>Durada mitjana: 152 minuts</p>
</div>

<section class="sala" id="sala-S1">
    <h2>Sala S1</h2>
    <div class="sessio">
        <span class="hora">16:00</span>
        <span class="titol">Dune: Part Two</span>
        <span class="durada categoria-llarga">166 min (Llarga) 🎬 Sessió llarga</span>
    </div>
    <!-- ... -->
</section>
```

Validació: Obre el fitxer XML, modificat per usar el nou XSL `cinema-avancat.xsl`, al navegador.

### Exercici 3

**Transformació completa amb múltiples plantilles**

Crea un sistema complet de transformació XSLT per a un **catàleg de receptes de cuina**. Aquest exercici requereix dissenyar tant l'XML com l'XSLT.

Requisits del document XML (`receptes.xml`):

1. Element arrel `<receptari>` amb atribut `autor`.
2. Almenys 4 receptes amb:
   * Atributs: `id`, `dificultat` ("fàcil", "mitjana", "difícil"), `temps` (en minuts).
   * Elements: `nom`, `categoria` (primers, segons, postres), `ingredients` (amb múltiples `ingredient`), `passos` (amb múltiples `pas`), `calories` (opcional).

Requisits del full XSLT (`receptes.xsl`):

1. **Plantilles separades** per a:
   * `/` (arrel): estructura HTML general.
   * `receptari`: capçalera i navegació.
   * `recepta`: targeta de cada recepta.
   * `ingredients`: llista d'ingredients.
   * `passos`: llista numerada de passos.

2. **Navegació per categories:**
   * Genera un índex a la capçalera amb enllaços a cada categoria.
   * Agrupa les receptes per categoria usant predicats XPath (`recepta[categoria='primers']`).

3. **Ordenació:** Receptes ordenades per temps de preparació dins de cada categoria.

4. **Condicions:**
   * Icona 🌱 si la recepta té manco de 300 calories.
   * Color diferent segons la dificultat.
   * Avís si el temps supera els 60 minuts.

5. **Variables:**
   * Variable global amb el total de receptes.
   * Variable local dins de cada recepta per calcular temps en hores i minuts si supera 60 min.

6. **Funcions XPath:**
   * Usa `count()` per mostrar el nombre d'ingredients.
   * Usa `concat()` per generar el text "Recepta X de Y".
   * Usa `position()` per numerar els passos.

Estructura de plantilles suggerida:

```xml
<!-- Plantilla arrel -->
<xsl:template match="/">
    <html>
        <head>...</head>
        <body>
            <xsl:apply-templates select="receptari"/>
        </body>
    </html>
</xsl:template>

<!-- Plantilla receptari -->
<xsl:template match="receptari">
    <header>...</header>
    <nav><!-- Índex per categories --></nav>
    
    <section id="primers">
        <h2>Primers plats</h2>
        <xsl:apply-templates select="recepta[categoria='primers']">
            <xsl:sort select="@temps" data-type="number"/>
        </xsl:apply-templates>
    </section>
    <!-- Més categories... -->
</xsl:template>

<!-- Plantilla recepta -->
<xsl:template match="recepta">
    <article class="recepta dificultat-{@dificultat}" id="{@id}">
        <h3><xsl:value-of select="nom"/></h3>
        <xsl:apply-templates select="ingredients"/>
        <xsl:apply-templates select="passos"/>
    </article>
</xsl:template>

<!-- Plantilla ingredients -->
<xsl:template match="ingredients">
    <div class="ingredients">
        <h4>Ingredients (<xsl:value-of select="count(ingredient)"/>)</h4>
        <ul>
            <xsl:for-each select="ingredient">
                <li><xsl:value-of select="."/></li>
            </xsl:for-each>
        </ul>
    </div>
</xsl:template>

<!-- Plantilla passos -->
<xsl:template match="passos">
    ...
</xsl:template>
```

Validació: Obre el fitxer XML al navegador per verificar la transformació completa.

### Execució

Per executar transformacions XSLT des de la línia de comandes:

```bash
# Amb xsltproc (XSLT 1.0)
xsltproc fitxer.xsl fitxer.xml > fitxer.html

# Obrir el resultat
firefox fitxer.html
```

Per provar directament al navegador, assegura't que el fitxer XML conté la instrucció de processament:

```xml
<?xml-stylesheet type="text/xsl" href="fitxer.xsl"?>
```
