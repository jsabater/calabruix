---
title: "Dockerfiles i construcció d'imatges"
date: 2026-03-31
lastmod: 2026-03-31
description: "Creació d'imatges personalitzades amb Dockerfile, instruccions, optimització i multi-stage builds"
summary: "Creació d'imatges personalitzades amb Dockerfile, instruccions, optimització i multi-stage builds"
categories: ["teaching"]
tags: ["docker", "engine", "dockerfile", "containers", "python", "django"]
series: ["Docker Engine"]
series_order: 5
weight: 50
slug: dockerfiles
---

Fins ara hem fet feina amb imatges existents de Docker Hub. En aquest article aprendrem a crear les nostres pròpies imatges personalitzades mitjançant **Dockerfiles**, fitxers de text que contenen les instruccions per construir una imatge.

## Què és un Dockerfile

Un `Dockerfile` és un fitxer de text que conté un conjunt d'instruccions per construir una imatge Docker. Actua com una recepta que especifica tot el necessari per muntar la imatge: el sistema operatiu base, les dependències, les variables d'entorn, la configuració de xarxa i el codi de l'aplicació.

En automatitzar el procés de creació d'imatges, els Dockerfiles garanteixen la **consistència** entre diferents entorns, des del desenvolupament fins a producció.

## Primera imatge

Comencem amb un exemple senzill. Crearem una imatge de PostgreSQL que inclogui un script d'inicialització. Comencem creant el següent fitxer `Dockerfile`:

```dockerfile
FROM postgres:18-alpine

COPY init.sql /docker-entrypoint-initdb.d/
```

El fitxer `init.sql` estaria al mateix directori que el `Dockerfile`:

```sql
-- init.sql
CREATE TABLE IF NOT EXISTS producte (
  id SERIAL PRIMARY KEY,
  nom VARCHAR(100) NOT NULL,
  preu DECIMAL(10,2)
);

INSERT INTO producte (nom, preu)
VALUES ('Teclat mecànic', 89.99),
       ('Ratolí ergonòmic', 45.50),
       ('Monitor 27 polzades', 299.00);
```

Per construir la imatge, usem la comanda `docker build`:

```bash
docker build --tag mypg:1.0 .
```

| Opció            | Descripció                                   |
|------------------|----------------------------------------------|
| `--tag mypg:1.0` | Assigna un nom i etiqueta a la imatge        |
| `.`              | El context de construcció (directori actual) |

Un cop construïda, podem veure la imatge amb `docker images` i executar-la:

```bash
docker run --name pg-custom \
  --env POSTGRES_PASSWORD=secret \
  --env POSTGRES_USER=demo \
  --env POSTGRES_DB=demo \
  --detach \
  mypg:1.0
```

{{< alert >}}
Els fitxers SQL dins de `/docker-entrypoint-initdb.d/` s'executen automàticament la primera vegada que s'inicia el contenidor. Aquesta és una funcionalitat específica de la imatge oficial de PostgreSQL.
{{< /alert >}}

## Instruccions

Un Dockerfile consisteix en una sèrie d'instruccions, cadascuna amb un propòsit específic. Les instruccions s'executen en ordre i cada una crea una nova **capa** a la imatge.

**FROM**

Especifica la imatge base sobre la qual construirem. Ha de ser la primera instrucció del Dockerfile (excepte comentaris i `ARG`).

```dockerfile
FROM python:3.13-slim
```

Podem usar `AS` per donar nom a una etapa (útil per a multi-stage builds):

```dockerfile
FROM python:3.13-slim AS builder
```

**RUN**

Executa comandes durant la construcció de la imatge. Cada `RUN` crea una nova capa.

```dockerfile
# Nota: En entorns de producció, es recomana fixar les versions dels paquets
# (e.g., curl=8.14.1-2+deb13u2) per garantir builds reproduïbles.
# Aquí ometem la versió per simplicitat i per evitar que l'exemple quedi obsolet.
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

{{< alert >}}
És bona pràctica combinar múltiples comandes en un sol `RUN` usant `&&` per reduir el nombre de capes i la mida de la imatge.
{{< /alert >}}

**COPY i ADD**

`COPY` copia fitxers i directoris des del context de construcció a la imatge:

```dockerfile
COPY requirements.txt /app/
COPY src/ /app/src/
```

`ADD` és similar però té funcionalitats addicionals: pot extreure arxius comprimits i descarregar fitxers d'URLs:

```dockerfile
ADD config.tar.gz /app/config/
```

En general, es recomana usar `COPY` llevat que necessitem les funcionalitats específiques d'`ADD`.

**WORKDIR**

Estableix el directori de feina per a les instruccions posteriors (`RUN`, `CMD`, `ENTRYPOINT`, `COPY`, `ADD`):

```dockerfile
WORKDIR /app
```

Si el directori no existeix, Docker el crea automàticament. És preferible usar `WORKDIR` en lloc de `RUN cd /app`.

**ENV**

Defineix variables d'entorn que estaran disponibles durant la construcció i l'execució del contenidor:

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
```

