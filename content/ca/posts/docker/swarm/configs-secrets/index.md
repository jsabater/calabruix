---
title: "Configuració i secrets a Docker Swarm"
date: 2026-02-11
lastmod: 2026-04-12
description: "Gestió segura de configuració i credencials amb Docker Configs i Docker Secrets"
summary: "Gestió segura de configuració i credencials amb Docker Configs i Docker Secrets"
categories: ["teaching"]
tags: ["docker", "swarm", "secrets", "config"]
series: ["Docker Swarm"]
series_order: 8
weight: 80
slug: configuracio-secrets
---

Totes les aplicacions necessiten valors de configuració, fitxers de configuració i credencials. Quan desplegam una aplicació en un clúster, la configuració ha d'estar disponible a qualsevol node on s'executi el servei. En aquest context, les solucions tradicionals presenten certs inconvenients:

| Mètode                  | Problema                                              |
|:------------------------|:------------------------------------------------------|
| Variables d'entorn      | Visibles amb `docker inspect`, no aptes per a secrets |
| Bind mounts             | El fitxer ha d'existir a tots els nodes               |
| Imatges personalitzades | Cal reconstruir la imatge per cada canvi              |
| Repositoris de codi     | Les credencials no s'han de ser mai part del codi     |

A més de les ja conegudes variables d'entorn, Docker Swarm proporciona dos mecanismes addicionals i específics per a gestionar aquesta informació de forma segura i distribuïda:

* **Docker Configs** per a fitxers de configuració amb dades no sensibles.
* **Docker Secrets** per a dades confidencials.

Docker Swarm distribueix automàticament els **configs** i els **secrets** als nodes que els necessiten.

> Les variables d'entorn que ja gestionàvem via `environment:` a Docker Compose continuen estan disponibles.

## Docker Configs

Els **configs** permeten emmagatzemar fitxers de configuració amb dades no sensibles al clúster i distribuir-los als serveis que els necessitin.

Tenim tres formes de crear una configuració:

* Des d'un fitxer.
  ```bash
  docker config create nginx_config nginx.conf
  ```

* Des de l'entrada estàndard.
  ```bash
  echo "DEBUG=true" | docker config create app_debug -
  ```

* Des d'un fitxer amb etiquetes.
  ```
  docker config create --label env=prod \
    traefik_config traefik.yml
  ```

Les configuracions, és clar, es poden llistar i inspeccionar. Per a llistar-les usarem la següent comanda:

```bash
docker config ls
```

A l'hora d'inspeccionar-les podem triar veure els detalls sense el contingut o amb el contingut, codificat en base 64:

```bash
# Veure els detalls sense el contingut
docker config inspect nginx_config

# Veure els detalls amb el contingut codificat en Base64
docker config inspect --pretty nginx_config
```

> El contingut de les configuracions és accessible per a qualsevol usuari amb permisos sobre el clúster. Per tant, no és adequat utilitzar-les per a dades sensibles.

Per fer ús d'una configuració a l'hora de crear el servei usarem el paràmetre `--config`:

```bash
docker service create \
  --name proxy \
  --config source=nginx_config,target=/etc/nginx/nginx.conf \
  nginx:alpine
```

El fitxer es munta a la ruta especificada dins el contenidor. Per defecte el seu propietari serà `root` i el fitxer tendrà permisos `0444` (només lectura). Si no s'especifica la ruta a través del `target`, es crearà a l'arrel (`/`).

Si volem especificar el propietari i els permisos ho podem fer al mateix paràmetre `--config`:

```bash
docker service create \
  --name app \
  --config source=app_config,target=/app/config.yml,uid=1000,gid=1000,mode=0440 \
  myapp:latest
```

Les configuracions són **immutables**, és a dir, no es poden modificar un cop creades. Per actualitzar la configuració d'un servei cal:

1. Crear una nova configuració amb el contingut actualitzat.
   ```bash
   docker config create nginx_config_v2 nginx-updated.conf
   ```

2. Actualitzar el servei per usar la nova configuració.
   ```bash
   docker service update \
   --config-rm nginx_config \
   --config-add source=nginx_config_v2,target=/etc/nginx/nginx.conf \
   proxy
   ```
