---
title: "Xarxes a Docker Swarm"
date: 2026-01-31
lastmod: 2026-01-31
description: "Xarxes overlay, descobriment de serveis, balanceig de càrrega i routing mesh"
summary: "Xarxes overlay, descobriment de serveis, balanceig de càrrega i routing mesh"
categories: ["ensenyament"]
tags: ["docker", "swarm"]
series: ["Docker Swarm"]
series_order: 5
weight: 50
slug: xarxes
---

A Docker Compose, els contenidors es comuniquen a través d'una xarxa *bridge* local. Això funciona perquè tots els contenidors s'executen a la mateixa màquina. A Docker Swarm, les tasques es distribueixen entre múltiples nodes, així que necessitam un mecanisme diferent per permetre la comunicació entre elles.

Docker Swarm utilitza **xarxes overlay** per connectar contenidors que s'executen en nodes diferents, com si estiguessin a la mateixa xarxa local. A més, proporciona **descobriment de serveis** automàtic i **balanceig de càrrega** integrat.

## Tipus de xarxes

Docker Swarm fa feina amb diversos tipus de xarxes:

| Tipus     | Àmbit           | Ús principal                                      |
|:----------|:----------------|:--------------------------------------------------|
| `bridge`  | Node local      | Contenidors individuals al mateix node            |
| `host`    | Node local      | Contenidor usa directament la xarxa del host      |
| `overlay` | Tot el clúster  | Comunicació entre serveis a diferents nodes       |
| `ingress` | Tot el clúster  | Routing mesh per a ports publicats (automàtica)   |

La xarxa `bridge` és la xarxa per defecte de Docker quan fem feina amb contenidors individuals (fora de Swarm). Cada node té la seva pròpia xarxa bridge, i els contenidors connectats a ella només es poden comunicar amb altres contenidors del mateix node. És la que has estat usant fins ara amb `docker run` i `docker compose`.

La xarxa `host` elimina l'aïllament de xarxa entre el contenidor i el node. El contenidor comparteix directament la xarxa del host, sense cap traducció de ports. És útil quan necessitam el màxim rendiment de xarxa o accés a la IP real del client, però perds l'aïllament i la flexibilitat de mapejat de ports.

La xarxa `ingress` és una xarxa overlay especial que Docker Swarm crea automàticament quan inicialitzam el clúster. Gestiona el tràfic extern que entra als serveis publicats (els que tenen `--publish`). No cal crear-la ni gestionar-la manualment, car Swarm s'encarrega del seu funcionament intern per fer possible el *routing mesh*.

Les xarxes `overlay` són les que crearem i gestionarem habitualment per connectar els nostres serveis.

## Xarxes overlay

Una xarxa overlay és una xarxa virtual que s'estén per tots els nodes del clúster. Els contenidors connectats a la mateixa xarxa overlay es poden comunicar directament, independentment de a quin node s'executin.

Per crear una xarxa overlay usarem la següent ordre:

```bash
docker network create --driver overlay backend
```

Per defecte, les xarxes overlay només són accessibles per als serveis de Swarm. Si volem que contenidors individuals (creats amb `docker run`) també s'hi puguin connectar, cal usar l'opció `--attachable`:

```bash
docker network create --driver overlay --attachable backend
```

Com és d'esperar, apareixen al llistat de xarxes que podem obtenir amb `docker network ls`:

```text
NETWORK ID     NAME              DRIVER    SCOPE
abc123def456   bridge            bridge    local
def789ghi012   host              host      local
ghi345jkl678   ingress           overlay   swarm
jkl901mno234   backend           overlay   swarm
```

Les xarxes amb `SCOPE` igual a `swarm` són accessibles des de tots els nodes del clúster.

En crear un servei, el podem connectar a una xarxa:

```bash
docker service create \
  --name api \
  --network backend \
  httpd:2.4
```

També podem connectar un servei existent a una xarxa addicional:

```bash
docker service update --network-add frontend api
```

I, més tard, desconnectar-lo:

```bash
docker service update --network-rm frontend api
```

## Descobriment de serveis

Docker Swarm inclou un servidor DNS intern que permet als serveis trobar-se pel seu nom. Quan cream un servei, Swarm registra automàticament el nom del servei al DNS.

Imaginem que tenim dos serveis: `api` i `database`, ambdós connectats a la xarxa `backend`.

```bash
docker network create --driver overlay backend
docker service create --name database --network backend postgres:16
docker service create --name api --network backend myapp/api
```

Des de qualsevol contenidor del servei `api`, podem accedir a la base de dades simplement pel nom:

```bash
# Des de dins d'un contenidor del servei api
ping database
psql -h database -U postgres
```

El DNS intern resol `database` a l'adreça IP del servei. Si el servei té múltiples rèpliques, el DNS retorna l'adreça IP virtual (VIP) del servei, que balanceja automàticament entre les rèpliques.

