---
title: "Origen i sintaxi de l'XML"
date: 2026-01-03
lastmod: 2026-01-08
description: "Origen i context històric de l'XML. Sintaxi bàsica: nodes, etiquetes, atributs, entitats, seccions CDATA, documents ben formats i vàlids."
summary: "Història i elements fonamentals: etiquetes, atributs, entitats i estructura de documents."
categories: ["ensenyament"]
tags: ["xml", "sgml"]
series: ["XML"]
series_order: 1
weight: 10
slug: introduccio
---

Als anys 80, el món de la documentació tècnica ja disposava d'un llenguatge de marques potent: l'Standard Generalized Markup Language, estandarditzat el 1986. Aquest permetia definir estructures de documents de manera flexible i era utilitzat per grans organitzacions, com el Departament de Defensa dels EUA o la indústria aeronàutica, per gestionar documentació tècnica complexa.

No obstant això, [*](SGML) tenia un problema fonamental: era extremadament complex. Les seves especificacions ocupaven centenars de pàgines i implementar un parser SGML complet requeria un esforç considerable. Aquesta complexitat el feia inaccessible per a la majoria de desenvolupadors i organitzacions.

```xml
<!DOCTYPE manual PUBLIC "-//ACME//DTD Manual Tècnic//CA">
<manual>
    <títol>Manual de Manteniment</títol>
    <capítol id=c1>
        <títol>Introducció
        <paràgraf>Aquest manual descriu els procediments de manteniment
        per a l'equip X-500.
        <paràgraf>Seguiu sempre les instruccions de seguretat.
    </capítol>
</manual>
```

## L'arribada d'HTML

El 1991, Tim Berners-Lee va crear l'[*](HTML) com una aplicació simplificada d'[*](SGML) per al web. HTML va ser un èxit rotund precisament per la seva senzillesa: qualsevol persona podia aprendre a crear pàgines web en poques hores.
Però HTML tenia limitacions importants:

* Vocabulari fix: les etiquetes estaven predefinides (`<p>`, `<h1>`, `<table>`, etc.) i no es podien crear de noves.
* Orientat a presentació: barrejava contingut amb format, dificultant la reutilització de dades.
* Poc rigorós: els navegadors acceptaven HTML mal format, cosa que generava inconsistències.

A mesura que la web creixia, es feia evident la necessitat d'un format que permetés intercanviar dades estructurades, no només presentar documents.

## El naixement d'XML

El 1996, el [*](W3C) va formar un grup de treball amb un objectiu clar: crear un subconjunt d'[*](SGML) que fos prou senzill per al web però prou potent per representar dades estructurades de qualsevol tipus.
Els principis que van guiar el disseny eren:

* Ha de ser fàcil d'usar a Internet.
* Ha de suportar una àmplia varietat d'aplicacions.
* Ha de ser compatible amb SGML.
* Ha de ser fàcil escriure programes que processin documents XML.
* El nombre de característiques opcionals ha de ser mínim, idealment zero.
* Els documents han de ser llegibles per humans i raonablement clars.
* El disseny ha de ser formal i concís.
* Els documents XML han de ser fàcils de crear.

El febrer de 1998, el W3C va publicar l'XML 1.0 com a recomanació oficial. El nom eXtensible Markup Language reflectia la seva característica principal: a diferència d'HTML, qualsevol persona podia definir les seves pròpies etiquetes segons les necessitats del seu domini. L'any 2004 es va publica l'XML 1.1, amb millores menors.

## Necessitats a resoldre

L'XML va néixer per resoldre problemes concrets:

| Necessitat                                      | Solució XML                                     |
| ----------------------------------------------- | ----------------------------------------------- |
| Intercanvi de dades entre sistemes heterogenis  | Format de text pla, independent de plataforma   |
| Definició d'estructures personalitzades         | Etiquetes extensibles, definides per l'usuari   |
| Validació de documents                          | DTD i, posteriorment, XML Schema                |
| Separació de dades i presentació                | XML per a dades, XSLT/CSS per a visualització   |
| Documentació autodescriptiva                    | Etiquetes amb noms significatius                |

Per apreciar com XML és autodescriptiu, a continuació es mostren dos exemples amb la mateixa informació en diferents formats. Dades en format CSV:

```csv
Nom,Llinatges,Mòdul,Any
Martí,Soler,ASIX,2025
```

