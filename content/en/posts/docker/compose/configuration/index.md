---
title: "Configuration, networks, and data persistence with Docker Compose"
date: 2026-01-02
lastmod: 2026-01-02
description: ""
summary: ""
categories: ["virtualisation"]
tags: ["docker", "compose"]
series: ["Docker Compose"]
series_order: 2
weight: 20
draft: true
---

After defining services and learning how Docker Compose builds and manages containers, the next step is to make those services work together reliably. We will now explore how to configure our environment through variables and `.env` files, connect services using custom networks, and ensure data persists across container restarts using volumes. These are essential concepts for building stable and reusable Compose setups.

## Environment variables

Hardcoding credentials or configuration values in `Dockerfiles` or a `docker-compose.yml` file is bad practice. Instead, use environment variables and `.env` files. Example of a `.env.postgres` file:

```ini
POSTGRES_USER=demouser
POSTGRES_PASSWORD=mypassword
POSTGRES_DB=demodb
```

Then, in our `docker-compose.yml` file, we would reference such variables:

```yaml
postgres:
  image: postgres:17
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: ${POSTGRES_DB}
  ports:
    - 5432:5432
```

To instruct Compose to use environment files, we use one or multiple `--env-file` arguments:

```bash
docker compose --env-file .env.postgres up -d
```

> Environment variables defined in a file named `.env` are loaded automatically.

## Networks

Each Compose project automatically gets its own network. Services can communicate by service name. The `networks` directive can appear at the top level or per service.

Basic example:

```yaml
networks:
  backend:

services:
  apache:
    build: docker/apache/
    networks:
      - backend
  postgres:
    image: postgres:17
    networks:
      - backend
```

> Docker assigns an available private subnet automatically, usually in 172.18.0.0/16 range.

We can be very specific about the details of the network configuration:

```yaml
networks:
  backend:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: vmbr0
    attachable: true
    internal: false
    external: false
    labels:
      purpose: internal-communication
    ipam:
      driver: default
      config:
        - subnet: 172.28.0.0/16
          gateway: 172.28.0.1
```

This block defines a custom user-defined bridge network called `backend`. User-defined bridge networks provide *container-level isolation and control* beyond Docker’s default `bridge` network, allowing you to customize parameters like the subnet, gateway, and more. If omitted, Docker Compose assumes `driver: bridge` for new local networks.

The `driver:` key specifies which *network driver* Docker should use:

* `bridge` is the default driver for local networks (on a single Docker host).
* The `bridge` driver creates a Linux bridge interface that connects containers' virtual Ethernet interfaces (veth pairs) to the host network stack.
* Other possible values: `overlay`, `macvlan`, `host`, `none`, or third-party drivers (e.g., from Docker plugins).

The `driver_opts` key lets us pass driver-specific options. These depend on the driver type. For the `bridge` driver, available options are:

* `com.docker.network.bridge.name` allow providing a custom name, which may make it easier to identify the network on the host (e.g., for firewall rules or debugging).
* `com.docker.network.bridge.enable_icc` enables inter-container communication (default `true`).
* `com.docker.network.bridge.enable_ip_masquerade` enables outbound NAT for the bridge (default `true`).
* `com.docker.network.bridge.host_binding_ipv4` specifies which host IP to bind exposed ports to.

The `attachable: true` key allows standalone containers (not launched by Compose or Swarm) to attach to this network. Useful for debugging, interactive testing, or connecting additional containers manually. Its default value is `false`.

The `internal` key determines whether the network is isolated from the external world (default `false`).

The `external` key indicates whether the network is managed externally (outside this Compose file). When `true`, Compose assumes the network already exists and will not attempt to create it. In this case, Compose will be able to reference it as `external.<name>`. Its default value is `false`, meaning Compose will create the network automatically.

The `labels` key allows us to add metadata to the network, in key-value pairs. These labels can be used for documentation, automation, or filtering, and are useful for tagging networks by purpose, environment, or ownership.

The `ipam` key, which stands for IP Address Management, defines how IP addresses are allocated within the network. In the case above, we are using Docker's built-in IPAM driver and we are defining custom addressing rules via a subnet in CIDR format and a gateway.

## Attaching services to networks

