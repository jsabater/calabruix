---
title: "Desplegament d'una aplicació Django amb Swarm"
date: 2026-02-11
lastmod: 2026-02-28
description: "Cas pràctic complet: desplegament d'una aplicació Django amb Traefik, PostgreSQL, Redis i Celery"
summary: "Cas pràctic complet: desplegament d'una aplicació Django amb Traefik, PostgreSQL, Redis i Celery"
categories: ["teaching"]
tags: ["docker", "swarm", "django", "traefik", "celery", "postgresql", "redis"]
series: ["Docker Swarm"]
series_order: 9
weight: 90
slug: exemple-complet
---

Aquest tema integra els conceptes vistos fins ara en un cas pràctic complet: el desplegament d'una aplicació web Django en un clúster Docker Swarm. L'exemple inclou molts dels components habituals d'una aplicació web moderna: proxy invers, base de dades, caché, cua de tasques i múltiples rèpliques de l'aplicació.

## Arquitectura

L'aplicació consta dels següents serveis:

| Servei   | Rèpliques | Mode                    | Funció                                    |
|:---------|:---------:|:------------------------|:------------------------------------------|
| traefik  | 1         | replicated              | Proxy invers i gestor de tràfic d'entrada |
| postgres | 1         | replicated (constraint) | Base de dades principal                   |
| redis    | 1         | replicated              | Sessions, caché i broker de Celery        |
| web      | 3         | replicated              | Aplicació Django amb Gunicorn             |
| worker   | 2         | replicated              | Workers de Celery                         |
| beat     | 1         | replicated              | Celery Beat per a tasques periòdiques     |

**Les bases de dades de Redis**

Redis és un servidor de base de dades en memòria. En aquesta arquitectura, una única instància de Redis serveix per a quatre propòsits diferents, usant bases de dades separades (índexos del 0 al 3):

| # | Ús                   | Qui hi escriu   | Qui hi llegeix  |
|:-:|----------------------|-----------------|-----------------|
| 0 | Sessions d'usuari    | Django (web)    | Django (web)    |
| 1 | Caché de dades       | Django (web)    | Django (web)    |
| 2 | Cua de tasques       | Django (web)    | Celery (worker) |
| 3 | Resultats de tasques | Celery (worker) | Django (web)    |

**El sistema de missatgeria**

El broker és el sistema de missatgeria que actua com a intermediari entre qui envia tasques i qui les executa. Quan el codi Django vol executar una tasca en segon pla, l'envia al broker (Redis, en aquest cas). Els workers de Celery estan constantment escoltant el broker esperant a consumir tasques noves.

```python
# tasks.py
from celery import shared_task

@shared_task
def send_welcome_email(user_id):
    user = User.objects.get(id=user_id)
    # Enviar email...

# views.py
def register(request):
    user = User.objects.create(...)
    send_welcome_email.delay(user.id)  # Afegeix la tasca a la cua
    return Response({"status": "ok"})
```

Celery Beat és un procés que s'executa contínuament i, segons un calendari definit, afegeix tasques a la cua. Essencialment, un `cron` per a Celery.

{{< alert icon="triangle-exclamation" >}}
Celery Beat ha de tenir **exactament una rèplica**. Múltiples instàncies executarien les tasques periòdiques més d'una vegada.
{{< /alert >}}

El següent diagrama mostra la relació entre els serveis:

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart TB
    subgraph public["Xarxa pública"]
        traefik["Traefik"]
    end
    
    subgraph backend["Xarxa interna"]
        web["3x Gunicorn"]
        worker["2x Celery worker"]
        beat["Celery Beat"]
        postgres["PostgreSQL"]
        redis["Redis"]
    end
    
    internet((Internet)) --> traefik
    traefik --> web
    web --> postgres
    web --> redis
    worker --> postgres
    worker --> redis
    beat --> redis
{{< /mermaid >}}

## Gestió de configuració

Quan el projecte Django usa un fitxer `.env` amb `django-environ` per carregar la configuració, cal adaptar l'enfocament per a Docker Swarm. L'estratègia recomanada és separar la configuració en tres categories:

| Categoria                | Mecanisme          | Exemple                           |
|:-------------------------|:-------------------|:----------------------------------|
| Configuració no sensible | Variables d'entorn | `DEBUG`, `ALLOWED_HOSTS`          |
| Fitxers de configuració  | Docker Configs     | Traefik, NGINX, etc.              |
| Credencials              | Docker Secrets     | `SECRET_KEY`, `POSTGRES_PASSWORD` |

És important tenir clar com arriben les variables al contenidor i com s'accedeixen des de Python:

| Mecanisme          | Definició (YAML) | Accés (Python)                       |
|:-------------------|:-----------------|:-------------------------------------|
| Variables d'entorn | `environment:`   | `env("VAR")` o `os.environ["VAR"]`   |
| Docker Configs     | `configs:`       | Llegint el fitxer `/run/configs/VAR` |
| Docker Secrets     | `secrets:`       | Llegint el fitxer `/run/secrets/VAR` |

