---
title: "Tècniques avançades"
date: 2026-06-06
lastmod: 2026-06-06
description: "Tècniques avançades de Docker Compose: escalat, límits de recursos, logging, extensions YAML, contenidors d'inicialització i integració amb Traefik."
summary: "Tècniques avançades de Docker Compose: escalat, límits de recursos, logging, extensions YAML, contenidors d'inicialització i integració amb Traefik."
categories: ["teaching"]
tags: ["docker", "compose", "advanced", "traefik", "scaling"]
series: ["Docker Compose"]
series_order: 9
weight: 90
slug: "avancat"
---

En aquest article explorarem tècniques avançades de Docker Compose que ens permetran gestionar aplicacions més complexes i preparar-les per a entorns de producció. Usarem [Odoo](https://www.odoo.com/), un ERP de codi obert, com a exemple pràctic per demostrar aquestes tècniques.

## Sintaxi YAML

Quan els fitxers `compose.yaml` creixen, sovint ens trobem repetint configuracions similars entre serveis. YAML ofereix mecanismes per evitar aquesta duplicació: ancoratges (*anchors*), àlies (*aliases*) i extensions.

### Ancoratges i àlies

Els ancoratges (`&nom`) permeten marcar un bloc de YAML per reutilitzar-lo després amb un àlies (`*nom`):

```yaml
services:
  app1:
    image: myapp:latest
    environment: &common-env
      TZ: Europe/Madrid
      LANG: ca_ES.UTF-8
      LOG_LEVEL: info

  app2:
    image: myapp:latest
    environment: *common-env
```

En aquest exemple, `&common-env` defineix un ancoratge i `*common-env` el referencia. Ambdós serveis tendran les mateixes variables d'entorn.

### Fusió amb `<<`

Si volem reutilitzar un bloc però afegir o sobreescriure algunes claus, usam l'operador de fusió `<<`:

```yaml
services:
  app1:
    image: myapp:latest
    environment: &common-env
      TZ: Europe/Madrid
      LANG: ca_ES.UTF-8
      LOG_LEVEL: info

  app2:
    image: myapp:latest
    environment:
      <<: *common-env
      LOG_LEVEL: debug    # Sobreescriu
      DEBUG: "true"       # Afegeix
```

### Extensions amb `x-`

Docker Compose ignora qualsevol clau que comenci amb `x-`, la qual cosa ens permet definir blocs reutilitzables a l'arrel del fitxer:

```yaml
x-common-env: &common-env
  TZ: Europe/Madrid
  LANG: ca_ES.UTF-8

x-healthcheck-defaults: &healthcheck-defaults
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s

x-restart-policy: &restart-policy
  restart: unless-stopped

services:
  app:
    image: myapp:latest
    <<: *restart-policy
    environment:
      <<: *common-env
      APP_ENV: production
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "curl", "-f", "http://localhost/health"]

  worker:
    image: myapp:latest
    <<: *restart-policy
    environment:
      <<: *common-env
      APP_ENV: production
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "pgrep", "-f", "worker"]
```

Aquesta tècnica és especialment útil quan tenim múltiples serveis amb configuracions similars.

## Límits de recursos

En entorns de producció és important limitar els recursos que cada contenidor pot consumir. Això evita que un servei consumeixi tots els recursos del sistema i afecti els altres.

La configuració de recursos es fa dins la secció `deploy.resources`:

```yaml
services:
  app:
    image: myapp:latest
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

- `limits`: El **màxim** de recursos que el contenidor pot usar. Si intenta superar-los, serà limitat (CPU) o **finalitzat** (memòria).
- `reservations`: El **mínim** de recursos que Docker garanteix al contenidor. Útil per assegurar que sempre hi hagi recursos disponibles.

Quant a les unitats de mesura, per a memòria podem usar:

| Unitat     | Significat |
|------------|------------|
| `b`        | Bytes      |
| `k` o `kb` | Kilobytes  |
| `m` o `mb` | Megabytes  |
| `g` o `gb` | Gigabytes  |

I per a CPU, el valor indica el nombre de nuclis (o fraccions):

| Valor   | Significat       |
|---------|------------------|
| `'0.5'` | 50% d'un nucli   |
| `'1.0'` | Un nucli complet |
| `'2.5'` | Dos nuclis i mig |

### Monitorització

Per veure el consum de recursos en temps real usam la següent comanda:

```bash
docker compose stats
```

Aquesta comanda mostra una taula amb el consum de CPU, memòria, I/O de xarxa i disc de cada contenidor:

```
CONTAINER ID   NAME   CPU %    MEM USAGE / LIMIT   MEM %    NET I/O          BLOCK I/O
a1b2c3d4e5f6   app    45.32%   234.5MiB / 512MiB   45.80%   1.23MB / 456kB   12.3MB / 0B
b2c3d4e5f6a7   db     12.10%   128.3MiB / 256MiB   50.12%   456kB / 1.2MB    5.6MB / 2.1MB
```

Per obtenir una captura puntual sense actualització contínua:

```bash
docker compose stats --no-stream
```

## Escalat de serveis

Docker Compose permet executar múltiples instàncies d'un mateix servei amb l'opció `--scale`:

```bash
docker compose up --detach --scale worker=3
```

Això crea tres contenidors del servei `worker`. És útil per a:

- Processar tasques en paral·lel, e.g., workers de cues de feina.
- Augmentar la capacitat de resposta (amb un balancejador davant).
- Testejar el comportament amb múltiples instàncies.

### Consideracions

**Ports**: Si el servei exposa ports, no podem escalar-lo directament perquè hi hauria conflictes. Cal usar un rang de ports o un proxy invers:

```yaml
services:
  app:
    image: myapp:latest
    # Malament: conflicte de ports si escalam
    # ports:
    #   - "8080:8080"

    # Bé: deixam que Docker assigni ports aleatoris
    ports:
      - "8080"
    
    # Bé: usam un rang de ports
    ports:
      - "8080-8082:8080"
```

Amb aquesta configuració, si escalem a 3 instàncies, Docker assignarà:

| Instància | Port de l'amfitió | Port del contenidor |
|-----------|-------------------|---------------------|
| Primera   | 8080              | 8080                |
| Segona    | 8081              | 8080                |
| Tercera   | 8082              | 8080                |

Si intentam escalar a més de 3 instàncies, Docker donarà error perquè no hi ha prou ports al rang.

**Volums**: Si el servei escriu a un volum, cal assegurar-se que les instàncies no entrin en conflicte. Per a dades compartides, usam volums de només lectura o sistemes de fitxers distribuïts, e.g., [CephFS](https://ceph.com/) o [GlusterFS](https://www.gluster.org/).

**Sessions**: Si l'aplicació manté estat en memòria (sessions, caché), cal externalitzar-lo (Redis, Valkey, base de dades) o usar *sticky sessions* al balancejador.

### Escalat declaratiu

També podem definir el nombre de rèpliques al `compose.yaml`:

```yaml
services:
  worker:
    image: myapp:latest
    deploy:
      replicas: 3
```

Amb aquesta configuració, `docker compose up` crearà automàticament tres instàncies del servei.

## Logging

Docker Compose permet configurar com es gestionen els logs dels contenidors a través dels control·ladors o *drivers* de *logging*.

La configuració bàsica és la seguent:

```yaml
services:
  app:
    image: myapp:latest
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

Aquesta configuració:

- Usa el driver `json-file` (el predeterminat).
- Limita cada fitxer de log a 10 MB.
- Manté un màxim de 3 fitxers (rotació automàtica).

Els següents control·ladors de *logging* estan disponibles:

| Driver      | Descripció                                                           |
|-------------|----------------------------------------------------------------------|
| `json-file` | Guarda els logs en format JSON al sistema de fitxers (predeterminat) |
| `local`     | Similar a `json-file` però amb compressió                            |
| `syslog`    | Envia els logs al dimoni syslog                                      |
| `journald`  | Envia els logs a systemd-journald                                    |
| `none`      | Desactiva el logging                                                 |
| `fluentd`   | Envia els logs a Fluentd                                             |
| `gelf`      | Envia els logs en format GELF (Graylog)                              |

**Exemple amb logging centralitzat**

Podem enviar els logs a un sistema centralitzat com [Loki](https://grafana.com/oss/loki/), un agregador de logs dissenyat per Grafana Labs. Usam extensions YAML per definir la configuració comuna:

```yaml
x-logging: &loki-logging
  driver: loki
  options:
    loki-url: "http://loki:3100/loki/api/v1/push"
    loki-batch-size: "400"
    max-size: "10m"
    max-file: "5"

services:
  loki:
    image: grafana/loki:3.7
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki
    restart: unless-stopped

  app:
    image: myapp:latest
    logging: *loki-logging

  worker:
    image: myapp:latest
    logging: *loki-logging

  db:
    image: postgres:18-alpine
    logging: *loki-logging

volumes:
  loki-data:
```

En aquest exemple:

- Definim `x-logging` amb el driver `loki` que envia els logs al servei Loki.
- Tots els serveis reutilitzen aquesta configuració amb `*loki-logging`.
- Els logs es poden consultar després des de Grafana, filtrant per contenidor, servei o qualsevol etiqueta.

Per usar el driver Loki, cal instal·lar-lo prèviament:

```bash
docker plugin install grafana/loki-docker-driver:3.7-amd64 --alias loki --grant-all-permissions
```

## Contenidors d'inicialització

De vegades necessitam executar tasques abans que els serveis principals s'iniciïn: migracions de base de dades, creació de directoris, generació de certificats, etc. Per resoldre aquestes situacions, podem usar contenidors que s'executen una vegada i després s'aturen.

### Amb `depends_on`

Una forma comuna de fer front a aquest problema és usar un patró amb `depends_on` i `service_completed_successfully`:

```yaml
services:
  migrations:
    image: myapp:latest
    command: python manage.py migrate
    depends_on:
      db:
        condition: service_healthy
    restart: "no"

  app:
    image: myapp:latest
    depends_on:
      db:
        condition: service_healthy
      migrations:
        condition: service_completed_successfully

  db:
    image: postgres:18-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
```

En aquest exemple:

- `migrations` espera que `db` estigui *healthy*.
- `migrations` executa les migracions i s'atura (`restart: "no"`).
- `app` espera que `migrations` hagi completat amb èxit.

### Múltiples tasques

Podem encadenar diverses tasques d'inicialització:

```yaml
# compose.yaml
services:
  create-dirs:
    image: busybox
    command: mkdir -p /data/uploads /data/cache
    volumes:
      - app-data:/data
    restart: "no"

  init-db:
    image: myapp:latest
    command: python manage.py migrate
    depends_on:
      db:
        condition: service_healthy
      create-dirs:
        condition: service_completed_successfully
    restart: "no"

  seed-data:
    image: myapp:latest
    command: python manage.py loaddata initial_data.json
    depends_on:
      init-db:
        condition: service_completed_successfully
    restart: "no"

  app:
    image: myapp:latest
    depends_on:
      seed-data:
        condition: service_completed_successfully
    volumes:
      - app-data:/data

  db:
    image: postgres:18-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  app-data:
```

En aquest exemple, les tasques s'executen en ordre:

1. `create-dirs` crea els directoris necessaris al volum compartit.
2. `init-db` espera que `db` estigui healthy i que `create-dirs` hagi completat, després executa les migracions.
3. `seed-data` espera que `init-db` hagi completat i carrega les dades inicials.
4. `app` només arrenca quan tota la cadena d'inicialització ha finalitzat amb èxit.

Observem que usam `restart: "no"` en tots els contenidors d'inicialització perquè no volem que es reiniciïn un pic han completat la seva tasca.

## Integració amb Traefik

[Traefik](https://traefik.io/) és un proxy invers modern que s'integra perfectament amb Docker. Descobreix automàticament els serveis i configura les rutes basant-se en etiquetes (*labels*).

Usar Traefik en comptes d'NGINX o Apache en un entorn de contenidors és convenient, car aporta els següents avantatges, que ens fan la vida més fàcil:

- **Descobriment automàtic**: Detecta nous contenidors i actualitza la configuració sense reiniciar.
- **Configuració via etiquetes**: No cal modificar fitxers de configuració externs.
- **Certificats automàtics**: Pot obtenir i renovar certificats Let's Encrypt.
- **Dashboard**: Interfície web per veure l'estat dels serveis.

### Configuració

Un exemple de configuració bàsica amb Traefik seria el següent:

```yaml
# compose.yaml
services:
  traefik:
    image: traefik:v3.6
    command:
      - "--api.dashboard=true"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entryPoints.web.address=:80"
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped

  app:
    image: myapp:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.localhost`)"
      - "traefik.http.routers.app.entrypoints=web"
      - "traefik.http.services.app.loadbalancer.server.port=8000"
    restart: unless-stopped
```

Amb aquesta configuració:

- Traefik escolta al port 80 i redirigeix les peticions als serveis.
- El dashboard és accessible al port 8080.
- `exposedByDefault=false` significa que només els serveis amb `traefik.enable=true` seran exposats.
- Les peticions a `app.localhost` es redirigeixen al servei `app` al port 8000.

De forma anàloga podem configurar múltiples serveis:

```yaml
# compose.yaml
services:
  traefik:
    image: traefik:v3.6
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entryPoints.web.address=:80"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  frontend:
    image: nginx:1.30-alpine
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`exemple.localhost`)"
      - "traefik.http.routers.frontend.entrypoints=web"

  api:
    image: myapi:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`exemple.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.api.entrypoints=web"
      - "traefik.http.services.api.loadbalancer.server.port=8000"
```

Amb aquesta configuració:

- Traefik escolta al port 80 i redirigeix les peticions als serveis.
- `exemple.localhost` serveix el frontend.
- `exemple.localhost/api/*` redirigeix a l'API.

### Escalat

Traefik balanceja automàticament entre les instàncies d'un servei escalat:

```bash
docker compose up --detach --scale api=3
```

Traefik detectarà les tres instàncies de `api` i distribuirà les peticions entre elles.

## Exemple pràctic: Odoo

Posarem en pràctica totes aquestes tècniques desplegant [Odoo](https://www.odoo.com/), un [*](ERP) de codi obert.

### Estructura del projecte

L’estructura proposada del projecte és la següent:

```
odoo/
├── compose.yaml
├── .env
├── config/
│   └── odoo.conf
└── addons/
```

### Fitxer `.env`

El fitxer `.env` contendrà les credencials d’accés a la base de dades PostgreSQL i l’entorn d’execució, així com els límits de recursos per a cada servei:

```ini
# Odoo
ODOO_VERSION=19.0
ODOO_ADMIN_PASSWORD=admin_secret_2026

# PostgreSQL
POSTGRES_USER=odoo
POSTGRES_PASSWORD=odoo_db_password_2026
POSTGRES_DB=postgres

# Recursos
ODOO_CPU_LIMIT=2.0
ODOO_MEMORY_LIMIT=2G
DB_CPU_LIMIT=1.0
DB_MEMORY_LIMIT=1G
```

### Fitxer `odoo.conf`

Crearem un fitxer de configuració `config/odoo.conf` amb les credencials d'accés a la base de dades de PostgreSQL, els principals paràmetres de configuració de l'aplicació i els límits de recursos per als *workers* d'Odoo:

```ini
[options]
admin_passwd = admin_secret_2026
db_host = db
db_port = 5432
db_user = odoo
db_password = odoo_db_password_2026
http_port = 8069
addons_path = /mnt/extra-addons

; Workers per producció
workers = 4
max_cron_threads = 2

; Límits de memòria per worker (en bytes)
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_time_cpu = 600
limit_time_real = 1200

; Proxy
proxy_mode = True
```

Odoo no suporta variables d'entorn dins el fitxer `odoo.conf`, així que els valors han d'estar escrits directament. Això significa que `admin_passwd` i `db_password` han de coincidir amb els valors del `.env`. En producció, aquest fitxer no s'hauria de versionar amb credencials reals.

La línia `proxy_mode = True` indica a Odoo que està darrere d'un proxy invers (en el nostre cas, Traefik). Quan aquesta opció està activada, Odoo llegeix les capçaleres HTTP que el proxy afegeix (com `X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`) per obtenir:

- La IP real del client (en comptes de la IP del proxy).
- El protocol original (HTTP o HTTPS).
- El nom de domini original.

Sense aquesta opció, Odoo veuria totes les peticions com si venguessin del proxy intern, cosa que afectaria els logs, les restriccions per IP, i la generació d'URLs.

### Fitxer `compose.yaml`

Per a aquest exemple pràctic definirem un fitxer `compose.yaml` amb algunes extensions 

```yaml
# compose.yaml
x-common-env: &common-env
  TZ: Europe/Madrid

x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "5"

x-healthcheck-db: &healthcheck-db
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
  interval: 10s
  timeout: 5s
  retries: 5

x-restart-policy: &restart-policy
  restart: unless-stopped

services:
  traefik:
    image: traefik:v3.6
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entryPoints.web.address=:80"
      - "--ping=true"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 10s
      timeout: 5s
      retries: 3
    logging: *default-logging
    <<: *restart-policy

  db:
    image: postgres:18-alpine
    environment:
      <<: *common-env
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      <<: *healthcheck-db
    deploy:
      resources:
        limits:
          cpus: ${DB_CPU_LIMIT}
          memory: ${DB_MEMORY_LIMIT}
        reservations:
          cpus: '0.5'
          memory: 512M
    logging: *default-logging
    <<: *restart-policy

  odoo-init:
    image: odoo:${ODOO_VERSION}
    depends_on:
      db:
        condition: service_healthy
    environment:
      <<: *common-env
      HOST: db
      USER: ${POSTGRES_USER}
      PASSWORD: ${POSTGRES_PASSWORD}
    command: >
      sh -c "
        odoo --init base --stop-after-init --database odoo ||
        echo 'Base de dades ja inicialitzada'
      "
    volumes:
      - odoo-data:/var/lib/odoo
      - ./config:/etc/odoo:ro
      - ./addons:/mnt/extra-addons:ro
    restart: "no"

  odoo:
    image: odoo:${ODOO_VERSION}
    depends_on:
      db:
        condition: service_healthy
      odoo-init:
        condition: service_completed_successfully
    environment:
      <<: *common-env
      HOST: db
      USER: ${POSTGRES_USER}
      PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - odoo-data:/var/lib/odoo
      - ./config:/etc/odoo:ro
      - ./addons:/mnt/extra-addons:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.odoo.rule=Host(`odoo.localhost`)"
      - "traefik.http.routers.odoo.entrypoints=web"
      - "traefik.http.services.odoo.loadbalancer.server.port=8069"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8069/web/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      resources:
        limits:
          cpus: ${ODOO_CPU_LIMIT}
          memory: ${ODOO_MEMORY_LIMIT}
        reservations:
          cpus: '1.0'
          memory: 1G
    logging: *default-logging
    <<: *restart-policy

volumes:
  postgres-data:
  odoo-data:
```

La imatge oficial d'Odoo no proporciona una forma automatitzada d'inicialitzar la base de dades. El flux estàndard d'Odoo espera que l'usuari creï la base de dades manualment des de la interfície web. La comanda `odoo --init base --stop-after-init` és un patró comú a la comunitat per automatitzar aquest procés. L'operador `||` captura l'error que Odoo retorna si la base de dades ja existeix, evitant que el contenidor falli en arrencades posteriors.

El contenidor `odoo-init` no cal eliminar-lo del fitxer `compose.yaml`. Gràcies a `restart: "no"`, s'executa una vegada i queda en estat "exited". En posteriors arrencades (`docker compose up`), Docker detecta que ja ha completat i no el torna a executar.

Es pot verificar-ho amb `docker compose ps -a`, on apareixerà amb estat "Exited (0)".

Si mai necessitam reinicialitzar la base de dades, podem forçar-ne l'execució amb `docker compose up odoo-init --force-recreate`.


### Preparació i arrencada

Segueix aquestes instruccions per a preparar la configuració i arrencar els serveis:

1. Crea els directoris i fitxers necessaris:
   ```bash
   mkdir --parents config addons
   ```

2. Crea el fitxer de configuració `config/odoo.conf` amb el contingut mostrat anteriorment.

3. Arrenca els serveis:
   ```bash
   docker compose up --detach
   ```

4. Accedeix a Odoo a `http://odoo.localhost/`.

5. Opcionalment, monitoritza els recursos:
   ```bash
   docker compose stats
   ```

### Tècniques aplicades

En aquest exemple pràctic hem aplicat les següents tècniques, vistes en aquest i anteriors articles:

- **Extensions YAML**: `x-common-env`, `x-logging`, `x-healthcheck-db`, `x-restart-policy` per evitar repetició.
- **Límits de recursos**: CPU i memòria per a Odoo i PostgreSQL.
- **Contenidor d'inicialització**: `odoo-init` inicialitza la base de dades abans d'arrencar Odoo.
- **Logging**: Configuració comuna amb rotació de fitxers.
- **Integració amb Traefik**: Proxy invers amb descobriment automàtic.
- **Secrets**: Contrasenya de PostgreSQL gestionada de forma segura.
- **Healthchecks**: Per a tots els serveis.

## Bones pràctiques

Tot seguit es revisen un conjunt de bones pràctiques quant a la gestió de serveis amb Compose.

**Usa extensions per evitar repetició**

Quan vegis configuracions repetides, extreu-les a blocs `x-`. Això facilita el manteniment i redueix errors.

**Sempre defineix límits de recursos**

Especialment en producció, defineix límits de memòria per evitar que un servei consumeixi tots els recursos i afecti els altres. Comença conservador i ajusta segons la monitorització.

**Configura la rotació de logs**

Si uses el driver `json-file` o `local`, els logs es guarden al disc de l'amfitrió i poden créixer indefinidament. Configura `max-size` i `max-file` per evitar omplir el disc. Si uses un sistema de *logging* centralitzat, e.g., Loki, Fluentd, la rotació la gestiona el propi sistema.

**Usa contenidors d'inicialització**

Per a tasques que s'han d'executar una vegada (migracions, seeds), crea serveis dedicats amb `restart: "no"` i `service_completed_successfully`.

**No escalis serveis amb estat**

Les bases de dades i altres serveis amb estat no s'han d'escalar amb `--scale`, sinó que cal usar solucions específiques (rèpliques de PostgreSQL, clúster de Redis) quan arribi el moment de necessitar alta disponibilitat.

**Traefik per a múltiples serveis**

Si tens diversos serveis web, Traefik simplifica molt la configuració. L'alternativa seria gestionar manualment les configuracions de Nginx.

## Exercicis

Es proposen dos exercicis pràctics per facilitar l’aprenentatge progressiu.

### Exercici 1

**Optimitzar un `compose.yaml` amb extensions YAML**

El següent fitxer té molta repetició. Refactoritza'l usant extensions i ancoratges per eliminar la duplicació:

```yaml
services:
  app:
    image: myapp:latest
    environment:
      TZ: Europe/Madrid
      LANG: ca_ES.UTF-8
      LOG_LEVEL: info
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped

  worker:
    image: myapp:latest
    command: python worker.py
    environment:
      TZ: Europe/Madrid
      LANG: ca_ES.UTF-8
      LOG_LEVEL: info
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "pgrep", "-f", "worker"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped

  scheduler:
    image: myapp:latest
    command: python scheduler.py
    environment:
      TZ: Europe/Madrid
      LANG: ca_ES.UTF-8
      LOG_LEVEL: info
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    healthcheck:
      test: ["CMD", "pgrep", "-f", "scheduler"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
```

{{< details summary="Respostes" >}}

Proposta de fitxer `compose.yaml` millorat:

```yaml
x-common-env: &common-env
  TZ: Europe/Madrid
  LANG: ca_ES.UTF-8
  LOG_LEVEL: info

x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

x-healthcheck-defaults: &healthcheck-defaults
  interval: 30s
  timeout: 10s
  retries: 3

x-service-defaults: &service-defaults
  image: myapp:latest
  environment: *common-env
  logging: *default-logging
  restart: unless-stopped

services:
  app:
    <<: *service-defaults
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "curl", "-f", "http://localhost/health"]

  worker:
    <<: *service-defaults
    command: python worker.py
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "pgrep", "-f", "worker"]

  scheduler:
    <<: *service-defaults
    command: python scheduler.py
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "pgrep", "-f", "scheduler"]
```

Observa que:

- `x-common-env` agrupa les variables d'entorn comunes.
- `x-logging` defineix la configuració de *logging*.
- `x-healthcheck-defaults` té els paràmetres comuns del *healthcheck*.
- `x-service-defaults` combina imatge, environment, logging i restart.
- Cada servei només defineix el que és específic (`command`, test del *healthcheck*).

{{< /details >}}

### Exercici 2

**Crear un stack amb contenidor d'inicialització i límits de recursos**

Crea un `compose.yaml` per a una aplicació web amb els següents requisits:

1. Un servei `db` amb PostgreSQL 18 Alpine amb:
   - Healthcheck configurat.
   - Límit de 512 MB de memòria i 0.5 CPU.
   - Reserva de 256 MB de memòria.

2. Un servei `migrations` que:
   - Usa la imatge `postgres:18-alpine`.
   - Executa un script SQL d'inicialització.
   - Espera que `db` estigui *healthy*.
   - No es reinicia mai.

3. Un servei `app` amb NGINX que:
   - Espera que `migrations` hagi completat amb èxit.
   - Té límit de 256 MB de memòria i 0.25 CPU.
   - Serveix contingut al port 80.

4. Usa extensions YAML per evitar repetició.

Proposta d'script SQL d'inicialització `init.sql`:

```sql
CREATE TABLE IF NOT EXISTS personatge (id SERIAL PRIMARY KEY, nom VARCHAR(50));
INSERT INTO personatge (id, nom)
VALUES (1, 'Miguel Rivera'), (2, 'Héctor Rivera'), (3, 'Ernesto de la Cruz'),
       (4, 'Mamá Imelda'), (5, 'Mamá Coco'), (6, 'Abuelita Elena')
ON CONFLICT (id) DO NOTHING;
```

{{< details summary="Respostes" >}}

Crea el fitxer `compose.yaml`:

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

x-restart-policy: &restart-policy
  restart: unless-stopped

services:
  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: app
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app"]
      interval: 5s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          memory: 256M
    logging: *default-logging
    <<: *restart-policy

  migrations:
    image: postgres:18-alpine
    depends_on:
      db:
        condition: service_healthy
    environment:
      PGHOST: db
      PGUSER: app
      PGPASSWORD: secret
      PGDATABASE: app
    volumes:
      - ./init.sql:/init.sql:ro
    command: ["psql", "--file", "/init.sql"]
    logging: *default-logging
    restart: "no"

  app:
    image: nginx:1.30-alpine
    depends_on:
      migrations:
        condition: service_completed_successfully
    ports:
      - "80:80"
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
    logging: *default-logging
    <<: *restart-policy

volumes:
  postgres-data:
```

Arrenca els serveis:

```bash
docker compose up --detach
```

Verifica que les migracions s'han executat:

```bash
docker compose logs migrations
```

Verifica els recursos assignats:

```bash
docker compose stats --no-stream
```

Finalment, verifica que la taula s'ha creat:

```bash
docker compose exec db psql -U app -d app -c "\dt"
```

{{< /details >}}
