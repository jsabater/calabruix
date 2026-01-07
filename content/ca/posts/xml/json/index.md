---
title: "Origen de JSON i comparativa amb XML"
date: 2026-01-03
lastmod: 2026-01-03
description: "Origen i evolució del format JSON. Comparativa detallada amb XML: sintaxi, tipus de dades, validació, rendiment i casos d'ús. Avantatges i limitacions de JSON."
summary: "Història de JSON, comparativa amb XML i anàlisi d'avantatges, limitacions i casos d'ús."
categories: ["ensenyament"]
tags: ["xml", "json"]
series: ["XML"]
series_order: 11
weight: 110
slug: comparativa-amb-json
---

A principis dels anys 2000, les aplicacions web van començar a necessitar comunicació asíncrona[^1] entre el navegador i el servidor. La tècnica AJAX (Asynchronous JavaScript and XML) permetia actualitzar parts d'una pàgina sense recarregar-la completament.

[^1]: Un mètode on el client i el servidor intercanvien dades sense que el client hagi d'esperar una resposta immediata, permetent actualitzacions dinàmiques en temps real i una millora de l'experiència d'usuari.

Tot i que AJAX incloïa "XML" al nom, els desenvolupadors van descobrir ràpidament que XML era massa pesat per a petits però freqüents intercanvis de dades. Calia un format més lleuger.

## JSON