Dades en format XML:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<alumne>
    <nom>Martí</nom>
    <cognom>Soler</cognom>
    <curs>ASIX</curs>
    <any>2025</any>
</alumne>
```

## Sintaxi fonamental

Tot document XML hauria de començar amb una declaració que indica la versió i la codificació de caràcters:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
```

Aquesta línia és una **instrucció de processament** i, tot i que tècnicament és opcional, es considera una bona pràctica incloure-la sempre. Els seus atributs són:

| Atribut      | Obligatori | Descripció                                                   |
|--------------|:----------:|--------------------------------------------------------------|
| `version`    | Sí         | Versió de l'XML (normalment "1.0")                           |
| `encoding`   | No         | Codificació de caràcters (UTF-8 per defecte)                 |
| `standalone` | No         | Si el document depèn de declaracions externes ("yes" o "no") |

## Estructura de nodes

Un document XML s'organitza com un arbre de **nodes**. Cada node pot contenir altres nodes, formant una jerarquia. Els tipus principals de nodes són:

* **Element:** el component bàsic, delimitat per etiquetes.
* **Atribut:** informació addicional associada a un element.
* **Text:** el contingut textual dins d'un element.
* **Comentari:** anotacions ignorades pel parser.
* **Instrucció de processament:** ordres per a aplicacions externes.

Tot document XML ha de tenir exactament **un element arrel** que contingui tots els altres elements. Aquest és un requisit fonamental:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<biblioteca>
    <llibre>...</llibre>
    <llibre>...</llibre>
</biblioteca>
```

En aquest exemple, `<biblioteca>` és l'element arrel. Un document amb dos elements al nivell superior seria incorrecte:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<llibre>...</llibre>
<llibre>...</llibre>
```

## Etiquetes i elements

Les **etiquetes** defineixen els elements del document. Cada **element** té una etiqueta d'obertura i una de tancament:

```xml
<assignatura>Llenguatges de Marques</assignatura>
```

Els noms d'etiquetes:

* Poden contenir lletres, números, guions, guions baixos i punts.
* Han de començar amb una lletra o guió baix (mai amb un número).
* No poden començar amb "xml" (en qualsevol combinació de majúscules/minúscules).
* Són sensibles a majúscules i minúscules: `<Alumne>` i `<alumne>` són etiquetes diferents.

| Nom vàlid     | Nom invàlid   | Motiu              |
|:-------------:|:-------------:|--------------------|
| `alumne`      | `2alumne`     | Comença amb número |
| `nom_complet` | `nom complet` | Conté espai        |
| `preu-total`  | `xml-dades`   | Comença amb "xml"  |
| `Curs2025`    | `@curs`       | Caràcter no permès |

## Atributs

Els **atributs** proporcionen informació addicional sobre un element. Es col·loquen dins de l'etiqueta d'obertura:

```xml
<alumne id="A001" actiu="true">
    <nom>Maria</nom>
</alumne>
```

Els atributs han de seguir les següents regles:

* El valor sempre ha d'anar entre cometes (dobles `"` o simples `'`).
* Un element no pot tenir dos atributs amb el mateix nom.
* L'ordre dels atributs no és significatiu.

L'ús d'elements i d'atributs és una qüestió de disseny que sovint genera debat. Un criteri orientatiu seria el d'usar atributs per a:

* Identificadors (`id="A001"`).
* Metadades que no formen part del contingut (`lang="ca"`, `version="2.0"`).
* Valors simples i atòmics.

I usar elements per a:

* Dades que podrien tenir estructura interna.
* Contingut que podria repetir-se.
* Informació que els usuaris haurien de veure.

Exemple comparatiu:

```xml
<!-- Enfocament amb atributs -->
<alumne id="A001" nom="Maria" cognom="García" edat="19"/>

<!-- Enfocament amb elements -->
<alumne id="A001">
    <nom>Maria</nom>
    <cognom>García</cognom>
    <edat>19</edat>
</alumne>
```

El segon enfocament és més extensible: si demà necessitam afegir un segon cognom o un sobrenom, l'estructura ho permet fàcilment.

## Elements buits

Un element sense contingut es pot escriure de dues maneres equivalents:

```xml
<!-- Forma llarga -->
<imatge src="foto.jpg"></imatge>

