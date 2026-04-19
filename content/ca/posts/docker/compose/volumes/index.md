---
title: "Volums i persistència"
date: 2026-04-04
lastmod: 2026-04-04
description: "Gestió de volums Docker Compose, persistència de dades, bind mounts, còpies de seguretat i restauració"
summary: "Gestió de volums Docker Compose, persistència de dades, bind mounts, còpies de seguretat i restauració"
categories: ["teaching"]
tags: ["docker", "compose"]
series: ["Docker Compose"]
series_order: 4
weight: 40
slug: volums
---

Per defecte, les dades emmagatzemades dins un contenidor són efímeres. Quan el contenidor s'elimina, totes les dades desapareixen amb ell. Això és un problema greu per a aplicacions que necessiten conservar informació: bases de dades, fitxers pujats pels usuaris, configuracions, etc.

Docker resol aquest problema amb els volums, un mecanisme que permet emmagatzemar dades fora del sistema de fitxers del contenidor. En aquest article explorarem els diferents tipus de volums, com gestionar-los amb Docker Compose i les bones pràctiques per garantir la persistència i seguretat de les nostres dades.

## L'efimeritat

Quan arrencam un contenidor, Docker crea una capa de lectura/escriptura sobre la imatge base. Totes les modificacions (fitxers creats, dades guardades, configuracions canviades) s'emmagatzemen en aquesta capa. El problema és que aquesta capa:

- Desapareix quan el contenidor s'elimina: Un `docker compose down` elimina els contenidors i, amb ells, totes les dades.
- No es comparteix entre contenidors: Si volem que dos contenidors accedeixin a les mateixes dades, no ho podem fer amb la capa d'escriptura.
- Té un rendiment limitat: El sistema de fitxers per capes (*overlay filesystem*) és més lent que l'accés directe al disc.

Per evitar aquests problemes, Docker ofereix els volums.

## Tipus de volums

Docker suporta tres tipus principals de volums: temporals, amb nom i *bind mounts*.

### Volums amb nom

Els volums amb nom són gestionats completament per Docker. S'emmagatzemen en un directori especial del sistema (`/var/lib/docker/volumes/` a Linux) i són l'opció recomanada per a la majoria de casos.

```yaml
services:
  db:
    image: postgres:18-alpine
    volumes:
      - postgres-data:/var/lib/postgresql

volumes:
  postgres-data:
```

Avantatges:

- Docker gestiona la ubicació i els permisos automàticament.
- Fàcils de fer backup i restaurar.
- Funcionen igual en qualsevol sistema operatiu.
- Poden ser compartits entre múltiples contenidors.

### Bind mounts

Els bind mounts munten un directori o fitxer de l'amfitrió directament dins el contenidor. Són útils per a desenvolupament o quan necessitem accedir a les dades des de l'amfitrió.

```yaml
services:
  webapp:
    image: nginx:alpine
    volumes:
      - ./src:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

La sintaxi és `<ruta_amfitrió>:<ruta_contenidor>[:opcions]`. Si la ruta de l'amfitrió comença amb `./` o `/`, Docker la interpreta com un bind mount.

Avantatges:

- Accés directe als fitxers des de l'amfitrió.
- Ideal per a desenvolupament (canvis immediats sense reconstruir).
- Útil per muntar fitxers de configuració.

Inconvenients:

- Depèn de l'estructura de directoris de l'amfitrió.
- Problemes de permisos entre l'amfitrió i el contenidor.
- Manco portable entre diferents sistemes.

### Volums tmpfs

Els volums tmpfs emmagatzemen dades a la memòria RAM. Les dades no es persisteixen al disc i desapareixen quan el contenidor s'atura.

```yaml
services:
  webapp:
    image: myapp:latest
    tmpfs:
      - /tmp
      - /var/cache