### Fitxer de configuració

El codi Python del fitxer `settings.py` s'ha d'adaptar per compatibilitzar l'entorn de desenvolupament (Docker Compose amb fitxer `.env`) i l'entorn de producció (Docker Swarm amb secrets):

```python
# settings.py
from pathlib import Path
import environ


# Directori base del projecte
BASE_DIR = Path(__file__).resolve().parent.parent

# Inicialització de django-environ
env = environ.Env()

# Llegir .env si existeix (entorn de desenvolupament)
env_file = BASE_DIR.parent / ".env"
if env_file.exists():
    environ.Env.read_env(env_file)


def get_secret(name):
    """Llegeix un secret de /run/secrets/ si existeix."""
    secret_path = Path(f"/run/secrets/{name}")
    if secret_path.exists():
        return secret_path.read_text().strip()
    return None


# Configuració general

SECRET_KEY = get_secret("SECRET_KEY") or env("SECRET_KEY")
DEBUG = env.bool("DEBUG")
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS")


# Base de dades

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "HOST": env("POSTGRES_HOST"),
        "PORT": env.int("POSTGRES_PORT"),
        "NAME": env("POSTGRES_DB"),
        "USER": get_secret("POSTGRES_USER") or env("POSTGRES_USER"),
        "PASSWORD": get_secret("POSTGRES_PASSWORD") or env("POSTGRES_PASSWORD"),
    }
}


# Redis

REDIS_SESSIONS_URL = env("REDIS_SESSIONS_URL")
REDIS_CACHE_URL = env("REDIS_CACHE_URL")

SESSION_ENGINE = "django.contrib.sessions.backends.cache"
SESSION_CACHE_ALIAS = "sessions"

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_CACHE_URL,
    },
    "sessions": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_SESSIONS_URL,
    },
}


# Celery

CELERY_BROKER_URL = env("CELERY_BROKER_URL")
CELERY_RESULT_BACKEND = env("CELERY_RESULT_BACKEND")
```

L'ordre `get_secret() or env()` permet que:

* A desenvolupament es llegeix del fitxer `.env`.
* A producció es llegeix del fitxer i s'ignora la variable d'entorn.

### Fitxer de variables

Al repositori hi haurà un fitxer `.env.example` amb valors per defecte apropiats per a desenvolupament. El procediment habitual és copiar aquest fitxer a `.env` abans de construir l'entorn amb Docker Compose:

```bash
# Django
SECRET_KEY=dev-secret-key-change-in-production
DEBUG=true
ALLOWED_HOSTS=localhost,127.0.0.1

# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=myapp
POSTGRES_USER=myapp
POSTGRES_PASSWORD=myapp

# Redis
# Base de dades 0: Sessions
# Base de dades 1: Caché de dades
# Base de dades 2: Broker Celery (cua de tasques)
# Base de dades 3: Backend Celery (resultats)
REDIS_SESSIONS_URL=redis://redis:6379/0
REDIS_CACHE_URL=redis://redis:6379/1
CELERY_BROKER_URL=redis://redis:6379/2
CELERY_RESULT_BACKEND=redis://redis:6379/3
```

El fitxer `.env` s'ha d'excloure del repositori afegint-lo al `.gitignore`:

```gitignore
.env
.env.prod
!.env.example
```

## Traefik

Traefik actua com a proxy invers i gestor del tràfic d'entrada. La seva configuració, diferent per a desenvolupament i producció, es gestiona amb Docker Configs. Guardarem ambdós fitxers de configuració dins el subdirectori `docker/<servei>/`.

```yaml
# docker/traefik/traefik.devel.yml
api:
  dashboard: true
  insecure: true  # Dashboard sense autenticació

entryPoints:
  http:
    address: ":80"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: myapp_public
```

A la configuració de producció afegirem:

* Redirecció automàtica de HTTP a HTTPS.
* Certificats Let's Encrypt.
* Mode Swarm activat.

```yaml
# docker/traefik/traefik.prod.yml
api:
  dashboard: false

entryPoints:
  http:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: https
          scheme: https
  https:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    swarmMode: true
    exposedByDefault: false
    network: myapp_public

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@domini.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: http
```

A diferència d'NGINX, amb Traefik la configuració es dinàmica, a través d'etiquetes als contenidors. Traefik descobreix automàticament els serveis i les seves regles consultant l'API de Docker. Per exemple, l'equivalent al `server_name` d'NGINX o `ServerName` d'Apache es defineix a les etiquetes del servei Docker, no al fitxer de configuració:

```yaml
# docker-stack.yml
services:
  web:
    image: myapp:latest
    deploy:
      labels:
        - "traefik.http.routers.web.rule=Host(`example.com`) || Host(`www.example.com`)"
```

