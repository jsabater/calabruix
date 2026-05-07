---
title: "Perfils i entorns"
date: 2026-05-07
lastmod: 2026-05-07
description: "Gestió de perfils per activar serveis selectivament i configuració de múltiples entorns amb Docker Compose."
summary: "Gestió de perfils per activar serveis selectivament i configuració de múltiples entorns amb Docker Compose."
categories: ["teaching"]
tags: ["docker", "compose", "profiles", "environments"]
series: ["Docker Compose"]
series_order: 7
weight: 70
slug: "perfils-entorns"
---

Quan desenvolupam aplicacions, necessitam configuracions diferents segons l'entorn on s'executen. En el nostre entorn de desenvolupament volem eines de depuració, logs detallats i serveis auxiliars per testejar. A producció, en canvi, volem optimitzar recursos, usar servidors reals i minimitzar l'exposició de ports.

Docker Compose ofereix diverses estratègies per gestionar aquestes diferències: perfils per activar serveis selectivament, fitxers d'entorn per configurar variables i múltiples fitxers Compose per sobreescriure configuracions.

## Perfils

Els perfils permeten definir grups de serveis que només s'activen quan s'especifica el perfil corresponent. Això és útil per a serveis que només fan falta en certs contextos, com ara eines de desenvolupament o monitorització.

Per assignar un servei a un perfil, usam la directiva `profiles`:

```yaml
services:
  app:
    image: myapp:latest
    ports:
      - "3000:3000"

  adminer:
    image: adminer:latest
    profiles:
      - dev
    ports:
      - "8080:8080"
```

En aquest exemple, el servei `app` sempre s'inicia, però `adminer` només s'inicia si activam el perfil `dev`.

Una vegada definits, hi ha diverses maneres d'activar perfils:

* Amb l'opció `--profile`.
  ```bash
  docker compose --profile dev up --detach
  ```

* Amb la variable d'entorn `COMPOSE_PROFILES`.
  ```bash
  export COMPOSE_PROFILES=dev
  docker compose up --detach
  ```
* Al fitxer `.env`.
  ```bash
  COMPOSE_PROFILES=dev
  ```

> La instrucció `export` fa que la variable estigui disponible en totes les comandes que executis posteriorment en aquesta sessió de shell.

Un servei pot pertànyer a diversos perfils, i s'activarà si qualsevol d'ells està actiu:

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    profiles:
      - monitoring
      - dev
```

Per activar múltiples perfils simultàniament, els separam amb comes:

```bash
docker compose --profile dev --profile monitoring up --detach
```

O amb la variable d'entorn:

```bash
COMPOSE_PROFILES=dev,monitoring
```

Quan un servei sense perfil depèn d'un servei amb perfil, cal activar el perfil perquè la dependència es resolgui. Per exemple:

```yaml
services:
  app:
    image: myapp:latest
    depends_on:
      - db

  db:
    image: postgres:18-alpine
    profiles:
      - backend
```

En aquest cas, si intentam arrencar `app` sense activar el perfil `backend`, Docker Compose mostrarà un error perquè `db` no està disponible.

Una bona pràctica és deixar els serveis essencials (base de dades, cache) sense perfil i assignar perfils només als serveis opcionals, e.g., eines de desenvolupament, monitorització, etc.

## Fitxers d'entorn

El fitxer `.env` permet definir variables d'entorn que Docker Compose substitueix automàticament al `compose.yaml`. Fins ara hem usat un únic fitxer `.env`, però en podem tenir múltiples. Per exemple, podem crear fitxers específics per als nostres entorns de desenvolupament i de producció:

```
projecte/
├── compose.yaml
├── .env                    # Variables comunes
├── .env.development        # Variables de desenvolupament
└── .env.production         # Variables de producció
```

Per usar un fitxer d'entorn específic usam el paràmetre `--env-file`:

```bash
docker compose --env-file .env.development up --detach
```

Però sovint ens serà còmode combinar múltiples fitxers d'entorn. Les variables dels fitxers posteriors sobreescriuen les anteriors:

```bash
docker compose --env-file .env --env-file .env.development \
  up --detach
