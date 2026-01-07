---
title: "Document XML d'exemple"
date: 2026-01-03
lastmod: 2026-01-03
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
├── curs
│   ├── @id
│   ├── @nom
│   ├── assignatures
│   │   └── assignatura (x3)
│   │       ├── @codi
│   │       ├── nom
│   │       └── hores
│   └── alumnes
│       └── alumne (x10)
│           ├── @id
│           ├── nom
│           ├── cognoms
│           ├── data-naixement
│           └── email
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
                <email>maria.garcia@cifpmoll.eu</email>
            </alumne>
            <alumne id="A002">
                <nom>Pere</nom>
                <cognoms>Martínez Soler</cognoms>
                <data-naixement>2004-07-22</data-naixement>
                <email>pere.martinez@cifpmoll.eu</email>
            </alumne>
            <alumne id="A003">
                <nom>Laura</nom>
                <cognoms>Vidal Mas</cognoms>
                <data-naixement>2005-01-08</data-naixement>
                <email>laura.vidal@cifpmoll.eu</email>
            </alumne>
            <alumne id="A004">
                <nom>Jordi</nom>
                <cognoms>Pons Ferrer</cognoms>
                <data-naixement>2004-11-30</data-naixement>
                <email>jordi.pons@cifpmoll.eu</email>
            </alumne>
            <alumne id="A005">
                <nom>Anna</nom>
                <cognoms>Serra Riera</cognoms>
                <data-naixement>2005-06-12</data-naixement>
                <email>anna.serra@cifpmoll.eu</email>
            </alumne>
            <alumne id="A006">
                <nom>Marc</nom>
                <cognoms>Oliver Tous</cognoms>
                <data-naixement>2004-09-03</data-naixement>
                <email>marc.oliver@cifpmoll.eu</email>
            </alumne>
            <alumne id="A007">
                <nom>Carla</nom>
                <cognoms>Munar Cifre</cognoms>
                <data-naixement>2005-04-25</data-naixement>
                <email>carla.munar@cifpmoll.eu</email>
            </alumne>
            <alumne id="A008">
                <nom>Tomeu</nom>
                <cognoms>Amengual Reus</cognoms>
                <data-naixement>2004-12-18</data-naixement>
                <email>tomeu.amengual@cifpmoll.eu</email>
            </alumne>
            <alumne id="A009">
                <nom>Aina</nom>
                <cognoms>Crespí Bonnín</cognoms>
                <data-naixement>2005-08-07</data-naixement>
                <email>aina.crespi@cifpmoll.eu</email>
            </alumne>
            <alumne id="A010">
                <nom>Miquel</nom>
                <cognoms>Fiol Pascual</cognoms>
                <data-naixement>2004-05-14</data-naixement>
                <email>miquel.fiol@cifpmoll.eu</email>
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
<!-- Notes dels alumnes per assignatura -->
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
