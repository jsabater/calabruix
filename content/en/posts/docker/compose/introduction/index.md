---
title: "Docker Compose fundamentals"
date: 2026-01-02
lastmod: 2026-01-02
description: ""
summary: ""
categories: ["virtualisation", "teaching"]
tags: ["docker", "compose"]
series: ["Docker Compose"]
series_order: 1
weight: 10
draft: true
---

When projects grow beyond a few containers, managing them with multiple `docker` commands quickly becomes messy. Docker Compose is a tool to define and run multi-container Docker applications using a single YAML file (by default, named `docker-compose.yml`). This configuration file describes the whole environment (services, networks and volumes) in a simple, declarative manner.

An example scenario could be a PHP application that depends on a database (PostgreSQL), a cache (Redis), and an object store (MinIO). With Compose, you describe all in a `docker-compose.yml` and start everything with:

```bash
docker compose up --detach
```

## The configuration file

Compose uses a YAML file to define how services, networks, and volumes work together. YAML is readable and declarative, meaning that you describe what you want, not how to run it. You should [familiarise yourself with the YAML syntax](https://www.redhat.com/en/topics/automation/what-is-yaml), in which indentation is crucial, as it uses spaces, not tabs.

The default name of the configuration file is `docker-compose.yml`, but you can specify a different file name using the `--file` or `-f` argument. Let's say that we have a project such as this:

```bash
myphpapp/
│
├── docker/
│   ├── apache/
│   │   └── Dockerfile
│   └── postgres/
│        └── Dockerfile
│
├── docker-compose.yml
│
├── sql/
│   ├── init.tar.gz
│   └── postgis.sql
│
└── src/
    └── info.php
```

Just taking into consideration the Apache Web Server for now, our first, basic example content of the `docker-compose.yml` file could be:

```yaml
services:
  apache:
    build:
      dockerfile: docker/apache/Dockerfile
    ports:
      - "8080:80"
```

This defines a single service `apache`, tells Compose expose port 8080 and to build it from a local `docker/apache/Dockerfile`:

```dockerfile
FROM debian:13
EXPOSE 80

# Install the necessary packages to support PHP applications
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get install --yes --no-install-recommends \
    apache2 curl libapache2-mod-php php php-curl \
    php-gd php-mbstring php-pgsql php-redis php-xml
RUN apt-get clean

# Copy the PHP application to the default Apache document root
COPY src/ /var/www/html/

# Temporary uploads directory
RUN mkdir --parents /var/www/uploads && \
    chown --recursive www-data:www-data /var/www/uploads && \
    chmod --recursive 775 /var/www/uploads

# Start Apache in the foreground
CMD ["apache2ctl", "-D", "FOREGROUND"]

HEALTHCHECK CMD curl -f http://localhost/ || exit 1
```

Let's instruct Compose to start all services in the background:

```bash
docker compose up --detach
```

We should see a lot of output, as it builds the image by following the instructions of the `docker/apache/Dockerfile`, ending in three lines similar to these ones:

```console
[+] Running 3/3
 ✔ myphpapp-apache              Built    0.0s 
 ✔ Network myphpapp_default     Created  0.1s
 ✔ Container myphpapp-apache-1  Started  0.4s
```

> Docker Compose uses the project folder name as prefix for the image, container and network names.

We can use `docker ps` to check that a container named `myphpapp-apache-1` has been created. Let's take the chance to learn how to select which columns we want to see in the output of that command:

```bash
docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
```

This should generate an output similar to this one:

```console
CONTAINER ID   IMAGE             STATUS                    NAMES
6967a9264bd4   myphpapp-apache   Up 11 minutes (healthy)   myphpapp-apache-1
```

And we can use `docker network ls` to check that a network named `myphpapp_default` has been created:

```console
NETWORK ID     NAME               DRIVER    SCOPE
54a8194f576e   bridge             bridge    local
4f8526c27950   host               host      local
3af9acc15ac1   myphpapp_default   bridge    local
f5a661f700d9   none               null      local
```

## Building images

As we have just seen, Compose can build images directly from local `Dockerfiles`, just like `docker build`:

```yaml
services:
  apache:
    build:
      context: docker/apache
      dockerfile: Dockerfile
```

But we can also use `image` instead of `build` if we want to use a pre-built image.

```yaml
services:
  redis:
    image: redis:8.2
```
## Naming conventions

Docker Compose automatically generates names for the resources it creates, such as containers, images, volumes, and networks, following a predictable naming scheme.

Understanding this nomenclature helps you identify, manage, and troubleshoot these resources more effectively, especially when running multiple projects or environments on the same host.

The following subsections describe the default naming conventions used by Docker Compose for each type of resource.

### Containers

By default, Docker Compose names each container following the pattern `<project>_<service>_<index>`, where:

* `<project>` is the Compose project name, derived from the directory name that contains the `docker-compose.yml`, unless overridden with `-p` or  `--project-name`.
* `<service>` is the service name from the Compose file, e.g., `apache`.
* `<index>` is a sequential number starting at `1`, used if multiple containers of the same service are created, e.g., with `scale` or replicas.

We can customise the name assigned to the container by using the `container_name` key under the `service:` key in the `docker-compose.yml` file. For example:

```yaml
services:
  apache:
    container_name: myphpapp-webserver
    build:
      dockerfile: docker/apache/Dockerfile
```

### Images

Docker Compose automatically builds an image with a generated name following the `<project>_<service>` pattern, where:

* `<project>` is the project name, derived from:
  * the name of the directory where your `docker-compose.yml` lives, or
  * the value passed via `--project-name` or `-p` when running docker compose up.
* `<service>` is the name of the service in the YAML (e.g., `apache`).

To give the built image a custom name (and optional tag), use the `image:` key alongside `build:`:

```yaml
services:
  apache:
    build:
      dockerfile: docker/apache/Dockerfile
    image: myphpapp/apache:latest
```

### Volumes

When you define a named volume in your `docker-compose.yml` (under `volumes:`) but do not explicitly give it a `name:` property, Docker Compose will generate the actual Docker volume name by prefixing the *project name* (by default the directory name) and an underscore, followed by the volume key.

We can override this default behaviour by using the `name:` key:

```yaml
volumes:
  data:
    name: myvolume
```

In this case, Docker Compose will create a volume named `myvolume`, i.e., not prefixed by the project name.

> Bind mounts (host directory to container path) are not treated as named volumes in this scheme.

### Networks

If you do not define custom networks in your Compose file, Docker Compose will automatically create a default network for all services in the project. The default network name is `<project>_default`, where `<project>` is, again, the directory name by default.

If you explicitly define a network under `networks:` in your Compose file and do not provide a `name:` property, the Compose-generated name follows the same prefix pattern.

If you want to have a custom name for your network, use the following:

```yaml
networks:
  backend:
    name: custom-backend
```

## Defining services

A service is the equivalent of a container definition. It defines what image to use, what ports to expose, what environment variables to use, the dependencies is has, etc. Each service represents one part of your application stack. For example:

```yaml
services:

  apache:
    build:
      dockerfile: docker/apache/Dockerfile
    image: myphpapp/apache
    ports:
      - "8080:80"
    volumes:
      - ./src:/var/www/html
    depends_on:
      - postgres
      - redis
      - minio

  postgres:
    build:
      dockerfile: docker/postgres/Dockerfile
    image: myphpapp/postgres
    environment:
      POSTGRES_USER: demouser
      POSTGRES_PASSWORD: mypassword
      POSTGRES_DB: demodb
    volumes:
      - postgres:/var/lib/postgresql/data

  redis:
    image: redis:8.2

  minio:
    image: minio/minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: miniouser
      MINIO_ROOT_PASSWORD: miniopasswd
    volumes:
      - minio:/data
    command: server /data --console-address ":9001"

volumes:
  postgres:
  minio:

networks:
  myphpapp:
```

This `docker-compose.yml` file:

* Defines four services, two built from `Dockerfiles` (`apache` and `postgres`), and two using external images.
* Defines and makes use of two named volumes (`postgres-data` and `minio-data`) to persist data for PostgreSQL and MinIO.
* Specifies dependencies to ensure that the database, cache, and object storage start before Apache.
* Defines a bind mount in the `apache` service so that changes to the PHP source code are reflected immediately without rebuilding the image [^1].

[^1]: This makes the `COPY` instruction in the `Dockerfile` of the `apache` service redundant, although it will not break anything.

> Regarding the bind mount, it needs to include the relative path `./` in the host part. Otherwise, Docker Compose will look for a named volume `src`, which we have not defined under `volumes:`.

For this example to work, we require the `docker/postgres/Dockerfile`:

```dockerfile
FROM postgres:17
EXPOSE 5432
RUN apt-get update && \
    apt-get install --yes --no-install-recommends postgresql-17-postgis-3 && \
    apt-get clean
COPY sql/postgis.sql /docker-entrypoint-innitdb.d/
ADD sql/init.tar.gz /docker-entrypoint-initdb.d/
```

The file `sql/postgis.sql` is used to create the PostGIS extension in PostgreSQL:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

This is a feature of the `postgres` image, not Docker or Docker Compose, by which all `.sql` files inside `/docker-entrypoint-innitdb.d/` are executed upon the initial run of the container.

Because we are using both `build:` and `image:` keys at the same time, in order to prevent warnings in our logs, it may be convenient to separate the build phase from the execution phase:

```bash
docker-compose build
docker-compose up -d
```

> Bind mounts will not work on mounted volumes, like pCloud or NFS.

### Docker CLI

For reference, next you have the equivalent commands, using the Docker CLI, to the `docker-compose.yml` file above:

```bash
docker network create myphpapp_default

docker volume create myphpapp_postgres
docker volume create myphpapp_minio

docker build --file docker/postgres/Dockerfile \
             --tag myphpapp/postgres .
docker build --file docker/apache/Dockerfile \
             --tag myphpapp/apache .

docker run --name myphpapp-postgres \
  --network myphpapp_default \
  -e POSTGRES_PASSWORD=mypassword \
  -e POSTGRES_USER=demouser \
  -e POSTGRES_DB=demodb \
  -p 5432:5432 \
  -v myphpapp_postgres:/var/lib/postgresql/data \
  -d myphpapp/postgres

docker run --name myphpapp-redis \
  --network myphpapp_default \
  -d redis:8.2

docker run --name myphpapp-minio \
  --network myphpapp_default \
  -e MINIO_ROOT_USER=miniouser \
  -e MINIO_ROOT_PASSWORD=miniopasswd \
  -p 9000:9000 \
  -p 9001:9001 \
  -v myphpapp_minio:/data minio/minio
  -d minio/minio \
  server /data --console-address ":9001"

docker run --name myphpapp-apache \
  --network myphpapp_default \
  -p 8080:80 \
  -v ./src:/var/www/html \
  -d myphpapp/apache
```
