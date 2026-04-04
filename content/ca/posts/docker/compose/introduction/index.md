---
title: "Fonaments de Docker Compose"
date: 2026-04-04
lastmod: 2026-04-04
description: "Introducció, estructura del fitxer de configuració, definició de serveis, comandes del cicle de vida i convencions de noms"
summary: "Introducció, estructura del fitxer de configuració, definició de serveis, comandes del cicle de vida i convencions de noms"
categories: ["teaching"]
tags: ["docker", "compose"]
series: ["Docker Compose"]
series_order: 10
weight: 10
slug: fonaments
---

Quan els projectes creixen més enllà d'uns pocs contenidors, gestionar-los amb múltiples comandes `docker run` es converteix ràpidament en un malson. Docker Compose és una eina que ens permet definir i executar aplicacions Docker multi-contenidor usant un únic fitxer YAML. Aquest fitxer de configuració descriu tot l'entorn (serveis, xarxes i volums) de manera declarativa i llegible.

Imaginem un escenari típic: una aplicació web que depèn d'una base de dades PostgreSQL, una memòria cau Redis i un servidor de monitorització. Sense Compose, hauríem d'executar quatre comandes `docker run` separades, recordant els paràmetres de cadascuna, l'ordre d'arrencada i les xarxes que les connecten. Amb Compose, ho descrivim tot en un fitxer `compose.yaml` i ho arrencam amb una sola comanda:

```bash
docker compose up --detach
```

## Evolució de Docker Compose

Docker Compose ha passat per una evolució significativa. La primera versió (v1) era una eina independent escrita en Python que s'instal·lava per separat i s'executava amb la comanda `docker-compose` (amb guió). L'any 2020, Docker va començar a reescriure Compose en Go com a plugin integrat del Docker CLI, donant lloc a la versió 2.

Avui dia, Docker Compose v2 és la versió recomanada i ve inclosa amb les instal·lacions modernes de Docker Engine, inclosa la que s'instal·la si seguim les instruccions d'instal·lació oficials de Docker per a Debian o Ubuntu. La comanda ara és `docker compose` (sense guió, com a subcomanda de `docker`).

Si escau, segueix les instruccions de [l'article d'instal·lació de la sèrie Docker Engine]({{<relref "/posts/docker/engine/installation/">}}) per a veure com instal·lar Docker.

> Si trobes documentació o tutorials que usen `docker-compose` amb guió, això vol dir que fan referència a la versió antiga. Les comandes són pràcticament idèntiques, però la sintaxi moderna és `docker compose`.

## Configuració

Docker Compose cerca per defecte un fitxer de configuració seguint aquest ordre de precedència:

1. `compose.yaml` (preferit)
2. `compose.yml`
3. `docker-compose.yaml`
4. `docker-compose.yml`

Nosaltres usarem `compose.yaml`, que és el nom recomanat per la documentació oficial. El fitxer utilitza el format YAML, que és llegible i declaratiu: descrivim *què* volem, no *com* ho volem fer. Si no estàs familiaritzat amb YAML, recorda que la indentació és crucial i que s'usen espais, mai tabuladors.

L'estructura bàsica d'un fitxer `compose.yaml` conté aquestes claus de primer nivell:

```yaml
services:
  # Definició dels contenidors

networks:
  # Definició de xarxes personalitzades (opcional)

volumes:
  # Definició de volums amb nom (opcional)

configs:
  # Fitxers de configuració (opcional)

secrets:
  # Dades sensibles (opcional)
```

La clau `services` és l'única obligatòria i és on definirem els nostres contenidors. Les altres claus les anirem explorant en articles posteriors.

> Si trobes fitxers `compose.yaml` amb una clau `version:` a l'inici, sabràs que és sintaxi antiga. Des de Docker Engine 25.0 i Docker Compose 2.22, aquesta clau és obsoleta i s'ignora. No la incloguis als teus fitxers nous.

## Definició de serveis