3. Opcionalment, eliminar la configuració antiga.
   ```bash
   docker config rm nginx_config
   ```

No hi ha manera d'evitar aquest ball de noms amb Docker Configs. És una de les limitacions del disseny. Per aquest motiu, més endavant passarem a usar [Traefik](https://traefik.io/traefik) en comptes d'NGINX.

## Docker Secrets

Els **secrets** són similars a les configuracions, però dissenyats per a dades sensibles. Les diferències principals es resumeixen a la següent taula:

| Aspecte                      | Configs                      | Secrets           |
|:-----------------------------|:-----------------------------|:------------------|
| Xifratge en repòs            | No                           | Sí (al Raft log)  |
| Transmissió                  | Canal xifrat TLS             | Canal xifrat TLS  |
| Emmagatzematge al contenidor | Fitxer al sistema de fitxers | `tmpfs` (memòria) |
| Visibilitat amb `inspect`    | Contingut visible            | Contingut ocult   |

Raft és l'algoritme de consens que usen els nodes gestors de Docker Swarm per mantenir un estat consistent del clúster. Quan fem un canvi, el líder del clúster propaga aquest canvi a la majoria dels gestors abans de confirmar-lo. El Raft log és el registre on s'emmagatzemen tots aquests canvis de forma ordenada.

Quan deim que els secrets estan xifrats al *Raft log*, significa que les dades sensibles es guarden xifrades en aquest registre distribuït entre els gestors, de manera que ni accedint directament al disc d'un node gestor es podrien llegir en clar.

Comencem per crear un secret. Tenim dues formes:

* Des d'un fitxer.
  ```bash
  docker secret create db_password db_password.txt
  ```

* Des de l'entrada estàndard.
  ```bash
  echo "MyS3cr3tP@ssw0rd" | docker secret create db_password -
  ```

Podem usar OpenSSL per a generar secret aleatoris. La següent comanda genera una cadena de caràcters alfanumèrics, eliminant `/`, `=` i `+` perquè són part de l'alfabet [Base64](https://ca.wikipedia.org/wiki/Base64):

```bash
openssl rand -base64 25 | tr --delete /=+ | cut --characters -32
```

> Evita passar secrets com a arguments de línia de comandes, ja que queden registrats a l'historial del terminal. Usa l'entrada estàndard o fitxers temporals que eliminis immediatament.

Anàlogament a les configuracions, també podem llistar i inspeccionar secrets. Per a llistar tots els secrets usarem la següent comanda:

```bash
docker secret ls
```

Per a inspeccionar-les usarem la següent comanda, la qual mostra les metadades, però no el contingut, que no es mostra mai:

```bash
docker secret inspect db_password
```

Per fer ús d'un secret en un servei usarem el paràmetre `--secret`:

```bash
docker service create \
  --name api \
  --secret db_password \
  myapp:latest
```

Per defecte, el secret es munta a `/run/secrets/<nom_secret>`. Com que l'aplicació haurà de llegir el contingut d'aquest fitxer, ens convé especificar la ruta i els permisos:

```bash
docker service create \
  --name api \
  --secret source=db_password,target=/app/secrets/db_pass,uid=1000,gid=1000,mode=0400 \
  myapp:latest
```

Per tant, cal destacar que serà necessari preparar la nostra aplicació per ser desplegada dins un entorn Docker Swarm. Exemple de *helper* amb Python:

```python
def get_secret(name):
    try:
        with open(f'/run/secrets/{name}', 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        return None

db_password = get_secret('db_password')
```

Per aquest motiu, moltes imatges oficials suporten el patró `*_FILE` per a variables d'entorn:

```yaml
services:
  db:
    image: postgres:18
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
```

**Actualitzar un secret**

Els secrets, com els configs, són immutables. Per actualitzar-los cal:

1. Crear el nou secret.
   ```bash
   docker secret create postgres_password_v2 new_db_password.txt
   ```

2. Actualitzar el servei usant el nou secret.
   ```bash
   docker service update \
     --secret-rm postgres_password \
     --secret-add source=postgres_password_v2,target=/run/secrets/postgres_password_v2 \
     myapp_postgres
   ```

