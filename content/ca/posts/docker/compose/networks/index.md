---
title: "Xarxes i comunicació"
date: 2026-04-14
lastmod: 2026-04-14
description: "Configuració de xarxes Docker Compose, aïllament frontend/backend, resolució DNS i comunicació entre serveis"
summary: "Configuració de xarxes Docker Compose, aïllament frontend/backend, resolució DNS i comunicació entre serveis"
categories: ["teaching"]
tags: ["docker", "compose"]
series: ["Docker Compose"]
series_order: 30
weight: 30
slug: xarxes
---

Quan desplegam aplicacions amb múltiples serveis, la comunicació entre ells és fonamental: l'aplicació ha de poder connectar-se a la base de dades i a la memòria cau, el proxy invers ha de poder connectar-se a l'aplicació i, potser, un servei d'administració necessita connectar-se a diversos backends.

Al mateix temps, sovint volem aïllar certs serveis perquè no siguin accessibles des d'altres parts de l'aplicació o des de l'exterior.

Docker Compose simplifica la gestió de xarxes creant automàticament una xarxa compartida per a tots els serveis d'un projecte i permetent-nos definir xarxes personalitzades quan necessitam més control.

## Xarxa per defecte

Quan executam `docker compose up`, Compose crea automàticament una xarxa per al projecte. Aquesta xarxa rep el nom `<projecte>_default`, on `<projecte>` és el nom del directori que conté el fitxer `compose.yaml`.

Tots els serveis definits al fitxer es connecten automàticament a aquesta xarxa i poden comunicar-se entre ells usant el nom del servei com a *hostname*. Per exemple, si tenim dos serveis `webapp` i `db`, des de `webapp` podem connectar-nos a la base de dades usant simplement `db` com a *hostname*.

```yaml
services:
  webapp:
    image: myapp:latest
    environment:
      DATABASE_HOST: db  # Resolució automàtica pel nom del servei

  db:
    image: postgres:18-alpine
```

Docker incorpora un servidor DNS intern que resol automàticament els noms dels serveis a les seves adreces IP dins la xarxa. Aquesta resolució és dinàmica: si un contenidor es reinicia i obté una IP diferent, el DNS s'actualitza automàticament.

Per inspeccionar la xarxa per defecte i veure quins contenidors hi estan connectats usarem la següent comanda:

```bash
docker network inspect <projecte>_default
```

La sortida mostra informació detallada sobre la xarxa, incloent la subxarxa, la passarel·la i els contenidors connectats amb les seves adreces IP.

## Xarxes personalitzades

Tot i que la xarxa per defecte és suficient per a molts de casos, les xarxes personalitzades ens ofereixen avantatges importants:

- **Aïllament**: Podem separar grups de serveis que no necessiten comunicar-se entre ells.
- **Seguretat**: Els serveis de *backend* no han de ser accessibles des de la xarxa *frontend*.
- **Organització**: Una arquitectura de xarxes clara fa el sistema més fàcil d'entendre i mantenir.

Per definir xarxes personalitzades, usam la clau `networks` a dos nivells: al nivell superior per declarar les xarxes i dins cada servei per especificar a quines xarxes es connecta.

```yaml
services:
  nginx:
    image: nginx:alpine
    networks:
      - frontend

  webapp:
    image: myapp:latest
    networks:
      - frontend
      - backend

  db:
    image: postgres:18-alpine
    networks:
      - backend

networks:
  frontend:
  backend:
```

En aquest exemple, `nginx` i `webapp` poden comunicar-se a través de la xarxa `frontend`, mentre que `webapp` i `db` es comuniquen a través de la xarxa `backend`. Però `nginx` no pot accedir directament a `db` perquè no comparteixen cap xarxa. Aquesta és la base del patró d'aïllament frontend/backend.

> Quan definim xarxes personalitzades, Compose no crea la xarxa `default` automàticament. Cada servei ha d'especificar explícitament a quines xarxes es connecta.

## Configuració avançada

Sovint no ens cal fer res més que declarar les xarxes personalitzades que ens facin falta, però pot ser necessari definir una configuració avançada per a alguns casos especials.

