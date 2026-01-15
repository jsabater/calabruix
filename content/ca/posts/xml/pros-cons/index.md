---
title: "Pros i contres de l'XML"
date: 2026-01-03
lastmod: 2026-01-03
description: "Anàlisi equilibrada dels avantatges i desavantatges de l'XML. Punts forts com la validació i extensibilitat, i limitacions com la verbositat i el rendiment."
summary: "Avantatges i limitacions: quan és la millor opció i quan convé considerar alternatives."
categories: ["ensenyament"]
tags: ["xml"]
series: ["XML"]
series_order: 10
weight: 100
slug: pros-contres
---

XML va néixer el 1998 com una simplificació d'[*](SGML), amb l'objectiu de ser un format universal per a l'intercanvi de dades estructurades. Durant els anys 2000, es va convertir en l'estàndard dominant: configuracions d'aplicacions, serveis web (SOAP), documents ofimàtics, feeds RSS... tot era XML. L'ecosistema que el rodejava (DTD, XSD, XSLT, XPath, XQuery) oferia solucions per a qualsevol necessitat.

No obstant això, l'auge de les aplicacions web i el desenvolupament amb JavaScript van fer emergir alternatives més lleugeres. JSON va aparèixer el 2002 com un format nadiu per a JavaScript, molt més concís. Més tard, YAML (2001, popularitzat cap al 2010) es va adoptar per a fitxers de configuració llegibles. TOML (2013) va oferir una sintaxi encara més simple per a configuracions. Protocol Buffers (Google, 2008) i MessagePack van prioritzar l'eficiència binària sobre la llegibilitat.

Avui, XML ja no és l'opció per defecte per a tot, però tampoc ha desaparegut. Continua sent essencial en àmbits on les seves fortaleses (validació, namespaces, transformacions) són crítiques. La qüestió no és si XML és "millor" o "pitjor" que les alternatives, sinó entendre quan és l'eina adequada. Per això, cal conèixer tant els seus avantatges com les seves limitacions.

## Avantatges

Els principals avantatges d'XML són els següents.

### Autodescriptiu i llegible

L'XML utilitza etiquetes amb noms significatius que descriuen el contingut. Qualsevol persona pot entendre l'estructura sense documentació addicional.

```xml
<alumne>
    <nom>Maria</nom>
    <cognoms>Llompart Canyellas</cognoms>
    <email>maria.llompart@cifpfbmoll.eu</email>
</alumne>
```

Si ho comparam amb un format binari o un CSV sense capçaleres, la diferència en claredat és evident.

### Validació robusta

Els esquemes DTD i XSD permeten definir exactament quina estructura i quins tipus de dades són vàlids. Això garanteix la integritat de les dades abans de processar-les. Per exemple, XSD pot validar que `email` tengui un format correcte, que `data-naixement` sigui una data vàlida o que `hores` sigui un enter entre 1 i 300.

Cap altre format de dades té un sistema de validació tan madur i potent.

### Extensibilitat

XML permet crear vocabularis personalitzats per a qualsevol domini. Les etiquetes no estan predefinides, sinó que cada aplicació defineix les que necessita.

```xml
<!-- Vocabulari per a xarxes -->
<xarxa>
    <switch id="SW01">
        <port numero="1" vlan="10" velocitat="1Gbps"/>
    </switch>
</xarxa>

<!-- Vocabulari per a receptes -->
<recepta>
    <ingredient quantitat="200" unitat="g">Farina</ingredient>
</recepta>
```

### Namespaces

Els espais de noms permeten combinar vocabularis diferents en un sol document sense col·lisions, evitant conflictes.

```xml
<document xmlns:xarxa="http://exemple.com/xarxa"
          xmlns:inv="http://exemple.com/inventari">
    <xarxa:switch>
        <inv:preu>450.00</inv:preu>
    </xarxa:switch>
</document>
```

### Transformacions potents

XSLT permet convertir XML a qualsevol format de sortida: HTML, PDF, text, altres XML, etc. Això separa completament les dades de la presentació.

### Suport universal

Totes les plataformes tenen parsers XML. Tots els llenguatges de programació tenen biblioteques XML. Les eines de validació i transformació són madures i estables. L'estàndard té més de 25 anys i no canviarà.

A més, l'ecosistema XML inclou estàndars complementaris madurs i ben definits per a cada necessitat.

* `XPath`: Selecció de nodes
* `XSLT`: Transformacions
* `XQuery`: Consultes complexes
* `XSD`: Validació d'esquemes
* `XLink`: Enllaços
* `XPointer`: Referències a fragments

### Multiplataforma

Un document XML creat en Windows es pot llegir en Linux, MacOS o qualsevol altre sistema. És text pla amb codificació estàndard (UTF-8), independent de la plataforma.

### Suport per a metadades

Els atributs permeten afegir metadades sense afectar l'estructura principal del document.

```xml
<document creat="2025-03-15" autor="jaume" versio="1.2">
    <contingut>[..]</contingut>
</document>
```

