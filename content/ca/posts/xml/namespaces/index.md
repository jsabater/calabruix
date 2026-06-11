---
title: "Espais de noms a l'XML"
date: 2026-01-03
lastmod: 2026-01-11
description: "Què són els espais de noms en XML, per què es necessiten, sintaxi de declaració, prefixos, namespace per defecte i resolució de conflictes entre vocabularis."
summary: "Declaració, prefixos, àmbits i exemple pràctic d'espais de noms en XML amb múltiples vocabularis."
categories: ["teaching"]
tags: ["xml"]
series: ["XML"]
series_order: 5
weight: 50
slug: espais-de-noms
---

Imagina que vols crear un document XML que combini informació de dues fonts diferents. Una font descriu llibres i l'altra descriu mobles. Ambdues podrien tenir un element `<taula>`:

```xml
<!-- Taula de continguts d'un llibre -->
<taula>
    <entrada>Capítol 1: Introducció</entrada>
    <entrada>Capítol 2: Desenvolupament</entrada>
</taula>

<!-- Taula com a moble -->
<taula>
    <material>Fusta de roure</material>
    <dimensions>120x80x75 cm</dimensions>
</taula>
```

Si intentam combinar aquestes dues estructures en un sol document, el parser no pot distingir quin element `<taula>` és quin. Aquest és el problema de col·lisió de noms que els namespaces resolen.

## Què són

Un espai de noms, o *namespace*, és un identificador únic, en forma d'[*](URI), que qualifica els noms dels elements i atributs per evitar ambigüitats. No cal que la URI apunti a cap recurs real; només serveix com a identificador únic.

Amb namespaces, el document anterior quedaria:

```xml
<document xmlns:llibre="http://exemple.com/llibres"
          xmlns:moble="http://exemple.com/mobles">
    
    <llibre:taula>
        <llibre:entrada>Capítol 1: Introducció</llibre:entrada>
    </llibre:taula>
    
    <moble:taula>
        <moble:material>Fusta de roure</moble:material>
    </moble:taula>
    
</document>
```

Ara cada element `<taula>` està clarament identificat pel seu namespace.

## Declaració

Els namespaces es declaren amb l'atribut especial `xmlns` (XML Namespace). Els namespaces poden tenir un prefix:

```xml
<element xmlns:prefix="URI-del-namespace">
```

### Prefixos

El prefix és un àlies curt que s'usa per qualificar els elements:

```xml
<inventari xmlns:hw="http://exemple.com/hardware"
           xmlns:sw="http://exemple.com/software">
    
    <hw:equip>
        <hw:nom>Servidor Dell R740</hw:nom>
        <hw:cpu>Intel Xeon Gold</hw:cpu>
    </hw:equip>
    
    <sw:aplicacio>
        <sw:nom>Apache HTTP Server</sw:nom>
        <sw:versio>2.4.57</sw:versio>
    </sw:aplicacio>
    
</inventari>
```

Si no es vol usar prefixos, es pot declarar un namespace per defecte que s'aplica a l'element i tots els seus descendents:

```xml
<inventari xmlns="http://exemple.com/hardware">
    <!-- Tots els elements sense prefix pertanyen al namespace per defecte -->
    <equip>
        <nom>Servidor Dell R740</nom>
        <cpu>Intel Xeon Gold</cpu>
    </equip>
</inventari>
```

XML permet la combinació d'un espai de noms per defecte i prefixos:

```xml
<empresa xmlns="http://exemple.com/empresa"
         xmlns:rh="http://exemple.com/recursos-humans">
    
    <!-- Elements sense prefix: namespace per defecte (empresa) -->
    <nom>TechCorp S.L.</nom>
    <cif>B12345678</cif>
    
    <!-- Elements amb prefix: namespace de recursos humans -->
    <rh:empleat>
        <rh:nom>Maria García</rh:nom>
        <rh:departament>Desenvolupament</rh:departament>
    </rh:empleat>
    
</empresa>
```

### Àmbits

La declaració d'un namespace té efecte sobre l'element on es declara i tots els seus descendents, fins que es redefineix.

