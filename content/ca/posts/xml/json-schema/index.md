---
title: "Equivalències entre JSON i XML i JSON Schema"
date: 2026-01-03
lastmod: 2026-01-09
description: "Conversió d'exemples XML a JSON. Introducció a JSON Schema per validar documents JSON. Eines online i de terminal Linux per a fer feina amb JSON."
summary: "Conversió XML a JSON, validació amb JSON Schema i eines de feina de terminal Linux i enn línia."
categories: ["ensenyament"]
tags: ["xml", "json", "schema"]
series: ["XML"]
series_order: 12
weight: 120
slug: json-schema
---

Convertir un document XML a JSON no és un procés mecànic amb una única solució correcta. Ambdós formats tenen estructures i filosofies diferents, i les decisions de conversió afecten com de fàcil serà treballar amb les dades resultants. No existeix un estàndard que defineixi com fer aquesta conversió, sinó que cada desenvolupador o eina pot prendre decisions diferents.

Els principals reptes de la conversió són:

* Què fer amb els atributs XML (que no existeixen en JSON).
* Com representar elements repetits (que en JSON són arrays).
* Com adaptar els noms d'elements a les convencions de JSON.

## Exemple de l'institut

A continuació, convertirem [l'exemple de l'institut](/xml/exemple/institut.xml) que hem usat al llarg de la sèrie, explicant les decisions preses i per què. Per contextualitzar, aquest és un extracte de l'XML original:

```xml
<?xml version="1.0" encoding="UTF-8"?>
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
                <email>maria.garcia@cifpmoll.eu</email>
            </alumne>
            <alumne id="A002">
                <nom>Pere</nom>
                <cognoms>Martínez Soler</cognoms>
                <data-naixement>2004-07-22</data-naixement>
                <email>pere.martinez@cifpmoll.eu</email>
            </alumne>
            [..]
        </alumnes>
    </curs>
</institut>
```

El seu JSON equivalent podria ser el següent:

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
                    "nom": "Llenguatges de Marques i Sistemes de Gestió d'Informació",
                    "hores": 128
                },
                [..]
            ],
            "alumnes": [
                {
                    "id": "A001",
                    "nom": "Maria",
                    "cognoms": "García López",
                    "dataNaixement": "2005-03-15",
                    "email": "maria.garcia@cifpmoll.eu"
                },
                    "id": "A002",
                    "nom": "Pere",
                    "cognoms": "Martínez Soler",
                    "dataNaixement": "2004-07-22",
                    "email": "pere.martinez@cifpmoll.eu"
                },
                [..]
            ]
        }
    }
}
```

Les decisions preses a l'hora de fer aquesta conversió es resumeixen en la següent taula:

| XML                     | JSON                 | Raonament                                          |
|-------------------------|----------------------|----------------------------------------------------|
| Atributs (`id`, `codi`) | Propietats           | JSON no té atributs; es converteixen en propietats |
| `any-academic`          | `anyAcademic`        | camelCase és la convenció en JSON                  |
| `data-naixement`        | `dataNaixement`      | Els guions no són habituals en claus JSON          |
| `<hores>128</hores>`    | `"hores": 128`       | Es converteix a número (tipus nadiu)               |
| Elements repetits       | Arrays               | `<assignatura>` repetit → array `assignatures`     |
| Element contenidor      | Eliminat o mantingut | `<assignatures>` pot eliminar-se si és redundant   |

## Exemple d'empresa

Tot seguit anam a fer una conversió més complexa, car [l'exemple de document XML d'empresa](/xml/namespaces/empresa.xml) utilitza espais de noms. L'esquema del document XML original amb namespaces és aquest:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<emp:empresa xmlns:emp="http://exemple.com/empresa"
             xmlns:rh="http://exemple.com/recursos-humans"
             xmlns:fin="http://exemple.com/finances"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    
    <!-- Informació general de l'empresa -->
    <emp:identificacio>
        [..]
    </emp:identificacio>
    
    <!-- Departaments -->
    <emp:departaments>
        [..]
    </emp:departaments>
    
    <!-- Recursos humans: empleats -->
    <rh:plantilla>
        [..]
    </rh:plantilla>
    
    <!-- Dades financeres globals -->
    <fin:resum-financer exercici="2024">
        [..]
    </fin:resum-financer>
    
</emp:empresa>
```

Car JSON no té namespaces, hi ha diverses estratègies per gestionar-ho. Cada estratègia té avantatges i inconvenients, i l'elecció depèn del context: qui consumirà el JSON, si hi ha risc de conflictes de noms, i quina estructura resulta més pràctica per al processament posterior.

**Opció 1: Ignorar els espais de noms**

La solució més senzilla és eliminar els prefixos i tractar tots els elements com si fossin d'un únic vocabulari. Aquesta opció és vàlida quan:

* No hi ha conflictes de noms (cap element de namespaces diferents té el mateix nom).
* El consumidor del JSON no necessita saber d'on prové cada camp.
* Es prioritza la simplicitat i llegibilitat.

```json
{
    "empresa": {
        "nom": "TechSolutions Balears S.L.",
        "cif": "B07123456",
        "empleats": [
            {
                "id": "EMP001",
                "nom": "Catalina",
                "cognoms": "Sureda Vidal",
                "salari": {
                    "valor": 45000.00,
                    "moneda": "EUR"
                }
            },
            {
                "id": "EMP002",
                "nom": "Miquel",
                "cognoms": "Fiol Amengual",
                "salari": {
                    "valor": 38000.00,
                    "moneda": "EUR"
                }
            }
        ]
    }
}
```

