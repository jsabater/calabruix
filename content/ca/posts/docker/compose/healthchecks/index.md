---
title: "Healthchecks i dependències"
date: 2026-04-23
lastmod: 2026-04-23
description: "Configuració de healthchecks, gestió de dependències entre serveis i polítiques de reinici amb Docker Compose."
summary: "Configuració de healthchecks, gestió de dependències entre serveis i polítiques de reinici amb Docker Compose."
categories: ["teaching"]
tags: ["docker", "compose", "n8n", "healthchecks", "dependencies"]
series: ["Docker Compose"]
series_order: 6
weight: 60
slug: "healthchecks-dependencies"
---

Un contenidor pot estar en execució però no estar preparat per rebre peticions. El procés pot haver arrencat, però l'aplicació encara pot estar inicialitzant connexions, carregant dades o esperant recursos externs. 

Això és perquè, quan arrencam múltiples serveis amb `docker compose up`, Docker inicia tots els contenidors gairebé simultàniament. L'exemple més habitual és el d'un servei web que intenta connectar-se a la base de dades abans que aquesta estigui preparada per acceptar connexions, provocant errors d'inici.

Docker Compose permet configurar *healthchecks* per verificar l'estat real dels serveis, així com gestionar les dependències entre contenidors, el que permet controlar l'ordre d'arrencada i configurar polítiques de reinici automàtic.

## Dependències

La directiva `depends_on`, en la seva forma més simple, garanteix l'ordre d'arrencada dels contenidors:

```yaml
services:
  web:
    image: myapp:latest
    depends_on:
      - db  # El contenidor db s'inicia primer

  db:
    image: postgres:18-alpine
```

En aquest exemple, el contenidor `web` arrencarà després que el contenidor `db` s'hagi iniciat, però PostgreSQL pot trigar uns segons a estar llest per acceptar connexions. El resultat és que l'aplicació web falla perquè intenta connectar abans d'hora.

## Healthchecks

Els *healthchecks* permeten a Docker verificar periòdicament si un servei funciona correctament. No comproven només si el procés està en execució, sinó si el servei respon adequadament.

La configuració bàsica d'un *healthcheck* es defineix amb els següents paràmetres:

```yaml
services:
  db:
    image: postgres:18-alpine
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
```

Analitzem cada opció:

- `test`: La comanda que s'executa per verificar l'estat. Si retorna `0`, el servei es considera saludable; qualsevol altre valor indica un problema.
- `interval`: Cada quant de temps s'executa la comprovació (per defecte `30s`).
- `timeout`: Temps màxim d'espera per a la resposta (per defecte `30s`).
- `retries`: Nombre de fallades consecutives abans de marcar el servei com a *unhealthy* (per defecte `3`).
- `start_period`: Temps de gràcia inicial durant el qual les fallades no compten (per defecte `0s`).

### Sintaxi del test

Hi ha dues formes d'especificar la comanda de test:

**Format llista**

El primer element indica el tipus:

- `CMD`: Executa la comanda directament, sense shell.
- `CMD-SHELL`: Executa la comanda dins una shell, permetent ús de pipes, variables d'entorn i altres funcionalitats del shell.

```yaml
healthcheck:
  test: ["CMD", "pg_isready", "-U", "postgres"]
```

És el format recomanat, sobre tot perquè es considera una bona pràctica, però també per rendiment i menor consum de recursos, car no es crea un procés addicional.

**Format cadena**

Quan s'especifica com a cadena, Docker assumeix `CMD-SHELL` automàticament.

```yaml
healthcheck:
  test: pg_isready -U postgres
```

### `CMD` vs `CMD-SHELL`

Usa `CMD` quan la comanda és simple i no requereixi funcionalitats del shell:

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
```

Usa `CMD-SHELL` quan necessitis:

- Pipes, per exemple per filtrar la sortida d'una comanda.
  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
  ```
- Variables d'entorn:
  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
  ```
- Operadors lògics, per exemple per combinar condicions.
  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
  ```

### Exemples

Cada tipus de servei té la seva manera òptima de verificar l'estat. Vegem alguns exemples:

**PostgreSQL**

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
  interval: 5s
  timeout: 5s
  retries: 5
```

La comanda `pg_isready` és una utilitat inclosa a PostgreSQL específicament dissenyada per comprovar si el servidor accepta connexions.

**Redis i Valkey**

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 5s
  timeout: 3s
  retries: 3
```

La comanda `ping` de Redis retorna `PONG` si el servidor està operatiu. Valkey es comporta de la mateixa manera, però la comanda es diu `valkey-cli`.