```xml
<!-- ns1 per defecte -->
<arrel xmlns="http://ns1.com">
    <a>Element en ns1</a>

    <!-- ns2 per defecte dins de <b> -->
    <b xmlns="http://ns2.com">
        <c>Element en ns2</c>
        <d>També en ns2</d>
    </b>

    <!-- ns1 per defecte altra vegada -->
    <e>Tornem a ns1</e>
</arrel>
```

### Identificadors

Les URIs dels namespaces són simplement identificadors únics. Per convenció, s'usen URLs que sovint apunten a documentació, però això no és obligatori:

```xml
<!-- URIs típiques -->
xmlns="http://www.w3.org/1999/xhtml"
xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"

<!-- També són vàlides URNs -->
xmlns:isbn="urn:isbn"
xmlns:exemple="urn:exemple:inventari:2025"
```

El parser XML no accedeix a aquestes URIs, sinó que només les compara com a cadenes de text per determinar si dos elements pertanyen al mateix namespace.

## Espais de noms i atributs

Els atributs es comporten de manera diferent als elements respecte als namespaces. Els atributs sense prefix **no pertanyen a cap namespace**, ni tan sols al namespace per defecte:

```xml
<element xmlns="http://exemple.com/ns">
    <!-- L'atribut "id" no té namespace -->
    <item id="001">Contingut</item>
</element>
```

Per assignar un namespace a un atribut, cal usar explícitament un prefix:

```xml
<element xmlns="http://exemple.com/ns"
         xmlns:meta="http://exemple.com/metadata">
    <!-- L'atribut meta:autor pertany al namespace metadata -->
    <item id="001" meta:autor="Joan">Contingut</item>
</element>
```

## Exemple complet

