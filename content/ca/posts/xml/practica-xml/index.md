---
title: "Pràctica lliurable: Catàleg de videojocs en XML"
date: 2026-01-11
lastmod: 2026-01-11
description: "Pràctica integradora on l'alumnat crea un catàleg de videojocs estil Steam utilitzant tot l'ecosistema XML: document ben format, validació amb DTD i XSD, organització amb namespaces, atributs reservats, visualització amb CSS i transformació XSLT a HTML."
summary: "Pràctica lliurable d'XML: crea un catàleg de videojocs amb DTD, XSD, namespaces, CSS i XSLT."
categories: ["ensenyament"]
tags: ["xml", "xslt", "dtd", "xsd", "css", "schema", "html"]
series: ["XML"]
series_order: 13
weight: 130
slug: practica-xml
---

En aquesta pràctica crearàs un catàleg de videojocs utilitzant XML i les tecnologies associades que hem estudiat al llarg del curs. El catàleg seguirà una estructura similar a la que utilitzen plataformes com Steam, incloent informació detallada sobre cada videojoc: títol, descripció, desenvolupador, plataformes, requisits del sistema, DLCs, valoracions, etc.

L'objectiu és demostrar el domini de tot l'ecosistema XML: des de la creació d'un document ben format fins a la seva validació amb esquemes (DTD i XSD), l'organització amb namespaces, i la visualització i transformació amb CSS i XSLT. La pràctica està estructurada en quatre blocs de dificultat progressiva, de manera que pots anar construint el projecte pas a pas i obtenir puntuació parcial segons el nivell assolit.

## Objectius

Els objectius generals de cada bloc són:

| Bloc | Objectius                                                 |
|:----:|-----------------------------------------------------------|
| 1    | Demostrar el domini de la sintaxi i estructura XML        |
| 2    | Aplicar esquemes de validació (DTD i XSD)                 |
| 3    | Utilitzar namespaces per organitzar vocabularis diferents |
| 4    | Visualitzar i transformar documents XML                   |

## Lliurables

Els lliurables de la pràctica són els següents:

| Fitxer         | Descripció                           | Bloc |
|----------------|--------------------------------------|:----:|
| `basic.xml`    | Document XML bàsic sense namespaces  | 1    |
| `cataleg.xml`  | Document XML principal               | 2    |
| `cataleg.dtd`  | Esquema de validació DTD             | 2    |
| `cataleg.xsd`  | Esquema de validació XSD             | 2    |
| `cataleg.css`  | Full d'estils per a visualització    | 3    |
| `cataleg.xsl`  | Transformació XSLT amb CSS incrustat | 4    |
| `cataleg.html` | Resultat de la transformació XSLT    | 4    |

## Bloc 1: XML

