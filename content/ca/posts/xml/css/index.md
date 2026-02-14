---
title: "Visualització amb CSS"
date: 2026-01-03
lastmod: 2026-01-11
description: "Aplicació de fulls d'estils CSS a documents XML. Enllaç amb instrucció de processament, selectors d'elements, propietats de visualització i exemple complet."
summary: "Estilització de documents XML amb CSS: enllaç, selectors i exemple pràctic complet."
categories: ["teaching"]
tags: ["xml", "css"]
series: ["XML"]
series_order: 6
weight: 60
slug: css
---

Els fulls d'estils CSS (Cascading Style Sheets) no són exclusius de l'HTML. Qualsevol document XML es pot visualitzar en un navegador aplicant-hi estils CSS. Això permet presentar dades XML de manera llegible sense necessitat de transformar-les a HTML.

Els avantatges d'usar CSS amb XML són:

* Senzillesa: CSS és un llenguatge conegut i fàcil d'aplicar.
* Separació: Les dades (XML) es mantenen separades de la presentació (CSS).
* Rapidesa: No cal processament addicional; el navegador aplica els estils directament.

Però també es pateixen una sèrie de limitacions:

* CSS no pot canviar l'ordre dels elements ni afegir contingut nou.
* No es poden fer operacions amb les dades.
* No es pot mostrar text que no existeixi al document.

Per a transformacions més complexes, cal usar XSLT, que veurem més endavant.

## Enllaçar un full CSS

La connexió entre un document XML i el seu full d'estils es fa mitjançant una **instrucció de processament** situada just després de la declaració XML:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/css" href="estils.css"?>
<arrel>
    [..]
</arrel>
```

Els atributs disponibles en aquesta instrucció són:

|   Atribut   | Descripció                         | Exemple                        |
|-------------|------------------------------------|--------------------------------|
| `type`      | Tipus MIME del full d'estils       | `text/css`                     |
| `href`      | Ruta al fitxer CSS                 | `estils.css`, `css/estils.css` |
| `media`     | Mitjà de sortida (opcional)        | `screen`, `print`              |
| `title`     | Títol del full d'estils (opcional) | `Estil principal`              |
| `alternate` | Si és un estil alternatiu          | `yes`, `no`                    |

Es poden enllaçar múltiples fulls d'estils:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/css" href="base.css"?>
<?xml-stylesheet type="text/css" href="colors.css"?>
<?xml-stylesheet type="text/css" href="impressio.css" media="print"?>
<document>
    [..]
</document>
```

## Selectors CSS

En XML, els selectors CSS funcionen de manera similar a HTML, però s'apliquen als noms dels elements XML.

El selector d'element selecciona tots els elements amb un nom determinat:

```css
/* Selecciona tots els elements <nom> */
nom {
    font-weight: bold;
}

/* Selecciona tots els elements <alumne> */
alumne {
    margin-bottom: 1em;
}
```

El selector descendent selecciona elements dins d'altres elements:

```css
/* Selecciona <nom> dins de <alumne> */
alumne nom {
    color: navy;
}

/* Selecciona <nom> dins de <assignatura> */
assignatura nom {
    color: darkgreen;
}
```

El selector de fill directe selecciona només fills immediats:

```css
/* Selecciona <nom> que sigui fill directe de <institut> */
institut > nom {
    font-size: 1.5em;
}
```

El selector d'atribut selecciona elements segons els seus atributs:

```css
/* Elements amb atribut id */
[id] {
    border-left: 3px solid blue;
}

/* Elements amb atribut codi="LLM" */
[codi="LLM"] {
    background-color: #ffe0e0;
}

/* Elements amb atribut que comença per "A" */
[id^="A"] {
    color: purple;
}
```

## Pseudoclasses CSS

Algunes pseudoclasses útils:

```css
/* Primer element d'un tipus */
alumne:first-of-type {
    border-top: 2px solid black;
}

/* Últim element d'un tipus */
alumne:last-of-type {
    border-bottom: 2px solid black;
}

/* Elements parells/senars (per a zebrat) */
alumne:nth-of-type(odd) {
    background-color: #f5f5f5;
}

alumne:nth-of-type(even) {
    background-color: #ffffff;
}
```

## La propietat display

Per defecte, els elements XML no tenen cap estil de visualització definit. La propietat `display` és fonamental per controlar com es mostren:

|     Valor      | Comportament                                        |
|----------------|-----------------------------------------------------|
| `block`        | Ocupa tota l'amplada, salt de línia abans i després |
| `inline`       | Flueix amb el text, sense salt de línia             |
| `inline-block` | Inline però accepta dimensions                      |
| `none`         | No es mostra                                        |
| `table`        | Es comporta com una taula                           |
| `table-row`    | Es comporta com una fila de taula                   |
| `table-cell`   | Es comporta com una cel·la de taula                 |
| `flex`         | Contenidor flexible                                 |
| `grid`         | Contenidor de graella                               |

Exemple bàsic d'ús de la propietat `display`:

```css
/* Elements contenidors com a blocs */
institut, curs, assignatures, alumnes {
    display: block;
}

/* Elements de dades en línia */
nom, cognoms, email {
    display: inline;
}

/* Ocultar elements */
codi, data-naixement {
    display: none;
}
```

## Pseudoelements CSS

Tot i que CSS no pot crear elements nous, pot afegir contingut decoratiu amb `::before` i `::after`:

```css
/* Afegir etiqueta abans del contingut */
email::before {
    content: "✉ ";
}

/* Afegir separador després */
nom::after {
    content: " | ";
}

/* Mostrar el valor d'un atribut */
assignatura::before {
    content: "[" attr(codi) "] ";
    font-weight: bold;
}
```

## Exemple complet

Anem a aplicar un full d'estils CSS a [l'exemple de l'institut](/xml/css/institut.xml) que hem usat en aquesta sèrie. El document XML quedaria segons segueix:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/css" href="institut.css"?>
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

Acompanyariem el document anterior amb el [corresponent full d'estils CSS](/xml/css/institut.css):

```css
/* ----- Estils generals ----- */

institut {
    display: block;
    font-family: 'Segoe UI', Roboto, Arial, sans-serif;
    font-size: 14px;
    line-height: 1.6;
    max-width: 900px;
    margin: 20px auto;
    padding: 20px;
    background-color: #f9f9f9;
    border: 1px solid #ddd;
    border-radius: 8px;
}

[..]
```

## Resultat visual

En obrir el document XML en un navegador modern (Firefox, Vivaldi, Brave), es mostrarà:

1. **Capçalera:** Nom del centre centrat i destacat, codi i any acadèmic.
2. **Secció d'assignatures:** Cada assignatura amb el seu codi en una etiqueta verda i les hores alineades a la dreta.
3. **Llistat d'alumnes:** Files amb efecte zebrat, identificador en blau, nom complet i email.
4. **Interactivitat:** Efecte hover als alumnes per ressaltar-los.

## Consideracions pràctiques

Quan és convenient usar CSS amb XML:

* **Visualització ràpida:** Per previsualitzar dades XML durant el desenvolupament.
* **Documents simples:** Quan l'estructura XML coincideix amb la presentació desitjada.
* **Prototipatge:** Per mostrar com es veuran les dades abans d'implementar XSLT.

Limitacions a recordar:

1. **No es pot reordenar:** Els elements es mostren en l'ordre del document.
2. **No hi ha taules automàtiques:** Cal usar `display: table` manualment.
3. **Sense lògica condicional:** No es pot mostrar contingut diferent segons valors.
4. **Navegació limitada:** Els enllaços no funcionen automàticament.

Per a presentacions elaborades o quan cal reestructurar les dades, XSLT és l'opció adequada.

## Resum

CSS ofereix una manera senzilla i directa d'aplicar estils a documents XML sense necessitat de transformació. Tot i les seves limitacions, és útil per a visualitzacions ràpides i documents amb estructures simples. La clau és entendre que CSS només pot modificar l'aparença visual, no l'estructura del document.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Estilització d'un catàleg de productes**

Crea un document XML que representi un **catàleg de productes d'una fruiteria** i un full d'estils CSS per visualitzar-lo al navegador de manera atractiva.

Requisits del document XML:

1. Element arrel `<fruiteria>` amb el nom de la botiga.
2. Almenys 3 categories de productes (fruites, verdures, fruits secs...).
3. Cada categoria amb almenys 3 productes.
4. Cada producte ha de tenir: nom, preu (amb atribut `unitat`: "kg", "unitat", "manat"...), origen i un atribut `ecologic` ("si"/"no").

Requisits del full d'estils CSS:

1. Usa la instrucció de processament `<?xml-stylesheet?>` per enllaçar el CSS.
2. Defineix `display` apropiat per a cada tipus d'element (block, inline, etc.).
3. Aplica estils diferenciats per categoria usant selectors descendents.
4. Mostra el valor de l'atribut `unitat` després del preu usant `::after` i `attr()`.
5. Destaca visualment els productes ecològics (selector d'atribut `[ecologic="si"]`).
6. Aplica efecte zebrat als productes de cada categoria.
7. Oculta algun element que no sigui rellevant per a la visualització (per exemple, un codi intern).

Estructura suggerida:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/css" href="fruiteria.css"?>
<fruiteria>
    <nom>Fruites Can Melció</nom>
    <categoria tipus="fruites">
        <producte ecologic="si">
            <nom>Taronja de Sóller</nom>
            <preu unitat="kg">2.50</preu>
            <origen>Mallorca</origen>
        </producte>
        <!-- més productes... -->
    </categoria>
    <!-- més categories... -->
</fruiteria>
```

Els fitxers a lliurar seran `fruiteria.xml` i `fruiteria.css`.

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/), i obre'l amb un navegador per verificar els estils.

### Exercici 2

**Agenda de contactes amb múltiples vistes**

Crea un document XML que representi una **agenda de contactes** i dos fulls d'estils CSS diferents: un per a visualització en pantalla i un altre optimitzat per a impressió.

Requisits del document XML:

1. Almenys 6 contactes amb: nom, telèfon (amb atribut `tipus`: "mòbil", "fix", "feina"), email, adreça i notes.
2. Cada contacte ha de tenir un atribut `categoria` ("família", "amics", "feina").
3. Alguns contactes poden tenir múltiples telèfons.

Requisits del CSS per a pantalla (`agenda-screen.css`):

1. Disseny visual atractiu amb colors i espaiat.
2. Icones o símbols abans dels camps (✆ per telèfon, ✉ per email, etc.) usant `::before`.
3. Estils diferents segons la categoria del contacte (colors de fons o vores).
4. Efecte hover als contactes.
5. Mostra el tipus de telèfon entre parèntesis després del número.

Requisits del CSS per a impressió (`agenda-print.css`):

1. Sense colors de fons (estalvi de tinta).
2. Tipografia serif i mida adequada per a lectura en paper.
3. Vores senzilles per separar contactes.
4. Oculta les notes (potser contenen informació privada).
5. Mostra la categoria com a text en lloc de color.

Enllaç dels dos fulls d'estils:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/css" href="agenda-screen.css" media="screen"?>
<?xml-stylesheet type="text/css" href="agenda-print.css" media="print"?>
<agenda>
    ...
</agenda>
```

Els fitxers a lliurar seran `agenda.xml`, `agenda-screen.css` i `agenda-print.css`.

Validació: Obre el document al navegador i comprova ambdues vistes (usa la previsualització d'impressió del navegador per veure la versió d'impressió).

### Exercici 3

**Limitacions de CSS amb XML**

Aquest exercici té com a objectiu comprendre les limitacions de CSS per estilitzar XML i identificar quan cal usar XSLT.

**Part A: Intent d'estilització**

Donat el següent document XML d'una llista de tasques:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/css" href="tasques.css"?>
<llista-tasques>
    <tasca prioritat="alta" completada="no">
        <titol>Preparar examen de LLM</titol>
        <descripcio>Repassar XSLT i XPath</descripcio>
        <data-limit>2025-02-15</data-limit>
        <etiquetes>
            <etiqueta>estudis</etiqueta>
            <etiqueta>urgent</etiqueta>
        </etiquetes>
    </tasca>
    <tasca prioritat="baixa" completada="si">
        <titol>Comprar material oficina</titol>
        <descripcio>Bolígrafs, paper, carpetes</descripcio>
        <data-limit>2025-02-01</data-limit>
        <etiquetes>
            <etiqueta>compres</etiqueta>
        </etiquetes>
    </tasca>
    <tasca prioritat="mitjana" completada="no">
        <titol>Revisar apunts CSS</titol>
        <descripcio>Selectors avançats i pseudoelements</descripcio>
        <data-limit>2025-02-10</data-limit>
        <etiquetes>
            <etiqueta>estudis</etiqueta>
        </etiquetes>
    </tasca>
</llista-tasques>
```

Crea un full d'estils CSS (`tasques.css`) que:

1. Mostri les tasques com a targetes amb vora i ombra.
2. Apliqui colors diferents segons la prioritat (alta=vermell, mitjana=taronja, baixa=verd).
3. Mostri les tasques completades amb el text ratllat (`text-decoration: line-through`).
4. Mostri les etiquetes com a "badges" en línia.
5. Formateja la data límit amb un símbol de calendari (📅).

**Part B: Anàlisi de limitacions**

Respon les següents preguntes sobre què **no es pot fer** amb CSS:

1. Es pot mostrar primer les tasques d'alta prioritat i després les de baixa? Per què?
2. Es pot mostrar "Completada" o "Pendent" en lloc de llegir l'atribut `completada`? Per què?
3. Es pot calcular quants dies falten fins a la data límit? Per què?
4. Es pot mostrar un comptador amb el total de tasques pendents? Per què?
5. Es pot convertir la data de format ISO (2025-02-15) a format europeu (15/02/2025)? Per què?
6. Es pot generar una taula HTML amb les tasques ordenades per data? Per què?

{{< details summary="Respostes" >}}

| #  | Es pot fer? | Explicació                                                                                   |
|:--:|:-----------:|----------------------------------------------------------------------------------------------|
| 1  | No          | CSS no pot canviar l'ordre dels elements; es mostren segons apareixen al document            |
| 2  | No          | CSS pot mostrar el valor d'un atribut amb attr(), però no pot fer substitucions condicionals |
| 3  | No          | CSS no pot fer càlculs amb dades del document ni accedir a la data actual                    |
| 4  | No          | CSS no té comptadors que puguin filtrar per valor d'atribut ni mostrar totals                |
| 5  | No          | CSS no pot transformar ni reformatar el contingut textual dels elements                      |
| 6  | No          | CSS no pot generar nous elements HTML; només pot estilitzar els elements XML existents       |

{{< /details >}}
