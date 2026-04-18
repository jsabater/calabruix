---
title: "Variables d'entorn i configuració"
date: 2026-04-04
lastmod: 2026-04-18
description: "Gestió de la configuració amb variables d'entorn, fitxers .env, directiva env_file i bones pràctiques de seguretat"
summary: "Gestió de la configuració amb variables d'entorn, fitxers .env, directiva env_file i bones pràctiques de seguretat"
categories: ["teaching"]
tags: ["docker", "compose"]
series: ["Docker Compose"]
series_order: 2
weight: 20
slug: variables-entorn
---

A l'article anterior vam veure com definir serveis amb Docker Compose i com passar variables d'entorn directament al fitxer `compose.yaml`. Aquesta aproximació funciona per a exemples senzills, però quan fem feina amb aplicacions reals que requereixen credencials de bases de dades, claus API o configuracions específiques per entorn, necessitam una estratègia més robusta.

Incrustar credencials directament al fitxer de configuració és una pràctica perillosa: si versionam el fitxer amb Git, les credencials quedaran exposades a l'historial del repositori per sempre. A més, fa difícil reutilitzar la mateixa configuració en diferents entorns (desenvolupament, proves, producció) sense haver de modificar el fitxer cada vegada.

Docker Compose ofereix diverses eines per gestionar la configuració de manera segura i flexible: variables d'entorn en línia, fitxers `.env`, la directiva `env_file` i interpolació de variables. En aquest article explorarem cadascuna d'aquestes opcions i les seves aplicacions pràctiques.

## Variables d'entorn inline

La manera més directa de passar variables d'entorn a un contenidor és usant la clau `environment` dins la definició del servei. Aquesta clau accepta dos formats, mapa i llista, ambdós equivalents. Com que el format mapa, o diccionari, es més legible, usarem el format mapa per a tots els exemples d'aquesta sèrie.

Exemple:

```yaml
services:
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: docmost
      POSTGRES_PASSWORD: secretpassword
      POSTGRES_DB: docmost
```

> Les variables definides amb `environment` s'injecten directament al contenidor i estan disponibles per al procés que s'hi executa.

## Fitxers `.env`

Un fitxer `.env` és un fitxer de text pla que conté parells clau-valor, un per línia. Docker Compose carrega automàticament el fitxer `.env` que es trobi al mateix directori que el fitxer `compose.yaml`:

```ini
# Configuració de PostgreSQL
POSTGRES_USER=docmost
POSTGRES_PASSWORD=secretpassword
POSTGRES_DB=docmost

# Configuració de l'aplicació
APP_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
APP_URL=http://localhost:3000
```

La sintaxi dels fitxers `.env` és senzilla:

- Cada línia conté una assignació `CLAU=valor`
- Les línies que comencen amb `#` són comentaris
- Els espais al voltant del `=` no estan permesos
- Els valors poden contenir espais si s'envolten amb cometes dobles
- Les línies buides s'ignoren

**Interpolació de variables**

Un cop definides les variables al fitxer `.env`, podem usar-les dins el `compose.yaml` amb la sintaxi `${VARIABLE}`:

```yaml
services:
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
```

Quan executam `docker compose up`, Compose substitueix `${POSTGRES_USER}` pel valor `docmost` definit al fitxer `.env`, i el mateix amb la resta de variables. Aquesta interpolació és especialment útil per:

- Compartir valors entre múltiples serveis.
- Mantenir les credencials fora del fitxer `compose.yaml`.
- Facilitar el canvi de configuració sense modificar el fitxer principal.

**Valors per defecte**

Podem especificar valors per defecte en cas que una variable no estigui definida:

```yaml
services:
  webapp:
    image: myapp:latest
    environment:
      LOG_LEVEL: ${LOG_LEVEL:-info}
      DEBUG: ${DEBUG:-false}
```

La sintaxi `${VARIABLE:-valor_defecte}` assigna `valor_defecte` si `VARIABLE` no existeix o està buida.

**Especificar un fitxer `.env` diferent**

Per defecte, Compose cerca un fitxer anomenat `.env` al mateix directori on es troba el fitxer `compose.yaml`, però podem especificar un fitxer diferent amb l'opció `--env-file`:

```bash
docker compose --env-file .env.production up --detach
```

Això és útil per mantenir configuracions separades per a diferents entorns:

```
projecte/
├── compose.yaml
├── .env              # Desenvolupament (carregat per defecte)
├── .env.staging      # Proves
└── .env.production   # Producció
```