El resultat és un JSON net i fàcil de consumir, on les claus són curtes i el document és llegible.

Però es perd la informació sobre l'origen de cada camp. Si el document XML original tenia un element `<emp:nom>` (nom de l'empresa) i un `<rh:nom>` (nom de l'empleat), ambdós es convertirien en `"nom"` i caldria distingir-los pel context (nivell d'imbricació).

**Opció 2: Prefixos a les claus**

Si és important preservar la informació dels namespaces, es poden mantenir els prefixos com a part del nom de les claus. Aquesta opció és útil quan:

* Cal saber exactament d'on prové cada camp (per auditoria o traçabilitat).
* Hi ha conflictes de noms que cal distingir.
* El JSON es convertirà de nou a XML i cal preservar l'estructura original.

```json
{
    "emp:empresa": {
        "emp:nom": "TechSolutions Balears S.L.",
        "emp:cif": "B07123456",
        "rh:empleats": [
            {
                "rh:id": "EMP001",
                "rh:nom": "Catalina",
                "rh:cognoms": "Sureda Vidal",
                "fin:salari": {
                    "fin:valor": 45000.00,
                    "fin:moneda": "EUR"
                }
            },
            {
                "rh:id": "EMP002",
                "rh:nom": "Miquel",
                "rh:cognoms": "Fiol Amengual",
                "fin:salari": {
                    "fin:valor": 38000.00,
                    "fin:moneda": "EUR"
                }
            }
        ]
    }
}
```

Aquest JSON Preserva completament la informació dels namespaces i permet reconstruir l'XML original sense ambigüitats.

A canvi, les es claus són més llargues i el JSON és més difícil de llegir. Accedir a un camp requereix usar el prefix complet (per exemple, `dades["emp:empresa"]["rh:empleats"]`).

**Opció 3: Estructura separada per dominis**

Una alternativa més semàntica és reorganitzar el document JSON agrupant les dades segons el seu domini d'origen. En lloc de mantenir l'estructura jeràrquica de l'XML, es creen seccions separades per a cada namespace. Aquesta opció és adequada quan:

* Es vol una estructura JSON idiomàtica i fàcil de consumir.
* Cada domini (empresa, recursos humans, finances) es processarà de manera independent.
* Es prioritza la claredat semàntica sobre la fidelitat a l'estructura XML original.

```json
{
    "empresa": {
        "nom": "TechSolutions Balears S.L.",
        "cif": "B07123456",
        "departaments": [
            {
                "id": "DEP001",
                "nom": "Desenvolupament"
            },
            {
                "id": "DEP002",
                "nom": "Administració"
            }
        ]
    },
    "recursosHumans": {
        "empleats": [
            {
                "id": "EMP001",
                "nom": "Catalina",
                "cognoms": "Sureda Vidal",
                "departament": "DEP001"
            },
            {
                "id": "EMP002",
                "nom": "Miquel",
                "cognoms": "Fiol Amengual",
                "departament": "DEP001"
            }
        ]
    },
    "finances": {
        "exercici": 2024,
        "salaris": [
            {
                "empleatId": "EMP001",
                "brut": 45000.00,
                "moneda": "EUR"
            },
            {
                "empleatId": "EMP002",
                "brut": 38000.00,
                "moneda": "EUR"
            }
        ]
    }
}
```

Aquest JSON té una estructura clara i ben organitzada. Cada secció és independent i es pot processar per separat. Les claus són netes i segueixen convencions JSON estàndard, cosa que el fa ideal per a APIs on cada endpoint podria retornar una secció diferent.

L'inconvenient és que l'estructura és diferent de l'XML original, cosa que dificulta la conversió inversa. Les relacions entre elements (per exemple, quin salari correspon a quin empleat) s'han de fer explícites amb identificadors (`empleatId`), mentre que en l'XML original podien estar implícites per la jerarquia. Requereix més feina de disseny per decidir com organitzar les dades.

**Quina opció triar?**

Per a la majoria de casos (APIs web, aplicacions modernes), l'opció 1 o 3 són preferibles. L'opció 2 només té sentit quan la fidelitat a l'XML original és crítica, per exemple, en sistemes d'intercanvi on el JSON és un format intermedi i cal reconstruir l'XML exacte.


## JSON Schema

Quan fem feina amb JSON en aplicacions reals, sovint necessitam garantir que les dades tenen l'estructura correcta. Per exemple, si una API rep dades d'un formulari de registre, cal verificar que el camp `email` existeix, que conté un email vàlid, i que `edat` és un número enter positiu. Sense validació, el sistema podria fallar o, pitjor, processar dades incorrectes.

JSON Schema és un vocabulari que permet definir l'estructura esperada d'un document JSON i validar-lo automàticament. És l'equivalent a DTD/XSD per a XML, tot i que és més recent (el primer esborrany és de 2010 i la primera versió estable es va publicar el 2019) i encara està en evolució. A diferència de DTD i XSD, JSON Schema s'escriu en el mateix format que valida: JSON.

### Estructura bàsica

Un esquema JSON Schema és, en si mateix, un document JSON amb una estructura específica:

```json
{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://cifpfbmoll.eu/esquema.json",
    "title": "Títol de l'esquema",
    "description": "Descripció de l'esquema",
    "type": "object",
    "properties": {
        [..]
    }
}
```

Analitzem cada camp:

* `$schema`: Indica quina versió de JSON Schema s'utilitza. És important perquè les funcionalitats varien entre versions. La versió `2020-12` és l'última estable.
* `$id`: Identificador únic de l'esquema. Normalment és una URL que podria apuntar a on està publicat l'esquema, tot i que no és obligatori que la URL sigui accessible.
* `title` i `description`: Documentació per a humans. No afecten la validació, però ajuden a entendre què valida l'esquema.
* `type`: El tipus de dada esperat a l'arrel del document. Normalment és `object` per a documents JSON complets.
* `properties`: Defineix les propietats que pot tenir l'objecte i les seves restriccions.

### Tipus de dades

JSON Schema suporta els mateixos tipus que JSON, amb l'afegit d'`integer` per distingir enters de decimals:

| Tipus     | Descripció               | Exemple de valor    |
|-----------|--------------------------|---------------------|
| `string`  | Cadena de text           | `"Hola món"`        |
| `number`  | Número (enter o decimal) | `3.14`, `42`        |
| `integer` | Només enters             | `42`, `-7`          |
| `boolean` | Valor lògic              | `true`, `false`     |
| `null`    | Valor nul                | `null`              |
| `object`  | Objecte JSON             | `{"clau": "valor"}` |
| `array`   | Array JSON               | `[1, 2, 3]`         |

La diferència entre `number` i `integer` és important: `number` accepta `3.14` mentre que `integer` el rebutjaria.

### Validacions comunes

JSON Schema permet definir restriccions molt precises per a cada tipus de dada. Vegem les més habituals amb exemples pràctics.

**Validació de strings**

```json
{
    "type": "string",
    "minLength": 1,
    "maxLength": 100,
    "pattern": "^[A-Z][a-z]+$"
}
```

En aquest cas:

* `minLength` i `maxLength`: Longitud mínima i màxima del text. `minLength: 1` evita strings buits.
* `pattern`: Expressió regular que el valor ha de complir. En aquest exemple, `^[A-Z][a-z]+$` significa "comença amb majúscula seguida d'una o més minúscules" (per exemple, "Maria" seria vàlid, però "maria" o "MARIA" no).

**Validació de números**

```json
{
    "type": "integer",
    "minimum": 1,
    "maximum": 300
}
```

En aquest cas:

* `minimum` i `maximum`: Valor mínim i màxim acceptat (inclosos).
* També existeixen `exclusiveMinimum` i `exclusiveMaximum` per a límits no inclosos.

Per exemple, per validar hores d'una assignatura (entre 1 i 300), aquesta restricció rebutjaria valors com `0`, `-5` o `500`.

**Enumeracions**

Quan un camp només pot tenir uns valors concrets, usem `enum`:

```json
{
    "type": "string",
    "enum": ["LLM", "FP", "ASIX", "ASO"]
}
```

Qualsevol valor que no sigui exactament un dels llistats serà rebutjat. Això és útil per a codis, estats, categories, etc.

**Formats predefinits**

JSON Schema inclou formats predefinits per a tipus de dades comuns:

```json
{
    "type": "string",
    "format": "email"
}
```

Formats disponibles més habituals:

| Format      | Descripció                   | Exemple vàlid                          |
|-------------|------------------------------|----------------------------------------|
| `email`     | Adreça de correu electrònic  | `usuari@domini.com`                    |
| `date`      | Data ISO 8601                | `2025-03-15`                           |
| `time`      | Hora ISO 8601                | `14:30:00`                             |
| `date-time` | Data i hora ISO 8601         | `2025-03-15T14:30:00Z`                 |
| `uri`       | URL o URI                    | `https://exemple.com`                  |
| `uuid`      | Identificador únic universal | `550e8400-e29b-41d4-a716-446655440000` |
| `ipv4`      | Adreça IPv4                  | `192.168.1.1`                          |
| `ipv6`      | Adreça IPv6                  | `2001:0db8:85a3::8a2e:0370:7334`       |

> No tots els validadors implementen tots els formats. Alguns només comproven el tipus (`string`) però no el format. Cal verificar què suporta l'eina que s'utilitzi.

**Validació d'arrays**

```json
{
    "type": "array",
    "items": {
        "type": "string"
    },
    "minItems": 1,
    "maxItems": 10,
    "uniqueItems": true
}
```

* `items`: Defineix l'esquema que han de complir els elements de l'array. En aquest cas, tots han de ser strings.
* `minItems` i `maxItems`: Nombre mínim i màxim d'elements.
* `uniqueItems`: Si és `true`, no es permeten elements duplicats.

**Camps obligatoris i opcionals**

Per defecte, totes les propietats són opcionals. Per fer-les obligatòries, s'usa `required`:

```json
{
    "type": "object",
    "required": ["nom", "email"],
    "properties": {
        "nom": { "type": "string" },
        "email": { "type": "string", "format": "email" },
        "telefon": { "type": "string" }
    }
}
```

En aquest exemple, `nom` i `email` són obligatoris, mentre que `telefon` és opcional (pot no existir).

### Reutilització

Quan un esquema és complex i té estructures que es repeteixen, podem definir-les un cop i referenciar-les. Això fa l'esquema més mantenible i llegible.

* `$defs`: Secció on es defineixen subesquemes reutilitzables.
* `$ref`: Referència a un subesquema definit en una altra part.

```json
{
    "$defs": {
        "adreca": {
            "type": "object",
            "properties": {
                "carrer": { "type": "string" },
                "ciutat": { "type": "string" },
                "codiPostal": { "type": "string", "pattern": "^[0-9]{5}$" }
            }
        }
    },
    "type": "object",
    "properties": {
        "adrecaFacturacio": { "$ref": "#/$defs/adreca" },
        "adrecaEnviament": { "$ref": "#/$defs/adreca" }
    }
}
```

