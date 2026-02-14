---
title: "De Compose a Swarm amb Stacks"
date: 2026-01-31
lastmod: 2026-01-31
description: "Desplegament d'aplicacions multi-servei amb Docker Stack i fitxers Compose"
summary: "Desplegament d'aplicacions multi-servei amb Docker Stack i fitxers Compose"
categories: ["teaching"]
tags: ["docker", "swarm", "stack", "compose"]
series: ["Docker Swarm"]
series_order: 7
weight: 70
slug: stacks
---

Fins ara hem creat serveis individualment amb `docker service create`. Això funciona per a serveis senzills, però quan una aplicació consta de múltiples serveis interconnectats (web, API, base de dades, cache, etc.), gestionar-los un per un es torna feixuc i propens a errors.

Docker Swarm ofereix el concepte de **stack**: un conjunt de serveis, xarxes i volums definits en un fitxer YAML que es despleguen com una unitat. El format del fitxer és pràcticament idèntic al de Docker Compose, cosa que facilita la transició d'entorns de desenvolupament a producció.

## De Compose a Swarm

Havent fet feina amb Docker Compose, ja coneixem la idea: un fitxer `docker-compose.yml` que descriu tots els components de l'aplicació. A Docker Swarm, aquest mateix fitxer es desplega amb `docker stack deploy`, amb alguns ajustos.

Diferències principals:

| Aspecte         | Docker Compose           | Docker Stack          |
|:----------------|:-------------------------|:----------------------|
| Comanda         | `docker compose up`      | `docker stack deploy` |
| Àmbit           | Una sola màquina         | Tot el clúster Swarm  |
| Escalat         | Manual o amb `replicas`  | Gestionat per Swarm   |
| Xarxes          | Bridge per defecte       | Overlay per defecte   |
| Actualitzacions | Recreació de contenidors | Rolling updates       |
| Dependències    | `depends_on` funciona    | `depends_on` s'ignora |

La diferència més important és que `depends_on` s'ignora a Swarm. Això és perquè en un entorn distribuït no es pot garantir l'ordre d'arrencada entre nodes. Per tant, les aplicacions han d'estar dissenyades per tolerar que els serveis dels quals depenen encara no estiguin disponibles (*retry*, *circuit breaker*, etc.).

## El fitxer stack

A diferència de Docker Compose, que cerca automàticament `docker-compose.yml` al directori actual, `docker stack deploy` no fa aquesta cerca automàtica. Per tant, per a gestionar els nostres entorns tenim dues possibilitats:

* Crear un fitxer base `docker-compose.yml` per a desenvolupament i usar *overrides* pels altres entorns, e.g., `docker-compose.production.yml`.
* Mantenir el nostre fitxer actual `docker-compose.yml` per a desenvolupament i crear un nou fitxer `docker-stack.yml` per a producció.

A la pràctica, la convenció més habitual és crear un fitxer separat `docker-stack.yml` per a l'entorn de producció, amb totes aquelles opcions que són pròpies de Docker Swarm i, alhora, eliminant aquelles opcions de Docker Compose que no són d'aplicació:

```yaml
# docker-stack.yml
services:
  web:
    image: nginx:1.26
    ports:
      - "80:80"
    deploy:
      replicas: 3
    networks:
      - frontend

  api:
    image: myapp/api:latest
    environment:
      - DATABASE_URL=postgres://db:5432/myapp
    deploy:
      replicas: 2
    networks:
      - frontend
      - backend

  db:
    image: postgres:18
    volumes:
      - db-data:/var/lib/postgresql
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.storage==ssd
    networks:
      - backend

networks:
  frontend:
  backend:
    internal: true

volumes:
  db-data:
```

Ja coneixem aquestes tres seccions de Docker Compose, que es mantenen a Docker Swarm:

* `services`: Defineix els serveis de l'aplicació.
* `networks`: Defineix les xarxes (*overlay* per defecte a Swarm).
* `volumes`: Defineix els volums de dades.

## La clau deploy

La clau `deploy` conté totes les opcions de desplegament. En versions modernes de Docker ja no és exclusiva de Swarm, sinó que forma part de l'estàndard Compose.

> "Deploy is an optional part of the Compose Specification. It provides a set of deployment specifications for managing the behavior of containers across different environments."

Ara bé, no totes les opcions de `deploy` formen part d'aquesta especificació:

| Opció                   | Compose | Swarm | Descripció                                  |
|-------------------------|:-------:|:-----:|---------------------------------------------|
| `replicas`              | Sí      | Sí    | Nombre de rèpliques del servei              |
| `resources`             | Sí      | Sí    | Límits i reserves de CPU i memòria          |
| `restart_policy`        | Sí      | Sí    | Política de reinici en cas d'error          |
| `labels`                | Sí      | Sí    | Metadades del servei                        |
| `mode: replicated`      | Sí      | Sí    | Executa N rèpliques del servei              |
| `mode: global`          | No      | Sí    | Executa una rèplica per node                |
| `placement.constraints` | No      | Sí    | Restringeix on s'executen les tasques       |
| `placement.preferences` | No      | Sí    | Preferències de distribució entre nodes     |
| `endpoint_mode`         | No      | Sí    | Mètode de descobriment (`VIP` o `DNSRR`)    |
| `update_config`         | Parcial | Sí    | Configuració d'actualitzacions progressives |
| `rollback_config`       | Parcial | Sí    | Configuració de rollback automàtic          |

L'opció `deploy` permet, per exemple, definir el nombre de rèpliques i el [mode de desplegament]({{<relref "/posts/docker/swarm/services/">}}):

```yaml
deploy:
  replicas: 3
  mode: replicated
```

També permet definir restriccions d'ubicació:

```yaml
deploy:
  placement:
    constraints:
      - node.role==worker
      - node.labels.zone==barcelona
    preferences:
      - spread: node.labels.zone
```

També permet determinar el procés a seguir a l'hora d'aplicar actualitzacions, incloses les reversions:

```yaml
deploy:
  update_config:
    parallelism: 2        # Tasques simultànies
    delay: 10s            # Espera entre lots
    failure_action: rollback
    order: start-first
  rollback_config:
    parallelism: 1
    delay: 5s
```

També permet definir els recursos assignats a cada servei:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

I la política de reinicis:

```yaml
deploy:
  restart_policy:
    condition: on-failure
    delay: 5s
    max_attempts: 3
    window: 120s
```

## Desplegar un stack

La comanda `docker stack deploy` desplega un stack al clúster:

```bash
docker stack deploy --compose-file docker-stack.yml myapp
```

En executar aquesta comanda, Swarm crearà els serveis, les xarxes i els volums especificats al fitxer, amb el prefix del stack:

* Serveis: `myapp_web`, `myapp_api`, `myapp_db`.
* Xarxes: `myapp_frontend`, `myapp_backend`.
* Volums: `myapp_db-data`.

## Gestionar stacks

La primera passa és poder llistar els stacks:

```bash
docker stack ls
```

Un exemple de sortida seria el següent:

```text
NAME      SERVICES   ORCHESTRATOR
myapp     3          Swarm
```

La següent passa seria veure serveis d'un stack:

```bash
docker stack services myapp
```

Un exemple de sortida seria el següent:

```text
ID             NAME         MODE         REPLICAS   IMAGE
abc123         myapp_web    replicated   3/3        nginx:1.26
def456         myapp_api    replicated   2/2        myapp/api:latest
ghi789         myapp_db     replicated   1/1        postgres:16
```

La següent passa seria veure les tasques d'un stack:

```bash
docker stack ps myapp
```

Aquest ordre mostra totes les tasques de tots els serveis del stack, incloent l'historial.

Si escau, podem eliminar un stack:

```bash
docker stack rm myapp
```

Això elimina tots els serveis i xarxes del stack. Els volums es mantenen per defecte (per evitar pèrdua de dades accidental).

Molt possiblement haurem d'actualitzar l'stack. Per actualitzar un stack, simplement modificarem el fitxer [*](YAML) i tornarem a executar `docker stack deploy`:

```bash
docker stack deploy -c docker-stack.yml myapp
```

Swarm compararà l'estat actual amb el desitjat i aplicarà els canvis necessaris:

* Si un servei ha canviat, farà rolling update.
* Si un servei és nou, el crearà.
* Si un servei ha desaparegut del fitxer, l'eliminarà.

## Variables d'entorn

Com amb Compose, podem definir variables d'entorn en un fitxer `.env` al mateix directori on tenim el nostre fitxer `docker-compose.yml`:

```bash
NGINX_VERSION=1.27
WEB_REPLICAS=5
```

I usar aquestes variables d'entorn al fitxer YAML:

```yaml
services:
  web:
    image: nginx:${NGINX_VERSION:-1.26}
    deploy:
      replicas: ${WEB_REPLICAS:-3}
```

Per conveniència, també tenim l'opció de passar-les directament:

```bash
NGINX_VERSION=1.27
docker stack deploy -c docker-stack.yml myapp
```

## Múltiples fitxers

