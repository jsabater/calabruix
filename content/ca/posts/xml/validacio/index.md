---
title: "Validació documents XML"
date: 2026-01-03
lastmod: 2026-01-11
description: "Validació de documents XML amb DTD i XSD. Sintaxi de DTD, introducció a XML Schema i comparativa entre ambdós sistemes."
summary: "Esquemes de validació XML: DTD complet, introducció a XSD i exemples pràctics."
categories: ["teaching"]
tags: ["xml", "dtd", "xsd", "schema"]
series: ["XML"]
series_order: 4
weight: 40
slug: validacio-documents
---

Un document XML **ben format** segueix les regles sintàctiques bàsiques, però això no garanteix que l'estructura sigui correcta per a una aplicació concreta. Per exemple, un document d'alumnes podria estar ben format però tenir un camp `<edat>` on s'esperava `<data-naixement>`.

La **validació** comprova que el document segueix un esquema predefinit que estableix:

* Quins elements poden existir.
* En quin ordre i amb quina freqüència.
* Quins atributs són permesos o obligatoris.
* Quin tipus de contingut pot tenir cada element.

Hi ha dos sistemes principals de validació: Document Type Definition (DTD) i XML Schema Definition (XSD).

## Document Type Definition

Les DTD són el sistema de validació original de l'XML, heretat de l'SGML. Tot i que, avui dia, XSD ofereix més funcionalitats, les DTD continuen sent àmpliament utilitzades per la seva senzillesa.

La DTD es vincula al document XML mitjançant la declaració `<!DOCTYPE>`, que pot ser intern (dins el document XML), externa (en un fitxer separat) o pública (amb identificador públic):

```xml
<!-- DTD interna -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE institut [
    <!-- Inici de declaracions DTD -->
]>
<institut>
    [..]
</institut>

<!-- DTD externa -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE institut SYSTEM "institut.dtd">
<institut>
    [..]
</institut>

<!-- DTD pública -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" 
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
[..]
```

### Definició d'elements

La declaració `<!ELEMENT>` defineix quins elements poden existir i quin contingut poden tenir. La sintaxi bàsica és aquesta:

```dtd
<!ELEMENT nom-element (contingut)>
```

Els tipus de continguts suportats són els següents:

| Contingut   | Significat                 | Exemple                     |
|-------------|----------------------------|-----------------------------|
| `EMPTY`     | Element sense contingut    | `<!ELEMENT br EMPTY>`       |
| `ANY`       | Qualsevol contingut        | `<!ELEMENT contenidor ANY>` |
| `(#PCDATA)` | Només text                 | `<!ELEMENT nom (#PCDATA)>`  |
| `(fill)`    | Un element fill            | `<!ELEMENT pare (fill)>`    |
| `(a,b,c)`   | Seqüència ordenada         | `<!ELEMENT x (a,b,c)>`      |
| `(a\|b\|c)` | Alternativa (un dels tres) | `<!ELEMENT x (a\|b\|c)>`    |

Els indicadors de cardinalitat suportats són els següents:

| Símbol | Significat    | Exemple      |
|--------|---------------|--------------|
| (cap)  | Exactament un | `(element)`  |
| `?`    | Zero o un     | `(element?)` |
| `*`    | Zero o més    | `(element*)` |
| `+`    | Un o més      | `(element+)` |

Exemples pràctics:

```dtd
<!-- Element buit -->
<!ELEMENT separador EMPTY>

<!-- Element amb només text -->
<!ELEMENT nom (#PCDATA)>

<!-- Element amb fills en ordre específic -->
<!ELEMENT alumne (nom, cognoms, data-naixement, email)>

<!-- Element amb fills opcionals -->
<!ELEMENT persona (nom, cognoms, telefon?, email?)>

<!-- Element amb fills repetibles -->
<!ELEMENT alumnes (alumne+)>

<!-- Element amb alternatives -->
<!ELEMENT contacte (email | telefon | adreca)>

<!-- Contingut mixt (text i elements) -->
<!ELEMENT paragraf (#PCDATA | negreta | cursiva)*>
```