En aquest exemple, definim una vegada l'estructura d'adreça a `$defs` i la reutilitzam per a l'adreça de facturació i la d'enviament. Si més tard cal afegir un camp a les adreces, només cal modificar un lloc.

La sintaxi `#/$defs/adreca` significa "dins d'aquest document (`#`), a la secció `$defs`, l'element `adreca`".

### Document de l'institut

Vegem un [esquema complet per validar el document JSON de l'institut](/xml/json-schema/institut.schema.json) que hem usat als exemples anteriors. L'esquema defineix l'estructura esperada amb totes les restriccions:

```json
{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "$id": "https://cifpmoll.eu/schemas/institut.json",
    "title": "Institut de Formació Professional",
    "description": "Esquema per validar documents JSON d'instituts de FP",
    "type": "object",
    "required": ["institut"],
    "properties": {
        "institut": {
            "type": "object",
            "required": ["nom", "codi", "anyAcademic", "curs"],
            "properties": {
                "nom": {
                    "type": "string",
                    "description": "Nom oficial del centre",
                    "minLength": 1
                },
                "codi": {
                    "type": "string",
                    "description": "Codi del centre educatiu (8 dígits)",
                    "pattern": "^[0-9]{8}$"
                },
                "anyAcademic": {
                    "type": "string",
                    "description": "Any acadèmic en format AAAA-AA",
                    "pattern": "^[0-9]{4}-[0-9]{2}$"
                },
                "curs": {
                    "$ref": "#/$defs/curs"
                }
            }
        }
    },
    "$defs": {
        "curs": {
            "type": "object",
            "required": ["id", "nom", "assignatures", "alumnes"],
            "properties": {
                "id": {
                    "type": "string",
                    "description": "Identificador del curs (2-5 lletres majúscules)",
                    "pattern": "^[A-Z]{2,5}$"
                },
                "nom": {
                    "type": "string",
                    "minLength": 1
                },
                "assignatures": {
                    "type": "array",
                    "minItems": 1,
                    "items": {
                        "$ref": "#/$defs/assignatura"
                    }
                },
                "alumnes": {
                    "type": "array",
                    "items": {
                        "$ref": "#/$defs/alumne"
                    }
                }
            }
        },
        "assignatura": {
            "type": "object",
            "required": ["codi", "nom", "hores"],
            "properties": {
                "codi": {
                    "type": "string",
                    "description": "Codi de l'assignatura",
                    "pattern": "^[A-Z]{2,5}$"
                },
                "nom": {
                    "type": "string",
                    "minLength": 1
                },
                "hores": {
                    "type": "integer",
                    "description": "Hores lectives totals",
                    "minimum": 1,
                    "maximum": 300
                }
            }
        },
        "alumne": {
            "type": "object",
            "required": ["id", "nom", "cognoms", "email"],
            "properties": {
                "id": {
                    "type": "string",
                    "description": "Identificador d'alumne (A seguit de 3 dígits)",
                    "pattern": "^A[0-9]{3}$"
                },
                "nom": {
                    "type": "string",
                    "minLength": 1
                },
                "cognoms": {
                    "type": "string",
                    "minLength": 1
                },
                "dataNaixement": {
                    "type": "string",
                    "format": "date"
                },
                "email": {
                    "type": "string",
                    "format": "email"
                }
            }
        }
    }
}
```

Observa com l'esquema:

1. Defineix tres tipus reutilitzables a `$defs`: `curs`, `assignatura` i `alumne`.
2. Usa `$ref` per referenciar aquests tipus on cal.
3. Especifica quins camps són obligatoris amb `required`.
4. Valida formats específics: codis amb patrons regex, hores amb rang numèric, email amb format predefinit.

Si un document JSON no compleix alguna d'aquestes restriccions, el validador indicarà exactament quin camp falla i per què.

### Comparativa

La següent taula inclou una comparativa entre JSON Schema, DTD i XSD:

| Aspecte                  | DTD               | XSD                   | JSON Schema              |
|--------------------------|-------------------|-----------------------|--------------------------|
| **Sintaxi**              | Pròpia (no XML)   | XML                   | JSON                     |
| **Tipus de dades**       | Bàsics (10 tipus) | Molt rics (44+ tipus) | Rics (7 tipus + formats) |
| **Patrons (regex)**      | No                | Sí                    | Sí                       |
| **Reutilització**        | Entitats          | Tipus complexos       | `$ref` i `$defs`         |
| **Documentació**         | Comentaris        | `xs:annotation`       | `title`, `description`   |
| **Validació en línia**   | Dins del document | Fitxer extern         | Fitxer extern            |
| **Maduresa**             | Molt alta (1998)  | Molt alta (2001)      | Mitjana-alta (2019)      |
| **Adopció**              | Decreixent        | Estable               | Creixent                 |
| **Corba d'aprenentatge** | Baixa             | Alta                  | Mitjana                  |

La principal diferència pràctica és que JSON Schema s'escriu en JSON, cosa que el fa més familiar per a desenvolupadors que ja treballen amb aquest format. XSD, en canvi, requereix conèixer una sintaxi XML específica i bastant verbosa.

## Eines online

Les eines online són ideals per a validacions ràpides, proves puntuals i aprenentatge. No requereixen instal·lació i ofereixen resultats immediats, cosa que les fa molt pràctiques durant el desenvolupament.

**Validadors i formatejadors**

| Eina                                                                          | Funcionalitats principals                                             |
|-------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| [JSONLint](https://jsonlint.com/)                                             | Validació de sintaxi, formatació, missatges d'error clars             |
| [JSON Editor Online](https://jsoneditoronline.org/)                           | Edició visual en arbre, validació en temps real, conversió de formats |
| [JSON Formatter (Curious Concept)](https://jsonformatter.curiousconcept.com/) | Formatació amb diferents estils d'indentació, minificació             |
| [Code Beautify JSON Viewer](https://codebeautify.org/jsonviewer)              | Visualització en arbre, conversió JSON ↔ XML, comparació de documents |

**Validadors JSON Schema**

| Eina                                                                 | Funcionalitats principals                                               |
|----------------------------------------------------------------------|-------------------------------------------------------------------------|
| [JSON Schema Validator](https://www.jsonschemavalidator.net/)        | Validació contra JSON Schema, errors detallats                          |
| [Hyperjump JSON Schema Validator](https://json-schema.hyperjump.io/) | Suport per a múltiples versions de JSON Schema, validació en temps real |

Aquestes eines permeten comprovar que un document JSON compleix un esquema sense necessitat d'escriure codi.

**Conversors**

| Eina                                                            | Funcionalitats principals |
|-----------------------------------------------------------------|---------------------------|
| [Code Beautify XML to JSON](https://codebeautify.org/xmltojson) | Conversió XML → JSON      |
| [Code Beautify JSON to XML](https://codebeautify.org/jsontoxml) | Conversió JSON → XML      |

Útils per comparar estructures entre formats o migrar dades d'un format a l'altre.

## Eines de terminal

### jq

`jq` és l'eina de referència per treballar amb JSON a Linux. És l'equivalent a `xmllint` i `xsltproc` combinats, però per a JSON:

```bash
sudo apt install jq
jq --version
```

Aquestes són les seves opcions més útils:

| Opció                  | Descripció                                |
|------------------------|-------------------------------------------|
| `.`                    | Filtre identitat (formata el document)    |
| `-r`                   | Raw output (sense cometes en strings)     |
| `-c`                   | Compacte (una línia, sense formatació)    |
| `-s`                   | Slurp (llegeix múltiples JSON com array)  |
| `-e`                   | Exit status segons resultat               |
| `--arg nom valor`      | Passa variable com a string               |
| `--argjson nom valor`  | Passa variable com a JSON                 |
| `--slurpfile nom file` | Carrega fitxer JSON a variable            |

**Format**

Podem usar `jq` per formatejar JSON (pretty print):

```bash
# Des de fitxer
jq '.' document.json

# Des de pipe
echo '{"nom":"Maria","edat":19}' | jq '.'
```

**Processament**

Podem usar `jq` per extreure valors (similar a XPath en XML):

```bash
# Valor d'una clau
jq '.institut.nom' institut.json

# Sense cometes (raw output)
jq -r '.institut.nom' institut.json

# Accedir a un element d'un array
jq '.institut.curs.assignatures[0]' institut.json

# Tots els elements d'un array
jq '.institut.curs.assignatures[]' institut.json

# Propietat de tots els elements
jq '.institut.curs.assignatures[].nom' institut.json
```

Podem usar `jq` per filtrar i seleccionar dades:

```bash
# Seleccionar assignatures amb més de 100 hores
jq '.institut.curs.assignatures[] | select(.hores > 100)' institut.json

# Obtenir només noms i hores
jq '.institut.curs.assignatures[] | {nom, hores}' institut.json

# Filtrar alumnes per patró
jq '.institut.curs.alumnes[] | select(.email | contains("garcia"))' institut.json
```

Podem usar `jq` per transformar dades:

```bash
# Crear nou objecte
jq '.institut.curs.assignatures[] | {codi: .codi, durada: .hores}' institut.json

# Sumar valors
jq '[.institut.curs.assignatures[].hores] | add' institut.json

# Comptar elements
jq '.institut.curs.alumnes | length' institut.json

# Ordenar
jq '.institut.curs.assignatures | sort_by(.hores) | reverse' institut.json
```

Podem usar `jq` per modificar documents:

```bash
# Afegir camp
jq '.institut.web = "https://cifpmoll.eu"' institut.json

# Modificar valor
jq '.institut.curs.assignatures[0].hores = 130' institut.json

# Eliminar camp
jq 'del(.institut.codi)' institut.json

# Actualitzar múltiples valors
jq '.institut.curs.alumnes[].actiu = true' institut.json
```

A continuació es mostren alguns exemples pràctics:

```bash
$ jq -r '.institut.curs.alumnes[].nom' institut.json
Maria
Pere
Laura
Jordi
Anna

$ jq -r '.institut.curs.alumnes[0].nom' institut.json
Maria

$ jq '.institut.curs.alumnes | length' institut.json
10

$ jq '[.institut.curs.assignatures[].hores] | add' institut.json
320
```

Finalment, `jq` permet exportar a formats tabulars:

```bash
# Convertir a CSV
jq -r '.institut.curs.alumnes[] | [.id, .nom, .cognoms, .email] | @csv' institut.json

# Convertir a TSV
jq -r '.institut.curs.alumnes[] | [.id, .nom, .email] | @tsv' institut.json
```

**Validació**

Per validar sintaxi JSON des de la línia de comandes, la comanda `jq empty` és la manera més ràpida de validar: no produeix sortida si el JSON és vàlid, i mostra un error si no ho és.

```bash
jq empty institut.json
```

### jsonschema

Per validar documents JSON contra un esquema JSON Schema, l'opció més còmoda que tenim és [check-jsonschema](https://github.com/python-jsonschema/check-jsonschema), car està disponible com a paquet de sitema:

```bash
sudo apt install python3-jsonschema
jsonschema --version
```

La seva execució és molt senzilla:

```bash
jsonschema --output pretty --instance institut.json institut.schema.json
```

## Exemple complet

Amb un simple script de BASH i les eines anteriorment explicades, podem fàcilment generar pipelines de validació de documents JSON, amb o sense JSON Schema.

### jq

El següent exemple valida tots els JSON d'un directori:

```bash
#!/bin/bash
ERRORS=0

for fitxer in *.json; do
    echo -n "Validant $fitxer... "
    if jq empty "$fitxer" 2>/dev/null; then
        echo "OK"
    else
        echo "Error!"
        ((ERRORS++))
    fi
done

echo "---"
echo "Fitxers amb errors: $ERRORS"
exit $ERRORS
```

### jsonschema

I el següent exemple fa la validació amb esquema:

```bash
#!/bin/bash
JSON="$1"
SCHEMA="institut-schema.json"

if [ -z "$JSON" ]; then
    echo "Ús: $0 fitxer.json"
    exit 1
fi

echo "1. Comprovant sintaxi JSON..."
if ! jq empty "$JSON" 2>&1; then
    echo "Error: JSON mal format!"
    exit 1
fi

echo "2. Validant contra esquema..."
if jsonschema --instance "$JSON" "$SCHEMA" 2>&1; then
    echo "OK: Document vàlid."
else
    echo "Error: Document no vàlid!"
    exit 2
fi
```

### Equivalències

Equivalències de comandes entre les eines XML i les eines JSON:

| Funció                | XML                                         | JSON                                              |
|-----------------------|---------------------------------------------|---------------------------------------------------|
| Comprovar format      | `xmllint --noout fitxer.xml`                | `jq empty fitxer.json`                            |
| Formatejar            | `xmllint --format fitxer.xml`               | `jq '.' fitxer.json`                              |
| Compactar             | `xmllint --noblanks fitxer.xml`             | `jq -c '.' fitxer.json`                           |
| Validar amb esquema   | `xmllint --schema esquema.xsd fitxer.xml`   | `jsonschema --instance fitxer.json esquema.json`  |
| Seleccionar amb query | `xmllint --xpath "//alumne/nom" fitxer.xml` | `jq '.alumnes[].nom' fitxer.json`                 |
| Comptar elements      | `xmllint --xpath "count(//alumne)" f.xml`   | `jq '.alumnes \| length' fitxer.json`             |
| Sumar valors          | `xmllint --xpath "sum(//hores)" f.xml`      | `jq '[.assignatures[].hores] \| add' fitxer.json` |

> La conversió entre formats XML i JSON i l'extracció de dades de documents JSON no són operacions habituals a la línia de comandes, sinó que solen fer-se des de codi (Python, Java, JavaScript).

## Extensions

Si uses [VSCodium](https://vscodium.com/) o [VSCode](https://code.visualstudio.com/) per a desenvolupar, el suport per a JSON ja ve integrat. Per a funcionalitats addicionals, les extensions recomanades són:

| Extensió              | Funcionalitats                      | VSCode                                                                                      | VSCodium                                                            |
|-----------------------|-------------------------------------|---------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| **JSON Tools**        | Formatació, minificació, escapat    | [Marketplace](https://marketplace.visualstudio.com/items?itemName=eriklynd.json-tools)      | [Open VSX](https://open-vsx.org/extension/eriklynd/json-tools)      |
| **JSON Schema Store** | Autocompletat amb esquemes populars | [Marketplace](https://marketplace.visualstudio.com/items?itemName=remcohaszing.schemastore) | [Open VSX](https://open-vsx.org/extension/remcohaszing/schemastore) |

I si uses Vim o Neovim, et recoman les següents instruccions al teu fitxer `~/.vimrc`:

```vim
" Formatejar JSON amb jq
command! JSONFormat %!jq '.'

" Compactar JSON
command! JSONCompact %!jq -c '.'

" Validar JSON
command! JSONValidate !jq empty %

" Mapeig de tecles
nnoremap <leader>jf :JSONFormat<CR>
nnoremap <leader>jc :JSONCompact<CR>
nnoremap <leader>jv :JSONValidate<CR>
```

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Creació d'un JSON Schema**

Crea un JSON Schema `reserva.schema.json` complet per validar documents JSON que representin reserves d'hotel. Estructura del document JSON `reserva.json` a validar:

```json
{
    "reserva": {
        "id": "RES-2025-001234",
        "hotel": {
            "nom": "Hotel Playa de Palma",
            "estrelles": 4,
            "adreca": {
                "carrer": "Carrer de la Mar, 15",
                "ciutat": "Palma",
                "codiPostal": "07610",
                "pais": "ES"
            }
        },
        "client": {
            "nom": "Maria García López",
            "email": "maria.garcia@example.com",
            "telefon": "+34612345678",
            "dni": "12345678A"
        },
        "estada": {
            "dataEntrada": "2025-07-15",
            "dataSortida": "2025-07-22",
            "habitacions": [
                {
                    "tipus": "doble",
                    "preu": 120.00,
                    "hostes": 2,
                    "vistes": false
                }
            ],
            "pensio": "mitja",
            "observacions": null
        },
        "total": 840.00,
        "pagat": false,
        "dataReserva": "2025-03-15T10:30:00Z"
    }
}
```

Requisits del JSON Schema:

1. **Estructura general:**
   * L'arrel ha de ser un objecte amb la propietat `reserva` obligatòria.
   * Usa `$defs` per definir tipus reutilitzables: `adreca`, `client`, `habitacio`.

2. **Validacions específiques:** Aplica les següents:
   * `id`: Patró `^RES-[0-9]{4}-[0-9]{6}$`.
   * `estrelles`: Enter entre 1 i 5.
   * `codiPostal`: Exactament 5 dígits.
   * `pais`: Codi ISO de 2 lletres majúscules.
   * `email`: Format email.
   * `telefon`: Patró per a telèfons internacionals (comença amb `+`, seguit de 9-15 dígits).
   * `dni`: Patró `^[0-9]{8}[A-Z]$`.
   * `dataEntrada`, `dataSortida`, `dataReserva`: Format date o date-time segons correspongui.
   * `tipus` habitació: Enumeració (`individual`, `doble`, `suite`, `familiar`).
   * `pensio`: Enumeració (`sense`, `esmorzar`, `mitja`, `completa`).
   * `preu`: Número positiu.
   * `hostes`: Enter entre 1 i 6.
   * `total`: Número positiu.
   * `observacions`: String o null.

3. **Camps obligatoris:** La resta són opcionals:
   * `reserva`: `id`, `hotel`, `client`, `estada`, `total`, `dataReserva`.
   * `hotel`: `nom`, `estrelles`.
   * `client`: `nom`, `email`.
   * `estada`: `dataEntrada`, `dataSortida`, `habitacions`.
   * `habitacio`: `tipus`, `preu`.

Validació: Usa [JSON Schema Validator](https://www.jsonschemavalidator.net/) o `jsonschema`. Prova de modificar el document d'exemple per provocar errors i verifica que el validador els detecta.

### Exercici 2

**Consultes i transformacions amb `jq`**

Donat el següent document JSON `cursos.json` d'una plataforma de cursos online, escriu les comandes `jq` necessàries per obtenir la informació sol·licitada:

```json
{
    "plataforma": {
        "nom": "TechLearn",
        "cursos": [
            {
                "id": "C001",
                "titol": "Introducció a Python",
                "instructor": "Anna Vidal",
                "preu": 49.99,
                "hores": 20,
                "categoria": "programacio",
                "alumnes": 1250,
                "valoracio": 4.8,
                "publicat": true
            },
            {
                "id": "C002",
                "titol": "Docker i Kubernetes",
                "instructor": "Miquel Ferrer",
                "preu": 79.99,
                "hores": 35,
                "categoria": "devops",
                "alumnes": 820,
                "valoracio": 4.6,
                "publicat": true
            },
            {
                "id": "C003",
                "titol": "Machine Learning Bàsic",
                "instructor": "Anna Vidal",
                "preu": 99.99,
                "hores": 45,
                "categoria": "ia",
                "alumnes": 650,
                "valoracio": 4.9,
                "publicat": true
            },
            {
                "id": "C004",
                "titol": "Administració de Sistemes Linux",
                "instructor": "Pere Soler",
                "preu": 59.99,
                "hores": 30,
                "categoria": "sistemes",
                "alumnes": 430,
                "valoracio": 4.5,
                "publicat": true
            },
            {
                "id": "C005",
                "titol": "Ciberseguretat Avançada",
                "instructor": "Laura Costa",
                "preu": 129.99,
                "hores": 50,
                "categoria": "seguretat",
                "alumnes": 280,
                "valoracio": 4.7,
                "publicat": false
            },
            {
                "id": "C006",
                "titol": "JavaScript Modern",
                "instructor": "Miquel Ferrer",
                "preu": 69.99,
                "hores": 25,
                "categoria": "programacio",
                "alumnes": 980,
                "valoracio": 4.4,
                "publicat": true
            }
        ]
    }
}
```

Consultes a realitzar:

1. Obtenir el nom de la plataforma.
2. Llistar tots els títols dels cursos.
3. Obtenir el curs amb id "C003" (tot l'objecte).
4. Llistar els cursos publicats (només títol i preu).
5. Comptar el nombre total de cursos.
6. Calcular la suma total d'alumnes de tots els cursos.
7. Obtenir els cursos amb valoració superior a 4.7.
8. Llistar els cursos ordenats per preu (de menor a major).
9. Obtenir els cursos de la categoria "programacio".
10. Calcular el preu mitjà de tots els cursos.
11. Obtenir els cursos de l'instructora "Anna Vidal" (només títol i categoria).
12. Llistar les categories úniques (sense repeticions).
13. Obtenir el curs amb més alumnes.
14. Crear un array amb objectes `{titol, instructor, hores}` de tots els cursos.
15. Exportar els cursos publicats a format CSV amb columnes: id, titol, preu.

{{< details summary="Respostes" >}}

| #  | Descripció                         | Comanda `jq`                                                                                          |
|:--:|------------------------------------|-------------------------------------------------------------------------------------------------------|
| 1  | Nom plataforma                     | `jq -r '.plataforma.nom' cursos.json`                                                                 |
| 2  | Tots els títols                    | `jq -r '.plataforma.cursos[].titol' cursos.json`                                                      |
| 3  | Curs amb id "C003"                 | `jq '.plataforma.cursos[] \| select(.id == "C003")' cursos.json`                                      |
| 4  | Cursos publicats (títol i preu)    | `jq '.plataforma.cursos[] \| select(.publicat) \| {titol, preu}' cursos.json`                         |
| 5  | Nombre total de cursos             | `jq '.plataforma.cursos \| length' cursos.json`                                                       |
| 6  | Suma total d'alumnes               | `jq '[.plataforma.cursos[].alumnes] \| add' cursos.json`                                              |
| 7  | Cursos amb valoració > 4.7         | `jq '.plataforma.cursos[] \| select(.valoracio > 4.7)' cursos.json`                                   |
| 8  | Cursos ordenats per preu           | `jq '.plataforma.cursos \| sort_by(.preu)' cursos.json`                                               |
| 9  | Cursos categoria "programacio"     | `jq '.plataforma.cursos[] \| select(.categoria == "programacio")' cursos.json`                        |
| 10 | Preu mitjà                         | `jq '[.plataforma.cursos[].preu] \| add / length' cursos.json`                                        |
| 11 | Cursos d'Anna Vidal                | `jq '.plataforma.cursos[] \| select(.instructor == "Anna Vidal") \| {titol, categoria}' cursos.json`  |
| 12 | Categories úniques                 | `jq '[.plataforma.cursos[].categoria] \| unique' cursos.json`                                         |
| 13 | Curs amb més alumnes               | `jq '.plataforma.cursos \| max_by(.alumnes)' cursos.json`                                             |
| 14 | Array amb titol, instructor, hores | `jq '[.plataforma.cursos[] \| {titol, instructor, hores}]' cursos.json`                               |
| 15 | Exportar a CSV                     | `jq -r '.plataforma.cursos[] \| select(.publicat) \| [.id, .titol, .preu] \| @csv' cursos.json`       |

{{< /details >}}

Validació: Executa cada comanda i verifica el resultat.

### Exercici 3

**Script de validació i informe JSON**

Crea un script de Bash `analitza-comandes.sh` que validi una col·lecció de fitxers JSON contra un esquema `comanda.schema.json` i generi un informe amb estadístiques extretes amb `jq`. 

Per fer aquest exercici, tens un directori amb fitxers JSON de comandes d'una botiga (al manco 5 comandes), cadascun seguint aquesta estructura:

```json
{
    "comanda": {
        "id": "ORD-2025-000001",
        "data": "2025-01-15",
        "client": {
            "nom": "Maria García",
            "email": "maria@example.com"
        },
        "productes": [
            {
                "sku": "PROD001",
                "nom": "Teclat mecànic",
                "quantitat": 1,
                "preu": 89.99
            },
            {
                "sku": "PROD002",
                "nom": "Ratolí ergonòmic",
                "quantitat": 2,
                "preu": 45.00
            }
        ],
        "subtotal": 179.99,
        "iva": 37.80,
        "total": 217.79,
        "estat": "enviat"
    }
}
```

Genera almanco 4 fitxers adicionals, seguint el format de nom que consideris oportú, però assegura't de que tenguin l'extensió `.json`.

Requisits de l'script:

1. **Paràmetres:**
   * `-d directori`: Directori amb els fitxers JSON (per defecte: `.`).
   * `-s esquema`: Fitxer JSON Schema per validar (opcional).
   * `-o fitxer`: Fitxer de sortida per a l'informe (per defecte: `informe.txt`).
   * `-h`: Mostra ajuda.

2. **Validació:**
   * Comprova que cada fitxer és JSON vàlid amb `jq empty`.
   * Si s'ha proporcionat esquema, valida contra ell.
   * Mostra errors però continua processant.

3. **Estadístiques a extreure:**
   * Total de comandes processades.
   * Suma total de vendes (camp `total`).
   * Comanda amb import més alt.
   * Nombre de comandes per estat (pendents, enviades, etc.).
   * Mitjana d'articles per comanda.
   * Client amb més comandes (si n'hi ha repetits).

4. **Informe de sortida:**

   ```
   ==========================================
   INFORME DE COMANDES
   Data: 2025-01-15 14:30:00
   ==========================================
   
   VALIDACIÓ
   ---------
   Fitxers processats: 15
   Fitxers vàlids: 14
   Fitxers amb errors: 1
     - comanda-corrupta.json: JSON mal format
   
   ESTADÍSTIQUES
   -------------
   Total vendes: 4.523,45 €
   Comanda més alta: ORD-2025-000023 (312,50 €)
   Mitjana per comanda: 301,56 €
   Mitjana articles/comanda: 3.2
   
   ESTAT DE COMANDES
   -----------------
     pendents: 3
     enviades: 8
     entregades: 3
   
   ==========================================
   ```

5. **Estructura suggerida:**

   ```bash
   #!/bin/bash
   
   # Funcions auxiliars
   mostrar_ajuda() {
       echo "Ús: $0 [-d directori] [-s esquema] [-o fitxer] [-h]"
       # ...
   }
   
   validar_json() {
       local fitxer="$1"
       jq empty "$fitxer" 2>/dev/null
   }
   
   extreure_total() {
       local fitxer="$1"
       jq -r '.comanda.total' "$fitxer"
   }
   
   # Processar arguments amb getopts
   # ...
   
   # Variables per a estadístiques
   TOTAL_VENDES=0
   declare -A ESTATS  # Array associatiu per comptar estats
   
   # Iniciar informe
   {
       echo "=========================================="
       echo "INFORME DE COMANDES"
       echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
       echo "=========================================="
       echo ""
   } > "$SORTIDA"
   
   # Bucle principal
   for json in "$DIRECTORI"/*.json; do
       [ -e "$json" ] || continue
       
       if validar_json "$json"; then
           # Extreure dades amb jq
           total=$(extreure_total "$json")
           estat=$(jq -r '.comanda.estat' "$json")
           
           # Acumular estadístiques
           TOTAL_VENDES=$(echo "$TOTAL_VENDES + $total" | bc)
           ((ESTATS[$estat]++))
           
           # ...
       fi
   done
   
   # Afegir estadístiques a l'informe
   # ...
   ```

Nota: Per a càlculs amb decimals en Bash, usa `bc`:

```bash
# Suma
echo "10.5 + 20.3" | bc

# Divisió amb decimals
echo "scale=2; 100 / 3" | bc
```