Si, en comptes de tenir un fitxer separat `docker-stack.yml`, preferim seguir el paradigma de Docker Compose, podem combinar múltiples fitxers per separar la configuració base de la configuració específica d'entorn:

```bash
docker stack deploy \
  -c docker-compose.yml \
  -c docker-compose.production.yml \
  myapp
```

El segon fitxer sobreescriu o amplia el primer. Això permet fer la següent combinació:

* `docker-compose.yml`: Configuració base per a desenvolupament.
* `docker-compose.production.yml`: Configuració per a producció.

Per exemple, podríem tenir el següent fitxer de configuració de producció:

```yaml
# docker-compose.production.yml
services:
  web:
    deploy:
      replicas: 5
      resources:
        limits:
          memory: 1G

  db:
    deploy:
      placement:
        constraints:
          - node.labels.storage==ssd
```

En aquest cas, tres paràmetres defineixen característiques de l'entorn de producció:

1. Usarem cinc rèpliques del servei `web`.
2. Limitarem cadascun d'aquests serveis a 1G de RAM.
3. Restringirem l'ubicació del servidor de base de dades als nodes amb discos d'estat sòlid.

Ara bé, cal tenir en compte que algunes opcions de Docker Compose no funcionen a Swarm:

| Opció                | Motiu                                                                |
|:---------------------|:---------------------------------------------------------------------|
| `build`              | Swarm no construeix imatges, cal usar imatges prèviament construïdes |
| `depends_on`         | Les aplicacions han de tolerar dependències no disponibles           |
| `container_name`     | Els noms són gestionats per Swarm                                    |
| `links`              | Obsolet; cal usar xarxes                                             |
| `network_mode: host` | No suportat per a serveis replicats                                  |

> Docker Swarm ignora silenciosament les opcions no suportades (mostra un avís), però continua amb el desplegament. Això permet usar el mateix fitxer Compose per a desenvolupament i producció.

Si el fitxer conté `build`, cal construir les imatges primer i pujar-les a un registre:

```bash
docker compose build
docker compose push
```

I després ja podem fer el desplegament.

## Exemple complet     

Vegem un exemple d'una aplicació web amb NGINX com a proxy invers, una API amb Python i Redis per a cache, en un entorn de desenvolupament:

```yaml
# docker-stack.yml
services:
  proxy:
    image: nginx:1.26-alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
    networks:
      - frontend

  api:
    image: myapp/api:1.0
    environment:
      - REDIS_HOST=cache
      - LOG_LEVEL=info
    deploy:
      replicas: 4
      update_config:
        parallelism: 2
        delay: 5s
        failure_action: rollback
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
    networks:
      - frontend
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  cache:
    image: redis:7-alpine
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role==worker
    networks:
      - backend
    volumes:
      - cache-data:/data

networks:
  frontend:
    driver: overlay
  backend:
    driver: overlay
    internal: true

volumes:
  cache-data:
```

Per desplegar aquesta configuració usaríem la següent comanda:

```bash
docker stack deploy -c docker-stack.yml webapp
```

Imaginem que editam el fitxer `docker-stack.yml` i modificam la imatge de la nostra API a `myapp/api:1.1`. Llavors, per actualitzar l'API a aquesta nova versió, usaríem la següent ordre:

```bash
docker stack deploy -c docker-stack.yml webapp
```

Swarm farà *rolling update* de l'API sense afectar el proxy ni el cache.

> La pràctica recomanada és definir el `HEALTHCHECK` complet al `Dockerfile`, usant el `docker-compose.yml` només per a ajustar certs valors o quan la imatge és d'un tercer i no inclou aquesta configuració.

## Bind mounts

Quant al bind mount del servei `proxy` de l'exemple anterior, essent adient per a un entorn de desenvolupament, cal tenir en compte les següents dificultats en un entorn de producció:

* El fitxer ha d'existir a tots els nodes on pugui executar-se el servei.
* Cal copiar el fitxer a cada node del clúster (sincronització manual).
* Ens arriscam a tenir versions diferents a cada node.
* Si un node nou s'uneix al clúster, no tendrà el fitxer.

Per a solventar aquests problemes tenim diverses opcions:

| Mètode                | Cas d'ús                | Avantatge                             |
|-----------------------|-------------------------|---------------------------------------|
| Docker Configs        | Fitxers de configuració | Distribuït automàticament pel clúster |
| Docker Secrets        | Credencials, claus      | Xifrat i segur                        |
| Imatge personalitzada | Configuració estàtica   | Immutable, versionada                 |
| Volums NFS            | Fitxers compartits      | Accessible des de tots els nodes      |

