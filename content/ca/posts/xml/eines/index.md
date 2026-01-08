---
title: "Eines de feina XML"
date: 2026-01-03
lastmod: 2026-01-08
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

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu, més un quart exercici avançat.

### Exercici 1

**Consultes `XPath` amb `xmllint`**

Donat el [document XML d'una botiga de música](/xml/eines/botiga-musica.xml), escriu les expressions `XPath` necessàries per obtenir la informació sol·licitada i la comanda `xmllint` completa per a cada consulta:

1. Obtenir el nom de la botiga (atribut de l'element arrel).
2. Llistar tots els títols dels discos.
3. Obtenir el títol i l'artista del disc amb id "D003".
4. Llistar els títols dels discos en format vinil.
5. Obtenir els discos de Jazz (tots els fills de l'element `<disc>`).
6. Comptar el nombre total de discos.
7. Calcular la suma total de l'estoc (unitats disponibles).
8. Obtenir els discos amb preu superior a 30€.
9. Llistar els discos anteriors a 1970 (ordenats pel document, no per `XPath`).
10. Obtenir els discos sense estoc (estoc = 0).

Validació: Executa cada comanda i verifica que el resultat és correcte.

### Exercici 2

**Edició i selecció amb `xmlstarlet`**

Usant el mateix document `botiga-musica.xml` de l'exercici 1, realitza les següents operacions amb `xmlstarlet`.

**Part A: Selecció amb format personalitzat**

Escriu les comandes `xmlstarlet sel` per obtenir:

1. Un llistat amb format `ARTISTA - TITOL (ANY)` per a cada disc.
2. Un llistat dels discos de vinil amb format `[ID] TITOL: PREU €`.
3. La suma total del valor de l'inventari (preu × estoc per a cada disc, sumat).

Pista per al punt 3: `xmlstarlet` no pot fer càlculs complexos directament, però pots extreure les dades i processar-les amb `awk`. L'estratègia és:

```bash
# 1. Extreure preu i estoc de cada disc, separats per espai
xmlstarlet sel -t -m "//disc" -v "preu" -o " " -v "estoc" -n fitxer.xml
# Sortida:
# 32.99 5
# 15.99 12
# ...

# 2. Usar awk per multiplicar i sumar
# awk '{suma += $1 * $2} END {print suma}'
# On $1 és el preu i $2 és l'estoc de cada línia

# 3. Combinar amb pipe
xmlstarlet sel -t -m "//disc" -v "preu" -o " " -v "estoc" -n fitxer.xml | \
    awk '{suma += $1 * $2} END {printf "Valor total inventari: %.2f €\n", suma}'
```

**Part B: Edició de documents**

Escriu les comandes `xmlstarlet ed` per:

4. Afegir un atribut `disponible="true"` a tots els discos amb estoc > 0.
5. Afegir un atribut `disponible="false"` als discos amb estoc = 0.
6. Canviar el preu del disc "D004" a 10.99.
7. Afegir un nou element `<ubicacio>Secció Rock</ubicacio>` a tots els discos de gènere "Rock".
8. Eliminar l'element `<estoc>` de tots els discos (simulant que no volem mostrar aquesta informació).

**Part C: Altres operacions**

9. Mostra l'estructura d'elements del document (sense valors) amb `xmlstarlet el`.
10. Formata el document amb `xmlstarlet fo` i guarda'l com a `botiga-formatejada.xml`.

### Exercici 3

**Script de processament XML**

Tens un directori amb múltiples fitxers XML de comandes d'una botiga online, on cada fitxer segueix aquesta estructura:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<comanda id="COM-2025-001" data="2025-01-15">
    <client>
        <nom>Maria García</nom>
        <email>maria@example.com</email>
    </client>
    <productes>
        <producte codi="PROD001" quantitat="2">
            <nom>Teclat mecànic</nom>
            <preu>89.99</preu>
        </producte>
        <producte codi="PROD002" quantitat="1">
            <nom>Ratolí ergonòmic</nom>
            <preu>45.00</preu>
        </producte>
    </productes>
    <estat>pendent</estat>
</comanda>
```

Genera al manco tres fitxers de comandes, anomenats `comanda-COM-2025-001.xml`, `comanda-COM-2025-002.xml`, etc, seguint aquest format. Llavors, combinant l'ús de `xmllint`, `xsltproc` i/o `xmlstarlet`, crea un script de Bash `processa-comandes.sh` que processi la col·lecció de fitxers XML i generi un informe.

Requisits de l'script:

1. **Validació:** Per a cada fitxer XML del directori:
   * Comprova que és ben format.
   * Mostra un missatge d'error si no ho és i continua amb el següent.

2. **Extracció de dades:** Per a cada comanda vàlida, extreu:
   * ID de la comanda.
   * Data.
   * Nom del client.
   * Nombre de productes.
   * Total de la comanda (suma de preu × quantitat).

3. **Informe:** Genera un fitxer `informe.txt` amb:
   * Capçalera amb data de generació.
   * Llistat de comandes processades amb les dades extretes.
   * Resum final: total de comandes, comandes pendents, import total.

4. **Opcions de l'script:**
   * `-d directori`: Directori amb els fitxers XML (per defecte: directori actual).
   * `-o fitxer`: Fitxer de sortida (per defecte: `informe.txt`).
   * `-v`: Mode verbose (mostra informació de progrés).
   * `-h`: Mostra ajuda.

Estructura suggerida:

```bash
#!/bin/bash

# Valors per defecte
DIRECTORI="."
SORTIDA="informe.txt"
VERBOSE=false

# Variables per al resum
TOTAL_COMANDES=0
TOTAL_PENDENTS=0
IMPORT_TOTAL=0

# Funció d'ajuda
mostrar_ajuda() {
    echo "Ús: $0 [-d directori] [-o fitxer] [-v] [-h]"
    echo "  -d directori  Directori amb fitxers XML (defecte: .)"
    echo "  -o fitxer     Fitxer de sortida (defecte: informe.txt)"
    echo "  -v            Mode verbose"
    echo "  -h            Mostra aquesta ajuda"
}

# Processar arguments
while getopts "d:o:vh" opt; do
    case $opt in
        d) DIRECTORI="$OPTARG" ;;
        o) SORTIDA="$OPTARG" ;;
        v) VERBOSE=true ;;
        h) mostrar_ajuda; exit 0 ;;
        *) exit 1 ;;
    esac