Cada servei dins la clau `services` representa un contenidor (o múltiples rèpliques d'un contenidor). Vegem un exemple senzill amb [Uptime Kuma](https://hub.docker.com/r/louislam/uptime-kuma), una eina de monitorització d'uptime autoallotjada:

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:2
    ports:
      - "3001:3001"
    volumes:
      - uptime-kuma-data:/app/data

volumes:
  uptime-kuma-data:
```

Analitzem les claus utilitzades:

- `image`: Especifica la imatge Docker a usar. En aquest cas, `louislam/uptime-kuma:2` descarregarà la versió 2.x més recent d'Uptime Kuma des de Docker Hub.
- `ports`: Mapeja ports entre l'amfitrió i el contenidor. La sintaxi `"3001:3001"` significa que el port 3001 de l'amfitrió es redirigeix al port 3001 del contenidor.
- `volumes`: Munta volums per a persistència de dades. Aquí muntem un volum amb nom `uptime-kuma-data` al directori `/app/data` del contenidor.

A més, hem definit el volum `uptime-kuma-data` a la secció `volumes` de primer nivell. Això indica a Compose que ha de crear un volum Docker amb nom per emmagatzemar les dades de manera persistent.

### Imatges vs construcció

Hi ha dues maneres de definir d'on prové la imatge d'un servei:

```yaml
services:
  # Opció 1: Usar una imatge existent
  redis:
    image: valkey/valkey:9.0-alpine

  # Opció 2: Construir des d'un Dockerfile
  webapp:
    build:
      context: ./docker/webapp
      dockerfile: Dockerfile
    image: la-meva-webapp:latest
```

Quan usam `image` sol, Compose descarregarà la imatge del registre (Docker Hub per defecte). Quan usam `build`, Compose construirà la imatge a partir del Dockerfile especificat. Podem combinar `build` i `image` per assignar un nom personalitzat a la imatge construïda.

### Variables d'entorn

Podem passar variables d'entorn als contenidors amb la clau `environment`:

```yaml
services:
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: usuari
      POSTGRES_PASSWORD: contrasenya
      POSTGRES_DB: basededades
```

{{< alert >}}
Mai inclogueu credencials sensibles directament al fitxer `compose.yaml` si el versionau amb Git. A l'article següent veurem com usar fitxers `.env` per gestionar la configuració de manera segura.
{{< /alert >}}

## Posem-ho en pràctica

Creem un directori per al nostre projecte i el fitxer de configuració:

```bash
mkdir --parents ~/Projects/uptime-kuma
cd ~/Projects/uptime-kuma
```

I cream ara el fitxer `compose.yaml` dins el directori del projecte amb el contingut seguent:

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:2
    container_name: uptime-kuma
    ports:
      - "3001:3001"
    volumes:
      - uptime-kuma-data:/app/data
    restart: unless-stopped

volumes:
  uptime-kuma-data:
```

Hem afegit dues claus noves:

- **`container_name`**: Assigna un nom fix al contenidor en lloc del generat automàticament.
- **`restart`**: Defineix la política de reinici. `unless-stopped` significa que el contenidor es reiniciarà automàticament excepte si l'hem aturat manualment.

Ara podem arrencar el servei:

```bash
docker compose up --detach
```

La sortida mostrarà el progrés de la descàrrega de la imatge i la creació dels recursos:

```
[+] Running 3/3
 ✔ Network uptime-kuma_default            Created
 ✔ Volume "uptime-kuma_uptime-kuma-data"  Created
 ✔ Container uptime-kuma                  Started
```

Si obrim el navegador a `http://localhost:3001` podrem veure la interfície d'Uptime Kuma, llesta per a configurar-se.

## Cicle de vida

Docker Compose proporciona un conjunt de comandes per gestionar tot el cicle de vida dels serveis. Totes s'executen des del directori on tenim el fitxer `compose.yaml`.

### Arrencada i aturada

Per arrencar tots els serveis en segon pla usarem la següent comanda:

```bash
docker compose up --detach
```

Per a arrencar els serveis i reconstruir les imatges, si cal, usarem la següent comanda:

```bash
docker compose up --detach --build
```

Per aturar tots els serveis i eliminar els contenidors usarem la següent comanda:

```bash
docker compose down
```

Per aturar tots els serveis i eliminar els contenidors i els volums usarem la següent comanda:

```bash
docker compose down --volumes
```

La diferència entre `up` i `down` és important: `up` crea i arrenca els recursos, mentre que `down` els atura i elimina. Si volem conservar les dades, no podem usar `--volumes` amb `down`.

### Gestió de serveis

Per aturar els serveis sense eliminar-los usarem la següent comanda:

```bash
docker compose stop
```

Per arrencar els serveis aturats usarem la següent comanda:

```bash
docker compose start
```

Per reiniciar els serveis usarem la següent comanda:

```bash
docker compose restart
```

Per pausar els serveis (congelar els processos) usarem la següent comanda:

```bash
docker compose pause
```

Per reprendre serveis pausats usarem la següent comanda:

```bash
docker compose unpause
```

### Monitorització

Per llistar els serveis i el seu estat usarem la següent comanda:

```bash
docker compose ps
```

Per veure els logs de tots els serveis usarem la següent comanda:

```bash
docker compose logs
```

Per veure els logs de tots els serveis en temps real usarem la següent comanda:

```bash
docker compose logs --follow
```

Per veure els logs d'un servei específic en temps real usarem la següent comanda:

```bash
docker compose logs --follow uptime-kuma
```

Per mostrar només les últimes 50 línies de logs usarem la següent comanda:

```bash
docker compose logs --tail 50
```

### Execució de comandes

Per obrir una shell dins un contenidor usarem la següent comanda:

```bash
docker compose exec uptime-kuma sh
```

Per executar una comanda concreta dins un contenidor usarem la següent comanda:

```bash
docker compose exec uptime-kuma ls -la /app/data
```

Per executar una comanda concreta dins un contenidor nou usarem la següent comanda:

```bash
docker compose run --rm uptime-kuma echo "Hola"
```

La diferència entre `exec` i `run` és que `exec` s'executa dins un contenidor ja en marxa, mentre que `run` crea un contenidor nou temporal.

### Construcció d'imatges

Per construir, o reconstruir, les imatges dels serveis usarem la següent comanda:

```bash
docker compose build
```

Per construir les imatges dels serveis sense usar la memòria cau usarem la següent comanda:

```bash
docker compose build --no-cache
```

### Opcions globals

Podem especificar un fitxer de configuració diferent durant l'execució:

```bash
docker compose -f produccio.yaml up --detach
```

I també podem especificar un projecte diferent:

```bash
docker compose -p el-meu-projecte up --detach
```

El nom del projecte serà usat per Docker Compose per asignar noms als recursos.

## Convencions de noms

Docker Compose genera automàticament noms per als recursos que crea seguint un esquema predictible basat en el nom del projecte. Per defecte, el nom del projecte és el nom del directori que conté el fitxer `compose.yaml`.

Els contenidors segueixen el patró `<projecte>-<servei>-<índex>`:

- `<projecte>`: Nom del projecte (directori o valor de `-p`).
- `<servei>`: Nom del servei definit al YAML.
- `<índex>`: Número seqüencial començant per 1.

Per exemple, si el nostre directori es diu `uptime-kuma` i tenim un servei `uptime-kuma`, el contenidor es dirà `uptime-kuma-uptime-kuma-1`. Per evitar aquesta redundància, podem usar `container_name`:

```yaml
services:
  uptime-kuma:
    container_name: uptime-kuma
    # ...
```

Quant a les xarxes, Compose crea automàticament una xarxa per defecte per a cada projecte amb el nom `<projecte>_default`. Tots els serveis es connecten a aquesta xarxa i poden comunicar-se entre ells usant el nom del servei com a hostname. Podem llistar les xarxes existents amb la següent ordre:

```bash
docker network ls
```

La sortida serà:

```
NETWORK ID     NAME                   DRIVER    SCOPE
a1b2c3d4e5f6   uptime-kuma_default    bridge    local
```

Els volums amb nom segueixen el patró `<projecte>_<nom-volum>`. Podem llistar els volums existents amb la següent ordre:

```bash
docker volume ls
```

La sortida serà:

```
DRIVER    VOLUME NAME
local     uptime-kuma_uptime-kuma-data
```

Si volem un nom de volum sense prefix, podem usar la clau `name`:

```yaml
volumes:
  uptime-kuma-data:
    name: uptime-kuma-data
```

Quan Compose construeix una imatge des d'un Dockerfile (amb `build`), li assigna el nom `<projecte>-<servei>`. Podem personalitzar-ho afegint la clau `image`:

```yaml
services:
  webapp:
    build: ./docker/webapp
    image: <el-meu-registre>/webapp:1.0
```

## Neteja

Per eliminar completament l'exemple d'Uptime Kuma, començarem aturant i eliminant els contenidors i les xarxes:

```bash
docker compose down
```

I, si també volem eliminar les dades, llavors executarem:

```bash
docker compose down --volumes
```

## Exercicis

Es proposen dos exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Grafana standalone**

En aquest execucici es proposa desplegar [Grafana](https://hub.docker.com/r/grafana/grafana) amb Docker Compose i accedir a la interfície web.

1. Creeu un directori anomenat `grafana-standalone`.
2. Dins, creau un fitxer `compose.yaml` que defineixi un servei `grafana` amb:
   - Imatge `grafana/grafana:12.4`.
   - Port 3000 mapejat al port 3000 de l'amfitrió.
   - Un volum amb nom per persistir les dades de `/var/lib/grafana`.
3. Arrencau el servei i accediu a `http://localhost:3000`/.
4. Les [credencials per defecte](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/) són `admin` / `admin`. Opcionalment, usa les variables `GF_SECURITY_ADMIN_USER` and `GF_SECURITY_ADMIN_PASSWORD` per personalitzar-les.
5. Comprovau que podeu iniciar sessió i que Grafana us demana canviar la contrasenya.

> Consulta la [plana oficial de Grafana al seu web](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/) per obtenir més informació.

{{< details summary="Respostes" >}}

Exemple de fitxer `compose.yaml`:

```yaml
services:
  grafana:
    image: grafana/grafana:12.4
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: "root"
      GF_SECURITY_ADMIN_PASSWORD: "0a6A0IhnoIHkG2l1iPVYzDYJa"

volumes:
  grafana-data:
```

Crea el directori de feina:

```bash
mkdir -p ~/Projects/grafana-standalone
cd ~/Projects/grafana-standalone
```

Crea el fitxer `compose.yaml` amb el contingut anterior i executa la comanda:

```bash
docker compose up --detach
```

Accedeix a `http://localhost:3000/` i inicia sessió amb les credencials definides.

{{< /details >}}

### Exercici 2

**Prometheus i Grafana**

En aquest exercici es proposa desplegar Prometheus i Grafana junts, configurant Grafana per usar Prometheus com a font de dades.

1. Crea un directori anomenat `prometheus-grafana` al teu directori de projectes, e.g., `~/Projects/prometheus-grafana`.
2. Crea un fitxer `compose.yaml` amb dos serveis:
   - `prometheus` amb la imatge `prom/prometheus:v3.11` al port 9090.
   - `grafana` amb la imatge `grafana/grafana:12.4` al port 3000.
3. Arrenca els serveis i comprova que pots accedir a ambdues interfícies.
4. A Grafana, afegeix Prometheus com a `Data Source`:
   - Ves a `Connections >  Data Sources > Add data source`.
   - Selecciona `Prometheus`.
   - A la URL, posa `http://prometheus:9090`.
   - Clica `Save & Test` per verificar la connexió.
5. Comprovau que la connexió és correcta.

> Els serveis dins el mateix projecte Compose es poden comunicar usant el nom del servei com a hostname. Per tant, des de Grafana, Prometheus és accessible a `http://prometheus:9090`.

{{< details summary="Respostes" >}}

Exemple de fitxer `compose.yaml`:

```yaml
services:
  prometheus:
    image: prom/prometheus:v3.11
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - prometheus-data:/prometheus
    restart: unless-stopped

  grafana:
    image: grafana/grafana:12.4
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    restart: unless-stopped

volumes:
  prometheus-data:
  grafana-data:
```

Crea el directori de feina:

```bash
mkdir -p ~/Projects/prometheus-grafana
cd ~/Projects/prometheus-grafana
```

Crea el fitxer `compose.yaml` amb el contingut anterior i executa la comanda:

```bash
docker compose up --detach
```

Accedeix a les URLs seguents:

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

A Grafana, ves a `Connections > Data Sources > Add data source > Prometheus` i instrodueix la URL `http://prometheus:9090`. El nom `prometheus` funciona perquè ambdós contenidors estan a la mateixa xarxa de Compose i Docker resol el nom del servei automàticament.

{{< /details >}}