**ARG**

Defineix variables que només estan disponibles durant la construcció (no en temps d'execució):

```dockerfile
ARG PYTHON_VERSION=3.13
FROM python:${PYTHON_VERSION}-slim
```

Les podem passar en temps de construcció:

```bash
docker build --build-arg PYTHON_VERSION=3.14 --tag myapp:latest .
```

**EXPOSE**

Documenta quins ports utilitza el contenidor. No publica el port, sinó que és informatiu:

```dockerfile
EXPOSE 8000
```

Per publicar el port, hem d'usar `--publish` en executar el contenidor.

**USER**

Canvia l'usuari per a les instruccions posteriors i per a l'execució del contenidor:

```dockerfile
RUN useradd --no-create-home appuser
USER appuser
```

> Executar com a usuari no privilegiat és una bona pràctica de seguretat.

**CMD i ENTRYPOINT**

Ambdues instruccions defineixen què s'executa quan el contenidor s'inicia, però tenen comportaments diferents.

`CMD` especifica la comanda d'inici o per defecte. Es pot sobreescriure passant arguments a `docker run`:

```dockerfile
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

`ENTRYPOINT` defineix l'executable principal del contenidor. Els arguments de `docker run` s'afegeixen a l'entrypoint:

```dockerfile
ENTRYPOINT ["python", "manage.py"]
CMD ["runserver", "0.0.0.0:8000"]
```

Amb aquesta configuració:
- `docker run myapp` executa `python manage.py runserver 0.0.0.0:8000`
- `docker run myapp migrate` executa `python manage.py migrate`

**HEALTHCHECK**

Defineix una comanda per comprovar si el contenidor funciona correctament:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl --fail http://localhost:8000/health/ || exit 1
```

| Opció            | Descripció                                                               |
|------------------|--------------------------------------------------------------------------|
| `--interval`     | Temps entre comprovacions                                                |
| `--timeout`      | Temps màxim d'espera per a la resposta                                   |
| `--start-period` | Temps d'espera inicial abans de començar les comprovacions               |
| `--retries`      | Nombre d'intents fallits abans de marcar el contenidor com a *unhealthy* |

**LABEL**

Afegeix metadades a la imatge:

```dockerfile
LABEL maintainer="jaume@example.com"
LABEL version="1.0"
LABEL description="Aplicació Django amb Ninja API"
```

## Excloure fitxers

El fitxer `.dockerignore` funciona de manera similar a `.gitignore`: especifica quins fitxers i directoris s'han d'excloure del context de construcció. Exemple:

```text
# .dockerignore
.git
.gitignore
.env
*.pyc
__pycache__
.pytest_cache
.mypy_cache
venv
.venv
*.md
!README.md
docker-compose*.yml
Dockerfile*
```

Excloure fitxers innecessaris:

- Redueix la mida del context enviat al daemon Docker.
- Accelera la construcció.
- Evita copiar fitxers sensibles (com `.env` amb secrets).

## Capes i cache

Cada instrucció del Dockerfile crea una **capa** a la imatge. Docker manté una cache d'aquestes capes i les reutilitza si no han canviat:

```
Step 1/7 : FROM python:3.13-slim
 ---> Using cache
Step 2/7 : WORKDIR /app
 ---> Using cache
Step 3/7 : COPY requirements.txt .
 ---> Using cache
Step 4/7 : RUN pip install -r requirements.txt
 ---> Using cache
Step 5/7 : COPY src/ /app/
 ---> 7a8b9c0d1e2f   # Nova capa (el codi ha canviat)
```

Per aprofitar la cache, hem d'ordenar les instruccions de manco a més propenses a canviar:

1. Instruccions base, e.g., `FROM`, `WORKDIR`.
2. Dependències, e.g., `COPY requirements.txt`, `RUN pip install`.
3. Codi de l'aplicació, e.g., `COPY src/ /app/`.

Si copiam tot el codi abans d'instal·lar les dependències, qualsevol canvi al codi invalidaria la cache de les dependències.

## Exemple complet

Per posar en pràctica tot el que hem après, construirem una imatge per a una aplicació web real: una API REST amb [Django Ninja](https://django-ninja.dev/) servida amb [Uvicorn](https://www.uvicorn.org/).

Django Ninja és un framework per construir APIs REST amb Django, inspirat en FastAPI. Utilitza *type hints* de Python per validar dades automàticament i genera documentació interactiva ([Swagger](https://swagger.io/)/[OpenAPI](https://swagger.io/specification/)) sense configuració addicional. Uvicorn és un servidor ASGI lleuger i ràpid, ideal per servir aplicacions Django modernes.

### Preparació

{{< icon "download" >}} Descarrega [l'arxiu de l'aplicació d'exemple](/docker/engine/dockerfiles/myapi.tar.gz) al teu directori de projectes, e.g., `~/Projects`. Un pic descarregat, extreu-lo i accedeix al directori:

```bash
cd ~/Projects
tar --extract --gzip --file myapi.tar.gz
cd myapi
```

L'estructura del projecte és la següent:

```
myapi/
├── Dockerfile          # Instruccions per construir la imatge
├── .dockerignore       # Fitxers a excloure durant la construcció
├── requirements.txt    # Dependències de Python
├── manage.py           # CLI de Django
└── myapi/
    ├── __init__.py     # Marca el directori com a paquet Python
    ├── api.py          # Definició dels endpoints de l'API
    ├── asgi.py         # Punt d'entrada per a Uvicorn
    ├── settings.py     # Configuració de Django
    └── urls.py         # Configuració de rutes URL
```

### Requirements

Les dependències de l'aplicació són mínimes:

```text
django==5.2
django-ninja==1.4
uvicorn==0.34
```

### L'API

El cor de l'aplicació és el fitxer `api.py`, on definim els endpoints:

```python
from ninja import NinjaAPI

api = NinjaAPI()


@api.get("/health")
def health(request):
    """Endpoint per comprovar l'estat del servei."""
    return {"status": "ok"}


@api.get("/hello")
def hello(request):
    """Endpoint de prova que retorna un missatge de salutació."""
    return {"message": "Hola des de Django Ninja!"}
```

Amb Django Ninja, cada endpoint es defineix amb un decorador (`@api.get`, `@api.post`, etc.) i una funció que rep la petició i retorna la resposta. El framework s'encarrega de serialitzar el diccionari Python a JSON automàticament.

### Les rutes

Per connectar l'API a Django, només cal una línia a `urls.py`:

```python
from django.urls import path

from .api import api

urlpatterns = [
    path("api/", api.urls),
]
```

Tots els endpoints definits a `api.py` estaran disponibles sota el prefix `/api/`.

### El fitxer .dockerignore

Abans de veure el Dockerfile, és important configurar `.dockerignore` per excloure fitxers innecessaris:

```text
# Git
.git
.gitignore

# Python
*.pyc
__pycache__
.pytest_cache

# Entorns virtuals
.venv
.env

# IDE
.vscode

# Docker
Dockerfile*

# Documentació
*.md
```

### El Dockerfile

Finalment, el Dockerfile que ho uneix tot:

```dockerfile
FROM python:3.13-slim

# Evitar que Python escrigui fitxers .pyc
ENV PYTHONDONTWRITEBYTECODE=1

# Evitar que Python usi un buffer de sortida i poder, així, veure els logs en temps real
ENV PYTHONUNBUFFERED=1

# Crear directori de treball
WORKDIR /app

# Instal·lar dependències del sistema
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copiar i instal·lar dependències de Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Crear usuari de sistema sense directori de treball ni shell
RUN useradd --system --no-create-home \
    --shell /usr/sbin/nologin appuser

# Copiar el codi de l'aplicació
COPY --chown=appuser:appuser . .

# Canviar a usuari no privilegiat
USER appuser

# Documentar el port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
            --start-period=5s --retries=3 \
  CMD curl --fail http://localhost:8000/api/health || exit 1

# Comanda per defecte usant exec form per permetre que els senyals,
# e.g., `SIGTERM`, arribin directament a l'aplicació, i.e., `uvicorn`.
CMD ["uvicorn", "myapi.asgi:application", "--host", "0.0.0.0", "--port", "8000"]
```

> En entorns de producció, es recomana fixar les versions dels paquets, e.g., `curl=8.14.1-2+deb13u2`, per garantir builds reproduïbles. Al `Dockerfile` anterior ometem la versió per simplicitat i per evitar que l'exemple quedi aviat obsolet.

Observa com aprofitam la cache de Docker: primer copiam el fitxer `requirements.txt` i instal·lam les dependències, i després copiam el codi de l'aplicació. D'aquesta manera, si només canviam el codi, Docker reutilitzarà la capa de les dependències.

### Construcció i execució

Construïm la imatge:

```bash
docker build --tag myapi:1.0 .
```

Executam el contenidor:

```bash
docker run --name myapi --publish 8000:8000 --detach myapi:1.0
```

Provam l'endpoint `/api/health`:

```bash
curl http://localhost:8000/api/health
```

Hauríem d'obtenir la següent sortida:

```json
{"status": "ok"}
```

Provam l'endpoint `/api/hello`:

```bash
curl http://localhost:8000/api/hello
```

Hauríem d'obtenir la següent sortida:

```json
{"message": "Hola des de Django Ninja!"}
```

### Documentació

Django Ninja genera documentació interactiva de l'API automàticament. Amb el contenidor en execució, accedim a:

- Swagger UI: http://localhost:8000/api/docs
- ReDoc: http://localhost:8000/api/redoc

**Swagger UI** és una interfície interactiva que permet explorar i provar els endpoints de l'API directament des del navegador. Podem veure els paràmetres que accepta cada endpoint, executar peticions i inspeccionar les respostes, tot sense necessitat d'usar `curl` o eines externes.

**ReDoc** és una alternativa de només lectura, amb un disseny net i orientat a la documentació. És ideal per compartir amb altres desenvolupadors o per consultar l'especificació de l'API sense la part interactiva.

Ambdues interfícies es generen a partir de l'especificació OpenAPI que Django Ninja crea automàticament, basant-se en els endpoints i els *type hints* de les funcions. No cal cap configuració addicional.

### Neteja

Per aturar i eliminar el contenidor:

```bash
docker rm --force myapi
```

## Multi-stage builds

Els **multi-stage builds** permeten usar múltiples instruccions `FROM` en un sol Dockerfile. Cada `FROM` inicia una nova etapa de construcció i podem copiar artefactes d'una etapa a una altra. Això és especialment útil per:

- Reduir la mida de la imatge final, car les eines de construcció no s'inclouen a la imatge de producció.
- Separar les fases de construcció i execució.
- Millorar la seguretat, car manco eines a la imatge final significa menor superfície d'atac.

### Exemple amb Go

Un cas clàssic és una aplicació Go, on el compilador no és necessari en temps d'execució.

Go (també conegut com Golang) és un llenguatge de programació compilat, desenvolupat per Google. A diferència de Python o JavaScript, que s'interpreten en temps d'execució, Go compila el codi font a un **binari executable natiu** que s'executa directament sobre el sistema operatiu, sense necessitat d'intèrpret ni màquina virtual.

Aquest binari és **autocontingut**: inclou tot el necessari per executar-se, sense dependències externes. Això fa que les aplicacions Go siguin ideals per a contenidors, ja que la imatge final pot ser extremadament petita.

El compilador de Go, però, ocupa centenars de megabytes. No té sentit incloure'l a la imatge de producció, on només necessitem el binari resultant. Els multi-stage builds resolen aquest problema: una primera etapa compila el codi amb el SDK de Go i una segona etapa copia només el binari a una imatge mínima com Alpine.

```dockerfile
# Etapa 1: Construcció
FROM golang:1.26-alpine3.23 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server .

# Etapa 2: Imatge final
FROM alpine:3.23
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /app/server .
USER nobody
EXPOSE 8080
CMD ["./server"]
```

La imatge final només conté el binari compilat i Alpine, sense el compilador de Go.

### Exemple amb Django

En aplicacions web modernes, és habitual separar el backend, e.g., fet amb [Django](https://www.djangoproject.com/), del frontend, e.g., fet amb [React](https://reactjs.org/) o [Vue](https://vuejs.org/). El frontend es desenvolupa amb eines de l'ecosistema [Node.js](https://nodejs.org/) i es compila a fitxers estàtics (HTML, JavaScript i CSS) que Django serveix en producció.

Aquest procés de compilació requereix Node.js i pot generar un directori `node_modules` molt gran. No té sentit incloure tot això a la imatge final, que només necessita Python i els fitxers ja compilats.

Els multi-stage builds resolen aquest problema: una primera etapa amb Node.js compila el frontend, i una segona etapa amb Python copia només els fitxers resultants. La imatge final és lleugera i conté exactament el que necessita per executar-se.

```dockerfile
# Etapa 1: Compilar assets amb Node.js
FROM node:25.9-alpine23.3 AS assets
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY frontend/ ./frontend/
RUN npm run build

# Etapa 2: Imatge Python per a producció
FROM python:3.13-slim AS production

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Dependències del sistema
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Dependències de Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar assets compilats de l'etapa anterior
COPY --from=assets /app/static/dist ./static/dist

# Copiar codi de l'aplicació
COPY . .

# Usuari no privilegiat
RUN useradd --create-home appuser
USER appuser

EXPOSE 8000

CMD ["uvicorn", "myapi.asgi:application", "--host", "0.0.0.0", "--port", "8000"]
```

La imatge final no inclou Node.js ni les dependències de desenvolupament del frontend.

## Bones pràctiques

Les imatges Docker que construïm tenen un impacte directe en la seguretat, el rendiment i la mantenibilitat de les nostres aplicacions. Una imatge mal construïda pot ser innecessàriament gran, vulnerable a atacs o difícil de depurar quan sorgeixen problemes.

Les següents pràctiques provenen de l'experiència acumulada de la comunitat i les recomanacions oficials de Docker. No són regles rígides, però seguir-les ens estalviarà problemes a llarg termini.

**Usar imatges base oficials i específiques**

Hem d'usar `python:3.13-slim` en lloc de `python:latest`. L'etiqueta `latest` canvia amb el temps, i el que funciona avui pot fallar demà quan es publiqui una nova versió. Especificar la versió garanteix builds reproduïbles: qualsevol persona que construeixi la imatge obtindrà el mateix resultat.

**Minimitzar el nombre de capes**

Cada instrucció `RUN`, `COPY` i `ADD` crea una nova capa a la imatge. Combinar comandes relacionades en un sol `RUN` redueix el nombre de capes i la mida final. Per exemple, instal·lar paquets i netejar la cache en la mateixa instrucció evita que la cache quedi "atrapada" en una capa intermèdia.

**Aprofitar la cache de construcció**

Docker guarda en cache cada capa i la reutilitza si no ha canviat. Hem d'ordenar les instruccions de manco a més propenses a canviar: primer les dependències del sistema, després les dependències de l'aplicació i, finalment, el codi font. D'aquesta manera, un canvi al codi no invalida la cache de les dependències.

**No executar com a root**

Per defecte, els processos dins d'un contenidor s'executen com a `root`. Si un atacant aconsegueix explotar una vulnerabilitat de l'aplicació, tendrà privilegis de `root` dins del contenidor, facilitant una possible escapada cap a l'amfitrió. Crear un usuari de sistema sense privilegis i usar la instrucció `USER` mitiga aquest risc.

**Usar `.dockerignore`**

El context de construcció és tot el que Docker envia al daemon per construir la imatge. Sense un fitxer `.dockerignore`, Docker envia tot el directori, incloent `.git`, entorns virtuals, i fitxers temporals. Això alenteix la construcció i pot filtrar informació sensible a la imatge.

**Netejar després d'instal·lar**

Les eines de gestió de paquets mantenen caus per accelerar futures instal·lacions. Dins d'un contenidor, aquestes caus són inútils i ocupen espai. Eliminar-les a la mateixa instrucció `RUN` on instal·lem els paquets redueix la mida de la imatge.

**Usar multi-stage builds**

Separar la construcció de l'execució permet tenir imatges finals lleugeres. Les eines de compilació, els fitxers font intermedis i les dependències de desenvolupament es queden a l'etapa de construcció i no s'inclouen a la imatge de producció.

**Documentar amb LABEL**

Les etiquetes (`LABEL`) afegeixen metadades a la imatge: autor, versió, descripció, URL del repositori. Aquesta informació és útil per a la gestió d'imatges i l'automatització de pipelines CI/CD.

**Definir HEALTHCHECK**

Sense un `HEALTHCHECK`, Docker només sap si el procés principal està en execució, però no si l'aplicació funciona correctament. Un procés pot estar viu però bloquejat o en un estat inconsistent. El *health check* permet a Docker detectar aquests casos i actuar en conseqüència, e.g., reiniciar el contenidor, treure'l del balancejador de càrrega, etc.

**Especificar versions de les dependències**

Tant la imatge base com els paquets del sistema i les dependències de l'aplicació han de tenir versions explícites. Això garanteix que la imatge es pugui reconstruir de manera idèntica en el futur i facilita l'auditoria de seguretat.

## Convenció estilística

No existeix un estàndard oficial per ordenar les instruccions d'un Dockerfile, però amb el temps la comunitat ha anat adoptant una convenció que facilita la lectura i el manteniment. Aquesta convenció prové principalment de les [recomanacions de bones pràctiques de Docker](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) i de l'experiència compartida en projectes de codi obert.

La idea és organitzar les instruccions en tres blocs lògics: primer la configuració base (què és aquesta imatge), després la construcció (què conté) i, finalment, l'execució (com s'inicia).

| Ordre | Instrucció           | Descripció                                               |
|:-----:|----------------------|----------------------------------------------------------|
| 1     | `FROM`               | Imatge base sobre la qual construïm                      |
| 2     | `LABEL`              | Metadades: autor, versió, descripció                     |
| 3     | `ARG`                | Variables disponibles només durant la construcció        |
| 4     | `ENV`                | Variables d'entorn disponibles en construcció i execució |
| 5     | `WORKDIR`            | Directori de treball per a les instruccions següents     |
| 6     | `RUN`                | Instal·lació de paquets i configuració del sistema       |
| 7     | `COPY` / `ADD`       | Codi de l'aplicació i fitxers necessaris                 |
| 8     | `USER`               | Usuari amb què s'executarà el contenidor                 |
| 9     | `EXPOSE`             | Ports que el contenidor utilitza (informatiu)            |
| 10    | `HEALTHCHECK`        | Comanda per verificar l'estat del servei                 |
| 11    | `CMD` / `ENTRYPOINT` | Comanda que s'executa en iniciar el contenidor           |

Aquesta ordenació també té un benefici pràctic: les instruccions que canvien amb manco freqüència (imatge base, dependències del sistema) es troben a dalt, mentre que les que canvien més sovint (codi de l'aplicació, configuració d'execució) es troben a baix. Això maximitza l'aprofitament de la cache de Docker.

Cal tenir en compte que és una convenció, no una obligació. Docker processarà les instruccions correctament independentment de l'ordre (amb l'excepció de `FROM`, que ha de ser la primera). Tanmateix, seguir aquesta estructura fa que els Dockerfiles siguin més fàcils de llegir i mantenir, especialment en equips on múltiples persones hi fan feina.

## Comandes útils

En aquest apartat pots trobar un llistat de les comandes utilitzades per construir i gestionar imatges, a mode de resum del que hem vist en aquest article.

| Comanda                                 | Descripció                        |
|-----------------------------------------|-----------------------------------|
| `docker build --tag nom:etiqueta .`     | Construir una imatge              |
| `docker build --no-cache .`             | Construir sense cache             |
| `docker build --file Dockerfile.prod .` | Usar un Dockerfile diferent       |
| `docker history nom:etiqueta`           | Veure les capes d'una imatge      |
| `docker image inspect nom:etiqueta`     | Informació detallada de la imatge |
| `docker image prune`                    | Eliminar imatges no utilitzades   |

## Exercicis pràctics

Es proposen dos exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Imatge personalitzada de Nginx**

1. Crea un directori de projecte amb un fitxer `index.html` personalitzat i un fitxer `nginx.conf` amb una configuració bàsica.
2. Escriu un Dockerfile que:
   - Parteixi de `nginx:alpine`
   - Copiï el fitxer HTML al directori corresponent
   - Copiï la configuració personalitzada
   - Defineixi un `HEALTHCHECK`
   - Inclogui senglars etiquetes `LABEL` amb el teu nom i la data
3. Construeix la imatge amb el tag `mynginx:1.0`.
4. Executa un contenidor i verifica que serveix el contingut personalitzat.
5. Usa `docker history` per veure les capes de la imatge.

### Exercici 2

**Multi-stage build amb aplicació Java**

1. Crea una aplicació Java mínima (un "Hello World" que s'executi contínuament mostrant l'hora cada 5 segons).
2. Escriu un Dockerfile multi-stage que:
   - Etapa 1: Usi `maven:3.9-eclipse-temurin-21` per compilar l'aplicació
   - Etapa 2: Usi `eclipse-temurin:21-jre-alpine` per executar-la
3. Construeix la imatge i compara la mida amb una imatge que inclogui tot el JDK.
4. Executa el contenidor i verifica que funciona correctament.
5. Comprova els logs amb `docker logs --follow`.

> Pista: Consulta la documentació de Maven per a l'estructura bàsica d'un projecte Java.
