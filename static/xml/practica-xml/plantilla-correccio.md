# Plantilla de correcció: Catàleg de Videojocs XML

## Preparació

### Instal·lació d'eines (si no estan instal·lades)

```bash
# Eines XML (probablement ja instal·lades)
sudo apt install libxml2-utils xsltproc

# Validador HTML5 (requereix Python i Java)
pip install html5validator --break-system-packages
sudo apt install default-jre
```

### Estructura de fitxers esperada

```
lliurament/
├── basic.xml
├── cataleg.xml
├── cataleg.dtd
├── cataleg.xsd
├── cataleg.css
├── cataleg.xsl
└── cataleg.html
```

---

## Bloc 1: Document XML bàsic (3 punts)

### 1.1 Verificar que `basic.xml` està ben format

```bash
xmllint --noout basic.xml
```

- **Sense errors:** Document ben format ✓
- **Amb errors:** Document mal format, revisar missatges d'error

### 1.2 Verificar estructura jeràrquica (3+ nivells)

```bash
# Mostrar estructura en arbre
xmllint --xpath '//*' basic.xml | head -50

# Comptar nivells de profunditat (manual)
xmllint --format basic.xml | head -40
```

### 1.3 Comptar videojocs (15-20)

```bash
xmllint --xpath 'count(//videojoc)' basic.xml
```

- **Resultat esperat:** Entre 15 i 20

### 1.4 Verificar camps de videojocs

```bash
# Llistar tots els elements fills del primer videojoc
xmllint --xpath '//videojoc[1]/*' basic.xml 2>/dev/null | xmllint --format -

# Verificar camps específics existeixen
xmllint --xpath 'count(//titol)' basic.xml
xmllint --xpath 'count(//descripcio)' basic.xml
xmllint --xpath 'count(//desenvolupador)' basic.xml
xmllint --xpath 'count(//preu)' basic.xml
xmllint --xpath 'count(//puntuacio)' basic.xml
xmllint --xpath 'count(//requisits)' basic.xml
```

### 1.5 Comptar videojocs amb DLCs (mínim 3)

```bash
xmllint --xpath 'count(//videojoc[dlcs])' basic.xml
```

- **Resultat esperat:** >= 3

### 1.6 Verificar atributs

```bash
# Llistar tots els IDs de videojocs
xmllint --xpath '//videojoc/@id' basic.xml

# Verificar atribut moneda als preus
xmllint --xpath '//preu/@moneda' basic.xml

# Comprovar IDs únics (no hauria de repetir-se cap)
xmllint --xpath '//videojoc/@id' basic.xml 2>/dev/null | tr ' ' '\n' | sort | uniq -d
```

### 1.7 Verificar comentaris XML

```bash
grep -c '<!--' basic.xml
```

- **Resultat esperat:** >= 3

---

## Bloc 2: Validació i namespaces (4 punts)

### 2.1 Verificar namespaces declarats

```bash
# Mostrar declaracions de namespace a l'element arrel
head -10 cataleg.xml | grep xmlns
```

- **Esperat:** `xmlns:cat=` i `xmlns:joc=`

### 2.2 Verificar ús de prefixos

```bash
# Comptar elements amb prefix cat:
grep -o '<cat:[a-zA-Z]*' cataleg.xml | wc -l

# Comptar elements amb prefix joc:
grep -o '<joc:[a-zA-Z]*' cataleg.xml | wc -l
```

### 2.3 Verificar col·lisió de noms resolta

```bash
# Buscar elements amb el mateix nom local però diferent prefix
grep -E '<(cat|joc):titol' cataleg.xml
grep -E '<(cat|joc):descripcio' cataleg.xml
```

- **Esperat:** Almenys un element repetit amb prefixos diferents

### 2.4 Verificar xml:lang

```bash
# xml:lang a l'arrel
grep -o 'xml:lang="[^"]*"' cataleg.xml | head -1

# xml:lang a descripcions
grep 'xml:lang=' cataleg.xml | grep -E '(cat|joc):descripcio' | head -5
```

### 2.5 Verificar xml:base

```bash
grep 'xml:base=' cataleg.xml
```

### 2.6 Verificar metadades del catàleg

```bash
# Buscar secció info amb els camps requerits
xmllint --xpath '//*[local-name()="info"]' cataleg.xml 2>/dev/null | xmllint --format -
```

### 2.7 Validar amb DTD