## Directiva `env_file`

Mentre que el fitxer `.env` s'usa principalment per a la interpolació dins el `compose.yaml`, la directiva `env_file` carrega variables d'entorn directament dins el contenidor:

```yaml
services:
  webapp:
    image: myapp:latest
    env_file:
      - .env.webapp
```

El fitxer `.env.webapp` podria contenir:

```ini
DATABASE_URL=postgresql://user:pass@db:5432/myapp
REDIS_URL=redis://redis:6379
SECRET_KEY=mysupersecretkey
```

Aquestes variables estaran disponibles dins el contenidor però no seran visibles ni interpolables dins el `compose.yaml`.

**Diferència entre .env i env_file**

És important entendre la diferència entre el fitxer `.env` i la directiva `env_file`:

| Característica                      | Fitxer `.env`                    | Directiva `env_file`             |
|-------------------------------------|----------------------------------|----------------------------------|
| Propòsit                            | Interpolació dins `compose.yaml` | Injectar variables al contenidor |
| Carrega automàtica                  | Sí (si es diu `.env`)            | No, cal especificar-ho           |
| Variables visibles a Compose        | Sí                               | No                               |
| Variables disponibles al contenidor | Només si s'interpolen            | Sí, totes                        |

Podem combinar ambdues tècniques:

```yaml
services:
  webapp:
    image: myapp:${APP_VERSION}  # Interpola des de .env
    env_file:
      - .env.webapp              # Carrega al contenidor
    environment:
      APP_URL: ${APP_URL}        # Interpola des de .env
```

## Precedència de variables

Quan una mateixa variable es defineix en múltiples llocs, Docker Compose segueix un ordre de precedència (de major a menor prioritat):

1. Variables d'entorn del sistema operatiu, exportades amb `export` o com a part de la comanda executada.
2. Fitxer especificat amb `--env-file`.
3. Fitxer `.env` al directori actual.
4. Variables definides dins `env_file` al `compose.yaml`.
5. Variables definides dins `environment` al `compose.yaml`.

Aquesta jerarquia permet sobreescriure valors sense modificar els fitxers de configuració. El següent exemple sobreescriu temporalment una variable d'entorn:

```bash
POSTGRES_PASSWORD=noupassword docker compose up --detach
```

## Variables predefinides

Docker Compose predefineix algunes variables que podem usar per personalitzar el comportament:

| Variable               | Descripció                                           |
|------------------------|------------------------------------------------------|
| `COMPOSE_PROJECT_NAME` | Nom del projecte (per defecte, el nom del directori) |
| `COMPOSE_FILE`         | Ruta al fitxer de configuració                       |
| `COMPOSE_PROFILES`     | Perfils actius (els veurem a un article posterior)   |
| `DOCKER_HOST`          | Socket de Docker a usar                              |

Per exemple, per executar el mateix projecte amb un nom diferent:

```bash
COMPOSE_PROJECT_NAME=docmost-prod docker compose up --detach
```

## Exemple pràctic

