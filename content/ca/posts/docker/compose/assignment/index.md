---
title: "Pràctica introductòria a Docker Compose"
date: 2026-01-02
lastmod: 2026-01-02
description: ""
summary: ""
categories: ["virtualisation"]
tags: ["docker", "compose"]
series: ["Docker Compose"]
series_order: 10
weight: 100
slug: practica
draft: true
---

A l'empresa on fem feina, després de fer un prototipus del nou entorn de desenvolupament i arrel del feedback rebut, ens han demanat una versió lleguremanet evolucionada de l'arquitectura web usant Docker Compose. Aquesta nova iteració serà usada com a referència de cara al nou entorn de producció.

La proposta d'arquitectura consta de 5 blocs, on cadascun representa un conjunt de serveis o contenidors Docker independents

* Balancejador de càrrega.
* Front-end.
* Back-end.
* Aplicació heretada.
* Aplicació d'intel·ligència de negoci.

## Balancejador de càrrega

Aquest bloc inclou un balancejador de càrrega (en anglès, "load balancer"), que actua com a punt d'entrada de les peticions que arriben al nostre web de reserves. Aquest servidor té com a missió repartir la *càrrega dinàmica* (PHP) entre els nostres servidors d'aplicacions i la *càrrega estàtica* (imatges i documents) cap al magatzem d'objectes S3.

A més de la IP privada corresponent, el balancejador de càrrega haurà de tenir una "IP pública" que, a efectes d'aquesta pràctica, serà de la xarxa local de l'ordinador de l'alumne. També a efectes d'aquesta pràctica, escoltarà les peticions al port 80.

