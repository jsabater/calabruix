---
title: "Gestió de contenidors"
date: 2026-03-29
lastmod: 2026-03-29
description: "Execució, configuració, inspecció, logs, interacció i cicle de vida dels contenidors Docker"
summary: "Execució, configuració, inspecció, logs, interacció i cicle de vida dels contenidors Docker"
categories: ["ensenyament"]
tags: ["docker", "engine", "containers", "mariadb", "adminer", "postgresql"]
series: ["Docker Engine"]
series_order: 3
weight: 30
slug: contenidors
---

A l'article anterior vàrem veure com descarregar imatges i executar contenidors de forma bàsica. En aquest article aprofundirem en la gestió del cicle de vida dels contenidors: com configurar-los, inspeccionar-los, interactuar-hi i gestionar-ne l'execució.

Per il·lustrar els conceptes, farem feina amb dos serveis: [MariaDB](https://hub.docker.com/_/mariadb), la base de dades relacional, i [Adminer](https://hub.docker.com/_/adminer), la interfície web per gestionar bases de dades.

## Execució amb configuració

La comanda `docker run` accepta moltes opcions per configurar el comportament del contenidor. Vegem les més habituals creant un contenidor de MariaDB:

```bash
docker run --name mariadb-demo \
  --env MARIADB_ROOT_PASSWORD=secret \
  --env MARIADB_DATABASE=demo \
  --env MARIADB_USER=demouser \
  --env MARIADB_PASSWORD=demopass \
  --publish 3306:3306 \
  --detach \
  mariadb:12
```

Analitzem les opcions utilitzades:

| Opció                  | Descripció                                                    |
|------------------------|---------------------------------------------------------------|
| `--name mariadb-demo`  | Assigna un nom descriptiu al contenidor                       |
| `--env VARIABLE=valor` | Defineix variables d'entorn dins del contenidor               |
| `--publish 3306:3306`  | Mapeja el port 3306 de l'amfitrió al port 3306 del contenidor |
| `--detach`             | Executa el contenidor en segon pla                            |
| `mariadb:12`           | La imatge i etiqueta a utilitzar                              |

Les **variables d'entorn** són el mecanisme estàndard per configurar contenidors. Cada imatge defineix les seves pròpies variables; en el cas de MariaDB:

- `MARIADB_ROOT_PASSWORD`: Contrasenya de l'usuari root (obligatòria).
- `MARIADB_DATABASE`: Nom d'una base de dades a crear automàticament.
- `MARIADB_USER` i `MARIADB_PASSWORD`: Usuari i contrasenya amb accés a la base de dades creada.

{{< alert >}}
Les contrasenyes en text pla a la línia de comandes queden registrades a l'historial del shell. En entorns de producció, usarem fitxers de secrets o variables d'entorn del sistema.
{{< /alert >}}

## Llistar i inspeccionar contenidors

Per veure els contenidors en execució:

```bash
docker ps
```

La sortida mostra informació bàsica de cada contenidor:

```
CONTAINER ID   IMAGE       COMMAND                  CREATED          STATUS          PORTS                    NAMES
968c157c2e0f   mariadb:12  "docker-entrypoint.s…"   30 seconds ago   Up 29 seconds   0.0.0.0:3306->3306/tcp   mariadb-demo
```

Per veure tots els contenidors, incloent els aturats, afegim l'opció `--all`:

```bash
docker ps --all
```

La comanda `docker ps --all`, o `docker ps -a`, és molt útil per diagnosticar problemes: si un contenidor s'atura immediatament després d'iniciar-se, apareixerà aquí amb l'estat `Exited`.

Per obtenir informació detallada d'un contenidor, usam `docker inspect`:

```bash
docker inspect mariadb-demo
```

Aquesta comanda retorna un document JSON amb tota la configuració del contenidor: xarxes, volums, variables d'entorn, punts de muntatge, etc. Podem filtrar la sortida amb l'opció `--format`, per exemple per obtenir només l'adreça IP del contenidor:

```bash
docker inspect \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  mariadb-demo
```

## Logs

La comanda `docker logs` és l'eina principal per consultar la sortida d'un contenidor:

```bash
docker logs mariadb-demo
```

Opcions més útils:

| Opció             | Descripció                                                  |
|-------------------|-------------------------------------------------------------|
| `--tail N`        | Mostra només les últimes N línies                           |
| `--follow` o `-f` | Segueix els logs en temps real (com `tail -f`)              |
| `--timestamps`    | Afegeix marca temporal a cada línia                         |
| `--since TEMPS`   | Mostra logs des d'un moment específic (p.ex. `--since 10m`) |

Per exemple, per seguir els logs en temps real mostrant només les últimes 20 línies:

```bash
docker logs --follow --tail 20 mariadb-demo
```

Per sortir del mode `--follow`, premem `Ctrl+C`.

## Ús de recursos

La comanda `docker stats` mostra l'ús de recursos en temps real:

```bash
docker stats mariadb-demo
```

La sortida mostra:

```
CONTAINER ID   NAME           CPU %     MEM USAGE / LIMIT     MEM %     NET I/O         BLOCK I/O        PIDS
968c157c2e0f   mariadb-demo   0.15%     89.4MiB / 15.6GiB     0.56%     1.2kB / 0B      12.3MB / 41kB    8
```

Per obtenir una captura instantània sense actualització contínua, usam `--no-stream`:

```bash
docker stats --no-stream mariadb-demo
```

Si el contenidor està aturat, totes les estadístiques mostraran zero.

## Cicle de vida

Un contenidor pot estar en diferents estats: creat, en execució, pausat, aturat o eliminat. Les comandes principals per gestionar el cicle de vida són:

| Comanda                       | Descripció                                |
|-------------------------------|-------------------------------------------|
| `docker stop mariadb-demo`    | Atura el contenidor                       |
| `docker start mariadb-demo`   | Inicia un contenidor aturat               |
| `docker restart mariadb-demo` | Atura i inicia el contenidor              |
| `docker pause mariadb-demo`   | Congela tots els processos del contenidor |
| `docker unpause mariadb-demo` | Descongela els processos del contenidor   |

La comanda `docker stop` envia primer un senyal `SIGTERM` al procés principal del contenidor, donant-li l'oportunitat de tancar-se correctament. Si el procés no s'atura en 10 segons (configurable amb `--time`), Docker envia `SIGKILL` per forçar l'aturada.

Per eliminar un contenidor aturat:

```bash
docker rm mariadb-demo
```

Per eliminar un contenidor en execució, hem d'aturar-lo primer o usar l'opció `--force`:

```bash
docker rm --force mariadb-demo
```

## Interacció

Sovint necessitam executar comandes dins d'un contenidor en execució, ja sigui per depurar problemes, consultar dades o realitzar tasques administratives.

Primer, tornem a crear el contenidor de MariaDB:

```bash
docker run --name mariadb-demo \
  --env MARIADB_ROOT_PASSWORD=secret \
  --env MARIADB_DATABASE=demo \
  --env MARIADB_USER=demouser \
  --env MARIADB_PASSWORD=demopass \
  --publish 3306:3306 \
  --detach \
  mariadb:12
```

La comanda `docker exec` permet executar comandes dins d'un contenidor en execució. Per exemple, podem executar una comanda simple:

```bash
docker exec mariadb-demo ls -la /var/lib/mysql
```

Però també podem executar comandes interactives, per exemple obrir un shell:

```bash
docker exec --interactive --tty mariadb-demo /bin/bash
```

Les opcions `--interactive` (`-i`) i `--tty` (`-t`) són necessàries per a sessions interactives:

- `--interactive`: Manté l'entrada estàndard (stdin) oberta.
- `--tty`: Assigna un pseudo-terminal (necessari per a shells i editors).

Normalment s'usen combinades com `-it`:

```bash
docker exec -it mariadb-demo /bin/bash
```

> Algunes imatges minimalistes (com les basades en Alpine o les *distroless*) no inclouen Bash. En aquests casos, usarem `/bin/sh`.

Un pic dins del contenidor, podem executar comandes com si estiguéssim en un sistema Linux normal. Les eines disponibles depenen del que estigui instal·lat a la imatge. Per sortir del shell, escrivim `exit` o premem `Ctrl+D`.

### Connexió a MariaDB

Podem connectar-nos al client de MariaDB directament:

```bash
docker exec -it mariadb-demo mariadb \
  --user=demouser --password=demopass demo
```

Un pic dins del client MariaDB, podem executar consultes SQL:

```sql
-- Mostrar les bases de dades disponibles
SHOW DATABASES;

-- Crear una taula
CREATE TABLE productes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nom VARCHAR(100) NOT NULL,
  preu DECIMAL(10,2)
);

-- Inserir dades
INSERT INTO productes (nom, preu) VALUES 
  ('Teclat mecànic', 89.99),
  ('Ratolí ergonòmic', 45.50),
  ('Monitor 27"', 299.00);

-- Consultar les dades
SELECT * FROM productes;

-- Sortir del client MariaDB
EXIT;
```

### Des de l'amfitrió

Com que hem publicat el port 3306, també podem connectar-nos des de l'amfitrió si tenim el client MariaDB instal·lat. En cas de no ser així, ho podem fer amb la següent comanda:

```bash
sudo apt-get install mariadb-client
```

Una vegada tenim el client MariaDB instal·lat, ja podem connectar-nos:

```bash
mariadb --host=127.0.0.1 --port=3306 --user=demouser \
  --password=demopass demo
```

## Còpia de fitxers

La comanda `docker cp` permet copiar fitxers entre l'amfitrió i un contenidor (en qualsevol direcció). Per exemple, per a copiar un fitxer de l'amfitió al contenidor:

```bash
docker cp fitxer.sql mariadb-demo:/tmp/fitxer.sql
```

I per a copiar un fitxer del contenidor a l'amfitió:

```bash
docker cp mariadb-demo:/var/log/mysql/error.log ./error.log
```

Per exemple, suposem que tenim un fitxer `init.sql` amb dades inicials:

```sql
-- init.sql
CREATE TABLE IF NOT EXISTS clients (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nom VARCHAR(100) NOT NULL,
  email VARCHAR(100)
);

INSERT INTO clients (nom, email) VALUES
  ('Anna García', 'anna@example.com'),
  ('Pere Martí', 'pere@example.com'),
  ('Marta Vidal', 'marta@example.com');
```

Podem copiar-lo al contenidor i executar-lo amb les següents sentències. Primer, el copiam al contenidor:

```bash
docker cp init.sql mariadb-demo:/tmp/init.sql
```

Ara ja podem executar el fitxer SQL dins del contenidor:

```bash
docker exec mariadb-demo mariadb --user=demouser \
  --password=demopass demo -e "SOURCE /tmp/init.sql"
```

I, per acabar, podem verificar que s'han creat les dades:

```bash
docker exec mariadb-demo mariadb --user=demouser \
  --password=demopass demo -e "SELECT * FROM clients"
```

## Adminer

Adminer és una eina lleugera per gestionar bases de dades des del navegador. Executem un contenidor d'Adminer connectat a la mateixa xarxa que MariaDB:

```bash
docker run --name adminer \
  --publish 8080:8080 \
  --detach \
  adminer
```

Ara podem accedir a `http://localhost:8080` des del navegador. Per connectar-nos a MariaDB des d'Adminer, necessitam saber l'adreça IP del contenidor MariaDB:

```bash
docker inspect \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  mariadb-demo
```

A la interfície d'Adminer, introduïm:

- **Sistema**: MySQL
- **Servidor**: L'adreça IP obtinguda (p.ex. `172.17.0.2`)
- **Usuari**: `demouser`
- **Contrasenya**: `demopass`
- **Base de dades**: `demo`

> A l'article sobre xarxes veurem com crear una xarxa Docker personalitzada on els contenidors es poden comunicar usant els seus noms en lloc d'adreces IP.

## Neteja

Per netejar els recursos creats durant aquesta lliçó:

```bash
docker rm --force mariadb-demo adminer
docker rmi mariadb:12 adminer
```

## Exercicis pràctics

Es proposen tres exercicis pràctics per facilitar l'aprenentatge progressiu.

### Exercici 1

**Exploració de PostgreSQL**

1. Descarrega la imatge `postgres:18-alpine`.
2. Consulta la [documentació a Docker Hub](https://hub.docker.com/_/postgres) i la [documentació oficial](https://www.postgresql.org/docs/current/libpq-envars.html) al per identificar les variables d'entorn necessàries.
3. Executa un contenidor anomenat `pg-test` amb una base de dades `biblioteca`, usuari `biblio` i contrasenya `biblio123`.
4. Connecta't al contenidor amb `docker exec` i obre el client `psql`.
5. Crea una taula `llibres` amb columnes `id`, `titol` i `autor`, i insereix un conjunt de registres.
   ```sql
   CREATE TABLE IF NOT EXISTS llibres
   (id SERIAL PRIMARY KEY, titol VARCHAR(50), autor);

   INSERT INTO llibres (titol, autor)
        VALUES (1, 'Red Sparrow', 'Jason Matthews'),
               (2, 'A Feast for Crows', 'George R. R. Martin'),
               (3, 'Foundation', 'Isaac Asimov'),
               (4, '1984', 'George Orwell'),
               (5, 'The Lord of the Rings', 'J. R. R. Tolkien'),
               (6, 'Woken Furies', 'Richard Morgan')
   ON CONFLICT (id) DO NOTHING;
   ```
6. Consulta les dades per verificar que s'han inserit correctament.
   ```sql
   SELECT * FROM llibres ORDER BY id ASC;
   ```
7. Consulta els logs del contenidor per veure els missatges d'inicialització.

Pista: Usa `psql --help` per a averiguar com connectar-te a la base de dades a través de les variables d'entorn i executar comandes SQL.

### Exercici 2

**Diagnòstic i monitorització**

Per a aquest exercici farem servir uns fitxers SQL ja preparats, que pots descarregar:

- {{< icon "download" >}} [city.sql](/docker/engine/management/city.sql): Crea la taula city amb dades de ciutats i coordenades geogràfiques (requereix PostGIS).
- {{< icon "download" >}} [student.sql](/docker/engine/management/student.sql): Crea la taula student amb dades d'estudiants.
- {{< icon "download" >}} [queries.sql](/docker/engine/management/queries.sql): Consultes SQL per generar activitat al servidor.

1. Descarrega els tres fitxers SQL.
2. Executa un contenidor PostgreSQL anomenat `pg-monitor` amb les credencials que consideris adequades.
3. Obre una nova terminal i executa `docker logs --follow pg-monitor` per veure els logs en temps real.
4. Obre una altra terminal i executa `docker stats pg-monitor` per monitoritzar l'ús de recursos.
5. Usant `docker cp `, copia els fitxers `city.sql` i `student.sql` al contenidor i executa'ls per crear les taules i inserir les dades.
6. Copia el fitxer `queries.sql` al contenidor i executa'l diverses vegades per generar activitat.
7. Observa com canvien les estadístiques de CPU i memòria.
8. Atura el monitoratge amb Ctrl+C i neteja el contenidor.

> Les consultes espacials amb PostGIS generen més càrrega de CPU que les consultes simples, cosa que facilita observar els canvis a `docker stats`.