Dins d'una xarxa overlay, cada servei és accessible per:

| Format           | Exemple             | Resolució                             |
|:-----------------|:--------------------|:--------------------------------------|
| `servei`         | `database`          | IP virtual del servei (amb balanceig) |
| `tasks.servei`   | `tasks.database`    | Totes les IPs de les tasques          |
| `servei.slot.id` | `database.1.abc123` | IP d'una tasca específica             |

Normalment, utilitzarem simplement el nom del servei per aprofitar el balanceig automàtic.

## Balanceig de càrrega

Quan un servei té múltiples rèpliques, Docker Swarm balanceja automàticament les peticions entre elles. Hi ha dos modes:

* Mode VIP (Virtual IP, per defecte).
* Mode DNSRR (DNS Round Robin).

En el mode VIP, el servei té una IP virtual (VIP) única. El DNS resol el nom del servei a aquesta VIP, i Swarm s'encarrega de distribuir les peticions entre les rèpliques.

```bash
docker service create \
  --name api \
  --replicas 3 \
  --network backend \
  httpd:2.4
```

Totes les peticions a `api` van a la mateixa VIP, però internament es distribueixen entre les 3 rèpliques.

En el mode DNSRR, el DNS retorna directament les IPs de totes les rèpliques, i el client tria a quina connectar-se (normalment la primera).

```bash
docker service create \
  --name api \
  --replicas 3 \
  --network backend \
  --endpoint-mode dnsrr \
  httpd:2.4
```

El mode DNSRR és útil quan necessitam controlar el balanceig des del client o quan usam protocols que no funcionen bé amb VIP (com alguns sistemes de missatgeria).

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart TB
    subgraph vip["MODE VIP (per defecte)"]
        C1["Client"] --> VIP["VIP: 10.0.0.5"]
        VIP --> R1["api.1"]
        VIP --> R2["api.2"]
        VIP --> R3["api.3"]
    end
    
    subgraph dnsrr["MODE DNSRR"]
        C2["Client"] --> DNS["DNS"]
        DNS -->|"10.0.0.10"| D1["api.1"]
        DNS -.->|"10.0.0.11"| D2["api.2"]
        DNS -.->|"10.0.0.12"| D3["api.3"]
    end
    
    vip ~~~ dnsrr
{{< /mermaid >}}

## Routing mesh

El **routing mesh** és el mecanisme que permet accedir a un servei publicat des de qualsevol node del clúster, encara que el node no executi cap tasca d'aquell servei.

Quan publicam un port amb `--publish`, Docker Swarm:

1. Obre el port a **tots** els nodes del clúster.
2. Redirigeix les peticions cap a una tasca activa del servei, independentment de quin node rebi la petició.

Per exemple, suposem que cream el següent servei:

```bash
docker service create \
  --name webserver \
  --replicas 2 \
  --publish 80:80 \
  httpd:2.4
```

Si el servei només té tasques a `node1` i `node2`, però accedim a `http://node3:80`, el routing mesh redirigeix la petició a `node1` o `node2`.

Avantatges del routing mesh:

* Podem posar un balancejador extern apuntant a qualsevol node (o a tots).
* No cal saber a quin node s'executen les tasques.
* Si una tasca es mou a un altre node, el routing mesh s'actualitza automàticament.

**Mode host (bypass del routing mesh)**

Si volem que un servei només escolti al node on s'executa (sense routing mesh), podem usar el mode `host`:

```bash
docker service create \
  --name webserver \
  --publish mode=host,target=80,published=80 \
  --mode global \
  httpd:2.4
```

En mode `host`:

* El port només s'obre als nodes que executen tasques del servei.
* No hi ha balanceig automàtic entre nodes.
* Útil quan necessites rendiment màxim o accés a la IP real del client.

Normalment s'usa amb `--mode global` per assegurar que cada node té una tasca.

## Xarxes externes i internes

Per defecte, les xarxes overlay permeten sortida a Internet. Si volem crear una xarxa interna o aïllada (per exemple, per a bases de dades que no han de tenir accés extern), usarem el paràmetre `--internal`:

```bash
docker network create --driver overlay --internal database-net
```

Els serveis connectats a una xarxa `--internal` només es poden comunicar amb altres serveis de la mateixa xarxa, sense accés a Internet.

Una pràctica habitual és crear xarxes separades o aïllades per a cada capa de l'arquitectura. Per exemple, una xarxa pel front-end i una altra pel back-end:

```bash
# Xarxa per al frontend (accessible des de l'exterior)
docker network create --driver overlay frontend

# Xarxa per al backend (comunicació api-database)
docker network create --driver overlay --internal backend
```

Una vegada creades les xarxes, connectarem els serveis a les xarxes pertinents:

```bash
# El proxy invers es connecta al frontend
docker service create --name proxy --network frontend --publish 80:80 traefik:v3.6.7

# L'API es connecta a ambdues xarxes
docker service create --name api --network frontend --network backend myapp/api

# La base de dades només es connecta al backend
docker service create --name database --network backend postgres:18
```

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart LR
    U["Usuari"] --> P["proxy<br/>:80"]
    
    subgraph frontend["Xarxa frontend"]
        P
        A["api"]
    end
    
    subgraph backend["Xarxa backend"]
        A2["api"]
        DB["database"]
    end
    
    P --> A
    A --- A2
    A2 --> DB
{{< /mermaid >}}

Amb aquesta configuració:

* El proxy és accessible des de l'exterior.
* L'API rep peticions del proxy i pot connectar a la base de dades.
* La base de dades només és accessible des de l'API, no des de l'exterior ni des d'Internet.

## Inspeccionar xarxes

Podem veure els detalls d'una xarxa amb la següent comanda:

```bash
docker network inspect backend
```

La sortida JSON mostra els serveis i contenidors connectats, les IPs assignades, i la configuració de la xarxa.

També podem veure a quines xarxes està connectat un servei:

```bash
docker service inspect --pretty api
```

La secció `Networks` a la sortida és on trobarem la informació.

## Resum

| Comanda                                                   | Funció                                                |
|:----------------------------------------------------------|:------------------------------------------------------|
| `docker network create --driver overlay NOM`              | Crea una xarxa overlay                                |
| `docker network create --driver overlay --attachable NOM` | Crea una xarxa accessible per contenidors individuals |
| `docker network create --driver overlay --internal NOM`   | Crea una xarxa sense accés a Internet                 |
| `docker network ls`                                       | Llista les xarxes                                     |
| `docker network inspect NOM`                              | Mostra detalls d'una xarxa                            |
| `docker network rm NOM`                                   | Elimina una xarxa                                     |
| `docker service create --network NOM`                     | Connecta un servei a una xarxa                        |
| `docker service update --network-add NOM`                 | Afegeix una xarxa a un servei existent                |
| `docker service update --network-rm NOM`                  | Desconnecta un servei d'una xarxa                     |
| `docker service create --endpoint-mode dnsrr`             | Usa DNS Round Robin en lloc de VIP                    |
| `docker service create --publish mode=host,...`           | Publica en mode host (sense routing mesh)             |

## Exercici pràctic

L'objectiu d'aquest exercici és comprendre les xarxes overlay, el descobriment de serveis i el routing mesh.

Requisits:

* Un clúster Docker Swarm amb almanco 3 nodes.
* Connectivitat de xarxa entre els nodes.

Tasques:

1. **Crear xarxes**:
   * Crea una xarxa overlay anomenada `web-public`.
   * Crea una xarxa overlay interna anomenada `db-private`.
   * Verifica que ambdues apareixen a `docker network ls`.

2. **Desplegar una base de dades aïllada**:
   * Crea un servei `redis` amb la imatge `redis:7-alpine`, connectat només a `db-private`.
   * Verifica que el servei està en execució.

3. **Desplegar una aplicació web**:
   * Crea un servei `webapp` amb la imatge `containous/whoami` i 3 rèpliques.
   * Connecta'l a ambdues xarxes: `web-public` i `db-private`.
   * Publica el port 8080.
   * Verifica que hi ha una tasca a cada node.

4. **Comprovar el descobriment de serveis**:
   * Accedeix a un contenidor del servei `webapp`:
     ```bash
     docker exec -it $(docker ps -q -f name=webapp) sh
     ```
   * Des de dins, comprova que pots resoldre el nom `redis`:
     ```bash
     ping -c 3 redis
     ```
   * Surt del contenidor.

5. **Comprovar el routing mesh**:
   * Identifica a quins nodes s'executen les tasques de `webapp` amb `docker service ps webapp`.
   * Des de la teva màquina o des d'un node sense tasques, accedeix a `http://<ip-node>:8080`.
   * Fes diverses peticions i observa com el `Hostname` canvia (balanceig entre rèpliques):
     ```bash
     for i in $(seq 1 10)
     do
        curl -s http://<ip-node>:8080 | grep Hostname
     done
     ```

6. **Comprovar l'aïllament**:
   * Intenta accedir a `redis` des de fora del clúster (hauria de fallar, no té port publicat).
   * Crea un servei temporal per verificar que des de `web-public` no es pot accedir a `redis`:
     ```bash
     docker service create --name test --network web-public alpine sleep 3600
     docker exec -it $(docker ps -q -f name=test) ping -c 3 redis
     ```
   * Hauria de fallar perquè `redis` només està a `db-private`.

7. **Neteja**:
   * Elimina tots els serveis creats.
   * Elimina les xarxes `web-public` i `db-private`.