El següent {{< icon "download" >}} [document XML d'exemple d'empresa](/downloads/xml/namespaces/empresa.xml) amb múltiples vocabularis combina informació d'empresa, recursos humans i dades financeres en un sol document:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<emp:empresa xmlns:emp="http://exemple.com/empresa"
             xmlns:rh="http://exemple.com/recursos-humans"
             xmlns:fin="http://exemple.com/finances"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    
    <!-- Informació general de l'empresa -->
    <emp:identificacio>
        <emp:nom>TechSolutions Balears S.L.</emp:nom>
        <emp:cif>B07123456</emp:cif>
        <emp:adreca>
            <emp:carrer>Carrer de la Tecnologia, 42</emp:carrer>
            <emp:ciutat>Palma</emp:ciutat>
            <emp:cp>07001</emp:cp>
        </emp:adreca>
        <emp:web>https://www.exemple.com</emp:web>
    </emp:identificacio>
    
    <!-- Departaments -->
    <emp:departaments>
        <emp:departament id="DEP001">
            <emp:nom>Desenvolupament</emp:nom>
            <emp:ubicacio>Planta 2</emp:ubicacio>
        </emp:departament>
        <emp:departament id="DEP002">
            <emp:nom>Sistemes</emp:nom>
            <emp:ubicacio>Planta 1</emp:ubicacio>
        </emp:departament>
        <emp:departament id="DEP003">
            <emp:nom>Administració</emp:nom>
            <emp:ubicacio>Planta baixa</emp:ubicacio>
        </emp:departament>
    </emp:departaments>
    
    <!-- Recursos humans: empleats -->
    <rh:plantilla>
        <rh:empleat id="EMP001" emp:departament-ref="DEP001">
            <rh:dades-personals>
                <rh:nom>Catalina</rh:nom>
                <rh:cognoms>Sureda Vidal</rh:cognoms>
                <rh:dni>43123456A</rh:dni>
            </rh:dades-personals>
            <rh:dades-laborals>
                <rh:carrec>Cap de Desenvolupament</rh:carrec>
                <rh:data-alta>2018-03-15</rh:data-alta>
                <rh:tipus-contracte>Indefinit</rh:tipus-contracte>
            </rh:dades-laborals>
            <fin:dades-salarials>
                <fin:salari-brut moneda="EUR">45000.00</fin:salari-brut>
                <fin:complements>
                    <fin:complement tipus="antiguitat">1500.00</fin:complement>
                    <fin:complement tipus="responsabilitat">3000.00</fin:complement>
                </fin:complements>
            </fin:dades-salarials>
        </rh:empleat>
        
        <rh:empleat id="EMP002" emp:departament-ref="DEP001">
            <rh:dades-personals>
                <rh:nom>Miquel</rh:nom>
                <rh:cognoms>Ferrer Mas</rh:cognoms>
                <rh:dni>43234567B</rh:dni>
            </rh:dades-personals>
            <rh:dades-laborals>
                <rh:carrec>Programador Sènior</rh:carrec>
                <rh:data-alta>2020-09-01</rh:data-alta>
                <rh:tipus-contracte>Indefinit</rh:tipus-contracte>
            </rh:dades-laborals>
            <fin:dades-salarials>
                <fin:salari-brut moneda="EUR">38000.00</fin:salari-brut>
                <fin:complements>
                    <fin:complement tipus="antiguitat">800.00</fin:complement>
                </fin:complements>
            </fin:dades-salarials>
        </rh:empleat>
        
        <rh:empleat id="EMP003" emp:departament-ref="DEP002">
            <rh:dades-personals>
                <rh:nom>Aina</rh:nom>
                <rh:cognoms>Pons Oliver</rh:cognoms>
                <rh:dni>43345678C</rh:dni>
            </rh:dades-personals>
            <rh:dades-laborals>
                <rh:carrec>Administradora de Sistemes</rh:carrec>
                <rh:data-alta>2019-01-10</rh:data-alta>
                <rh:tipus-contracte>Indefinit</rh:tipus-contracte>
            </rh:dades-laborals>
            <fin:dades-salarials>
                <fin:salari-brut moneda="EUR">42000.00</fin:salari-brut>
                <fin:complements>
                    <fin:complement tipus="antiguitat">1200.00</fin:complement>
                    <fin:complement tipus="disponibilitat">2000.00</fin:complement>
                </fin:complements>
            </fin:dades-salarials>
        </rh:empleat>
        
        <rh:empleat id="EMP004" emp:departament-ref="DEP003">
            <rh:dades-personals>
                <rh:nom>Joana</rh:nom>
                <rh:cognoms>Riera Crespí</rh:cognoms>
                <rh:dni>43456789D</rh:dni>
            </rh:dades-personals>
            <rh:dades-laborals>
                <rh:carrec>Responsable d'Administració</rh:carrec>
                <rh:data-alta>2017-06-20</rh:data-alta>
                <rh:tipus-contracte>Indefinit</rh:tipus-contracte>
            </rh:dades-laborals>
            <fin:dades-salarials>
                <fin:salari-brut moneda="EUR">35000.00</fin:salari-brut>
                <fin:complements>
                    <fin:complement tipus="antiguitat">1800.00</fin:complement>
                </fin:complements>
            </fin:dades-salarials>
        </rh:empleat>
    </rh:plantilla>
    
    <!-- Dades financeres globals -->
    <fin:resum-financer exercici="2024">
        <fin:massa-salarial>
            <fin:total-brut moneda="EUR">160000.00</fin:total-brut>
            <fin:total-complements moneda="EUR">10300.00</fin:total-complements>
            <fin:cost-empresa moneda="EUR">204360.00</fin:cost-empresa>
        </fin:massa-salarial>
    </fin:resum-financer>
    
