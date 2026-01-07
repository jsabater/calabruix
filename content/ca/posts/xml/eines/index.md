---
title: "Eines de feina XML"
date: 2026-01-03
lastmod: 2026-01-03
description: "Eines en línia i de terminal de comandes per a treballar amb documents XML: validadors, formatejadors i transformadors, amb exemples pràctics."
summary: "Eines en línia i de terminal de comandes per a validar, formatejar i transformar documents XML."
categories: ["ensenyament"]
tags: ["xml", "xmllint", "xsltproc", "xmlstarlet"]
series: ["XML"]
series_order: 8
weight: 80
slug: eines
---

En aquest article es proposen un seguit d'eines en línia i de terminal o línia de comandes per fer feina amb XML. Les primeres són apropiades per a la validació ràpida, el prototipatge i l'aprenentatge, mentres que les segones són necessàries per a l'automatització i la integració.

## Eines online

Les eines online són ideals per a validacions ràpides, proves puntuals i aprenentatge. No requereixen instal·lació i ofereixen resultats immediats, cosa que les fa molt pràctiques durant el desenvolupament.

**Validadors i formatejadors**

| Eina                                                                                | Funcionalitats principals                                             |
|-------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| [XML Validation](https://www.xmlvalidation.com/)                                    | Validació de format, DTD i XSD                                        |
| [FreeFormatter XML Validator](https://www.freeformatter.com/xml-validator-xsd.html) | Validació de format i XSD, interfície senzilla                        |
| [W3C Markup Validation](https://validator.w3.org/)                                  | Validació d'XHTML i documents XML amb estàndards web                  |
| [Code Beautify XML Viewer](https://codebeautify.org/xmlviewer)                      | Formatació, minificació, visualització en arbre, conversió XML ↔ JSON |
| [XML Grid](https://xmlgrid.net/)                                                    | Edició visual, visualització en graella, validació                    |

**Eines XPath**

| Eina                                                                          | Funcionalitats principals                                |
|-------------------------------------------------------------------------------|----------------------------------------------------------|
| [FreeFormatter XPath Tester](https://www.freeformatter.com/xpath-tester.html) | Proves d'expressions XPath sobre documents XML           |
| [XPather](https://github.com/Simek/XPather) (extensió per a Chromium)         | Proves d'expressions XPath directament sobre pàgines web |

Aquestes eines són especialment útils per depurar expressions XPath abans d'incorporar-les a fulls XSLT.

**Transformadors XSLT**

| Eina                                                                                 | Funcionalitats principals                                                           |
|--------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| [FreeFormatter XSLT Transformer](https://www.freeformatter.com/xsl-transformer.html) | Transformacions XSLT 1.0                                                            |
| [XSLTFiddle](https://xsltfiddle.liberty-development.net/)                            | Suport XSLT 1.0, 2.0 i 3.0, múltiples processadors (Saxon, Xalan), URL compartibles |

XSLTFiddle és l'opció més completa si necessites provar característiques d'XSLT 2.0 o 3.0 sense instal·lar Saxon localment.

## Eines de terminal

### xmllint

`xmllint` és l'eina de referència per treballar amb XML a Linux. Forma part del paquet `libxml2-utils`:

```bash
sudo apt install libxml2-utils
xmllint --version
```

Aquestes són les seves opcions més útils:

| Opció                   | Descripció                                 |
|-------------------------|--------------------------------------------|
| `--noout`               | No mostra la sortida, només errors         |
| `--format`              | Formata el document (pretty print)         |
| `--valid`               | Valida contra DTD referenciada al document |
| `--dtdvalid fitxer.dtd` | Valida contra DTD específica               |
| `--schema fitxer.xsd`   | Valida contra XSD                          |
| `--xpath "expressió"`   | Avalua expressió XPath                     |
| `--recover`             | Intenta recuperar documents mal formats    |
| `--nonet`               | No accedeix a la xarxa (DTD/XSD locals)    |
| `--timing`              | Mostra temps de processament               |
| `--debug`               | Mostra informació de depuració             |

Podem usar `xmllint` per a comprovar si un document és ben format:

```bash
xmllint --noout institut.xml
```

> L'opció `--noout` evita que es mostri el contingut; només mostra errors si n'hi ha.

Podem usar `xmllint` per formatejar XML (pretty print):

```bash
# Mostrar per pantalla
xmllint --format institut.xml

# Guardar a un fitxer
xmllint --format institut.xml > institut_formatejat.xml
```

Podem usar `xmllint` per a validar un document XML contra un document DTD. Si el document inclou una referència a DTD interna o externa, usarem la següent ordre:

```bash
xmllint --valid --noout institut.xml
```

Però també podem validar un document XML contra una DTD específica sense haver de modificar l'XML:

```bash
xmllint --dtdvalid institut.dtd --noout institut.xml
```

També pòdem usar `xmllint` per a validar contra XSD:

```bash
xmllint --schema institut.xsd --noout institut.xml
```

Finalment, podem usar `xmllint` per a avaluar expressions `XPath`:

```bash
# Seleccionar nodes
xmllint --xpath "//alumne/nom" institut.xml

# Obtenir valor de text
xmllint --xpath "//alumne[@id='A001']/nom/text()" institut.xml

# Comptar elements
xmllint --xpath "count(//alumne)" institut.xml

# Obtenir atributs
xmllint --xpath "//assignatura/@codi" institut.xml
```

A continuació es mostren alguns exemples pràctics:

```bash
$ xmllint --xpath "//alumne/nom/text()" institut.xml
MariaPere LauraJordiAnnaMarcCarlaTomeuAinaMiquel

$ xmllint --xpath "//alumne[1]/nom/text()" institut.xml
Maria

$ xmllint --xpath "count(//alumne)" institut.xml
10

$ xmllint --xpath "sum(//hores)" institut.xml
320
```

### xsltproc

`xsltproc` és el processador XSLT de referència a Linux, disponible en un paquet amb el mateix nom:

```bash
sudo apt install xsltproc
```

Aquestes són les seves opcions més útils:

| Opció                     | Descripció                     |
|---------------------------|--------------------------------|
| `-o fitxer`               | Fitxer de sortida              |
| `--stringparam nom valor` | Passa paràmetre de text        |
| `--param nom valor`       | Passa paràmetre numèric/XPath  |
| `--timing`                | Mostra temps de processament   |
| `--profile`               | Mostra informació de rendiment |
| `--nonet`                 | No accedeix a la xarxa         |
| `--verbose`               | Mode detallat                  |

Una transformació bàsica és molt senzilla de fer:

```bash
xsltproc estil.xsl document.xml
```

Això mostra el resultat per la sortida estàndard. Per guardar-lo en un fitxer podem usar el paràmetre `-o`:

```bash
xsltproc -o resultat.html estil.xsl document.xml
```

A continuació es mostren alguns exemples pràctics:

```bash
# Transformar institut.xml a HTML
$ xsltproc -o institut.html institut.xsl institut.xml

# Verificar el resultat
$ head -20 institut.html
<!DOCTYPE html SYSTEM "about:legacy-compat">
<html lang="ca">
<head>
<meta charset="UTF-8">
[..]

# Obrir al navegador
$ firefox institut.html &
```

Si el full XSLT defineix paràmetres, es poden passar des de la línia de comandes. Per exemple, donat el següent XML:

```xml
<xsl:param name="titol" select="'Valor per defecte'"/>
<xsl:param name="max-alumnes" select="10"/>
```

Passaríem el valor de `titol` i el valor de `max-alumnes` de la següent forma:

```bash
xsltproc --stringparam titol "Nou títol" \
         --param max-alumnes 5 estil.xsl document.xml
```

### xmlstarlet

`xmlstarlet` és una eina més avançada que combina diverses funcionalitats. La podem obtenir a través del paquet amb el mateix nom:

```bash
sudo apt install xmlstarlet
```

Les comandes principals que ofereix són les següents:

| Comanda          | Funció              |
|------------------|---------------------|
| `xmlstarlet val` | Validar             |
| `xmlstarlet sel` | Seleccionar (XPath) |
| `xmlstarlet ed`  | Editar              |
| `xmlstarlet fo`  | Formatejar          |
| `xmlstarlet tr`  | Transformar (XSLT)  |
| `xmlstarlet el`  | Llistar elements    |

A continuació és mostren alguns exemples:

```bash
# Validar document
xmlstarlet val -e institut.xml

# Validar amb DTD
xmlstarlet val -d institut.dtd institut.xml

# Validar amb XSD
xmlstarlet val -s institut.xsd institut.xml

# Seleccionar amb XPath
xmlstarlet sel -t -v "//alumne/nom" institut.xml

# Seleccionar amb format personalitzat
xmlstarlet sel -t -m "//alumne" -v "nom" -o ": " -v "email" -n institut.xml

# Formatejar
xmlstarlet fo institut.xml

# Llistar estructura d'elements
xmlstarlet el institut.xml

# Editar: afegir atribut
xmlstarlet ed -i "//alumne" -t attr -n "actiu" -v "true" institut.xml

# Editar: canviar valor
xmlstarlet ed -u "//institut/nom" -v "Nou nom" institut.xml

# Transformar amb XSLT
xmlstarlet tr institut.xsl institut.xml
```

Usant `XPath`, el següent script extreu tots els emails dels alumnes del [document XML d'exemple de l'institut](../validation/institut.xml):

```bash
#!/bin/bash

echo "Emails de l'alumnat:"
xmlstarlet sel -t -v "//alumne/email" -n institut.xml | sort | uniq
```

## Exemple complet

Amb un simple script de BASH i les eines anteriorment explicades, podem fàcilment generar pipelines de validació i transformació de documents XML.

### xmllint/xsltproc

A continuació es mostra un script de BASH que actua a mode de pipeline de validació i transformació d'un document XML, usant les eines `xmllint` i `xsltproc`:

```bash
#!/bin/bash

XML="$1"
DTD="institut.dtd"
XSL="institut.xsl"

if [ -z "$XML" ]; then
    echo "Ús: $0 fitxer.xml"
    exit 1
fi

echo "1. Comprovant format..."
if ! xmllint --noout "$XML" 2>&1; then
    echo "Error: Document mal format!"
    exit 1
fi

echo "2. Validant contra DTD..."
if ! xmllint --dtdvalid "$DTD" --noout "$XML" 2>&1; then
    echo "Error: Document no vàlid!"
    exit 2
fi

echo "3. Transformant a HTML..."
SORTIDA="${XML%.xml}.html"
if xsltproc -o "$SORTIDA" "$XSL" "$XML"; then
    echo "OK: El fitxer resultant és a $SORTIDA."
else
    echo "Error: Transformació fallida!"
    exit 3
fi
```

### xmlstarlet

La següent versió de l'script fa el mateix que l'anterior, però usant l'eina `xmlstarlet`:

```bash
#!/bin/bash

XML="$1"
DTD="institut.dtd"
XSL="institut.xsl"

if [ -z "$XML" ]; then
    echo "Ús: $0 fitxer.xml"
    exit 1
fi

echo "1. Comprovant format..."
if ! xmlstarlet val -e "$XML" 2>&1; then
    echo "Error: Document mal format!"
    exit 1
fi

echo "2. Validant contra DTD..."
if ! xmlstarlet val -e -d "$DTD" "$XML" 2>&1; then
    echo "Error: Document no vàlid!"
    exit 2
fi

echo "3. Transformant a HTML..."
SORTIDA="${XML%.xml}.html"
if xmlstarlet tr "$XSL" "$XML" > "$SORTIDA"; then
    echo "OK: El fitxer resultant és a $SORTIDA."
else
    echo "Error: Transformació fallida!"
    exit 3
fi
```

### Equivalències

Equivalències de comandes entre `xmlint/xsltproc` i `xmlstarlet`:

| Funció           | xmllint / xsltproc                                  | xmlstarlet                                          |
|------------------|-----------------------------------------------------|-----------------------------------------------------|
| Comprovar format | `xmllint --noout fitxer.xml`                        | `xmlstarlet val -e fitxer.xml`                      |
| Validar amb DTD  | `xmllint --dtdvalid esquema.dtd --noout fitxer.xml` | `xmlstarlet val -e -d esquema.dtd fitxer.xml`       |
| Validar amb XSD  | `xmllint --schema esquema.xsd --noout fitxer.xml`   | `xmlstarlet val -e -s esquema.xsd fitxer.xml`       |
| Transformar XSLT | `xsltproc -o sortida.html estil.xsl fitxer.xml`     | `xmlstarlet tr estil.xsl fitxer.xml > sortida.html` |

> L'opció `-e` de `xmlstarlet` val mostra els errors de validació (equivalent al comportament per defecte de `xmllint`).


## Extensions

Si uses [VSCodium](https://vscodium.com/) o [VSCode](https://code.visualstudio.com/) per a desenvolupar, les extensions recomanades són les següents:

| Extensió          | Funcionalitats                  | VSCode                                                                                  | VSCodium                                                       |
|-------------------|---------------------------------|-----------------------------------------------------------------------------------------|----------------------------------------------------------------|
| **XML (Red Hat)** | Validació, formatació, XSD      | [Marketplace](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-xml)    | [Open VSX](https://open-vsx.org/extension/redhat/vscode-xml)   |
| **XML Tools**     | XPath, formatació               | [Marketplace](https://marketplace.visualstudio.com/items?itemName=DotJoshJohnson.xml)   | [Open VSX](https://open-vsx.org/extension/DotJoshJohnson/xml)  |
| **XSLT/XPath**    | Suport per XSLT 3.0 i XPath 3.1 | [Marketplace](https://marketplace.visualstudio.com/items?itemName=deltaxml.xslt-xpath)  | [Open VSX](https://open-vsx.org/extension/deltaxml/xslt-xpath) |

I si uses Vim o Neovim, et recoman les següents instruccions al teu fitxer `~/.vimrc`:

```vim
" Formatejar XML amb xmllint
command! XMLFormat %!xmllint --format -

" Validar XML
command! XMLValidate !xmllint --noout %

" Mapeig de tecles
nnoremap <leader>xf :XMLFormat<CR>
nnoremap <leader>xv :XMLValidate<CR>
```
