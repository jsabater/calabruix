---
title: "Document XML d'exemple"
date: 2026-01-03
lastmod: 2026-01-15
description: "Exemple pràctic de document XML amb una estructura d'alumnes i assignatures en un curs de formació professional."
summary: "XML complet d'un curs de formació professional amb alumnes i assignatures"
categories: ["ensenyament"]
tags: ["xml"]
series: ["XML"]
series_order: 2
weight: 20
slug: exemple
---

Per il·lustrar els conceptes de l'XML de manera pràctica, crearem un document que representi informació acadèmica d'un institut de formació professional. Aquest exemple ens servirà de base per als següents articles. L'estructura inclourà:

* Informació del centre educatiu.
* Un curs, Administració de Sistemes Informàtics en Xarxa (ASIX).
* Tres assignatures del curs (LLM, FP, ASO).
* Deu alumnes matriculats.

Abans d'escriure el codi, és útil visualitzar l'estructura jeràrquica:

```
institut
├── nom
├── codi
├── any-academic
└─── curs
    ├── @id
    ├── @nom
    ├── assignatures
    │   └── assignatura (x3)
    │       ├── @codi
    │       ├── nom
    │       └── hores
    └── alumnes
        └── alumne (x10)
            ├── @id
            ├── nom
            ├── cognoms
            ├── data-naixement
            └── email
```

Els elements precedits per `@` són atributs. Observa com hem decidit:

* Usar **atributs** per a identificadors (`id`, `codi`) que serveixen com a claus úniques.
* Usar **elements** per a dades amb contingut textual significatiu (`nom`, `cognoms`, `email`).

## El document complet

A continuació es presenta [el document XML base](/xml/exemple/institut.xml) amb el que farem feina durant la major part d'aquesta sèrie d'articles, que anomenarem `institut.xml`:

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
            <assignatura codi="FP">
                <nom>Fonaments de Programació</nom>
                <hores>66</hores>
            </assignatura>
            <assignatura codi="ASO">
                <nom>Administració de Sistemes Operatius</nom>
                <hores>126</hores>
            </assignatura>
        </assignatures>
        
        <alumnes>
            <alumne id="A001">
                <nom>Maria</nom>
                <cognoms>García López</cognoms>
                <data-naixement>2005-03-15</data-naixement>
                <email>maria.garcia@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A002">
                <nom>Pere</nom>
                <cognoms>Martínez Soler</cognoms>
                <data-naixement>2004-07-22</data-naixement>
                <email>pere.martinez@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A003">
                <nom>Laura</nom>
                <cognoms>Vidal Mas</cognoms>
                <data-naixement>2005-01-08</data-naixement>
                <email>laura.vidal@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A004">
                <nom>Jordi</nom>
                <cognoms>Pons Ferrer</cognoms>
                <data-naixement>2004-11-30</data-naixement>
                <email>jordi.pons@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A005">
                <nom>Anna</nom>
                <cognoms>Serra Riera</cognoms>
                <data-naixement>2005-06-12</data-naixement>
                <email>anna.serra@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A006">
                <nom>Marc</nom>
                <cognoms>Oliver Tous</cognoms>
                <data-naixement>2004-09-03</data-naixement>
                <email>marc.oliver@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A007">
                <nom>Carla</nom>
                <cognoms>Munar Cifre</cognoms>
                <data-naixement>2005-04-25</data-naixement>
                <email>carla.munar@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A008">
                <nom>Tomeu</nom>
                <cognoms>Amengual Reus</cognoms>
                <data-naixement>2004-12-18</data-naixement>
                <email>tomeu.amengual@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A009">
                <nom>Aina</nom>
                <cognoms>Crespí Bonnín</cognoms>
                <data-naixement>2005-08-07</data-naixement>
                <email>aina.crespi@cifpfbmoll.eu</email>
            </alumne>
            <alumne id="A010">
                <nom>Miquel</nom>
                <cognoms>Fiol Pascual</cognoms>
                <data-naixement>2004-05-14</data-naixement>
                <email>miquel.fiol@cifpfbmoll.eu</email>
            </alumne>
        </alumnes>
    </curs>
</institut>
```

## Anàlisi del document

La següent taula resumeix i justifica les decisions de disseny que s'han pres:

| Decisió                                | Justificació                                                 |
|----------------------------------------|--------------------------------------------------------------|
| `id` com a atribut                     | És un identificador únic, no contingut visible               |
| `nom` com a element                    | És contingut textual que es mostrarà a l'usuari              |
| `data-naixement` amb format ISO        | Format estàndard AAAA-MM-DD, ordenable i internacional       |
| `hores` com a element                  | Podria tenir atributs addicionals (teòriques, pràctiques)    |
| `nom` del curs com a atribut           | Inconsistència al document per debatre amb l'alumnat         |
| Contenidors `assignatures` i `alumnes` | Agrupen elements del mateix tipus, faciliten el processament |

I aquestes són les bones pràctiques aplicades:

1. **Noms descriptius:** Les etiquetes indiquen clarament el seu contingut (`data-naixement`, no `dn`).
2. **Consistència:** Tots els alumnes segueixen la mateixa estructura exacta.
3. **Separació lògica:** Les assignatures i els alumnes estan en contenidors separats.
4. **Format de dates estàndard:** ISO 8601 permet ordenació i és independent de la localització.
5. **Codificació UTF-8:** Permet caràcters especials com accents i la ce trencada.

Aquest document és **ben format** perquè:

* Té un únic element arrel (`<institut>`).
* Totes les etiquetes estan correctament tancades.
* Els elements estan correctament imbricats.
* Tots els valors d'atributs van entre cometes.

Encara no és **vàlid** perquè no hem definit cap esquema (DTD o XSD). Ho farem més endavant.

## Possibles extensions

El document es podria ampliar amb:

```xml
<!-- Notes dels alumnes per assignatura, dins cada `alumne` -->
<matricula alumne="A001" assignatura="LLM">
    <nota-parcial>7.5</nota-parcial>
    <nota-final>8.0</nota-final>
