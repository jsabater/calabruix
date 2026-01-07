---
title: "XML a la indústria"
date: 2026-01-03
lastmod: 2026-01-03
description: "Usos actuals de l'XML en diferents indústries i sectors, amb exemples realistes de formats XML en configuració de sistemes, intercanvi de dades, documents ofimàtics, serveis web i estàndards sectorials."
summary: "Casos d'ús reals de l'XML: configuració, intercanvi de dades, documents i estàndards sectorials."
categories: ["ensenyament"]
tags: ["xml"]
series: ["XML"]
series_order: 9
weight: 90
slug: us-industria
---

Tot i l'auge de JSON en aplicacions web, XML segueix sent fonamental en molts àmbits per diverses raons:

* Maduresa: Més de 25 anys d'estàndards, eines i documentació.
* Validació: Esquemes XSD per garantir integritat de dades.
* Transformació: XSLT permet convertir dades a qualsevol format.
* Metadades: Suport natiu per a namespaces i atributs complexos.
* Llegat: Molts sistemes crítics es van dissenyar amb XML.

En aquest article s'expliquen alguns usos d'XML a diverses indústries.

## Configuració

Un ús habitual dels documents XML són els fitxers de configuració de sistemes i aplicacions. Exemple:

* Servidors d'aplicacions Java. Els servidors Java EE utilitzen extensivament XML per a configuració.
* Gestió de projectes i dependències. Apache Maven usa XML per a la configuració del projecte Java.
* Configuració de frameworks.

Exemple de fitxer `server.xml` per a Apache Tomcat:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
    <Service name="Catalina">
        <Connector port="8080" protocol="HTTP/1.1"
                   connectionTimeout="20000"
                   redirectPort="8443"/>
        <Engine name="Catalina" defaultHost="localhost">
            <Host name="localhost" appBase="webapps"
                  unpackWARs="true" autoDeploy="true">
            </Host>
        </Engine>
    </Service>
</Server>
```

Exemple de fitxer `pom.xml` per a Apache Maven:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>eu.cifpmoll</groupId>
    <artifactId>projecte-asix</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>5.11.0</version>
            <scope>test</scope>
        </dependency>
    </dependencies>
</project>
```

Exemple de fitxer `applicationContext.xml` per a Spring Framework:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
                           http://www.springframework.org/schema/beans/spring-beans.xsd">
    
    <bean id="dataSource" class="org.apache.commons.dbcp2.BasicDataSource">
        <property name="driverClassName" value="org.postgresql.Driver"/>
        <property name="url" value="jdbc:postgresql://localhost:5432/asix"/>
        <property name="username" value="admin"/>
        <property name="password" value="secret"/>
    </bean>
    
    <bean id="userService" class="eu.cifpmoll.services.UserService">
        <property name="dataSource" ref="dataSource"/>
    </bean>
</beans>
```

## Documents ofimàtics

Des d'Office 2007, els documents de Microsoft Office en format OOXML (`.docx`, `.xlsx`, `.pptx`) són, en realitat, arxius ZIP que contenen fitxers XML. Així mateix, el format Open Document Format (`.odt`, `.ods`, `.odp`) també és basa en XML, seguint la següent estructura pel cas dels fitxers `.odt`:

```
document.odt (ZIP)
├── content.xml           ← Contingut principal
├── styles.xml            ← Estils
├── meta.xml              ← Metadades
├── settings.xml          ← Configuració
├── META-INF/
│   └── manifest.xml
└── Pictures/             ← Imatges incrustades
```

Extracte de `content.xml` d'un fitxer `document.odt`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<office:document-content 
    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
    xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
    <office:body>
        <office:text>
            <text:p text:style-name="Standard">
                Hola, aquest és un paràgraf.
            </text:p>
            <text:h text:style-name="Heading_1" text:outline-level="1">
                Això és un títol
            </text:h>
        </office:text>
    </office:body>
</office:document-content>
```

## Serveis web SOAP

SOAP (Simple Object Access Protocol) és un protocol de missatgeria basat en XML per a serveis web empresarials. Exemple de petició SOAP:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:ws="http://exemple.com/serveis">
    <soap:Header>
        <ws:Authentication>
            <ws:Token>bearer-token-super-secret-abc123xyz</ws:Token>
        </ws:Authentication>
    </soap:Header>
    <soap:Body>
        <ws:GetAlumne>
            <ws:Id>A001</ws:Id>
        </ws:GetAlumne>
    </soap:Body>