```bash
# Verificar que el DOCTYPE està present
head -5 cataleg.xml | grep DOCTYPE

# Validar amb DTD
xmllint --valid --noout cataleg.xml
```

- **Sense errors:** DTD correcte ✓
- **Amb errors:** Revisar missatges

### 2.8 Validar amb XSD

```bash
xmllint --schema cataleg.xsd --noout cataleg.xml
```

- **Sense errors:** XSD correcte ✓
- **Amb errors:** Revisar missatges

### 2.9 Verificar restriccions XSD

```bash
# Buscar patrons (pattern)
grep -c 'xs:pattern' cataleg.xsd

# Buscar enumeracions
grep -c 'xs:enumeration' cataleg.xsd

# Buscar restriccions numèriques
grep -E 'minInclusive|maxInclusive|minExclusive|maxExclusive' cataleg.xsd | wc -l

# Buscar tipus de dades específics
grep -E 'xs:date|xs:decimal|xs:integer' cataleg.xsd | wc -l
```

---

## Bloc 3: Visualització CSS (2 punts)

### 3.1 Verificar enllaç CSS al XML

```bash
grep 'xml-stylesheet' cataleg.xml
```

- **Esperat:** `<?xml-stylesheet type="text/css" href="cataleg.css"?>`

### 3.2 Verificar existència i contingut CSS

```bash
# Verificar que el fitxer existeix i té contingut
wc -l cataleg.css

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

### 3.3 Visualització manual

```bash
# Obrir al navegador per verificar visualització
# (executar des d'entorn gràfic)
firefox cataleg.xml &
# o
google-chrome cataleg.xml &
```

---

## Bloc 4: Transformació XSLT (1 punt)

### 4.1 Verificar estructura XSLT

```bash
# Verificar declaració i namespaces
head -10 cataleg.xsl

# Comptar plantilles
grep -c 'xsl:template' cataleg.xsl

# Verificar output HTML
grep 'xsl:output' cataleg.xsl
```

### 4.2 Verificar elements XSLT requerits

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

# choose/when/otherwise
grep -c 'xsl:choose' cataleg.xsl
grep -c 'xsl:when' cataleg.xsl

# variables
grep -c 'xsl:variable' cataleg.xsl

# Attribute Value Templates (buscar {})
grep -E '\{[@$][^}]+\}' cataleg.xsl | wc -l
```

### 4.3 Executar transformació XSLT

```bash
# Generar HTML
xsltproc -o /tmp/test-cataleg.html cataleg.xsl cataleg.xml

# Verificar que s'ha generat
ls -la /tmp/test-cataleg.html

# Comparar amb el lliurat
diff /tmp/test-cataleg.html cataleg.html
```

### 4.4 Validar HTML generat

```bash
# Validar HTML5
html5validator cataleg.html

# O amb més detall
html5validator --show-warnings cataleg.html
```

### 4.5 Verificar contingut HTML

```bash
# Verificar DOCTYPE
head -3 cataleg.html | grep -i doctype

# Verificar lang="ca"
grep -o 'lang="[^"]*"' cataleg.html | head -1

# Verificar que només mostra català (no hauria de tenir xml:lang="en" visible)
grep -c 'xml:lang="en"' cataleg.html
# Esperat: 0

# Verificar estadístiques (buscar count, total, mitjana)
grep -iE '(total|mitjana|count)' cataleg.html

# Verificar CSS incrustat
grep -c '<style>' cataleg.html
```

---

## Script de correcció automatitzada