3. Opcionalment, eliminar el secret antic.
   ```bash
   docker secret rm postgres_password
   ```

## Fitxers stack

La forma més habitual de gestionar configuracions i secrets és dins el fitxer YAML de l'stack. Un exemple de definició bàsica seria el següent:

```yaml
services:
  web:
    image: nginx:alpine
    configs:
      - source: nginx_config
        target: /etc/nginx/nginx.conf
        uid: "1000"
        gid: "1000"
        mode: "0440"
    secrets:
      - source: db_password
        uid: "1000"
        gid: "1000"
        mode: "0400"

configs:
  nginx_config:
    file: ./nginx.conf

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

Quan definim configuracions i secrets al fitxer stack, Docker Swarm segueix un procés en dos passos: primer crea els objectes al clúster (llegint els fitxers locals), i després els distribueix als contenidors que els necessiten.

D'una banda, les seccions `configs` i `secrets` a nivell superior del fitxer anterior defineixen quines configuracions i secrets existeixen i d'on provenen. Quan executam `docker stack deploy`, Docker llegeix els fitxers indicats i crea els objectes al clúster.

Per tant, aquest bloc en YAML:

```yaml
configs:
  nginx_config:
    file: ./nginx.conf

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

És equivalent a executar manualment:

```bash
docker config create nginx_config ./nginx.conf
docker secret create db_password ./secrets/db_password.txt
```

A partir d'aquest moment, els fitxers originals ja no són necessaris: el contingut queda emmagatzemat al clúster (específicament, al *Raft log* dels managers) i es distribuirà automàticament a qualsevol node que l'hagi de menester.

D'altra banda, les seccions `configs` i `secrets` dins dels serveis indiquen quins serveis necessiten quines configuracions i quins secrets, i on es muntaran dins del contenidor. El paràmetre `source` referencia el nom definit a la secció superior, mentre que `target` especifica la ruta dins el contenidor.

```yaml
services:
  web:
    image: nginx:alpine
    configs:
      - source: nginx_config
        target: /etc/nginx/nginx.conf
    secrets:
      - source: db_password
```

Pels secrets, si no s'especifica `target`, es munten a `/run/secrets/<nom>`. Per tant, `db_password` serà accessible a `/run/secrets/db_password`. Per les configuracions, si no s'especifica `target`, es munten a `/run/configs/<nom>`.

**Cicle de vida de configs i secrets**

El següent diagrama reflexa el cicle de vida de configuracions i secrets en un procés de desplegament a Docker Swarm:

{{< mermaid >}}
%%{init: {'theme': 'base'}}%%
flowchart LR
    A["Deploy"] --> B["Llegeix<br>fitxers<br>locals"]
    B --> C["Crea<br>objectes<br>al clúster"]
    C --> D["Distribueix<br>als nodes"]
    D --> E["Munta<br>dins els<br>contenidors"]   
{{< /mermaid >}}

> Quan canviem la configuració de secrets d'un servei, encara que la imatge i el codi siguin idèntics, Swarm ho detecta com un canvi de configuració i fa un rolling update de les tasques afectades.

**Configs i secrets externs**

Per defecte, quan definim un secret o configuració al fitxer stack amb `file:`, Docker Swarm el crea automàticament durant el desplegament:

```yaml
secrets:
  db_password:
    # Docker llegeix aquest fitxer i crea el secret
    file: ./secrets/db_password.txt
```

Això implica que el fitxer `db_password.txt` ha d'existir a la màquina des d'on executam `docker stack deploy`. Si la configuració o secret ja existeix al clúster, llavors podem usar la clau `external: true` per a marcar-lo com a tal.

```yaml
secrets:
  db_password:
    external: true  # El secret ja existeix, no el creïs
```

Això implica que, prèviament a l'execució de la comanda `docker stack deploy`, haurem executat l'ordre següent:

```bash
docker secret create db_password db_password.txt
```

> La pràctica recomanada és usar `external: true` amb inicialització prèvia. Usar `file:` té sentit en entorns de proves locals o demostracions ràpides on la seguretat no és prioritària.