```

Amb aquesta comanda, primer es carreguen les variables de `.env` i després les de `.env.development`. Si una variable apareix a ambdós fitxers, el valor de `.env.development` és el que s'aplica.

Les variables d'entorn es poden usar de diverses maneres al `compose.yaml`:

* Substitució simple:
  ```yaml
  services:
    app:
      image: myapp:${APP_VERSION}
  ```

* Substitució amb valor per defecte:
  ```yaml
  services:
    app:
      image: myapp:${APP_VERSION:-latest}
  ```
  Si `APP_VERSION` no està definida, s'usa `latest`.

* Substituació amb error si no està definida:
  ```yaml
  services:
    app:
      image: myapp:${APP_VERSION:?La versió és obligatòria}
  ```
  Si `APP_VERSION` no està definida, Docker Compose mostra l'error especificat i atura l'execució.

## Múltiples fitxers Compose

Una altra estratègia és dividir la configuració en múltiples fitxers Compose que es combinen en temps d'execució. Això permet tenir una configuració base i sobreescriure-la segons l'entorn.

L'estructura típica és la següent:

```
projecte/
├── compose.yaml            # Configuració base
├── compose.override.yaml   # Configuració local
├── compose.dev.yaml        # Configuració de desenvolupament
└── compose.prod.yaml       # Configuració de producció
```

Docker Compose, per defecte, combina automàticament `compose.yaml` amb `compose.override.yaml`, si aquest existeix. Això és útil per a configuracions locals de desenvolupament que no volem versionar:

```yaml
# compose.yaml
services:
  app:
    image: myapp:latest
    environment:
      - NODE_ENV=production
```

```yaml
# compose.override.yaml
services:
  app:
    environment:
      - NODE_ENV=development
      - DEBUG=true
    ports:
      - "3000:3000"
```

Quan executam `docker compose up`, ambdós fitxers es combinen. Però també podem combinar fitxers específics mitjançant l'opció `-f`:

```bash
docker compose -f compose.yaml -f compose.prod.yaml up --detach
```

Els fitxers es processen en ordre. Les configuracions dels fitxers posteriors sobreescriuen o amplien les anteriors, seguint aquestes regles:

- En cas de **valors escalars**, e.g., cadenes o números, el valor posterior sobreescriu l'anterior.
- En cas de **llistes**, e.g., claus `ports` o `volumes`, per defecte les llistes es concatenen. Atenció, això podria causar duplicats!
- En cas de **mapes**, e.g., claus `environment` o `labels`, es fusionen, amb els valors posteriors sobreescrivint els anteriors.

Per exemple, si tenim:

```yaml
# compose.yaml
services:
  app:
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=info

# compose.dev.yaml
services:
  app:
    environment:
      - NODE_ENV=development
      - DEBUG=true
```

El resultat combinat seria:

```yaml
services:
  app:
    environment:
      - NODE_ENV=development  # sobreescrit
      - LOG_LEVEL=info        # mantingut
      - DEBUG=true            # afegit
```

## Exemple pràctic

Ampliarem [l'exemple de N8N de l'article anterior]({{<relref "/posts/docker/compose/healthchecks/#exemple-pràctic">}}) per demostrar l'ús d'entorns. Afegirem [Mailpit](https://mailpit.axllent.org/), un servidor [*](SMTP) de proves que captura els emails sense enviar-los realment, ideal per a desenvolupament.

Volem aconseguir el següent:

- A l'entorn de **desenvolupament**, N8N usa Mailpit per capturar emails, permetent verificar les notificacions sense enviar correus reals.
- A l'entorn de **producció**, N8N usa un servidor SMTP real per enviar els emails.

### Estructura del projecte

Es proposa la següent estructura pel projecte:

```
n8n/
├── compose.yaml            # Configuració base
├── compose.override.yaml   # Desenvolupament
├── compose.prod.yaml       # Sobreescriptures per producció
├── .env.example            # Plantilla versionada
├── .env                    # Desenvolupament
└── .env.production         # Valors de producció
```

Docker Compose, per defecte, combina automàticament `compose.yaml` amb `compose.override.yaml` si aquest existeix. Això simplifica enormement el flux de feina en desenvolupament.

El fitxer `.env` és la configuració local per a desenvolupament i es genera a partir d'una copia del fitxer `.env.example`, versionat al repositori.

El fitxer `.env.production` és la configuració per a producció i es generat pel conducte d'integració contínua i desplegament continu, fent ús d'una bòveda de secrets, e.g., Docker Secrets.

Per tant, el fitxer `.gitignore` haurà d'incloure:

```
.env
.env.production
compose.override.yaml
```

### Plantilla de variables

El fitxer `.env.example` és la plantilla versionada que els membres de l'equip de desenvolupament copien a `.env`:

```bash
# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=canvia_aquesta_contrasenya
POSTGRES_DB=n8n