**Què implica `swarmMode: true`?**

Si `swarmMode` és `false` o no s'especifica, Traefik consulta l'API de *Docker* per descobrir contenidors individuals. En canvi, si és `true`, Traefik consulta l'API de *Swarm* per descobrir serveis.

| Mode               | Descobreix  | Etiquetes les llegeix de    | Balanceig                |
|--------------------|-------------|-----------------------------|--------------------------|
| `swarmMode: false` | Contenidors | `labels:` del contenidor    | Traefik gestiona         |
| `swarmMode: true`  | Serveis     | `deploy.labels:` del servei | Swarm gestiona (VIP[^1]) |

[^1]: Virtual IP (VIP) és una adreça lògica assignada al servei que habilita el balanceig de càrrega intern i el descobriment automàtic de serveis.

Amb `swarmMode: true`:

* Traefik veu un sol endpoint per servei (la IP virtual de Swarm), no cada rèplica individual.
* Les etiquetes s'han de posar dins deploy.labels, no a labels del servei.
* Swarm s'encarrega del balanceig entre rèpliques.

**Redirecció a domini arrel**

Traefik utilitza un *middleware* per a redirigir el tràfic del subdomini `www.domini.com` al domini `domini.com`:

```yaml
services:
  web:
    deploy:
      labels:
        # Router principal pel domini arrel
        - "traefik.http.routers.web.rule=Host(`domini.com`)"
        - "traefik.http.routers.web.entrypoints=https"
        - "traefik.http.routers.web.tls.certresolver=letsencrypt"
        
        # Router pel subdomini `www.`
        - "traefik.http.routers.www.rule=Host(`www.domini.com`)"
        - "traefik.http.routers.www.entrypoints=https"
        - "traefik.http.routers.www.tls.certresolver=letsencrypt"
        - "traefik.http.routers.www.middlewares=www-redirect"
        
        # Middleware per a redirigir tràfic del subdomini `www.` al domini arrel
        - "traefik.http.middlewares.www-redirect.redirectregex.regex=^https://www\\.domini\\.com/(.*)"
        - "traefik.http.middlewares.www-redirect.redirectregex.replacement=https://domini.com/$${1}"
        - "traefik.http.middlewares.www-redirect.redirectregex.permanent=true"
        
        # Servei web amb Django
        - "traefik.http.services.web.loadbalancer.server.port=8080"
```

Això crea dos routers, un pel domini arrel `domini.com`, que serveix l'aplicació, i un altre per al subdomini `www.domini.com`, i un *middleware* que redirigeix del segon al primer amb un HTTP 301.

> Les etiquetes de Traefik es posen al servei `web` (l'aplicació Django amb Gunicorn/Uvicorn) perquè és el servei que ha de rebre el tràfic extern.

## Fitxers Docker

Com ja hem explicat en anteriors articles, a causa del nombre de diferències que arribarem a acumular entre Docker Compose i Docker Stack, en comptes d'un override de Compose usarem fitxers separats per a cada entorn.

> Per evitar sorpreses, a cada servei emprarem la mateixa imatge i etiqueta tant a desenvolupament com a producció.

### Fitxer Compose

Per a desenvolupament local, usam el fitxer `docker-compose.yml`. Les diferències principals respecte al fitxer stack són:

* Ús de `build:` per construir imatges localment, combinat amb `image:` per etiquetar-les.
* Variables d'entorn carregades des del fitxer `.env`.
* *Bind volumes* per muntar el codi font i permetre hot-reload.
* Tots els secrets es passen com a variables d'entorn.
* Ports exposats per facilitar la depuració.
* Traefik configurat sense mode Swarm.

```yaml
# docker-compose.yml

services:
  # Traefik: Proxy invers
  traefik:
    image: traefik:v3.6
    ports:
      - "80:80"
      - "8080:8080"  # Dashboard de Traefik
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./docker/traefik/traefik.devel.yml:/etc/traefik/traefik.yml:ro
    networks:
      - public

  # PostgreSQL: Base de dades principal
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql
    ports:
      - "5432:5432"  # Accés directe per a psql i pgAdmin
    networks:
      - backend

  # Redis: Sessions, caché i broker de Celery
  redis:
    image: redis:8.6-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"  # Accés directe per a redis-cli
    networks:
      - backend

  # Aplicació web Django amb Gunicorn/Uvicorn
  web:
    build:
      context: .
      dockerfile: docker/app/Dockerfile  # Usa la comanda per defecte
    environment:
      - DEBUG=${DEBUG}
      - SECRET_KEY=${SECRET_KEY}
      - ALLOWED_HOSTS=${ALLOWED_HOSTS}
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - REDIS_SESSIONS_URL=redis://redis:6379/0
      - REDIS_CACHE_URL=redis://redis:6379/1
      - CELERY_BROKER_URL=redis://redis:6379/2
      - CELERY_RESULT_BACKEND=redis://redis:6379/3
    volumes:
      - .:/app  # Codi font per a hot-reload
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.web.rule=Host(`localhost`)"
      - "traefik.http.routers.web.entrypoints=http"
      - "traefik.http.services.web.loadbalancer.server.port=8080"
    networks:
      - public
      - backend
    depends_on:
      - postgres
      - redis

  # Celery worker: consumidors de tasques
  worker:
    build:
      context: .
      dockerfile: docker/app/Dockerfile
    command: celery -A myapp worker -l info  # Sobreescriu la comanda per defecte
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - CELERY_BROKER_URL=redis://redis:6379/2
      - CELERY_RESULT_BACKEND=redis://redis:6379/3
    volumes:
      - .:/app
    networks:
      - backend
    depends_on:
      - redis

  # Celery Beat per a tasques programades, i.e., cron.
  beat:
    build:
      context: .
      dockerfile: docker/app/Dockerfile
    command: celery -A myapp beat -l info  # Sobreescriu la comanda per defecte
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - CELERY_BROKER_URL=redis://redis:6379/2
      - CELERY_RESULT_BACKEND=redis://redis:6379/3
    volumes:
      - .:/app
    networks:
      - backend
    depends_on:
      - redis

networks:
  public:
  backend:

volumes:
  postgres_data:
  redis_data:
```

### Dockerfile

Fixa't que els serveis `web`, `worker` i `beat` usen el mateix `Dockerfile`. Això és perquè els tres serveis executen el mateix codi Python (l'aplicació Django), canviant només la comanda d'entrada:

| Servei   | Comanda                                           | Funció                       |
|----------|---------------------------------------------------|------------------------------|
| `web`    | `gunicorn myapp.wsgi` (o implicita al Dockerfile) | Serveix peticions HTTP       |
| `worker` | `celery -A myapp worker -l info`                  | Processa tasques de la cua   |
| `beat`   | `celery -A myapp beat -l info`                    | Programa tasques periòdiques |

El Dockerfile construeix una imatge amb tot el necessari: Django, Celery, Gunicorn, dependències i el codi font. Després, cada servei sobreescriu la comanda per defecte amb `command:`.

```yaml
# docker/app/Dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Comanda per defecte (servei web)
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "myapp.wsgi"]
```

El worker de Celery necessita:

* Models de Django per accedir a la base de dades via l'ORM.
* La configuració de l'aplicació (`settings.py`) amb credencials, connexions, etc.
* El codi de l'aplicació, car les funcions de tasques importen mòduls del projecte.
* Les mateixes biblioteques que l'aplicació web.

> Celery no pot funcionar aïlladament perquè les tasques són codi Python que depèn de l'aplicació.

### Fitxer Stack

Per a producció usam el fitxer `docker-stack.yml`, que defineix tots els serveis, xarxes, volums, configs i secrets. Les diferències principals respecte al fitxer compose són:

* Ús estricte d'`image:` amb registre (Swarm no suporta `build:`).
* Variables d'entorn definides al propi fitxer.
* *Named volumes* amb constraints per a garantir persistència de dades al node correcte.
* Ús de Docker Configs per als fitxers de configuració.
* Ús de Docker Secrets per a les credencials.
* Els únics ports exposats són els del proxy invers.
* Traefik configurat amb mode Swarm.

**Xarxes**

Cream dues xarxes separades en aquesta arquitectura:

* La xarxa `public`, accessible des de l'exterior, connecta Traefik amb l'aplicació web.
* La xarxa `backend`, marcada com a `internal: true` per impedir l'accés extern, connecta l'aplicació amb PostgreSQL i Redis.

```yaml
# docker-stack.yml: Xarxes
networks:
  public:
    driver: overlay
  backend:
    driver: overlay
    internal: true
```

**Volums**

En aquesta configuració, Redis emmagatzema dades efímeres (sessions, caché) i la cua de tasques de Celery. El volum `redis_data` proporciona persistència bàsica: si el contenidor es reinicia, les dades es mantenen.

Tanmateix, cal tenir en compte:

* La caché i les sessions són regenerables. Si es perden, els usuaris hauran de tornar a iniciar sessió i la caché es reconstruirà automàticament.
* Les tasques pendents a la cua de Celery es perdrien si Redis cau sense persistència. Per aquest motiu, la comanda `--appendonly yes` activa l'AOF (Append Only File), que registra cada operació a disc i permet recuperar les tasques després d'un reinici.

Per a entorns amb requisits d'alta disponibilitat, caldria considerar Redis Sentinel o Redis Cluster, però això excedeix l'abast d'aquest exemple.

```yaml
# Volums
volumes:
  postgres_data:
  redis_data:
```

**Configuracions**

Usam el fitxer de Traefik de l'entorn de producció.