Ens interessa usar aquesta clau `external` quan volem evitar que el secret hagi d'existir al repositori o a la màquina des de la qual es faci el desplegament. En aquest context, el flux de desplegament seria el següent:

1. L'administrador de sistemes crea els secrets al clúster una sola vegada, des d'una màquina segura, idealment usant una bòveda.
2. Els desenvolupadors fan `docker stack deploy` sense tenir accés als valors reals dels secrets.
3. El fitxer `docker-stack.yml` pot formar part del repositori sense cap risc, car només referencia secrets que ja existeixen al clúster.

Sense `external: true`, caldria tenir el fitxer `./secrets/db_password.txt` disponible cada pic que es fes un desplegament, cosa que és un risc de seguretat.

> Si desplegam des d'un conducte CI/CD, llavors els secrets hauran d'estar guardats a qualque bòveda accessible des de la *pipeline*.

## Desenvolupament

Per al nostre entorn de desenvolupament seguirem usant el fitxer `docker-compose.yml`. En aquest entorn carregarem tots els valors via variables d'entorn, des del fitxer `.env`. No cal Docker Secrets perquè no hi ha requisits de seguretat, ni Docker Configs perquè ja tenim els fitxers al nostre disc. Així simplificam el flux.

```yaml
# docker-compose.yml
services:
  web:
    build:
      dockerfile: docker/app/Dockerfile
    image: myapp
    environment:
      - DEBUG=true
      - ALLOWED_HOSTS=localhost,127.0.0.1
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=myapp
      - SECRET_KEY=${SECRET_KEY}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - .:/app  # Codi font per a hot-reload
    ports:
      - "8000:8000"

  postgres:
    image: postgres:18
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
```

## Producció

Per al nostre entorn de producciód usarem un nou fitxer, que anomenarem `docker-stack.yml`. En aquest fitxer farem ús de la clau `environment:` per a definir variables d'entorn, de la clau `configs:` per a definir fitxers de Docker Configs i de la clau `secrets:` per a definir fitxers de Docker Secrets. Així aprofitam al màxim la potència de Docker Swarm.

```yaml
# docker-stack.yml
services:
  web:
    image: username/myapp:${VERSION:-latest}
    environment:
      - DEBUG=false
      - ALLOWED_HOSTS=exemple.com,www.exemple.com
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=myapp
    secrets:
      - source: myapp_secret_key
        target: /run/secrets/SECRET_KEY
      - source: myapp_postgres_user
        target: /run/secrets/POSTGRES_USER
      - source: myapp_postgres_password
        target: /run/secrets/POSTGRES_PASSWORD
    deploy:
      replicas: 3

  postgres:
    image: postgres:18-alpine
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER_FILE=/run/secrets/postgres_user
      - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
    secrets:
      - postgres_user
      - postgres_password
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.db == true

secrets:
  myapp_secret_key:
    external: true
  myapp_postgres_user:
    external: true
  myapp_postgres_password:
    external: true
  postgres_user:
    external: true
  postgres_password:
    external: true
```

Com ja hem vist en apartats anteriors, abans de fer el deploy crearem els secrets al clúster:

```bash
docker secret create django_secret_key django_secret_key.txt
docker secret create postgres_password postgres_password.txt
```

## Fitxers separats

Es presenten a continuació els motius pels quals aquesta sèrie d'articles recomana usar fitxers separats (`docker-compose.yml` per a desenvolupament, `docker-stack.yml` per a producció) per a cada entorn (en comptes d'overrides de Compose):

1. Cada fitxer és complet i autocontingut (claredat).
2. Separació de diferències estructurals.
   * Docker Compose usa `build:` per a la generació d'imatges, `volumes:` per al codi font i `ports:` per a la publicació de ports (per a facilitar la depuració).
   * Docker Stack  usa `deploy:` per a la configuració de paràmetres de desplegament, `configs:` per als fitxers de configuració i `secrets:` per als secrets.
