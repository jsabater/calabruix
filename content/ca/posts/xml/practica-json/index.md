---
title: "Pràctica lliurable: Botiga d'esports en JSON"
date: 2026-03-11
lastmod: 2026-05-05
description: "Creació d'un catàleg de productes esportius en JSON amb validació d'esquemes i consultes amb jq."
summary: "Creació d'un catàleg de productes esportius en JSON amb validació d'esquemes i consultes amb jq."
categories: ["teaching"]
tags: ["xml", "json", "schema"]
series: ["XML"]
series_order: 14
weight: 140
slug: practica-json
---

En aquesta pràctica crearàs el catàleg de productes d'una botiga d'esports en línia utilitzant JSON i les tecnologies associades que hem estudiat. El catàleg inclourà informació detallada sobre cada producte: nom, descripció, preu, estoc, variants (talles i colors), ressenyes d'usuaris, etc.

L'objectiu és demostrar el domini de JSON com a format d'intercanvi de dades: des de la creació d'un document ben estructurat fins a la seva validació amb JSON Schema i el processament amb l'eina `jq`. La pràctica està estructurada en tres blocs de dificultat progressiva, de manera que pots anar construint el projecte pas a pas i obtenir puntuació parcial segons el nivell assolit.

## Objectius

Els objectius generals de cada bloc són:

| Bloc | Objectius                                                                                  |
|:----:|--------------------------------------------------------------------------------------------|
| 1    | Demostrar el domini de la sintaxi i estructura JSON, prenent decisions de disseny raonades |
| 2    | Crear un esquema JSON Schema per validar el document                                       |
| 3    | Processar el document amb consultes `jq`                                                   |

## Lliurables

Els lliurables de la pràctica són els següents:

| Fitxer               | Descripció                                         | Bloc |
|----------------------|----------------------------------------------------|:----:|
| `botiga.json`        | Document JSON principal                            | 1    |
| `README.md`          | Document explicant les decisions de disseny        | 1    |
| `botiga.schema.json` | Esquema de validació JSON Schema                   | 2    |
| `CONSULTES.md`       | Document amb les consultes jq i els seus resultats | 3    |

## Bloc 1: Document JSON

En aquest bloc crearàs el document JSON principal de la botiga d'esports i documentaràs les decisions de disseny que has pres.

### Requisits del document

El document `botiga.json` ha de contenir:

1. **Informació de la botiga** amb:
   - Nom de la botiga.
   - Eslògan.
   - Any de fundació.
   - Dades de contacte (email, telèfon, adreça).
   - Xarxes socials (almanco 2).

2. **Categories de productes** (mínim 4) amb:
   - Identificador únic.
   - Nom de la categoria.
   - Descripció breu.

> Exemples de categories: Running, Fitness, Natació, Ciclisme, Futbol, Bàsquet, Tennis, Muntanya...

