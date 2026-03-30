---
title: "Instal·lació de Docker i primers passos"
date: 2026-03-25
lastmod: 2026-03-25
description: "Instal·lació de Docker a Debian/Ubuntu, primers comandaments i gestió bàsica d'imatges"
summary: "Instal·lació de Docker a Debian/Ubuntu, primers comandaments i gestió bàsica d'imatges"
categories: ["ensenyament"]
tags: ["docker", "engine", "containers"]
series: ["Docker Engine"]
series_order: 2
weight: 20
slug: installacio
---

En aquest article instal·larem Docker Engine a una distribució Debian o derivada (com Ubuntu o Linux Mint), i aprendrem els primers comandaments per fer feina amb imatges i contenidors.

## La CLI

La [*](CLI) de Docker proporciona una àmplia gamma de comandes per interactuar amb els serveis de Docker. Agruparem aquestes comandes en quatre categories:

1. Gestió d'imatges: `docker pull`, `docker images`, `docker rmi`, `docker build`
2. Gestió de contenidors: `docker run`, `docker ps`, `docker stop`, `docker rm`
3. Gestió de volums: `docker volume ls`, `docker volume create`, `docker volume rm`
4. Gestió de xarxes: `docker network ls`, `docker network create`, `docker network rm`

En aquest article ens centrarem en les dues primeres categories. Els volums i les xarxes els tractarem en articles posteriors.

## Instal·lació

