---
title: "Pràctica final de desplegament"
date: 2026-06-11
lastmod: 2026-06-13
description: "Desplegament complet d'una aplicació web amb Docker Compose, amb proxy invers, API, base de dades, cache i cues de missatges"
summary: "Desplegament complet d'una aplicació web amb proxy invers, API, base de dades, cache i cues de missatges"
categories: ["teaching"]
tags: ["docker", "compose", "assignment"]
series: ["Docker Compose"]
series_order: 10
weight: 100
slug: practica
---

En aquesta pràctica final, desplegareu l'aplicació **Sports Club**, una API REST desenvolupada amb Django Ninja que gestiona un petit club d'atletisme, i afegireu nous serveis, aplicant tots els conceptes treballats durant la sèrie de Docker Compose per crear un entorn de desplegament complet, segur i mantenible.

L'aplicació [Sports Club](https://github.com/jsabater/sportsclub) és un projecte de codi obert, disponible a Github, específicament creat perquè l'alumnat disposi d'una API REST per fer pràctiques de front-end, contenidors i ciberseguretat. Haureu de fer un *fork* del repositori i fer feina sobre la vostra còpia.


## Arquitectura requerida

Heu de desplegar un entorn amb els següents serveis:

**Serveis principals**

1. **Traefik**: Proxy invers que encamina les peticions als serveis corresponents.
2. **NGINX**: Serveix el *front-end* estàtic (HTML/CSS/JS amb HTMX) que consumeix l'API REST.
3. **API REST**: L'aplicació Django Ninja **Sports Club** que actua com a *back-end* (un únic servei)
4. **PostgreSQL**: Base de dades principal de l'aplicació.
5. **Valkey**: Cache de dades.
6. **RabbitMQ**: Broker de missatges per a tasques asíncrones.
7. **Worker**: Consumidor de missatges de RabbitMQ (se us proporciona el codi).

**Serveis de desenvolupament**

8. **Adminer**: Interfície web per gestionar PostgreSQL.
9. **Mailpit**: Servidor SMTP de proves per capturar emails.


## Metodologia de feina

A diferència dels exercicis que hem anat fent al llarg d'aquesta sèrie, en aquesta pràctica partim d'un projecte existent, que funciona de forma autònoma i que necessitam modificar per adaptar-lo als requeriments. Això no només vol dir afegir serveis, sinó també modificar-los i, si escau, eliminar-los.


### Aproximació recomanada

La manera més directa de realitzar aquesta pràctica és fer feina sobre el vostre *fork* del repositori `sportsclub`:

1. Feu un *fork* del repositori [sportsclub](https://github.com/jsabater/sportsclub) al vostre compte.
2. Clonau el *fork* al vostre ordinador.
3. Segui les instruccions d'instal·lació del projecte que trobareu al `README.md`.
4. Ampliau i millorau el `compose.yaml` i els `Dockerfiles` al directori `docker/` existent.
5. Afegiu els nous serveis (Traefik, Valkey, RabbitMQ, worker, etc.) al mateix projecte, modificant els existents segons considereu necessari.

Aquesta aproximació reflecteix un escenari real: teniu un projecte existent i l'heu de preparar per a un desplegament complet.

> Fixau-vos que heretau un repositori que usa blue/green deployment però l'arquitectura requerida usa un únic servei de back-end.

Opcionalment, afegiu el domini `sportsclub.local` al vostre `/etc/hosts` i configurau el proxy invers amb aquest domini en comptes de `localhost`.


### Alternatives

Si preferiu mantenir una separació més clara entre l'aplicació i la infraestructura, podeu explorar altres aproximacions:

- **Repositoris separats amb xarxes compartides**: Manteniu `sportsclub` com a repositori independent, aplicant-hi les millores pertinents i els canvis necessaris, i creau un segon repositori per a la infraestructura, compartint xarxes Docker entre ambdós.
- **Comunicació via host**: Ídem, amb dos repositoris completament independents, però establint la comunicació a través de la xarxa de l'amfitrió, simulant serveis distribuïts.

Aquestes alternatives afegeixen complexitat i requereixen coordinar configuracions entre repositoris. Si optau per una d'elles, documentau-ho adequadament al `PRACTICA.md`.


## Tasques

Com a part d'aquesta pràctica, heu de dur a terme les següents tasques.

### Disseny de l'arquitectura

Abans d'escriure cap fitxer de configuració, dissenyau l'arquitectura:

1. Creau un **diagrama** que representi:
   - Tots els contenidors i les seves imatges base
   - Les xarxes i quins serveis pertanyen a cadascuna
   - Els volums i quins serveis els utilitzen
   - Els ports exposats i el flux de peticions
   - Les dependències entre serveis

2. A la documentació haureu de justificar les vostres decisions:
   - Per què heu segmentat les xarxes d'aquesta manera?
   - Quins serveis necessiten accés a múltiples xarxes i per què?
   - Quines dades necessiten persistència?

Podeu usar l'eina de diagrama com a codi que vulgueu, e.g., D2, Mermaid, PlantUML, etc. Haureu d'entregar el codi font del diagrama així com una imatge amb l'exportació.

### Configuració de l'entorn

El repositori `sportsclub` ja conté una estructura bàsica. Haureu d'ampliar-la fins a tenir:

```
sportsclub/
├── compose.yaml              # Ampliat amb tots els serveis
├── compose.override.yaml     # Opcional: si s'usa l'estratègia d'override
├── .env.example              # Ampliat amb totes les variables
├── .gitignore                # Revisat per incloure fitxers i directoris
├── docs/
│   ├── arquitectura.mmd      # O .d2, .puml, etc., segons l'eina usada
│   ├── arquitectura.png      # Exportació del diagrama
│   └── PRACTICA.md           # Fitxer amb la documentació de la pràctica
├── docker/
│   ├── app/
│   │   └── Dockerfile        # Existent: corregir i millorar, si escau
│   ├── frontend/
│   │   ├── Dockerfile        # Nou: Dockerfile del front-end
│   │   └── index.html        # Proporcionat
│   ├── postgres/
│   │   └── Dockerfile        # Existent: actualitzar, si escau
│   └── worker/
│       ├── Dockerfile        # Nou: Dockerfile del worker
│       ├── package.json      # Proporcionat
│       └── worker.js         # Proporcionat
├── README.md                 # Fitxer original que no s'ha de modificar
└── sportsclub/               # Existent: codi Django
    └── ...
```

Requisits:

- Decidiu on i com emmagatzemar les credencials i configuracions sensibles.
- Investigau la documentació de cada servei per determinar quines variables d'entorn són necessàries.
- Actualitzau la plantilla `.env.example` perquè altres desenvolupadors puguin configurar l'entorn.
- Justificau les vostres decisions al fitxer `PRACTICA.md`, fent referència als conceptes vists durant el curs.

### Xarxes i aïllament

Dissenyau i implementau una estratègia de xarxes que:

- Aïlli els serveis segons les seves necessitats de comunicació
- Segueixi el principi de mínim privilegi
- Permeti el flux de peticions des del proxy fins als serveis finals

### Volums i persistència

Identificau quins serveis necessiten persistència de dades i configurau volums amb nom adequats. Justificau les vostres decisions.

### Healthchecks i dependències

Configureu *healthchecks* per a **tots** els serveis:

- Investigau quina és la manera recomanada de verificar l'estat de cada servei.
- Configurau les dependències entre serveis de manera que cap servei arrenqui abans que les seves dependències estiguin realment disponibles.
- Triau la condició de dependència adequada per a cada cas i justificau la vostra elecció.

> L'API de Sports Club disposa d'un endpoint `/api/v1/health` per verificar-ne l'estat.

### Dockerfile de l'API

El repositori `sportsclub` conté un `Dockerfile` amb **errors intencionats i males pràctiques**. Heu de:

1. Identificar els problemes.
2. Corregir-los aplicant les bones pràctiques treballades al curs.
3. Documentar al `PRACTICA.md` quins problemes heu trobat i com els heu solucionat.

### Extensions YAML

Usau extensions YAML per evitar la repetició de configuracions comunes entre serveis. Identificau quines configuracions es repeteixen i extraieu-les a blocs reutilitzables.

### Límits de recursos

Investigau els requisits de recursos de cada servei i definiu límits de CPU i memòria adequats. Documentau al `PRACTICA.md`:

- Quins límits heu definit per a cada servei
- Com heu arribat a aquests valors (fonts consultades, proves realitzades)

### Perfils i entorns

Configurau l'entorn perquè:

- En mode "producció", només s'arrenquin els serveis principals.
- En mode "desenvolupament", també s'arrenquin les eines de desenvolupament:
  - Adminer
  - Mailpit
  - Worker (consumidor de RabbitMQ)

Usau la característica de perfils de Docker Compose o l'estratègia de múltiples fitxers Compose que considereu més adequada.


### Configuració del proxy

Configurau Traefik com a proxy invers amb:

- Descobriment automàtic de serveis
- Routing basat en *path* (decidiu vosaltres l'esquema de rutes)
- *Healthcheck* configurat


### Worker de RabbitMQ

Se us proporciona un *worker* en [Node.js](https://nodejs.org/) que consumeix missatges de [RabbitMQ](https://www.rabbitmq.com/). Heu de:

1. Crear el `Dockerfile` per al *worker*.
2. Configurar-lo correctament al `compose.yaml`.
3. Assegurar-vos que les dependències i *healthchecks* estan ben configurats.


### Front-end

Se us proporciona un fitxer `docker/frontend/index.html` amb [HTMX](https://htmx.org/) que consumeix l'API. Configurau NGINX per servir aquest fitxer i encaminar les peticions a l'API quan correspongui.

Functionalitats:

- *Health check* a `/api/v1/core/health` amb indicadors visuals
- Llistar atletes amb taula que mostra identificador públic, nom i dorsal
- Veure detall d'un atleta (inclou el `public_id` per a RabbitMQ)
- Crear atleta amb formulari (nom, cognoms, email, dorsal)
- Editar atleta amb `PATCH` (només camps modificats)
- Eliminar atleta amb modal de confirmació

Aspectes tècnics:

- [HTMX](https://htmx.org/) per carregar la llista inicial i refrescar
- *Fetch* API per a les operacions [*](CRUD) (més control sobre els formularis)
- Missatges de feedback d'èxit i d'error
- El `public_id` és visible a la taula i al detall per facilitar l'ús amb RabbitMQ

> A través d'aquest front-end podreu obtenir un llistat d'atletes on consultar els identificadors públics que necessitareu per a ficar tasques a la cua de RabbitMQ.


## Mailpit

[Mailpit](https://mailpit.axllent.org/) és un servidor SMTP de proves que captura tots els emails enviats i els mostra en una interfície web. És molt útil durant el desenvolupament per verificar que els emails s'envien correctament sense necessitat de configurar un servidor de correu real ni arriscar-se a enviar correus electrònics a adreces reals.

En aquest projecte, Mailpit rep els emails que envia el worker quan processa tasques de la cua.

Mailpit només està disponible quan s'arrenca l'entorn amb el perfil `dev`:

```bash
docker compose --profile dev up -d
```

La interfície web és accessible a través del [port 8025 exposat directament al localhost](http://localhost:8025).

> Mailpit no passa per Traefik perquè és una eina de desenvolupament que no hauria d'estar exposada en producció. L'accés directe via port simula un escenari on les eines d'administració estan en una xarxa separada.


## RabbitMQ

[RabbitMQ](https://www.rabbitmq.com/) és un broker de missatges que implementa el protocol [*](AMQP). Permet desacoblar els components d'una aplicació mitjançant cues de missatges, de manera que un servei pot publicar tasques i un altre les pot consumir de forma asíncrona.

A aquest projecte, RabbitMQ gestiona la cua `tasks` on es publiquen les tasques que el *worker* ha de processar.

La interfície de gestió de RabbitMQ és accessible a través del [port 15672 exposat directament al localhost](http://localhost:15672). Les credencials per accedir a la interfície s'obtenen de les variables d'entorn `RABBITMQ_DEFAULT_USER` i `RABBITMQ_DEFAULT_PASS` del fitxer `.env`.

> Com Mailpit, RabbitMQ Management no passa per Traefik. En un entorn de producció, aquesta interfície estaria restringida a una xarxa d'administració o protegida per VPN.


## Sistema de cues

El projecte inclou un sistema de tasques asíncrones format per RabbitMQ (broker de missatges), un *worker* de Node.js (consumidor) i Mailpit (servidor SMTP de proves). Aquest sistema ja ve configurat i funcional; només heu de desplegar-lo correctament.

Flux de funcionament:

1. Es publica un missatge a la cua `tasks` de RabbitMQ a través del CLI.
2. El *worker* consumeix el missatge.
3. El *worker* crida a l'API per obtenir les dades de l'atleta indicat.
4. El *worker* compon i envia un email de benvinguda a Mailpit.
5. El correu electrònic es pot visualitzar a la interfície web de Mailpit.

> En un entorn real, el front-end cridaria a un endpoint de l'API REST i aquesta s'encarregaria de publicar el job a la cua de RabbitMQ. Per simplicitat, en aquesta pràctica simulam la introducció de jobs directament a través del CLI o de la interfície web de RabbitMQ.

**Format del missatge**

Els missatges a la cua han de tenir el format següent:

```json
{"type": "email", "subtype": "welcome", "target": "athlete", "public_id": "ath_m_katir"}
```

On `public_id` és l'identificador públic d'un atleta existent a la base de dades.

**Publicar missatges via CLI**

Per a public missatges a la cua via CLI (terminal), usarem el CLI `rabbitmqadmin` de RabbitMQ:

```bash
source .env
docker compose exec rabbitmq rabbitmqadmin \
  --username=$RABBITMQ_DEFAULT_USER \
  --password=$RABBITMQ_DEFAULT_PASS \
  publish message \
  -k tasks \
  -m '{"type": "email", "subtype": "welcome", "target": "athlete", "public_id": "ath_m_katir"}'
```

**Publicar missatges via interfície web**

Alternativament, podeu fer ús de la interfície web de RabbitMQ, seguint aquests passos:

1. Accediu a la interfície de RabbitMQ Management a `http://localhost:15672`.
2. Autenticau-vos amb les credencials definides al `.env`.
3. Anau a la pestanya `Queues and Streams`.
4. Seleccionau la cua `tasks`.
5. Desplegau la secció `Publish message`.
6. Al camp `Payload`, introduïu el JSON del missatge.
7. Feu clic a `Publish message`.

**Verificar el processament**

Per a verificar que el processament s'ha dut a terme correctament teniu dues opcions:

1. Revisau els logs del *worker*:
   ```bash
   docker compose logs worker -f
   ```

2. Visualitzau els [emails a Mailpit](http://localhost:8025) (amb el perfil `dev`).

> El *worker* i Mailpit només s'arrenquen amb el perfil `dev`. Per tant, per provar el sistema de cues i notificacions, cal arrencar l'entorn amb `--profile dev`.

El log de sortida del *worker* mostra:

```bash
worker-1  | [2026-06-12T21:52:29.624Z] Missatge rebut: {"type": "email", "subtype": "welcome", "target": "athlete", "public_id": "ath_m_katir"}
worker-1  |   Obtenint dades de l'atleta ath_m_katir...
worker-1  |   Atleta trobat: Mohamed Katir
worker-1  |   Enviant email de benvinguda...
worker-1  |   Email enviat correctament (ID: <a9a1d5c5-a8d1-61cd-c1a3-1c64aa710845@sportsclub.local>)
worker-1  |   Processament completat ✓
```


## Docker Hub

Heu de publicar les imatges que hagueu creat a Docker Hub:

1. Creau un compte a [Docker Hub](https://hub.docker.com/) usant el vostre correu electrònic del centre.
2. Publicau les imatges amb etiquetes adequades (versió, `latest`).
3. Documentau al `PRACTICA.md`:
   - Els enllaços als vostres repositoris de Docker Hub
   - Les comandes que heu usat per autenticar-vos, etiquetar i pujar les imatges
   - L'estratègia d'etiquetatge que heu seguit i per què


## Fitxers proporcionats

Per aquest projecte se us proporcionen els fitxers següents:

1. `docker/frontend/index.html`: [Front-end estàtic amb HTMX](/downloads/docker/compose/assignment/docker/frontend/index.html) {{< icon "download" >}}.
2. `docker/worker/worker.js`: [Worker de Node.js](/downloads/docker/compose/assignment/docker/worker/worker.js) {{< icon "download" >}} per consumir missatges de RabbitMQ.
3. `docker/worker/package.json`: [Dependències del worker](/downloads/docker/compose/assignment/docker/worker/package.json) {{< icon "download" >}}.

A continuació es fa una breu explicació de cada fitxer, per contextualitzar.

**Front-end estàtic amb HTMX**

Front-end estàtic que, fent ús de la llibreria HTMX:

- Mostra l'estat de l'API i la base de dades amb indicadors de color
- Llista atletes, entrenadors, instal·lacions i entrenaments
- Transforma automàticament les respostes JSON en taules HTML
- Té botons per actualitzar cada secció
- Estils CSS integrats (sense dependències externes excepte HTMX)

**Worker de Node.js per consumir missatges de RabbitMQ**

Worker de Node.js que, fent ús de la llibreria [amqp](https://www.npmjs.com/package/amqp):

- Es connecta a RabbitMQ amb reintents automàtics
- Consumeix missatges de la cua `tasks`
- Processa diferents tipus de missatges (email, notification, report)
- Gestiona el tancament graciós (`SIGINT`, `SIGTERM`)
- Llegeix la configuració de variables d'entorn

**Dependències del worker**

Fitxer `package.json` que defineix les dependències del worker de Node.js, amb les següents característiques:

- Només `amqplib` com a dependència
- Requereix Node.js 20+

> No necessitau instal·lar Node.js a la vostra màquina, car la compilació es fa directament en la imatge Docker.


## Documentació

El fitxer `PRACTICA.md` ha d'incloure els següents apartats, en aquest ordre:

1. **Descripció del projecte**: Breu descripció de què és i què fa.

2. **Arquitectura**: Diagrama i descripció dels serveis, xarxes i volums. Si feu el diagrama amb Mermaid, podeu incrustar-lo dins el fitxer. Altrament, podeu enllaçar la imatge.

3. **Requisits previs**: Què cal tenir instal·lat.

4. **Configuració**:
   - On s'emmagatzemen les credencials i per què
   - Com se'n fa ús d'aquesta configuració, incloses les credencials
   - Com preparar l'entorn abans de la primera execució

5. **Instruccions d'execució**:
   - Com arrencar l'entorn (desenvolupament i producció)
   - Com aturar l'entorn

6. **Neteja de l'entorn**: Comandes per eliminar completament tots els recursos creats (contenidors, imatges, volums, xarxes). Explicau què fa cada comanda.

7. **Verificació del desplegament**: Comandes per verificar que tot funciona correctament. Per a cada comanda, explicau:
   - Què verifica
   - Quina informació aporta
   - Quin resultat s'espera

8. **Decisions tècniques**: Explicació de les decisions que heu pres, incloent:
   - Situació inicial del repositori
   - Gestió de credencials i secrets
   - Estratègia de xarxes
   - Límits de recursos i justificació
   - Correccions al `Dockerfile` de l'API REST
   - Qualsevol altra decisió rellevant

9. **Publicació a Docker Hub**:
   - Enllaços als repositoris de Docker Hub
   - Comandes usades per a la publicació
   - Estratègia d'etiquetatge

10. **Estructura del projecte**: Descripció dels fitxers i directoris.


## Contingut mínim

El vostre repositori ha de contenir, com a mínim:

**Fitxers de configuració de Docker Compose:**
- `compose.yaml` — Configuració base amb tots els serveis
- `compose.override.yaml` — Si s'usa l'estratègia de fitxers *override*
- `.env.example` — Plantilla de variables d'entorn

**Dockerfiles:**
- `docker/app/Dockerfile` — Dockerfile de l'API (corregit i millorat)
- `docker/frontend/Dockerfile` — Dockerfile del frontend (nou)
- `docker/worker/Dockerfile` — Dockerfile del worker (nou)

**Fitxers del worker proporcionats:**
- `docker/worker/worker.js`
- `docker/worker/package.json`

**Fitxer del front-end proporcionat:**
- `docker/frontend/index.html`

**Documentació:**
- `docs/PRACTICA.md` — Documentació completa de la pràctica
- `docs/arquitectura.mmd` — Diagrama de l'arquitectura (en el format i extensió pertinent)
- `docs/arquitectura.png` — Exportació a imatge del diagrama de l'arquitectura

**Altres:**
- `.gitignore` — Actualitzat per excloure fitxers sensibles
- `sportsclub/` — Codi del back-end clonat des del *fork*


## Checklist de verificació

Abans d'entregar, revisau:

1. Estructura i fitxers:
   - Existeixen tots els fitxers requerits?
   - Els fitxers sensibles estan exclosos del repositori?
   - La documentació conté tot el que es demana i és útil?

2. Configuració:
   - Les credencials estan gestionades de forma segura i justificada?
   - Els serveis estan aïllats en xarxes segons les seves necessitats?
   - Les dades persistents usen volums amb nom?
   - Tots els serveis tenen *healthchecks*?
   - Les dependències estan configurades correctament?
   - Hi ha configuracions repetides que es podrien extreure a extensions?

3. Execució:
   - L'entorn arrenca correctament en mode producció?
   - L'entorn arrenca correctament en mode desenvolupament?
   - Tots els serveis arriben a l'estat *healthy*?
   - El front-end és accessible i mostra dades de l'API?
   - El proxy encamina les peticions correctament?

4. Publicació:
   - Les imatges estan publicades a Docker Hub?
   - Les etiquetes són coherents i informatives?
   - Els enllaços als repositoris funcionen?

5. Qualitat:
   - El `Dockerfile` de l'API segueix bones pràctiques?
   - Els *commits* són petits, funcionals i amb missatges descriptius?

## Entrega

Heu d'entregar:

1. Enllaç al vostre **fork del repositori**[^1] `sportsclub`:
   - Amb tots els fitxers necessaris, incloent `PRACTICA.md` amb la documentació
   - Amb *commits* petits i atòmics (un canvi concret per *commit*)
   - Cada *commit* ha de deixar el projecte en un estat funcional
   - Els missatges de *commit* han de ser descriptius i explicar què canvia i per què
   
   > Es penalitzaran commits grans que canvien massa coses alhora o missatges genèrics com "fix", "update" o "canvis"

2. Un únic **arxiu ZIP** amb el contingut del projecte (sense `.git/`, `node_modules/`, `__pycache__/`, `.venv/`, etc.).

3. Enllaç als **repositoris de Docker Hub** amb les imatges publicades.


> Si heu optat per una aproximació alternativa amb repositoris separats, heu d'entregar els enllaços a tots els repositoris implicats.

[^1]: Podeu fer un *fork* a Github mateix, o usar alternatives com Codeberg, GitLab, etc.


## Defensa oral

La pràctica s'ha de defensar oralment. Durant la defensa:

1. Partireu d'un entorn net, sense contenidors, imatges, volums ni xarxes relacionats amb el projecte. Executareu les comandes d'instal·lació i configuració que hagueu documentat al fitxer `PRACTICA.md`.
2. Arrencareu l'entorn des de zero i demostrareu que funciona.
3. Explicareu les decisions tècniques que heu pres.
4. Respondreu preguntes sobre els conceptes aplicats.

La defensa és **obligatòria** per aprovar la pràctica. Una pràctica lliurada però no defensada es considera no presentada.

> Per accedir a la defensa oral, cal haver lliurat tots els elements requerits (repositori, ZIP i enllaços a Docker Hub) abans de la data límit i que l'entorn arrenqui correctament.

## Criteris d'avaluació

S'avaluarà:

- Correctesa i presentació del diagrama
- Correctesa tècnica de la solució
- Aplicació de les bones pràctiques treballades al curs
- Qualitat de la documentació
- Justificació de les decisions tècniques
- Capacitat de respondre preguntes durant la defensa
- Qualitat de l'historial de commits
- Correcta publicació d'imatges a Docker Hub
