---
title: "Secrets a Docker Compose"
date: 2026-06-06
lastmod: 2026-06-06
description: "Gestió segura de credencials i secrets: variables d'entorn, patró _FILE i Docker Secrets"
summary: "Gestió segura de credencials amb variables d'entorn, fitxers i Docker Secrets"
categories: ["teaching"]
tags: ["docker", "compose", "secrets", "vault", "security"]
series: ["Docker Compose"]
series_order: 8
weight: 80
slug: "secrets"
---

La gestió de credencials és un dels aspectes més crítics en el desplegament d'aplicacions. Contrasenyes de bases de dades, claus d'API o tokens d'autenticació són dades que necessiten ser protegides adequadament. En aquest article explorarem diferents estratègies per gestionar secrets amb Docker Compose, des de les més senzilles fins a solucions professionals.

La manera més directa de passar credencials als contenidors quan desplegam aplicacions amb Docker Compose seria usar variables d'entorn al fitxer `compose.yaml`:

```yaml
# compose.yaml
services:
  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: super_secret_password
```

Aquesta aproximació té diversos problemes de seguretat:

- Les variables d'entorn són visibles amb `docker inspect` o `docker compose config`.
- Les variables d'entorn poden aparèixer als logs de depuració o d'errors.
- Si el fitxer es versiona, les credencials queden a l'historial de Git.
- Qualsevol procés dins el contenidor pot llegir les variables d'entorn.

Vegem com podem millorar aquesta situació progressivament.

## Fitxer `.env`

El primer pas és moure les credencials fora del `compose.yaml`, a un fitxer `.env`:

```yaml
# compose.yaml
services:
  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

Compose automàticament substituira les variables d'entorn amb el contingut del fitxer `.env`:

```bash
# .env
POSTGRES_USER=myapp
POSTGRES_PASSWORD=super_secret_password
```

Això permet:

- No versionar el fitxer `.env` (afegint-lo al `.gitignore`).
- Tenir diferents credencials per a cada entorn.
- Separar la configuració del codi.

Però les credencials segueixen sent variables d'entorn dins el contenidor, amb els mateixos problemes de visibilitat esmentats anteriorment.

## Patró `_FILE`

Moltes imatges oficials de Docker suporten el patró `_FILE`, que permet llegir el valor d'una variable des d'un fitxer en comptes de passar-lo directament. Això és més segur perquè:

- El secret només existeix com a fitxer dins el contenidor.
- No apareix a `docker inspect`.
- No es propaga a processos fills automàticament.

Les imatges oficials més comunes que suporten aquest patró són:

| Imatge        | Variables amb suport `_FILE`                                         |
|---------------|----------------------------------------------------------------------|
| PostgreSQL    | `POSTGRES_PASSWORD_FILE`, `POSTGRES_USER_FILE`, `POSTGRES_DB_FILE`   |
| MySQL/MariaDB | `MYSQL_ROOT_PASSWORD_FILE`, `MYSQL_PASSWORD_FILE`, `MYSQL_USER_FILE` |
| Redis         | `REDIS_PASSWORD_FILE`                                                |
| MongoDB       | `MONGO_INITDB_ROOT_PASSWORD_FILE`, `MONGO_INITDB_ROOT_USERNAME_FILE` |

**Exemple amb PostgreSQL**

Cream un fitxer amb la contrasenya:

```bash
mkdir -p secrets
echo -n "super_secret_password" > secrets/postgres_password
chmod 600 secrets/postgres_password
```

I configuram el servei per llegir-la:

```yaml
# compose.yaml
services:
  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: myapp
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    volumes:
      - ./secrets/postgres_password:/run/secrets/postgres_password:ro
```

Observem que:

- Muntam el fitxer com a només lectura (`:ro`).
- Usam `/run/secrets/` com a convenció de directori.
- El fitxer conté només la contrasenya, sense salt de línia final (per això usam `echo -n`).

**Aplicació que llegeix secrets de fitxers**

Si la nostra aplicació no suporta el patró `_FILE` de forma nativa, podem implementar-lo nosaltres mateixos. Per exemple, en Python:

```python
import os

def get_secret(name: str) -> str:
    """Llegeix un secret d'una variable d'entorn o d'un fitxer."""
    # Primer, comprova si existeix la variable _FILE
    file_var = f"{name}_FILE"
    if file_path := os.environ.get(file_var):
        with open(file_path, "r") as f:
            return f.read().strip()
    # Si no, retorna la variable directa
    return os.environ.get(name, "")

