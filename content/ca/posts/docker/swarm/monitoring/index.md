---
title: "Monitorització i troubleshooting"
date: 2026-03-02
lastmod: 2026-03-02
description: "Diagnòstic, depuració, logs centralitzats i monitorització amb Grafana Stack"
summary: "Diagnòstic, depuració, logs centralitzats i monitorització amb Grafana Stack"
categories: ["teaching"]
tags: ["docker", "swarm", "monitoring", "troubleshooting", "grafana", "loki", "prometheus"]
series: ["Docker Swarm"]
series_order: 13
weight: 130
slug: monitoritzacio-troubleshooting
---

Quan un servei falla o es comporta de manera inesperada, cal tenir les eines i el coneixement per diagnosticar i resoldre el problema ràpidament. En aquest article veurem com fer diagnòstic amb eines de terminal, interpretar els errors més comuns, i configurar un sistema de monitorització centralitzat amb l'stack de Grafana.

## Diagnòstic ràpid

Quan alguna cosa no funciona, necessitem eines que ens donin informació immediata. Aquesta secció recull les comandes més útils per a diagnòstic en temps real.

### Visió ràpida

En primer lloc ens interessarà obtenir una visió ràpida de l'estat general del clúster. Com ja hem vist en anteriors articles, comptam amb les següents comandes `docker`:

* Nodes del clúster i el seu estat:
  ```bash
  docker node ls
  ```
* Serveis i les seves rèpliques:
  ```bash
  docker stack services myapp
  ```
* Totes les tasques de l'stack:
  ```bash
  docker stack ps myapp
  ```
* Tasques amb errors (filtre per estat):
  ```bash
  docker stack ps myapp --filter "desired-state=shutdown"
  ```

### Consum de recursos

En segon lloc ens interessarà mostrar el consum de recursos de tots els contenidors en temps real. Per això tenim la comanda `docker stats`, que podem parametritzar:

* Visió bàsica de tots els contenidors:
  ```bash
  docker stats
  ```
* Visió d'un contenidor específic:
  ```bash
  docker stats $(docker ps -q -f name=myapp_web)
  ```
* Si volem un format personalitzat hem d'usar `--format`:
  ```bash
  docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
  ```
  Sortida d'exemple:
  ```
  NAME                CPU %     MEM USAGE / LIMIT
  myapp_web.1         2.34%     156MiB / 512MiB
  myapp_web.2         1.89%     148MiB / 512MiB
  myapp_postgres.1    0.45%     89MiB / 256MiB
  myapp_redis.1       0.12%     12MiB / 128MiB
  ```

> La comanda `docker ps -q -f name=myapp_web` retorna l'ID del contenidor a partir del nom del servei. Usam aquest mecanisme perquè el nom del contenidor inclou un sufix aleatori, generat per Docker Swarm.

### Esdeveniments

En tercer lloc ens podrà interessar revisar els esdeveniments del clúster. Per això tenim la comanda `docker events`, que mostra els esdeveniments del clúster en temps real i que també podem parametritzar:

* Tots els esdeveniments:
  ```bash
  docker events
  ```
* Esdeveniments d'un tipus específic:
  ```bash
  docker events --filter type=service
  docker events --filter type=container
  ```
* Esdeveniments des d'un moment concret:
  ```bash
  docker events --since "2026-03-02T10:00:00"
  ```
* Esdeveniments amb format JSON (útil per processar):
  ```bash
  docker events --format '{{json .}}'
  ```

Exemple de sortida:
```text
2026-03-02T10:30:15 service update myapp_web (replicas.new=3, replicas.old=2)
2026-03-02T10:30:16 container start abc123 (name=myapp_web.3.xyz)
2026-03-02T10:30:18 container health_status: healthy abc123
```

> La comanda `docker events` és molt útil per veure què està passant durant un desplegament o quan hi ha problemes.

### Inspecció detallada

Una vegada tenim una idea general del que pot estar passant, segurament ens convendrà fer una inspecció detallada. Per obtenir informació detallada d'un servei o tasca usarem `docker service`, que també podem parametritzar:

* Informació completa d'un servei:
  ```bash
  docker service inspect myapp_web
  ```
* En format llegible:
  ```bash
  docker service inspect --pretty myapp_web
  ```