```yaml
# Configs
configs:
  traefik_config:
    file: ./docker/traefik/traefik.prod.yml
```

**Secrets**

Els secrets es marquen com a `external: true` perquè es crearan prèviament amb `docker secret create`. Això evita tenir fitxers amb credencials al repositori.

```yaml
# Secrets
secrets:
  secret_key:
    external: true
  postgres_user:
    external: true
  postgres_password:
    external: true
```

> El nom d'usuari de la base de dades també cal considerar-lo un secret.

**Servei de Traefik**

Traefik necessita accés al socket de Docker (`/var/run/docker.sock`) per descobrir serveis. En mode Swarm, només els managers tenen la informació completa del clúster a través d'aquest socket. Si Traefik s'executés a un worker, no podria descobrir els serveis correctament.

Per això restringim aquest servei als nodes gestors. Tots els managers tenen `node.role == manager`, així que Traefik pot executar-se a qualsevol d'ells, no només al líder.

```yaml
services:
  # Traefik: Proxy invers
  traefik:
    image: traefik:v3.6
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    configs:
      - source: traefik_config
        target: /etc/traefik/traefik.yml
    networks:
      - public
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
```

**Servei de PostgreSQL**

El servei `postgres` té un constraint `node.labels.db == true`. Això garanteix que la base de dades s'executi sempre al mateix node, on hi ha el volum amb les dades.

```yaml
  # PostgreSQL: Base de dades principal
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER_FILE: /run/secrets/postgres_user
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    secrets:
      - postgres_user
      - postgres_password
    volumes:
      - postgres_data:/var/lib/postgresql
    networks:
      - backend
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.db == true
```

**Servei de Redis**

El servei `redis` té un constraint `node.labels.cache == true`. Això garanteix que la base de dades s'executi sempre al mateix node, on hi ha el volum amb les dades.

```yaml
  # Redis: Sessions, caché i broker de Celery
  redis:
    image: redis:8.6-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.cache == true
```

**Servei de l'aplicació web Django amb Gunicorn**

El servei té definits límits de CPU i memòria per evitar que un servei consumeixi tots els recursos del clúster.

```yaml
  # Aplicació web Django amb Gunicorn
  web:
    image: myuser/myapp:${VERSION:-latest}
    environment:
      - DEBUG=false
      - ALLOWED_HOSTS=domini.com,www.domini.com
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=myapp
      - REDIS_SESSIONS_URL=redis://redis:6379/0
      - REDIS_CACHE_URL=redis://redis:6379/1
      - CELERY_BROKER_URL=redis://redis:6379/2
      - CELERY_RESULT_BACKEND=redis://redis:6379/3
    secrets:
      - source: secret_key
        target: /run/secrets/SECRET_KEY
      - source: postgres_user
        target: /run/secrets/POSTGRES_USER
      - source: postgres_password
        target: /run/secrets/POSTGRES_PASSWORD
    networks:
      - public
      - backend
    deploy:
      replicas: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.web.rule=Host(`domini.com`) || Host(`www.domini.com`)"
        - "traefik.http.routers.web.entrypoints=https"
        - "traefik.http.services.web.loadbalancer.server.port=8080"
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first  # crea les noves tasques abans d'aturar les antigues
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
```

Diferències entre `limits` i `reservations`:

| Clau           | Funció                                                                                               |
|----------------|------------------------------------------------------------------------------------------------------|
| `limits`       | Màxim que el contenidor pot usar. Si ho supera, Docker el mata (OOM) o el restringeix.               |
| `reservations` | Mínim garantit. Swarm només programa el contenidor a nodes que tinguin aquests recursos disponibles. |

Per tant, a l'exemple anterior:

* Swarm no posarà aquest contenidor a un node que no tingui almenys 0.25 CPU i 128M lliures.
* Un cop en execució, el contenidor pot usar fins a 1 CPU i 512M, però no més.

Les `reservations` són útils per evitar sobrecarregar nodes. Sense elles, Swarm podria programar molts contenidors al mateix node, assumint que tots cabran, fins que els recursos s'esgoten i tot va malament.

**Celery**

Tant el servei dels consumidors de Celery com el servei de Celery Beat usen la mateixa imatge que l'aplicació web Django, només canviant la comanda principal. Ambdós també tenen definits límits de CPU i memòria per evitar que consumeixin tots els recursos del clúster.

