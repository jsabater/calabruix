---
title: "Atributs reservats XML"
date: 2026-01-03
lastmod: 2026-01-03
description: "Atributs reservats de l'especificació XML per a l'idioma, per al tractament d'espais en blanc i per a URIs base. Propòsit i exemples pràctics."
summary: "Atributs especials d'idioma, espais en blanc i URIs base: propòsit i exemples pràctics."
categories: ["ensenyament"]
tags: ["xml", "sgml"]
series: ["XML"]
series_order: 3
weight: 30
slug: attributs-reservats
---

L'especificació XML defineix un conjunt d'atributs especials amb el prefix `xml:` que tenen un significat estàndard per a qualsevol parser. Aquests atributs no cal declarar-los en un DTD o esquema perquè formen part de l'espai de noms XML reservat.

Els tres principals atributs reservats són:

| Atribut     | Propòsit                                     |
|-------------|----------------------------------------------|
| `xml:lang`  | Indica l'idioma del contingut                |
| `xml:space` | Controla el tractament dels espais en blanc  |
| `xml:base`  | Defineix la URI base per a enllaços relatius |

## xml:lang

L'atribut `xml:lang` especifica l'idioma del contingut d'un element i dels seus descendents. El valor segueix l'estàndard [BCP 47](https://en.wikipedia.org/wiki/IETF_language_tag) (Best Current Practice 47), que inclou els [codis ISO 639](https://en.wikipedia.org/wiki/ISO_639).

La sintaxi és la següent:

```xml
<element xml:lang="codi-idioma">contingut</element>
```

I aquests són alguns exemples de codis i els seus idiomes equivalents:

| Codi    | Idioma             |
|---------|--------------------|
| `ca`    | Català             |
| `es`    | Castellà           |
| `en`    | Anglès             |
| `en-GB` | Anglès britànic    |
| `en-US` | Anglès americà     |
| `de`    | Alemany            |
| `fr`    | Francès            |
| `pt-BR` | Portuguès brasiler |

A continuació es presenta un document XML d'exemple, on es fa ús de diversos idiomes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manual xml:lang="ca">
    <titol>Guia d'Instal·lació</titol>
    <seccio>
        <paragraf>Seguiu aquests passos per instal·lar el programari.</paragraf>
        
        <!-- Cita en anglès dins d'un document en català -->
        <cita xml:lang="en">The installation was successful.</cita>
        
        <paragraf>El missatge anterior confirma que tot ha anat bé.</paragraf>
    </seccio>
    
    <!-- Secció traduïda al castellà -->
    <seccio xml:lang="es">
        <titol>Guía de Instalación</titol>
        <paragraf>Siga estos pasos para instalar el software.</paragraf>
    </seccio>
</manual>
```

L'atribut `xml:lang` s'hereta als elements descendents fins que es redefineix:

```xml
<!-- Tot el document en català -->
<document xml:lang="ca">
    <capitol>

        <!-- Hereta xml:lang="ca" -->
        <titol>Capítol 1</titol>

        <!-- Canvi a anglès -->
        <text xml:lang="en">

            <!-- Hereta xml:lang="en" -->
            <paragraf>Hello</paragraf>
        </text>

        <!-- Torna a heretar xml:lang="ca" -->
        <text>Text en català</text>
    </capitol>
</document>
```

Utilitats d'aquest atribut reservat:

* Processadors de text: Apliquen regles de guionatge i ortografia correctes.
* Sintetitzadors de veu: Pronuncien el text amb l'accent adequat.
* Cercadors: Indexen el contingut segons l'idioma.
* CSS: Permet estilitzar segons l'idioma amb el selector `:lang()`.

## xml:space

L'atribut `xml:space` indica com s'han de tractar els espais en blanc (espais, tabuladors, salts de línia) dins d'un element.

Valors possibles:

| Valor      | Comportament                                      |
|------------|---------------------------------------------------|
| `default`  | L'aplicació decideix com tractar els espais       |
| `preserve` | Es preserven tots els espais en blanc tal com són |

A continuació es presenta un document XML d'exemple:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<document>
    <!-- Espais tractats segons el comportament per defecte -->
    <paragraf>
        Aquest   text   té   espais   múltiples.
    </paragraf>
    
    <!-- Espais preservats literalment -->
    <codi xml:space="preserve">
def hola():
    print("Hola món")
    if True:
        return 42
    </codi>
</document>
```

Amb `xml:space="preserve"`, la indentació del codi Python es manté exactament com està escrita, incloent-hi els espais al principi de cada línia.

Quant a l'herència, igual que `xml:lang`, l'atribut `xml:space` s'hereta als elements descendents:

```xml
<pre xml:space="preserve">
    <linia>Primera línia amb    espais</linia>
    
    <!-- També preserva espais -->
    <linia>Segona línia</linia>
</pre>
```

Casos d'ús típics d'aquest atribut reservat:

* Codi font: Preservar la indentació és essencial.
* Poesia: Els espais i salts de línia formen part del format.
* Art ASCII: Els espais són part del dibuix.
* Dades tabulars en text pla: L'alineació depèn dels espais.

Cal tenir en compte que l'atribut `xml:space` és una **indicació** per a l'aplicació que processa l'XML, no una ordre obligatòria. Alguns processadors poden ignorar-lo. Per garantir la preservació d'espais, sovint es combina amb seccions `CDATA` o es processa amb eines que respecten aquest atribut.

## xml:base

L'atribut `xml:base` defineix una [*](URI) base per resoldre les referències relatives dins d'un element i els seus descendents. Està definit a l'especificació *XML Base* ([RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986)).

La sintaxi és la següent:

```xml
<element xml:base="uri-base">
    <!-- Les URIs relatives es resolen respecte a uri-base -->
</element>
```

A continuació es presenta un document XML d'exemple:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<recursos xml:base="https://cifpmoll.eu/asix/">

    <!-- https://cifpmoll.eu/asix/apunts/tema1.pdf -->
    <document href="apunts/tema1.pdf"/>

    <!-- https://cifpmoll.eu/asix/apunts/tema2.pdf -->
    <document href="apunts/tema2.pdf"/>
    
    <seccio xml:base="exercicis/">
        <!-- https://cifpmoll.eu/asix/exercicis/ex01.xml -->
        <fitxer href="ex01.xml"/>

        <!-- https://cifpmoll.eu/asix/exercicis/ex02.xml -->
        <fitxer href="ex02.xml"/>
    </seccio>
    
    <!-- URI absoluta, ignora xml:base -->
    <extern href="https://w3.org/XML/"/>
</recursos>
```

Les regles de resolució segueixen l'estàndard [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986):

| URI base                    | URI relativa         | URI resultant                         |
|-----------------------------|----------------------|---------------------------------------|
| `https://exemple.com/docs/` | `fitxer.xml`         | `https://exemple.com/docs/fitxer.xml` |
| `https://exemple.com/docs/` | `../img/foto.png`    | `https://exemple.com/img/foto.png`    |
| `https://exemple.com/docs/` | `/arrel.xml`         | `https://exemple.com/arrel.xml`       |
| `https://exemple.com/docs/` | `https://altre.com/` | `https://altre.com/`                  |

L'atribut `xml:base` s'acumula en elements imbricats:

```xml
<a xml:base="https://exemple.com/">
    <b xml:base="docs/">
        <c xml:base="2025/">
            <enllaç href="gener.html"/>
            <!-- Resultat: https://exemple.com/docs/2025/gener.html -->
        </c>
    </b>
</a>
```

Casos d'ús típics d'aquest atribut reservat:

* Documents amb molts enllaços: Evita repetir el prefix comú.
* Contingut reubicable: Canviant només `xml:base`, tots els enllaços s'actualitzen.
* Fragments XML inclosos: Cada fragment pot definir la seva base.
* `XInclude`[^1] i `XLink`[^2]: dues especificacions que extenen les capacitats natives d'XML utilitzen `xml:base` per resoldre referències.

[^1]: `XInclude` allows including external XML content into a document.
[^2]: `XLink` provides a standard way to create hyperlinks in XML documents

## Aplicació a l'exemple

Podem enriquir [el document XML de l'institut]({{< relref "/posts/xml/exemple/" >}}) amb aquests atributs reservats:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<institut xml:lang="ca" xml:base="https://cifpmoll.eu/asix/">
    <nom>CIFP Francesc de Borja Moll</nom>
    <codi>08012345</codi>
    <any-academic>2025-26</any-academic>
    
    <curs id="ASIX" nom="Administració de Sistemes Informàtics en Xarxa">
        <assignatures>
            <assignatura codi="LLM">
                <nom>Llenguatges de Marques i Sistemes de Gestió d'Informació</nom>
                <nom xml:lang="es">Lenguajes de Marcas y Sistemas de Gestión de Información</nom>
                <nom xml:lang="en">Markup Languages and Information Management Systems</nom>
                <hores>128</hores>
                <material href="materials/llm/temari.pdf"/>
            </assignatura>
            <!-- ... -->
        </assignatures>
        
        <alumnes>
            <alumne id="A001">
                <nom>Maria</nom>
                <cognoms>García López</cognoms>
                <bio xml:space="preserve">Estudiant de segon any.
Interessada en:
    - Ciberseguretat
    - Administració de xarxes
    - Cloud computing</bio>
            </alumne>
            <!-- ... -->
        </alumnes>
    </curs>
</institut>
```

## Resum

| Atribut     | Funció                  | Heretable       | Valors                |
|-------------|-------------------------|:---------------:|-----------------------|
| `xml:lang`  | Idioma del contingut    | Sí              | Codis BCP 47          |
| `xml:space` | Tractament d'espais     | Sí              | `default`, `preserve` |
| `xml:base`  | URI base per a enllaços | Sí (acumulatiu) | Qualsevol URI vàlida  |

Aquests atributs són opcionals però molt útils per crear documents XML més expressius i fàcils de processar correctament per diferents aplicacions.