# Ús
db_password = get_secret("POSTGRES_PASSWORD")
```

## Docker Secrets

Docker Compose té suport natiu per a secrets a través de la directiva `secrets`. Aquesta funcionalitat va ser dissenyada originalment per a Docker Swarm, on els secrets s'emmagatzemen encriptats al clúster i només es desencripten dins els contenidors que els necessiten.

A Docker Compose, els secrets funcionen d'una manera més senzilla: es munten com a fitxers dins els contenidors, però no tenen la mateixa protecció criptogràfica que a Swarm.

### Sintaxi bàsica

```yaml
# compose.yaml
services:
  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: myapp
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/postgres_password
```

Amb aquesta configuració:

- Docker munta el contingut del fitxer a `/run/secrets/db_password` dins el contenidor.
- El fitxer té permisos restrictius (només llegible per l'usuari del procés).
- La sintaxi és més neta que muntar volums manualment.

### Des de variables

També podem definir secrets directament des de l'entorn, útil per a conductes de CI/CD:

```yaml
# compose.yaml
secrets:
  db_password:
    environment: "POSTGRES_PASSWORD"
```

En aquest cas, el valor de la variable d'entorn `POSTGRES_PASSWORD` (de l'entorn on s'executa `docker compose`) es munta com a fitxer dins el contenidor.

### Exemple complet

El següent fitxer `compose.yaml` mostra un exemple complet d'aplicació amb base de dades que utilitza secrets:

```yaml
# compose.yaml
services:
  app:
    image: myapp:latest
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_HOST: db
      DATABASE_NAME: myapp
      DATABASE_USER: myapp
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: myapp
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myapp -d myapp"]
      interval: 5s
      timeout: 5s
      retries: 5

secrets:
  db_password:
    file: ./secrets/postgres_password

volumes:
  postgres-data:
```

### Limitacions

A diferència de Docker Swarm, a Compose *standalone*:

- Els secrets no estan encriptats en repòs (són fitxers normals al sistema de fitxers).
- No hi ha rotació automàtica de secrets.
- No hi ha control d'accés granular (qui pot llegir quin secret).

Per a entorns de producció amb requisits de seguretat elevats, necessitem una solució més robusta com HashiCorp Vault.

## Eines alternatives

Docker Secrets és adequat per a molts projectes, però en entorns empresarials amb requisits de seguretat elevats, existeixen eines especialitzades que ofereixen funcionalitats addicionals:

- **Emmagatzematge segur**: Secrets encriptats en repòs i en trànsit.
- **Control d'accés**: Polítiques granulars sobre qui pot llegir quins secrets.
- **Auditoria**: Registre complet de tots els accessos.
- **Secrets dinàmics**: Generació de credencials temporals amb temps de vida limitat.
- **Rotació automàtica**: Canvi periòdic de credencials sense intervenció manual.

Algunes de les eines de codi obert més populars són:

- [HashiCorp Vault](https://www.vaultproject.io/): L'eina més coneguda i completa, amb suport per a múltiples backends d'emmagatzematge i mètodes d'autenticació. Llicència BSL (Business Source License).
- [OpenBao](https://openbao.org/): Fork comunitari de Vault hostatjat per la [Linux Foundation](https://www.linuxfoundation.org/), amb llicència MPL 2.0 (Mozilla Public License). Manté compatibilitat amb Vault però amb una llicència més permissiva.
- [Infisical](https://infisical.com/): Plataforma moderna sota llicència MIT, dissenyada per ser més senzilla que Vault. Usa PostgreSQL i Redis, té una interfície web intuïtiva i és fàcil de desplegar.

Per a qui prefereixi solucions gestionades al núvol, existeixen també serveis com AWS Secrets Manager, Azure Key Vault i Google Secret Manager, que s'integren amb els seus respectius ecosistemes.

La configuració d'aquestes eines queda fora de l'abast d'aquest curs, però és important conèixer-ne l'existència per a projectes amb requisits de seguretat més exigents.

## Bones pràctiques

Tot seguit es revisen un conjunt de bones pràctiques quant a la gestió de credencials i secrets.

**Mai versionis secrets**

Afegeix sempre al `.gitignore` les entrades necessàries per a evitar que els secrets siguin pujats al repositori:

```
.env
.env.production
.env.*.local
secrets/
*.key
*.pem
```

**Usa valors per defecte segurs**

Quan un secret no està disponible, l'aplicació hauria de fallar de forma segura, no usar un valor per defecte insegur:

```python
# Malament
password = os.environ.get("DB_PASSWORD", "password123")