3. **Entre 15 i 20 productes** amb la següent informació per a cadascun:
   - Identificador únic ([*](SKU)).
   - Nom del producte.
   - Descripció.
   - Marca.
   - Categoria (referència a l'identificador de categoria).
   - Preu (amb moneda).
   - Preu amb descompte (pot ser `null`).
   - Estoc disponible.
   - Valoració mitjana (0-5).
   - Nombre de valoracions.
   - Data d'incorporació al catàleg.
   - Disponible (booleà).
   - Imatges (array d'URLs).
   - Etiquetes (array de paraules clau).

4. **Variants de producte** per a almanco 4 productes de roba o calçat:
   - Talla (XS, S, M, L, XL o números per a calçat).
   - Color.
   - Estoc específic de la variant.
   - SKU de la variant (derivat del SKU principal).

> Exemple: Una camiseta tècnica pot tenir variants per a cada combinació de talla i color.

5. **Ressenyes d'usuaris** per a almenys 4 productes, amb:
   - Nom de l'usuari.
   - Puntuació (1-5).
   - Comentari.
   - Data de la ressenya.
   - Verificat (booleà que indica si l'usuari ha comprat el producte).

6. **Ús dels 6 tipus de dades JSON:**
   - `string`: noms, descripcions, codis de monedes, URLs...
   - `number`: preus, estocs, puntuacions...
   - `boolean`: disponibilitat, verificat...
   - `null`: descompte inexistent, camps opcionals...
   - `object`: producte, ressenya, informació de contacte...
   - `array`: categories, productes, variants, imatges, etiquetes...

### Decisions de disseny

El document `README.md` ha d'explicar breument (1-2 pàgines en format Markdown) les decisions de disseny que has pres:

1. **Estructura general:** Com has organitzat el document? Per què?

2. **Categories:** Les categories són un array independent o estan imbricades dins dels productes? Com fas referència a la categoria d'un producte?

3. **Variants:** Com has representat les variants de producte? Són objectes dins d'un array? Quins camps tenen?

4. **Ressenyes:** Les ressenyes estan dins de cada producte o en una estructura separada? Per què?

5. **Convencions de noms:** Has usat `camelCase`, `snake_case` o una altra convenció? Per què?

6. **Altres decisions:** Qualsevol altra decisió rellevant que vulguis justificar, e.g., preus, etc.

7. **Restriccions implementades:** Restriccions als tipus de dades que has usat al JSON Schema.

8. **Autoavaluació:** Inclou les comandes del blocs 1 i 2 de l'autoavaluació que trobaràs més avall en aquest document.

Aprofita aquest document per afegir la documentació o context que consideris necessari a l'hora de fer la correcció.

## Bloc 2: JSON Schema

En aquest bloc crearàs un esquema JSON Schema per validar el document `botiga.json`. L'esquema ha de garantir que qualsevol document que hi validi compleix l'estructura i les restriccions definides.

### Requisits de l'esquema

El fitxer `botiga.schema.json` ha d'incloure:

1. **Metadades de l'esquema:**
   - `$schema`: Versió de JSON Schema (`https://json-schema.org/draft/2020-12/schema`).
   - `$id`: Identificador únic de l'esquema.
   - `title`: Títol descriptiu.
   - `description`: Descripció de l'esquema.

2. **Tipus de dades correctes** per a cada camp:
   - `string` per a textos.
   - `number` o `integer` segons correspongui.
   - `boolean` per a valors lògics.
   - `array` per a llistes.
   - `object` per a objectes imbricats.

3. **Camps obligatoris** amb `required`:
   - L'esquema ha d'indicar quins camps són obligatoris a cada nivell.
   - Per exemple, un producte ha de tenir obligatòriament `sku`, `nom`, `preu` i `estoc`.

4. **Restriccions numèriques:**
   - Preu: `minimum: 0` (no pot ser negatiu).
   - Preu amb descompte: menor que el preu original (o `null`).
   - Estoc: `minimum: 0`.
   - Valoració: `minimum: 0`, `maximum: 5`.
   - Puntuació de ressenya: `minimum: 1`, `maximum: 5`.

5. **Restriccions de cadenes:**
   - SKU: Patró amb `pattern` (per exemple, `^[A-Z]{2,4}-[0-9]{3,5}$` per a codis com `RUN-001` o `FIT-1234`).
   - Email: `format: "email"`.
   - Data: `format: "date"`.
   - URL d'imatges: `format: "uri"`.

6. **Restriccions de vectors (arrays):**
   - `uniqueItems` per a llistes sense duplicats.
   - `minItems` i `maxItems` per a llistes de certa longitud.
   - `items` per a llistes d'elements de cert tipus.

7. **Restriccions lògiques:** Usa al manco una de les seguents restriccions:
   - `allOf` per a llistes de camps amb valors obligatoris.
   - `oneOf` o `anyOf` per a llistes de camps amb valors possibles.
   - `not` per a negar una restricció.

8. **Enumeracions** amb `enum`:
   - Talles de roba: `["XS", "S", "M", "L", "XL", "XXL"]`.
   - Moneda: `["EUR", "USD", "GBP"]`.
   - Colors disponibles (defineix 6-8 colors).

9. **Reutilització** amb `$defs` i `$ref`:
   - Defineix subesquemes reutilitzables per a: producte, variant, ressenya.
   - Referencia'ls amb `$ref` on calgui.
   - Això evita duplicar definicions i fa l'esquema més mantenible.

### Validació

Per validar el document JSON amb l'esquema, pots usar:

```bash
jsonschema --instance botiga.json botiga.schema.json
```

Si la validació és correcta, la comanda no mostrarà cap sortida. Si hi ha errors, mostrarà missatges indicant quin camp falla i per què.

## Bloc 3: Processament

En aquest bloc demostraràs que saps usar l'eina `jq` per extreure, filtrar i processar dades del document JSON.

### Requisits

El document `CONSULTES.md` ha de contenir **totes les consultes** `jq` de la llista següent, o equivalents adaptades al teu document:

1. Llistar tots els noms de productes.
2. Filtrar productes d'una categoria específica, per exemple, tots els productes de "Running".
3. Filtrar productes amb preu inferior a X euros, per exemple, productes per sota de 50 €.
4. Filtrar productes amb descompte, és a dir, on `preuDescompte` no sigui `null`.
5. Comptar el nombre total de productes.
6. Comptar el nombre de productes per categoria.
7. Calcular el preu mitjà dels productes.
8. Calcular la suma total de l'estoc disponible.
9. Mostrar productes amb estoc 0, és a dir, no disponibles.
10. Extreure només el nom i el preu de cada producte (projecció de camps).
11. Ordenar productes per preu (ascendent o descendent).
12. Mostrar el producte amb millor valoració.

Per a cada consulta, has d'incloure:

- La comanda `jq` completa.
- El resultat obtingut, o un extracte si és molt llarg.
- Una breu explicació del que fa la consulta.

### Format del document

El document `CONSULTES.md` ha de seguir aquest format:

* Un títol (nivell 1) del document.
* Un subtítol (nivell 2) per a cada consulta, amb el nom de la consulta.
* La comanda a executar, formatada. Exemple:
  ```bash
  jq '.productes[].nom' botiga.json
  ```

* El resultat de la comanda, formatat. Exemple:
  ```text
  "Esportives running Nike Air Zoom"
  "Camiseta tècnica Adidas"
  "Pilota de futbol Adidas UCL"
  ...
  ```

* L'explicació del que fa la consulta, per exemple:
  ```text
  Aquesta consulta accedeix a l'array 'productes' i extreu
  el camp 'nom' de cada element.
  ```
  Cal explicar com la consulta aconsegueix el resultat.

## Autoavaluació

Abans de lliurar la pràctica, pots usar les següents comandes per verificar la feina feta. Necessitaràs instal·lar els paquets `jq` i `python3-jsonschema`. Si no les tens instal·lades:

```bash
sudo apt install jq python3-jsonschema
```

### Bloc 1: Document JSON

Verifica que el document JSON està ben format:

```bash
jq empty botiga.json
```

Si no hi ha errors, la comanda no mostrarà cap sortida. Si el JSON està mal format, mostrarà un missatge d'error indicant la línia i el problema.

Mostra el document formatat per revisar-lo visualment:

```bash
jq '.' botiga.json | head -100
```

Compta el nombre de productes:

```bash
jq '.productes | length' botiga.json
```

Verifica que tots els productes tenen els camps obligatoris (adapta els noms de camps segons la teva estructura):

```bash
jq '.productes[] | select(.sku == null or .nom == null or .preu == null)' botiga.json
```

Si aquesta consulta no retorna res, tots els productes tenen els camps obligatoris.

Compta productes amb variants:

```bash
jq '[.productes[] | select(.variants != null)] | length' botiga.json
```

Compta productes amb ressenyes:

```bash
jq '[.productes[] | select(.ressenyes != null and (.ressenyes | length) > 0)] | length' botiga.json
```

### Bloc 2: JSON Schema

Verifica que l'esquema JSON Schema està ben format:

```bash
jq empty botiga.schema.json
```

Valida el document contra l'esquema:

```bash
jsonschema --instance botiga.json botiga.schema.json
```

Verifica que l'esquema usa `$defs` per reutilització:

```bash
jq 'has("$defs")' botiga.schema.json
```

Compta el nombre de definicions reutilitzables:

```bash
jq '."$defs" | keys | length' botiga.schema.json
```

Verifica que l'esquema inclou restriccions (cerca patrons, enumeracions i restriccions numèriques):

```bash
grep -c '"pattern"' botiga.schema.json
grep -c '"enum"' botiga.schema.json
grep -c '"minimum"\|"maximum"' botiga.schema.json
```

## Llista de verificació

Pots usar aquesta llista per fer un seguiment de l'autoavaluació:

**Bloc 1: Document JSON**

- [ ] Document JSON ben format (sense errors de sintaxi).
- [ ] Informació de la botiga completa.
- [ ] Mínim 4 categories.
- [ ] Entre 15 i 20 productes.
- [ ] Tots els camps requerits per producte.
- [ ] Mínim 4 productes amb variants.
- [ ] Mínim 4 productes amb ressenyes.
- [ ] Ús dels 6 tipus de dades JSON.
- [ ] Document `README.md` amb explicacions clares.

**Bloc 2: JSON Schema**

- [ ] Esquema JSON Schema ben format.
- [ ] Metadades (`$schema`, `$id`, `title`, `description`).
- [ ] Tipus de dades correctes.
- [ ] Camps obligatoris amb `required`.
- [ ] Restriccions numèriques (`minimum`, `maximum`).
- [ ] Restriccions de cadenes (`pattern`, `format`).
- [ ] Enumeracions (`enum`).
- [ ] Reutilització amb `$defs` i `$ref`.
- [ ] Validació correcta del document.

**Bloc 3: Consultes jq**

- [ ] Document `CONSULTES.md` amb format correcte.
- [ ] Les 12 consultes.
- [ ] Cada consulta inclou: comanda, resultat i explicació.
- [ ] Les consultes funcionen correctament.
- [ ] Varietat de consultes (extracció, filtrat, agregació).