```yaml
  # Celery worker
  worker:
    image: myuser/myapp:${VERSION:-latest}
    command: celery -A myapp worker -l info
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=myapp
      - REDIS_SESSIONS_URL=redis://redis:6379/0
      - REDIS_CACHE_URL=redis://redis:6379/1
      - CELERY_BROKER_URL=redis://redis:6379/2
      - CELERY_RESULT_BACKEND=redis://redis:6379/3
    secrets:
      - source: secret_key
        target: /run/secrets/SECRET_KEY
      - source: postgres_user
        target: /run/secrets/POSTGRES_USER
      - source: postgres_password
        target: /run/secrets/POSTGRES_PASSWORD
    networks:
      - backend
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '0.5'
          memory: 256M

  # Celery Beat
  beat:
    image: myuser/myapp:${VERSION:-latest}
    command: celery -A myapp beat -l info
    environment:
      - CELERY_BROKER_URL=redis://redis:6379/2
      - CELERY_RESULT_BACKEND=redis://redis:6379/3
    secrets:
      - source: secret_key
        target: /run/secrets/SECRET_KEY
    networks:
      - backend
    deploy:
      replicas: 1  # Una única rèplica!
      resources:
        limits:
          cpus: '0.25'
          memory: 128M
```

### Comparativa

Acabam aquest bloc amb una taula resum que justifica la separació dels entorns en fitxers distints:

| Aspecte             | `docker-compose.yml`               | `docker-stack.yml`                 |
|:--------------------|:-----------------------------------|:-----------------------------------|
| Imatges             | `build:`                           | `image:` (registre)                |
| Secrets             | Variables d'entorn                 | Docker Secrets                     |
| Codi font           | Muntat amb volum                   | Inclòs a la imatge                 |
| Rèpliques           | Configurable amb `deploy.replicas` | Configurable amb `deploy.replicas` |
| Recursos            | Configurable amb `deploy.resources`| Configurable amb `deploy.resources`|
| Xarxa               | Bridge                             | Overlay                            |
| Traefik             | `swarmMode: false`                 | `swarmMode: true`                  |
| Etiquetes Traefik   | `labels:`                          | `deploy.labels:`                   |
| Publicació de ports | Tots exposats                      | Només exposats els de Traefik      |

## Desplegament

El desplegament de l'Stack amb Docker Swarm passa pels següents passos:

1. Preparar els servidors.
2. Instal·lar Docker.
2. Inicialitzar el clúster.
3. Configuració del clúster.
4. Desplegament de l'Stack.

### Preparació

Assumim que disposam de tres servidors (VPS o dedicats) amb Debian estable i accés per SSH. El sistema operatiu i el servidor SSH ja han estat adequadaments configurats.

| Nom     | Adreça IPv4    | Rol     |
|---------|----------------|---------|
| `node1` | `aaa.bb.cc.10` | Manager |
| `node2` | `aaa.bb.cc.11` | Worker  |
| `node3` | `aaa.bb.cc.12` | Worker  |

Els servidors necessiten tenir connectivitat i accés als següents ports entre ells:

| Port   | Protocol    | Funció                                  |
|:------:|:-----------:|:----------------------------------------|
| `2377` | `TCP`       | Comunicació de gestió del clúster (API) |
| `7946` | `TCP/UDP`   | Descobriment de nodes i gossip protocol |
| `4789` | `UDP`       | Tràfic de xarxa overlay (VXLAN)         |

> Els ports només han d'estar oberts entre els nodes del clúster. Obrir-los a Internet seria un risc de seguretat important.

Si volem filar molt prim, el port 2377 només cal que estigui obert cap als managers, mentre que 7946 i 4789 han d'estar oberts entre tots els nodes.

### Instal·lació

Connectam per SSH a cada servidor i instal·lam Docker:

* Actualitzam el sistema i instal·lam els prerequisits:
  ```bash
  apt update
  apt install --yes ca-certificates curl lsb-release
  ```
* Afegim la clau pública oficial del repositori de Docker:
  ```bash
  install -m 0755 -d /etc/apt/keyrings
  curl --fail --silent --show-error --location \
    https://download.docker.com/linux/debian/gpg \
    --output /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  ```

* Afegim el repositori de Docker usant el format DEB822:
  ```bash
  tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
  Types: deb
  URIs: https://download.docker.com/linux/debian
  Suites: $(lsb_release -cs)
  Components: stable
  Architectures: $(dpkg --print-architecture)
  Signed-By: /etc/apt/keyrings/docker.asc
  EOF   
  ```

* Actualitzam l'índex de paquets i instal·lam Docker:
  ```bash
  apt update
  apt install --yes docker-ce docker-ce-cli containerd.io \
    docker-compose-plugin docker-buildx-plugin
  ```

* Verificam la instal·lació:
  ```bash
  systemctl status docker
  ```

* Si volem gestionar el clúster amb un usuari que no sigui `root`, haurem d'afegir aquest usuari al grup `docker`:
  ```bash
  adduser <usuari> docker
  ```
  Altrament, podem instal·lar `sudo` i prefixar totes les comandes `docker`.

### Inicialització

Des del node que farà la feina de gestor (*manager*), connectats per SSH, inicialitzam el clúster:

```bash
docker swarm init --advertise-addr aaa.bb.cc.10
```

> Per defecte, els nodes manager també actuen com a workers.