El balancejador de càrrega podrà estar basat en [NGINX](https://nginx.org/), [HA Proxy](https://haproxy.org/) o [Apache](https://httpd.apache.org/) (amb `mod_proxy` i `mod_proxy_balancer`), entre d'altres.

## Front-end

El nostre front-end estarà format per tres servidors Apache, amb el mòdul de PHP, on hi executarem la nostra nova aplicació web de reserves.

A més, necessitarem un contenidor d'objectes compatible amb S3, que podrà estar basat en [Garage](https://garagehq.deuxfleurs.fr/), [MinIO](https://min.io/) o [SeaweedFS](https://seaweedfs.com/), entre d'altres. Aquest contenidor serà accessible tant per part dels servidors del front-end com pel balancejador de càrrega.

## Back-end

El back-end tendrà els següents contenidors:

* Dos servidors PostgreSQL, un per escriptures i un altre per a lectures, sincronitzats, que actuaran com a servidors de base de dades principals del nostre nou aplicació web.
* Un contenidor amb Redis, per a la caché de dades.
* Un contenidor amb RabbitMQ, per a la gestió de cues de tasques.
* Un contenidor amb un programa que consumirà (processarà i executarà) les tasques del RabbitMQ.

Quan a l'agent consumidor de tasques, s'ha pres la decisió de permetre a l'equip de desenvolupament usar tant Java com PHP per a implementar-los, sempre seguint les recomanacions del propi web oficial:

* [RabbitMQ Java Stream tutorial](https://www.rabbitmq.com/tutorials/tutorial-one-java-stream)
* [RabbitMQ PHP tutorial](https://www.rabbitmq.com/tutorials/tutorial-one-php)

S'espera que els contenidors dels agents, en arrencar, executing l'agent, bé usant Java, bé PHP. La configuració d'aquest procés agent és opcional i servirà per a millorar nota.

Els servidors Apache necessitaran poder accedir al PostgreSQL per a la gestió de dades, al Redis per a la gestió de la caché i al RabbitMQ per a crear-hi tasques.

L'agent consumidor de tasques tendrà accés al PostgreSQL per a la gestió de dades, al Redis per a la gestió de la caché i al RabbitMQ per a consumir tasques.

## Intel·ligència de negoci

El personal directiu, de màrqueting i de vendes fa servir una aplicació d'intel·ligència de negoci (en anglés, "business intelligence") anomenada [Metabase](https://metabase.com/). Aquesta eina, basada en Java, utilitza PostgreSQL com a base de dades.

Per a evitar la saturació de la base de dades principal de l'aplicació de reserves de l'empresa, es farà un desenvolupament que duplicarà algunes dades des de la base principal cap a la base de dades de Metabase. Aquest desenvolupament es farà amb procediments emmagatzemats de PostgreSQL i, per tant, només caldrà habilitar la comunicació directa entre aquests dos contenidors.

Per tant, aquest bloc comptarà amb dos contenidors:

* Un servidor de Metabase, que ja inclou el servidor Jetty com a servidor web i d'aplicacions.
* Un servidor PostgreSQL, com a base de dades de l'aplicació Metabase.

## Aplicació heretada

La nostra aplicació antiga (en anglès, "legacy application"), basada en Java i que usa Apache Tomcat com a servidor d'aplicaciós i MariaDB com a base de dades, tendrà els següents contenidors:

* Un servidor d'aplicacions Tomcat, on hi executarem la nostra aplicació web antiga.
* Un servidor de base de dades MariaDB.

Aquesta aplicació es consulta de manera puntual, tant des de la nova aplicació web com des de l'eina d'intel·ligència de negoci. Afortunadament, aquest aplicació ja tenia una API de serveis web, que s'utilitza per a recuperar algunes dades i executar alguns processos de càlcul que no s'han migrat al nou sistema.

## Tasques

Tasques a dur a terme:

1. A partir dels requeriments, és a dir, l'enunciat de la pràctica, crea un diagrama amb la teva proposta de contenidors, ports, xarxes i volums. Pots usar l'eina que vulguis.
2. Disenya un projecte amb un subdirectori `docker/`, que contendrà els `Dockerfiles` necessaris per a cobrir els requeriments, i un subdirectori `src/`, que contendrà els fitxers fonts del teu projecte, que usaràs a les instruccions `COPY`, `ADD`, `ENTRYPOINT` o `CMD`. A l'arrel del projecte, crea el teu fitxer `docker-compose.yml`.
3. Redacta una documentació que expliqui:
   * Aquelles decisions que, a partir de l'enunciat, has pres a l'hora d'implementar la solució, especialment en termes d'imatges, volums i xarxes. No cal repetir el que ja diu l'enunciat.
   * L'estructura del teu projecte. És important que raonis les teves decisions a l'hora de determinar-ne la composició. Assegura't de ser clar i concís amb la terminologia i amb la nomenclatura que hagis decidit usar (per exemple, el nom de les xarxes).
   * Explica les ordres `docker compose` que són necessàries per a reproduir l'entorn en un ordinador que no sigui el teu. Si aquestes instruccions no funcionen, no es podrà corregir la pràctica.
4. Usant comentaris, documenta in situ les instruccions que decideixis usar als `Dockerfiles`.
5. Registra't un compte a [Docker Hub](https://hub.docker.com/) usant el teu correu electrònic del centre i puja-hi les imatges que hagis generat [^1].

[^1]: Recerca les ordres `docker login` i `docker push`.

Per ajudar en la concepció del diagrama de l'arquitectura, pots tenir en compte les següents consideracions:

* Com segmentaràs les xarxes? Quines xarxes ad-hoc, o selectives, necessitaràs?
* Quines xarxes assignaràs a quins contenidors?
* Quins contenidors tendran accés a més d'una xarxa?
* Com assignaràs la IP pública al balancejador de càrrega?
* Quins contenidors necessitaran persistència de dades?
* Quins contenidors hauran de compartir volums o dades?
* Quins contenidors necessitaran d'una configuració específica?
* Com garantiràs que les dependències d'arrencada?
* Quins verificacions d'estat (en anglès, "health checks") consideres imprescindibles i quins consideres opcionals?

És requisit d'aquesta pràctica usar un únic fitxer `docker-compose.yml` i els fitxers `Dockerfile` que consideris necessaris.

## Entregables

Heu d'entregar els següents fitxers a través de l'aula virtual de l'assignatura:

1. El diagrama de l'arquitectura, en format original i exportat a imatge (PNG, WebP o semblant). Si uses una eina en línia, registra't un compte usant el teu correu electrònic del centre i inclou un enllaç al document.
2. Fitxer de text `README.md` dins l'arrel del projecte, en format Markdown, amb els continguts descrits a l'apartat anterior. Aquest document ha de contenir la informació justa i necessària. No cal repetir allò que és als apunts. Sigues concís, precís i breu.
3. El contingut del projecte arxivat en format ZIP.
4. Enllaç al compte a Docker Hub amb les imatges resultants dels `Dockerfiles`.

A efectes d'aquesta pràctica, n'hi ha prou que incloguis un petit script PHP a cada servidor Apache, que mostri la sortida de la instrucció `phpinfo()`. Així mateix, de cara a l'aplicació antiga basada en Java, és suficient crear un fitxer `info.jsp` que mostri algunes informacions de sistema. Aquí en tens un exemple, que pots prendre com a referència:

```jsp
<%@ page import="java.util.Properties" %>
<%
    Properties props = System.getProperties();
    out.println("<h2>System Properties</h2>");
    for (String key : props.stringPropertyNames()) {
        out.println(key + " = " + props.getProperty(key) + "<br>");
    }
%>
```

## Quan al RabbitMQ

Per aquesta pràctica, és suficient que el contenidor amb el RabbitMQ arrenqui el servei. Quan al contenidor amb l'agent o dèmon que processa les tasques de les cues del RabbitMQ, no és necessària la seva implementació, però t'ajudarà a pujar nota.

## Rúbrica

| **Criteri**                                | **Descripció**                                                                                                                                                         | **Punts (màx.)** | **Observacions / Què mirar**                                                                                                                                                                                                                                                        |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Diagrama de l'arquitectura          | Representa correctament tots els contenidors, xarxes, ports i volums, amb relacions coherents i llegibles.                                                             | 0–2          | 2 → Diagrama complet, clar i ben justificat.<br>1 → Petites omissions o incoherències.<br>0 → Incomplet, erroni o inexistent.                                                                                                                                                       |
| Estructura del projecte             | Estructura de directoris (`docker/`, `src/`, etc.) coherent i ordenada. Inclou documentació (`README.md`) clara, ben redactada i amb cura formal.                      | 0–3          | 3 → Organització impecable i coherent; documentació clara, amb explicació de decisions i instruccions d'execució correctes.<br>2 → Correcte amb petites mancances o errors formals.<br>1 → Estructura confusa o documentació incompleta.<br>0 → Desorganitzat o sense documentació. |
| Execució i reproduïbilitat          | Les instruccions permeten executar i reproduir l'entorn completament amb Docker Compose.                                                                             | 0–3          | 3 → Tot funciona segons el descrit; l'entorn es pot reproduir sense errors.<br>2 → Funciona parcialment o amb petits ajustos.<br>1 → Només arrenca una part o requereix molta intervenció manual.<br>0 → No es pot executar.                                                        |
| Qualitat del `doker-compose.yml`, dels Dockerfiles i les imatges | `docker-compose.yml` i `Dockerfiles` correctes, eficients i documentats. Bon ús d'instruccions, bones pràctiques i publicació correcta d'imatges al Docker Hub. | 0–2          | 2 → `docker-compose.yml` i `Dockerfiles` nets, ben estructurats i funcionals; imatges publicades i etiquetades correctament.<br>1 → Funciona però amb errors o manca d'optimització; publicació parcial o etiquetatge confús.<br>0 → Errors greus o falta d'imatges.                                         |