</emp:empresa>
```

Analitzem l'exemple, part per part. Comencem pels espais de noms utilitzats:

| Prefix | URI                                        | Propòsit                     |
|--------|--------------------------------------------|------------------------------|
| `emp`  | http://exemple.com/empresa                 | Estructura organitzativa     |
| `rh`   | http://exemple.com/recursos-humans         | Dades de personal            |
| `fin`  | http://exemple.com/finances                | Informació econòmica         |
| `xsi`  | http://www.w3.org/2001/XMLSchema-instance  | Atributs estàndard d'esquema |

Punts a destacar:

1. Separació de responsabilitats: Cada namespace agrupa elements d'un domini específic.
2. Referències creuades: L'atribut `emp:departament-ref` vincula empleats amb departaments usant el namespace corresponent.
3. Atributs amb namespace: L'atribut `moneda` no té prefix (és local), mentre que `emp:departament-ref` sí que en té.
4. Mescla de vocabularis: Un empleat (`rh:`) conté dades salarials (`fin:`), mostrant com es poden combinar namespaces.

Alguns namespaces són estàndards àmpliament reconeguts:

| Prefix típic | URI                                         | Ús                                  |
|--------------|---------------------------------------------|-------------------------------------|
| `xml`        | http://www.w3.org/XML/1998/namespace        | Atributs reservats (xml:lang, etc.) |
| `xmlns`      | http://www.w3.org/2000/xmlns/               | Declaració de namespaces            |
| `xsi`        | http://www.w3.org/2001/XMLSchema-instance   | Instàncies d'esquema                |
| `xs`/`xsd`   | http://www.w3.org/2001/XMLSchema            | Definicions d'esquema               |
| `xsl`        | http://www.w3.org/1999/XSL/Transform        | Transformacions XSLT                |
| `html`       | http://www.w3.org/1999/xhtml                | XHTML                               |
| `svg`        | http://www.w3.org/2000/svg                  | Gràfics vectorials                  |
| `soap`       | http://schemas.xmlsoap.org/soap/envelope/   | Serveis web SOAP                    |

D'aquest exemple podem deduir-ne un seguit de bones pràctiques:

1. **Tria URIs estables:** Usa dominis que controlis o URNs per garantir unicitat.
2. **Prefixos significatius:** Usa prefixos curts però descriptius (`rh` millor que `x1`).
3. **Documenta els namespaces:** Indica a la documentació què representa cada namespace.
4. **Consistència:** Usa els mateixos prefixos en tots els documents relacionats.
5. **Evita canviar URIs:** Un canvi d'URI crea un namespace diferent, trencant la compatibilitat.

## Resum

Els namespaces són essencials per fer feina amb documents XML complexos que combinen múltiples vocabularis, car permeten:

* Evitar col·lisions de noms entre elements de fonts diferents.
* Identificar clarament l'origen i propòsit de cada element.
* Combinar estàndards diversos en un sol document.
* Validar selectivament parts del document amb esquemes diferents.

Tot i que afegeixen verbositat al document, els namespaces són imprescindibles en aplicacions reals com serveis web, formats de documents (e.g., OOXML, ODF) i intercanvi de dades entre sistemes.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Resolució de col·lisions de noms**

El següent document XML presenta col·lisions de noms: hi ha elements amb el mateix nom però significats diferents. Reescriu el document usant namespaces per resoldre les ambigüitats.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<projecte>
    <!-- Informació del projecte de software -->
    <nom>Sistema de Gestió Acadèmica</nom>
    <versio>2.1.0</versio>
    <data>2025-01-15</data>
    
    <!-- Equip humà -->
    <equip>
        <membre>
            <nom>Catalina Vidal</nom>
            <rol>Cap de projecte</rol>
        </membre>
        <membre>
            <nom>Miquel Ferrer</nom>
            <rol>Desenvolupador</rol>
        </membre>
    </equip>
    
    <!-- Equipament informàtic assignat -->
    <equip>
        <ordinador>
            <nom>Servidor principal</nom>
            <cpu>Intel Xeon</cpu>
            <ram>64GB</ram>
        </ordinador>
        <ordinador>
            <nom>Estació de treball 1</nom>
            <cpu>AMD Ryzen 9</cpu>
            <ram>32GB</ram>
        </ordinador>
    </equip>
    
    <!-- Calendari -->
    <fita>
        <nom>Lliurament fase 1</nom>
        <data>2025-03-01</data>
    </fita>
    <fita>
        <nom>Lliurament final</nom>
        <data>2025-06-15</data>
    </fita>
</projecte>
```

Requisits:

1. Identifica els elements amb noms repetits però significats diferents.
2. Defineix namespaces apropiats per a cada domini:
   * `http://exemple.com/projecte`: informació general del projecte.
   * `http://exemple.com/recursos-humans`:  equip humà.
   * `http://exemple.com/infraestructura`: equipament informàtic.
   * `http://exemple.com/planificacio`: fites i calendari.