* Extreure camps específics:
  ```bash
  docker service inspect myapp_web --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
  docker service inspect myapp_web --format '{{json .Spec.TaskTemplate.Resources}}'
  ```

Per veure per què una tasca ha fallat podem:

* Mostrar errors del conjunt de les tasques:
  ```bash
  docker stack ps myapp --no-trunc
  ```
* Mostrar errors d'una tasca específica:
  ```bash
  docker inspect <task_id> --format '{{.Status.Err}}'
  ```

### Interactivitat

Finalment, és possible que necessitem accedir dins d'un contenidor en execució per a depurar-lo. Per això usarem la ja coneguda comanda `docker exec`:

* Shell interactiva:
  ```bash
  docker exec -it $(docker ps -q -f name=myapp_web) sh
  ```
* Executar una comanda:
  ```bash
  docker exec $(docker ps -q -f name=myapp_web) ps aux
  ```
* Veure variables d'entorn:
  ```bash
  docker exec $(docker ps -q -f name=myapp_web) env
  ```

> Les eines de les que disposarem dins d'un contenidor en execució depenen de la imatge que haguem usat. Imatges més lleugeres, com les basades en Alpine Linux, no inclouen moltes de les eines d'usuari habituals, com `find` o `grep`, mentres que les basades en Debian Linux sí.

## Estats possibles

Docker Swarm assigna un estat a cada tasca que indica en quin punt del seu cicle de vida es troba. Aquests estats es mostren a la columna `CURRENT STATE` de les comandes `docker stack ps` i `docker service ps`. Entendre'ls és clau per diagnosticar per què un servei no funciona com s'espera.

| Estat       | Significat                                           |
|:------------|:-----------------------------------------------------|
| `new`       | Tasca creada, pendent d'assignació                   |
| `pending`   | Esperant recursos o que es compleixi un constraint   |
| `assigned`  | Assignada a un node, pendent d'execució              |
| `accepted`  | El node ha acceptat la tasca                         |
| `preparing` | Descarregant imatge o preparant recursos             |
| `starting`  | Iniciant el contenidor                               |
| `running`   | Contenidor en execució                               |
| `complete`  | Tasca finalitzada correctament (per a tasques batch) |
| `failed`    | El contenidor ha sortit amb error                    |
| `shutdown`  | Tasca aturada (per actualització o escala)           |
| `rejected`  | El node ha rebutjat la tasca                         |
| `orphaned`  | El node assignat no està disponible                  |

## Errors comuns