# Bé
password = os.environ.get("DB_PASSWORD")
if not password:
    raise ValueError("DB_PASSWORD és obligatori")
```

**Principi de mínim privilegi**

Cada servei només hauria de tenir accés als secrets que necessita. Amb Docker Secrets, això s'aconsegueix assignant secrets de forma selectiva:

```yaml
services:
  app:
    secrets:
      - db_password      # Només els secrets necessaris
      - api_key

  db:
    secrets:
      - db_password      # La base de dades no necessita api_key

  worker:
    secrets:
      - api_key          # El worker no necessita db_password
```

D'aquesta manera, si un contenidor es veu compromès, l'atacant només té accés als secrets assignats a aquell servei.

**Rotació de secrets**

Planifica la rotació periòdica de secrets, especialment per a:

- Contrasenyes de bases de dades
- Claus d'API
- Tokens d'accés
- Certificats TLS

**Separació d'entorns**

Usa secrets completament diferents per a cada entorn (desenvolupament, *staging*, producció). Mai reutilitzis credencials entre entorns.


## Exercicis

Es proposen dos exercicis pràctics per facilitar l’aprenentatge progressiu.

### Exercici 1

**Implementar Docker Secrets en un stack complet**

Crea un stack amb NGINX, una aplicació web (usa `nginx:1.30-alpine` com a *placeholder*), PostgreSQL i Redis. Implementa la gestió de secrets seguint les bones pràctiques:

1. Crea els fitxers de secrets necessaris (contrasenya de PostgreSQL i contrasenya de Redis).
2. Configura PostgreSQL per llegir la contrasenya amb `POSTGRES_PASSWORD_FILE`.
3. Configura Redis per llegir la contrasenya d'un fitxer.
4. Assigna a cada servei només els secrets que necessita (principi de mínim privilegi).
5. Afegeix *healthchecks* als serveis de base de dades.

> Pista: Redis no suporta `_FILE` de forma nativa. Pots usar `command: sh -c "redis-server --requirepass $$(cat /run/secrets/redis_password)"`.

> Pista: Per al healthcheck de Redis amb contrasenya, pots usar: `redis-cli -a $$(cat /run/secrets/redis_password) ping`.

{{< details summary="Respostes" >}}

Cream l'estructura del projecte:

```
stack-secrets/
├── compose.yaml
└── secrets/
    ├── db_password
    └── redis_password