3. Assigna prefixos significatius (per exemple: `proj`, `rh`, `infra`, `plan`).
4. Decideix si usar un namespace per defecte o només prefixos, i justifica la decisió.

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Exercici 2

**Document amb múltiples vocabularis**

Crea un document XML per a una **plataforma de comerç electrònic** que combini tres vocabularis diferents en un sol document. El document ha de representar una comanda completa.

Vocabularis a usar:

1. **Catàleg** (`http://exemple.com/cataleg`): informació dels productes.
   * Producte: id, nom, categoria, preu base.

2. **Client** (`http://exemple.com/clients`): informació del comprador.
   - Client: id, nom complet, email, adreça d'enviament

3. **Transacció** (`http://exemple.com/transaccions`): informació de la compra.
   * Comanda: número, data, estat.
   * Línia de comanda: referència a producte, quantitat, preu unitari, descompte.
   * Totals: subtotal, IVA, total.

Requisits:

1. Usa prefixos per a tots els namespaces (no namespace per defecte).
2. Inclou almenys 2 productes a la comanda.
3. Usa referències creuades entre vocabularis (per exemple, la línia de comanda referencia un producte del catàleg).
4. Els atributs de referència han de portar el prefix del namespace apropiat.

Estructura suggerida:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<comanda xmlns:cat="http://exemple.com/cataleg"
         xmlns:cli="http://exemple.com/clients"
         xmlns:trx="http://exemple.com/transaccions">
    
    <!-- Productes del catàleg referenciats -->
    <cat:productes>
        <cat:producte id="PROD001">...</cat:producte>
    </cat:productes>
    
    <!-- Informació del client -->
    <cli:client id="CLI001">...</cli:client>
    
    <!-- Detalls de la transacció -->
    <trx:comanda numero="COM-2025-001234">
        <trx:linia cat:producte-ref="PROD001">...</trx:linia>
        ...
    </trx:comanda>
    
</comanda>
```

Validació: Comprova que el document és ben format amb `xmllint` o [XML Validation](https://www.xmlvalidation.com/).

### Exercici 3

**Anàlisi d'àmbits de namespaces**

Analitza el següent document XML i respon les preguntes sobre els àmbits dels namespaces.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<arrel xmlns="http://ns-default.com"
       xmlns:a="http://ns-a.com"
       xmlns:b="http://ns-b.com">
    
    <element1>
        <a:subelement>Text A</a:subelement>
        <subelement>Text Default 1</subelement>
    </element1>
    
    <b:element2>
        <b:subelement>Text B</b:subelement>
        <subelement>Text Default 2</subelement>
        
        <intern xmlns="http://ns-intern.com">
            <item>Text Intern</item>
            <a:item>Text A dins Intern</a:item>
        </intern>
        
        <item>Text Default 3</item>
    </b:element2>
    
    <element3 xmlns:a="http://ns-a-alternatiu.com">
        <a:subelement>Text A Alternatiu</a:subelement>
        <element4>
            <a:subelement>Text A Alternatiu 2</a:subelement>
        </element4>
    </element3>
    
    <a:element5>Text A Original</a:element5>
    
</arrel>
```

Preguntes:

1. A quin namespace pertany `<element1>`?
2. A quin namespace pertany `<subelement>` dins de `<element1>`?
3. A quin namespace pertany `<subelement>` dins de `<b:element2>`?
4. A quin namespace pertany `<item>` dins de `<intern>`?
5. A quin namespace pertany `<a:item>` dins de `<intern>`?
6. A quin namespace pertany `<item>` després de tancar `</intern>` (dins de `<b:element2>`)?
7. A quin namespace pertany `<a:subelement>` dins de `<element3>`?
8. A quin namespace pertany `<a:subelement>` dins de `<element4>`?
9. A quin namespace pertany `<a:element5>`?
10. Si afegíssim un atribut `id="001"` (sense prefix) a `<b:element2>`, a quin namespace pertanyeria?

Pregunta addicional: Explica per què les respostes 7 i 9 són diferents, tot i que ambdós elements usen el prefix `a:`.