**MySQL/MariaDB**

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
  interval: 10s
  timeout: 5s
  retries: 5
```

**NGINX/Apache/Traefik**

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

L'opció `-f` de `curl` fa que retorni un codi d'error si el servidor respon amb un codi HTTP 4xx o 5xx.

Algunes imatges lleugeres basades en Alpine no inclouen `curl`. En aquests casos podem usar `wget`:

```yaml
healthcheck:
  test: ["CMD", "wget", "-q", "--spider","http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

L'opció `--spider` de `wget` fa que no es descarregui el contingut de la pàgina, sinó que només verifiqui que hi hagi una resposta.

Quant a Traefik, aquest exposa un *endpoint* de *healthcheck* dedicat a `/ping`, que s'ha d'habilitar explícitament a la configuració:

```yaml
traefik:
  image: traefik:v3.6
  command:
    - "--ping=true"
  healthcheck:
    test: ["CMD", "traefik", "healthcheck", "--ping"]
    interval: 10s
    timeout: 5s
    retries: 3
```

### Estats

Un contenidor amb *healthcheck* configurat pot estar en un de tres estats:

- `starting`: El contenidor acaba d'arrencar i encara està dins el `start_period`.
- `healthy`: L'últim *healthcheck* ha tingut èxit.
- `unhealthy`: El nombre de fallades consecutives ha superat `retries`.

Podem consultar l'estat amb:

```bash
docker compose ps
```

O, amb més detall, amb:

```bash
docker inspect --format='{{json .State.Health}}' nom_contenidor | jq
```

## Dependències

Amb els *healthchecks* configurats, podem usar `depends_on` amb condicions per controlar quan s'inicia cada servei. Per exemple:

```yaml
services:
  web:
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
      migrations:
        condition: service_completed_successfully
```

Les condicions disponibles són:

- `service_started`: El contenidor s'ha iniciat (comportament per defecte, equivalent a la forma simple `depends_on: [db]`).
- `service_healthy`: El contenidor ha passat el *healthcheck*.
- `service_completed_successfully`: El contenidor ha finalitzat amb codi de sortida `0` (útil per a contenidors d'inicialització o migracions).

### Exemple

Vegem un exemple amb múltiples dependències:

```yaml
services:
  api:
    image: myapi:latest
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
      migrations:
        condition: service_completed_successfully

  db:
    image: postgres:18-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:8.6-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3

  migrations:
    image: myapi:latest
    command: ["npm", "run", "migrate"]
    depends_on:
      db:
        condition: service_healthy
```

En aquest exemple:

1. Primer arrenca `db` i `redis`.
2. Quan `db` està *healthy*, arrenca `migrations`.
3. Quan `migrations` finalitza amb èxit i `redis` està *healthy*, arrenca `api`.

## Polítiques de reinici

Les polítiques de reinici determinen què fa Docker quan un contenidor s'atura o falla. Exemple:

```yaml
services:
  web:
    image: myapp:latest
    restart: unless-stopped
```

Les opcions disponibles són:

| Política         | Descripció                                                             |
|------------------|------------------------------------------------------------------------|
| `no`             | No reinicia mai el contenidor (per defecte)                            |
| `always`         | Reinicia sempre, incloent quan el dèmon de Docker es reinicia          |
| `on-failure`     | Reinicia només si el contenidor surt amb un codi d'error               |
| `unless-stopped` | Com `always`, però no reinicia si el contenidor s'ha aturat manualment |

Un seguit de recomanacions d'ús:

- En un entorn de desenvolupament usa `no` o `on-failure` per detectar errors ràpidament.
- A producció, usa `unless-stopped` per a la majoria de serveis.
- En cas de tasques puntuals, usa `no` per a contenidors que han d'executar-se una sola vegada, e.g., migracions o còpies de seguretat.

Finalment, quant a la interacció amb els *healthchecks*, és important entendre que la política de reinici actua sobre l'estat del procés, no sobre l'estat del *healthcheck*. Un contenidor marcat com *unhealthy* no es reinicia automàticament només per aquesta condició.

Per aconseguir reinicis automàtics basats en *healthchecks* cal usar [Docker Swarm]({{<relref "/posts/docker/swarm/">}}). A Docker Compose, els *healthchecks* serveixen principalment per controlar l'ordre d'arrencada amb `depends_on`.

## Exemple pràctic

Per a l'exemple pràctic d'aquest article usarem [N8N](https://n8n.io/), una plataforma d'automatització de fluxos de treball, similar a [Zapier](https://zapier.com/) o [Make](https://www.make.com/), però de codi obert i auto-allotjable. Desplegarem [N8N](https://hub.docker.com/r/n8nio/n8n) amb PostgreSQL per a persistència i Redis per a la gestió de cues.

### Estructura del projecte

L’estructura proposada del projecte és la següent:

```
n8n/
├── compose.yaml
└── .env
```

### Fitxer `.env`

El fitxer `.env` contendrà les credencials d’accés a la base de dades PostgreSQL i l’entorn d’execució:

```bash
# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=canvia_aquesta_contrasenya
POSTGRES_DB=n8n

# N8N
N8N_VERSION=2.17.3
N8N_ENCRYPTION_KEY=una_clau_secreta_molt_llarga_i_segura
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
```

> La variable `N8N_ENCRYPTION_KEY` és crítica: N8N l'usa per xifrar les credencials emmagatzemades. Si la perds, totes les credencials guardades seran irrecuperables. Genera una clau segura i guarda-la en un lloc segur, e.g., una bòveda.

### Fitxer `compose.yaml`

El fitxer `compose.yaml` orquestra els tres serveis: PostgreSQL, Redis i N8N. Els serveis estan configurats amb *healthchecks*. Els tres serveis usen les respectives imatges oficials a Docker Hub.

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
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=${N8N_PORT}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - WEBHOOK_URL=${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}/
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

  redis:
    image: redis:8.6-alpine
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3
    restart: unless-stopped

volumes:
  n8n-data:
  postgres-data:
  redis-data:
```

Aspectes destacables de la configuració del fitxer `compose.yaml`:

* Servei `db` (base de dades):
  - Usa `pg_isready` per verificar que accepta connexions.
  - Intervals curts (`5s`) perquè PostgreSQL normalment arrenca ràpid.
  - Les variables d'entorn s'expandeixen per Compose a l'amfitrió abans d'executar el *healthcheck*.

* Servei `redis` (memòria cau):
  - Usa `redis-cli ping`, que retorna `PONG` si el servidor està operatiu.
  - No necessita `CMD-SHELL` perquè la comanda és simple i no requereix variables.

* Servei `n8n` (aplicació):
  - Depèn de `db` i `redis` amb condició `service_healthy`.
  - Usa l'endpoint `/healthz` que N8N proporciona per a *healthchecks*.
  - Té un `start_period: 30s` per donar temps a N8N per inicialitzar-se abans de començar amb els *healthchecks*.
  - La variable `DB_TYPE=postgresdb` indica a N8N que usi PostgreSQL en lloc de SQLite.

### Arrencada

Arrencam els serveis amb la comanda habitual:

```bash
docker compose up --detach
```

Sense esperar, observa l'ordre d'arrencada i l'estat dels *healthchecks* amb la següent comanda:

```bash
docker compose ps
```

Hauries de veure alguna cosa semblant a:

```
NAME          IMAGE                STATUS                   PORTS
n8n-db-1      postgres:18-alpine   Up 2 minutes (healthy)
n8n-redis-1   redis:8.6-alpine     Up 2 minutes (healthy)
n8n-n8n-1     n8nio/n8n:2.17.3     Up 1 minute (healthy)    0.0.0.0:5678->5678/tcp
```

Obri el navegador a `http://localhost:5678/` per accedir a N8N i completar la configuració inicial.

### Monitorització

Per veure l'historial de *healthchecks* d'un contenidor pots usar la següent comanda:

```bash
docker inspect n8n-db-1 --format='{{json .State.Health}}' | jq
```

La sortida mostra l'estat actual i els últims resultats:

```json
{
  "Status": "healthy",
  "FailingStreak": 0,
  "Log": [
    {
      "Start": "2026-04-20T10:30:00.000000000Z",
      "End": "2026-04-20T10:30:00.100000000Z",
      "ExitCode": 0,
      "Output": "/var/run/postgresql:5432 - accepting connections\n"
    }
  ]
}
```

## Bones pràctiques

En aquest apartat fem un recull de bones pràctiques a l'hora de configurar *healthchecks* i dependències amb Docker Compose.

**Intervals i timeouts adequats**

Ajusta els paràmetres segons les característiques del servei:

- Bases de dades: Intervals curts (`5-10s`) perquè els healthchecks són lleugers.
- Aplicacions web: Intervals més llargs (`30s`) per no sobrecarregar el servei.
- Serveis lents en arrencar: Usa `start_period` generosament per evitar falsos negatius durant la inicialització.

**Healthchecks lleugers**

El *healthcheck* s'executa dins el contenidor i consumeix recursos. Per tant, ens convé evitar comprovacions costoses. Per exemple, evita una consulta completa a la base de dades:

```yaml
healthcheck:
  test: ["CMD-SHELL", "psql -U postgres -c 'SELECT COUNT(*) FROM users'"]
```

És millor fer una comprovació de connexió:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
```

**Endpoints de salut dedicats**

Per a aplicacions pròpies, implementa un endpoint `/health` que verifiqui les dependències crítiques. Per exemple, amb [Node.js](https://nodejs.org/) i [Express](https://expressjs.com/):

```javascript
app.get('/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    await redis.ping();
    res.json({ status: 'healthy' });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', error: error.message });
  }
});
```

Això permet que el *healthcheck* detecti problemes amb les dependències, no només que el procés estigui en execució.

**Gestió d'errors a l'arrencada**

Si un servei falla repetidament durant l'arrencada, revisa:

1. Els logs del contenidor amb `docker compose logs <servei>`.
2. L'historial de *healthchecks* amb `docker inspect`.
3. Que els paràmetres de *healthcheck* siguin realistes per al temps d'arrencada del servei.

## Exercicis


Es proposen dos exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Afegir healthcheck a l'API de tasques**

Partint del projecte de l'article anterior (Tasks API amb Express i PostgreSQL), implementa un sistema de *healthchecks* complet.

1. Afegeix un endpoint `/health` a l'API que verifiqui la connexió amb PostgreSQL.
2. Configura el *healthcheck* per al servei `api` al `compose.yaml`.
3. Modifica el `depends_on` per usar la condició `service_healthy`.
4. Verifica que l'API no arrenca fins que PostgreSQL estigui llest.

> Pista: Per verificar la connexió amb PostgreSQL des de Node.js, pots fer una consulta simple com `SELECT 1` o usar el mètode `pool.query()` que ja tens al mòdul `db.js`.

{{< details summary="Respostes" >}}

Afegeix el següent endpoint a `api/src/app.js`, just després dels altres endpoints:

```javascript
/**
 * GET /health - Healthcheck endpoint.
 * Verifica la connexió amb la base de dades.
 */
app.get("/health", async (req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "healthy", database: "connected" });
  } catch (error) {
    console.error("Health check failed:", error);
    res.status(503).json({ status: "unhealthy", database: "disconnected" });
  }
});
```

No oblidis afegir `pool` a la línia d'importació:

```javascript
import { initDB, getTasks, createTask, completeTask, deleteTask } from "./db.js";
import pool from "./db.js";
```

Modifica el servei `api` al `compose.yaml`:

```yaml
services:
  api:
    build:
      context: ./api
    image: tasks-api:1.0
    depends_on:
      db:
        condition: service_healthy
    environment:
      NODE_ENV: ${NODE_ENV}
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB}
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "3000:3000"
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:3000/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 15s
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