```

Cream els fitxers de secrets:

```bash
mkdir --parents secrets
echo -n "postgres_super_secret_2024" > secrets/db_password
echo -n "redis_super_secret_2024" > secrets/redis_password
chmod 600 secrets/*
```

Cream el fitxer `compose.yaml`:

```yaml
services:
  proxy:
    image: nginx:1.30-alpine
    ports:
      - "80:80"
    depends_on:
      app:
        condition: service_started
    restart: unless-stopped

  app:
    image: nginx:alpine
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    secrets:
      - db_password
      - redis_password
    restart: unless-stopped

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_DB: app
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:8.8-alpine
    command: sh -c "redis-server --requirepass $$(cat /run/secrets/redis_password)"
    secrets:
      - redis_password
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a $$(cat /run/secrets/redis_password) ping"]
      interval: 5s
      timeout: 3s
      retries: 3
    restart: unless-stopped

secrets:
  db_password:
    file: ./secrets/db_password
  redis_password:
    file: ./secrets/redis_password

volumes:
  postgres-data:
  redis-data:
```

Observem que:

- `proxy` no té cap secret assignat perquè no en necessita.
- `app` té ambdós secrets perquè es connecta a la base de dades i a Redis.
- `db` només té `db_password`.
- `redis` només té `redis_password`.

Arrencam:

```bash
docker compose up --detach
```

Verificam que PostgreSQL funciona:

```bash
docker compose exec db psql -U app -d app -c "SELECT 1"
```

Verificam que Redis funciona:

```bash
docker compose exec redis redis-cli -a "$(cat secrets/redis_password)" ping
```

{{< /details >}}

### Exercici 2

**Identificar problemes de seguretat**

El següent fitxer `compose.yaml` conté diversos problemes de seguretat relacionats amb la gestió de secrets. Identifica'ls i proposa solucions:

```yaml
services:
  app:
    image: myapp:latest
    environment:
      DATABASE_URL: postgres://admin:admin123@db:5432/myapp
      API_KEY: sk-1234567890abcdef
      DEBUG: "true"
    ports:
      - "3000:3000"

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin123
      POSTGRES_DB: myapp
    ports:
      - "5432:5432"
    volumes:
      - ./data:/var/lib/postgresql

  redis:
    image: redis:8.8-alpine
    ports:
      - "6379:6379"
```

Per a cada problema identificat, explica:

1. Quin és el risc de seguretat.
2. Com es pot solucionar.

{{< details summary="Respostes" >}}

**Problema 1**

Credencials en text pla al `compose.yaml`:

```yaml
environment:
  DATABASE_URL: postgres://admin:admin123@db:5432/myapp
  API_KEY: sk-1234567890abcdef
```

*Risc*: Si el fitxer es versiona a Git, les credencials queden exposades a l'historial. Qualsevol persona amb accés al repositori pot veure-les.

*Solució*: Usar Docker Secrets:

```yaml
services:
  app:
    secrets:
      - db_password
      - api_key
    environment:
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key
```

**Problema 2**

Contrasenya feble i genèrica:

```yaml
POSTGRES_PASSWORD: admin123
```

*Risc*: Contrasenyes febles com "admin123" són fàcils d'endevinar amb atacs de diccionari.

*Solució*: Usar contrasenyes llargues i aleatòries:

```bash
openssl rand -base64 25 | tr --delete /=+ | \
  cut --characters -32 > secrets/db_password
```

**Problema 3**

Port de PostgreSQL exposat a l'amfitrió:

```yaml
ports:
  - "5432:5432"
```

*Risc*: La base de dades és accessible des de qualsevol lloc, no només des dels contenidors. Un atacant podria intentar connectar-s'hi directament.

*Solució*: Eliminar el mapeig de ports. Els serveis dins la xarxa de Docker ja es poden comunicar entre ells sense exposar ports:

```yaml
db:
  image: postgres:18-alpine
  # Sense "ports:" - només accessible internament
```

**Problema 4**

Port de Redis exposat sense autenticació:

```yaml
redis:
  image: redis:8-alpine
  ports:
    - "6379:6379"
```

*Risc*: Redis sense contrasenya i exposat públicament és un dels vectors d'atac més comuns. Un atacant pot accedir a totes les dades o usar-lo per a atacs.

*Solució*: Configurar autenticació i no exposar el port:

```yaml
redis:
  image: redis:8-alpine
  command: sh -c "redis-server --requirepass $$(cat /run/secrets/redis_password)"
  secrets:
    - redis_password
  # Sense "ports:" - només accessible internament
```

**Problema 5**

Mode `DEBUG` activat:

```yaml
DEBUG: "true"
```

*Risc*: En mode debug, les aplicacions sovint mostren informació sensible en els missatges d'error (traces, variables d'entorn, rutes de fitxers).

*Solució*: Mai activar DEBUG en producció. Usar variables d'entorn per controlar-ho:

```yaml
environment:
  DEBUG: ${DEBUG:-false}
```

**Problema 6**

Volum amb ruta relativa:

```yaml
volumes:
  - ./data:/var/lib/postgresql
```

*Risc*: Les dades de la base de dades es guarden en un directori local que podria ser accessible per altres usuaris del sistema o ser versionat accidentalment.

*Solució*: Usar volums amb nom gestionats per Docker:

```yaml
volumes:
  - postgres-data:/var/lib/postgresql

volumes:
  postgres-data:
```

**Fitxer corregit**

```yaml
services:
  app:
    image: myapp:latest
    environment:
      DATABASE_HOST: db
      DATABASE_NAME: myapp
      DATABASE_USER: app
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key
      DEBUG: ${DEBUG:-false}
    secrets:
      - db_password
      - api_key
    ports:
      - "3000:3000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  db:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d myapp"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:8.8-alpine
    command: sh -c "redis-server --requirepass $$(cat /run/secrets/redis_password)"
    secrets:
      - redis_password
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD-SHELL", "redis-cli -a $$(cat /run/secrets/redis_password) ping"]
      interval: 5s
      timeout: 3s
      retries: 3

secrets:
  db_password:
    file: ./secrets/db_password
  api_key:
    file: ./secrets/api_key
  redis_password:
    file: ./secrets/redis_password

volumes:
  postgres-data:
  redis-data:
```

{{< /details >}}