<!-- Forma abreujada (autotancament) -->
<imatge src="foto.jpg" />
```

La forma abreujada amb `/>` és preferible per la seva concisió.

## Comentaris

Els comentaris s'escriuen entre `<!--` i `-->`:

```xml
<!-- Això és un comentari que el parser ignorarà -->
<element>contingut</element>
```

Els comentaris no poden contenir la seqüència `--` al seu interior ni poden estar imbricats.

## Instruccions de processament

Les instruccions de processament transmeten ordres a aplicacions externes. La seva sintaxi és:

```xml
<?nom-aplicacio instruccions?>
```

L'exemple més comú és l'enllaç a un full d'estils:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/css" href="estils.css"?>
<document>
    ...
</document>
```

## Espais en blanc

L'XML preserva els espais en blanc dins del contingut textual, però els parsers poden tractar-los de manera diferent segons el context:

```xml
<missatge>Hola    món</missatge>
```

Els espais múltiples es mantenen tal qual dins de l'element. No obstant això, els espais entre etiquetes (fora del contingut) sovint s'ignoren o es normalitzen segons l'aplicació.

Per controlar explícitament el tractament dels espais, es pot usar l'atribut reservat `xml:space`, que veurem més endavant.

## Entitats predefinides

Alguns caràcters tenen un significat especial en XML i no es poden usar directament dins del contingut. Per representar-los, s'utilitzen entitats predefinides:

| Caràcter | Entitat  | Descripció                   |
|:--------:|:--------:|------------------------------|
| `<`      | `&lt;`   | Menor que (inici d'etiqueta) |
| `>`      | `&gt;`   | Major que (fi d'etiqueta)    |
| `&`      | `&amp;`  | Ampersand (inici d'entitat)  |
| `"`      | `&quot;` | Cometes dobles               |
| `'`      | `&apos;` | Cometa simple (apòstrof)     |

Per exemple, el següent bocí d'XML:

```xml
<formula>si x &lt; 10 &amp;&amp; y &gt; 5, surt</formula>
```

Es renderitzaria com:

```
Si x < 10 && y > 5, surt
```

## Seccions CDATA

Quan es necessita incloure un bloc de text amb molts caràcters especials, les seccions `CDATA` (Character Data) permeten escriure'l sense escapar cada caràcter:

```xml
<codi>
<![CDATA[
function compara(a, b) {
    if (a < b && b > 0) {
        return a + b;
    }
}
]]>
</codi>
```

Tot el contingut entre `<![CDATA[` i `]]>` es tracta com a text literal. L'única seqüència que no pot aparèixer dins d'un CDATA és `]]>`.

Els usos més freqüents de les seccions `CDATA` són:

* Per incloure codi font (JavaScript, SQL, etc.).
* Per a blocs de text amb molts de símbols `<`, `>` o `&`.
* Quan escapar cada caràcter faria el document il·legible.

## Document vàlid i ben format

Aquests dos conceptes són fonamentals i sovint es confonen.

Un document XML és **ben format** si compleix les regles sintàctiques bàsiques:

* Té exactament un element arrel.
* Totes les etiquetes obertes es tanquen correctament.
* Els elements estan correctament imbricats (no es creuen).
* Els valors dels atributs van entre cometes.
* No hi ha atributs duplicats en un mateix element.

Exemple de document mal format, amb etiquetes creuades i valors d'atributs sense cometes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<alumnes>
    <alumne>
        <nom>Pere
        <cognom>Mas</nom>
    </alumne>
    <alumne id=002>
        <nom>Anna</nom>
    </alumne>
</alumnes>
```

El document anterior passaria a ser ben format amb les següents modificacions:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<alumnes>
    <alumne id="001">
        <nom>Pere</nom>
        <cognom>Mas</cognom>
    </alumne>
    <alumne id="002">
        <nom>Anna</nom>
        <cognom>Miralles</cognom>
    </alumne>
</alumnes>
```

Un document és **vàlid** si, a més de ser ben format, compleix les regles definides en un esquema (DTD o XSD). L'esquema especifica:

* Quins elements poden existir.
* En quin ordre i amb quina freqüència.
* Quins atributs són permesos o obligatoris.
* Quin tipus de dades pot contenir cada element.

Per tant, un document XML mal format serà rebutjat pel parser, mentre que un document ben format serà parsejat correctament.

Un document ben format i vàlid serà correcta tant sintàcticament com estructuralment. En canvi, un document ben format però no vàlid tendrà una sintaxi correcta però no seguirà l'esquema definit.

Tot document vàlid és necessàriament ben format, però un document ben format no és necessàriament vàlid (pot no tenir esquema o no complir-lo).

```xml
<!-- Declaració XML -->
<?xml version="1.0" encoding="UTF-8"?>

<!-- Instrucció de processament -->
<?xml-stylesheet type="text/css" href="estils.css"?>

<!-- Element arrel amb atribut -->
<arrel atribut="valor">

    <!-- Element amb text -->
    <element>Contingut textual</element>

    <!-- Element buit -->
    <buit/>

    <!-- Entitats -->
    <especials>&lt;codi&gt;</especials>

    <!-- Secció CDATA -->
    <codi><![CDATA[a < b]]></codi>

</arrel>
```

L'especificació XML permet espais en blanc opcionals abans de `/>` i `?>` (és una qüestió d'estil), però no permet espai entre `<?` i el nom de la instrucció de processament.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Disseny d'un vocabulari XML**

Tria un dels contextos següents (o proposa'n un de propi) i dissenya un vocabulari XML per representar-ne les dades. El document ha de ser **ben format**.

Contextos proposats:

* Una col·lecció de videojocs (títol, plataforma, gènere, any, puntuació...).
* Un menú de restaurant (plats, preus, ingredients, al·lèrgens...).
* Una llista de reproducció musical (cançons, artistes, durada, àlbum...).
* Un catàleg de pel·lícules (títol, director, any, actors, sinopsi...).
* Una agenda de contactes (nom, telèfon, email, adreça...).

Requisits:

1. El document ha de tenir declaració XML amb versió i codificació.
2. Ha de tenir exactament un element arrel amb un nom significatiu.
3. Ha de contenir almenys 3 elements diferents amb contingut textual.
4. Ha de incloure almenys 2 atributs (per exemple, identificadors o metadades).
5. Ha de tenir almenys 3 registres (3 videojocs, 3 plats, 3 cançons...).
6. Ha d'incloure almenys un element buit amb atributs.

Exemple de lliurament (no copiïs aquest, crea el teu propi):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<biblioteca>
    <llibre id="L001" disponible="true">
        <titol>1984</titol>
        <autor>George Orwell</autor>
        <any>1949</any>
        <genere>Distopia</genere>
        <prestec/>
    </llibre>
    <!-- més llibres... -->
</biblioteca>
```

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Exercici 2

**Correcció d'errors**

El següent document XML conté **6 errors** que el fan mal format. Identifica'ls i corregeix-los. Explica breument cada error.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<receptes>
    <recepta id=001 dificultat="fàcil">
        <nom>Ensalada mediterrània</nom>
        <temps>15 minuts<temps>
        <ingredients>
            <ingredient>Tomàquet
            <ingredient>Ceba</ingredient>
            <ingredient>Olives</ingredient>
        <calories>250</calories>
    </recepta>
    <recepta id="002">
        <nom>Truita de patates</nom>
        <temps>30 minuts</temps>
        <ingredients>
            <ingredient>Patates</ingredient>
            <ingredient>Ous</ingredient>
        </ingredients>
        <!-- Recepta clàssica -- molt bona -->
        <calories>450</calories>
    </recepta>
<receptes>
```

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Exercici 3

**Entitats i CDATA**

Crea un document XML per a una pàgina de **preguntes freqüents (FAQ)** d'una botiga online. El document ha de demostrar l'ús correcte d'entitats predefinides i seccions CDATA.

Requisits:

1. Almenys 3 preguntes amb les seves respostes.
2. Una resposta ha de contenir una comparació matemàtica (per exemple, "si el preu < 50€..."). Usa entitats.
3. Una resposta ha de contenir codi HTML d'exemple (per exemple, explicant com incrustar un widget). Usa una secció CDATA.
4. Una resposta ha de contenir el caràcter `&` en un context natural (per exemple, "termes & condicions"). Usa l'entitat corresponent.

Estructura suggerida:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<faq>
    <pregunta id="Q001">
        <text>Com puc fer una devolució?</text>
        <resposta>...</resposta>
    </pregunta>
    <!-- més preguntes... -->
</faq>
```

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).
