---
title: "Autoavaluació del catàleg de videojocs en XML"
date: 2026-01-11
lastmod: 2026-01-11
description: "Guia d'autoavaluació per a la pràctica lliurable de creació d'un catàleg de videojocs estil Steam. Comandes per validar XML, DTD, XSD, CSS i XSLT amb xmllint i xsltproc."
summary: "Comandes de terminal per autoavaluar la pràctica del catàleg de videojocs."
categories: ["teaching"]
tags: ["xml", "xslt", "dtd", "xsd", "css", "schema", "html", "practica", "autoavaluacio"]
slug: autoavaluacio
---

Un dels avantatges de fer feina amb XML i les tecnologies associades és que les mateixes eines que hem utilitzat durant els exercicis del curs serveixen per validar i verificar el treball propi abans de lliurar-lo. A diferència d'altres formats, XML ofereix mecanismes formals de validació integrats en l'ecosistema:

* `xmllint` permet comprovar que un document està ben format, que compleix un DTD o que valida contra un XSD.
* `xsltproc` permet executar transformacions i detectar errors de sintaxi o lògica a l'XSLT.

Aquesta capacitat d'autovalidació és una de les raons per les quals XML continua sent l'estàndard en contextos on la correcció i la interoperabilitat són crítiques, com la facturació electrònica, els formats documentals (OOXML, ODF) o els intercanvis de dades entre sistemes.

Aprofita aquestes eines per revisar la teva pràctica: si les comandes no retornen errors, tens una bona base; si en retornen, els missatges t'indicaran exactament on i què has de corregir.

> Hauràs d'adaptar les comandes a les etiquetes i atributs que hagis usat a la pràctica.

## Instal·lació d'eines

Les eines necessàries per a dur a terme aquest correcció són les següents:

```bash
sudo apt install libxml2-utils xsltproc
```

## Bloc 1

L'objectiu del bloc 1 és demostrar el domini de la sintaxi i estructura XML.

Comença verificant que el document `basic.xml` està ben format:

```bash
xmllint --noout basic.xml
```

Mostra l'estructura en arbre per a verificar l'estructura jeràrquica del document:

```bash
xmllint --xpath '//*' basic.xml | head -50
```

Compta els nivells de profunditat:

```bash
xmllint --format basic.xml | head -40
```

Compta el número de videojocs:

```bash
xmllint --xpath 'count(//videojoc)' basic.xml
```

Verifica els camps dels videojocs llistant tots els elements fills del primer videojoc:

```bash
xmllint --xpath '//videojoc[1]/*' basic.xml 2>/dev/null | xmllint --format -
```

Verifica que els camps específics dels videojocs existeixen:

```bash
xmllint --xpath 'count(//titol)' basic.xml
xmllint --xpath 'count(//descripcio)' basic.xml
xmllint --xpath 'count(//desenvolupador)' basic.xml
xmllint --xpath 'count(//preu)' basic.xml
xmllint --xpath 'count(//puntuacio)' basic.xml
xmllint --xpath 'count(//requisits)' basic.xml
```

Compta el número de videojocs amb DLCs:

```bash
xmllint --xpath 'count(//videojoc[dlcs])' basic.xml
```

Llista tots els valors de l'atribut `id` als videojocs per a verificar-los:

```bash
xmllint --xpath '//videojoc/@id' basic.xml
```

Verifica l'atribut `moneda` als preus dels videjocs:

```bash
xmllint --xpath '//preu/@moneda' basic.xml
```

Comprova que els identificadors dels videojocs són únics:

```bash
xmllint --xpath '//videojoc/@id' basic.xml 2>/dev/null | tr ' ' '\n' | sort | uniq -d
```

Verifica que has usat comentaris al document XML:

```bash
grep -c '<!--' basic.xml
```

## Bloc 2

Els objectius del bloc 2 són, d'una banda, utilitzar espais de noms per organitzar vocabularis diferents i, d'altra, aplicar esquemes de validació DTD i XSD.

Verifica els espais de noms declarats mostrant les declaracions de namespace a l'element arrel:

```bash
head -10 cataleg.xml | grep xmlns
```

Verifica l'ús de prefixos comptant els elements amb prefix `cat:` i amb prefix `joc:`:

```bash
# Comptar elements amb prefix cat:
grep -o '<cat:[a-zA-Z]*' cataleg.xml | wc -l

# Comptar elements amb prefix joc:
grep -o '<joc:[a-zA-Z]*' cataleg.xml | wc -l
```

Verifica la resolució de la col·lisió de noms cercant elements amb el mateix nom local però diferent prefix:

```bash
grep -E '<(cat|joc):titol' cataleg.xml
grep -E '<(cat|joc):descripcio' cataleg.xml
```

Verifica l'ús d'`xml:lang` tant a l'arrel com a les descripcions:

```bash
# xml:lang a l'arrel
grep -o 'xml:lang="[^"]*"' cataleg.xml | head -1

# xml:lang a descripcions
grep 'xml:lang=' cataleg.xml | grep -E '(cat|joc):descripcio' | head -5
```

Verifica l'ús d'`xml:base`:

```bash
grep 'xml:base=' cataleg.xml
```

Verifica les metadades del catàleg cercant la secció `info` per poder revisar que conté els camps requerits:

```bash
xmllint --xpath '//*[local-name()="info"]' cataleg.xml 2>/dev/null | xmllint --format -
```

Valida el document XML, d'una banda assegurant que el `DOCTYPE` està present i, d'altra, amb el DTD:

```bash
# Verificar que el DOCTYPE està present
head -5 cataleg.xml | grep DOCTYPE

# Validar amb DTD
xmllint --valid --noout cataleg.xml
```

Valida el document XML amb l'XSD:

```bash
xmllint --schema cataleg.xsd --noout cataleg.xml
```

Verifica les restriccions de l'XSD cercant patrons, enumeracions, restriccions numèriques i tipus de dades específics:

```bash
# Cercar patrons (pattern)
grep -c 'xs:pattern' cataleg.xsd

# Cercar enumeracions
grep -c 'xs:enumeration' cataleg.xsd

# Cercar restriccions numèriques
grep -E 'minInclusive|maxInclusive|minExclusive|maxExclusive' cataleg.xsd | wc -l

# Cercar tipus de dades específics
grep -E 'xs:date|xs:decimal|xs:integer' cataleg.xsd | wc -l
```

## Bloc 3

L'objectiu del bloc 3 és visualitzar el document XML a través d'un full d'estils.

Verifica l'enllaç al fitxer CSS dins el document XML:

```bash
grep 'xml-stylesheet' cataleg.xml
```

Verifica el contingut del fitxer CSS:

```bash
# Verificar ús de variables CSS
grep -c '\-\-' cataleg.css

# Verificar ús de Grid o Flexbox
grep -E 'display:\s*(grid|flex)' cataleg.css

# Verificar selectors d'atribut
grep -E '\[[a-zA-Z]' cataleg.css

# Verificar pseudoelements
grep -E '::(before|after)' cataleg.css

# Verificar ús de attr()
grep -c 'attr(' cataleg.css

# Verificar :hover
grep -c ':hover' cataleg.css

# Verificar mides relatives
grep -E '[0-9]+(em|rem|%)' cataleg.css | head -5
```

Per a comprovar el resultat d'aplicar el full d'estils al fitxer XML, visualització manualment el document XML al navegador que tenguis instal·lat, e.g., Firefox, Vivaldi o Brave.

## Bloc 4

L'objectiu del bloc 4 és transformar el document XML en un document HTML.

Verifica l'estructura XSLT:

```bash
# Verificar declaració i namespaces
head -10 cataleg.xsl

# Comptar plantilles
grep -c 'xsl:template' cataleg.xsl

# Verificar output HTML
grep 'xsl:output' cataleg.xsl
```

Verifica els elements XSLT requerits:

```bash
# for-each
grep -c 'xsl:for-each' cataleg.xsl

# apply-templates
grep -c 'xsl:apply-templates' cataleg.xsl

# value-of
grep -c 'xsl:value-of' cataleg.xsl

# sort
grep -c 'xsl:sort' cataleg.xsl

# if
grep -c 'xsl:if' cataleg.xsl

# choose/when
grep -c 'xsl:choose' cataleg.xsl
grep -c 'xsl:when' cataleg.xsl

# variables
grep -c 'xsl:variable' cataleg.xsl

# Attribute Value Templates (cercam '{}')
grep -E '\{[@$][^}]+\}' cataleg.xsl | wc -l
```

Executa la transformació XSLT:

```bash
xsltproc -o cataleg.html cataleg.xsl cataleg.xml
```

Verifica el contingut del fitxer HTML:

```bash
# Verificar DOCTYPE
head -3 cataleg.html | grep -i doctype

# Verificar lang="ca"
grep -o 'lang="[^"]*"' cataleg.html | head -1

# Verificar que només mostra català (no hauria de tenir xml:lang="en" visible)
grep -c 'xml:lang="en"' cataleg.html

# Verificar estadístiques (buscar count, total, mitjana)
grep -iE '(total|mitjana|count)' cataleg.html

# Verificar l'existència de CSS incrustat
grep -c '<style>' cataleg.html
```

Visualitza el fitxer HTML generat al teu navegador. Valida'l a través del [Markup Validation Service del W3C](https://validator.w3.org/).

## Llista de verificació manual

Pots usar la següent plantilla per a fer un seguiment de l'autoavaluació:

**Bloc 1**

* [ ] Declaració XML correcta (versió, codificació).
* [ ] Estructura jeràrquica amb 3+ nivells.
* [ ] 15-20 videojocs.
* [ ] Tots els camps requerits per videojoc.
* [ ] 3+ videojocs amb DLCs.
* [ ] IDs únics i moneda als preus.
* [ ] Mínim 3 comentaris descriptius.

**Bloc 2**

* [ ] Namespaces `cat:` i `joc:` declarats i usats.
* [ ] Col·lisió de noms resolta (titol o descripcio).
* [ ] `xml:lang` a l'arrel i descripcions.
* [ ] `xml:base` a recursos.
* [ ] Secció metadades completa.
* [ ] DTD valida sense errors.
* [ ] XSD valida amb restriccions avançades.

**Bloc 3**

* [ ] Instrucció `xml-stylesheet`.
* [ ] Layout amb Grid o Flexbox.
* [ ] Variables CSS.
* [ ] Selectors variats (element, atribut, descendent).
* [ ] Pseudoelements `::before`/`::after` amb `attr()`.
* [ ] Interactivitat `:hover`.

**Bloc 4**

* [ ] Múltiples plantilles `xsl:template`.
* [ ] Iteració: `for-each`, `apply-templates`, `value-of`.
* [ ] Ordenació: `xsl:sort`.
* [ ] Condicionals: `xsl:if` i `xsl:choose`.
* [ ] Variables globals amb estadístiques.
* [ ] Attribute Value Templates `{}`.
* [ ] HTML 5 generat amb 3 seccions.
* [ ] Només descripcions en català.
