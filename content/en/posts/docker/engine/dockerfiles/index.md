---
title: "Working with multiple Dockerfiles"
date: 2026-01-02
lastmod: 2026-01-02
description: ""
summary: ""
categories: ["virtualisation"]
tags: ["docker", "engine"]
series: ["Docker"]
series_order: 9
weight: 90
draft: true
---

Because we are now going to work with more than one container, properly organising the contents of our project becomes a must. It is best practice to organise the `Dockerfiles` into separate subdirectories, each dedicated to a specific service or component. This approach provides clarity and scalability, and makes it easy to maintain.

Let's say that we are planning on having a PHP application that:

* Runs on [Apache Web Server](https://httpd.apache.org/).
* Uses [PostgreSQL](https://postgresql.org/) as database server.
* Uses [MinIO Object Store](https://min.io/) to store media files.
* Uses [Redis](https://redis.io/) in-memory database to cache data.

We would organise our project as follows:

```bash
myphpapp/
│
├── docker/
│   ├── apache/
│   │   └── Dockerfile
│   ├── postgres/
│   │   └── Dockerfile
│   ├── minio/
│   │   └── Dockerfile
│   └── redis/
│       └── Dockerfile
│
└── src/
    └── info.php
```

The `src/` directory contains the source code of the PHP application. For our demonstration, we will create a simple `info.php` file with the following content:

```php
<?php
  phpinfo();
?>
```

In order to acomplish this, we will be creating four `Dockerfiles`, two volumes and one network. Let's start with the network:

```bash
docker network create myphpapp-network
```

And now let's create the volumes, one for the PostgreSQL database, one for our files on MinIO:

```bash
docker volume create myphpapp-postgres
docker volume create myphpapp-minio
```

In case we want to start by uploading images directly on the filesystem and leave the integration with an S3 object storage for later, we could also create another volume, which we would delete when not in use anymore:

```bash
docker volume create myphpapp-uploads
```

Volumes and networks are not defined in `Dockerfiles`, but handled via the `docker` command. This separation ensures `Dockerfiles` are used to build images only, while volumes and networks are managed at runtime.

We are now ready to define our `Dockerfiles`.

## PostgreSQL

Let's start with the PostgreSQL container:

```dockerfile
# docker/postgres/Dockerfile
FROM postgres:17
EXPOSE 5432
RUN apt-get update && \
    apt-get install --yes --no-install-recommends postgresql-17-postgis-3 && \
    apt-get clean
COPY init.sql /docker-entrypoint-initdb.d/
```

The `postgres:17` image already includes an `ENTRYPOINT` instruction that automatically starts the PostgreSQL server daemon when the container is run, therefore a `CMD` instruction is not required. You can check how it works by examining the `Dockerfile-debian.template` file in [their source code](https://github.com/docker-library/postgres).

Moreover, it also includes the `EXPOSE 5432` instruction, so it is redundant.

We will use an `init.sql` file to enable the PostGIS extension into our application database:

```sql
-- init.sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

We can now build the image:

```bash
docker build --tag myphpapp-postgres:latest .
```

Once built, we can run the container:

```bash
docker run --name myphpapp-postgres \
  --network myphpapp-network \
  --volume "myphpapp-postgres:/var/lib/postgresql/data" \
  --env POSTGRES_PASSWORD=myphpapp \
  --env POSTGRES_USER=myphpapp \
  --env POSTGRES_DB=myphpapp \
  --publish 5432:5432 \
  --detach myphpapp-postgres:latest
```

## Redis

Let's continue with the Redis container:

```dockerfile
# docker/redis/Dockerfile
FROM redis:8.2
EXPOSE 6379
CMD ["redis-server"]
```

The image `redis:8.2` already includes a `CMD` instruction, so we do not need to include it unless we need to use specific parametre values. Moreover, it also includes the `EXPOSE 6379` instruction, so it is also redundant.

Let's build the image:

```bash
docker build --tag myphpapp-redis:latest .
```

And run the container:

```bash
docker run --name myphpapp-redis \
  --network myphpapp-network \
  --env REDIS_PASSWORD=myphpapp \
  --publish 6379:6379 \
  --detach myphpapp-redis:latest
```

All in all, unless we needed to customise the base image, we could skip the `Dockerfile` and go straight to running the container using the `redis:8.2` image.

## MinIO

Now it is the turn for the S3-compatible object storage using MinIO. Let's craft a `Dockerfile`:

```dockerfile
# docker/minio/Dockerfile
FROM minio/minio:latest
EXPOSE 9000
EXPOSE 9001
CMD ["server", "--address", ":9000", "--console-address", ":9001", "/data"]
```

The image `minio/minio` already includes a `CMD` instruction, so we do not need to include it unless we need to use specific parametre values. The `address` and `console-address` arguments in the `CMD` instruction above are default values, shown there just to demonstrate how it would work.

Moreover, it also includes `EXPOSE` instructions for ports 9000 and 9001, which correspond to the MinIO API and console interfaces, respectively, so they are also redundant.

Let's build the image:

```bash
docker build --tag myphpapp-minio:latest .
```

And run the container:

```bash
docker run --name myphpapp-minio \
  --network myphpapp-network \
  --volume "myphpapp-minio:/data" \
  --env MINIO_ROOT_USER=miniouser \
  --env MINIO_ROOT_PASSWORD=miniopasswd \
  --publish 9000:9000 \
  --publish 9001:9001 \
  --detach myphpapp-minio:latest
```

All in all, unless we needed to customise the base image, we could skip the `Dockerfile` and go straight to running the container using the `minio/minio:latest` image.

Incidentally, whenever you need to setting up buckets and service accounts, start with these commands, which set a local alias and validate server information:

```bash
mc alias set local http://localhost:9000 miniouser miniopasswd
mc admin info
```

You will need to perform these operations from inside the container:

```bash
docker exec -it myphpapp-minio /bin/bash
```

You can find the rest of commands in the [documentation of the MinIO CLI](https://docs.min.io/enterprise/aistor-object-store/reference/cli/).

## Apache

Finally, let's create a `Dockerfile` for our Apache HTTP server with PHP support, where we will run our web application:

```dockerfile
# docker/apache/Dockerfile
FROM debian:13
LABEL maintainer="Jaume Sabater <jsabater@example.com>"
EXPOSE 80

# Install the necessary packages to support PHP applications
# The installation script for the libapache2-mod-php already enables the mod
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    apache2 \
    curl \
    libapache2-mod-php \
    php \
    php-curl \
    php-gd \
    php-mbstring \
    php-pgsql \
    php-redis \
    php-xml

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

You absolutely need this at the end — Debian’s apache2 package installs a systemd service by default, but containers don’t use systemd.
So you must manually tell Apache to stay in the foreground; otherwise the container exits immediately.

Let's build the image. While at the project root, run this command:

```bash
docker build --file docker/apache/Dockerfile --tag myphpapp-apache:latest .
```

And run the container:

```bash
docker run --name myphpapp-apache \
  --network myphpapp-network \
  --volume myphpapp-uploads:/var/www/uploads \
  --publish 8080:80 \
  --detach myphpapp-apache:latest
```

> The first port in the mapping is the external port (the port on the host), whereas the second port is the port inside the Docker container.

You can now check that Apache is correctly serving PHP files by loading the URL `http://localhost:8080/info.php` on your browser.

For future reference, whenever you need to confirm a daemon is listening on a given port inside the container, e.g., Apache on port 80, run a shell inside the container, then use the following command, which has no dependencies:

```bash
docker exec -it myphpapp-apache /bin/bash
root@7957e1f92342:/# (echo > /dev/tcp/localhost/80) &>/dev/null && echo "open" || echo "close"
```