volumes:
  postgres-data:
```

Reconstrueix i arrenca els serveis:

```bash
docker compose up --build --detach
```

Verifica l'estat dels *healthchecks*:

```bash
docker compose ps
```

Prova l'endpoint de *healthcheck*:

```bash
curl http://localhost:3000/health
```

{{< /details >}}

### Exercici 2

**Healthcheck amb múltiples dependències**

Configura un stack amb tres serveis on el servei principal depengui de dos serveis de backend:

1. Un servei `cache` amb Redis.
2. Un servei `db` amb PostgreSQL.
3. Un servei `web` amb NGINX que només arrenca quan els dos anteriors estan saludables.

El servei `web` ha de servir una pàgina HTML estàtica que mostri "Servidor operatiu".

{{< details summary="Respostes" >}}

Crea l'estructura del projecte:

```
stack-healthcheck/
├── compose.yaml
├── .env
└── html/
    └── index.html
```

Crea el fitxer `html/index.html`:

```html
<!DOCTYPE html>
<html lang="ca">
<head>
    <meta charset="UTF-8">
    <title>Stack healthcheck</title>
</head>
<body>
    <h1>Servidor operatiu</h1>
    <p>Tots els serveis han arrencat correctament.</p>
</body>
</html>
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
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_healthy
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost/ || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
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

  cache:
    image: redis:8.6-alpine
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 3
    restart: unless-stopped

volumes:
  postgres-data:
  redis-data:
```

Arrenca l'stack:

```bash
docker compose up --detach
```

Observa com el servei `web` espera que `db` i `cache` estiguin saludables:

```bash
docker compose ps
```

Obre el navegador a `http://localhost:8080/` per verificar que tot funciona.

{{< /details >}}
