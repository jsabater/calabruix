---
title: "Projectes multi-contenidor"
date: 2026-04-04
lastmod: 2026-04-04
description: "Gestió de projectes multi-contenidor amb Docker Compose: del problema a la solució"
summary: "Gestió de projectes multi-contenidor amb Docker Compose: del problema a la solució"
categories: ["teaching"]
tags: ["docker", "engine", "compose", "php", "mariadb", "redis"]
series: ["Docker Engine"]
series_order: 7
weight: 70
slug: multicontenidor
---

Fins ara hem fet feina amb contenidors individuals o amb pocs contenidors que hem executat manualment. Tanmateix, les aplicacions reals solen requerir múltiples serveis treballant conjuntament: un servidor web, una base de dades, un sistema de cache, etc.

En aquest article veurem els reptes de gestionar manualment una aplicació multi-contenidor i com Docker Compose ofereix una solució elegant a aquests problemes.

## Exemple amb Docker

Imaginem que volem desplegar una aplicació web PHP clàssica amb la següent arquitectura:

- **Apache amb PHP**: Servidor web que executa l'aplicació.
- **MariaDB**: Base de dades relacional.
- **Redis**: Sistema de cache en memòria.

{{< mermaid >}}
flowchart LR
    subgraph Internet
        U[Usuari]
    end
    
    subgraph Docker Host
        subgraph app-network
            A[Apache/PHP<br/>:80]
            D[(MariaDB<br/>:3306)]
            R[(Redis<br/>:6379)]
        end
    end
    
    U -->|:8080| A
    A --> D
    A --> R
{{< /mermaid >}}

### Execució manual

Per desplegar aquesta aplicació manualment, hem de seguir un ordre específic de comandes. En primer lloc crearíem la xarxa i els volum:

```bash
docker network create app-network
docker volume create app-dbdata
```

En segon lloc executaríem el contenidor amb MariaDB:

```bash
docker run --name app-db \
  --network app-network \
  --volume app-dbdata:/var/lib/mysql \
  --env MARIADB_ROOT_PASSWORD=rootsecret \
  --env MARIADB_DATABASE=myapp \
  --env MARIADB_USER=appuser \
  --env MARIADB_PASSWORD=apppassword \
  --detach \
  mariadb:12.2
```

A continuació, executaríem el contenidor amb Redis:

```bash
docker run --name app-redis \
  --network app-network \
  --detach \
  redis:8.6-alpine
```

I, finalment, ens quedaria el contenidor amb Apache i PHP. Suposem que tenim el projecte al subdirectori `~/Projects/myapp`, podríem tenir a dins un subdirectori `src/` amb el contingut de l'aplicació.

```bash
mkdir --parents ~/Projects/myapp/src
```

A mode d'exemple, podríem crear un senzill fitxer `~/Projects/myapp/src/index.php` amb el següent contingut:

```php
<?php phpinfo(); ?>
```

Arribats a aquest punt, executaríem el contenidor amb la seguent comanda:

```bash
docker run --name app-web \
  --network app-network \
  --volume ~/Projects/myapp/src:/var/www/html:ro \
  --publish 8080:80 \
  --detach \
  php:8.4-apache
```

Hauríem de poder accedir a l'execució de l'aplicació web a la URL `http://localhost:8080/`, on veurem la pàgina d'informació de PHP.

### Aturada manual

Arribada l'ocasió, si necessitàssim aturar l'aplicació, hauríem d'aturar cada contenidor individualment:

```bash
docker stop app-web app-redis app-db
```

I, finalment, eliminar tots els recursos també individualment:

```bash
docker rm app-web app-redis app-db
docker network rm app-network
docker volume rm app-dbdata
```

### Els inconvenients

Aquesta aproximació manual presenta diversos problemes:

- És repetitiva i propensa a errors, car hem de recordar múltiples comandes llargues amb molts de paràmetres.
- Els serveis s'han d'iniciar en un ordre específic, e.g., la base de dades abans que l'aplicació web.
- És difícil de compartir, per tant ens caldrà documentar-la separadament i amb suficient detall.
- La configuració no se troba a cap fitxer que puguem versionar amb Git.
- Qualsevol canvi requereix modificar i executar múltiples comandes.

## Docker Compose

**Docker Compose** és una eina que permet definir i executar aplicacions multi-contenidor mitjançant un fitxer de configuració YAML. En lloc de múltiples comandes `docker run`, definim tots els serveis, xarxes i volums en un sol fitxer anomenat `compose.yaml`.

Avantatges principals:

- **Declaratiu**: Descrivim l'estat desitjat, no els passos per arribar-hi.
- **Versionable**: El fitxer `compose.yaml` es pot versionar amb Git.
- **Reproduïble**: Qualsevol persona amb el fitxer pot desplegar exactament la mateixa configuració.
- **Simple**: Una sola comanda per iniciar o aturar tota l'aplicació.

Docker Compose ve inclòs amb Docker Desktop. En instal·lacions de Docker Engine a Linux, cal instal·lar el paquet corresponent:

```bash
sudo apt-get install docker-compose-plugin
```

Podem verificar la instal·lació amb la següent comanda:

```bash
docker compose version
```

## Exemple amb Compose

Anem a convertir l'exemple anterior a Docker Compose. Sobre l'estructura del projecte que ja crearem, només hem d'afegir el fitxer `compose.yaml`:

```
myapp/
├── compose.yaml
└── src/
    └── index.php
```

El contingut del fitxer `compose.yaml`, a l'arrel del projecte, seria el següent:

```yaml
services:
  web:
    image: php:8.4-apache
    ports:
      - "8080:80"
    volumes:
      - ./src:/var/www/html:ro
    depends_on:
      - db
      - redis

  db:
    image: mariadb:12.2
    volumes:
      - dbdata:/var/lib/mysql
    environment:
      MARIADB_ROOT_PASSWORD: rootsecret
      MARIADB_DATABASE: myapp
      MARIADB_USER: appuser
      MARIADB_PASSWORD: apppassword

  redis:
    image: redis:8.6-alpine

volumes:
  dbdata:
```

Analitzem l'estructura:

| Secció     | Descripció                                      |
|------------|-------------------------------------------------|
| `services` | Defineix els contenidors que formen l'aplicació |
| `volumes`  | Defineix els volums persistents                 |

Cada servei pot tenir:

| Clau          | Descripció                             |
|---------------|----------------------------------------|
| `image`       | La imatge Docker a utilitzar           |
| `ports`       | Mapatge de ports (amfitrió:contenidor) |
| `volumes`     | Muntatge de volums o bind mounts       |
| `environment` | Variables d'entorn                     |
| `depends_on`  | Serveis que han d'iniciar-se abans     |

Fixem-nos que no hem definit cap xarxa. Docker Compose crea automàticament una xarxa per al projecte i hi connecta tots els serveis. El nom de la xarxa és `<nom_directori>_default`.

Dins d'aquesta xarxa, cada servei és accessible pel seu nom. Per exemple, des del contenidor `web`, podem accedir a MariaDB amb el host `db` i a Redis amb el host `redis`.

## Comandes bàsiques

Des del directori que conté `compose.yaml` podem iniciar l'aplicació amb:

```bash
docker compose up --detach
```

L'opció `--detach` (o `-d`) executa els contenidors en segon pla. Sense aquesta opció, veuríem els logs de tots els serveis a la terminal.

La primera vegada, Docker descarregarà les imatges necessàries, crearà la xarxa i els volums, i iniciarà els contenidors en l'ordre correcte.

Un pic l'aplicació estigui en execució, podem verificar que tot funciona accedint amb el navegador a `http://localhost:8080/`.

Docker Compose ofereix [moltes comandes per gestionar l'aplicació](https://docs.docker.com/compose/reference/), algunes de les quals es mostren a la següent taula:

| Comanda                              | Descripció                           |
|--------------------------------------|--------------------------------------|
| `docker compose up -d`               | Inicia l'aplicació en segon pla      |
| `docker compose down`                | Atura i elimina contenidors i xarxes |
| `docker compose down -v`             | A més, elimina els volums            |
| `docker compose ps`                  | Mostra l'estat dels serveis          |
| `docker compose logs`                | Mostra els logs                      |
| `docker compose logs -f <servei>`    | Segueix els logs d'un servei         |
| `docker compose stop`                | Atura els contenidors                |
| `docker compose start`               | Inicia els contenidors aturats       |
| `docker compose restart`             | Reinicia els contenidors             |
| `docker compose exec <servei> <cmd>` | Executa una comanda dins un servei   |

## Segueix aprenent

Com es pot apreciar en aquesta introducció, Docker Compose simplifica la gestió d'aplicacions multi-contenidor, però Compose ofereix moltes més funcionalitats:

- Variables d'entorn amb fitxers `.env`.
- Construcció d'imatges amb `build`.
- Múltiples fitxers Compose per a diferents entorns.
- Perfils per activar serveis opcionals.
- Healthchecks i polítiques de reinici.
- Configuració de xarxes personalitzades.
- Secrets i configuracions.

Totes aquestes funcionalitats les explorarem en profunditat a la [sèrie de Docker Compose]({{<relref "/posts/docker/compose/">}}).

## Exercicis pràctics

Es proposa un exercici pràctic per facilitar l'aprenentatge progressiu.

### Exercici 1

**WordPress amb MariaDB**

1. Crea un directori de projecte amb un fitxer `compose.yaml`.
2. Defineix dos serveis:
   - `wordpress`: Utilitza la imatge `wordpress:6`, exposa el port 8080 i connecta amb la base de dades.
   - `db`: Utilitza la imatge `mariadb:12.2` amb les variables d'entorn necessàries.
3. Defineix volums per persistir tant les dades de WordPress com les de MariaDB.
4. Inicia l'aplicació i completa la instal·lació de WordPress al navegador.
5. Reinicia l'aplicació amb `docker compose restart` i verifica que les dades persisteixen.
6. Neteja tots els recursos.

> Pista: Consulta la documentació de la [imatge de WordPress a Docker Hub](https://hub.docker.com/_/wordpress) per veure les variables d'entorn necessàries per connectar amb la base de dades.