```

Casos d'ús:

- Dades temporals que no necessiten persistència.
- Informació sensible que no volem escriure al disc.
- Millora del rendiment per a caus temporals.

## Declaració de volums

Docker Compose suporta dues sintaxis per definir volums, curta i llarga. La sintaxi curta és més concisa:

```yaml
services:
  db:
    image: postgres:18-alpine
    volumes:
      - postgres-data:/var/lib/postgresql
      - ./backups:/backups
```

La sintaxi llarga és més explícita i permet més opcions:

```yaml
services:
  db:
    image: postgres:18-alpine
    volumes:
      - type: volume
        source: postgres-data
        target: /var/lib/postgresql
      - type: bind
        source: ./backups
        target: /backups
        read_only: true
```

### Opcions de muntatge

Podem afegir opcions al final de la definició del volum:

- **`:ro`** — Només lectura (*read-only*). El contenidor no pot modificar el contingut.
- **`:rw`** — Lectura i escriptura (per defecte).

```yaml
volumes:
  - ./config:/app/config:ro    # El contenidor només pot llegir
  - data:/app/data:rw          # Lectura i escriptura (per defecte)
```

### Secció `volumes`

Els volums amb nom s'han de declarar a la secció `volumes` del nivell superior, bé en format abreujat:

```yaml
volumes:
  postgres-data:  # Declaració mínima

services:
  db:
    image: postgres:18-alpine
    volumes:
      - postgres-data:/var/lib/postgresql
```

Bé en format llarg:

```yaml
volumes:
  postgres-data:  # Declaració amb opcions
    driver: local
    driver_opts:
      type: none
      device: /srv/postgresql
      o: bind

services:
  db:
    image: postgres:18-alpine
    volumes:
      - postgres-data:/var/lib/postgresql
```

Si no especificam opcions, Docker crea un volum amb la configuració per defecte.

## Cicle de vida dels volums

Els volums amb nom es creen automàticament quan executam `docker compose up`. Però, a diferència dels contenidors, **no s'eliminen** amb `docker compose down`. Si, a més d'aturar i eliminar els contenidors, volem també eliminar els volums, usarem el paràmetre `--volumes`:

```bash
docker compose down --volumes
```

{{< alert >}}
L'opció `--volumes` elimina permanentment les dades. Usa-la amb precaució.
{{< /alert >}}

### Inspecció de volums

Podem llistar i inspeccionar els volums amb les comandes de Docker. Per llistar tots els volums usarem:

```bash
docker volume ls
```

Per inspeccionar un volum concret usarem:

```bash
docker volume inspect metabase_postgres-data
```

I per veure l'espai utilitzat usarem:

```bash
docker system df -v
```

La sortida de `docker volume inspect` mostra informació detallada del volum, com el nom, el tipus de muntatge o la ubicació al disc:

```json
[
  {
    "Name": "metabase_postgres-data",
    "Driver": "local",
    "Mountpoint": "/var/lib/docker/volumes/metabase_postgres-data/_data",
    "Labels": {
      "com.docker.compose.project": "metabase"
    }
  }
]
```

### Volums orfes

Amb el temps, podem acumular volums que ja no estan associats a cap contenidor. Per llistar-los usarem:

```bash
docker volume ls -f dangling=true
```

I per eliminar-los usarem:

```bash
docker volume prune
```

## Exemple pràctic

Posem en pràctica el que hem après amb [Metabase](https://www.metabase.com/), una eina de *business intelligence* que permet crear dashboards i analitzar dades. Metabase necessita una base de dades per emmagatzemar la seva configuració, usuaris i dashboards.

Abans de res, anem a crear el directori de feina:

```bash
mkdir --parents ~/Projects/metabase
cd ~/Projects/metabase
```

### Estructura del projecte

L'estructura necessària per aquest projecte és molt simple:

```
metabase/
├── compose.yaml
└── .env
```

### Fitxer `.env`

```ini
# PostgreSQL
POSTGRES_USER=metabase
POSTGRES_PASSWORD=canvia-aquest-password
POSTGRES_DB=metabase
```

### Fitxer `compose.yaml`

```yaml
services:
  metabase:
    image: metabase/metabase:v0.59.x
    container_name: metabase
    depends_on:
      db:
        condition: service_healthy
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
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres-data:
```

Observa com:

- El servei `db` té un volum amb nom `postgres-data` per persistir les dades de PostgreSQL.
- Metabase usa `depends_on` amb `condition: service_healthy` per esperar que PostgreSQL estigui llest.
- El *healthcheck* de PostgreSQL verifica que la base de dades accepta connexions.

### Arrencada

Usarem la comanda habitual per arrencar els serveis:

```bash
docker compose up --detach
```

Metabase tarda uns minuts en inicialitzar-se la primera vegada. Podem seguir el progrés amb:

```bash
docker compose logs --follow metabase
```

Quan vegem el missatge `Metabase Initialization COMPLETE`, podem accedir a `http://localhost:3000/` i completar la configuració inicial.