### Definició d'atributs

La declaració `<!ATTLIST>` defineix els atributs permesos per a un element. La sintaxi bàsica és aquesta:

```dtd
<!ATTLIST nom-element
    nom-atribut tipus-atribut valor-per-defecte
>
```

Els tipus d'atributs suportats són els següents:

|    Tipus     | Descripció                     | Exemple de valor  |
|--------------|--------------------------------|-------------------|
| `CDATA`      | Text lliure                    | "qualsevol cosa"  |
| `ID`         | Identificador únic al document | "A001"            |
| `IDREF`      | Referència a un ID existent    | "A001"            |
| `IDREFS`     | Llista de referències a IDs    | "A001 A002 A003"  |
| `NMTOKEN`    | Token de nom (sense espais)    | "valor123"        |
| `NMTOKENS`   | Llista de tokens               | "val1 val2 val3"  |
| `(a\|b\|c)`  | Enumeració de valors           | "a" o "b" o "c"   |

Els valors per defecte son els següents:

|      Valor       | Significat                           |
|------------------|--------------------------------------|
| `#REQUIRED`      | L'atribut és obligatori              |
| `#IMPLIED`       | L'atribut és opcional                |
| `#FIXED "valor"` | Valor fix, no es pot canviar         |
| `"valor"`        | Valor per defecte si no s'especifica |

Exemples pràctics:

```dtd
<!-- Atribut obligatori de tipus ID -->
<!ATTLIST alumne id ID #REQUIRED>

<!-- Atribut opcional de text lliure -->
<!ATTLIST alumne comentari CDATA #IMPLIED>

<!-- Atribut amb valor per defecte -->
<!ATTLIST alumne actiu (si|no) "si">

<!-- Atribut amb valor fix -->
<!ATTLIST document versio CDATA #FIXED "1.0">

<!-- Múltiples atributs per a un element -->
<!ATTLIST assignatura
    codi ID #REQUIRED
    obligatoria (si|no) "si"
    hores-setmana NMTOKEN #IMPLIED
>

<!-- Referència a un altre element -->
<!ATTLIST matricula
    alumne IDREF #REQUIRED
    assignatura IDREF #REQUIRED
>
```

### Definició d'entitats

Les entitats declarades amb `<!ENTITY>` permeten definir abreviatures o incloure contingut extern. Aquestes entitats poden ser internes o externes:

```dtd
<!-- Entitats internes -->
<!ENTITY cifp "CIFP Francesc de Borja Moll">
<!ENTITY copyright "© 2025 Tots els drets reservats">

<!-- Ús al document -->
<nom>&cifp;</nom>
<peu>&copyright;</peu>

<!-- Entitats externes -->
<!ENTITY capitol1 SYSTEM "capitol1.xml">
<!ENTITY logo SYSTEM "logo.png" NDATA png>
```

Addicionalment, les entitats també poden ser de de paràmetre (per a DTD). Aquestes s'usen dins de la pròpia DTD per reutilitzar declaracions:

```dtd
<!ENTITY % dades-personals "nom, cognoms, email">
<!ELEMENT alumne (%dades-personals;, data-naixement)>
<!ELEMENT professor (%dades-personals;, departament)>
```

### Exemple complet

A continuació es mostra un [exemple de DTD extern per a l'exemple de l'institut](/xml/validacio/institut.dtd), que podríem guardar amb el nom `institut.dtd`:

```dtd
<?xml version="1.0" encoding="UTF-8"?>
<!ELEMENT institut (nom, codi, any-academic, curs+)>

<!ELEMENT nom (#PCDATA)>
<!ELEMENT codi (#PCDATA)>
<!ELEMENT any-academic (#PCDATA)>

<!ELEMENT curs (assignatures, alumnes)>
<!ATTLIST curs
    id ID #REQUIRED
    nom CDATA #REQUIRED
>

<!ELEMENT assignatures (assignatura+)>
<!ELEMENT assignatura (nom, hores)>
<!ATTLIST assignatura
    codi ID #REQUIRED
>

<!ELEMENT hores (#PCDATA)>

<!ELEMENT alumnes (alumne+)>
<!ELEMENT alumne (nom, cognoms, data-naixement, email)>
<!ATTLIST alumne
    id ID #REQUIRED
>

<!ELEMENT cognoms (#PCDATA)>
<!ELEMENT data-naixement (#PCDATA)>
<!ELEMENT email (#PCDATA)>
```

I al fitxer `institut.xml` tendríem la següent referència:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE institut SYSTEM "institut.dtd">
<institut>
    [..]
</institut>
```

En canvi, si optàssim per una [DTD interna completa per a l'exemple de l'institut](/xml/validacio/institut.xml), llavors obtendríem el següent fitxer `institut.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE institut [
    <!ELEMENT institut (nom, codi, any-academic, curs+)>
    <!ELEMENT nom (#PCDATA)>
    <!ELEMENT codi (#PCDATA)>
    <!ELEMENT any-academic (#PCDATA)>
    <!ELEMENT curs (assignatures, alumnes)>
    <!ATTLIST curs
        id ID #REQUIRED
        nom CDATA #REQUIRED
    >
    <!ELEMENT assignatures (assignatura+)>
    <!ELEMENT assignatura (nom, hores)>
    <!ATTLIST assignatura codi ID #REQUIRED>
    <!ELEMENT hores (#PCDATA)>
    <!ELEMENT alumnes (alumne+)>
    <!ELEMENT alumne (nom, cognoms, data-naixement, email)>
    <!ATTLIST alumne id ID #REQUIRED>
    <!ELEMENT cognoms (#PCDATA)>
    <!ELEMENT data-naixement (#PCDATA)>
    <!ELEMENT email (#PCDATA)>
]>
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

## XML Schema

XML Schema (XSD) és un sistema de validació més modern i potent que les DTD. Va ser recomanat pel W3C l'any 2001 i ofereix avantatges significatius.

| Característica     | DTD              | XSD                               |
|--------------------|------------------|-----------------------------------|
| Sintaxi            | Pròpia (no XML)  | XML                               |
| Tipus de dades     | Limitats         | Rics (enters, dates, decimals...) |
| Espais de noms     | No suportats     | Suportats                         |
| Extensibilitat     | Limitada         | Alta (herència, restriccions)     |
| Documentació       | Comentaris       | Elements d'anotació               |
| Valors per defecte | Només atributs   | Elements i atributs               |

La seva estructura bàsica és la següent:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
    
    <!-- Definicions d'elements, tipus, etc. -->
    
</xs:schema>
```

XSD inclou més de 40 tipus de dades predefinits. Alguns dels més importants són els següents:

| Categoria      |     Tipus      | Exemple de valor    |
|----------------|----------------|---------------------|
| Text           | `xs:string`    | "Hola món"          |
| Numèrics       | `xs:integer`   | 42                  |
|                | `xs:decimal`   | 3.14                |
|                | `xs:float`     | 2.5E10              |
| Booleans       | `xs:boolean`   | true, false         |
| Dates          | `xs:date`      | 2025-03-15          |
|                | `xs:dateTime`  | 2025-03-15T10:30:00 |
|                | `xs:time`      | 10:30:00            |
| URIs           | `xs:anyURI`    | https://exemple.com |
| Identificadors | `xs:ID`        | A001                |
|                | `xs:IDREF`     | A001                |

Exemple de definició d'elements simples:

```xml
<!-- Element amb tipus predefinit -->
<xs:element name="nom" type="xs:string"/>
<xs:element name="hores" type="xs:integer"/>
<xs:element name="data-naixement" type="xs:date"/>
<xs:element name="actiu" type="xs:boolean"/>

<!-- Element amb valor per defecte -->
<xs:element name="pais" type="xs:string" default="Espanya"/>

<!-- Element amb valor fix -->
<xs:element name="versio" type="xs:string" fixed="1.0"/>
```

Exemple de definició d'elements complexos:

```xml
<!-- Element amb fills -->
<xs:element name="alumne">
    <xs:complexType>
        <xs:sequence>
            <xs:element name="nom" type="xs:string"/>
            <xs:element name="cognoms" type="xs:string"/>
            <xs:element name="data-naixement" type="xs:date"/>
            <xs:element name="email" type="xs:string"/>
        </xs:sequence>
        <xs:attribute name="id" type="xs:ID" use="required"/>
    </xs:complexType>
</xs:element>
```

Exemple d'indicadors de cardinalitat:

```xml
<xs:element name="telefon" type="xs:string" minOccurs="0" maxOccurs="3"/>
<!-- minOccurs="0" = opcional -->
<!-- maxOccurs="unbounded" = sense límit -->
```

Exemple de tipus personalitzats amb restriccions:

```xml
<!-- Tipus per a codis d'assignatura (3-4 lletres majúscules) -->
<xs:simpleType name="tipusCodiAssignatura">
    <xs:restriction base="xs:string">
        <xs:pattern value="[A-Z]{3,4}"/>
    </xs:restriction>
</xs:simpleType>

<!-- Tipus per a hores (entre 1 i 300) -->
<xs:simpleType name="tipusHores">
    <xs:restriction base="xs:integer">
        <xs:minInclusive value="1"/>
        <xs:maxInclusive value="300"/>
    </xs:restriction>
</xs:simpleType>

<!-- Tipus per a email -->
<xs:simpleType name="tipusEmail">
    <xs:restriction base="xs:string">
        <xs:pattern value="[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"/>
    </xs:restriction>
</xs:simpleType>
```

A continuació es mostra un [exemple d'XSD extern per a l'exemple de l'institut](/xml/validacio/institut.xsd), que podríem guardar amb el nom `institut.xsd`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
    
    <!-- Tipus personalitzats -->
    <xs:simpleType name="tipusCodiAssignatura">
        <xs:restriction base="xs:string">
            <xs:pattern value="[A-Z]{2,5}"/>
        </xs:restriction>
    </xs:simpleType>
    
    <xs:simpleType name="tipusHores">
        <xs:restriction base="xs:integer">
            <xs:minInclusive value="1"/>
            <xs:maxInclusive value="300"/>
        </xs:restriction>
    </xs:simpleType>
    
    <xs:simpleType name="tipusEmail">
        <xs:restriction base="xs:string">
            <xs:pattern value="[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"/>
        </xs:restriction>
    </xs:simpleType>
    
    <!-- Element arrel -->
    <xs:element name="institut">
        <xs:complexType>
            <xs:sequence>
                <xs:element name="nom" type="xs:string"/>
                <xs:element name="codi" type="xs:string"/>
                <xs:element name="any-academic" type="xs:string"/>
                <xs:element name="curs" maxOccurs="unbounded">
                    <xs:complexType>
                        <xs:sequence>
                            <xs:element name="assignatures">
                                <xs:complexType>
                                    <xs:sequence>
                                        <xs:element name="assignatura" maxOccurs="unbounded">
                                            <xs:complexType>
                                                <xs:sequence>
                                                    <xs:element name="nom" type="xs:string"/>
                                                    <xs:element name="hores" type="tipusHores"/>
                                                </xs:sequence>
                                                <xs:attribute name="codi" type="tipusCodiAssignatura" use="required"/>
                                            </xs:complexType>
                                        </xs:element>
                                    </xs:sequence>
                                </xs:complexType>
                            </xs:element>
                            <xs:element name="alumnes">
                                <xs:complexType>
                                    <xs:sequence>
                                        <xs:element name="alumne" maxOccurs="unbounded">
                                            <xs:complexType>
                                                <xs:sequence>
                                                    <xs:element name="nom" type="xs:string"/>
                                                    <xs:element name="cognoms" type="xs:string"/>
                                                    <xs:element name="data-naixement" type="xs:date"/>
                                                    <xs:element name="email" type="tipusEmail"/>
                                                </xs:sequence>
                                                <xs:attribute name="id" type="xs:ID" use="required"/>
                                            </xs:complexType>
                                        </xs:element>
                                    </xs:sequence>
                                </xs:complexType>
                            </xs:element>
                        </xs:sequence>
                        <xs:attribute name="id" type="xs:ID" use="required"/>
                        <xs:attribute name="nom" type="xs:string" use="required"/>
                    </xs:complexType>
                </xs:element>
            </xs:sequence>
        </xs:complexType>
    </xs:element>
    
</xs:schema>
```

Podem vincular el document XSD al document XML de la següent forma:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<institut xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:noNamespaceSchemaLocation="institut.xsd">
    <nom>CIFP Francesc de Borja Moll</nom>
    [..]
</institut>
```

## DTD vs XSD

Quan usar cadascun? Usa DTD quan:

* Necessitis una validació senzilla.
* El document no requereixi tipus de dades estrictes.
* Hagis de mantenir compatibilitat amb sistemes antics.

I usa XSD quan:

* Necessitis validar tipus de dades (dates, números, patrons).
* Treballis amb espais de noms.
* Vulguis restriccions complexes.
* El document s'intercanviarà entre sistemes diversos.

La següent taula comparativa pot servir com a referència:

| Aspecte                   | DTD                | XSD                              |
|---------------------------|--------------------|----------------------------------|
| Corba d'aprenentatge      | Baixa              | Mitjana-alta                     |
| Validació de tipus        | Bàsica             | Molt detallada                   |
| Expressió de restriccions | Limitada           | Patrons, rangs, longituds...     |
| Reutilització             | Entitats           | Tipus i grups                    |
| Suport d'eines            | Universal          | Universal                        |
| Ús actual                 | Llegat, HTML/XHTML | Serveis web, intercanvi de dades |

## Resum

La validació és essencial per garantir la qualitat i consistència dels documents XML. Les DTD ofereixen una solució senzilla i àmpliament suportada, mentre que XSD proporciona un control molt més fi sobre l'estructura i els tipus de dades. En projectes moderns, XSD és l'opció preferida, però conèixer DTD continua sent important per treballar amb sistemes existents i entendre els fonaments de la validació XML.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Creació d'una DTD**

Crea una DTD per validar documents XML que representin una **carta de restaurant**. El [document XML ja està definit](/xml/validacio/carta-restaurant.xml); la teva tasca és escriure la DTD que el validi correctament.

Requisits de la DTD:

1. L'element `<carta>` ha de tenir els atributs `restaurant` (obligatori) i `data-actualitzacio` (opcional).
2. Una carta conté una o més seccions.
3. Cada `<seccio>` té un atribut `nom` obligatori i conté un o més plats.
4. Cada `<plat>` té un `id` únic (tipus ID), un atribut `vegetaria` amb valors `si` o `no` (per defecte `no`).
5. Un plat conté: `nom` (obligatori), `descripcio` (opcional), `preu` (obligatori) i `alergens` (obligatori, pot estar buit).
6. L'element `<preu>` té un atribut `moneda` amb valor fix `EUR`.
7. L'element `<alergens>` pot contenir zero o més elements `<alergen>`.

El fitxer a crear haurà de tenir el nom `carta-restaurant.dtd`.

Validació: Comprova que el document és ben format i vàlid amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Exercici 2

**Creació d'un XML Schema (XSD)**

Crea un XML Schema per validar documents XML que representin un **catàleg de productes** d'una botiga d'electrònica. A diferència de l'exercici anterior, aquí has de dissenyar tant l'XSD com un document XML d'exemple.

Requisits de l'esquema:

1. **Element arrel `<cataleg>`** amb atributs:
   * `botiga`: nom de la botiga (obligatori).
   * `actualitzat`: data d'actualització (tipus `xs:date`, obligatori).

2. **Categories de productes:** El catàleg conté una o més categories, cadascuna amb:
   * Atribut `id` (tipus ID, obligatori).
   * Atribut `nom` (obligatori).
   * Un o més productes.

3. **Productes:** Cada producte ha de tenir:
   * Atribut `sku` (codi únic, patró: 3 lletres majúscules + 4 dígits, ex: `TEL1234`).
   * Atribut `disponible` (booleà, per defecte `true`).
   * Element `nom` (string, obligatori).
   * Element `marca` (string, obligatori).
   * Element `preu` (decimal amb exactament 2 decimals, entre 0.01 i 99999.99).
   * Element `estoc` (enter, mínim 0).
   * Element `descripcio` (string, opcional, màxim 500 caràcters).
   * Element `garantia` (enter, opcional, en mesos, entre 1 i 60).

4. **Tipus personalitzats a definir:**
   * `tipusSKU`: patró `[A-Z]{3}[0-9]{4}`.
   * `tipusPreu`: decimal amb restriccions de rang.
   * `tipusDescripcio`: string amb longitud màxima.

El lliurament de l'exercici són dos fitxers:

1. Fitxer `cataleg.xsd` amb l'esquema complet.
2. Fitxer `cataleg.xml` amb almenys 2 categories i 3 productes per categoria.

Validació: Comprova que el document és ben format i vàlid amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Exercici 3

**De DTD a XSD**

Converteix la següent DTD a un XML Schema equivalent, aprofitant les capacitats addicionals d'XSD per millorar la validació.

```dtd
<!ELEMENT biblioteca (llibre+)>
<!ATTLIST biblioteca
    nom CDATA #REQUIRED
>

<!ELEMENT llibre (titol, autor+, any, genere, isbn, pagines?, disponible)>
<!ATTLIST llibre
    id ID #REQUIRED
>

<!ELEMENT titol (#PCDATA)>
<!ELEMENT autor (#PCDATA)>
<!ELEMENT any (#PCDATA)>
<!ELEMENT genere (#PCDATA)>
<!ELEMENT isbn (#PCDATA)>
<!ELEMENT pagines (#PCDATA)>
<!ELEMENT disponible (#PCDATA)>
```

Millores a incorporar amb XSD:

1. **`any`**: Tipus enter, entre 1450 (impremta de Gutenberg) i l'any actual.
2. **`genere`**: Enumeració amb valors: `Novel·la`, `Poesia`, `Assaig`, `Teatre`, `Ciència-ficció`, `Fantasia`, `Biografia`, `Història`.
3. **`isbn`**: Patró per ISBN-13 (13 dígits, pot incloure guions): `[0-9]{3}-?[0-9]{1,5}-?[0-9]{1,7}-?[0-9]{1,7}-?[0-9]`
4. **`pagines`**: Enter positiu, mínim 1, màxim 10000.
5. **`disponible`**: Booleà (`true`/`false`).

**Lliurament:**

1. Fitxer `biblioteca.xsd` amb l'esquema millorat.
2. Fitxer `biblioteca.xml` amb almenys 4 llibres de gèneres diferents.
3. Breu explicació (en comentaris XML o document apart) de les millores que aporta XSD respecte a la DTD original.

Validació: Comprova que el document és ben format i vàlid amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Eines de validació

Per validar amb DTD des de la línia de comandes:

```bash
# DTD referenciada dins el document XML
xmllint --valid --noout document.xml

# DTD externa específica
xmllint --dtdvalid esquema.dtd --noout document.xml
```

Per validar amb XSD des de la línia de comandes:

```bash
xmllint --schema esquema.xsd --noout document.xml
```

Per a validació online, [XML Validation](https://www.xmlvalidation.com/) suporta tant DTD com XSD, però també pots usar [Free Online XML Validator (XSD)](https://www.liquid-technologies.com/online-xsd-validator).