</soap:Envelope>
```

Exemple de resposta SOAP:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:ws="http://exemple.com/serveis">
    <soap:Body>
        <ws:GetAlumneResponse>
            <ws:Alumne>
                <ws:Id>A001</ws:Id>
                <ws:Nom>Maria</ws:Nom>
                <ws:Cognoms>García López</ws:Cognoms>
                <ws:Email>maria.garcia@cifpmoll.eu</ws:Email>
            </ws:Alumne>
        </ws:GetAlumneResponse>
    </soap:Body>
</soap:Envelope>
```

Quan es fa feina amb SOAP, també es sol fer feina amb WSDL (Web Services Description Language), el qual descriu la interfície d'un servei web SOAP. Per exemple:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
             xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
             xmlns:tns="http://exemple.com/serveis"
             name="AlumneService"
             targetNamespace="http://exemple.com/serveis">
    
    <message name="GetAlumneRequest">
        <part name="id" type="xsd:string"/>
    </message>
    
    <message name="GetAlumneResponse">
        <part name="alumne" type="tns:Alumne"/>
    </message>
    
    <portType name="AlumnePortType">
        <operation name="GetAlumne">
            <input message="tns:GetAlumneRequest"/>
            <output message="tns:GetAlumneResponse"/>
        </operation>
    </portType>
    
    <service name="AlumneService">
        <port name="AlumnePort" binding="tns:AlumneSoapBinding">
            <soap:address location="http://exemple.com/ws/alumne"/>
        </port>
    </service>
</definitions>
```

## Sindicació de continguts

RSS (Really Simple Syndication) permet distribuir continguts actualitzats (notícies, blogs, podcasts). I Atom és una alternativa més moderna a RSS. Exemple de fitxer XML al qual ens subscriuríem:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
    <title>Blog ASIX - CIFP Francesc de Borja Moll</title>
    <link href="https://cifpmoll.eu/asix/blog"/>
    <link rel="self" href="https://cifpmoll.eu/asix/blog/feed.atom"/>
    <id>urn:uuid:blog-asix-cifpmoll</id>
    <updated>2025-03-15T10:00:00+01:00</updated>
    
    <entry>
        <title>Introducció a Docker</title>
        <link href="https://cifpmoll.eu/asix/blog/intro-docker"/>
        <id>urn:uuid:intro-docker-2025</id>
        <updated>2025-03-15T10:00:00+01:00</updated>
        <summary>Aprèn els conceptes bàsics de contenidors amb Docker.</summary>
        <author>
            <name>Equip ASIX</name>
        </author>
    </entry>
</feed>
```

## Gràfics vectorials

SVG (Scalable Vector Graphics) és un format XML per a gràfics vectorials. SVG és àmpliament utilitzat per a logotips i icones en webs, infografies interactives, visualització de dades (e.g., `D3.js`, o Data Driven Documents.js) i mapes vectorials. Exemple de fitxer:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" 
     width="200" height="200" 
     viewBox="0 0 200 200">
    
    <!-- Fons -->
    <rect width="200" height="200" fill="#f0f0f0"/>
    
    <!-- Cercle -->
    <circle cx="100" cy="80" r="50" fill="#3498db"/>
    
    <!-- Text -->
    <text x="100" y="160" 
          text-anchor="middle" 
          font-family="Arial" 
          font-size="20" 
          fill="#2c3e50">
        ASIX
    </text>
    
    <!-- Línia -->
    <line x1="30" y1="180" x2="170" y2="180" 
          stroke="#2c3e50" stroke-width="2"/>
</svg>
```

## Estàndards sectorials

Diverses indústries, normalment altament regulades, fan un ús extensiu de l'ecosistema XML. En aquests sectors, els errors tenen conseqüències greus: un error en un historial clínic pot afectar el tractament d'un pacient, una factura mal formada pot provocar problemes legals o fiscals, i un informe financer incorrecte pot tenir implicacions legals. Per això, la capacitat de validació estricta de l'XML és convenient, sinó fonamental.

### Sanitat

Dins el sector de la sanitat, HL7 CDA (Clinical Document Architecture) és l'estàndard per a documents i historials clínics.

Imagina el problema: un pacient visita un hospital a Palma, però té un accident a Barcelona i necessita atenció urgent. Els metges de Barcelona necessiten accedir al seu historial, que està en un sistema informàtic completament diferent. HL7 CDA resol això definint exactament com s'ha d'estructurar la informació clínica perquè qualsevol sistema la pugui llegir.

Exemple de document:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ClinicalDocument xmlns="urn:hl7-org:v3">
    <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
    <id root="2.16.840.1.113883.19.4" extension="c266"/>
    <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" 
          displayName="Summarization of Episode Note"/>
    <title>Informe d'alta hospitalària</title>
    <effectiveTime value="20250315"/>
    
    <recordTarget>
        <patientRole>
            <id extension="12345678A" root="1.3.6.1.4.1.19126.3"/>
            <patient>
                <name>
                    <given>Maria</given>
                    <family>García López</family>
                </name>
                <birthTime value="19850315"/>
            </patient>
        </patientRole>
    </recordTarget>
    
    <component>
        <structuredBody>
            <component>
                <section>
                    <title>Diagnòstic</title>
                    <text>Bronquitis aguda</text>
                </section>
            </component>
        </structuredBody>
    </component>
</ClinicalDocument>
```