En aquesta pràctica crearàs un catàleg de videojocs utilitzant XML i les tecnologies associades que hem estudiat al llarg del curs. El catàleg seguirà una estructura similar a la que utilitzen plataformes com [Steam](https://ca.wikipedia.org/wiki/Steam), incloent informació detallada sobre cada videojoc.

Requisits del document XML:

1. **Declaració XML** amb versió 1.0 i codificació UTF-8.

2. **Estructura jeràrquica** amb almenys 3 nivells de profunditat.

3. **Entre 15 i 20 videojocs** amb la següent informació per a cadascun:
   * Títol.
   * Descripció.
   * Desenvolupador.
   * Distribuïdor.
   * Data de llançament.
   * Gèneres (pot ser més d'un).
   * Plataformes disponibles (Windows, Mac, Linux, PlayStation, Xbox, Switch...).
   * Preu (amb moneda).
   * Puntuació (0-100).
   * Nombre de ressenyes.
   * Requisits mínims del sistema (versió de sistema operatiu, CPU, RAM en GB, VRAM en GB, espai en disc en GB).
   * Etiquetes (cooperatiu, multijugador, un-jugador, món-obert, etc.).

4. **DLCs o expansions** per a almanco 3 videojocs, amb:
   * Nom del DLC.
   * Indicació de si és gratuït o no.

5. **Ús coherent d'atributs** per a:
   * Identificadors únics (`id`).
   * Moneda del preu.
   * Altres metadades que consideris apropiades.

6. **Comentaris XML** explicant les seccions principals del document.

## Bloc 2: Namespaces i schema

Aquest bloc afegeix validació formal amb [*](DTD) i [*](XSD), organització amb namespaces i ús d'atributs reservats XML.

Requisits del document XML amb espais de noms:

1. **Dos namespaces** per organitzar el vocabulari:

   | Prefix | URI                           | Propòsit                                                                  |
   |--------|-------------------------------|---------------------------------------------------------------------------|
   | `cat:` | `http://exemple.com/cataleg`  | Estructura del catàleg: element arrel, metadades, recursos                |
   | `joc:` | `http://exemple.com/videojoc` | Dades dels videojocs: títol, gèneres, plataformes, preus, requisits, DLCs |

2. **Col·lisió de noms resolta:** Els namespaces han de resoldre almenys una col·lisió real. Per exemple, `cat:titol` (títol del catàleg) i `joc:titol` (títol del videojoc), o `cat:descripcio` i `joc:descripcio`.

3. **Atribut reservat `xml:lang`:** per indicar l'idioma:
   * A l'element arrel per definir l'idioma principal del document (per exemple, `ca`).
   * A les descripcions dels videojocs per oferir versions en català i anglès.

4. **Atribut reservat `xml:base`** per definir una URI base per a recursos externs. Secció de recursos (imatges, enllaços) que utilitzi URIs relatives resoltes contra la base definida.

5. **Secció de metadades** amb el namespace `cat:`, incloent:
   * Títol del catàleg.
   * Autor (el teu nom).
   * Data d'actualització.
   * Descripció del catàleg en català i anglès (usant `xml:lang`).

6. **Validació DTD** a través d'un fitxer `cataleg.dtd` que:
   * Defineixi tots els elements i atributs del document.
   * Estableixi la cardinalitat correcta (elements obligatoris, opcionals, repetibles).
   * Declari els tipus d'atributs adequats (`ID`, `CDATA`, enumeracions).
   * Sigui referenciat des del document XML amb `<!DOCTYPE>`.

7. **Validació XSD** a través d'un fitxer `cataleg.xsd` que, a més del que fa el DTD, inclogui:
   * Tipus de dades: `xs:date` per a dates, `xs:decimal` per a preus, `xs:integer` per a RAM/VRAM/disc/ressenyes.
   * Restriccions numèriques: puntuació entre 0 i 100, RAM i disc mínim 1.
   * Patrons: codi de moneda amb `[A-Z]{3}` (ISO 4217).
   * Enumeracions: plataformes (`Windows`, `Mac`, `Linux`, `PlayStation`, `Xbox`, `Switch`), o gèneres principals.
   * Sigui referenciat des del document XML amb `xsi:schemaLocation`.

Recorda que, per a validar amb DTD referenciat dins el document XML, pots usar:

```bash
xmllint --valid --noout cataleg.xml
```

I per a validar amb XSD, pots user:

```bash
xmllint --schema cataleg.xsd --noout cataleg.xml
```

## Bloc 3: CSS

Aquest bloc requereix crear un full d'estils CSS que permeti visualitzar el document XML directament al navegador de manera presentable i funcional.

Requisits del document:

1. **Instrucció de processament** `<?xml-stylesheet?>` al document XML per enllaçar el fitxer CSS.

2. **Propietat `display`** aplicada correctament:
   * Elements contenidors com a `block`.
   * Elements de dades en línia quan sigui apropiat.
   * Ocultació d'elements no rellevants per a la visualització (per exemple, identificadors interns).

3. **Layout modern** amb almenys una d'aquestes tècniques:
   * CSS Grid per a la disposició general o les targetes de videojocs.
   * Flexbox per a l'alineació d'elements.

4. **Tipografia:**
   * Família tipogràfica adequada (sans-serif recomanat).
   * Mides relatives (`em`, `rem`, `%`) en comptes de píxels fixos.
   * Jerarquia visual clara (títols més grans, descripcions més petites).

5. **Colors i variables CSS:**
   * Definició de variables CSS (custom properties) per a colors principals.
   * Contrast adequat entre text i fons.
   * Ús de colors per diferenciar seccions o categories.

6. **Selectors:**
   * Selectors d'element per als elements XML.
   * Selectors d'atribut per estilitzar segons valors (per exemple, `[moneda="EUR"]`).
   * Selectors descendents per aplicar estils contextuals.

7. **Pseudoelements `::before` i `::after`:**
   * Afegir etiquetes o icones abans de certs camps (per exemple, "Preu:", "🎮", "⭐").
   * Mostrar el valor d'atributs amb `attr()` (per exemple, mostrar la moneda del preu).

8. **Pseudoclasse `:hover`** per ressaltar elements en passar el ratolí (per exemple, els videojocs o els DLCs).


## Bloc 4: XSLT

Aquest bloc requereix crear una transformació XSLT que generi una pàgina HTML completa i funcional a partir del document XML.

Requisits de l'estructura de la transformació:

1. **Declaració XSLT** amb versió 1.0 i namespaces correctament definits per accedir als elements `cat:` i `joc:`.

2. **Sortida HTML5** amb `<xsl:output method="html" encoding="UTF-8"/>`.

3. **Plantilles múltiples** (`xsl:template`):
   * Una plantilla principal que generi l'estructura HTML (`<html>`, `<head>`, `<body>`).
   * Una plantilla específica per processar cada videojoc.
   * Opcionalment, plantilles addicionals per a altres elements (DLCs, requisits...).

Elements XSLT obligatoris:

4. **Iteració:**
   * `xsl:for-each` per recórrer col·leccions (gèneres, plataformes, etiquetes...).
   * `xsl:apply-templates` per aplicar la plantilla de videojoc a cada element.
   * `xsl:value-of` per extreure valors dels elements XML.

5. **Ordenació:** `xsl:sort` per ordenar els videojocs per algun criteri (títol, puntuació o data).

6. **Condicionals:**
   * `xsl:if` per mostrar contingut només quan existeixi (per exemple, la secció de DLCs).
   * `xsl:choose`/`xsl:when`/`xsl:otherwise` per aplicar diferents estils o textos segons un valor (per exemple, classificar la puntuació com a "excel·lent", "bo" o "regular").

7. **Variables globals:** `xsl:variable` per calcular estadístiques del catàleg: nombre total de videojocs (`count()`) i puntuació mitjana (`sum() div count()`).

8. **Atributs dinàmics:** Attribute Value Templates `{}` per generar atributs HTML amb valors del XML (per exemple, `id="{@id}"` o `class="puntuacio-{$categoria}"`).

Contingut de l'HTML generat:

9. **Document HTML5 complet:**
   * Declaració `<!DOCTYPE html>`.
   * Element `<html>` amb atribut `lang="ca"`.
   * Secció `<head>` amb `<meta charset>`, `<title>` dinàmic i estils CSS incrustats.
   * Secció `<body>` amb el contingut.

   > Pots reutilitzar el full d'estils del bloc 3, adaptant els selectors.

10. **Idioma únic:** Mostrar només les descripcions en català, filtrant per `xml:lang="ca"`.

11. **Tres seccions de contingut:**
    * **Capçalera:** Una secció a dalt de la pàgina que mostri les metadades del catàleg (`cat:info`): el títol, l'autor i la data d'actualització. Bàsicament, que l'alumne demostri que sap extreure i mostrar informació del bloc de metadades.
    * **Llista o graella de videojocs (catàleg):** El cos principal de la pàgina amb tots els videojocs. Pot ser una llista vertical o una graella (grid) de targetes, que mostri les dades principals de cada joc: títol, descripció, desenvolupador, plataformes, preu, puntuació i altres dades rellevants.No és necessari que mostri absolutament tots els camps.
    * **Estadístiques:** Algun càlcul fet amb XSLT que demostri l'ús d'`xsl:variable` del punt 7 i funcions com `count()` i `sum()`. Per exemple, mostrar "Total: 17 jocs" i "Puntuació mitjana: 82/100".    

Recorda que, per a transformar el document XML en un document HTML pots usar:

```bash
xsltproc -o cataleg.html cataleg.xsl cataleg.xml
```

I que pots verificar la validesa del fitxer HTML generat:

```bash
