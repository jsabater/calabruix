---
title: "Volums i persistència"
date: 2026-04-02
lastmod: 2026-04-02
description: "Persistència de dades amb volums Docker, bind mounts i gestió del cicle de vida de les dades"
summary: "Persistència de dades amb volums Docker, bind mounts i gestió del cicle de vida de les dades"
categories: ["teaching"]
tags: ["docker", "engine", "containers", "mongodb", "valkey"]
series: ["Docker Engine"]
series_order: 4
weight: 40
slug: volums
---

Els contenidors Docker són **efímers** per disseny: quan eliminam un contenidor, totes les dades que contenia desapareixen amb ell. Això és desitjable per a molts casos d'ús (aplicacions sense estat, entorns de proves), però és un problema quan necessitam persistir dades com ara bases de dades, fitxers pujats pels usuaris o configuracions.

En aquest article veurem com els **volums** resolen aquest problema, permetent que les dades sobrevisquin al cicle de vida dels contenidors.

## La pèrdua de dades

Per il·lustrar el problema, usarem [MongoDB](https://hub.docker.com/_/mongo), una base de dades documental NoSQL. Començarem executant un contenidor sense cap volum:

```bash
docker run --name mongo-temp \
  --env MONGO_INITDB_ROOT_USERNAME=admin \
  --env MONGO_INITDB_ROOT_PASSWORD=secret \
  --detach \
  mongo:8.2
```

Connectem-nos al contenidor i creem una col·lecció amb dades:

```bash
docker exec --interactive --tty mongo-temp mongosh \
  --username admin --password secret
```

Dins del shell de MongoDB, cream una base de dades i una col·lecció:

```javascript
use botiga
```

Inserim alguns documents:

```javascript
db.productes.insertMany([
  { nom: "Teclat mecànic", preu: 89.99, estoc: 15 },
  { nom: "Ratolí ergonòmic", preu: 45.50, estoc: 30 },
  { nom: "Monitor 27 polzades", preu: 299.00, estoc: 8 }
])
```

Comprovem que les dades s'han inserit:

```javascript
db.productes.find()
```

I sortim del shell:

```javascript
exit
```

Ara eliminam el contenidor i el tornam a crear:

```bash
docker rm --force mongo-temp

docker run --name mongo-temp \
  --env MONGO_INITDB_ROOT_USERNAME=admin \
  --env MONGO_INITDB_ROOT_PASSWORD=secret \
  --detach \
  mongo:8.2
```

Si intentam consultar les dades:

```bash
docker exec -it mongo-temp mongosh --username admin \
  --password secret --eval "use botiga" \
  --eval "db.productes.find()"
```

Les dades han desaparegut. Cada vegada que eliminam i recream el contenidor, MongoDB comença amb una base de dades buida.

Netejem abans de continuar:

```bash
docker rm --force mongo-temp
```

## Volums Docker

Els **volums** són el mecanisme recomanat per persistir dades generades i utilitzades pels contenidors. Un volum és un directori gestionat per Docker que existeix fora del sistema de fitxers del contenidor.

Característiques principals:

- **Persistència**: Les dades sobreviuen a l'eliminació del contenidor.
- **Compartició**: Múltiples contenidors poden accedir al mateix volum.
- **Gestió per Docker**: Docker s'encarrega de la ubicació i els permisos.
- **Portabilitat**: Els volums es poden migrar entre amfitrions.

La comanda que permet gestionar volums és `docker volume`.

### Crear i llistar

Per crear un volum:

```bash
docker volume create mongo-data
```

Per llistar els volums existents:

```bash
docker volume ls
```

La sortida mostra:

```
DRIVER    VOLUME NAME
...
local     mongo-data
```

### Inspeccionar

Per veure informació detallada d'un volum:

```bash
docker volume inspect mongo-data
```

La sortida inclou la ubicació física del volum al sistema amfitrió:

```json
[
    {
        "CreatedAt": "2026-03-30T08:00:00Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/mongo-data/_data",
        "Name": "mongo-data",
        "Options": null,
        "Scope": "local"
    }
]
```

El camp `Mountpoint` indica on Docker emmagatzema físicament les dades del volum.

### Muntar un volum

Ara executarem MongoDB amb el volum que acabem de crear:

```bash
docker run --name mongo-persistent \
  --env MONGO_INITDB_ROOT_USERNAME=admin \
  --env MONGO_INITDB_ROOT_PASSWORD=secret \
  --volume mongo-data:/data/db \
  --detach \
  mongo:8.2
```

L'opció `--volume mongo-data:/data/db` indica:

- `mongo-data`: El nom del volum (que hem creat prèviament).
- `/data/db`: El directori dins del contenidor on es muntarà el volum (on MongoDB emmagatzema les dades).

{{< alert >}}
Si el volum no existeix quan executem `docker run --volume`, Docker el crea automàticament. Tanmateix, és bona pràctica crear-lo explícitament per tenir més control.
{{< /alert >}}

### Verificar la persistència

Ara comprovarem que les dades persisteixen. Començarem creant dades, seguint el mateix procediment que hem fet abans. En primer lloc, obrim un shell dins del contenidor:

```bash
docker exec -it mongo-persistent mongosh \
  --username admin --password secret
```

Seleccionam la base de dades `botiga`:

```javascript
use botiga
```

I inserim dades:

```javascript
db.productes.insertMany([
  { nom: "Teclat mecànic", preu: 89.99, estoc: 15 },
  { nom: "Ratolí ergonòmic", preu: 45.50, estoc: 30 },
  { nom: "Monitor 27 polzades", preu: 299.00, estoc: 8 },
  { nom: "Auriculars amb micròfon", preu: 65.00, estoc: 22 },
  { nom: "Disc SSD 1TB", preu: 79.95, estoc: 45 },
  { nom: "Memòria RAM 16GB DDR5", preu: 52.50, estoc: 18 }
])
```

Per sortir del shell, escrivim `exit` o premem `Ctrl+D`.

A continuació eliminam el contenidor i el tornam a crear amb el mateix volum:

```bash
docker rm --force mongo-persistent

docker run --name mongo-persistent \
  --env MONGO_INITDB_ROOT_USERNAME=admin \
  --env MONGO_INITDB_ROOT_PASSWORD=secret \
  --volume mongo-data:/data/db \
  --detach \
  mongo:8.2
```

Verificam que les dades encara hi són:

```bash
docker exec -it mongo-persistent mongosh --username admin \
  --password secret --eval "use botiga" \
  --eval "db.productes.find()"
```

Les dades han sobreviscut a l'eliminació i recreació del contenidor.

### Eliminar volums

Per eliminar un volum que ja no necessitem:

```bash
docker volume rm mongo-data
```

{{< alert >}}
No podem eliminar un volum que estigui en ús per un contenidor (en execució o aturat). Primer hem d'eliminar el contenidor.
{{< /alert >}}

Per eliminar tots els volums que no estiguin en ús:

```bash
docker volume prune --force
```

El paràmetre `--force` farà que Docker no demani confirmació abans d'eliminar els volums.

## Bind mounts

Els **bind mounts** són una altra manera de persistir dades. En aquest cas, en comptes d'usar un volum gestionat per Docker, muntam directament un directori de l'amfitrió dins del contenidor.

Les diferències principals:

| Característica | Volums                              | Bind mounts                                 |
|----------------|-------------------------------------|---------------------------------------------|
| Ubicació       | Gestionada per Docker[^1]           | Qualsevol directori de l'amfitrió           |
| Creació        | `docker volume create` o automàtica | El directori ha d'existir                   |
| Portabilitat   | Alta (Docker ho gestiona tot)       | Baixa (depèn de l'estructura de l'amfitrió) |
| Cas d'ús típic | Dades de producció, bases de dades  | Desenvolupament, compartir codi font        |

[^1]: Per defecte `/var/lib/docker/volumes/` a Debian/Ubuntu.

### Exemple

Suposem que volem compartir un directori de configuració amb un contenidor de [Valkey](https://hub.docker.com/r/valkey/valkey). Per fer-ho, en primer lloc crearem el directori de configuració a l'amfitrió:

```bash
mkdir --parents ~/valkey-config
```

I, en segon lloc, crearem un fitxer de configuració `~/valkey-config/valkey.conf` amb el segÜent contingut:

```ini
maxmemory 100mb
maxmemory-policy allkeys-lru
appendonly yes
```

Ara executam un contenidor Valkey muntant aquest directori:

```bash
docker run --name valkey-demo \
  --volume ~/valkey-config:/usr/local/etc/valkey:ro \
  --detach \
  valkey/valkey:9.0-alpine \
  valkey-server /usr/local/etc/valkey/valkey.conf
```

Analitzem l'opció `--volume`:

- `~/valkey-config`: Directori de l'amfitrió (ruta absoluta o relativa a home).
- `/usr/local/etc/valkey`: Directori dins del contenidor.
- `:ro`: Muntar el volum en mode només lectura (*read-only*).

{{< alert >}}
El sufix `:ro` és opcional però recomanat quan el contenidor no necessita escriure al directori, car afegeix una capa de seguretat.
{{< /alert >}}

> El paràmetre canvia la comanda per defecte que s'executarà, en aquest cas indicant que s'usi el fitxer de configuració `/usr/local/etc/valkey/valkey.conf` dins el contenidor.

Podem verificar que Valkey ha carregat la configuració:

```bash
docker exec valkey-demo valkey-cli CONFIG GET maxmemory
```

### Desenvolupament

Un cas d'ús molt comú és muntar el codi font de l'aplicació durant el desenvolupament, permetent veure els canvis sense reconstruir la imatge.

Suposem que tenim una aplicació web estàtica al directori `~/Projects/web`:

```bash
mkdir -p ~/Projects/web
cat << EOF > ~/Projects/web/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>My First HTML Page</title>
</head>
<body>
    <h1>Hola, Docker!</h1>
</body>
</html>
EOF
```

Podem servir-la amb NGINX muntant el directori:

```bash
docker run --name nginx-dev \
  --volume ~/Projects/web:/usr/share/nginx/html:ro \
  --publish 8080:80 \
  --detach \
  nginx:1.29-alpine
```

Si carregam `http://localhost:8080/` al navegador veurem el contingut de l'aplicació. Ara, si modificam el fitxer `~/Projects/web/index.html`, els canvis es reflecteixen immediatament sense reiniciar el contenidor:

```bash
sed --in-place 's|<h1>.*</h1>|<h1>Contingut actualitzat!</h1>|' \
  ~/Projects/web/index.html
```

Si recarregam la pàgina al navegador podem veure el canvi.

## Volums anònims

Quan executam un contenidor amb `--volume` especificant només el punt de muntatge dins del contenidor, Docker crea un **volum anònim**:

```bash
docker run --name mongo-anon \
  --volume /data/db \
  --detach \
  mongo:8.2
```

Docker assigna un nom aleatori al volum (una cadena hexadecimal llarga). Podem veure'l amb:

```bash
docker volume ls
```

Els volums anònims són útils per a proves ràpides, però dificulten la gestió perquè no tenen noms descriptius. És preferible usar volums amb nom.

## Inspecció de dades

De vegades necessitam accedir directament a les dades d'un volum sense passar pel contenidor. Hi ha diverses maneres de fer-ho.

Suposem que tenim tenim un volum `nginx-web` amb un contenidor NGINX que en fa ús:

```bash
docker volume create nginx-web

docker run --name nginx-temp \
  --volume nginx-web:/usr/share/nginx/html \
  --detach \
  nginx:1.29-alpine
```

**Accés amb un contenidor auxiliar**

Una forma habitual es muntar el volum en un contenidor auxiliar per inspeccionar-lo.

```bash
docker run --rm -it \
  --volume nginx-web:/data:ro \
  alpine \
  ls -la /data
```

Amb aquesta comanda, estam muntant el mateix volum que usa el contenidor `nginx-temp` en mode només lectura a `/data` d'un nou contenidor auxiliar i temporal.

L'opció `--rm` de la comanda `docker run` elimina el contenidor automàticament quan surt.

**Accés directe**

Una altra forma és accedir al directori físic del volum a l'amfitrió (requereix permisos de `root`):

```bash
sudo ls -la /var/lib/docker/volumes/nginx-web/_data
```

{{< alert >}}
L'accés directe als fitxers de Docker només s'ha de fer per a depuració. Modificar fitxers mentre un contenidor està en execució pot causar corrupció de dades.
{{< /alert >}}

## Còpies de seguretat

Per fer una còpia de seguretat d'un volum que conté fitxers estàtics (com ara pàgines web, configuracions o documents), podem usar un contenidor auxiliar que munti el volum i creï un arxiu:

```bash
docker run --rm \
  --volume nginx-web:/source:ro \
  --volume $(pwd):/backup \
  alpine \
  tar --create --gzip --file /backup/nginx-backup.tar.gz \
  --directory /source .
```

Aquesta comanda:

1. Munta el volum `nginx-web` en mode només lectura a `/source`
2. Munta el directori actual a `/backup`
3. Crea un arxiu comprimit amb el contingut del volum

Per restaurar:

```bash
docker run --rm \
  --volume nginx-web:/target \
  --volume $(pwd):/backup:ro \
  alpine \
  tar --extract --gzip --file /backup/nginx-backup.tar.gz \
  --directory /target
```

{{< alert >}}
Aquesta tècnica és adequada per a fitxers estàtics (pàgines web, configuracions, documents). Per a bases de dades, hem d'usar les eines de backup específiques de cada sistema (per exemple, mongodump per a MongoDB o pg_dump per a PostgreSQL).
{{< /alert >}}

## Neteja

Per netejar tots els recursos creats durant aquesta lliçó començarem aturant i esborrant els contenidors:

```bash
docker rm --force mongo-anon mongo-persistent mongo-temp
docker rm --force nginx-dev nginx-temp valkey-demo
```

I continuarem eliminant els volums:

```bash
docker volume rm mongo-data nginx-web
```

Per a eliminar volums no utilitzats, incloent els anònims, podem usam:

```bash
docker volume prune --force
```

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Persistència amb PostgreSQL**

1. Crea un volum anomenat `pg-biblioteca`.
2. Executa un contenidor PostgreSQL anomenat `pg-volum` que utilitzi aquest volum per emmagatzemar les dades, amb una base de dades `biblioteca`, usuari `biblio` i contrasenya `dFeWm5y2dZCP9wKKWYAe`.
3. Connecta't al contenidor i crea una taula `llibre` amb columnes `id`, `titol` i `autor`, i insereix un conjunt de registres.
4. Atura el contenidor.

> Pista: Consulta la [documentació de PostgreSQL a Docker Hub](https://hub.docker.com/_/postgres) per saber on s'emmagatzemen les dades dins del contenidor.

{{< details summary="Respostes" >}}

Creació del volum:

```bash
docker volume create pg-biblioteca
```

Creació del contenidor amb el volum:

```bash
docker run --name pg-volum \
  --env POSTGRES_PASSWORD='dFeWm5y2dZCP9wKKWYAe' \
  --env POSTGRES_USER=biblio \
  --env POSTGRES_DB=biblioteca \
  --volume pg-biblioteca:/var/lib/postgresql \
  --detach \
  postgres:18-alpine
```

Connexió al contenidor:

```bash
docker exec -it pg-volum psql --user=biblio --dbname=biblioteca
```

Creació de la taula:

```sql
CREATE TABLE IF NOT EXISTS llibre (
  id SERIAL PRIMARY KEY,
  titol VARCHAR(100),
  autor VARCHAR(100)
);
```

Inserció de registres a la taula:

```sql
INSERT INTO llibre (titol, autor)
VALUES ('Red Sparrow', 'Jason Matthews'),
       ('A Feast for Crows', 'George R. R. Martin'),
       ('Foundation', 'Isaac Asimov'),
       ('1984', 'George Orwell'),
       ('The Lord of the Rings', 'J. R. R. Tolkien'),
       ('Woken Furies', 'Richard Morgan');
```

Consulta de registres existents:

```sql
SELECT * FROM llibre ORDER BY id;
```

Aturada del contenidor:

```bash
docker stop pg-volum
```

{{< /details >}}

### Exercici 2

**Verificació de persistència**

1. Partint de l'exercici anterior, elimina el contenidor `pg-volum` sense eliminar el volum `pg-biblioteca`.
2. Crea un nou contenidor amb el mateix nom i configuració, reutilitzant el volum existent.
3. Connecta't a la base de dades i verifica que els llibres de l'exercici anterior encara hi són.
4. Insereix tres llibres nous a la taula.
5. Executa una consulta que mostri tots els llibres ordenats alfabèticament per autor.
6. Neteja tots els recursos creats (contenidor i volum).

{{< details summary="Respostes" >}}

Eliminació del contenidor:

```bash
docker rm --force pg-volum
```

Creació d'un nou contenidor amb el mateix volum:

```bash
docker run --name pg-volum \
  --env POSTGRES_PASSWORD='dFeWm5y2dZCP9wKKWYAe' \
  --env POSTGRES_USER=biblio \
  --env POSTGRES_DB=biblioteca \
  --volume pg-biblioteca:/var/lib/postgresql \
  --detach \
  postgres:18-alpine
```

Connexió al contenidor:

```bash
docker exec -it pg-volum psql --user=biblio --dbname=biblioteca
```

Verificació de les dades existents:

```sql
SELECT * FROM llibre ORDER BY id;
```

Inserció de tres llibres nous:

```sql
INSERT INTO llibre (titol, autor)
VALUES ('Brave New World', 'Aldous Huxley'),
       ('Dune', 'Frank Herbert'),
       ('Foundation and Empire', 'Isaac Asimov'),
       ('Leviathan Wakes', 'James S. A. Corey');
```

Consulta de tots els llibres ordenats per autor i títol:

```sql
SELECT id, titol, autor
FROM llibre
ORDER BY autor ASC, titol ASCq;
```

Neteja dels recursos:

```bash
docker rm --force pg-volum
docker volume rm pg-biblioteca
```

{{< /details >}}

### Exercici 3

**Bind mount per a desenvolupament web**

1. Crea un directori al teu directori `~/Projects` anomenat `webapp` amb un fitxer `index.html` que contengui una pàgina HTML bàsica amb un títol i un paràgraf.
2. Executa un contenidor Caddy (`caddy:2-alpine`) que munti aquest directori com a arrel del servidor web, publicant el port 8080.
3. Accedeix a la pàgina des del navegador a `http://localhost:8080/`.
4. Modifica el fitxer `index.html` afegint-hi més contingut i comprova que els canvis es reflecteixen sense reiniciar el contenidor.
5. Crea un subdirectori `css` amb un fitxer `estils.css` i enllaça'l des de l'HTML.
6. Verifica que el servidor serveix correctament els fitxers estàtics, inclosos els de nova creació.
7. Neteja tots els recursos creats.

> Pista: Consulta la [documentació de Caddy a Docker Hub](https://hub.docker.com/_/caddy) per saber on s'ha de muntar el directori de fitxers estàtics.

{{< details summary="Respostes" >}}

Creació del directori i el fitxer HTML:

```bash
mkdir -p ~/webapp
cat > ~/webapp/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ca">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Webapp de prova</title>
</head>
<body>
  <h1>Hola, Docker!</h1>
  <p>Aquesta pàgina es serveix des d'un contenidor Caddy.</p>
</body>
</html>
EOF
```

Execució del contenidor Caddy:

```bash
docker run --name caddy-dev \
  --volume ~/webapp:/usr/share/caddy:ro \
  --publish 8080:80 \
  --detach \
  caddy:2-alpine
```

Modificació del fitxer HTML:

```bash
cat > ~/webapp/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ca">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Webapp de prova</title>
  <link rel="stylesheet" href="css/estils.css">
</head>
<body>
  <h1>Hola, Docker!</h1>
  <p>Aquesta pàgina es serveix des d'un contenidor Caddy.</p>
  <p>El contingut s'actualitza automàticament gràcies al bind mount.</p>
</body>
</html>
EOF
```

Creació del directori CSS i el fitxer d'estils:

```bash
mkdir -p ~/webapp/css
cat > ~/webapp/css/estils.css << 'EOF'
body {
  font-family: system-ui, sans-serif;
  max-width: 800px;
  margin: 2rem auto;
  padding: 0 1rem;
  background-color: #f5f5f5;
}

h1 {
  color: #2c3e50;
}

p {
  color: #34495e;
  line-height: 1.6;
}
EOF
```

Neteja dels recursos:

```bash
docker rm --force caddy-dev
rm -rf ~/webapp
```

{{< /details >}}