Posem en pràctica tot el que hem après amb un exemple real amb Docmost, PostgreSQL i Redis. [Docmost](https://docmost.com/) és un wiki col·laboratiu de codi obert que requereix PostgreSQL, Redis i, opcionalment, emmagatzematge S3. Per simplificar, en aquest article usarem emmagatzematge local per als fitxers adjunts.

### Estructura del projecte

```
docmost/
├── compose.yaml
├── .env
├── .env.example
└── .gitignore
```

### Fitxer `.env.example`

El fitxer `.env.example` és un fitxer d'exemple que documentarà les variables necessàries sense contenir valors reals i que podem pujar al nostre repositori Git:

```ini
# Configuració de Docmost
APP_SECRET=genera_amb_openssl_rand_hex_32
APP_URL=http://localhost:3000

# Base de dades PostgreSQL
POSTGRES_USER=docmost
POSTGRES_PASSWORD=canvia_aquest_password
POSTGRES_DB=docmost
```

### Fitxer `.env`

Copiam `.env.example` a `.env` i hi posam els valors reals:

```ini
# Configuració de Docmost
APP_SECRET=7d37d093435a41f2aab8f13c19ba067d9776c90215f56614adad6ece
APP_URL=http://localhost:3000

# Base de dades PostgreSQL
POSTGRES_USER=docmost
POSTGRES_PASSWORD=Xk9mP2vL8nQ4wR7j
POSTGRES_DB=docmost
```

Podem usar OpenSSL per a generar secret aleatoris. La següent comanda genera una cadena de caràcters alfanumèrics, eliminant `/`, `=` i `+` perquè són part de l'alfabet [Base64](https://ca.wikipedia.org/wiki/Base64):

```bash
openssl rand -base64 25 | tr --delete /=+ | cut --characters -32
```

### Fitxer `.gitignore`

Per evitar que les credencials es pugin al repositori Git en assegurarem de que el nostre fitxer `.gitignore` inclogui les següents línies:

```gitignore
.env
!.env.example
```

### Fitxer `compose.yaml`

```yaml
services:
  docmost:
    image: docmost/docmost:latest
    container_name: docmost
    depends_on:
      - db
      - redis
      - garage
    environment:
      APP_URL: ${APP_URL}
      APP_SECRET: ${APP_SECRET}
      DATABASE_URL: "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}"
      REDIS_URL: "redis://redis:6379"
    ports:
      - "3000:3000"
    volumes:
      - docmost-data:/app/data/storage
    restart: unless-stopped

  db:
    image: postgres:18-alpine
    container_name: docmost-db
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    restart: unless-stopped

  redis:
    image: redis:8-alpine
    container_name: docmost-redis
    command: ["redis-server", "--appendonly", "yes", "--maxmemory-policy", "noeviction"]
    volumes:
      - redis-data:/data
    restart: unless-stopped

volumes:
  docmost-data:
  postgres-data:
  redis-data:
```

Observa com:

- Totes les credencials s'interpolen des del fitxer `.env`.
- La variable `DATABASE_URL` es construeix combinant múltiples variables.
- Cada servei té el seu volum per a persistència.

### Arrencar els serveis

Cream el directori de feina:

```bash
mkdir --parents ~/Projects/docmost
cd ~/Projects/docmost
```

Després de crear-hi a dins tots els fitxers especificats en els anteriors apartats, arrenquem els serveis:

```bash
docker compose up --detach
```

## Bones pràctiques

Per concloure, algunes recomanacions per gestionar la configuració de manera segura i mantenible:

**Seguretat:**
- Mai versionis fitxers `.env` amb credencials reals.
- Usa `.env.example` per documentar les variables necessàries.
- Genera secrets aleatoris amb `openssl` o similar.
- Afegeix `.env` al `.gitignore` del projecte.

**Organització:**
- Manté fitxers `.env` separats per entorn, e.g., `.env.production`.
- Documenta cada variable amb comentaris.
- Usa noms de variables descriptius i en majúscules.

**Mantenibilitat:**
- Centralitza les credencials compartides al fitxer `.env`.
- Evita duplicar valors; usa interpolació.
- Revisa periòdicament les credencials i rota-les si escau.

## Exercicis

Es proposen dos exercicis pràctics per facilitar l’aprenentatge progressiu.

### Exercici 1

**Metabase amb variables d'entorn**

En aquest exercici es proposa desplegar [Metabase](https://www.metabase.com/), una eina de *business intelligence*, usant variables d'entorn per a la configuració. Passos:

1. Crea un directori `metabase` al teu directori de projectes.
2. Crea un fitxer `.env` amb les variables necessàries per a PostgreSQL.
3. Crea un fitxer `compose.yaml` amb dos serveis:
   - `metabase` amb la imatge `metabase/metabase:v0.59.x` al port 3000.
   - `db` amb la imatge `postgres:18-alpine`.
4. Configura Metabase per usar PostgreSQL com a base de dades d'aplicació (no la base de dades H2 per defecte). Les variables d'entorn de Metabase són:
   - `MB_DB_TYPE`: Tipus de base de dades (`postgres`).
   - `MB_DB_HOST`: Nom del servei de PostgreSQL.
   - `MB_DB_PORT`: Port de PostgreSQL (5432).
   - `MB_DB_DBNAME`: Nom de la base de dades.
   - `MB_DB_USER`: Usuari de la base de dades.
   - `MB_DB_PASS`: Contrasenya de la base de dades.
5. Arrenca els serveis i accedeix a `http://localhost:3000` per completar la configuració inicial.

> Consulta la [documentació oficial de Metabase](https://www.metabase.com/docs/latest/installation-and-operation/running-metabase-on-docker) per a més informació sobre les variables d'entorn disponibles.

{{< details summary="Respostes" >}}

Crea el directori de feina:

```bash
mkdir --parents ~/Projects/metabase
cd ~/Projects/metabase
```

Crea el fitxer `.env`:

```ini
# PostgreSQL
POSTGRES_USER=metabase
POSTGRES_PASSWORD=<password>
POSTGRES_DB=metabase
```

Crea el fitxer `compose.yaml`:

```yaml
services:
  metabase:
    image: metabase/metabase:v0.59.x
    container_name: metabase
    depends_on:
      - db
    environment:
      MB_DB_TYPE: postgres
      MB_DB_HOST: db
      MB_DB_PORT: 5432
      MB_DB_DBNAME: ${POSTGRES_DB}
      MB_DB_USER: ${POSTGRES_USER}
      MB_DB_PASS: ${POSTGRES_PASSWORD}
    ports:
      - "3000:3000"
    restart: unless-stopped

  db:
    image: postgres:18-alpine
    container_name: metabase-db
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres-data:/var/lib/postgresql
    restart: unless-stopped

volumes:
  postgres-data:
```


Executa Docker Compose:

```bash
docker compose up --detach
```

Accedeix a `http://localhost:3000` i segueix l'assistent de configuració inicial de Metabase.

{{< /details >}}

### Exercici 2

**Vikunja amb env_file**

En aquest exercici es proposa desplegar [Vikunja](https://vikunja.io/), una aplicació de gestió de tasques, usant la directiva `env_file` per organitzar la configuració. Passos:

1. Crea un directori `vikunja` al teu directori de projectes.
2. Crea dos fitxers de configuració:
   - `.env.postgres` amb les variables de PostgreSQL.
   - `.env.vikunja` amb les variables de Vikunja.
3. Crea un fitxer `compose.yaml` amb dos serveis:
   - `vikunja` amb la imatge `vikunja/vikunja` al port 3456.
   - `db` amb la imatge `postgres:18-alpine`.
4. Usa `env_file` per carregar les variables als contenidors corresponents.
5. Les variables de Vikunja més importants són:
   - `VIKUNJA_SERVICE_PUBLICURL`: URL pública de l'aplicació.
   - `VIKUNJA_SERVICE_JWTSECRET`: Secret per als tokens JWT.
   - `VIKUNJA_DATABASE_TYPE`: Tipus de base de dades (`postgres`).
   - `VIKUNJA_DATABASE_HOST`: Nom del servei de PostgreSQL.
   - `VIKUNJA_DATABASE_USER`: Usuari de la base de dades.
   - `VIKUNJA_DATABASE_PASSWORD`: Contrasenya de la base de dades.
   - `VIKUNJA_DATABASE_DATABASE`: Nom de la base de dades.
6. Arrenca els serveis i accedeix a `http://localhost:3456` per crear un compte.

> Consulta la [documentació oficial de Vikunja](https://vikunja.io/docs/config-options/) per a més informació sobre les opcions de configuració.

{{< details summary="Respostes" >}}

Crea el directori de feina:

```bash
mkdir --parents ~/Projects/vikunja
cd ~/Projects/vikunja
```

Crea el fitxer `.env.postgres`:

```ini
POSTGRES_USER=vikunja
POSTGRES_PASSWORD=<password>
POSTGRES_DB=vikunja
```

Crea el fitxer `.env.vikunja`:

```ini
VIKUNJA_SERVICE_PUBLICURL=http://localhost:3456
VIKUNJA_SERVICE_JWTSECRET=<very-long-and-secure-secret>
VIKUNJA_DATABASE_TYPE=postgres
VIKUNJA_DATABASE_HOST=db
VIKUNJA_DATABASE_USER=vikunja
VIKUNJA_DATABASE_PASSWORD=<password>
VIKUNJA_DATABASE_DATABASE=vikunja
```

Crea el fitxer `compose.yaml`:

```yaml
services:
  vikunja:
    image: vikunja/vikunja
    container_name: vikunja
    depends_on:
      - db
    env_file:
      - .env.vikunja
    ports:
      - "3456:3456"
    volumes:
      - vikunja-files:/app/vikunja/files
    restart: unless-stopped

  db:
    image: postgres:18-alpine
    container_name: vikunja-db
    env_file:
      - .env.postgres
    volumes:
      - postgres-data:/var/lib/postgresql
    restart: unless-stopped

volumes:
  vikunja-files:
  postgres-data:
```

Executa Docker Compose:

```bash
docker compose up --detach
```

Accedeix a `http://localhost:3456` i crea un compte d'usuari per començar a usar Vikunja.

{{< /details >}}