> Docker Configs i Docker Secrets es tracten al [següent article]({{< relref "/posts/docker/swarm/configs-secrets/" >}}).

Pel cas del fitxer `nginx.conf` de l'exemple de l'apartat anterior, Docker Configs seria una molt bona opció. Per fer-ne ús, el primer que faríem seria canviar la configuració del fitxer `docker-stacks.yml`:

```yaml
services:
  proxy:
    image: nginx:1.26-alpine
    configs:
      - source: nginx_config
        target: /etc/nginx/nginx.conf

configs:
  nginx_config:
    file: ./nginx.conf
```

Una vegada creat el contingut del fitxer `nginx.conf` segons les nostres necessitats, usaríem les següents comandes per a crear la configuració i actualitzar el servei:

```bash
# Cream la configuració
docker config create nginx_config nginx.conf

# Actualitzam el servei
docker service update \
  --config-add source=nginx_config,target=/etc/nginx/nginx.conf \
  mystack_proxy
```

Això no vol dir que no tenguem escenaris on els *bind mounts* no siguin necessaris a producció, com per exemple:

* Fitxers de logs que han de persistir al host.
* Sockets (com `/var/run/docker.sock` per a Traefik).
* Dades locals amb constraint de node (el servei sempre s'executa al mateix node).

> Aquesta secció només introdueix el concepte de Docker Configs. Al [següent article]({{< relref "/posts/docker/swarm/configs-secrets/" >}}) es profunditza en la gestió.

## Resum

| Comanda                             | Funció                         |
|:------------------------------------|:-------------------------------|
| `docker stack deploy -c FILE STACK` | Desplega o actualitza un stack |
| `docker stack ls`                   | Llista els stacks              |
| `docker stack services STACK`       | Mostra els serveis d'un stack  |
| `docker stack ps STACK`             | Mostra les tasques d'un stack  |
| `docker stack rm STACK`             | Elimina un stack               |

## Exercici pràctic

L'objectiu d'aquest exercici és desplegar una aplicació multi-servei usant docker Stack.

Requisits:

* Un clúster docker Swarm amb almanco 3 nodes.
* Connectivitat de xarxa entre els nodes.

Tasques:

1. **Crear el fitxer stack**:
   * Crea un fitxer `docker-compose.yml` amb els següents serveis:
     * `frontend`: imatge `nginxdemos/hello`, 3 rèpliques, port 8080 publicat.
     * `backend`: imatge `hashicorp/http-echo` amb l'argument `-text="Hola des del backend"`, 2 rèpliques, sense port publicat.
     * `monitor`: imatge `prom/prometheus:latest`, 1 rèplica, port 9090 publicat.
   * Defineix dues xarxes: `public` i `internal` (aquesta darrera marcada com a interna).
   * Connecta `frontend` a `public`, `backend` a `internal`, i `monitor` a ambdues.

2. **Desplegar el stack**:
   * Desplega el stack amb el nom `demo`.
   * Verifica que els serveis s'han creat amb `docker stack services demo`.
   * Comprova que les tasques estan distribuïdes entre els nodes.

3. **Comprovar el funcionament**:
   * Accedeix a `http://<ip_node>:8080` i verifica que el frontend respon.
   * Accedeix a `http://<ip_node>:9090` i verifica que Prometheus està en execució.

4. **Escalar un servei**:
   * Modifica el fitxer per augmentar les rèpliques de `frontend` a 5.
   * Redesplega el stack amb `docker stack deploy`.
   * Verifica que ara hi ha 5 rèpliques de `frontend`.

5. **Actualitzar un servei**:
   * Canvia la imatge de `backend` per `hashicorp/http-echo` amb el text "Backend actualitzat".
   * Afegeix configuració d'actualització: 1 tasca simultània, 10 segons de delay.
   * Redesplega i observa el rolling update amb `docker stack ps demo`.

6. **Simular un entorn de producció**:
   * Crea un fitxer `docker-compose.produdction.yml` que:
     * Augmenti les rèpliques de `frontend` a 6.
     * Afegeixi límits de recursos a `backend` (256M memòria, 0.5 CPU).
     * Restringeixi `monitor` a nodes amb rol `manager`.
   * Desplega combinant els dos fitxers:
     ```bash
     docker stack deploy \
       -c docker-compose.yml \
       -c docker-compose.production.yml \
       demo
     ```
   * Verifica que els canvis s'han aplicat.

7. **Neteja**:
   * Elimina el stack `demo`.
   * Verifica que els serveis i xarxes s'han eliminat.
   * Comprova si els volums (si n'hi havia) s'han mantingut.