### Estructura jeràrquica

L'XML representa, de manera natural, dades amb relacions pare-fill, cosa molt comuna en el món real.

```xml
<empresa>
    <departament>
        <empleat>
            <projecte>[..]</projecte>
        </empleat>
    </departament>
</empresa>
```

## Desavantatges

Però XML també compta amb un seguit important de desavantatges.

### Verbositat

L'XML és molt més llarg que altres formats per representar les mateixes dades.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<alumnes>
    <alumne>
        <nom>Maria</nom>
        <edat>19</edat>
    </alumne>
</alumnes>
```

Sense tenir en compte tabuladors o espais, aquest document XML ocupa 135 caràcters, mentre que el seu equivalent en JSON només 42:

```json
{
    "alumnes": [
        {"nom": "Maria", "edat": 19}
    ]
}
```

Aquesta verbositat implica:

* Més ample de banda en transmissions.
* Més espai d'emmagatzematge.
* Més temps de parseig.

### Corba d'aprenentatge

A banda d'aprendre la seva sintaxi, per a dominar l'ecosistema XML cal aprendre múltiples tecnologies: DTD, XSD (molt més complex que DTD), XPath, XSLT i namespaces. La corba d'aprenentatge és considerablement complexa, especialment si la comparam amb la de JSON.

### Rendiment de parseig

Parsejar XML és més lent i consumeix més memòria que formats més simples. El parser ha de:

* Validar la sintaxi.
* Construir l'arbre DOM (si s'usa DOM).
* Gestionar namespaces.
* Resoldre entitats.

En terme mig, el parseig d'un document XML serà entre 3 i 5 vegades més lent que el seu equivalent en JSON.

### No té tipus de dades

XML no té tipus de dades nadius. Tot és text i cal convertir manualment o usar XSD.

```xml
<!-- Això és un número o un text? -->
<valor>42</valor>

<!-- I això? -->
<actiu>true</actiu>
```

JSON, en canvi, té tipus nadius:

```json
{
    "valor": 42, "actiu": true
}
```

### Atributs vs elements

No hi ha regles clares sobre quan usar atributs o elements. Aquesta ambigüitat pot provocar inconsistències.

```xml
<!-- Enfocament 1 -->
<alumne id="A001" nom="Maria" edat="19"/>

<!-- Enfocament 2 -->
<alumne>
    <id>A001</id>
    <nom>Maria</nom>
    <edat>19</edat>
</alumne>

<!-- Enfocament mixt -->
<alumne id="A001">
    <nom>Maria</nom>
    <edat>19</edat>
</alumne>
```

Les tres opcions són vàlides, però la inconsistència dificulta el processament.

### Espais en blanc

El tractament d'espais en blanc i comentaris pot ser problemàtic. Diferents parsers poden comportar-se de manera diferent. En el següent exemple, els espais i els salts de línia es preserven depenent del parser:

```xml
<element>
    Text amb espais
</element>
```

### Ordre dels elements

En XML, l'ordre dels elements pot ser significatiu segons l'esquema, cosa que complica alguns processaments. El següent document, si l'esquema defineix seqüència, podria ser invàlid, car el cognom hauria d'anar després del nom:

```xml
<alumne>
    <cognoms>García</cognoms>
    <nom>Maria</nom>
</alumne>
```

### Namespaces complexos

Tot i ser potents, els namespaces afegeixen complexitat considerable (el document es torna difícil de llegir):

```xml
<emp:empresa xmlns:emp="http://exemple.com/empresa"
             xmlns:rh="http://exemple.com/rrhh"
             xmlns:fin="http://exemple.com/finances"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
</emp:empresa>
```

### XSD massa complex

XML Schema és extremadament potent però també molt complex. Definir un esquema complet pot requerir més línies que el propi document.

## Quan triar XML

XML és una excel·lent opció quan:

* Necessitis validació estricta de l'estructura i tipus de dades.
* Hagis de combinar múltiples vocabularis (namespaces).
* El document requereixi transformacions complexes (XSLT).
* Treballis amb sistemes empresarials o legacy.
* L'estàndard del sector ho requereixi (factures, sanitat, finances).
* El document hagi de ser llegible i autoexplicatiu a llarg termini.
* Necessitis signatura digital o xifratge estàndard (XML Signature, XML Encryption).

Però considera alternatives quan:

* Desenvolupis APIs web modernes (JSON).
* El rendiment sigui crític (JSON, Protocol Buffers, MessagePack).
* Treballis principalment amb JavaScript (JSON).
* Les dades siguin simples i planes (CSV, JSON).
* Necessitis fitxers de configuració llegibles (YAML, TOML).

## Resum

L'XML no és millor ni pitjor que altres formats; és una eina amb els seus punts forts i febles. La clau és triar el format adequat per a cada situació, i l'XML continua sent l'opció òptima en molts escenaris empresarials i d'intercanvi de dades estructurades.
