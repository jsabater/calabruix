---
title: "Visualització amb CSS"
date: 2026-01-03
lastmod: 2026-01-03
description: "Aplicació de fulls d'estils CSS a documents XML. Enllaç amb instrucció de processament, selectors d'elements, propietats de visualització i exemple complet."
summary: "Estilització de documents XML amb CSS: enllaç, selectors i exemple pràctic complet."
categories: ["ensenyament"]
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
|:-----------:|------------------------------------|--------------------------------|
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
|:--------------:|-----------------------------------------------------|
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
                <email>maria.garcia@cifpmoll.eu</email>
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