Per a instal·lar Docker hem de seguir les [instruccions d'instal·lació per a la nostra distribució](https://docs.docker.com/engine/install/). En aquest curs farem feina principalment amb Debian o distribucions basades en Debian (Ubuntu, Linux Mint, etc.). La majoria de comandes d'aquesta secció requereixen privilegis de `root`, per tant fem servir `sudo`.

Primer de tot, ens asseguram que no hi ha paquets conflictius dels repositoris de la distribució instal·lats:

```bash
sudo apt-get purge docker.io docker-doc docker-compose \
  podman-docker containerd runc
```

> No és un error si `apt-get` indica que algun d'aquests paquets no està instal·lat.

Acte seguit, instal·lam els paquets necessaris per afegir repositoris HTTPS:

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl
```

A continuació, afegeim la clau GPG oficial de Docker al *keyring* del sistema:

```bash
sudo install --mode=0755 --directory /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod 0644 /etc/apt/keyrings/docker.asc
```

> Si utilitzam Ubuntu, hem de substituir `debian` per `ubuntu` a la URL.

Ara ja podem afegir el repositori de Docker a les fonts d'APT. El següent exemple usa el [format DEB822](https://repolib.readthedocs.io/en/latest/deb822-format.html):

```bash
ARCH=$(dpkg --print-architecture)
CODENAME=$(source /etc/os-release && echo "$VERSION_CODENAME")
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null << EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $CODENAME
Components: stable
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

> Novament, si utilitzam Ubuntu, hem de substituir `debian` per `ubuntu` a la línia `URIs`.

Arriba ara el moment d'actualitzar l'index de paquets i instal·lar Docker Engine:

```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

Els paquets instal·lats són:

| Paquet                  | Descripció                           |
|-------------------------|--------------------------------------|
| `docker-ce`             | Docker Engine (el daemon)            |
| `docker-ce-cli`         | Interfície de línia de comandes      |
| `containerd.io`         | Runtime de contenidors               |
| `docker-buildx-plugin`  | Plugin per a construccions avançades |
| `docker-compose-plugin` | Plugin de Docker Compose             |

El servei Docker s'inicia automàticament després de la instal·lació. Podem usar la següent comanda per verificar que està en execució:

```bash
systemctl status docker
```

Per defecte, les comandes de Docker requereixen privilegis de `root`. Per poder executar `docker` com a usuari normal, hem d'afegir el teu usuari al grup `docker`:

```bash
sudo usermod --append --groups docker $USER
```

{{< alert >}}
L'accés al grup `docker` és equivalent a tenir accés `root` al sistema. Hem d'assegurar-nos de que els usuaris afegits a aquest grupo són de confiança.
{{< /alert >}}

Haurem de tancar la sessió i tornar a iniciar-la perquè els canvis tenguin efecte. Alternativament, podem executar `newgrp docker`.

Per acabar, comprovam que Docker funciona correctament executant el contenidor de prova:

```bash
docker run hello-world
```

Si tot ha anat bé, veurem un missatge de benvinguda que confirma que Docker pot descarregar imatges i executar contenidors.

## Primers passos

Començarem comprovant la versió de Docker instal·lada:

```bash
docker --version
```

Per obtenir informació més detallada sobre la instal·lació podem usar `docker info`. Aquesta comanda mostra informació sobre el daemon, el nombre de contenidors i imatges, el controladors d'emmagatzemament, o *storage drivers*, i altres configuracions del sistema.

### Recursos del sistema

Abans de descarregar imatges i executar contenidors, comprovarem que tenim suficients recursos:

```bash
free -h      # Memòria disponible
df -h        # Espai de disc disponible
```

Docker emmagatzema les imatges i dades dels contenidors a `/var/lib/docker` per defecte. Ens convé assegurar-nos de tenir espai suficient en aquesta partició.

### Ajuda integrada

La CLI de Docker proporciona ajuda integrada per a totes les comandes:

```bash
docker --help              # Llista de totes les comandes
docker pull --help         # Ajuda per a una comanda específica
```

## Gestió d'imatges

Les **imatges Docker** són plantilles de només lectura que contenen tot el necessari per executar una aplicació: el codi, les biblioteques, les dependències i la configuració del sistema. Les imatges són la base a partir de la qual es creen els contenidors.

Per descarregar una imatge del registre ([Docker Hub](https://hub.docker.com/) per defecte), utilitzam la comanda `docker pull`. Prenent [NGINX](https://hub.docker.com/_/nginx) com a exemple:

```bash
docker pull nginx
```

### Etiquetes

Quan no s'especifica cap etiqueta (*tag*), Docker descarrega la versió `latest`. És recomanable especificar sempre una versió concreta per garantir la reproductibilitat:

```bash
docker pull nginx:1.29
```

Les **etiquetes** (*tags*) identifiquen versions específiques d'una imatge. Per exemple:

| Imatge              | Descripció                                    |
|---------------------|-----------------------------------------------|
| `nginx:latest`      | Última versió disponible (pot canviar)        |
| `nginx:1.29`        | Versió 1.29 específica (basada en Debian)     |
| `nginx:1.29.7`      | Versió amb *patch* específic                  |
| `nginx:alpine`      | Variant basada en Alpine Linux                |
| `nginx:1.29-alpine` | Versió 1.29 específica basada en Alpine Linux |

{{< alert >}}
En entorns de producció, evitarem usar `latest` perquè el contingut pot canviar sense avís. Per tant, especificarem sempre una versió concreta.
{{< /alert >}}

Per veure les imatges disponibles al nostre sistema usarem:

```bash
docker images
```

La sortida mostra:

```
IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
hello-world:latest   e2ac70e7319a       10.1kB             0B    U   
nginx:1.29           0cf1d6af5ca7        161MB             0B        
nginx:latest         0cf1d6af5ca7        161MB             0B 
```

> La columna `EXTRA` mostra flags (estats/atributs) de l'imatge. Específicament, el flag `U` vol dir "Unpacked", i.e., totes les capes de la imatge estan presents localment.

Observa que `nginx:1.29` i `nginx:latest` tenen el mateix `IMAGE ID`: això indica que són la mateixa imatge amb dues etiquetes diferents.

Per eliminar una imatge que ja no necessitam:

```bash
docker rmi nginx:1.29
```

Si la imatge té múltiples etiquetes, només s'elimina l'etiqueta especificada. Per eliminar la imatge completament, hem d'eliminar totes les etiquetes o usar l'ID:

```bash
docker rmi 0cf1d6af5ca7
```

{{< alert >}}
No podem eliminar una imatge si hi ha contenidors (en execució o aturats) que la utilitzen. Primer hem d'eliminar els contenidors.
{{< /alert >}}

### Sistema de capes

Quan descarregam una imatge, Docker la descarrega en **capes** (*layers*). Cada capa representa un canvi al sistema de fitxers, com ara instal·lar un paquet o copiar fitxers.

```bash
$ docker pull postgres:18
18: Pulling from library/postgres
ec781dee3f47: Pull complete 
ce2467f2f21d: Pull complete 
d4ced18622af: Pull complete 
...
```

Aquest sistema de capes permet:

- Eficiència d'emmagatzematge, car les capes comunes entre imatges només s'emmagatzemen una vegada.
- Descàrregues ràpides, car només es descarreguen les capes que no tens localment.
- Construccions incrementals, car Docker reutilitza les capes que no han canviat quan construeixes imatges.

## Execució de contenidors

Amb les imatges descarregades, ja podem crear i executar contenidors. Un contenidor és una instància executable d'una imatge.

La comanda `docker run` crea i executa un contenidor a partir d'una imatge:

```bash
docker run nginx
```

Aquesta comanda:

1. Cerca la imatge `nginx:latest` localment.
2. Si no la troba, la descarrega de Docker Hub.
3. Crea un nou contenidor a partir de la imatge.
4. Executa el contenidor en primer pla (*foreground*).

Per aturar el contenidor, prem `Ctrl+C`.

Per executar un contenidor en segon pla (*background*), utilitzam l'opció `--detach` o `-d`:

```bash
docker run --detach nginx
```

La comanda retorna l'ID del contenidor i allibera el terminal.

Per defecte, Docker assigna noms aleatoris als contenidors (com `quirky_nobel` o `angry_darwin`). Pots assignar un nom descriptiu amb `--name`:

```bash
docker run --detach --name web nginx
```

### Publicar ports

Els contenidors, per defecte, estan aïllats de la xarxa de l'amfitrió. Per accedir a un servei dins del contenidor, hem de **publicar** el port amb l'opció `--publish` o `-p`:

```bash
docker run --detach --name web --publish 8080:80 nginx
```

Aquesta comanda mapeja el port 8080 de l'amfitrió al port 80 del contenidor. Ara podem accedir a NGINX des del navegador a `http://localhost:8080/`.

La sintaxi és `--publish PORT_AMFITRIÓ:PORT_CONTENIDOR`.

### Estat dels contenidors

Per llistar els contenidors en execució:

```bash
docker ps
```

Per veure tots els contenidors, incloent els aturats:

```bash
docker ps --all
```

### Aturar i eliminar

Per aturar un contenidor en execució:

```bash
docker stop web
```

Per eliminar un contenidor aturat:

```bash
docker rm web
```

Pots combinar ambdues accions amb l'opció `--force`:

```bash
docker rm --force web
```

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Explorar Docker Hub.**

1. Accedeix a Docker Hub i cerca la imatge oficial de Caddy (un servidor web modern amb HTTPS automàtic).
2. Identifica quines etiquetes (tags) estan disponibles i quina és la mida de la imatge `caddy:alpine`.
3. Descarrega la imatge `caddy:2.11-alpine` al teu sistema.
4. Compara la mida de `caddy:2.11-alpine` amb la de `nginx:1.29-alpine` que hem usat durant la lliçó. Quina és més lleugera?
5. Elimina ambdues imatges del sistema.

### Exercici 2

**Servidor web Caddy**

1. Descarrega la imatge `caddy:2.11-alpine`.
2. Executa un contenidor anomenat `caddy-web` en segon pla, publicant el port 9000 de l'amfitrió al port 80 del contenidor.
3. Accedeix a `http://localhost:9000` des del navegador. Quina pàgina es mostra?
4. Sense aturar el contenidor anterior, executa un segon contenidor anomenat `caddy-web2` publicant el port 9001.
5. Verifica amb `docker ps` que ambdós contenidors estan en execució.
6. Atura i elimina ambdós contenidors amb una sola comanda `docker rm`.

> Pista: Usa `docker rm --help` per a averiguar com esborrar múltiples contenidors amb una sola comanda.

### Exercici 3

**Base de dades MariaDB**

1. Cerca a Docker Hub la imatge oficial de MariaDB i identifica l'etiqueta de la versió LTS més recent.
2. Descarrega aquesta imatge.
3. Consulta la documentació de la imatge a Docker Hub i identifica quines variables d'entorn són obligatòries per executar el contenidor.
4. Executa un contenidor anomenat `mariadb-test` en segon pla, publicant el port 3306 i configurant les variables d'entorn necessàries.
5. Verifica que el contenidor està en execució amb docker ps.
6. Atura i elimina el contenidor.

> Pista: Usa `docker run --help` per a averiguar com executar un contenidor amb variables d'entorn.