```bash
#!/bin/bash
# corrector.sh - Script de correcció automàtica
# Ús: ./corrector.sh <directori_lliurament>

DIR="${1:-.}"
ERRORS=0
AVISOS=0

echo "=== Correcció Pràctica XML Catàleg Videojocs ==="
echo "Directori: $DIR"
echo ""

# Funció per mostrar resultat
check() {
    if [ $1 -eq 0 ]; then
        echo "  ✓ $2"
    else
        echo "  ✗ $2"
        ((ERRORS++))
    fi
}

warning() {
    echo "  ⚠ $1"
    ((AVISOS++))
}

# BLOC 1
echo "=== BLOC 1: Document XML bàsic ==="

# 1.1 basic.xml ben format
xmllint --noout "$DIR/basic.xml" 2>/dev/null
check $? "basic.xml ben format"

# 1.2 Comptar videojocs
COUNT=$(xmllint --xpath 'count(//videojoc)' "$DIR/basic.xml" 2>/dev/null)
if [ "$COUNT" -ge 15 ] && [ "$COUNT" -le 20 ]; then
    echo "  ✓ Nombre de videojocs: $COUNT (15-20)"
else
    echo "  ✗ Nombre de videojocs: $COUNT (esperat 15-20)"
    ((ERRORS++))
fi

# 1.3 DLCs
DLCS=$(xmllint --xpath 'count(//videojoc[dlcs])' "$DIR/basic.xml" 2>/dev/null)
if [ "$DLCS" -ge 3 ]; then
    echo "  ✓ Videojocs amb DLCs: $DLCS (mínim 3)"
else
    echo "  ✗ Videojocs amb DLCs: $DLCS (mínim 3)"
    ((ERRORS++))
fi

# 1.4 Comentaris
COMMENTS=$(grep -c '<!--' "$DIR/basic.xml" 2>/dev/null)
if [ "$COMMENTS" -ge 3 ]; then
    echo "  ✓ Comentaris XML: $COMMENTS (mínim 3)"
else
    warning "Comentaris XML: $COMMENTS (recomanat mínim 3)"
fi

echo ""
echo "=== BLOC 2: Validació i namespaces ==="

# 2.1 cataleg.xml ben format
xmllint --noout "$DIR/cataleg.xml" 2>/dev/null
check $? "cataleg.xml ben format"

# 2.2 Namespaces
NS_CAT=$(grep -c 'xmlns:cat=' "$DIR/cataleg.xml" 2>/dev/null)
NS_JOC=$(grep -c 'xmlns:joc=' "$DIR/cataleg.xml" 2>/dev/null)
if [ "$NS_CAT" -ge 1 ] && [ "$NS_JOC" -ge 1 ]; then
    echo "  ✓ Namespaces declarats (cat: i joc:)"
else
    echo "  ✗ Falten namespaces"
    ((ERRORS++))
fi

# 2.3 xml:lang
LANG=$(grep -c 'xml:lang=' "$DIR/cataleg.xml" 2>/dev/null)
if [ "$LANG" -ge 2 ]; then
    echo "  ✓ Atribut xml:lang present ($LANG ocurrències)"
else
    echo "  ✗ Atribut xml:lang insuficient"
    ((ERRORS++))
fi

# 2.4 xml:base
BASE=$(grep -c 'xml:base=' "$DIR/cataleg.xml" 2>/dev/null)
if [ "$BASE" -ge 1 ]; then
    echo "  ✓ Atribut xml:base present"
else
    warning "Atribut xml:base no trobat"
fi

# 2.5 Validar DTD
if [ -f "$DIR/cataleg.dtd" ]; then
    xmllint --valid --noout "$DIR/cataleg.xml" 2>/dev/null
    check $? "Validació DTD"
else
    echo "  ✗ Fitxer cataleg.dtd no trobat"
    ((ERRORS++))
fi

# 2.6 Validar XSD
if [ -f "$DIR/cataleg.xsd" ]; then
    xmllint --schema "$DIR/cataleg.xsd" --noout "$DIR/cataleg.xml" 2>/dev/null
    check $? "Validació XSD"
else
    echo "  ✗ Fitxer cataleg.xsd no trobat"
    ((ERRORS++))
fi

echo ""
echo "=== BLOC 3: Visualització CSS ==="

# 3.1 Enllaç CSS
STYLESHEET=$(grep -c 'xml-stylesheet' "$DIR/cataleg.xml" 2>/dev/null)
if [ "$STYLESHEET" -ge 1 ]; then
    echo "  ✓ Instrucció xml-stylesheet present"
else
    echo "  ✗ Falta instrucció xml-stylesheet"
    ((ERRORS++))
fi

# 3.2 Fitxer CSS
if [ -f "$DIR/cataleg.css" ]; then
    echo "  ✓ Fitxer cataleg.css present"
    
    # Variables CSS
    VARS=$(grep -c '\-\-' "$DIR/cataleg.css" 2>/dev/null)
    [ "$VARS" -ge 1 ] && echo "    - Variables CSS: $VARS" || warning "Sense variables CSS"
    
    # Grid/Flexbox
    LAYOUT=$(grep -cE 'display:\s*(grid|flex)' "$DIR/cataleg.css" 2>/dev/null)
    [ "$LAYOUT" -ge 1 ] && echo "    - Layout modern: $LAYOUT" || warning "Sense Grid/Flexbox"
    
    # Pseudoelements
    PSEUDO=$(grep -cE '::(before|after)' "$DIR/cataleg.css" 2>/dev/null)
    [ "$PSEUDO" -ge 1 ] && echo "    - Pseudoelements: $PSEUDO" || warning "Sense pseudoelements"
    
    # :hover
    HOVER=$(grep -c ':hover' "$DIR/cataleg.css" 2>/dev/null)
    [ "$HOVER" -ge 1 ] && echo "    - Interactivitat :hover: $HOVER" || warning "Sense :hover"
else
    echo "  ✗ Fitxer cataleg.css no trobat"
    ((ERRORS++))
fi

echo ""
echo "=== BLOC 4: Transformació XSLT ==="

# 4.1 Fitxer XSL
if [ -f "$DIR/cataleg.xsl" ]; then
    echo "  ✓ Fitxer cataleg.xsl present"
    
    # Elements XSLT
    echo "    - xsl:template: $(grep -c 'xsl:template' "$DIR/cataleg.xsl")"
    echo "    - xsl:for-each: $(grep -c 'xsl:for-each' "$DIR/cataleg.xsl")"
    echo "    - xsl:apply-templates: $(grep -c 'xsl:apply-templates' "$DIR/cataleg.xsl")"
    echo "    - xsl:sort: $(grep -c 'xsl:sort' "$DIR/cataleg.xsl")"
    echo "    - xsl:if: $(grep -c 'xsl:if' "$DIR/cataleg.xsl")"
    echo "    - xsl:choose: $(grep -c 'xsl:choose' "$DIR/cataleg.xsl")"
    echo "    - xsl:variable: $(grep -c 'xsl:variable' "$DIR/cataleg.xsl")"
else
    echo "  ✗ Fitxer cataleg.xsl no trobat"
    ((ERRORS++))
fi

# 4.2 Transformació
if [ -f "$DIR/cataleg.xsl" ] && [ -f "$DIR/cataleg.xml" ]; then
    xsltproc -o /tmp/test-output.html "$DIR/cataleg.xsl" "$DIR/cataleg.xml" 2>/dev/null
    check $? "Transformació XSLT executable"
fi

# 4.3 HTML generat
if [ -f "$DIR/cataleg.html" ]; then
    echo "  ✓ Fitxer cataleg.html present"
    
    # Validar HTML5 (si html5validator està instal·lat)
    if command -v html5validator &> /dev/null; then
        html5validator "$DIR/cataleg.html" 2>/dev/null
        check $? "Validació HTML5"
    else
        warning "html5validator no instal·lat, validació HTML5 omesa"
    fi
else
    echo "  ✗ Fitxer cataleg.html no trobat"
    ((ERRORS++))
fi

echo ""
echo "=== RESUM ==="
echo "Errors: $ERRORS"
echo "Avisos: $AVISOS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✓ Tots els tests bàsics superats!"
else
    echo "✗ Hi ha $ERRORS errors a revisar"
fi
```

