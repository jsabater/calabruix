---
title: "Actualització i manteniment de serveis"
date: 2026-01-31
lastmod: 2026-01-31
description: "Rolling updates, rollback, gestió de fallades i actualitzacions sense downtime"
summary: "Rolling updates, rollback, gestió de fallades i actualitzacions sense downtime"
categories: ["teaching"]
tags: ["docker", "swarm"]
series: ["Docker Swarm"]
series_order: 4
weight: 40
slug: actualitzacio
---

Un dels avantatges principals de Docker Swarm és la capacitat d'actualitzar serveis en producció sense interrompre el servei als usuaris. Això s'aconsegueix mitjançant les **rolling updates**: actualitzacions progressives que van substituint les tasques antigues per tasques noves de forma controlada.

## Actualitzar un servei

La comanda `docker service update` permet modificar qualsevol aspecte d'un servei en execució. Els canvis més habituals són:

* Canviar la imatge (nova versió de l'aplicació).
* Modificar variables d'entorn.
* Ajustar els recursos assignats (CPU, memòria).
* Canviar la configuració de xarxa o volums.

Per actualitzar la imatge a una nova versió usam el paràmetre `--image`:

```bash
docker service update --image nginx:1.26 web
```

Swarm començarà a substituir les tasques antigues (amb `nginx:1.25`) per tasques noves (amb `nginx:1.26`) de forma progressiva.

Per a afegir o modificar una variable d'entorn usarem els paràmetres `--env-add` i `--env-rm`:

```bash
docker service update --env-add DEBUG=true web
docker service update --env-rm DEBUG web
```

El mateix es pot fer amb les etiquetes (*labels*):

```bash
docker service update \
  --label-add environment=production \
  --label-add version=2.1.0 \
  --label-add team=backend \
  web
docker service update --label-add prometheus.scrape=false web
docker service update --label-add traefik.enable=false web
```

Amb la primera comanda hem aprofitat per crear o modificar múltiples etiquetes alhora. Amb la segona i la tercera hem canviat l'estat de la configuració de Prometheus i Traefik.

Anàlogament a `--env-rm`, el paràmetre `--label-rm` ens permet eliminar etiquetes, per exemple etiquetes temporals o obsoletes que ja no té sentit mantenir:

```bash
docker service update --label-rm canary web
```

La instrucció anterior podria tenir sentit després de promocionar un desplegament canari a estable.

Finalment, també podem, per exemple, canviar el port publicat per un servei:

```bash
docker service update --publish-rm 80:80 --publish-add 8080:80 web
```

O canviar el número de rèpliques d'un servei, com ja vàrem veure a l'article anterior:

```bash
docker service update --replicas 5 web
```

## Rolling updates

Per defecte, quan actualitzes un servei, Swarm aplica una estratègia de **rolling update**: actualitza les tasques d'una en una, esperant que cada tasca nova estigui en execució abans de passar a la següent.

Pots configurar com es fan les actualitzacions amb els següents paràmetres de control:

| Paràmetre                 | Descripció                                                   | Valor per defecte |
|:--------------------------|:-------------------------------------------------------------|:------------------|
| `--update-parallelism`    | Nombre de tasques a actualitzar simultàniament               | 1                 |
| `--update-delay`          | Temps d'espera entre actualitzacions de tasques              | 0s                |
| `--update-failure-action` | Què fer si una tasca falla (`pause`, `continue`, `rollback`) | `pause`           |
| `--update-order`          | Ordre d'actualització (`start-first`, `stop-first`)          | `stop-first`      |

Exemple amb paràmetres personalitzats:

```bash
docker service update \
  --image nginx:1.26 \
  --update-parallelism 2 \
  --update-delay 10s \
  --update-failure-action rollback \
  web
```

Aquesta comanda:

1. Actualitza 2 tasques simultàniament (`--update-parallelism 2`).
2. Espera 10 segons entre cada lot de tasques (`--update-delay 10s`).
3. Si alguna tasca falla, fa rollback automàtic (`--update-failure-action rollback`).

El paràmetre `--update-order` controla com es substitueixen les tasques:

| Valor         | Comportament                                                    |
|:--------------|:----------------------------------------------------------------|
| `stop-first`  | Atura la tasca antiga abans de crear la nova (per defecte)      |
| `start-first` | Crea la tasca nova abans d'aturar l'antiga (menys downtime)     |

L'opció `start-first` és útil quan vols minimitzar el temps sense servei, però requereix que el node tingui recursos suficients per executar temporalment ambdues tasques.

```bash
docker service update \
  --update-order start-first \
  --image nginx:1.26 \
  web
```

### Responsabilitats

Docker Swarm **no té coneixement del que passa dins el contenidor** a nivell d'aplicació. No sap si hi ha peticions HTTP en curs, connexions de base de dades obertes, o processos a mig executar.

El que fa Swarm és:

1. Deixa de dirigir noves peticions cap a la tasca que vol aturar (la treu del balancejador del routing mesh).
2. Envia un senyal `SIGTERM` al procés principal del contenidor.
3. Espera l'`stop-grace-period` (10 segons per defecte) perquè l'aplicació es tanqui correctament.
4. Envia `SIGKILL` si el contenidor encara no s'ha aturat.

Per tant, l'aplicació ha d'estar preparada per gestionar el `SIGTERM` correctament:

* Deixar d'acceptar connexions noves.
* Esperar que les peticions en curs acabin (*graceful shutdown*).
* Tancar connexions de base de dades, alliberar recursos.
* Sortir amb codi 0.

Si l'aplicació ignora el `SIGTERM` o tarda massa, Swarm la matarà amb `SIGKILL` després del període de gràcia, provocant possibles talls en connexions actives.

A l'exemple amb NGINX usat a la secció anterior, NGINX gestiona `SIGTERM` fent un *graceful shutdown*: deixa d'acceptar connexions noves però espera que les actives acabin. Per això és relativament segur amb el `stop-grace-period` per defecte (és fàcil monitoritzar si, sovint, tenim peticions al sistema que tarden més de 10 segons en completar-se).

Les aplicacins problemàtiques, per exemple aquelles que no gestionen `SIGTERM` o que tenen un temps d'execució molt llarg, simplement moren quan reben `SIGKILL`, tallant qualsevol petició en curs.

> En producció és important ajustar el `--stop-grace-period` segons el temps màxim que pugui durar una petició a l'aplicació, i assegurar-se que l'aplicació implementa *graceful shutdown*.

## Monitoritzar l'actualització

Mentre s'executa una actualització, es conveinent monitoritzar el progrés. Podem fer-ho a través de l'estat de les tasques:

```bash
docker service ps web
```

Un exemple de sortida seria:

```text
ID       NAME        IMAGE        NODE    DESIRED STATE   CURRENT STATE
abc123   web.1       nginx:1.26   node1   Running         Running 30 seconds ago
def456   web.2       nginx:1.26   node2   Running         Running 45 seconds ago
ghi789   web.3       nginx:1.26   node3   Running         Running 5 seconds ago
jkl012    \_ web.3   nginx:1.25   node3   Shutdown        Shutdown 20 seconds ago
```

La sortida mostra:

* Les tasques actuals amb la nova imatge (`nginx:1.26`).
* Les tasques antigues en estat `Shutdown`.
* La tasca `web.3` encara s'està actualitzant, per tant mostra l'antiga (ID `jkl012`) i la nova (ID `ghi789`).

Per veure un resum bo de llegir de l'estat del servei:

```bash
docker service inspect --pretty web
```

Cerca la secció `UpdateStatus` per veure l'estat de l'actualització:

```text
UpdateStatus:
 State:         completed
 Started:       2 minutes ago
 Completed:     30 seconds ago
 Message:       update completed
```

Els estats possibles són:

| Estat                | Descripció                                             |
|:---------------------|:-------------------------------------------------------|
| `updating`           | L'actualització està en curs                           |
| `paused`             | L'actualització s'ha pausat (per fallada o manualment) |
| `completed`          | L'actualització ha finalitzat correctament             |
| `rollback_started`   | S'està fent rollback                                   |
| `rollback_completed` | El rollback ha finalitzat                              |

## Rollback

Si una actualització causa problemes, es pot tornar a la versió anterior amb un **rollback**:

```bash
docker service rollback web
```

Swarm restaurarà la configuració anterior del servei, incloent la imatge, variables d'entorn, i qualsevol altre paràmetre que s'hagi modificat.

El rollback també es pot configurar, de forma similar a les actualitzacions:

| Paràmetre                   | Descripció                                         |
|:----------------------------|:---------------------------------------------------|
| `--rollback-parallelism`    | Tasques a revertir simultàniament                  |
| `--rollback-delay`          | Temps d'espera entre reversions                    |
| `--rollback-failure-action` | Què fer si el rollback falla (`pause`, `continue`) |

Aquests paràmetres es defineixen en crear o actualitzar el servei:

```bash
docker service update \
  --rollback-parallelism 1 \
  --rollback-delay 5s \
  --rollback-failure-action pause \
  web
```

Així mateix, si configures `--update-failure-action rollback`, Swarm farà rollback automàticament quan detecti que una tasca nova no arrenca correctament:

```bash
docker service update \
  --image myapp:broken \
  --update-failure-action rollback \
  web
```

Si la imatge `myapp:broken` falla en arrencar, Swarm detectarà l'error i tornarà automàticament a la versió anterior.

## Gestió de fallades

Swarm monitoritza l'estat de les tasques i actua segons la configuració quan detecta fallades.

Durant una actualització, el paràmetre `--update-failure-action` controla el comportament:

| Valor      | Comportament                                                |
|:-----------|:------------------------------------------------------------|
| `pause`    | Pausa l'actualització per permetre investigar (per defecte) |
| `continue` | Ignora l'error i continua amb les altres tasques            |
| `rollback` | Fa rollback automàtic a la versió anterior                  |

Quan Swarm atura una tasca, per defecte envia un senyal `SIGTERM` i espera 10 segons abans d'enviar `SIGKILL`. Es pot ajustar aquest període de gràcia:

```bash
docker service update --stop-grace-period 30s web
```

Això dona 30 segons a l'aplicació per tancar connexions i alliberar recursos de forma neta.

Quan una tasca falla (no durant una actualització, sinó en operació normal), Swarm la reinicia automàticament. Aquest comportament també és configurable:

```bash
docker service update \
  --restart-condition on-failure \
  --restart-delay 5s \
  --restart-max-attempts 3 \
  --restart-window 120s \
  web
```

La següent taula explica els paràmetres de l'exemple:

| Paràmetre                | Descripció                                            |
|:-------------------------|:------------------------------------------------------|
| `--restart-condition`    | Quan reiniciar: `none`, `on-failure`, `any` (defecte) |
| `--restart-delay`        | Temps entre intents de reinici                        |
| `--restart-max-attempts` | Màxim d'intents dins la finestra                      |
| `--restart-window`       | Finestra de temps per comptar intents                 |

## Health checks

Els health checks permeten a Swarm verificar que l'aplicació funciona correctament, no només que el contenidor està en execució. Per això és tant important fer-ne ús. Podem definir un health check de la següent forma:

```bash
docker service update \
  --health-cmd "curl -f http://localhost/ || exit 1" \
  --health-interval 30s \
  --health-timeout 10s \
  --health-retries 3 \
  --health-start-period 60s \
  web
```

La següent taula explica els paràmetres de l'exemple:

| Paràmetre               | Descripció                                        |
|:------------------------|:--------------------------------------------------|
| `--health-cmd`          | Comanda per verificar la salut del contenidor     |
| `--health-interval`     | Freqüència de comprovació                         |
| `--health-timeout`      | Temps màxim per a la comprovació                  |
| `--health-retries`      | Intents fallits abans de marcar com *unhealthy*   |
| `--health-start-period` | Temps inicial abans de començar les comprovacions |

Quan un contenidor es marca com *unhealthy*, Swarm l'atura i en crea un de nou.

> El més habitual és definir el health check al `Dockerfile`, amb la instrucció `HEALTHCHECK`. Si es defineix tant al `Dockerfile` com al servei, la configuració del servei té prioritat.

## Resum

| Comanda                                           | Funció                               |
|:--------------------------------------------------|:-------------------------------------|
| `docker service update --image IMATGE SERVEI`     | Actualitza la imatge del servei      |
| `docker service update --env-add VAR=VAL SERVEI`  | Afegeix una variable d'entorn        |
| `docker service update --env-rm VAR SERVEI`       | Elimina una variable d'entorn        |
| `docker service update --replicas N SERVEI`       | Canvia el nombre de rèpliques        |
| `docker service update --update-parallelism N`    | Tasques a actualitzar simultàniament |
| `docker service update --update-delay TEMPS`      | Espera entre actualitzacions         |
| `docker service update --update-order ORDRE`      | Ordre: `stop-first` o `start-first`  |
| `docker service update --stop-grace-period TEMPS` | Temps de gràcia abans de `SIGKILL`   |
| `docker service rollback SERVEI`                  | Torna a la versió anterior           |
| `docker service ps SERVEI`                        | Monitoritza l'estat de les tasques   |

## Exercici pràctic

L'objectiu d'aquest exercici és practicar les actualitzacions de serveis, configurar rolling updates i fer rollbacks.

Requisits:

* Un clúster Docker Swarm amb almanco 3 nodes.
* Connectivitat de xarxa entre els nodes.

Tasques:

1. **Crear un servei inicial**:
   * Crea un servei anomenat `webapp` amb la imatge `nginx:1.24` i 4 rèpliques.
   * Publica el port 80.
   * Verifica que totes les rèpliques s'estan executant correctament.

2. **Actualització bàsica**:
   * Actualitza el servei a la imatge `nginx:1.25`.
   * Observa el progrés amb `docker service ps webapp`.
   * Verifica que totes les tasques usen la nova imatge.

3. **Rolling update controlat**:
   * Actualitza a `nginx:1.26` amb els següents paràmetres:
     * 2 tasques simultànies.
     * 15 segons d'espera entre lots.
   * Monitoritza el progrés en temps real.
   * Comprova la durada total de l'actualització.

4. **Rollback manual**:
   * Executa un rollback del servei.
   * Verifica que les tasques tornen a la versió anterior (`nginx:1.25`).
   * Comprova l'estat del rollback amb `docker service inspect --pretty webapp`.

5. **Simular una fallada**:
   * Actualitza el servei a una imatge inexistent: `nginx:inexistent`.
   * Observa com l'actualització es pausa.
   * Executa un rollback per recuperar el servei.

6. **Rollback automàtic**:
   * Configura el servei amb `--update-failure-action rollback`.
   * Torna a intentar l'actualització a `nginx:inexistent`.
   * Observa com Swarm fa rollback automàticament.

7. **Health check**:
   * Actualitza el servei afegint un health check que comprovi que nginx respon.
   * Verifica que les tasques es marquen com *healthy*.
   * Consulta l'estat de salut amb `docker inspect` sobre un dels contenidors.

8. **Neteja**:
   * Elimina el servei `webapp`.