La comanda retorna un token i una comanda per unir obrers (*workers*) al clúster. Guardam el token a qualque lloc segur fora del clúster, per exemple una bòveda, i copiam la comanda. Ens connectam als altres dos nodes per SSH i executam la mateixa comanda a ambdós:

```bash
# A node2 i node3, per a unir-se com a workers
docker swarm join --token SWMTKN-1-xxx... aaa.bb.cc.10:2377
```

Verificam l'estat del clúster des del node manager:

```bash
docker node ls
```

La columna `AVAILABILITY` mostra l'estat de cada node.

En un clúster petit, com aquest, és habitual que els tres nodes siguin gestors. Per fer-ho, en comptes d'executar la comanda anterior per a unir-los com a obrers, usarem la comanda alternativa també resultant de la inicialització del clúster per a unir els altres dos nodes al clúster com a managers:

```bash
# A node2 i node3, per a unir-se com a managers
docker swarm join --token SWMTKN-manager-xxx... aaa.bb.cc.10:2377
```

> La recomanació és tenir un nombre senar de managers (3, 5, 7) per garantir quòrum. Amb 3 managers en podem perdre 1, amb 5 en podem perdre 2.

Els desavantatges de que els tres nodes siguin gestors són mínims:

| Aspecte     | Només managers dedicats                     | Tots managers                   |
|-------------|---------------------------------------------|---------------------------------|
| Rendiment   | Managers no consumeixen recursos en tasques | Managers també executen tasques |
| Seguretat   | Menys nodes amb accés al Raft log           | Més nodes amb accés al Raft log |
| Complexitat | Cal més nodes per separar rols              | Més simple                      |

### Etiquetatge

Etiquetarem els nodes per controlar on s'executen els serveis amb dades persistents. Totes les comandes `docker node` s'executen des del manager:

```bash
# Etiquetar els nodes que allotjaran les bases de dades
docker node update --label-add db=true node1
docker node update --label-add cache=true node2
```

En aquest exemple, PostgreSQL s'executarà al `node1` i Redis ho farà al `node2`.

### Secrets

Els secrets es creen des del node manager, abans del primer desplegament. Queden emmagatzemats al clúster i són distribuïts automàticament als nodes que els necessitin a través del *Raft log*. Les següents ordres s'executen al manager, guardant còpia del secret generat en un fitxer del disc:

```bash
# Generar, guardar i crear el SECRET_KEY de Django
SECRET_KEY=$(openssl rand -base64 50 | tr -d '/=+' | cut -c -50)
echo "$SECRET_KEY" >> /root/secret_key_backup.txt  # Guardar a bòveda
echo "$SECRET_KEY" | docker secret create secret_key -

# Generar, guardar i crear les credencials de PostgreSQL
echo "myapp" | docker secret create postgres_user -
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/=+' | cut -c -24)
echo "$POSTGRES_PASSWORD" >> /root/postgres_password_backup.txt  # Guardar a bòveda
echo "$POSTGRES_PASSWORD" | docker secret create postgres_password -
```

> Per defecte, `docker secret create` espera un fitxer, no entrada interactiva.

Verificam els secrets que s'han creat:

```bash
docker secret ls
```

### Desplegar l'stack

El fitxer `docker-stack.yml` ha d'estar present al node manager. Podem copiar-lo via SCP al directori de feina del nostre usuari:

```bash
scp docker-stack.yml root@aaa.bb.cc.10:
```

Des del node manager, ja podem desplegar l'stack amb la darrera versió:

```bash
docker stack deploy -c docker-stack.yml myapp
```

O podem especificar una versió concreta:

```bash
VERSION=1.1.0 docker stack deploy -c docker-stack.yml myapp
```

Alternativament, podem executar comandes remotes des de la màquina local sense connectar per SSH, configurant la variable `DOCKER_HOST`:

```bash
export DOCKER_HOST=ssh://root@aaa.bb.cc.10
docker stack deploy -c docker-stack.yml myapp
```

El nom `myapp` no està prèviament definit enlloc. Es crea en el moment del primer `docker stack deploy`. Aquest nom:

* Identifica l'stack dins el clúster.
* S'usa com a prefix per a tots els recursos: `myapp_web`, `myapp_postgres`, `myapp_public`, etc.
* Permet tenir múltiples stacks al mateix clúster, e.g., `myapp`, `myotherapp`.

Si tornam a executar el mateix deploy, Swarm actualitza l'stack existent en comptes de crear-ne un de nou.

### Verificació

Una vegada fet el desplegament, anem a verificar que tot s'està executant segons teníem previst. Totes les comandes de verificació s'executen des del manager (o via `DOCKER_HOST`):

```bash
# Veure l'estat dels serveis
docker stack services myapp

# Veure les tasques d'un servei concret
docker stack ps myapp

# Veure els logs de l'aplicació web
docker service logs myapp_web

# Veure els logs del worker de Celery
docker service logs myapp_worker
```