[Douglas Crockford](https://en.wikipedia.org/wiki/Douglas_Crockford) va popularitzar [JSON](https://json.org/) cap al 2001-2002. No va inventar el format, sinó que va descobrir que la sintaxi literal d'objectes de JavaScript[^2] podia servir com a format d'intercanvi de dades.

[^2]: La notació literal d'objectes de JavaScript defineix, literalment (directament), tant l'estructura de l'objecte com els seus valors.

La idea era simple: si JavaScript ja sabia interpretar la notació literal d'objectes literals, per què no usar aquesta mateixa sintaxi per enviar dades?

```javascript
// Sintaxi literal d'un objecte JavaScript (1995)
var alumne = {
    nom: "Maria",
    edat: 19,
    actiu: true
};

// El mateix, com a cadena de text intercanviable
'{"nom": "Maria", "edat": 19, "actiu": true}'
```

### Estàndarització

**JSON** significa **JavaScript Object Notation**. Tot i el nom, JSON és independent de JavaScript i s'utilitza amb qualsevol llenguatge de programació.

L'any 2013 es va publicar l'estàndar ECMA-404, actualitzat el 2017. ECMA-404 és l'estàndard de l'organització ECMA International, la mateixa que estandarditza JavaScript (ECMAScript). És un document molt breu (~5 pàgines) que defineix exclusivament la sintaxi de JSON: què és un objecte, un array, una cadena, un número, etc. No diu res sobre com s'ha d'usar, processar o transmetre.

[RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259) és l'especificació de JSON que s'usa actualment. RFC 8259 (2017, substituint RFC 7159 de 2014 i RFC 4627 de 2006) és l'estàndard de l'IETF (Internet Engineering Task Force), l'organització que defineix protocols d'Internet. És més extens i pràctic: a més de la sintaxi, especifica aspectes d'interoperabilitat com:

* La codificació ha de ser UTF-8 quan s'intercanvia per xarxa (ECMA-404 permet UTF-8, UTF-16 i UTF-32).
* Recomana que les claus d'un objecte siguin úniques (ECMA-404 no ho menciona).
* Defineix el tipus MIME application/json.
* Adverteix sobre límits de precisió numèrica per a interoperabilitat.

RFC 8259 és la referència més útil. ECMA-404 existeix principalment per tenir una especificació formal i estable dins l'ecosistema ECMA/JavaScript.


### Sintaxi

JSON es basa en dues estructures:

1. **Objecte:** Col·lecció de parells clau-valor entre claus `{}`.
2. **Array:** Llista ordenada de valors entre claudàtors `[]`.

Exemple:

```json
{
    "clau": "valor",
    "altra_clau": 123
}

[1, 2, 3, "quatre", true]
```

JSON té exactament sis tipus de dades:

| Tipus   | Exemple                      | Descripció                       |
|---------|------------------------------|----------------------------------|
| String  | `"Hola món"`                 | Text entre cometes dobles        |
| Number  | `42`, `3.14`, `-17`, `2.5e10`| Enter o decimal                  |
| Boolean | `true`, `false`              | Valors lògics                    |
| Null    | `null`                       | Valor nul                        |
| Object  | `{"clau": "valor"}`          | Col·lecció de parells clau-valor |
| Array   | `[1, 2, 3]`                  | Llista ordenada                  |

Les regles sintàctiques de JSON són poques i senzilles:

* Les claus dels objectes **sempre** van entre cometes dobles (`"`).
* Les cadenes **sempre** usen cometes dobles (mai simples).
* No es permeten comes finals (trailing commas).
* No es permeten comentaris.
* Els números no poden tenir zeros a l'esquerra (excepte decimals com `0.5`).

Exemple de JSON vàlid:

```json
{
    "nom": "Maria",
    "edat": 19,
    "notes": [7.5, 8.0, 9.5],
    "actiu": true,
    "tutor": null
}
```

Exemple de JSON invàlid:

```json
{
    nom: "Maria",           // Clau sense cometes
    "cognom": 'García',     // Cometes simples
    "edat": 019,            // Zero a l'esquerra
    "curs": "ASIX",         // Coma final
}
```

Exemple complet de document JSON:

```json
{
    "institut": {
        "nom": "CIFP Francesc de Borja Moll",
        "codi": "08012345",
        "anyAcademic": "2025-26",
        "curs": {
            "id": "ASIX",
            "nom": "Administració de Sistemes Informàtics en Xarxa",
            "assignatures": [
                {
                    "codi": "LLM",
                    "nom": "Llenguatges de Marques",
                    "hores": 128
                },
                {
                    "codi": "FP",
                    "nom": "Fonaments de Programació",
                    "hores": 66
                }
            ],
            "alumnes": [
                {
                    "id": "A001",
                    "nom": "Maria",
                    "cognoms": "García López",
                    "email": "maria.garcia@cifpmoll.eu"
                },
                {
                    "id": "A002",
                    "nom": "Pere",
                    "cognoms": "Martínez Soler",
                    "email": "pere.martinez@cifpmoll.eu"
                }
            ]
        }
    }
}
```

## Comparativa XML/JSON

Per entendre quan convé usar cada format, cal comparar-los en diversos aspectes. Veurem les mateixes dades representades en ambdós formats i analitzarem les diferències pràctiques.

### Sintaxi

Comencem amb un exemple senzill: les dades d'un alumne amb identificador, nom, cognoms, edat, estat i notes.

**XML:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<alumne id="A001">
    <nom>Maria</nom>
    <cognoms>García López</cognoms>
    <edat>19</edat>
    <actiu>true</actiu>
    <notes>
        <nota>7.5</nota>
        <nota>8.0</nota>
    </notes>
</alumne>
```

**JSON:**
```json
{
    "id": "A001",
    "nom": "Maria",
    "cognoms": "García López",
    "edat": 19,
    "actiu": true,
    "notes": [7.5, 8.0]
}
```

A primera vista, la diferència més evident és la **verbositat**: XML repeteix el nom de cada element a l'etiqueta d'obertura i de tancament (`<nom>...</nom>`), mentre que JSON només l'escriu un cop (`"nom": ...`). En aquest exemple petit, XML ocupa unes 14 línies i JSON només 9, però la diferència es multiplica en documents grans.

Així mateix, fixa't que, en XML, l'identificador `A001` és un **atribut** (dins de l'etiqueta d'obertura), mentre que en JSON és una **propietat** més, al mateix nivell que `nom` o `cognoms`. XML distingeix entre atributs i elements, mentre que JSON ho tracta tot com a propietats.

### Característiques

La taula següent resumeix les diferències principals entre ambdós formats:

| Característica             | XML                   | JSON                              |
|----------------------------|-----------------------|-----------------------------------|
| **Verbositat**             | Alta                  | Baixa                             |
| **Llegibilitat humana**    | Bona                  | Bona                              |
| **Tipus de dades nadius**  | No (tot és text)      | Sí (6 tipus)                      |
| **Atributs**               | Sí                    | No                                |
| **Comentaris**             | Sí                    | No                                |
| **Namespaces**             | Sí                    | No                                |
| **Ordre dels elements**    | Significatiu          | Arrays: sí, Objectes: no garantit |
| **Validació d'esquemes**   | DTD, XSD              | JSON Schema                       |
| **Transformacions**        | XSLT                  | Codi programàtic                  |
| **Suport JavaScript**      | Requereix parseig DOM | Nadiu (`JSON.parse`)              |
| **Metadades**              | Atributs i PIs        | Cal incloure com a camps          |

Algunes d'aquestes diferències mereixen explicació addicional:

* **Tipus de dades nadius:** En JSON, `19` és un número i `true` és un booleà. En XML, tot és text; si necessites saber que `<edat>19</edat>` és un número, cal validar amb XSD o fer la conversió al codi.

* **Ordre dels elements:** En XML, l'ordre dels fills pot ser significatiu segons l'esquema. En JSON, l'ordre de les claus d'un objecte no està garantit (l'especificació no n'obliga), tot i que la majoria de parsers el preserven. Els arrays sí que mantenen l'ordre.

* **Suport JavaScript:** JSON és un subconjunt de la sintaxi de JavaScript, per això `JSON.parse()` és natiu i molt ràpid. Per llegir XML en JavaScript cal usar el DOM o biblioteques externes.

### Mida i rendiment

La verbositat té un cost mesurable. JSON és típicament un 30-50% més petit i es parseja 2-3 vegades més ràpid. Aquesta diferència pot semblar irrellevant per a un sol document, però es torna significativa quan:

* Una API rep milers de peticions per segon (manco bytes = manco ample de banda i cost).
* Una aplicació mòbil descarrega dades amb connexió lenta.
* Un sistema processa milions de documents diaris.

Per això JSON domina en APIs web, mentre que XML es manté en contextos on la mida no és la prioritat principal.

### Tipus de dades

Aquesta diferència és fonamental i sovint passa desapercebuda.

**XML:** Tot el contingut és text. El parser XML no sap si `19` és un número o un codi postal.

```xml
<edat>19</edat>          <!-- És text "19" -->
<actiu>true</actiu>      <!-- És text "true" -->
<preu>29.99</preu>       <!-- És text "29.99" -->
```

Si el teu codi necessita fer operacions matemàtiques amb l'edat, hauràs de convertir el text a número. Si l'esquema XSD defineix que `<edat>` és un `xs:integer`, el validador comprovarà que el text representa un enter, però el valor dins del document segueix sent text.

**JSON:** Els tipus són nadius i el parser els reconeix automàticament.

```json
{
    "edat": 19,
    "actiu": true,
    "preu": 29.99
}
```

Quan un parser JSON llegeix aquest document, ja sap que `edat` és un número (pots fer `dades.edat + 1` directament), `actiu` és un booleà (pots usar-lo en un `if`) i `preu` és un número decimal.

JSON reconeix sis tipus de dades: `string`, `number`, `boolean`, `null`, `object` i `array`. XML, en canvi, només té un tipus: text (o més tècnicament, `PCDATA`). Aquesta simplicitat d'XML és alhora una fortalesa (flexibilitat total) i una limitació (cal més feina per processar les dades).

### Estructures de dades

Una diferència pràctica important és com cada format representa **llistes o col·leccions**. En **XML** no hi ha una sintaxi específica. Es representen repetint elements amb el mateix nom. Això pot generar ambigüitats. Exemple:

```xml
<notes>
    <nota>7.5</nota>
    <nota>8.0</nota>
</notes>
```

El problema: si només hi ha una nota, el parser no sap si és un element individual o una llista amb un sol element. Els processadors XML requereixen configuració específica per gestionar aquest cas correctament.

En canvi, **JSON** té una **sintaxi explícita i inequívoca** amb claudàtors `[]`.

```json
{
    "notes": [7.5, 8.0]
}
```

No hi ha ambigüitat: `notes` és sempre un array, encara que tengui un sol element (`"notes": [7.5]`) o estigui buit (`"notes": []`). Qualsevol parser JSON ho interpreta igual.

Una altra diferència pràctica important és com cada format representa els **objectes buits i els valors nuls**. En **XML** no hi ha manera estàndard de representar un element buit o nul. Es pot usar `<element/>`, `<element></element>` o, simplement, ometre l'element. Cada aplicació ho interpreta diferent.

En canvi, **JSON** té un valor explícit `null` i els objectes buits tenen sintaxi clara.

```json
{
    "tutor": null,
    "assignatures": [],
    "metadades": {}
}
```

### Metadades i atributs

En XML, hi ha una distinció arquitectònica entre el **contingut** (elements) i la **informació sobre el contingut** (atributs). Això permet separar les dades principals de les metadades.

```xml
<document versio="1.2" autor="jaume" creat="2025-03-15">
    <titol>Manual de l'usuari</titol>
    <contingut>Lorem ipsum...</contingut>
</document>
```

Aquí és clar que `versio`, `autor` i `creat` són metadades del document, mentre que `titol` i `contingut` són les dades principals. Aquesta distinció facilita el processament: un programa pot ignorar els atributs si només vol el contingut, o llegir només els atributs per a un índex ràpid.

En canvi, amb JSON no existeix el concepte d'atribut, sinó que tot són propietats al mateix nivell.

```json
{
    "versio": "1.2",
    "autor": "jaume",
    "creat": "2025-03-15",
    "titol": "Manual de l'usuari",
    "contingut": "Lorem ipsum..."
}
```

Per distingir metadades de dades, cal usar convencions (com prefixar amb `_` o `@`) o estructurar el document de manera diferent:

```json
{
    "metadades": {
        "versio": "1.2",
        "autor": "jaume",
        "creat": "2025-03-15"
    },
    "document": {
        "titol": "Manual de l'usuari",
        "contingut": "Lorem ipsum..."
    }
}
```

Aquesta segona opció és més clara, però afegeix un nivell d'imbricació i és responsabilitat del desenvolupador mantenir la convenció. En XML, la distinció és part del llenguatge.

## Avantatges de JSON

Resum dels avantatges de JSON, ja esmentats en anteriors seccions:

1. Llegibilitat i senzillesa. La sintaxi és mínima i fàcil d'aprendre. En pocs minuts es pot entendre tot el format.
2. Mida reduïda. Menys caràcters per representar les mateixes dades, estalviant ample de banda.
3. Parseig ràpid. Els parsers JSON són molt més ràpids que els XML, especialment en JavaScript.
4. Nadiu per a JavaScript.
   ```javascript
   // Parseig directe sense biblioteques externes
   const dades = JSON.parse(jsonString);
   console.log(dades.alumne.nom);
   
   // Serialització igualment senzilla
   const json = JSON.stringify(objecte);
   ```
5. Tipus de dades. Números, booleans i nulls es representen com a tals, no com a text.
6. Suport universal modern. Tots els llenguatges moderns tenen suport natiu o biblioteques madures per a JSON.
7. Ideal per a APIs REST. JSON s'ha convertit en l'estàndard de facto per a APIs web.
   ```http
   GET /api/alumnes/A001
   Accept: application/json
   
   HTTP/1.1 200 OK
   Content-Type: application/json
   
   {"id": "A001", "nom": "Maria", "cognoms": "García López"}
   ```

## Limitacions de JSON

Resum dels desavantatges de JSON, ja esmentats en anteriors seccions:

1. Sense comentaris. No hi ha manera estàndard d'afegir comentaris, cosa problemàtica per a fitxers de configuració.
   ```json
   {
       "port": 8080
       // Això NO és vàlid en JSON estàndard
   }
   ```
   Algunes eines accepten extensions com JSON5 o JSONC, però no són estàndard.
2. Sense esquema integrat. A diferència de XML amb DTD/XSD, JSON no té validació d'esquemes integrada. JSON Schema existeix però és manco madur.
3. Sense namespaces. No hi ha mecanisme per combinar vocabularis diferents sense col·lisions.
4. Sense transformacions estàndard. No existeix un equivalent a XSLT per a JSON. Cal escriure codi programàtic.
5. Claus duplicades ambigües. L'especificació no defineix clarament què passa amb claus duplicades:
   ```json
   {
       "nom": "Maria",
       "nom": "Pere"
   }
   ```
   Diferents parsers es comporten de manera diferent (alguns agafen el primer, altres l'últim).
6. Sense atributs. No hi ha distinció entre dades i metadades; tot són propietats.
7. Ordre no garantit en objectes. L'especificació no garanteix l'ordre de les claus en un objecte. Alguns parsers el preserven, altres no.
8. Limitacions numèriques:
   * No distingeix entre enters i decimals.
   * Números molt grans poden perdre precisió (límit de JavaScript: 2^53).
   * No suporta valors especials com `Infinity` o `NaN`.
   ```json
   {
       "idGran": 9007199254740993
   }
   // En JavaScript, això es pot llegir incorrectament
   ```
9. Sense suport per a dates. No hi ha tipus de data nadiu. Cal usar strings amb format convencional:
   ```json
   {
       "dataCreacio": "2025-03-15T10:30:00Z"
   }
   ```
10. Només UTF-8. JSON està limitat a codificació UTF-8 (tot i que RFC 8259 permet UTF-16 i UTF-32, rarament s'usen).

## Similituds XML/JSON

Resum de les similituds entre XML i JSON, ja esmentades en anteriors seccions:

* **Independents de plataforma:** Text pla llegible en qualsevol sistema.
* **Jeràrquics:** Suporten estructures imbricades pare-fill.
* **Autodescriptius:** Les claus/etiquetes indiquen el significat.
* **Àmpliament suportats:** Biblioteques disponibles per a tots els llenguatges.
* **Interoperabilitat:** Dissenyats per intercanvi de dades entre sistemes.
* **Extensibles:** Es poden afegir nous camps sense trencar compatibilitat.

## Quan usar cada format

Tria JSON quan:

* Desenvolupis APIs web o serveis REST.
* El client sigui una aplicació JavaScript/TypeScript.
* Necessitis rendiment i mida reduïda.
* Les dades siguin relativament simples.
* No calgui validació estricta d'esquemes.
* Treballis amb aplicacions mòbils.

Tria XML quan:

* Necessitis validació robusta (XSD).
* El document combini múltiples vocabularis (namespaces).
* Calguin transformacions complexes (XSLT).
* Treballis amb sistemes legacy o empresarials.
* L'estàndard del sector ho requereixi.
* El document necessiti metadades (atributs).
* Calgui signatura digital estàndard.

Qualsevol és vàlid per a:

* Fitxers de configuració (XML, JSON, YAML, TOML).
* Emmagatzematge de dades estructurades.
* Intercanvi entre sistemes moderns.

## Resum

JSON va néixer com una alternativa lleugera a XML per a aplicacions web. La seva senzillesa i integració nativa amb JavaScript l'han convertit en l'estàndard per a APIs modernes. No obstant això, XML continua sent essencial en àmbits que requereixen validació estricta, transformacions complexes o interoperabilitat amb sistemes empresarials.

No es tracta de formats rivals sinó complementaris: cada un excel·leix en contextos diferents. Un bon desenvolupador ha de dominar ambdós per triar l'adequat a cada situació.