3. Cada fitxer s'usa des de comandes diferentes:
   * Docker Compose s'executa amb `docker compose up` i usa `docker-compose.yml`.
   * Docker Swarm s'executa amb `docker stack deploy` i usa `docker-stack.yml`.
4. No hi ha risc de desplegar accidentalment una configuració de desenvolupament a producció.

> Quant a la publicació de ports, a producció només Traefik exposa ports (80 i 443). La resta de serveis són accessibles únicament dins de la xarxa interna del clúster.

## Resum

Bones pràctiques de seguretat:

* **Mai** pugis secrets al repositori de codi.
* Usa `external: true` per a secrets en producció.
* Limita els permisos dels fitxers de secrets (mode `0400`).
* Genera secrets aleatoris amb `openssl`.
* Rota els secrets periòdicament.

Bones pràctiques d'organització:

* Usa prefixos o sufixos per versionar: `nginx_config_v2`, `db_password_prod`.
* Documenta quins serveis usen cada secret.
* Manté un inventari de secrets (sense els valors!) al repositori.

Bones pràctiques d'entorns de desenvolupament i producció:

* Usa fitxer `.env` per a desenvolupament local.
* Usa secrets externs per a producció.
* El codi ha de suportar ambdós mecanismes.

Resum de comandes:

| Comanda                           | Funció                         |
|:----------------------------------|:-------------------------------|
| `docker config create NOM FITXER` | Crea un config des d'un fitxer |
| `docker config ls`                | Llista tots els configs        |
| `docker config inspect NOM`       | Mostra detalls d'un config     |
| `docker config rm NOM`            | Elimina un config              |
| `docker secret create NOM FITXER` | Crea un secret des d'un fitxer |
| `docker secret ls`                | Llista tots els secrets        |
| `docker secret inspect NOM`       | Mostra metadades d'un secret   |
| `docker secret rm NOM`            | Elimina un secret              |
| `--config source=X,target=Y`      | Munta un config en un servei   |
| `--secret source=X,target=Y`      | Munta un secret en un servei   |

## Exercici pràctic

L'objectiu d'aquest exercici és practicar la gestió de configs i secrets en un entorn Docker Swarm.

Requisits:

* Un clúster Docker Swarm amb almenys 2 nodes.
* Connectivitat de xarxa entre els nodes.

Tasques:

1. **Crear configs**:
   * Crea un fitxer `index.html` amb contingut personalitzat.
   * Crea un config anomenat `web_index` amb aquest fitxer.
   * Verifica que el config s'ha creat amb `docker config ls`.

2. **Usar configs en un servei**:
   * Crea un servei nginx que munti el config a `/usr/share/nginx/html/index.html`.
   * Publica el port 8080.
   * Verifica que el contingut es serveix correctament.

3. **Actualitzar un config**:
   * Modifica el fitxer `index.html`.
   * Crea un nou config `web_index_v2`.
   * Actualitza el servei per usar el nou config.
   * Verifica el canvi i elimina el config antic.

4. **Crear secrets**:
   * Genera una contrasenya aleatòria.
   * Crea un secret `db_password` amb aquesta contrasenya.
   * Crea un secret `api_key` amb el valor `my-api-key-12345`.
   * Llista els secrets i verifica que el contingut no és visible.

5. **Usar secrets en un servei**:
   * Crea un servei amb la imatge `hashicorp/http-echo` que mostri els secrets.
   * Munta `db_password` a `/run/secrets/db_password`.
   * Executa `docker exec` per verificar que el fitxer existeix i conté el valor correcte.

6. **Stack amb configs i secrets**:
   * Crea un fitxer `docker-stack.yml` amb:
     * Un servei nginx amb un config per a `index.html`.
     * Un servei de base de dades (postgres) que usi un secret per a la contrasenya.
   * Desplega l'stack i verifica que ambdós serveis funcionen.

7. **Secrets externs**:
   * Elimina l'stack anterior.
   * Modifica el fitxer stack per usar secrets externs (`external: true`).
   * Crea els secrets manualment amb `docker secret create`.
   * Torna a desplegar l'stack.

8. **Neteja**:
   * Elimina l'stack.
   * Elimina tots els configs i secrets creats.