Fixa't en els codis numèrics com `2.16.840.1.113883.6.1`: són identificadors únics globals (OIDs) que garanteixen que no hi hagi ambigüitat. El codi `34133-9` identifica exactament el tipus de document segons el sistema de codificació LOINC, usat mundialment. Això permet que un sistema a Japó interpreti correctament un document creat a Espanya.

### Finances

Dins el sector de les finances, XBRL (eXtensible Business Reporting Language) s'usa per a informes financers.

Les empreses cotitzades en borsa han de presentar informes financers als reguladors (com la CNMV a Espanya o la SEC als EUA). Abans d'XBRL, cada empresa enviava PDFs o fulls de càlcul, i els analistes havien d'introduir les dades manualment per comparar empreses. XBRL permet que les dades siguin llegibles per màquines: un programa pot descarregar els informes de 100 empreses i comparar-les automàticament.

Exemple de document:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xbrl xmlns="http://www.xbrl.org/2003/instance"
      xmlns:iso4217="http://www.xbrl.org/2003/iso4217"
      xmlns:emp="http://exemple.com/xbrl/empresa">
    
    <context id="ctx2024">
        <entity>
            <identifier scheme="http://www.cif.es">B07123456</identifier>
        </entity>
        <period>
            <startDate>2024-01-01</startDate>
            <endDate>2024-12-31</endDate>
        </period>
    </context>
    
    <unit id="EUR">
        <measure>iso4217:EUR</measure>
    </unit>
    
    <emp:Ingressos contextRef="ctx2024" unitRef="EUR" decimals="2">
        1500000.00
    </emp:Ingressos>
    
    <emp:Despeses contextRef="ctx2024" unitRef="EUR" decimals="2">
        1200000.00
    </emp:Despeses>
    
    <emp:BeneficiNet contextRef="ctx2024" unitRef="EUR" decimals="2">
        300000.00
    </emp:BeneficiNet>
</xbrl>
```

El més interessant d'XBRL és com associa cada xifra al seu context. L'element `<context>` defineix de quina empresa i de quin període són les dades. Així, quan un analista compara els ingressos de dues empreses, el sistema pot verificar automàticament que està comparant el mateix període fiscal. Els atributs `contextRef` i `unitRef` enllacen cada valor amb el seu context i moneda, evitant errors com comparar euros amb dòlars.

### Comerç electrònic

Dins el sector del comerç electrònic, UBL (Universal Business Language) estandarditza documents comercials.

Quan una empresa gran com El Corte Inglés o Amazon rep milers de factures diàries de proveïdors, no és viable processar-les manualment. UBL defineix exactament com ha de ser una factura, una comanda o un albarà perquè els sistemes ERP dels compradors i venedors es puguin comunicar automàticament. Una factura UBL enviada per un proveïdor a Alemanya pot ser processada automàticament pel sistema d'una empresa a Espanya.

Exemple de document:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
         xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
         xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
    
    <cbc:ID>FAC-2025-001234</cbc:ID>
    <cbc:IssueDate>2025-03-15</cbc:IssueDate>
    <cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>
    <cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>
    
    <cac:AccountingSupplierParty>
        <cac:Party>
            <cac:PartyName>
                <cbc:Name>TechSolutions Balears S.L.</cbc:Name>
            </cac:PartyName>
            <cac:PartyTaxScheme>
                <cbc:CompanyID>B07123456</cbc:CompanyID>
            </cac:PartyTaxScheme>
        </cac:Party>
    </cac:AccountingSupplierParty>
    
    <cac:InvoiceLine>
        <cbc:ID>1</cbc:ID>
        <cbc:InvoicedQuantity unitCode="EA">10</cbc:InvoicedQuantity>
        <cbc:LineExtensionAmount currencyID="EUR">500.00</cbc:LineExtensionAmount>
        <cac:Item>
            <cbc:Name>Servei de manteniment mensual</cbc:Name>
        </cac:Item>
    </cac:InvoiceLine>
    
    <cac:LegalMonetaryTotal>
        <cbc:TaxExclusiveAmount currencyID="EUR">500.00</cbc:TaxExclusiveAmount>
        <cbc:PayableAmount currencyID="EUR">605.00</cbc:PayableAmount>
    </cac:LegalMonetaryTotal>
</Invoice>
```