A service can be attached to *one or more networks*, and you can optionally configure network-specific options such as aliases or static IP addresses.
This enables flexible communication setups. For example, separating front-end and back-end traffic or assigning predictable addresses within a subnet. Example:

```yaml
services:

  apache:
    image: httpd:latest
    networks:
      backend:
        aliases:
          - web
        ipv4_address: 172.28.0.10
      frontend:
        aliases:
          - public-web

  postgres:
    image: postgres:17
    networks:
      - backend

networks:
  backend:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
  frontend:
    driver: bridge
```

Explanation of the `docker-compose.yml` file:

* The `apache` service connects to two networks:
  * `backend`, shared with `postgres`, to allow database access.
  * `frontend`, which could connect it to a reverse proxy or external clients.
* The alias `web` means that within the `backend` network, other containers can reach the apache service using the hostname `web`.
* The alias `public-web` serves the same purpose within the `frontend` network.
* The static IP `172.28.0.10` provides a fixed address within the backend subnet, which is only possible because IPAM is configured for that network.

## Volumes

Containers are ephemeral by design. If a container is deleted, all data inside it disappears. Volumes provide persistent storage that survives container restarts, rebuilds, and removals. In Compose, volumes can serve several purposes:

* Persistent data for databases (PostgreSQL, Redis, MinIO).
* Shared data between containers (e.g., Apache serving uploaded files stored in MinIO).
* Bind mounts for local development (e.g., linking `./src` to `/var/www/html`).

Compose will automatically manage them for you when you run `up` or `down`, and supports different ways to mount data into containers:

| Type             | Example                           | Description                          |
|------------------|-----------------------------------|--------------------------------------|
| Named volume     | `dbdata:/var/lib/postgresql/data` | Persists even after Compose down     |
| Anonymous volume | `:/var/lib/postgresql/data`       | Automatically created without a name |
| Bind mount       | `./src:/var/www/html`             | Maps a host directory                |

An anonymous volume is a volume created automatically by Docker without a name when you declare a mount target but no source. Anonymous volumes are used, typically, by official images, which include `VOLUME` instructions in their `Dockerfiles`, for short-lived testing (e.g., integration tests) and for prototyping. Anonymous volumes will remain orphaned, so you will need to clean them up manually:

```bash
docker volume prune
```

However, we will usually want to use named volumes, meaning we explicitly declare them:

```yaml
services:
  postgres:
    image: postgres:17
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
    driver: local
    driver_opts:
      type: none
      device: /mnt/external/postgres
      o: bind
```

This snippet defines a named volume called `pgdata`. It is configured to use the `local` driver with custom driver options, effectively turning it into a *bind mount* to a host directory.

The `driver` key specifies which *volume driver* Docker should use, that is, the mechanism Docker uses to manage storage. The `local` driver is the default and stores data directly on the host filesystem. It can be used in two ways:

* Default mode. Docker manages the storage path automatically (e.g., `/var/lib/docker/volumes/pgdata/_data`).
* Custom mode. Combined with `driver_opts`, you can control where and how data is stored. For example, on an external disk, NFS mount, or SSD.

The `driver_opts` key lets us pass *driver-specifi*c options to the storage driver. When using the `local` driver, these options are passed directly to Docker's underlying mount command, allowing you to fine-tune how and where data is stored:

* The `type` field specifies the filesystem type or mount type. Setting it to `none` tells Docker not to expect a specific filesystem like `ext4`, `nfs` or `tmpfs`, and instructs it to not perform a filesystem type check, which is typically used for bind mounts to existing directories. Common alternatives are `type: nfs` for network file systems, and `type: tmpfs` for temporary in-memory storage.
* The `device` field defines the path to the actual storage location on the host. When used with `type: none` and `o: bind`, this path must already exist.
* The `o: bind` option defines the mount options passed to the underlying system call. In this case, it means "bind-mount an existing directory", linking the host directory to the container volume. Common alternatives are `o: bind,ro`, to bind read-only, and `o: nfs, addr=...` to mount an NFS volume.

> The directory `/mnt/external/postgres` could be, for example, a separate disk or partition mounted under `/mnt/external`, or a network-mounted filesystem. This is wehre the volume's data will physically live.