# N8N
N8N_VERSION=2.17.3
N8N_ENCRYPTION_KEY=clau_aleatoria_minim_32_caracters
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http

# SMTP (Mailpit)
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=mailpit
N8N_SMTP_PORT=1025
N8N_SMTP_SENDER=n8n@localhost
```

El desenvolupador o desenvolupadora copia aquest fitxer i personalitza els valors:

```bash
cp .env.example .env
```

### Fitxer base

El fitxer `compose.yaml` conté la configuració base compartida entre tots els entorns per als tres serveis que usarem en aquest exemple pràctic:

```yaml
services:
  n8n:
    image: n8nio/n8n:${N8N_VERSION}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=db
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=${N8N_PORT}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - WEBHOOK_URL=${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}/
      - N8N_EMAIL_MODE=${N8N_EMAIL_MODE:-smtp}
      - N8N_SMTP_HOST=${N8N_SMTP_HOST}
      - N8N_SMTP_PORT=${N8N_SMTP_PORT}
      - N8N_SMTP_SENDER=${N8N_SMTP_SENDER}
    ports:
      - "${N8N_PORT}:5678"
    volumes:
      - n8n-data:/home/node/.n8n
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:8.6-alpine
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3

volumes:
  n8n-data:
  postgres-data:
  redis-data:
```

### Fitxer override

El fitxer `compose.override.yaml` conté la configuració específica per a desenvolupament. Si el cream devora del fitxer `compose.yaml Docker Compose el carregarà automàticament:

```yaml
services:
  n8n:
    depends_on:
      mailpit:
        condition: service_started
    restart: unless-stopped

  db:
    restart: unless-stopped

  redis:
    restart: unless-stopped

  mailpit:
    image: axllent/mailpit:1.29
    ports:
      - "8025:8025"
    environment:
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
    restart: unless-stopped
```

Observem que:

- Afegim el servei `mailpit` que només existeix a desenvolupament.
- N8N ara depèn també de `mailpit`.
- El port 8025 és la interfície web de [Mailpit](https://hub.docker.com/r/axllent/mailpit) per veure els emails capturats.
- El port SMTP (1025) no s'exposa a l'amfitrió perquè només N8N hi accedeix internament.
- Usam `restart: unless-stopped` perquè els serveis es recuperin de reinicis accidentals, però s'aturin quan ho demanem explícitament.

> Segons les regles de combinació que hem explicat anteriorment en aquest article, els mapes (diccionaris) es fusionen, amb els valors posteriors sobreescrivint o afegint-se als anteriors.

### Fitxer de producció

El fitxer `compose.prod.yaml` conté les sobreescriptures per a producció:

```yaml
services:
  n8n:
    environment:
      - N8N_SMTP_USER=${N8N_SMTP_USER}
      - N8N_SMTP_PASS=${N8N_SMTP_PASS}
      - N8N_SMTP_SSL=${N8N_SMTP_SSL:-false}
    restart: always

  db:
    restart: always

  redis:
    restart: always
```

En producció:

- Afegim les variables d'autenticació [*](SMTP) que no existeixen en desenvolupament.
- Usam `restart: always` perquè els serveis es recuperin sempre, fins i tot després d'un reinici del sistema.
- No hi ha servei Mailpit.

### Variables de producció

El fitxer `.env.production` es genera durant el pipeline de desplegament, a partir d'una bòveda de secrets, o es crea manualment al servidor, i conté els valors de les variables necessàries per a executar correctament els serveis a l'entorn de producció.

```bash
# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=contrasenya_molt_segura_i_llarga
POSTGRES_DB=n8n

# N8N
N8N_VERSION=2.17.3
N8N_ENCRYPTION_KEY=clau_produccio_aleatoria_32_caracters_minim
N8N_HOST=n8n.exemple.com
N8N_PORT=5678
N8N_PROTOCOL=https

# SMTP (servidor real)
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.exemple.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=notificacions@exemple.com
N8N_SMTP_PASS=contrasenya_smtp
N8N_SMTP_SENDER=notificacions@exemple.com
N8N_SMTP_SSL=false
```

{{< alert >}}
No versionis mai el fitxer `.env.production` amb credencials reals. Aquest fitxer s'ha de generar durant el desplegament o crear-se manualment al servidor de producció.
{{< /alert >}}

### Arrencada a desenvolupament

Gràcies a la càrrega automàtica de `compose.override.yaml`, arrencar l'entorn de desenvolupament és tan simple com:

```bash
docker compose up --detach
```

Això és tot. Docker Compose automàticament:

1. Carrega les variables de `.env`.
2. Combina `compose.yaml` amb `compose.override.yaml`.
3. Arrenca tots els serveis, incloent Mailpit.

Per veure els logs:

```bash
docker compose logs -f n8n
```

Per aturar l'entorn:

```bash
docker compose down
```

### Arrencada a producció

Per arrencar l'entorn de producció, hem d'especificar explícitament els fitxers per evitar que es carregui `compose.override.yaml`:

```bash
docker compose -f compose.yaml -f compose.prod.yaml \
  --env-file .env.production up --detach
```

Podem simplificar aquesta comanda amb un script `deploy.sh`:

```bash
#!/bin/bash
docker compose -f compose.yaml -f compose.prod.yaml \
  --env-file .env.production "$@"
```

I usar-lo així:

```bash
./deploy.sh up --detach
./deploy.sh logs -f n8n
./deploy.sh down
```

### Verificació de Mailpit

Un pic l'entorn de desenvolupament està en marxa, podem verificar que Mailpit funciona adequadament:

1. Accedeix a la interfície de Mailpit a `http://localhost:8025/`.
2. Des de N8N (`http://localhost:5678/`), configura un workflow que enviï un email, o simplement convida un nou usuari.
3. L'email apareixerà a la interfície de Mailpit en comptes d'enviar-se realment.

### Resum

En resum, el flux de feina és el següent:

| Entorn          | Comanda                | Fitxers carregats                                      |
|-----------------|------------------------|--------------------------------------------------------|
| Desenvolupament | `docker compose up -d` | `.env`, `compose.yaml`, `compose.override.yaml`        |
| Producció       | `./deploy.sh up -d`    | `.env.production`, `compose.yaml`, `compose.prod.yaml` |

Aquest patró és el més comú en projectes reals:

- El cas habitual (desenvolupament) és el més simple d'executar.
- El cas especial (producció) requereix una comanda explícita, normalment encapsulada en un script o pipeline.

## Exercicis

Es proposen dos exercicis pràctics per facilitar l’aprenentatge progressiu.

### Exercici 1

**Afegir eines de desenvolupament amb perfils**

Partint d'un stack bàsic amb una aplicació web i PostgreSQL, afegeix serveis opcionals que només s'activin en desenvolupament:

1. Crea un `compose.yaml` amb un servei `web` (usa `nginx:alpine` com a exemple) i un servei `db` amb PostgreSQL.
2. Afegeix un servei `adminer` (interfície web per gestionar PostgreSQL) amb el perfil `dev`.
3. Afegeix un servei `mailpit` amb el perfil `dev`.
4. Verifica que sense perfil només s'arrenquen `web` i `db`.
5. Verifica que amb el perfil `dev` s'arrenquen tots els serveis.

> Pista: Adminer usa el port 8080 per defecte i es connecta a PostgreSQL usant el nom del servei (`db`) com a servidor.

{{< details summary="Respostes" >}}

Crea l'estructura del projecte:

```
dev-tools/
├── compose.yaml
└── .env
```

Crea el fitxer `.env`:

```bash
POSTGRES_USER=app
POSTGRES_PASSWORD=secret
POSTGRES_DB=appdb
```

Crea el fitxer `compose.yaml`:

```yaml
services:
  web:
    image: nginx:1.29-alpine
    ports:
      - "8080:80"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  adminer:
    image: adminer:latest
    profiles:
      - dev
    ports:
      - "9090:8080"
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  mailpit:
    image: axllent/mailpit:latest
    profiles:
      - dev
    ports:
      - "8025:8025"
    environment:
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
    restart: unless-stopped

volumes:
  postgres-data:
```

Verifica sense perfil:

```bash
docker compose up --detach
docker compose ps
```

Haurien d'aparèixer només `web` i `db`.

Atura i verifica amb perfil:

```bash
docker compose down
docker compose --profile dev up --detach
docker compose ps
```

Ara haurien d'aparèixer `web`, `db`, `adminer` i `mailpit`.

Accedeix a Adminer a `http://localhost:9090` i connecta't amb:
- Sistema: PostgreSQL
- Servidor: db
- Usuari: app
- Contrasenya: secret
- Base de dades: appdb

Accedeix a Mailpit a `http://localhost:8025/`.

{{< /details >}}

### Exercici 2

**Configurar entorns múltiples**

Crea una configuració per a una aplicació amb diferents paràmetres segons l'entorn:

1. Crea un `compose.yaml` base amb un servei `app` (usa `nginx:1.29-alpine`) i un servei `db` amb PostgreSQL.
2. Crea fitxers `.env.development` i `.env.production` amb:
   - Diferents contrasenyes de base de dades.
   - Diferent nivell de log (`debug` vs `warn`).
3. Crea `compose.dev.yaml` que exposi el port de PostgreSQL per accedir-hi des de l'amfitrió.
4. Crea `compose.prod.yaml` que no exposi el port de PostgreSQL i configuri `restart: always`.
5. Verifica que pots arrencar cada entorn correctament.

{{< details summary="Respostes" >}}

Crea l'estructura del projecte:

```
multi-env/
├── compose.yaml
├── compose.dev.yaml
├── compose.prod.yaml
├── .env.development
└── .env.production
```

Crea el fitxer `.env.development`:

```bash
POSTGRES_USER=app
POSTGRES_PASSWORD=dev_password
POSTGRES_DB=appdb
LOG_LEVEL=debug
```

Crea el fitxer `.env.production`:

```bash
POSTGRES_USER=app
POSTGRES_PASSWORD=prod_super_secure_password_2024
POSTGRES_DB=appdb
LOG_LEVEL=warn
```

Crea el fitxer `compose.yaml`:

```yaml
services:
  app:
    image: nginx:1.29-alpine
    ports:
      - "80:80"
    environment:
      - LOG_LEVEL=${LOG_LEVEL}
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:
```

Crea el fitxer `compose.dev.yaml`:

```yaml
services:
  app:
    restart: unless-stopped

  db:
    ports:
      - "5432:5432"
    restart: unless-stopped
```

Crea el fitxer `compose.prod.yaml`:

```yaml
services:
  app:
    restart: always

  db:
    restart: always
```

Arrenca en desenvolupament:

```bash
docker compose --env-file .env.development \
  -f compose.yaml -f compose.dev.yaml \
  up --detach
```

Verifica que PostgreSQL és accessible des de l'amfitrió:

```bash
docker compose exec db psql -U app -d appdb -c "SELECT 1"
```

O si tens `psql` instal·lat localment:

```bash
psql -h localhost -U app -d appdb -c "SELECT 1"
```

Atura i arrenca en producció:

```bash
docker compose --env-file .env.development \
  -f compose.yaml -f compose.dev.yaml \
  down

docker compose --env-file .env.production \
  -f compose.yaml -f compose.prod.yaml \
  up --detach
```

Verifica que PostgreSQL no és accessible des de l'amfitrió (el port no està exposat):

```bash
docker compose ps
```

El servei `db` no hauria de mostrar cap port mapejat.

{{< /details >}}