done

# Iniciar fitxer d'informe (sobreescriu si existeix)
{
    echo "========================================"
    echo "INFORME DE COMANDES"
    echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo ""
} > "$SORTIDA"

# Funció per processar una comanda
processar_comanda() {
    local fitxer="$1"
    
    # Extreure dades amb xmllint o xmlstarlet
    local id=$(xmllint --xpath "string(/comanda/@id)" "$fitxer" 2>/dev/null)
    local data=$(xmllint --xpath "string(/comanda/@data)" "$fitxer" 2>/dev/null)
    local client=$(xmllint --xpath "string(//client/nom)" "$fitxer" 2>/dev/null)
    local num_productes=$(xmllint --xpath "count(//producte)" "$fitxer" 2>/dev/null)
    local estat=$(xmllint --xpath "string(//estat)" "$fitxer" 2>/dev/null)
    
    # TODO: Calcular total (preu × quantitat per cada producte)
    local total=0
    
    # Escriure al fitxer d'informe (afegeix al final)
    {
        echo "Comanda: $id"
        echo "  Data: $data"
        echo "  Client: $client"
        echo "  Productes: $num_productes"
        echo "  Total: $total €"
        echo "  Estat: $estat"
        echo ""
    } >> "$SORTIDA"
    
    # Actualitzar comptadors globals
    ((TOTAL_COMANDES++))
    if [ "$estat" = "pendent" ]; then
        ((TOTAL_PENDENTS++))
    fi
    # TODO: Acumular import total
}

