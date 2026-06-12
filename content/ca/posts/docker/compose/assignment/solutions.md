# Solucions

La situació actual del repositori `sportsclub` es la següent:

```
├── compose.yaml                # Blue-green deployment amb NGINX
├── docker/
│   ├── app/Dockerfile          # Python 3.13, uvicorn al port 8080
│   ├── nginx/
│   │   ├── Dockerfile          # NGINX stable
│   │   └── nginx.conf          # Proxy a app-blue/app-green
│   └── postgres/Dockerfile     # PostgreSQL 18 (buit, només FROM)
├── sportsclub/                 # Codi Django
└── requirements.txt
```

El següent diagrama representa l'arquitectura actual:

```
                     ┌─────────────────┐
                     │      NGINX      │
                     │ (proxy/balancer)│
                     │     :8000       │
                     └────────┬────────┘
                              │
             ┌────────────────┼────────────────┐
             │                                 │
             ▼                                 ▼
      ┌─────────────┐                   ┌─────────────┐
      │  app-blue   │                   │  app-green  │
      │   (actiu)   │                   │  (standby)  │
      │   :8080     │                   │   :8080     │
      └──────┬──────┘                   └──────┬──────┘
             │                                 │
             └────────────────┬────────────────┘
                              │
                              ▼
                       ┌─────────────┐
                       │ PostgreSQL  │
                       │   :5432     │
                       └─────────────┘
```


## Diagrama de referència

El següent diagrama representa l'arquitectura objectiu:

```
                      ┌─────────────────┐
                      │     Traefik     │
                      │  (proxy invers) │
                      │      :80        │
                      └────────┬────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
    │    NGINX     │    │     API      │    │  RabbitMQ    │
    │  (frontend)  │    │ (sportsclub) │    │ (management) │
    │     :80      │    │    :8080     │    │   :15672     │
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

- `frontend`: Traefik, NGINX, API
- `backend`: API, PostgreSQL, Valkey, RabbitMQ, Worker


## Volums proposats

Es proposen els següents volums de dades:

- `postgres-data`: Dades de PostgreSQL
- `valkey-data`: Dades de Valkey
- `rabbitmq-data`: Dades de RabbitMQ


## Servei d'NGINX

NGINX deixa d'usar-se com a proxy invers i passa a actuar únicament com a servidor web del front-end. Per tant, el seu fitxer de configuració `docker/nginx/nginx.conf` ha d'adaptar-se a aquestes circumstàncies:

```nginx
# docker/nginx/nginx.conf
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80;
        server_name localhost;

        root /usr/share/nginx/html;
        index index.html;

        # Frontend estàtic
        location / {
            try_files $uri $uri/ /index.html;
        }

        # Health check
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
```

> Hem aprofitat per a after un endpoint `/health` que NGINX usara per saber si el servei està actiu o no.

Així mateix, haurem de modificar també el `Dockerfile` per incloure el codi del front-end (fitxer `index.html` proporcionat):

```dockerfile
# docker/nginx/Dockerfile
FROM nginx:1.30-alpine

# Copiar configuració
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Copiar frontend
COPY frontend/ /usr/share/nginx/html/

EXPOSE 80
```




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
# docker/worker/Dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY worker.js ./
USER node
CMD ["node", "worker.js"]
```

Els fitxers `docker/worker/worker.js` i `docker/worker/packages.json` es proporcionen a l'enunciat.



# Consultar la documentació de l'API

```bash
curl http://localhost:8080/api/v1/docs
```



## Comandes per provar

```bash
# 1. Configurar entorn
cp .env.example .env
# Editar .env amb les credencials

# 2. Construir imatges
docker compose build

# 3. Arrencar serveis base
docker compose up -d postgres
docker compose ps  # Esperar healthy

# 4. Arrencar resta de serveis
docker compose up -d

# 5. Verificar estat
docker compose ps

# 6. Provar endpoints
curl http://localhost/                    # Frontend
curl http://localhost/api/v1/docs         # Documentació API
curl http://localhost/api/v1/health       # Health check

# 7. Mode desenvolupament
docker compose --profile dev up -d
curl http://localhost/adminer             # Adminer
curl http://localhost/mailpit             # Mailpit
```


Resultats:

http://localhost/ carrega correctament el frontend i les accions sobre els endpoints d'atletes funcionen.

http://localhost/api/v1/docs mostra una pàgina en blanc.

http://localhost/api/v1/core/health funciona correctament, retornant el JSON

http://localhost:8080/dashboard/ carrega correctament.

http://localhost:15672/ carrega correctament.

curl http://localhost/api/v1/core/health funciona bé
curl http://localhost/api/v1/people/athletes funciona bé.
La comanda docker compose --profile dev up -d​ funciona bé. La comanda docker compose logs worker -f​ mostra el logs (esperant missatges).



