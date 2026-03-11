# Rúbrica: Botiga d'esports en JSON

**Puntuació total:** 60 punts

## Criteri 1: Estructura i sintaxi JSON (10 punts)

| Punts | Nivell | Descripció |
|-------|--------|------------|
| 10 | Excel·lent | Document JSON perfectament format, sense errors de sintaxi. Estructura jeràrquica clara i ben organitzada amb objectes i arrays correctament imbricats. Ús consistent d'indentació i format llegible. |
| 7 | Bé | Document JSON vàlid amb estructura correcta. Pot tenir petites inconsistències d'indentació o format, però l'estructura és clara i funcional. |
| 4 | Suficient | Document JSON vàlid però amb estructura confusa o poc organitzada. Imbricació excessiva o insuficient. Format irregular però funcional. |
| 0 | Insuficient | Document JSON amb errors de sintaxi que impedeixen el parseig. Estructura invàlida o inexistent. |

## Criteri 2: Contingut del document (10 punts)

| Punts | Nivell | Descripció |
|-------|--------|------------|
| 10 | Excel·lent | Informació completa de la botiga. Mínim 4 categories ben definides. Entre 15-20 productes amb tots els camps requerits (SKU, nom, descripció, marca, categoria, preu, estoc, valoració, imatges, etiquetes). Mínim 4 productes amb variants completes (talla, color, estoc, SKU). Mínim 4 productes amb ressenyes completes (usuari, puntuació, comentari, data, verificat). Ús correcte dels 6 tipus de dades JSON. |
| 7 | Bé | Informació de la botiga present. 3-4 categories. 12-14 productes o 15+ amb alguns camps mancants. 3 productes amb variants. 3 productes amb ressenyes. Ús de 5 tipus de dades JSON. |
| 4 | Suficient | Informació bàsica de la botiga. 2 categories. 8-11 productes amb camps bàsics. 1-2 productes amb variants incompletes. 1-2 productes amb ressenyes bàsiques. Ús de 4 tipus de dades JSON. |
| 0 | Insuficient | Informació de la botiga absent o molt incompleta. Menys de 2 categories. Menys de 8 productes o productes sense camps essencials. Sense variants ni ressenyes. |

## Criteri 3: Document de decisions (10 punts)

| Punts | Nivell | Descripció |
|-------|--------|------------|
| 10 | Excel·lent | Document Markdown ben estructurat que explica clarament totes les decisions de disseny: estructura general, organització de categories, representació de variants, ubicació de ressenyes, convencions de noms. Justificacions raonades i coherents amb el document JSON. |
| 7 | Bé | Document que explica la majoria de decisions de disseny (4-5 aspectes). Justificacions presents però algunes poc desenvolupades. Coherent amb el document JSON. |
| 4 | Suficient | Document que explica algunes decisions (2-3 aspectes). Justificacions superficials o absents. Pot haver-hi incoherències amb el document JSON. |
| 0 | Insuficient | Document absent, buit o que no explica cap decisió de disseny rellevant. |

## Criteri 4: JSON Schema - estructura i tipus (10 punts)

| Punts | Nivell | Descripció |
|-------|--------|------------|
| 10 | Excel·lent | Esquema JSON Schema complet i vàlid. Metadades presents (`$schema`, `$id`, `title`, `description`). Tipus de dades correctes per a tots els camps (`string`, `number`, `integer`, `boolean`, `array`, `object`). Camps obligatoris ben definits amb `required` a tots els nivells. Reutilització efectiva amb `$defs` i `$ref` (mínim 3 definicions). El document JSON valida correctament contra l'esquema. |
| 7 | Bé | Esquema vàlid amb la majoria de metadades. Tipus de dades correctes per a la majoria de camps. `required` present però incomplet. Ús de `$defs` i `$ref` (1-2 definicions). Validació correcta amb errors menors. |
| 4 | Suficient | Esquema bàsic que valida parcialment el document. Alguns tipus de dades incorrectes. `required` absent o molt incomplet. Sense reutilització amb `$defs`. Errors de validació presents. |
| 0 | Insuficient | Esquema absent, invàlid o que no correspon al document JSON. No valida el document. |

## Criteri 5: JSON Schema - restriccions avançades (10 punts)

| Punts | Nivell | Descripció |
|-------|--------|------------|
| 10 | Excel·lent | Restriccions numèriques completes: `minimum`/`maximum` per a preu (>0), estoc (≥0), valoració (1-5), puntuació ressenya (1-5). Restriccions de cadenes: `pattern` per a SKU, `format` per a email, dates i URIs. Enumeracions (`enum`) per a talles, moneda i colors. Restriccions d'arrays: `minItems`/`maxItems` on correspongui. |
| 7 | Bé | Restriccions numèriques presents per a la majoria de camps numèrics. Almenys 1 `pattern` i 2 `format`. Almenys 2 enumeracions. Alguna restricció d'arrays. |
| 4 | Suficient | Algunes restriccions numèriques (`minimum` o `maximum`). Cap o 1 `pattern`/`format`. 1 enumeració. Sense restriccions d'arrays. |
| 0 | Insuficient | Sense restriccions avançades o restriccions incorrectes que impedeixen la validació. |

## Criteri 6: Consultes jq (10 punts)

| Punts | Nivell | Descripció |
|-------|--------|------------|
| 10 | Excel·lent | Document `consultes.md` amb mínim 6 consultes jq correctes i variades. Cada consulta inclou: comanda completa, resultat obtingut i explicació clara. Varietat de consultes: extracció de camps, filtrat amb `select`, agregació (`length`, `add`), projecció de camps, ordenació (`sort_by`). Totes les consultes funcionen correctament. |
| 7 | Bé | 5-6 consultes correctes amb comanda, resultat i explicació. Varietat acceptable (mínim 3 tipus diferents de consulta). Alguna consulta pot tenir errors menors. |
| 4 | Suficient | 3-4 consultes bàsiques. Format incomplet (falta resultat o explicació en algunes). Poca varietat (només extracció o només filtrat). Algunes consultes amb errors. |
| 0 | Insuficient | Menys de 3 consultes, consultes incorrectes que no funcionen, o document absent. |