# Bucle principal
for xml in "$DIRECTORI"/*.xml; do
    # Comprovar que existeixen fitxers
    [ -e "$xml" ] || continue
    
    if $VERBOSE; then
        echo "Processant: $xml"
    fi
    
    # Validar document
    if ! xmllint --noout "$xml" 2>/dev/null; then
        echo "AVÍS: $xml no és un XML vàlid, s'omet." >&2
        continue
    fi
    
    # Processar comanda
    processar_comanda "$xml"
done

# Afegir resum al final de l'informe
{
    echo "========================================"
    echo "RESUM"
    echo "========================================"
    echo "Total comandes processades: $TOTAL_COMANDES"
    echo "Comandes pendents: $TOTAL_PENDENTS"
    echo "Import total: $IMPORT_TOTAL €"
} >> "$SORTIDA"

# Missatge final
echo "Informe generat a: $SORTIDA"
```

Validació: L'script ha de funcionar correctament amb els fitxers de prova, generant la sortida esperada amb els valors correctes.

### Exercici 4

**XSLT 2.0 amb agrupació (avançat)**

Aquest exercici requereix usar [XSLTFiddle](https://xsltfiddle.liberty-development.net/) online o instal·lar Saxon localment.

L'objectiu de l'exercici és transformar el document `botiga-musica.xml` de l'exercici 1 a HTML agrupant els discos per gènere, usant `<xsl:for-each-group>` d'XSLT 2.0.

Requisits de la transformació:

1. Agrupa els discos per gènere usant `<xsl:for-each-group>`.
2. Per a cada gènere, mostra:
   * Nom del gènere com a títol.
   * Nombre de discos d'aquest gènere.
   * Llistat dels discos ordenats per any (ascendent).
3. Dins de cada disc, mostra:
   * Títol i artista.
   * Any i format.
   * Preu (formatejat amb 2 decimals usant `format-number()`).
4. Al final, mostra estadístiques generals:
   * Total de gèneres diferents.
   * Disc més antic (usa `min()` sobre els anys).
   * Disc més recent (usa `max()`).
   * Preu mitjà (usa `avg()`).

Estructura XSLT 2.0 suggerida del fitxer `botiga-generes.xsl`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    
    <xsl:output method="html" encoding="UTF-8" indent="yes"/>
    
    <xsl:template match="/">
        <html>
            <head><title>Catàleg per gènere</title></head>
            <body>
                <h1>Catàleg de <xsl:value-of select="/botiga/@nom"/></h1>
                
                <!-- Agrupació per gènere -->
                <xsl:for-each-group select="//disc" group-by="genere">
                    <xsl:sort select="current-grouping-key()"/>
                    
                    <section>
                        <h2><xsl:value-of select="current-grouping-key()"/></h2>
                        <p>(<xsl:value-of select="count(current-group())"/> discos)</p>
                        
                        <ul>
                            <xsl:for-each select="current-group()">
                                <xsl:sort select="any" data-type="number"/>
                                <li>
                                    <!-- TODO: Mostrar informació del disc -->
                                </li>
                            </xsl:for-each>
                        </ul>
                    </section>
                </xsl:for-each-group>
                
                <!-- Estadístiques -->
                <footer>
                    <h2>Estadístiques</h2>
                    <!-- TODO: Implementar amb min(), max(), avg() -->
                </footer>
            </body>
        </html>
    </xsl:template>
    
</xsl:stylesheet>
```

Comparació opcional amb XSLT 1.0: Com a part de l'exercici, intenta implementar la mateixa agrupació usant el mètode Muenchian d'XSLT 1.0 (amb `<xsl:key>`), en un fitxer que anomenaríem `botiga-generes-1.0.xsl`. Compara:

* Nombre de línies de codi.
* Llegibilitat.
* Facilitat de manteniment.

**Execució**

Amb XSLTFiddle:

1. Ves al web d'[XSLTFiddle](https://xsltfiddle.liberty-development.net/).
2. Enganxa l'XML a la secció "XML Input".
3. Enganxa l'XSLT a la secció "XSLT".
4. Selecciona "Saxon-HE" o "Saxon-JS" com a processador.
5. Fes clic a "Run".

Amb Saxon, localment, primer l'haurem d'instal·lar:

```bash
sudo apt install libsaxonb-java
```

I llavors podrem executar la transformació:

```bash
saxonb-xslt -s:botiga-musica.xml -xsl:botiga-generes.xsl -o:resultat.html
```