## Operacions habituals

Hi ha moltes operacions que, com a part de la gestió diària, s'executen en un clúster. Dins l'àmbit de Docker Swarm, en aquest apartat se'n presenten algunes de les més freqüents:

### Escalar un servei

No necessitam modificar el fitxer `docker-stack.yml`, pujar-lo al node gestor i executar un deploy si només necessitam escalar un servei. Per exemple, pot ser necessitam, temporalment, incrementar el nombre de rèpliques de l'aplicació web i de consumidors de tasques, per accelerar la sortida de tasques pendents:

```bash
docker service scale myapp_web=5
docker service scale myapp_worker=4
```

### Actualitzar l'aplicació

Per desplegar una nova versió de l'aplicació, que haurem prèviament etiquetat amb `git tag` abans de fer el `git push`, simplement necessitam tornar a executar la mateixa comanda de desplegament, especificant la versió de l'aplicació com a variable d'entorn:

```bash
VERSION=1.3.0 docker stack deploy -c docker-stack.yml myapp
```

Swarm farà un rolling update segons la configuració definida a `update_config`.

### Rotar un secret

Els secrets són immutables. Per actualitzar-los cal crear un nou secret i actualitzar el servei. Per tant, seguirem aquests quatre passos:

1. Crear el nou secret.
   ```bash
   POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/=+' | cut -c -24)
   echo "$POSTGRES_PASSWORD" >> /root/postgres_password_v2_backup.txt  # Guardar a bòveda
   echo "$POSTGRES_PASSWORD" | docker secret create postgres_password_v2 -
   ```

2. Actualitzar la contrasenya a PostgreSQL
   ```bash
   docker exec -it $(docker ps -q -f name=myapp_postgres) \
     psql -U myapp -c "ALTER USER myapp WITH PASSWORD '$POSTGRES_PASSWORD';"
   ```

3. Actualitzar els serveis afectats
   ```bash
   docker service update \
     --secret-rm postgres_password \
     --secret-add source=postgres_password_v2,target=/run/secrets/POSTGRES_PASSWORD \
     myapp_web

   docker service update \
     --secret-rm postgres_password \
     --secret-add source=postgres_password_v2,target=/run/secrets/POSTGRES_PASSWORD \
     myapp_worker
   ```

4. Eliminar el secret antic
   ```bash
   docker secret rm postgres_password
   ```

### Veure l'estat

Per a fer un cop d'ull ràpid a l'estat general, podem usar la següent comanda:

```bash
docker stack services myapp
```

Si volem examinar amb més detall l'estat d'un servei concret, podem usar la següent comanda:

```bash
docker service inspect --pretty myapp_web
```

I si volem veure l'historial de tasques, incloent les fallades, podem usar la següent comanda:

```bash
docker service ps --no-trunc myapp_web
```

## Exercici pràctic

L'objectiu d'aquest exercici és desplegar l'aplicació completa en un clúster Docker Swarm.

Requisits:

* Un clúster Docker Swarm amb almanco 2 nodes.
* Un registre d'imatges accessible des del clúster.
* Els fitxers del projecte Django preparats, e.g., [Athletics Sports Club](https://github.com/jsabater/sportsclub/).

Tasques:

1. **Preparar el clúster**:
   * Etiqueta un node amb `db=true` per a PostgreSQL.
   * Etiqueta un altre node amb `cache=true` per a Redis.
   * Verifica que tots els nodes estan actius.

2. **Crear els secrets**:
   * Crea els tres secrets necessaris: `secret_key`, `postgres_user`, `postgres_password`.
   * Verifica que s'han creat amb `docker secret ls`.

3. **Construir i pujar la imatge**:
   * Construeix la imatge de l'aplicació Django. Assegura't de que no hi inclous cap secret.
   * Puja-la al registre d'imatges.

4. **Desplegar l'stack**:
   * Crea el fitxer `docker/traefik/traefik.prod.yml`. No incloguis l'ús de certificats TLS ni de Let's Encrypt si estàs fent l'exercici en un entorn de laboratori sense adreces públiques.
   * Crea el fitxer `docker-stack.yml` amb tots els serveis.
   * Desplega l'stack amb `docker stack deploy`.

5. **Verificar el desplegament**:
   * Comprova que tots els serveis estan en execució.
   * Accedeix a l'aplicació a través de Traefik.
   * Si l'aplicació n'inclou, verifica que les tasques de Celery s'executen.

6. **Operacions**:
   * Escala l'aplicació web a 5 rèpliques.
   * Simula una actualització amb una nova versió de la imatge.
   * Observa el rolling update amb `docker service ps`.

7. **Neteja**:
   * Elimina l'stack amb `docker stack rm myapp`.
   * Elimina els secrets.
   * Elimina els volums si cal.