</matricula>

<!-- Professorat -->
<professors>
    <professor id="P001">
        <nom>Antoni Mesquida</nom>
        <assignatures-impartides>
            <assignatura-ref codi="LLM"/>
            <assignatura-ref codi="DIW"/>
        </assignatures-impartides>
    </professor>
</professors>
```

Aquestes extensions mostren com l'XML permet créixer l'estructura segons les necessitats, mantenint sempre la coherència del document.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Extensió del document de l'institut**

Partint del [document de l'institut.xml proporcionat a l'article](xml/exemple/institut.xml), amplia'l amb les funcionalitats següents:

Requisits:

1. **Afegeix una secció de professors** amb almenys 3 professors. Cada professor ha de tenir:
   * Identificador únic (atribut).
   * Nom i cognoms (elements).
   * Email (element).
   * Especialitat (element).
   * Assignatures que imparteix (referències a les assignatures existents).

2. **Afegeix una secció de matrícules** que relacioni alumnes amb assignatures i inclogui les seves notes. Cada matrícula ha de tenir:
   * Referència a l'alumne (atribut).
   * Referència a l'assignatura (atribut).
   * Nota del primer trimestre (element, opcional).
   * Nota del segon trimestre (element, opcional).
   * Nota final (element, opcional).

3. **Afegeix informació de contacte del centre** com a fill directe de l'element arrel:
   * Adreça (carrer, número, codi postal, ciutat).
   * Telèfon.
   * Email de contacte.
   * Pàgina web.

En un comentari al principi del document, justifica les següents decissions de disseny:

* Per què has triat usar atributs o elements en cada cas.
* Com has estructurat les referències entre professors i assignatures.
* Com has gestionat les notes opcionals (trimestres que encara no s'han avaluat).

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Exercici 2

**Disseny d'un vocabulari XML amb justificació**

Dissenya un document XML complet per a **un dels contextos següents**. El document ha de ser realista i prou complet per ser útil en una aplicació real.

* **Gestió d'una lliga esportiva:** equips, jugadors, partits, resultats, classificació.
* **Catàleg d'una botiga online:** productes, categories, estoc, preus, ofertes.
* **Sistema de reserves d'hotel:** habitacions, clients, reserves, serveis, tarifes.
* **Programació d'un festival de música:** escenaris, artistes, horaris, entrades.

Requisits:

1. El document ha de tenir almenys **3 nivells de profunditat** (element arrel → contenidors → elements amb fills).
2. Ha de contenir almenys **4 tipus d'elements diferents** amb contingut textual.
3. Ha d'incloure almenys **3 atributs** amb funcions diferents (identificadors, metadades, referències).
4. Ha de tenir **relacions entre elements** (per exemple, jugadors que pertanyen a equips, productes que pertanyen a categories).
5. Ha d'incloure almenys **5 registres** del tipus principal (5 productes, 5 jugadors, 5 habitacions...).
6. Utilitza dades fictícies però realistes.

Crea un diagrama de l'estructura, similar al de la primera secció de l'article, amb format d'arbre:

```
element-arrel
├── element-fill
│   ├── @atribut
│   └── subelement
└── altre-element
```

En un comentari al principi del document, justifica les decisions de disseny en format taula, de forma similar a la que trobaràs a la secció [Anàlisi del document](#an%c3%a0lisi-del-document). Així mateix, incorpora-hi un llista de, al manco, quatre bones pràctiques aplicades.

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Exercici 3

**Anàlisi crítica d'un disseny XML**

Analitza el següent document XML que representa una petita biblioteca. Identifica **almenys 5 decisions de disseny discutibles** i proposa alternatives.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<biblioteca>
    <llibre>
        <id>1</id>
        <info>1984|George Orwell|1949|Distopia</info>
        <prestec estat="disponible" data-retorn="" usuari=""/>
    </llibre>
    <llibre>
        <id>2</id>
        <info>El Quixot|Miguel de Cervantes|1605|Novel·la</info>
        <prestec estat="prestat" data-retorn="2025-02-15" usuari="Joan Garcia"/>
    </llibre>
    <llibre>
        <id>3</id>
        <info>Mecanoscrit del segon origen|Manuel de Pedrolo|1974|Ciència-ficció</info>
        <prestec estat="disponible" data-retorn="" usuari=""/>
    </llibre>
    <USU>
        <u id="u1" nom="Joan Garcia" email="joan@email.com" llibres_prestats="2"/>
        <u id="u2" nom="Maria López" email="maria@email.com" llibres_prestats="0"/>
    </USU>
</biblioteca>
```

Per a cada decisió discutible, indica:

1. **Problema:** Què està mal dissenyat i per què.
2. **Conseqüència:** Quin problema pràctic causa (processament, manteniment, extensibilitat).
3. **Alternativa:** Com ho dissenyaries tu.

Finalment, reescriu el document aplicant les millores proposades.