### Driver

Docker suporta diferents drivers de xarxa. El driver per defecte és `bridge`, adequat per a la majoria de casos en un sol host:

```yaml
networks:
  frontend:
    driver: bridge
```

Altres drivers disponibles inclouen `host` (comparteix la xarxa de l'amfitrió), `overlay` (per a clústers Docker Swarm) i `none` (sense xarxa).

### Subxarxes

Podem especificar la configuració IP de la xarxa amb la clau `ipam` (*IP Address Management*):

```yaml
networks:
  backend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
          gateway: 172.28.0.1
```

### Adreces estàtiques

Per defecte, Docker assigna adreces IP dinàmicament. Si necessitam una IP fixa per a un servei, podem especificar-la:

```yaml
services:
  db:
    image: postgres:18-alpine
    networks:
      backend:
        ipv4_address: 172.28.0.10

networks:
  backend:
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

> Assignar IPs estàtiques sol ser innecessari gràcies a la resolució DNS automàtica. Reserva aquesta opció per a casos especials.

### Àlies de xarxa

Un servei pot tenir múltiples noms dins una xarxa usant aliases:

```yaml
services:
  db:
    image: postgres:18-alpine
    networks:
      backend:
        aliases:
          - database
          - postgres
```

Ara, des de qualsevol servei connectat a `backend`, podem accedir a la base de dades com `db`, `database` o `postgres`.

### Xarxes internes

Podem crear xarxes sense accés a l'exterior amb la clau `internal`:

```yaml
networks:
  backend:
    internal: true
```

Els serveis connectats a una xarxa interna poden comunicar-se entre ells, però no tenen accés a Internet ni poden ser accedits des de fora de Docker. Això és ideal per a bases de dades i altres serveis que no necessiten connectivitat externa.

### Xarxes externes

Podem connectar-nos a xarxes que existeixen fora del projecte Compose amb la clau `external`:

```yaml
networks:
  proxy:
    external: true
```

Això és útil quan tenim un proxy invers compartit entre múltiples projectes Compose. La xarxa ha d'existir prèviament, podem crear-la amb la següent comanda:

```bash
docker network create proxy
```

## Exemple pràctic

Posem en pràctica el que hem après amb un stack LEMP (Linux, NGINX, MariaDB, PHP). Crearem una arquitectura amb separació clara entre frontend i backend:

- **NGINX** servirà contingut estàtic i farà de proxy invers cap a [*](PHP)-[*](FPM).
- **PHP-FPM** processarà els scripts PHP i es comunicarà amb MariaDB.
- **MariaDB** emmagatzemarà les dades i només serà accessible des del backend.

> L'acrònim LEMP ve de **L**inux + **E**ngine-X (NGINX) + **M**ySQL/MariaDB + **P**HP. La "E" representa la pronunciació de NGINX ("Engine-X"). És equivalent al clàssic LAMP, substituint Apache per NGINX.

### Estructura del projecte

El nostre projecte tendra la següent estructura:

```
lemp/
├── compose.yaml
├── .env
├── docker/
│   ├── nginx/
│   │   └── default.conf
│   └── php/
│       └── Dockerfile
└── src/
    └── index.php
```

Comencem per crear el directori de feina i els subdirectoris necessaris:

```bash
mkdir --parents ~/Projects/lemp/docker/nginx ~/Projects/lemp/docker/php
mkdir --parents ~/Projects/lemp/src
cd ~/Projects/lemp
```

### Fitxer `.env`

El fitxer `.env` contendrà les variables d'entorn per a MariaDB:

```ini
# MariaDB
MARIADB_ROOT_PASSWORD=rootpassword
MARIADB_DATABASE=webapp
MARIADB_USER=webapp
MARIADB_PASSWORD=webapppassword
```

### Configuració d'NGINX

El fitxer `docker/nginx/default.conf` configura NGINX per servir fitxers PHP a través de FastCGI. Per simplicitat, farem que només escolti al port 80:

```nginx
server {
  listen 80;
  server_name localhost;
  root /var/www/html;
  index index.php index.html;

  location / {
    try_files $uri $uri/ /index.php?$query_string;
  }

  location ~ \.php$ {
    fastcgi_pass php:9000;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
  }
}
```

Observa que `fastcgi_pass php:9000` usa el nom del servei `php` com a hostname. Això funciona perquè ambdós serveis estaran connectats a la mateixa xarxa.

### Dockerfile de PHP-FPM

La imatge oficial de PHP no inclou les extensions de base de dades per defecte. Per tant, necessitam crear un fitxer `docker/php/Dockerfile` per configurar la imatge amb les extensions necessàries:

```dockerfile
FROM php:8.4-fpm-alpine

RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && docker-php-ext-install pdo_mysql mysqli \
    && apk del .build-deps

EXPOSE 9000
```

Aquest Dockerfile:

- Parteix de la imatge oficial `php:8.4-fpm-alpine`.
- Instal·la temporalment les eines de compilació necessàries.
- Afegeix les extensions `pdo_mysql` i `mysqli` per a la connexió amb MariaDB.
- Elimina les eines de compilació per reduir la mida de la imatge.

Si inspeccionam la imatge:

```bash
docker run --rm php:8.4-fpm-alpine whoami
```

Veurem que el procés principal (`php-fpm: master process`) s'executa com a `root`, però els workers que processen les peticions s'executen com a usuari `www-data` (UID 82 a Alpine). Això és el comportament estàndard de PHP-FPM: el procés mestre necessita privilegis per gestionar els workers i obrir el port, però els workers que executen el codi PHP no són privilegiats.

### Aplicació PHP

El fitxer `src/index.php` comprova la connexió amb MariaDB i mostra la informació de PHP, suficient per a verificar el correcte funcionament:

```php
<?php
echo "<h1>Stack LEMP amb Docker Compose</h1>";

echo "<h2>Connexió a MariaDB</h2>";
$host = 'db';
$user = getenv('MARIADB_USER');
$pass = getenv('MARIADB_PASSWORD');
$name = getenv('MARIADB_DATABASE');

try {
    $pdo = new PDO("mysql:host=$host;dbname=$name", $user, $pass);
    echo "<p style='color: green;'>Connexió exitosa a MariaDB!</p>";
    echo "<p>Versió del servidor: " . $pdo->query('SELECT VERSION()')->fetchColumn() . "</p>";
} catch (PDOException $e) {
    echo "<p style='color: red;'>Error de connexió: " . $e->getMessage() . "</p>";
}

echo "<h2>Informació de PHP</h2>";
phpinfo(INFO_GENERAL | INFO_MODULES);
?>
```

### Fitxer `compose.yaml`

Configuram els tres serveis de la nostra aplicació, el volum de la base de dades i les dues xarxes a través del fitxer `compose.yaml`:

```yaml
services:
  nginx:
    image: nginx:1.29-alpine
    container_name: lemp-nginx
    ports:
      - "8080:80"
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./src:/var/www/html:ro
    depends_on:
      - php
    networks:
      - frontend
    restart: unless-stopped

  php:
    build: ./docker/php
    container_name: lemp-php
    volumes:
      - ./src:/var/www/html
    environment:
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
    depends_on:
      - db
    networks:
      - frontend
      - backend
    restart: unless-stopped

  db:
    image: mariadb:12.2
    container_name: lemp-db
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
    volumes:
      - mariadb-data:/var/lib/mysql
    networks:
      - backend
    restart: unless-stopped

networks:
  frontend:
  backend:
    internal: true

volumes:
  mariadb-data:
```

Observa com:

- El servei `php` usa `build: ./docker/php` en comptes d'`image:`, indicant a Compose que ha de construir la imatge a partir del Dockerfile.
- **NGINX** només està connectat a `frontend` i exposa el port 8080.
- **PHP-FPM** està connectat a ambdues xarxes: rep peticions de NGINX via `frontend` i es connecta a MariaDB via `backend`.
- **MariaDB** només està a `backend`, completament aïllat de la xarxa pública.
- **PHP-FPM** i **MariaDB** no publiquen ports, car els tres serveis es comuniquen internament i només el servei **NGINX** es comunica amb el exterior.

### Arrencada i verificació

Una vegada creats tots els fitxers nec necessaris, arrencam els serveis:

```bash
docker compose up --detach
```

Compose detectarà el `build:` al servei `php` i construirà automàticament la imatge abans d'arrencar els contenidors.

Accedim a `http://localhost:8080/` per veure la pàgina PHP. Hauríem de veure el missatge de connexió exitosa a MariaDB i la informació de PHP amb les extensions `pdo_mysql` i `mysqli` llistades.

Per verificar l'aïllament de xarxes, podem intentar fer ping des de NGINX a la base de dades:

```bash
docker exec lemp-nginx ping -c 2 db
```

El ping fallarà perquè `db` no és resoluble des de la xarxa `frontend`. En canvi, des de PHP-FPM funcionarà:

```bash
docker exec lemp-php ping -c 2 db
```

Per inspeccionar les xarxes creades usarem la següent comanda:

```bash
docker network ls | grep lemp
```

La sortida mostrarà les dues xarxes:

```
7b4c1ecae244   lemp_backend    bridge    local
a46644844df8   lemp_frontend   bridge    local
```

## Bones pràctiques

Algunes recomanacions per gestionar xarxes de manera efectiva:

**Arquitectura:**
- Separa frontend i backend sempre que sigui possible.
- Connecta cada servei només a les xarxes que realment necessita.
- Usa xarxes internes per a serveis que no necessiten accés a Internet.

**Nomenclatura:**
- Usa noms descriptius per a les xarxes, com `frontend`, `backend` o `monitoring`.
- Evita noms genèrics, com `network1` o `net`, o excessivament abreujats, com `fe` o `be`.

**Seguretat:**
- No exposis ports de bases de dades a l'amfitrió si no és estrictament necessari.
- Considera usar xarxes internes per a serveis sensibles.
- Revisa periòdicament quins serveis tenen accés a quines xarxes.

## Exercicis

Es proposen dos exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Afegir Adminer per a administració de MariaDB**

En aquest exercici es proposa afegir [Adminer](https://www.adminer.org/), una eina d'administració de bases de dades, a l'stack LEMP. Adminer ha de poder accedir a MariaDB però no ha de ser accessible des de NGINX. Passos:

1. Parteix de l'exemple LEMP de l'article.
2. Afegeix un servei `adminer` amb la imatge `adminer:latest` al port 8081.
3. Connecta Adminer només a la xarxa `backend`.
4. Verifica que pots accedir a Adminer a `http://localhost:8081` i connectar-te a MariaDB.
5. Verifica que NGINX no pot comunicar-se amb Adminer.

> Consulta la [documentació d'Adminer a Docker Hub](https://hub.docker.com/_/adminer) per a més informació sobre la configuració.

{{< details summary="Respostes" >}}

Afegeix el servei Adminer al `compose.yaml`:

```yaml
services:
  nginx:
    image: nginx:1.29-alpine
    container_name: lemp-nginx
    ports:
      - "8080:80"
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./src:/var/www/html:ro
    depends_on:
      - php
    networks:
      - frontend
    restart: unless-stopped

  php:
    build: ./docker/php
    container_name: lemp-php
    volumes:
      - ./src:/var/www/html
    environment:
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
    depends_on:
      - db
    networks:
      - frontend
      - backend
    restart: unless-stopped

  db:
    image: mariadb:12.2
    container_name: lemp-db
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
    volumes:
      - mariadb-data:/var/lib/mysql
    networks:
      - backend
    restart: unless-stopped

  adminer:
    image: adminer:latest
    container_name: lemp-adminer
    ports:
      - "8081:8080"
    networks:
      - backend
    restart: unless-stopped

networks:
  frontend:
  backend:

volumes:
  mariadb-data:
```

Executa Docker Compose:

```bash
docker compose up --detach
```

Accedeix a `http://localhost:8081` i connecta't amb les dades següents:

- **Sistema**: MySQL
- **Servidor**: db
- **Usuari**: webapp
- **Contrasenya**: webapppassword
- **Base de dades**: webapp

Per verificar l'aïllament, intenta fer ping des de NGINX a Adminer:

```bash
docker exec lemp-nginx ping -c 2 adminer
```

El ping fallarà perquè no comparteixen xarxa.

{{< /details >}}

### Exercici 2

**Afegir un comptador de visites amb Valkey**

En aquest exercici es proposa afegir [Valkey](https://valkey.io/), un emmagatzematge clau-valor compatible amb Redis, a l'stack LEMP per implementar un comptador de visites. Passos:

1. Parteix de l'exemple LEMP de l'article.
2. Modifica el fitxer `docker/php/Dockerfile` per afegir l'extensió `redis` (compatible amb Valkey). Consulta la [documentació de la imatge oficial de PHP](https://hub.docker.com/_/php) per veure com instal·lar extensions PECL.
3. Afegeix un servei `valkey` amb la imatge `valkey/valkey:9.0-alpine` a la xarxa `backend`.
4. Crea el fitxer `src/comptador.php` amb el següent contingut:
   ```php
   <?php
   echo "<h1>Comptador de visites</h1>";
   
   $redis = new Redis();
   
   try {
       $redis->connect('valkey', 6379);
       $visites = $redis->incr('comptador_visites');
       echo "<p style='color: green;'>Connexió exitosa a Valkey!</p>";
       echo "<p>Aquesta pàgina ha rebut <strong>$visites</strong> visites.</p>";
       echo "<p><a href='comptador.php'>Recarrega</a> per incrementar el comptador.</p>";
   } catch (RedisException $e) {
       echo "<p style='color: red;'>Error de connexió: " . $e->getMessage() . "</p>";
   }
   ?>
   ```
5. Reconstrueix la imatge de PHP i reinicia els serveis.
6. Accedeix a `http://localhost:8080/comptador.php` i verifica que el comptador s'incrementa amb cada visita.
7. Verifica que NGINX no pot comunicar-se amb Valkey.

{{< details summary="Respostes" >}}

Modifica el fitxer `docker/php/Dockerfile` per afegir l'extensió `redis`:

```dockerfile
FROM php:8.4-fpm-alpine

RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && docker-php-ext-install pdo_mysql mysqli \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

EXPOSE 9000
```

Afegeix el servei Valkey al `compose.yaml`:

```yaml
services:
  nginx:
    image: nginx:1.29-alpine
    container_name: lemp-nginx
    ports:
      - "8080:80"
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./src:/var/www/html:ro
    depends_on:
      - php
    networks:
      - frontend
    restart: unless-stopped

  php:
    build: ./docker/php
    container_name: lemp-php
    volumes:
      - ./src:/var/www/html
    environment:
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
    depends_on:
      - db
      - valkey
    networks:
      - frontend
      - backend
    restart: unless-stopped

  db:
    image: mariadb:12.2
    container_name: lemp-db
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE}
      MARIADB_USER: ${MARIADB_USER}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
    volumes:
      - mariadb-data:/var/lib/mysql
    networks:
      - backend
    restart: unless-stopped

  valkey:
    image: valkey/valkey:9.0-alpine
    container_name: lemp-valkey
    networks:
      - backend
    restart: unless-stopped

networks:
  frontend:
  backend:
    internal: true

volumes:
  mariadb-data:
```

Crea el fitxer `src/comptador.php` amb el contingut proporcionat a l'enunciat.

Reconstrueix la imatge de PHP i reinicia els serveis:

```bash
docker compose up --detach --build
```

L'opció `--build` força la reconstrucció de les imatges, necessària perquè hem modificat el Dockerfile.

Accedeix a `http://localhost:8080/comptador.php` i refresca la pàgina diverses vegades per veure el comptador incrementar-se.

Per verificar l'aïllament, intenta fer ping des de NGINX a Valkey:

```bash
docker exec lemp-nginx ping -c 2 valkey
```

El ping fallarà perquè no comparteixen xarxa.

{{< /details >}}