### Persistència

Per comprovar que les dades persisteixen, seguim aquests passos:

1. Accedim a Metabase i cream un usuari administrador.
2. Aturam i eliminam els contenidors:

```bash
docker compose down
```

3. Tornam a arrencar els serveis:

```bash
docker compose up --detach
```

4. Accedim a `http://localhost:3000/` i verificam que podem iniciar sessió amb l'usuari creat anteriorment.

Les dades s'han conservat perquè estan emmagatzemades al volum `postgres-data`, que no s'elimina amb `docker compose down`.

### Pèrdua de dades

Ara vegem què passa si eliminam els volums:

```bash
docker compose down --volumes
docker compose up --detach
```

Si accedim a `http://localhost:3000/`, veurem l'assistent de configuració inicial com si fos la primera vegada. Les dades s'han perdut perquè hem eliminat el volum.

## Bones pràctiques

Algunes recomanacions per gestionar volums de manera efectiva en entorns de producció:

**Persistència:**
- Usa sempre volums amb nom per a dades importants (bases de dades, fitxers d'usuari).
- Mai eliminis volums sense estar segur que tens una còpia de seguretat.
- Documenta quins volums conté cada projecte i què emmagatzemen.

**Bind mounts:**
- Reserva els bind mounts per a desenvolupament i fitxers de configuració.
- Usa `:ro` sempre que el contenidor no necessiti escriure.
- Compte amb els permisos: l'usuari del contenidor ha de poder accedir als fitxers.

**Seguretat:**
- Fes còpies de seguretat regulars dels volums amb dades crítiques.
- Revisa periòdicament els volums orfes i elimina'ls.
- Si el volum emmagatzema dades sensibles, avalua usar xifrat al sistema de fitxers de l'amfitrió[^1], o a nivell d'aplicació, si aquesta ho suporta[^2].

[^1]: Per exemple, usant [fscrypt](https://www.kernel.org/doc/html/latest/filesystems/fscrypt.html) per a xifrar fitxers o [LUKS](https://en.wikipedia.org/wiki/Linux_Unified_Key_Setup) per a xifrar el disc.
[^2]: Per exemple, si usam PostgreSQL, usant [Transparent Data Encryption](https://www.postgresql.org/docs/current/transparent-data-encryption.html).

**Organització:**
- Usa noms descriptius per als volums.
- Un volum per a cada tipus de dades (no barregis dades de diferents serveis).

## Exercicis

Es proposen dos exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Còpies de seguretat de PostgreSQL**

En aquest exercici es proposa configurar un sistema de còpies de seguretat per a la base de dades PostgreSQL de Metabase. Passos:

1. Parteix de l'exemple de Metabase de l'article.
2. Crea un directori `backups/` al directori del projecte.
   ```bash
   mkdir --parents ~/Projects/metabase/backups
   ```
3. Modifica el `compose.yaml` per afegir un bind mount que munti el directori `/backups/` dins el contenidor de PostgreSQL.
4. Executa una còpia de seguretat manualment amb `pg_dump`:
   ```bash
   docker exec metabase-db pg_dump --username=metabase \
     --dbname=metabase --format=c \
     --file=/backups/metabase_$(date +%Y%m%d_%H%M%S).pgc
   ```

5. Verifica que el fitxer s'ha creat correctament al directori `backups/`.

> Pista: El bind mount ha de permetre escriptura des del contenidor.

{{< details summary="Respostes" >}}

Crea el directori de backups:

```bash
mkdir --parents ~/Projects/metabase/backups
```

Modifica el fitxer `compose.yaml` per afegir el bind mount al servei `db`:

```yaml
services:
  ...

  db:
    ...
    volumes:
      - postgres-data:/var/lib/postgresql
      - ./backups:/backups

volumes:
  postgres-data:
```

Reinicia els serveis per aplicar els canvis:

```bash
docker compose up --detach
```

Executa la còpia de seguretat:

```bash
docker exec metabase-db pg_dump --username=metabase \
  --dbname=metabase --format=c \
  --file=/backups/metabase_$(date +%Y%m%d_%H%M%S).pgc
```

Verifica que el fitxer s'ha creat:

```bash
ls -lh ~/Projects/metabase/backups/
```

{{< /details >}}

### Exercici 2

**Backup, catàstrofe i restauració**

En aquest exercici es proposa simular una pèrdua total de dades i restaurar el sistema des d'una còpia de seguretat. Passos:

1. Parteix de l'exemple de Metabase amb la còpia de seguretat de l'exercici anterior.
2. Assegura't de que tens una còpia de seguretat recent al directori `~/Projects/metabase/backups/`.
3. Accedeix a Metabase i crea alguna configuració addicional, e.g., afegeix un document usant l'opció `New > Document`, que pots guardar a dins la `Personal collection` del teu usuari.
4. Fes una nova còpia de seguretat amb `pg_dump`.
   ```bash
   docker exec metabase-db pg_dump --username=metabase \
     --dbname=metabase --format=c \
     --file=/backups/metabase_$(date +%Y%m%d_%H%M%S).pgc
   ```
5. Simula una catàstrofe eliminant tots els volums:
   ```bash
   docker compose down --volumes
   ```
6. Arrenca els serveis de nou (es crearà un volum buit):
   ```bash
   docker compose up --detach
   ```
7. Espera que PostgreSQL estigui llest i restaura la còpia de seguretat:
   ```bash
   docker exec metabase-db pg_restore --username=metabase \
     --dbname=metabase --clean --if-exists --jobs=2 \
     /backups/metabase_YYYYMMDD_HHMMSS.pgc
   ```
8. Accedeix a `http://localhost:3000/` i verifica que les dades s'han recuperat.

> En un entorn de producció, les còpies de seguretat s'executen de forma automatitzada, e.g., amb cron job o un servei dedicat, i s'emmagatzemen en un lloc segur fora del servidor, e.g., un bucket d'S3 o un servidor de backups.

{{< details summary="Respostes" >}}

Assegura't que tens l'stack de Metabase funcionant amb dades (usuari creat, configuració inicial completada amb base de dades de prova per defecte de Metabase).

Fes una còpia de seguretat:

```bash
docker exec metabase-db pg_dump --username=metabase \
  --dbname=metabase --format=c \
  --file=/backups/metabase_pre_catastrofe.pgc
```

Verifica que el backup existeix:

```bash
ls -lh ~/Projects/metabase/backups/
```

Simula la catàstrofe:

```bash
docker compose down --volumes
```

Arrenca els serveis amb volums nous (buits):

```bash
docker compose up --detach
```

Espera que PostgreSQL estigui llest (pots verificar-ho amb els logs):

```bash
docker compose logs --follow db
```

Quan vegis `database system is ready to accept connections`, restaura el backup:

```bash
docker exec metabase-db pg_restore --username=metabase \
  --dbname=metabase --clean --if-exists --jobs=2 \
  /backups/metabase_pre_catastrofe.pgc
```

Accedeix a `http://localhost:3000/` i inicia sessió amb les credencials que tenies abans de la catàstrofe. Hauries de veure els documents de prova que vares crear, o configuracions, preguntes i dashboards.

{{< /details >}}