Fixa't en els namespaces: `cac` (Common Aggregate Components) agrupa elements complexos com les parts implicades, mentre que `cbc` (Common Basic Components) conté elements simples com dates i imports. Aquesta separació permet reutilitzar components entre diferents tipus de documents (factures, comandes, albarans). El codi `380` a `InvoiceTypeCode` és un codi estàndard UN/CEFACT que identifica el document com una factura comercial.

### Administració electrònica

A Espanya, la factura electrònica amb l'Administració pública utilitza el format Factura-e.

Des de 2015, qualsevol empresa que facturi a l'Administració pública espanyola (ajuntaments, ministeris, hospitals públics...) ha de fer-ho obligatòriament en format electrònic. Factura-e és el format oficial. Això ha eliminat milions de factures en paper, ha reduït errors i ha accelerat els pagaments. El sistema FACe (Punt General d'Entrada de Factures Electròniques) rep les factures i les distribueix automàticament a l'organisme corresponent.

Exemple de document:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<fe:Facturae xmlns:fe="http://www.facturae.es/Facturae/2014/v3.2.1/Facturae">
    <FileHeader>
        <SchemaVersion>3.2.1</SchemaVersion>
        <Modality>I</Modality>
        <InvoiceIssuerType>EM</InvoiceIssuerType>
    </FileHeader>
    <Parties>
        <SellerParty>
            <TaxIdentification>
                <PersonTypeCode>J</PersonTypeCode>
                <ResidenceTypeCode>R</ResidenceTypeCode>
                <TaxIdentificationNumber>B07123456</TaxIdentificationNumber>
            </TaxIdentification>
            <LegalEntity>
                <CorporateName>TechSolutions Balears S.L.</CorporateName>
            </LegalEntity>
        </SellerParty>
    </Parties>
    <Invoices>
        <Invoice>
            <InvoiceHeader>
                <InvoiceNumber>2025/001234</InvoiceNumber>
                <InvoiceDocumentType>FC</InvoiceDocumentType>
            </InvoiceHeader>
            <InvoiceTotals>
                <TotalGrossAmount>500.00</TotalGrossAmount>
                <TotalTaxOutputs>105.00</TotalTaxOutputs>
                <TotalExecutableAmount>605.00</TotalExecutableAmount>
            </InvoiceTotals>
        </Invoice>
    </Invoices>
</fe:Facturae>
```

El camp `PersonTypeCode` amb valor `J` indica persona jurídica (empresa), mentre que `F` seria persona física (autònom). `ResidenceTypeCode` amb valor `R` indica resident a Espanya. Aquests codis permeten que el sistema validi automàticament que el NIF correspon al tipus d'entitat declarat. A més, les factures Factura-e han d'anar signades digitalment amb certificat electrònic, cosa que garanteix l'autenticitat i la integritat del document.

## Per què XML en aquestes indústries?

Per què es tria XML en aquests casos i no en altres? La resposta té a veure amb les necessitats específiques d'aquests sectors:

1. **Validació estricta:** Un error en una factura o un historial clínic pot tenir conseqüències legals o mèdiques. Els esquemes XSD permeten validar automàticament que tots els camps obligatoris hi són, que els formats són correctes (dates, imports, codis) i que les relacions entre elements són vàlides. Això és molt més difícil d'aconseguir amb JSON.
2. **Interoperabilitat regulada:** Aquests sectors tenen reguladors (Hisenda, Sanitat, CNMV) que exigeixen formats estàndard. XML permet definir vocabularis molt precisos amb namespaces, evitant ambigüitats entre sistemes de diferents fabricants o països.
3. **Auditoria i traçabilitat:** En cas de litigi o inspecció, els documents XML són llegibles tant per màquines com per humans. Un inspector pot obrir una factura Factura-e amb un editor de text i entendre-la, cosa més difícil amb formats binaris.
4. **Signatura digital:** XML té estàndards madurs per a signatura digital (XMLDSig) i xifratge (XML Encryption). Una factura electrònica signada digitalment té validesa legal equivalent a una factura en paper signada.
5. **Longevitat:** Aquests documents s'han de conservar durant anys (les factures, 4 anys per Hisenda; els historials clínics, fins a 15 anys o més). XML, com a format de text pla basat en estàndards oberts, garanteix que els documents seran llegibles dins de dècades.

L'XML no és la solució per a tot, però continua sent l'opció preferida quan cal robustesa, validació i interoperabilitat en entorns on els errors tenen conseqüències greus.
