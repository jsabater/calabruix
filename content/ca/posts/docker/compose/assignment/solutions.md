# Solucions

## Diagrama de referència

Es proposa el següent diagrama de referència:

```
                      ┌─────────────────┐
                      │     Traefik     │
                      │  (proxy invers) │
                      │     :80/:443    │
                      └────────┬────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
    │    NGINX     │    │     API      │    │  RabbitMQ    │
    │  (front-end) │    │ (sportsclub) │    │ (management) │
    │    :80       │    │   :8000      │    │   :15672     │
    └──────────────┘    └──────┬───────┘    └──────┬───────┘
                               │                   │
           ┌───────────────────┼───────────────────┤
           │                   │                   │
           ▼                   ▼                   ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │ PostgreSQL  │     │   Valkey    │     │   Worker    │
    │   :5432     │     │   :6379     │     │  (Node.js)  │
    └─────────────┘     └─────────────┘     └─────────────┘
```

## Xarxes proposades

Es proposa la següent configuració de xarxes:

- `frontend`: Traefik, NGINX
- `backend`: API, PostgreSQL, Valkey, RabbitMQ, Worker
- `proxy`: Traefik, API, NGINX, RabbitMQ (management)

## Volums proposats

Es proposen els següents volums de dades:

- `postgres-data`: Dades de PostgreSQL
- `valkey-data`: Dades de Valkey
- `rabbitmq-data`: Dades de RabbitMQ

## Variables d'entorn mínimes

Les variables d'entorn mínimes necessàries són les següents:

```bash
# PostgreSQL
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=

# Django
DJANGO_SECRET_KEY=
DEBUG=

# Valkey
VALKEY_PASSWORD=

# RabbitMQ
RABBITMQ_DEFAULT_USER=
RABBITMQ_DEFAULT_PASS=
```

## Healthchecks de referència

Es proposa la següent configuració de *healthchecks*:

| Servei     | Comanda de *healthcheck*                               |
|------------|--------------------------------------------------------|
| PostgreSQL | `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}`     |
| Valkey     | `valkey-cli ping`                                      |
| RabbitMQ   | `rabbitmq-diagnostics -q ping`                         |
| API        | `wget -q --spider http://localhost:8000/api/v1/health` |
| Traefik    | `traefik healthcheck --ping`                           |
| Nginx      | `wget -q --spider http://localhost`                    |

## Límits de recursos orientatius

Es proposen els següents límits de recursos, considerats suficients donat el que s'ha d'executar a cada servei:

| Servei     | CPU màx. | Memòria màx. |
|------------|:--------:|--------------|
| API        | 1.0      | 512M         |
| PostgreSQL | 0.5      | 512M         |
| Valkey     | 0.25     | 256M         |
| RabbitMQ   | 0.5      | 512M         |
| Worker     | 0.25     | 256M         |
| Nginx      | 0.25     | 128M         |
| Traefik    | 0.25     | 256M         |

## Fitxer HTML del front-end

Per a poder aprofitar la configuración per defecte d'NGINX, col·locarem el fitxer `index.html` a la ruta `/usr/share/nginx/html/index.html`, muntant el directori `frontend/`  en aquesta ubicació. D'aquesta forma NGINX ja el servirà correctament a l'arrel.

## Fitxers del worker

El fitxer `worker.js` i el fitxer `package.json` es col·loquen al directori `docker/worker/` del repositori local.

## Variables d'entorn

Es proposa el següent fitxer `.env`:

```ini
# PostgreSQL
POSTGRES_USER=sportsclub
POSTGRES_PASSWORD=super-secret-postgres-password
POSTGRES_DB=sportsclub

# Django
DJANGO_SECRET_KEY=super-secret-and-long-django-secret-key
DEBUG=false
ALLOWED_HOSTS=localhost,127.0.0.1

# Valkey (cache)
VALKEY_PASSWORD=super-secret-valkey-password

# RabbitMQ
RABBITMQ_DEFAULT_USER=sportsclub
RABBITMQ_DEFAULT_PASS=super-secret-rabbitmq-password
```

## Dockerfile del worker

Es proposa el següent fitxer `Dockerfile` del worker, per a ser col·locat dins `docker/worker/`:

```dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY worker.js ./
USER node
CMD ["node", "worker.js"]
```

Una proposta alternativa més didàctica, amb multi-stage builds, seria:

```dockerfile
FROM node:24-alpine AS builder
WORKDIR /app
COPY package.json ./
RUN npm install

# --------------------------------------------------

FROM node:24-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY package.json worker.js ./
USER node
CMD ["node", "worker.js"]
```

## Fitxer compose.yaml

Es proposa el següent fitxer `compose.yaml`, a l'arrel del projecte:

```yaml
# compose.yaml

# Extensions YAML

x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

x-healthcheck-defaults: &healthcheck-defaults
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s

x-restart-policy: &restart-policy
  restart: unless-stopped


# Serveis

services:

  # Traefik - Proxy invers
  traefik:
    image: traefik:v3.4
    command:
      - "--api.dashboard=true"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entryPoints.web.address=:80"
      - "--ping=true"
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - frontend
      - proxy
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "traefik", "healthcheck", "--ping"]
    logging: *default-logging
    <<: *restart-policy


  # NGINX - Front-end estàtic
  nginx:
    image: nginx:alpine
    volumes:
      - ./frontend:/usr/share/nginx/html:ro
    networks:
      - frontend
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`localhost`) && !PathPrefix(`/api`) && !PathPrefix(`/rabbitmq`)"
      - "traefik.http.routers.frontend.entrypoints=web"
      - "traefik.http.services.frontend.loadbalancer.server.port=80"
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD-SHELL", "wget -q --spider http://localhost/ || exit 1"]
    logging: *default-logging
    <<: *restart-policy


  # API REST - Django Ninja (Sports Club)
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    environment:
      POSTGRES_HOST: db
      POSTGRES_PORT: 5432
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      SECRET_KEY: ${DJANGO_SECRET_KEY}
      DEBUG: ${DEBUG:-false}
      ALLOWED_HOSTS: ${ALLOWED_HOSTS:-localhost,127.0.0.1}
    networks:
      - backend
      - proxy
    depends_on:
      db:
        condition: service_healthy
      valkey:
        condition: service_healthy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.api.entrypoints=web"
      - "traefik.http.services.api.loadbalancer.server.port=8000"
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD-SHELL", "wget -q --spider http://localhost:8000/api/v1/docs || exit 1"]
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          memory: 256M
    logging: *default-logging
    <<: *restart-policy


# PostgreSQL - Base de dades
  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    networks:
      - backend
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          memory: 256M
    logging: *default-logging
    <<: *restart-policy


# Valkey - Cache
  valkey:
    image: valkey/valkey:8-alpine
    command: valkey-server --requirepass ${VALKEY_PASSWORD}
    volumes:
      - valkey-data:/data
    networks:
      - backend
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD-SHELL", "valkey-cli -a ${VALKEY_PASSWORD} ping | grep -q PONG"]
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
        reservations:
          memory: 128M
    logging: *default-logging
    <<: *restart-policy


  # RabbitMQ - Broker de missatges
  rabbitmq:
    image: rabbitmq:4-management-alpine
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_DEFAULT_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS}
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
    networks:
      - backend
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.rabbitmq.rule=Host(`localhost`) && PathPrefix(`/rabbitmq`)"
      - "traefik.http.routers.rabbitmq.entrypoints=web"
      - "traefik.http.middlewares.rabbitmq-strip.stripprefix.prefixes=/rabbitmq"
      - "traefik.http.routers.rabbitmq.middlewares=rabbitmq-strip"
      - "traefik.http.services.rabbitmq.loadbalancer.server.port=15672"
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      start_period: 60s
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          memory: 256M
    logging: *default-logging
    <<: *restart-policy

  # Worker - Consumidor de RabbitMQ amb Node.js
  worker:
    build:
      context: ./docker/worker
      dockerfile: Dockerfile
    environment:
      RABBITMQ_HOST: rabbitmq
      RABBITMQ_PORT: 5672
      RABBITMQ_USER: ${RABBITMQ_DEFAULT_USER}
      RABBITMQ_PASS: ${RABBITMQ_DEFAULT_PASS}
      QUEUE_NAME: tasks
    networks:
      - backend
    depends_on:
      rabbitmq:
        condition: service_healthy
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
        reservations:
          memory: 128M
    logging: *default-logging
    <<: *restart-policy

  # Adminer - Gestió de base de dades (perfil dev)
  adminer:
    image: adminer:latest
    networks:
      - backend
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.adminer.rule=Host(`localhost`) && PathPrefix(`/adminer`)"
      - "traefik.http.routers.adminer.entrypoints=web"
      - "traefik.http.services.adminer.loadbalancer.server.port=8080"
    depends_on:
      db:
        condition: service_healthy
    profiles:
      - dev
    logging: *default-logging
    <<: *restart-policy


  # Mailpit - Servidor SMTP de proves (perfil dev)
  mailpit:
    image: axllent/mailpit:latest
    environment:
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
    networks:
      - backend
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mailpit.rule=Host(`localhost`) && PathPrefix(`/mailpit`)"
      - "traefik.http.routers.mailpit.entrypoints=web"
      - "traefik.http.middlewares.mailpit-strip.stripprefix.prefixes=/mailpit"
      - "traefik.http.routers.mailpit.middlewares=mailpit-strip"
      - "traefik.http.services.mailpit.loadbalancer.server.port=8025"
    profiles:
      - dev
    logging: *default-logging
    <<: *restart-policy


# Xarxes

networks:
  frontend:
    name: sportsclub-frontend
  backend:
    name: sportsclub-backend
  proxy:
    name: sportsclub-proxy


# Volums

volumes:
  postgres-data:
    name: sportsclub-postgres-data
  valkey-data:
    name: sportsclub-valkey-data
  rabbitmq-data:
    name: sportsclub-rabbitmq-data
```