Quan una tasca no pot iniciar-se o falla durant l'execució, Docker Swarm mostra un missatge d'error a la columna `ERROR` de la sortida de `docker stack ps` o `docker service ps`. Aquests missatges provenen del planificador de Swarm (quan no pot assignar la tasca a cap node) o del propi contenidor (quan l'aplicació falla). A continuació es mostren els errors més comuns i el seu significat.

**No suitable node**

```
no suitable node (scheduling constraints not satisfied on X nodes)
```

Swarm no troba cap node que compleixi les restriccions (constraints). Causes:

* Etiqueta requerida no existeix a cap node.
* Tots els nodes amb l'etiqueta estan en `drain`.
* El constraint `node.role` no coincideix.

**Insufficient resources**

```
no suitable node (insufficient resources on X nodes)
```

No hi ha prou recursos disponibles. Causes:

- Reserva de memòria o CPU massa alta.
- Altres serveis consumeixen els recursos.

**Image not found** o **Manifest unknown**

```
no such image: myuser/myapp:1.2.3
```

La imatge no existeix al registre o el tag és incorrecte. Causes:

* Error tipogràfic al nom de la imatge.
* La imatge no s'ha pujat al registre.
* Problemes d'autenticació amb el registre.

**Container unhealthy**

```
task: non-zero exit (137): container unhealthy
```

El healthcheck ha fallat repetidament. Causes:

* L'aplicació no respon al healthcheck.
* El healthcheck està mal configurat.
* L'aplicació necessita més temps per arrencar.

**Network not found**

```
network myapp_backend not found
```

La xarxa referenciada no existeix. Causes:

* L'stack no s'ha desplegat correctament.
* La xarxa s'ha eliminat manualment.

## Depurar errors

Depurar errors és ciència, però també art. S'aprèn amb el temps, practicant. Quan una tasca falla, seguir aquest ordre et facilitarà el procés de cerca de l'origen del problema:

1. Estat de la tasca:
   ```bash
   docker stack ps myapp --no-trunc
   ```

2. Logs del servei:
   ```bash
   docker service logs myapp_web --tail 100
   ```

3. Esdeveniments recents:
   ```bash
   docker events --since "10m" --filter service=myapp_web
   ```

4. Inspecció de la tasca:
   ```bash
   docker inspect <task_id> --format '{{.Status.Err}}'
   ```

5. Recursos del node:
   ```bash
   docker node inspect <node> \
   --format '{{json .Description.Resources}}'
   ```

## Problemes i solucions

Taula de referència ràpida dels problemes més comuns que pots trobar-te en un clúster de Docker Swarm, amb les seves solucions (troubleshooting):

| Símptoma                          | Causa probable            | Solució                                        |
|:----------------------------------|:--------------------------|:-----------------------------------------------|
| Tasca en `pending` indefinidament | Constraints impossibles   | Revisar etiquetes i constraints                |
| Tasca en `preparing` molt temps   | Imatge gran o xarxa lenta | Usar imatges més lleugeres, verificar connexió |
| Servei reinicia constantment      | Aplicació falla a l'inici | Revisar logs, verificar configuració           |
| `no suitable node`                | Constraint no satisfet    | Revisar etiquetes dels nodes                   |
| `insufficient resources`          | Recursos insuficients     | Reduir reserves o afegir nodes                 |
| Contenidor `unhealthy`            | Healthcheck falla         | Ajustar interval/timeout del healthcheck       |
| Connexió refusada entre serveis   | Xarxa mal configurada     | Verificar que els serveis comparteixen xarxa   |
| Volum no accessible               | Volum en un altre node    | Usar constraint per fixar el servei al node    |

Exemples pràctics per a trobar i solucionar aquesta problemes més comuns:

**Servei que no arrenca per constraint**

Detecció:

```bash
$ docker stack ps myapp
ID       NAME         IMAGE         NODE   DESIRED STATE   CURRENT STATE
abc123   myapp_db.1   postgres:18   -      Running         Pending 2 minutes ago
```

Diagnòstic:

```bash
$ docker service ps myapp_db --no-trunc
"no suitable node (scheduling constraints not satisfied on 3 nodes)"
```

Investigació:

```bash
$ docker service inspect myapp_db --format \
'{{json .Spec.TaskTemplate.Placement.Constraints}}'
["node.labels.storage==ssd"]

$ docker node ls -q | xargs -I {} docker node inspect {} \
--format '{{.Description.Hostname}}: {{.Spec.Labels}}'
node1: map[]
node2: map[]
node3: map[]
```

Solució:

```bash
docker node update --label-add storage=ssd node1
```

**Servei que es reinicia constantment**

Detecció:

```bash
$ docker stack ps myapp
myapp_web.1     Running    Running 10 seconds ago
\_myapp_web.1   Shutdown   Failed 15 seconds ago   "task: non-zero exit (1)"
\_myapp_web.1   Shutdown   Failed 30 seconds ago   "task: non-zero exit (1)"
```

Diagnòstic:

```bash
$ docker service logs myapp_web --tail 50
Error: DATABASE_URL environment variable not set
```

Solució: Afegir la variable d'entorn al servei.

**Connexió refusada entre serveis**

Problema: L'aplicació no pot connectar a PostgreSQL.

Diagnòstic:

```bash
$ docker exec -it $(docker ps -q -f name=myapp_web) sh
$ ping postgres
ping: bad address 'postgres'
```

Investigació:

```bash
$ docker service inspect myapp_web \
--format '{{json .Spec.TaskTemplate.Networks}}'
[{"Target":"abc123"}]

$ docker service inspect myapp_postgres \
--format '{{json .Spec.TaskTemplate.Networks}}'
[{"Target":"def456"}]
```

Solució: Els serveis estan en xarxes diferents. Cal afegir ambdós a la mateixa xarxa `backend`.

## Configuració de logs

Docker Swarm permet configurar on i com s'emmagatzemen els logs dels contenidors. Amb aquest objectiu suporta un seguit de controladors, resumits a la següent taula:

| Driver      | Descripció                                       |
|:------------|:-------------------------------------------------|
| `json-file` | Per defecte. Guarda logs en fitxers JSON al node |
| `journald`  | Envia logs a systemd journal                     |
| `syslog`    | Envia logs a un servidor syslog                  |
| `fluentd`   | Envia logs a Fluentd                             |
| `gelf`      | Envia logs en format GELF (Graylog)              |
| `none`      | Desactiva els logs                               |

La configuració del controlador i la resta de paràmetres de *logging* es fa al servei, dins el fitxer `docker-stack.yml`:

```yaml
services:
  web:
    image: myuser/myapp:latest
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
        labels: "service,environment"
```

Per enviar logs directament a Loki, podem usar el driver de Loki:

```yaml
services:
  web:
    image: myuser/myapp:latest
    logging:
      driver: loki
      options:
        loki-url: "http://loki:3100/loki/api/v1/push"
        loki-batch-size: "400"
        loki-retries: "3"
        loki-external-labels: "job=myapp,service={{.Name}}"
```

Aquesta configuració requereix que el plugin de Loki estigui instal·lat als nodes:

```bash
docker plugin install grafana/loki-docker-driver:latest \
--alias loki --grant-all-permissions
```

Una alternativa més flexible és usar Grafana Alloy per recollir els logs, com veurem a la secció següent.

## Monitorització

Per a una monitorització completa, l'stack de Grafana ofereix una solució integrada:

* Grafana Alloy és l'agent que recull mètriques i logs.
* Prometheus és la base de dades de mètriques.
* Loki és la base de dades de logs.
* Grafana s'usa per a visualitzacions i alertes.

```text
┌─────────────────────────────────────────────────────────────┐
│                      Clúster Swarm                          │
│                                                             │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐                     │
│  │   web   │  │  worker │  │ postgres │  ← Serveis          │
│  └────┬────┘  └────┬────┘  └────┬─────┘                     │
│       │            │            │                           │
│       └────────────┴────────────┘                           │
│                    │                                        │
│              ┌─────▼─────┐                                  │
│              │   Alloy   │  ← Recull logs i mètriques       │
│              └─────┬─────┘                                  │
│                    │                                        │
└────────────────────┼────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
   ┌─────────┐              ┌─────────────┐
   │  Loki   │              │ Prometheus  │
   │ (logs)  │              │ (mètriques) │
   └────┬────┘              └─────┬───────┘
        │                         │
        └───────────┬─────────────┘
                    │
               ┌────▼────┐
               │ Grafana │  ← Visualització
               └─────────┘
```

### Servei Alloy

[Grafana Alloy](https://grafana.com/docs/alloy/latest/) és l'agent unificat de Grafana per recollir mètriques, logs i traces. Cal afegir-lo a l'stack, com un servei més:

```yaml
# docker-stack.yml

services:
  # ...

  alloy:
    image: grafana/alloy:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    configs:
      - source: alloy_config
        target: /etc/alloy/config.alloy
    networks:
      - backend
    deploy:
      mode: global  # Un per node
      resources:
        limits:
          memory: 128M

configs:
  alloy_config:
    file: docker/alloy/config.alloy
```

El fitxer de configuració d'Alloy usa el format HCL (HashiCorp Configuration Language). Com a versió inicial podem crear el següent fitxer dins `docker/allow/config.alloy` al nostre repositori, que només inclou logs:

```hcl
// Descobriment de contenidors Docker
discovery.docker "containers" {
  host = "unix:///var/run/docker.sock"
}

// Recollida de logs
loki.source.docker "docker_logs" {
  host = "unix:///var/run/docker.sock"
  targets = discovery.docker.containers.targets
  forward_to = [loki.write.default.receiver]
  labels = {
    job = "docker",
  }
}

// Enviament a Loki
loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}
```

### Mètriques amb cAdvisor

La configuració d'Alloy que hem vist anteriorment només recull logs. Per a mètriques dels contenidors, necessitem [cAdvisor](https://github.com/google/cadvisor) (Container Advisor), una eina de Google que exposa mètriques de CPU, memòria, xarxa i disc de cada contenidor.

També ens cal afegir-lo com a servei:

```yaml
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - backend
    deploy:
      mode: global
      resources:
        limits:
          memory: 128M
```

Després, afegim el bloc de scraping a la configuració d'Alloy perquè reculli les mètriques de cAdvisor i les enviï a Prometheus:

```hcl
// Afegir a docker/alloy/config.alloy

// Mètriques de cAdvisor
prometheus.scrape "cadvisor" {
  targets = [{
    __address__ = "cadvisor:8080",
  }]
  metrics_path = "/metrics"
  forward_to = [prometheus.remote_write.default.receiver]
}

// Enviament a Prometheus
prometheus.remote_write "default" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}
```

Amb aquesta configuració, Alloy recull mètriques de cAdvisor cada 15 segons (per defecte) i les envia a Prometheus, on podrem consultar-les i visualitzar-les amb Grafana.

### Dashboards

Grafana Labs ofereix dashboards predefinits per a Docker Swarm:

* Docker Swarm Cluster: Visió general del clúster.
* Docker Swarm Services: Detall per servei.
* Docker Container Metrics: Mètriques de contenidors individuals.

Es poden importar des de [Grafana Dashboards](https://grafana.com/grafana/dashboards/) cercant "docker swarm".

### Consideracions

L'stack complet de Grafana (Alloy + Prometheus + Loki + Grafana) requereix recursos significatius i és un tema extens per si mateix. Per a entorns de producció, es recomana:

- Desplegar Prometheus, Loki i Grafana fora del clúster d'aplicació, o en nodes dedicats.
- Usar Grafana Cloud per evitar la gestió de la infraestructura de monitorització.
- Començar amb logs centralitzats (Alloy + Loki) i afegir mètriques progressivament.

La configuració detallada d'aquest stack queda fora de l'abast d'aquest article, però els exemples proporcionats serveixen com a punt de partida.

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l’aprenentatge progressiu.

### Exercici 1

**Diagnòstic amb eines de terminal**

Familiaritza't amb les comandes de diagnòstic de Docker Swarm.

Tasques:

1. Desplega l'stack de l'aplicació i verifica l'estat:
   ```bash
   docker stack deploy -c docker-stack.yml myapp
   docker stack services myapp
   docker stack ps myapp
   ```

2. Controla els recursos en temps real:
   ```bash
   docker stats
   ```

3. Observa els esdeveniments del clúster mentre fas un canvi:
   ```bash
   # En un terminal
   docker events --filter type=service
   
   # En un altre terminal
   docker service scale myapp_web=5
   ```

4. Practica l'extracció d'informació amb formats personalitzats:
   ```bash
   docker service inspect myapp_web \
   --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
   docker node ls --format '{{.Hostname}}: {{.Status}}'
   ```

### Exercici 2

**Resolució de problemes**

Diagnostica i resol problemes comuns.

Tasques:

1. Simula un problema de restricció impossible:
   ```bash
   # Afegeix una constraint que no es pot satisfer
   docker service update \
   --constraint-add "node.labels.gpu==true" myapp_web
   ```

2. Diagnostica el problema:
   ```bash
   docker stack ps myapp --no-trunc
   docker service ps myapp_web --no-trunc
   ```

3. Resol el problema:
   ```bash
   # Opció A: Afegir l'etiqueta a un node
   docker node update --label-add gpu=true node1
   
   # Opció B: Eliminar la restricció
   docker service update --constraint-rm "node.labels.gpu==true" myapp_web
   ```

4. Simula un problema de recursos:
   ```bash
   docker service update --reserve-memory 100GB myapp_web
   ```

5. Diagnostica i resol el problema de recursos.

### Exercici 3

**Logs centralitzats**

Configura l'enviament de logs a Loki.

Tasques:

1. Instal·la el plugin de Loki als nodes del clúster:
   ```bash
   docker plugin install grafana/loki-docker-driver:latest \
   --alias loki --grant-all-permissions
   ```

2. Modifica el servei web per usar el driver de Loki:
   ```yaml
   services:
     web:
       logging:
         driver: loki
         options:
           loki-url: "http://loki:3100/loki/api/v1/push"
           loki-external-labels: "job=myapp,service={{.Name}}"
   ```

3. Desplega un servei Loki bàsic per a proves:
   ```bash
   docker service create --name loki \
     --network myapp_backend \
     -p 3100:3100 \
     grafana/loki:latest
   ```

4. Redesplega l'stack i verifica que els logs arriben a Loki:
   ```bash
   curl -G "http://localhost:3100/loki/api/v1/query" \
     --data-urlencode 'query={job="myapp"}'
   ```

5. Afegeix Grafana i importa un dashboard bàsic per visualitzar els logs.