---

## Llista de verificació manual

### Bloc 1 (3 pt)
- [ ] Declaració XML correcta (versió, codificació)
- [ ] Estructura jeràrquica amb 3+ nivells
- [ ] 15-20 videojocs
- [ ] Tots els camps requerits per videojoc
- [ ] 3+ videojocs amb DLCs
- [ ] IDs únics i moneda als preus
- [ ] Mínim 3 comentaris descriptius

### Bloc 2 (4 pt)
- [ ] Namespaces cat: i joc: declarats i usats
- [ ] Col·lisió de noms resolta (titol o descripcio)
- [ ] xml:lang a l'arrel i descripcions
- [ ] xml:base a recursos
- [ ] Secció metadades completa
- [ ] DTD valida sense errors
- [ ] XSD valida amb restriccions avançades

### Bloc 3 (2 pt)
- [ ] Instrucció xml-stylesheet
- [ ] Layout amb Grid o Flexbox
- [ ] Variables CSS
- [ ] Selectors variats (element, atribut, descendent)
- [ ] Pseudoelements ::before/::after amb attr()
- [ ] Interactivitat :hover

### Bloc 4 (1 pt)
- [ ] Múltiples plantilles xsl:template
- [ ] Iteració: for-each, apply-templates, value-of
- [ ] Ordenació: xsl:sort
- [ ] Condicionals: xsl:if i xsl:choose
- [ ] Variables globals amb estadístiques
- [ ] Attribute Value Templates {}
- [ ] HTML5 generat amb 3 seccions
- [ ] Només descripcions en català
