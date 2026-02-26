---
title: "Autoavaluació del catàleg de videojocs en XML"
date: 2026-01-11
lastmod: 2026-02-26
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
sudo apt install libxml2-utils xsltproc xmlstarlet
```

## Bloc 1

L'objectiu del bloc 1 és demostrar el domini de la sintaxi i estructura XML.

Comença verificant que el document `basic.xml` està ben format:

```bash
xmllint --noout basic.xml
```

Mostra l'estructura en arbre per a verificar la jerarquia d'elements del document i aprofita per fer una primera ullada a la seva profunditat:

```bash
xmllint --xpath '//*' basic.xml | head -50
```

Extreu el nombre de nivells màxim de profunditat:

```bash
xmlstarlet el -d basic.xml | awk -F'/' '{print NF-1}' | sort -rn | head -n 1
```

Compta el número de videojocs:

```bash
xmllint --xpath 'count(//videojoc)' basic.xml
```

Verifica els camps dels videojocs llistant tots els elements fills del primer videojoc:

```bash
xmlstarlet sel -t -c "//videojoc[1]" basic.xml | xmlstarlet fo
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

Llista tots els valors de l'atribut `id` als videojocs per a verificar-los, i aprofita per comprovar que els identificadors són únics:

```bash
xmllint --xpath '//videojoc/@id' basic.xml
```

Verifica l'atribut `moneda` als preus dels videjocs:

```bash
xmllint --xpath '//preu/@moneda' basic.xml
```

Verifica que has usat comentaris al document XML:

```bash
grep -c '<!--' basic.xml
```

## Bloc 2

Els objectius del bloc 2 són, d'una banda, utilitzar espais de noms per organitzar vocabularis diferents i, d'altra, aplicar esquemes de validació DTD i XSD.

Cal verificar els espais de noms declarats i usats. Comença per imprimir el namespace de l'element arrel:

```bash
xmllint --xpath 'namespace-uri(/*)' cataleg.xml
```

Continua imprimint tots els espais de noms declarats al document:

```bash
xmlstarlet sel -t -m "//namespace::*[name()!='xml']" -v "concat('xmlns:', name(), '=', .)" \
  -n cataleg.xml | sed 's/xmlns:=/xmlns=/' | sed 's/=\(.*\)/="\1"/' | sort -u
```

I acaba comptant el número de vegades que has fet ús d'un espai de noms al document:

```bash
xmlstarlet sel -t -v 'count(//*[namespace-uri()!=""])' cataleg.xml && echo
```

Verifica l'ús de prefixos comptant els elements amb prefix `cat:`:

```bash
xmlstarlet sel -t -v 'count(//*[starts-with(name(), "cat:")])' cataleg.xml && echo
```

 I també compta el elements amb prefix `joc:`:

```bash
xmlstarlet sel -t -v 'count(//*[starts-with(name(), "joc:")])' cataleg.xml && echo
```

Compta el número de videojocs:

```bash
xmllint --xpath "count(//*[local-name()='videojoc'])" cataleg.xml
```

Verifica els camps dels videojocs llistant tots els elements fills del primer videojoc:

```bash
xmlstarlet sel -t -c "//*[local-name()='videojoc'][1]" basic.xml | xmlstarlet fo
```

Verifica que els camps específics dels videojocs existeixen:

```bash
xmllint --xpath "count(//*[local-name()='titol'])" cataleg.xml
xmllint --xpath "count(//*[local-name()='descripcio'])" cataleg.xml
xmllint --xpath "count(//*[local-name()='desenvolupador'])" cataleg.xml
xmllint --xpath "count(//*[local-name()='preu'])" cataleg.xml
xmllint --xpath "count(//*[local-name()='puntuacio'])" cataleg.xml
xmllint --xpath "count(//*[local-name()='requisits'])" cataleg.xml
```

Compta el número de videojocs amb DLCs:

```bash
xmllint --xpath "count(//*[local-name()='videojoc'][*[local-name()='dlcs']])" cataleg.xml
```

Llista tots els valors de l'atribut `id` als videojocs per a verificar-los, i aprofita per comprovar que els identificadors són únics:

```bash
xmllint --xpath "//*[local-name()='videojoc']/@id" cataleg.xml
```

Verifica l'atribut `moneda` als preus dels videjocs:

```bash
xmllint --xpath "//*[local-name()='preu']/@moneda" cataleg.xml
```

Verifica la resolució de la col·lisió de noms cercant elements amb el mateix nom local però diferent prefix. Primer, per als títol:

```bash
xmlstarlet sel -t -m "//*[local-name()='titol']" -v "name()" -n cataleg.xml | sort -u
```

I, després, per a les descripcions:

```bash
xmlstarlet sel -t -m "//*[local-name()='descripcio']" -v "name()" -n cataleg.xml | sort -u
```

Verifica l'ús d'`xml:lang`, començant primer per l'arrel:

```bash
grep -o 'xml:lang="[^"]*"' cataleg.xml | head -1
```

I seguint amb les descripcions:

```bash
grep 'xml:lang=' cataleg.xml | grep -E '(cat|joc):descripcio' | head -5
```

Verifica l'ús d'`xml:base` a l'element arrel per a definir la URI base del document:

```bash
xmllint --xpath 'string(/*/@xml:base)' cataleg.xml
```

Si escau, verifica que se'n faci ús a qualsevol part del document, no només a l'arrel:

```bash
xmlstarlet sel -t -m "//*[@xml:base]" -v "name()" -o " amb valor " -v "@xml:base" -n cataleg.xml
```

Verifica les metadades del catàleg cercant la secció `info` per poder revisar que conté els camps requerits:

```bash
xmllint --xpath '//*[local-name()="info"]' cataleg.xml
```

Per validar el document XML amb el DTD, abans revisar que el `DOCTYPE` està present i que enllaça al DTD:

```bash
head -5 cataleg.xml | grep -i DOCTYPE
```

Ara ja pots fer la validació amb el DTD:

```bash
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

Verifica que el contingut del fitxer CSS compleix tots els requeriments de l'enunciat. Començar per l'ús de variables de CSS:

```bash
grep -c '\-\-' cataleg.css
```

Verifica l'ús de Grid o Flexbox:

```bash
grep -E 'display:\s*(grid|flex)' cataleg.css
```

Verifica l'ús de selectors d'atribut:

```bash
grep -E '\[[a-zA-Z]' cataleg.css
```

Verifica l'ús de pseudoelements:

```bash
grep -E '::(before|after)' cataleg.css
```

Verifica ús de la funció `attr()`:

```bash
grep -c 'attr(' cataleg.css
```

Verifica l'ús de la pseudoclasse `:hover`:

```bash
grep -c ':hover' cataleg.css
```

Verifica l'ús de mides relatives:

```bash
grep -E '[0-9]+(em|rem|%)' cataleg.css | head -5
```

Per a comprovar el resultat d'aplicar el full d'estils al fitxer XML, visualitza manualment el document XML al navegador que tenguis instal·lat, e.g., Firefox, Vivaldi o Brave.

## Bloc 4

L'objectiu del bloc 4 és transformar el document XML en un document HTML.

Verifica l'estructura XSLT, començant per la declaració i els namespaces:

```bash
xmlstarlet el -v cataleg.xsl | head -1
```

Compta el nombre de vegades que s'han usat plantilles:

```bash
grep -c 'xsl:template' cataleg.xsl
```

Verifica que s¡ha especificat que la sortida és HTML:

```bash
grep 'xsl:output' cataleg.xsl
```

Verifica que els elements XPath requerits són presents al document XSLT. Comença per l'ús de `xsl:for-each` per a iterar sobre el conjunt de nodes:

```bash
grep -c 'xsl:for-each' cataleg.xsl
```

Verifica l'ús de `xsl:apply-templates` per a l'aplicació de plantilles als nodes fills:

```bash
grep -c 'xsl:apply-templates' cataleg.xsl
```

Verifica l'ús de `xsl:value-of` per a extreure valors del nodes:

```bash
grep -c 'xsl:value-of' cataleg.xsl
```

Verifica l'ús de `xsl:sort` per a ordenar la llista de nodes:

```bash
grep -c 'xsl:sort' cataleg.xsl
```

Verifica l'ús de condicions simples a través de `xsl:if`:

```bash
grep -c 'xsl:if' cataleg.xsl
```

Verifica l'ús de condicions múltiples a través de `xsl:choose` i `xsl:when`:

```bash
grep -c 'xsl:choose' cataleg.xsl
grep -c 'xsl:when' cataleg.xsl
```

Verifica l'ús de variables a través de `xsl:variable`:

```bash
grep -c 'xsl:variable' cataleg.xsl
```

Verifica l'ús de plantilles de valor d'atribut (AVT):

```bash
grep -E '\{[@$][^}]+\}' cataleg.xsl | wc -l
```

Verifica l'ús de valors calculats (adapta-ho al teu fitxer):

```bash
grep -E 'xsl:variable.*(sum|count)\(' cataleg.xsl
```

També pots fer-ho amb `xmlstarlet`:

```bash
xmlstarlet sel -t -m "//xsl:variable[contains(@select, 'sum(') or contains(@select, 'count(')]" \
  -v "name()" -o " amb nom " -v "@name" -o " usa " -v "@select" -n cataleg.xsl
```

Executa la transformació XSLT:

```bash
xsltproc -o cataleg.html cataleg.xsl cataleg.xml
```

Verifica el contingut del fitxer HTML. Comença per assegurar-te de que tengui un `DOCTYPE`:

```bash
grep -i DOCTYPE cataleg.html
```

Verifica que has inclòs l'idioma:

```bash
grep -o 'lang="[^"]*"' cataleg.html | head -1
```

Verifica que has inclòs estadístiques (adapta-ho al teu fitxer):

```bash
grep -iE '(total|mitjana|count)' cataleg.html
```

Verifica l'existència de CSS incrustat_

```bash
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
