---
title: "Pràctica final de Docker Swarm"
date: 2026-03-03
lastmod: 2026-04-23
description: "Exercici integrador: desplegament complet d'una aplicació Django en un clúster Docker Swarm"
summary: "Exercici integrador: desplegament complet d'una aplicació Django en un clúster Docker Swarm"
categories: ["teaching"]
tags: ["docker", "swarm", "django", "traefik", "practice"]
series: ["Docker Swarm"]
series_order: 14
weight: 140
slug: practica-final
---

Aquesta pràctica final és un exercici integrador que posa en joc els coneixements adquirits al llarg de la sèrie. L'objectiu és desplegar, des de zero, una aplicació web completa sobre un clúster Docker Swarm, aplicant bones pràctiques de xarxes, persistència, secrets i gestió de serveis.

## Context

El club d'atletisme **CA Son Moix** ha contractat el vostre equip per posar en producció la seva plataforma de gestió esportiva. Es tracta d'[Athletics Sports Club](https://github.com/jsabater/sportsclub), una aplicació *headless* (API REST) construïda amb Django Ninja que gestiona atletes, entrenadors, instal·lacions i activitats (entrenaments i competicions).

L'aplicació actual utilitza PostgreSQL com a base de dades i NGINX com a proxy invers, orquestrada amb Docker Compose per a un entorn de desenvolupament d'un sol node. El club vol migrar-la a un clúster Docker Swarm per obtenir alta disponibilitat i facilitat d'escalat. A més, demana els següents canvis respecte a la configuració original:

1. Substituir NGINX per **Traefik** com a proxy invers, aprofitant la seva integració nativa amb Docker Swarm.
2. Afegir **Redis** com a servei de caché, per preparar la infraestructura per a futures millores de rendiment.

L'equip de desenvolupament ja ha publicat la imatge Docker de l'aplicació al registre. La vostra feina és preparar la infraestructura Swarm i desplegar-hi tots els serveis.

## Requisits previs

* Un clúster Docker Swarm amb **3 nodes** (1 manager + 2 workers), creat amb màquines virtuals al vostre portàtil ([Multipass](https://canonical.com/multipass), [Vagrant](https://developer.hashicorp.com/vagrant), [VirtualBox](https://www.virtualbox.org/) o similar).
* Accés SSH amb claus configurat al node manager.
* Docker i Git instal·lats a la màquina de desenvolupament.
* Un compte a Docker Hub (o un registre alternatiu).
* Coneixement dels temes 1–13 d'aquesta sèrie.

## Arquitectura objectiu

L'aplicació consta dels següents serveis:

| Servei     | Imatge                      | Rèpliques | Restriccions                      |
|:-----------|:----------------------------|:----------|:----------------------------------|
| `traefik`  | `traefik:v3.6`              | 1         | Només al node manager             |
| `app`      | `<usuari>/sportsclub:1.0.0` | 2         | Només als workers                 |
| `postgres` | `postgres:18-alpine`        | 1         | Node amb etiqueta `database=true` |
| `redis`    | `redis:8.6-alpine`          | 1         | Sense restricció                  |

Substitueix `<usuari>` pel teu nom d'usuari de Docker Hub.

Les xarxes necessàries són:

| Xarxa      | Tipus   | Propòsit                                    |
|:-----------|:--------|:--------------------------------------------|
| `frontend` | overlay | Comunicació entre Traefik i l'app           |
| `backend`  | overlay | Comunicació entre l'app, PostgreSQL i Redis |

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart TB
    subgraph internet["Internet"]
        U[Usuari]
    end

    subgraph cluster["Clúster Docker Swarm"]
        subgraph manager["Node Manager"]
            T[Traefik :443]
        end

        subgraph workers["Nodes Workers"]
            A1[App rèplica 1]
            A2[App rèplica 2]
        end

        subgraph db_node["Node amb database=true"]
            P[(PostgreSQL)]
        end

        R[(Redis)]
    end

    U -->|HTTPS| T
    T -->|frontend| A1
    T -->|frontend| A2
    A1 -->|backend| P
    A1 -->|backend| R
    A2 -->|backend| P
    A2 -->|backend| R
{{< /mermaid >}}

## Lliurament

El lliurament consisteix en:

1. Un arxiu **`docker-swarm.zip`** amb el projecte comprimit, seguint l'estructura indicada a continuació.
2. Un fitxer **`README.md`** dins el projecte amb els passos seguits per resoldre cada tasca i les respostes a les qüestions plantejades.

Estructura esperada del projecte:

```text
sportsclub/
├── docker/
│   ├── app/
│   │   └── Dockerfile
│   └── traefik/
│       └── traefik.prod.yml
├── deploy/
│   └── create-secrets.sh
├── docker-stack.yml
├── .env.example
├── .gitignore
└── README.md
```

> El `README.md` ha de documentar, per a cada tasca, els passos concrets que has seguit (comandes, decisions, problemes trobats) i les respostes a les qüestions. Ha de ser suficientment detallat perquè una altra persona pugui reproduir el desplegament seguint les teves instruccions.

## Preparació del projecte

Abans de començar amb les tasques de Docker Swarm, cal preparar el projecte `sportsclub` per al nou entorn:

1. Fes un *fork* del repositori [jsabater/sportsclub](https://github.com/jsabater/sportsclub) al teu compte de GitHub.
2. Clona el teu fork a la teva màquina de desenvolupament.
3. Estudia l'estructura del projecte: el `Dockerfile`, el `docker-compose.yml`, el `.env.example` i el `settings.py`. Entendre com l'aplicació es configura és essencial per adaptar-la a Docker Swarm.

El projecte original usa variables d'entorn per a la configuració (seguint la metodologia *twelve-factor app*). A Docker Swarm, les credencials sensibles s'han de gestionar com a **secrets**, que es munten com a fitxers dins el contenidor al directori `/run/secrets/`. L'aplicació Django, però, llegeix les credencials des de variables d'entorn.

Hauràs de trobar la manera de resoldre aquesta diferència: o bé adaptes la configuració de Django perquè llegeixi els fitxers de secrets, o bé fas servir un mecanisme al `docker-stack.yml` perquè el contingut dels secrets estigui disponible com a variables d'entorn.

Consulta la documentació oficial de PostgreSQL a Docker Hub per veure com altres imatges resolen aquesta qüestió amb la convenció `*_FILE`.

## Tasques

Amb l'objectiu de guiar l'alumnat al llarg de la pràctica, en aquesta secció es defineixen un seguit de tasques a dur a terme. No és obligatori seguir aquest ordre, però sí convenient.

### Creació del clúster

Crea un clúster Docker Swarm amb 3 nodes: un manager i dos workers. Assigna una etiqueta al node on vols que s'executi PostgreSQL, ja que aquest servei necessita una ubicació fixa per garantir la persistència de les dades.

Documenta al `README.md`:

* Les comandes que has usat per crear i configurar el clúster.
* El resultat de verificar l'estat dels nodes.

**Qüestió:** Quina diferència hi ha entre un node *manager* i un node *worker*? Pot un manager executar tasques (contenidors)?

### Gestió de secrets

Identifica quines dades sensibles necessita l'aplicació per funcionar (revisa el fitxer `.env.example` del projecte original) i crea els secrets corresponents a Docker Swarm.

Crea un script automatitzat (`deploy/create-secrets.sh`) que llegeixi les credencials d'un fitxer `.env.prod` i les registri com a secrets al clúster, seguint el patró que vam veure al tema d'automatització. Assegura't que el fitxer `.env.prod` mai arribi al repositori.

Documenta al `README.md`:

* La llista de secrets que has creat i per què.
* El contingut de l'script (o una referència si l'has copiat i adaptat).
* La verificació de que els secrets existeixen al clúster.

**Qüestió:** Per què els secrets de Docker Swarm són més segurs que les variables d'entorn definides directament al fitxer `docker-stack.yml`?

### Configuració de Traefik

Configura Traefik com a proxy invers per a l'aplicació, substituint l'NGINX del projecte original. Traefik ha de:

* Escoltar als ports 80 (HTTP) i 443 (HTTPS).
* Redirigir el tràfic HTTP a HTTPS.
* Usar el seu certificat autosignat per defecte (no cal configurar Let's Encrypt per a aquesta pràctica).
* Exposar el dashboard a un port addicional per a diagnòstic.
* Descobrir els serveis automàticament a través del proveïdor de Docker Swarm.

Crea el fitxer amb la configuració estàtica a `docker/traefik/traefik.prod.yml`. Consulta la [documentació oficial de Traefik per a Docker Swarm](https://doc.traefik.io/traefik/providers/swarm/) per als detalls de configuració del proveïdor.

Documenta al `README.md`:

* La configuració de Traefik que has creat i les decisions preses.
* Com has verificat que el dashboard és accessible.

**Qüestió:** Per què Traefik necessita accedir al socket de Docker? Quin risc de seguretat comporta això i com es podria mitigar en un entorn de producció real?

### Fitxer de l'stack

Aquesta és la tasca central de la pràctica. Crea el fitxer `docker-stack.yml` complet amb tots els serveis de l'arquitectura objectiu. Has de definir:

**Servei `traefik`:**

* Imatge `traefik:3`.
* Ports publicats, volums necessaris, xarxa i restriccions de desplegament.

> Les etiquetes (*labels*) de Traefik no s'apliquen a ell mateix sinó als serveis que vol exposar.

**Servei `app`:**

* La imatge que has construït i pujat al registre (següent tasca de la llista).
* Connexió a ambdues xarxes (`frontend` i `backend`).
* Accés als secrets necessaris.
* Variables d'entorn per a la configuració no sensible (amfitrió de la base de dades, URL de Redis, etc.).
* Etiquetes de Traefik per al *routing* (regla de host, *entrypoint*, port del servei).
* Dues rèpliques als nodes workers amb un *rolling update* configurat.

**Servei `postgres`:**

* Imatge `postgres:18-alpine`.
* Configuració a través de secrets (investiga la convenció `*_FILE` de la imatge oficial).
* Volum per a la persistència de dades.
* Restricció al node amb etiqueta `database=true`.
* Connexió només a la xarxa `backend`.

> A partir de PostgreSQL 18, la ruta per defecte de les dades (`PGDATA`) ha canviat a `/var/lib/postgresql/18/docker` i el punt de muntatge del volum a `/var/lib/postgresql`. Consulta la documentació de la imatge oficial per als detalls.

**Servei `redis`:**

* Imatge `redis:8.6-alpine`.
* Persistència habilitada.
* Volum per a les dades.
* Connexió només a la xarxa `backend`.

**Xarxes i volums:**

* Defineix les xarxes `frontend` i `backend` com a overlay dins l'stack (no com a externes).
* Defineix els volums necessaris per a PostgreSQL i Redis.

**Secrets:**

* Referencia els secrets com a externs (ja creats a la Tasca 2).

Documenta al `README.md`:

* Les decisions de disseny que has pres (per què cada servei està a cada xarxa, per què has triat certs paràmetres de rolling update, etc.).
* Els problemes que has trobat i com els has resolt.

**Qüestió:** Per què PostgreSQL té la restricció `node.labels.database == true` en lloc d'executar-se a qualsevol node? Quina relació té amb la persistència de dades en un entorn Swarm?

### Imatge de l'app

Construeix la imatge Docker de l'aplicació a partir del `Dockerfile` existent i publica-la al teu registre. Recorda usar una etiqueta de versió (no `latest`) per garantir la traçabilitat.

Si necessites modificar el `Dockerfile` per adaptar-lo al nou entorn (per exemple, per a la gestió de secrets), documenta els canvis i les raons.

Documenta al `README.md`:

* Les comandes de construcció i publicació.
* L'etiqueta de versió que has usat i per què.

### Desplegament

Desplega l'stack al clúster i verifica que tot funciona correctament:

1. Desplega l'stack i comprova que tots els serveis arriben a l'estat desitjat.
2. Verifica que les rèpliques de l'aplicació estan repartides entre els workers.
3. Accedeix a l'aplicació a través de Traefik (hauràs de configurar el domini `sportsclub.local` al teu `/etc/hosts`).
4. Comprova que l'API respon correctament (per exemple, accedint a la documentació Swagger a `/api/v1/docs`).
5. Verifica el *routing mesh*: accedeix a l'aplicació des de la IP de qualsevol node del clúster.
6. Simula la caiguda d'un contenidor: elimina manualment un dels contenidors de l'aplicació i observa com Swarm recrea la tasca automàticament.
7. Simula la caiguda d'un node: atura completament una de les màquines virtuals worker i observa com Swarm redistribueix les tasques als nodes restants. Un pic verificat, torna a encendre la VM i observa si les tasques es reequilibren automàticament o no (i reflexiona sobre per què).
8. Comprova els logs d'algun servei per verificar que no hi ha errors.

> Swarm pot tardar uns 30 segons a detectar que el node ha caigut.

Documenta al `README.md`:

* Les comandes usades per a cada verificació i els resultats obtinguts.
* Qualsevol problema trobat i com l'has resolt.

**Qüestió:** Què és el *routing mesh* de Docker Swarm i com permet accedir a l'aplicació des de la IP de qualsevol node, encara que el contenidor no s'executi en aquell node?

### Actualitzar l'app

Simula una actualització de l'aplicació. Fes un petit canvi al codi (per exemple, modifica el títol de la pàgina principal o afegeix un comentari visible), reconstrueix la imatge amb una nova etiqueta de versió, puja-la al registre i actualitza el servei.

Observa el procés de *rolling update* i verifica que l'aplicació continua disponible durant l'actualització. Si alguna cosa no funciona, fes un *rollback*.

Documenta al `README.md`:

* El canvi que has fet, la nova versió i les comandes d'actualització.
* L'observació del procés de rolling update.
* Si has hagut de fer rollback, documenta per què i com.

**Qüestió:** Quina és la diferència entre l'estratègia `start-first` i `stop-first` en un *rolling update*? Quina és més adequada per a una aplicació web i per què?

### Neteja i documentació

1. Elimina l'stack, els secrets i qualsevol recurs creat al clúster.
2. Revisa que el repositori no conté fitxers amb credencials reals.
3. Completa el `README.md` amb les respostes a totes les qüestions i una reflexió final.

**Qüestió final:** Resumeix en 5-10 línies els avantatges principals d'usar Docker Swarm per desplegar una aplicació web en comparació amb executar contenidors individuals amb `docker run` o amb Docker Compose en un sol node. Menciona almanco: orquestració, escalabilitat, secrets i alta disponibilitat.

## Autoavaluació

Abans de lliurar la pràctica, verifica cadascun dels punts d'aquesta llista. Cada element indica un aspecte concret que serà avaluat.

### Clúster i nodes

Verifica que el clúster té 3 nodes operatius:

```bash
docker node ls
```

Verifica que l'etiqueta `database=true` està assignada:

```bash
docker node inspect <nom_node> --format '{{ .Spec.Labels }}'
```

El resultat obtingut hauria de ser el següent:

* El clúster té 3 nodes amb estat *Ready*.
* Hi ha exactament un manager i dos workers.
* L'etiqueta `database=true` està assignada a un node.

### Secrets

Verifica que els secrets existeixen:

```bash
docker secret ls
```

Compta'n el nombre:

```bash
docker secret ls --format '{{.Name}}' | wc -l
```

El resultat obtingut hauria de ser el següent:

* Tots els secrets necessaris estan creats.
* L'script `deploy/create-secrets.sh` funciona sense errors.
* El fitxer `.env.prod` està inclòs al `.gitignore`.
* No hi ha credencials reals al repositori:
  ```bash
  grep -r "PASSWORD" --include="*.yml" --include="*.yaml"
  ```

### Traefik

Verifica que el servei Traefik s'està executant:

```bash
docker service ls --filter name=<stack>_traefik
```

Comprova la resposta HTTPS:

```bash
curl -sk https://sportsclub.local/
```

> Necessitaràs afegir la ruta estàtica al teu fitxer `/etc/hosts`:

El resultat obtingut hauria de ser el següent:

* El fitxer `traefik.prod.yml` existeix i configura el proveïdor Swarm.
* Traefik escolta als ports 80 i 443.
  ```bash
  netstat --program -all --numeric | grep --word-regexp LISTEN
  ```
* El dashboard és accessible.
* La redirecció HTTP → HTTPS funciona.

### Stack i serveis

Verifica que tots els serveis tenen les rèpliques correctes:

```bash
docker stack services <stack>
```

Verifica la distribució als nodes:

```bash
docker stack ps <stack>
```

Comprova que no hi ha tasques fallides:

```bash
docker stack ps <stack> --filter desired-state=running
```

El resultat obtingut hauria de ser el següent:

* Tots els serveis estan definits al `docker-stack.yml`.
* Les rèpliques coincideixen amb l'arquitectura objectiu.
* Les restriccions de desplegament s'apliquen correctament.
* Les xarxes `frontend` i `backend` estan definides dins l'stack.
* Els volums de PostgreSQL i Redis estan definits.
* L'app es connecta a ambdues xarxes; PostgreSQL i Redis només a `backend`.
* El *rolling update* està configurat per al servei `app`.

### Aplicació

Verifica la resposta de l'API:

```bash
curl -sk https://sportsclub.local/api/v1/docs
```

Verifica el routing mesh des d'un altre node:

```bash
curl -sk https://<ip_worker>/api/v1/docs
```

Simula caiguda i comprova recreació:

```bash
docker kill <container_id>
watch docker stack ps <stack>
```

El resultat obtingut hauria de ser el següent:

* L'aplicació respon a través de Traefik.
* L'API Swagger és accessible.
* El *routing mesh* funciona des de qualsevol node.
* Una rèplica eliminada manualment es recrea automàticament.

### Actualització

Verifica la versió de la imatge en execució

```bash
docker service inspect <stack>_app \
--format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
```

El resultat obtingut hauria de ser el següent:

* S'ha construït i publicat una nova versió de la imatge.
* El *rolling update* s'ha executat correctament.
* L'aplicació ha estat disponible durant l'actualització.

### Lliurament

Prepara el lliurament de la pràctica verificant que compleix aquests punts:

* El `README.md` documenta els passos seguits per a cada tasca.
* Totes les qüestions tenen resposta raonada.
* L'estructura del projecte coincideix amb l'esperada.
* L'arxiu `docker-swarm.zip` conté tot el projecte.
* No hi ha credencials reals a cap fitxer del lliurament.

I aquí tens uns consells útils:

1. Llegeix l'enunciat complet abans de començar. Planifica l'ordre de les tasques.
2. Estudia el projecte `sportsclub` a fons abans de tocar res: entén el `Dockerfile`, el `docker-compose.yml`, el `.env.example` i el `settings.py`.
3. Consulta els temes anteriors de la sèrie quan tenguis dubtes. Tot el que necessites per resoldre les tasques està explicat als articles.
4. Documenta a mesura que avances, no ho deixis pel final. El `README.md` és una part important de la feina.
5. Si la imatge de l'aplicació no funciona al primer intent, revisa els logs del servei (`docker service logs`) per diagnosticar el problema.
